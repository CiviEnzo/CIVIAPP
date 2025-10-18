import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/cart/cart_models.dart';
import 'package:civiapp/domain/entities/app_notification.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/client_photo.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/last_minute_slot.dart';
import 'package:civiapp/domain/entities/promotion.dart';
import 'package:civiapp/domain/entities/quote.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/presentation/common/theme_mode_action.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:civiapp/services/payments/stripe_payments_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'client_booking_sheet.dart';
import 'client_theme.dart';

const _instagramLogoAsset = 'assets/social_logo/instagram.PNG';
const _tiktokLogoAsset = 'assets/social_logo/tiktok.PNG';
const _facebookLogoAsset = 'assets/social_logo/facebook.PNG';
const _whatsappLogoAsset = 'assets/social_logo/whatsapp.PNG';
const _mapsLogoAsset = 'assets/social_logo/maps.PNG';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
}

enum _ClientBadgeTarget {
  loyalty,
  packages,
  quotes,
  billing,
  photos,
  agenda,
  notifications,
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen>
    with TickerProviderStateMixin {
  static const String _badgePreferencesKeyPrefix =
      'client_dashboard_acknowledged_badges';
  static const int _notificationsIntentIndex = -1;
  static const double _drawerStretchLimit = 72;
  static const SpringDescription _drawerSpring = SpringDescription(
    mass: 1,
    stiffness: 270,
    damping: 22,
  );
  late final AnimationController _drawerHeaderController;
  late final AnimationController _drawerFooterController;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  ProviderSubscription<ClientDashboardIntent?>? _intentSubscription;
  ProviderSubscription<SessionState>? _sessionSubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTab = 0;
  int _bookingSheetSeed = 0;
  bool _pendingShowNotifications = false;
  final Set<String> _processingQuotePayments = <String>{};
  final Map<_ClientBadgeTarget, int> _acknowledgedBadgeCounts = {};
  SharedPreferences? _badgePreferences;
  String? _badgePreferencesUserId;

  Future<SharedPreferences> _ensureBadgePreferences() async {
    final cached = _badgePreferences;
    if (cached != null) {
      return cached;
    }
    final resolved = await SharedPreferences.getInstance();
    _badgePreferences = resolved;
    return resolved;
  }

  String _badgePrefsKeyFor(String userId) {
    return '$_badgePreferencesKeyPrefix::$userId';
  }

  Future<void> _restoreAcknowledgedBadges({String? userId}) async {
    _badgePreferencesUserId = userId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) {
        _acknowledgedBadgeCounts.clear();
        return;
      }
      if (_acknowledgedBadgeCounts.isEmpty) {
        return;
      }
      setState(() {
        _acknowledgedBadgeCounts.clear();
      });
      return;
    }

    SharedPreferences prefs;
    try {
      prefs = await _ensureBadgePreferences();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Impossibile recuperare SharedPreferences: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }

    if (_badgePreferencesUserId != userId) {
      return;
    }

    final raw = prefs.getString(_badgePrefsKeyFor(userId));
    if (!mounted || _badgePreferencesUserId != userId) {
      return;
    }

    if (raw == null || raw.isEmpty) {
      if (_acknowledgedBadgeCounts.isEmpty) {
        return;
      }
      setState(() {
        _acknowledgedBadgeCounts.clear();
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final restored = <_ClientBadgeTarget, int>{};
      for (final entry in decoded.entries) {
        final target =
            _ClientBadgeTarget.values.firstWhereOrNull(
              (candidate) => candidate.name == entry.key,
            );
        if (target == null) {
          continue;
        }
        final value = entry.value;
        final resolved =
            value is int
                ? value
                : value is num
                ? value.toInt()
                : value is String
                ? int.tryParse(value)
                : null;
        if (resolved == null || resolved < 0) {
          continue;
        }
        restored[target] = resolved;
      }
      if (!mounted || _badgePreferencesUserId != userId) {
        return;
      }
      setState(() {
        _acknowledgedBadgeCounts
          ..clear()
          ..addAll(restored);
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Impossibile decodificare gli acknowledgement badge: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _persistAcknowledgedBadges() async {
    final session = ref.read(sessionControllerProvider);
    final userId = session.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    SharedPreferences prefs;
    try {
      prefs = await _ensureBadgePreferences();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Impossibile salvare gli acknowledgement badge: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }

    final payload = <String, int>{};
    _acknowledgedBadgeCounts.forEach((target, value) {
      if (value < 0) {
        return;
      }
      payload[target.name] = value;
    });

    final key = _badgePrefsKeyFor(userId);
    if (payload.isEmpty) {
      await prefs.remove(key);
      return;
    }

    try {
      await prefs.setString(key, jsonEncode(payload));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Impossibile serializzare gli acknowledgement badge: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  int _badgeDelta(_ClientBadgeTarget target, int currentCount) {
    final acknowledged = _acknowledgedBadgeCounts[target];
    if (acknowledged != null && currentCount < acknowledged) {
      _acknowledgedBadgeCounts[target] = currentCount;
      unawaited(_persistAcknowledgedBadges());
      return 0;
    }
    final baseline = _acknowledgedBadgeCounts[target] ?? 0;
    final delta = currentCount - baseline;
    return delta > 0 ? delta : 0;
  }

  void _acknowledgeBadge(_ClientBadgeTarget target, int currentCount) {
    _acknowledgedBadgeCounts[target] = currentCount;
    unawaited(_persistAcknowledgedBadges());
  }

  void _onDrawerElasticTick() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  double _clampStretch(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= _drawerStretchLimit) {
      return _drawerStretchLimit;
    }
    return value;
  }

  void _startDrawerHeaderRebound() {
    final current = _clampStretch(_drawerHeaderController.value);
    if (current == 0 || _drawerHeaderController.isAnimating) {
      if (_drawerHeaderController.value != current) {
        _drawerHeaderController.value = current;
      }
      return;
    }
    _drawerHeaderController.value = current;
    _drawerHeaderController.animateWith(
      SpringSimulation(_drawerSpring, current, 0, 0),
    );
  }

  void _startDrawerFooterRebound() {
    final current = _clampStretch(_drawerFooterController.value);
    if (current == 0 || _drawerFooterController.isAnimating) {
      if (_drawerFooterController.value != current) {
        _drawerFooterController.value = current;
      }
      return;
    }
    _drawerFooterController.value = current;
    _drawerFooterController.animateWith(
      SpringSimulation(_drawerSpring, current, 0, 0),
    );
  }

  bool _onDrawerScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (notification is ScrollUpdateNotification) {
      if (metrics.pixels < metrics.minScrollExtent) {
        final overscroll = _clampStretch(
          metrics.minScrollExtent - metrics.pixels,
        );
        if (_drawerHeaderController.isAnimating) {
          _drawerHeaderController.stop();
        }
        if (_drawerHeaderController.value != overscroll) {
          _drawerHeaderController.value = overscroll;
        }
        if (_drawerFooterController.value != 0) {
          if (_drawerFooterController.isAnimating) {
            _drawerFooterController.stop();
          }
          _drawerFooterController.value = 0;
        }
      } else if (metrics.pixels > metrics.maxScrollExtent) {
        final overscroll = _clampStretch(
          metrics.pixels - metrics.maxScrollExtent,
        );
        if (_drawerFooterController.isAnimating) {
          _drawerFooterController.stop();
        }
        if (_drawerFooterController.value != overscroll) {
          _drawerFooterController.value = overscroll;
        }
        if (_drawerHeaderController.value != 0) {
          if (_drawerHeaderController.isAnimating) {
            _drawerHeaderController.stop();
          }
          _drawerHeaderController.value = 0;
        }
      }
    } else if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      _startDrawerHeaderRebound();
      _startDrawerFooterRebound();
    }
    return false;
  }

  Widget _wrapWithBadge({
    Color? backgroundColor,
    Color? textColor,
    required Widget icon,
    required int badgeCount,
    required bool showBadge,
  }) {
    if (!showBadge || badgeCount <= 0) {
      return icon;
    }
    return Badge.count(
      count: badgeCount,
      isLabelVisible: badgeCount > 0,
      backgroundColor: backgroundColor,
      textColor: textColor,
      child: icon,
    );
  }

  Widget _buildDrawerHeaderSection({
    required Client client,
    required Salon? salon,
  }) {
    final stretch = _clampStretch(_drawerHeaderController.value);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24 + stretch, 20, 0),
      child: _ClientDrawerHeader(client: client, salon: salon),
    );
  }

  Widget _buildDrawerFooterSection({required BuildContext context}) {
    final stretch = _clampStretch(_drawerFooterController.value);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + stretch),
      child: _DrawerNavigationCard(
        icon: Icons.logout_rounded,
        label: 'Esci',
        onTap: () async {
          Navigator.of(context).pop();
          await ref.read(authRepositoryProvider).signOut();
        },
      ),
    );
  }

  Widget _navigationIcon(
    BuildContext context, {
    required IconData icon,
    bool selected = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (!selected) {
      return Icon(icon, size: 24, color: scheme.onSurfaceVariant);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 24, color: scheme.onPrimary),
      ),
    );
  }

  int _resolveLoyaltyValue(int? stored, int aggregated) {
    if (stored == null) {
      return aggregated;
    }
    if (stored == 0 && aggregated != 0) {
      return aggregated;
    }
    return stored;
  }

  int _resolveSpendableBalance({required int stored, required int computed}) {
    final normalizedStored = stored < 0 ? 0 : stored;
    final normalizedComputed = computed < 0 ? 0 : computed;
    if (normalizedStored == normalizedComputed) {
      return normalizedStored;
    }
    if (normalizedComputed == 0 && normalizedStored != 0) {
      return normalizedStored;
    }
    return normalizedComputed;
  }

  _LoyaltyStats _calculateLoyaltyStats(Client client, List<Sale> sales) {
    final aggregatedEarned = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.resolvedEarnedPoints,
    );
    final aggregatedRedeemed = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.redeemedPoints,
    );
    final initialPoints = client.loyaltyInitialPoints;
    final totalEarned = _resolveLoyaltyValue(
      client.loyaltyTotalEarned,
      aggregatedEarned,
    );
    final totalRedeemed = _resolveLoyaltyValue(
      client.loyaltyTotalRedeemed,
      aggregatedRedeemed,
    );
    final computedSpendable = initialPoints + totalEarned - totalRedeemed;
    final spendable = _resolveSpendableBalance(
      stored: client.loyaltyPoints,
      computed: computedSpendable,
    );

    return _LoyaltyStats(
      initialPoints: initialPoints,
      totalEarned: totalEarned,
      totalRedeemed: totalRedeemed,
      spendable: spendable,
    );
  }

  String _quoteLabel(Quote quote) {
    final number = quote.number;
    if (number != null && number.isNotEmpty) {
      return number;
    }
    final shortId = quote.id.length >= 6 ? quote.id.substring(0, 6) : quote.id;
    return '#$shortId';
  }

  String _staffInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'Operatore da definire') {
      return '?';
    }
    final parts =
        trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  TextStyle? _sectionTitleStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.1);
  }

  @override
  void initState() {
    super.initState();
    _drawerHeaderController = AnimationController.unbounded(vsync: this)
      ..addListener(_onDrawerElasticTick);
    _drawerFooterController = AnimationController.unbounded(vsync: this)
      ..addListener(_onDrawerElasticTick);
    _listenForegroundMessages();
    _intentSubscription = ref.listenManual<ClientDashboardIntent?>(
      clientDashboardIntentProvider,
      (previous, next) {
        final intent = next;
        if (intent == null) {
          return;
        }
        if (intent.tabIndex == _notificationsIntentIndex) {
          if (mounted) {
            setState(() => _pendingShowNotifications = true);
          } else {
            _pendingShowNotifications = true;
          }
        } else if (_currentTab != intent.tabIndex) {
          if (mounted) {
            setState(() => _currentTab = intent.tabIndex);
          } else {
            _currentTab = intent.tabIndex;
          }
        }
        unawaited(_handleDashboardIntent(intent));
        ref.read(clientDashboardIntentProvider.notifier).state = null;
      },
    );
    final session = ref.read(sessionControllerProvider);
    unawaited(_restoreAcknowledgedBadges(userId: session.userId));
    _sessionSubscription = ref.listenManual<SessionState>(
      sessionControllerProvider,
      (SessionState? previous, SessionState next) {
        if (previous?.userId == next.userId) {
          return;
        }
        unawaited(_restoreAcknowledgedBadges(userId: next.userId));
      },
    );
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _intentSubscription?.close();
    _sessionSubscription?.close();
    _drawerHeaderController.dispose();
    _drawerFooterController.dispose();
    super.dispose();
  }

  void _listenForegroundMessages() {
    _foregroundSub ??= FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      if (!mounted) {
        return;
      }
      final notificationService = ref.read(notificationServiceProvider);
      final notification = message.notification;
      final title =
          notification?.title ??
          message.data['title'] as String? ??
          'Nuova notifica';
      final body = notification?.body ?? message.data['body'] as String? ?? '';
      final payload = <String, Object?>{
        ...message.data.map((key, value) => MapEntry(key, value)),
        if (message.messageId != null) 'messageId': message.messageId!,
      };
      final badgeRaw = message.data['badge'] ?? message.data['unreadCount'];
      final badgeCount =
          badgeRaw is int
              ? badgeRaw
              : badgeRaw is String
              ? int.tryParse(badgeRaw)
              : null;
      if (badgeCount != null) {
        unawaited(notificationService.updateBadgeCount(badgeCount));
      }
      final int notificationId = DateTime.now().millisecondsSinceEpoch
          .remainder(1 << 31);
      notificationService
          .show(id: notificationId, title: title, body: body, payload: payload)
          .catchError((error, stackTrace) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'ClientDashboardScreen',
                informationCollector:
                    () => [
                      DiagnosticsNode.message(
                        'Failed to display foreground notification',
                      ),
                    ],
              ),
            );
            if (!mounted) {
              return;
            }
            final content = body.isEmpty ? title : '$title\n$body';
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(content),
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
    });
  }

  Future<void> _handleDashboardIntent(ClientDashboardIntent intent) async {
    final type = intent.payload['type']?.toString();
    if (type != 'last_minute_slot') {
      return;
    }
    final slotIdRaw = intent.payload['slotId'];
    final slotId = slotIdRaw?.toString();
    if (slotId == null || slotId.isEmpty) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) {
      return;
    }

    final data = ref.read(appDataProvider);
    final session = ref.read(sessionControllerProvider);
    final clients = data.clients;
    final client =
        clients.firstWhereOrNull(
          (candidate) => candidate.id == session.userId,
        ) ??
        (clients.isNotEmpty ? clients.first : null);
    if (client == null) {
      return;
    }

    final salon = data.salons.firstWhereOrNull(
      (candidate) => candidate.id == client.salonId,
    );
    final slot = data.lastMinuteSlots.firstWhereOrNull(
      (candidate) => candidate.id == slotId,
    );

    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questo slot last-minute non è più disponibile.'),
        ),
      );
      return;
    }

    final featureEnabled = salon?.featureFlags.clientLastMinute ?? false;
    if (!featureEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le offerte last-minute non sono più disponibili per questo salone.',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (!slot.isActiveAt(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lo slot last-minute è scaduto o è già stato prenotato.',
          ),
        ),
      );
      return;
    }

    final services = data.services
        .where(
          (service) => service.salonId == client.salonId && service.isActive,
        )
        .toList(growable: false);

    unawaited(
      _bookLastMinuteSlot(
        client,
        slot,
        services,
        salon: salon,
        overrideContext: context,
      ),
    );
  }

  Future<void> _openBookingSheet(
    Client client, {
    Service? preselectedService,
    LastMinuteSlot? lastMinuteSlot,
    BuildContext? overrideContext,
  }) async {
    final targetContext = overrideContext ?? context;
    final appointment = await ClientBookingSheet.show(
      targetContext,
      client: client,
      preselectedService: preselectedService,
      lastMinuteSlot: lastMinuteSlot,
    );
    if (!mounted || appointment == null) {
      return;
    }
    final confirmationFormat = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    ScaffoldMessenger.of(targetContext).showSnackBar(
      SnackBar(
        content: Text(
          'Appuntamento prenotato per '
          '${confirmationFormat.format(appointment.start)}.',
        ),
      ),
    );
  }

  Future<void> _rescheduleAppointment(
    Client client,
    Appointment appointment, {
    BuildContext? overrideContext,
  }) async {
    final targetContext = overrideContext ?? context;
    final updated = await ClientBookingSheet.show(
      targetContext,
      client: client,
      existingAppointment: appointment,
    );
    if (!mounted || updated == null) {
      return;
    }
    final format = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    ScaffoldMessenger.of(targetContext).showSnackBar(
      SnackBar(
        content: Text(
          'Appuntamento aggiornato al ${format.format(updated.start)}.',
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(
    Appointment appointment, {
    BuildContext? overrideContext,
  }) async {
    final format = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    final appointmentLabel = format.format(appointment.start);
    final shouldCancel = await showDialog<bool>(
      context: overrideContext ?? context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Annulla appuntamento'),
          content: Text(
            'Vuoi annullare l\'appuntamento del $appointmentLabel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sì, annulla'),
            ),
          ],
        );
      },
    );
    if (shouldCancel != true) {
      return;
    }
    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertAppointment(
            appointment.copyWith(status: AppointmentStatus.cancelled),
          );
      if (!mounted) return;
      final targetContext = overrideContext ?? context;
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: Text('Appuntamento del $appointmentLabel annullato.'),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      final targetContext = overrideContext ?? context;
      ScaffoldMessenger.of(
        targetContext,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      final targetContext = overrideContext ?? context;
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: const Text('Errore durante l\'annullamento. Riprova.'),
        ),
      );
    }
  }

  Future<void> _deleteAppointment(
    Appointment appointment, {
    BuildContext? overrideContext,
  }) async {
    final format = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    final appointmentLabel = format.format(appointment.start);
    final shouldDelete = await showDialog<bool>(
      context: overrideContext ?? context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Elimina appuntamento'),
          content: Text(
            'Vuoi eliminare definitivamente l\'appuntamento del $appointmentLabel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    final messenger = ScaffoldMessenger.of(overrideContext ?? context);
    try {
      await ref
          .read(appDataProvider.notifier)
          .deleteAppointment(appointment.id);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Appuntamento del $appointmentLabel eliminato.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error.code == 'permission-denied'
              ? 'Non hai i permessi per eliminare questo appuntamento.'
              : (error.message?.isNotEmpty == true
                  ? error.message!
                  : 'Errore durante l\'eliminazione. Riprova.');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on StateError catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
      );
    }
  }

  Future<void> _showPromotionDetails(
    Promotion promotion, {
    BuildContext? overrideContext,
  }) async {
    if (!mounted) {
      return;
    }
    final targetContext = overrideContext ?? context;
    final discountFormat = NumberFormat('##0.#', 'it_IT');
    await showModalBottomSheet<void>(
      context: targetContext,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final subtitle = promotion.subtitle;
        final tagline = promotion.tagline;
        final endsAt = promotion.endsAt;
        final hasLink = promotion.ctaUrl?.isNotEmpty == true;
        return _wrapClientModal(
          context: sheetContext,
          builder: (modalContext) {
            final theme = Theme.of(modalContext);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promotion.title, style: theme.textTheme.headlineSmall),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(subtitle, style: theme.textTheme.titleMedium),
                ],
                if (tagline != null && tagline.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(tagline, style: theme.textTheme.bodyLarge),
                ],
                if (promotion.discountPercentage > 0) ...[
                  const SizedBox(height: 12),
                  Chip(
                    avatar: const Icon(Icons.percent_rounded, size: 18),
                    label: Text(
                      '-${discountFormat.format(promotion.discountPercentage)}%',
                    ),
                  ),
                ],
                if (endsAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Valida fino al ${DateFormat('dd/MM', 'it_IT').format(endsAt)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                if (hasLink) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: promotion.ctaUrl!));
                      Navigator.of(sheetContext).pop();
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(targetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Link dell\'offerta copiato negli appunti.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Copia link offerta'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Apri il browser e incolla il link per continuare.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Chiudi'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addServiceToCart({
    required BuildContext context,
    required Client client,
    required Salon? salon,
    required Service service,
  }) {
    final cartNotifier = ref.read(cartControllerProvider.notifier);
    cartNotifier.addItem(
      CartItem(
        id: 'service-${service.id}',
        referenceId: service.id,
        type: CartItemType.service,
        name: service.name,
        unitPrice: service.price,
        metadata: {
          'serviceId': service.id,
          'salonId': salon?.id ?? client.salonId,
          'durationMinutes': service.duration.inMinutes,
        },
      ),
    );
    _showAddedToCartSnackBar(
      context: context,
      itemName: service.name,
      client: client,
      salon: salon,
    );
  }

  void _addPackageToCart({
    required BuildContext context,
    required Client client,
    required Salon? salon,
    required ServicePackage package,
  }) {
    final cartNotifier = ref.read(cartControllerProvider.notifier);
    cartNotifier.addItem(
      CartItem(
        id: 'package-${package.id}',
        referenceId: package.id,
        type: CartItemType.package,
        name: package.name,
        unitPrice: package.price,
        metadata: {
          'packageId': package.id,
          'salonId': package.salonId,
          if (package.sessionCount != null)
            'sessionCount': package.sessionCount,
          if (package.discountPercentage != null)
            'discountPercentage': package.discountPercentage,
          if (package.serviceIds.isNotEmpty)
            'serviceIds': package.serviceIds.join(','),
        },
      ),
    );
    _showAddedToCartSnackBar(
      context: context,
      itemName: package.name,
      client: client,
      salon: salon,
    );
  }

  void _showAddedToCartSnackBar({
    required BuildContext context,
    required String itemName,
    required Client client,
    required Salon? salon,
  }) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$itemName aggiunto al carrello'),
        action: SnackBarAction(
          label: 'Apri carrello',
          onPressed: () {
            if (!mounted) return;
            setState(() => _currentTab = 3);
          },
        ),
      ),
    );
  }

  Future<void> _bookLastMinuteSlot(
    Client client,
    LastMinuteSlot slot,
    List<Service> services, {
    Salon? salon,
    BuildContext? overrideContext,
  }) async {
    final targetContext = overrideContext ?? context;
    final service = services.firstWhereOrNull(
      (service) => service.id == slot.serviceId,
    );
    final canUseStripe = salon?.canAcceptOnlinePayments ?? false;

    if (!canUseStripe || salon == null) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        const SnackBar(
          content: Text(
            'Le offerte last-minute richiedono pagamento immediato. Contatta il salone per completare l\'acquisto.',
          ),
        ),
      );
      return;
    }

    final confirmed = await _showLastMinuteSummary(
      context: targetContext,
      slot: slot,
      service: service,
    );
    if (!mounted || !confirmed) {
      return;
    }

    await _checkoutLastMinuteSlot(
      context: targetContext,
      client: client,
      salon: salon,
      slot: slot,
      service: service,
    );
  }

  Future<bool> _showLastMinuteSummary({
    required BuildContext context,
    required LastMinuteSlot slot,
    Service? service,
  }) async {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateLabel = DateFormat('EEEE d MMMM', 'it_IT').format(slot.start);
    final timeLabel = DateFormat('HH:mm', 'it_IT').format(slot.start);
    final durationLabel = '${slot.duration.inMinutes} minuti';
    final operatorName = slot.operatorName ?? 'Operatore da assegnare';
    final basePriceLabel = currency.format(slot.basePrice);
    final priceNowLabel = currency.format(slot.priceNow);
    final savings = slot.basePrice - slot.priceNow;
    final hasSavings = savings > 0.01;
    final savingsLabel = currency.format(savings);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _wrapClientModal(
          context: sheetContext,
          builder: (modalContext) {
            final theme = Theme.of(modalContext);
            final scheme = theme.colorScheme;

            Widget infoSection(String label, String value) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riepilogo last-minute',
                  style: _sectionTitleStyle(context),
                ),
                const SizedBox(height: 12),
                infoSection('Servizio', service?.name ?? slot.serviceName),
                const Divider(height: 24),
                infoSection('Data', dateLabel),
                infoSection('Orario', timeLabel),
                infoSection('Durata', durationLabel),
                infoSection('Operatore', operatorName),
                const Divider(height: 32),
                Text(
                  'Totale da pagare',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      priceNowLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      basePriceLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasSavings) ...[
                      const Spacer(),
                      Text(
                        'Risparmi $savingsLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Pagamento immediato obbligatorio. Le offerte last-minute non possono essere modificate.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Conferma e paga'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _checkoutLastMinuteSlot({
    required BuildContext context,
    required Client client,
    required Salon salon,
    required LastMinuteSlot slot,
    Service? service,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final stripeAccountId = salon.stripeAccountId;
    if (stripeAccountId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pagamento non disponibile per questo salone.'),
        ),
      );
      return false;
    }

    final cartNotifier = ref.read(cartControllerProvider.notifier);
    cartNotifier.clear();
    cartNotifier.addItem(
      CartItem(
        id: 'lm-${slot.id}',
        referenceId: slot.id,
        type: CartItemType.lastMinute,
        name: slot.serviceName,
        unitPrice: slot.priceNow,
        metadata: {
          'slotId': slot.id,
          if (slot.serviceId != null) 'serviceId': slot.serviceId!,
          'slotStart': slot.start.toIso8601String(),
          'salonId': slot.salonId,
        },
      ),
    );

    final metadata = <String, dynamic>{
      'slotId': slot.id,
      'type': CartItemType.lastMinute.label,
      'slotStart': slot.start.toIso8601String(),
      'slotSalonId': slot.salonId,
      'clientName': client.fullName,
      if (slot.serviceId != null) 'serviceId': slot.serviceId!,
      if (service != null) 'serviceName': service.name,
    };

    var dialogVisible = false;
    if (mounted) {
      dialogVisible = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _ProcessingPaymentDialog(),
        ),
      );
    }

    var success = false;
    StripeCheckoutResult? checkoutResult;
    try {
      checkoutResult = await cartNotifier.checkout(
        salonId: salon.id,
        clientId: client.id,
        salonStripeAccountId: stripeAccountId,
        customerId: client.stripeCustomerId,
        additionalMetadata: metadata,
      );
      success = true;
      if (mounted) {
        final startLabel = DateFormat('HH:mm', 'it_IT').format(slot.start);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Pagamento completato! Ti aspettiamo alle $startLabel.',
            ),
          ),
        );
      }
    } on StripePaymentsException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Pagamento non riuscito: ${error.toString()}'),
          ),
        );
      }
    } finally {
      if (dialogVisible && mounted) {
        final navigator = Navigator.maybeOf(context, rootNavigator: true);
        if (navigator != null) {
          unawaited(navigator.maybePop());
        }
      }
      if (!success) {
        cartNotifier.clear();
      }
    }
    if (!success || checkoutResult == null) {
      return false;
    }

    try {
      await _finalizeLastMinuteBooking(
        client: client,
        salon: salon,
        slot: slot,
        paymentIntentId: checkoutResult.paymentIntentId,
      );
      return true;
    } on StateError catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Pagamento riuscito ma prenotazione non completata: ${error.message}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Pagamento riuscito ma prenotazione non completata. ${error.toString()}',
            ),
          ),
        );
      }
    }
    return false;
  }

  Future<void> _acceptQuoteWithStripe({
    required BuildContext context,
    required Client client,
    required Quote quote,
    required Salon salon,
  }) async {
    if (_processingQuotePayments.contains(quote.id)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (quote.status != QuoteStatus.sent) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Il preventivo deve essere inviato dal salone prima di poter essere accettato.',
          ),
        ),
      );
      return;
    }
    if (quote.isExpired) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Questo preventivo è scaduto. Richiedi al salone una nuova offerta.',
          ),
        ),
      );
      return;
    }
    if (quote.total <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Il totale del preventivo non è valido per il pagamento online.',
          ),
        ),
      );
      return;
    }
    if (!salon.canAcceptOnlinePayments) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Il salone non ha ancora attivato i pagamenti online.'),
        ),
      );
      return;
    }
    final stripeAccountId = salon.stripeAccountId;
    if (stripeAccountId == null || stripeAccountId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Account Stripe del salone non disponibile. Contatta il salone.',
          ),
        ),
      );
      return;
    }

    final paymentsService = ref.read(stripePaymentsServiceProvider);
    if (!paymentsService.isConfigured) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pagamento non disponibile. Riavvia l\'app e riprova.'),
        ),
      );
      return;
    }

    setState(() => _processingQuotePayments.add(quote.id));

    var dialogVisible = false;
    if (mounted) {
      dialogVisible = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _ProcessingPaymentDialog(),
        ),
      );
    }

    StripeCheckoutResult? checkoutResult;

    try {
      checkoutResult = await paymentsService.checkoutQuote(
        quoteId: quote.id,
        quoteNumber: quote.number,
        quoteTitle: quote.title,
        totalAmount: quote.total,
        salonId: salon.id,
        clientId: client.id,
        currency: 'eur',
        salonStripeAccountId: stripeAccountId,
        customerId: client.stripeCustomerId,
        clientName: client.fullName,
        salonName: salon.name,
      );
      if (!mounted) {
        return;
      }

      try {
        final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
        await functions.httpsCallable('finalizeQuotePaymentIntent').call(
          <String, dynamic>{'paymentIntentId': checkoutResult.paymentIntentId},
        );
      } on FirebaseFunctionsException catch (error) {
        if (mounted && kDebugMode) {
          debugPrint(
            'finalizeQuotePaymentIntent failed: ${error.code} ${error.message}',
          );
        }
      } catch (error, stackTrace) {
        if (mounted && kDebugMode) {
          debugPrint('finalizeQuotePaymentIntent error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Pagamento completato! Il salone riceverà subito il preventivo accettato.',
          ),
        ),
      );
    } on StripePaymentsException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Pagamento non riuscito: ${error.toString()}'),
          ),
        );
      }
    } finally {
      if (dialogVisible && mounted) {
        final navigator = Navigator.maybeOf(context, rootNavigator: true);
        navigator?.maybePop();
      }
      if (mounted) {
        setState(() => _processingQuotePayments.remove(quote.id));
      } else {
        _processingQuotePayments.remove(quote.id);
      }
    }
  }

  Future<void> _finalizeLastMinuteBooking({
    required Client client,
    required Salon salon,
    required LastMinuteSlot slot,
    required String paymentIntentId,
  }) async {
    final staffId =
        slot.operatorId != null && slot.operatorId!.isNotEmpty
            ? slot.operatorId!
            : 'auto-stripe';
    final appointment = Appointment(
      id: 'stripe-$paymentIntentId',
      salonId: salon.id,
      clientId: client.id,
      staffId: staffId,
      serviceId: slot.serviceId,
      start: slot.start,
      end: slot.start.add(slot.duration),
      status: AppointmentStatus.confirmed,
      notes: 'Prenotazione last-minute ${slot.id} (Stripe)',
      roomId: slot.roomId,
      lastMinuteSlotId: slot.id,
    );

    final store = ref.read(appDataProvider.notifier);
    await store.upsertAppointment(
      appointment,
      consumeLastMinuteSlotId: slot.id,
    );
    await _ensureLastMinuteSaleAndCashFlow(
      client: client,
      salon: salon,
      slot: slot,
      paymentIntentId: paymentIntentId,
    );
  }

  Future<void> _ensureLastMinuteSaleAndCashFlow({
    required Client client,
    required Salon salon,
    required LastMinuteSlot slot,
    required String paymentIntentId,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      await functions.httpsCallable('ensureLastMinutePaymentRecords').call({
        'paymentIntentId': paymentIntentId,
        'salonId': salon.id,
        'clientId': client.id,
        'slotId': slot.id,
        'clientName': client.fullName,
        'slot': {
          'serviceId': slot.serviceId,
          'serviceName': slot.serviceName,
          'operatorId': slot.operatorId,
          'priceNow': slot.priceNow,
          'basePrice': slot.basePrice,
          'discountPercentage': slot.discountPercentage,
          'start': slot.start.toIso8601String(),
          'durationMinutes': slot.duration.inMinutes,
          'roomId': slot.roomId,
        },
      });
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'ensureLastMinutePaymentRecords failed: ${error.code} ${error.message}',
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ensureLastMinutePaymentRecords error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  IconData _cartItemIcon(CartItemType type) {
    switch (type) {
      case CartItemType.package:
        return Icons.card_giftcard_rounded;
      case CartItemType.service:
        return Icons.design_services_rounded;
      case CartItemType.lastMinute:
        return Icons.flash_on_rounded;
    }
  }

  String _cartItemTypeLabel(CartItemType type) {
    switch (type) {
      case CartItemType.package:
        return 'Pacchetto';
      case CartItemType.service:
        return 'Servizio';
      case CartItemType.lastMinute:
        return 'Last minute';
    }
  }

  String? _cartItemSubtitle(CartItem item) {
    switch (item.type) {
      case CartItemType.service:
        final duration = item.metadata['durationMinutes'];
        if (duration != null) {
          return 'Durata ${duration} minuti';
        }
        return null;
      case CartItemType.package:
        final sessions = item.metadata['sessionCount'];
        if (sessions != null) {
          return '$sessions sessioni incluse';
        }
        return null;
      case CartItemType.lastMinute:
        final slotStart = item.metadata['slotStart'];
        if (slotStart is String) {
          final parsed = DateTime.tryParse(slotStart);
          if (parsed != null) {
            final formatted = DateFormat('dd/MM HH:mm', 'it_IT').format(parsed);
            return 'Slot del $formatted';
          }
        }
        return null;
    }
  }

  String _formatCountdown(DateTime start) {
    final now = DateTime.now();
    final diff = start.difference(now);
    if (diff.isNegative) {
      return 'In corso';
    }
    final minutes = diff.inMinutes;
    if (minutes >= 60) {
      final hours = diff.inHours;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${remainingMinutes}m';
    }
    final seconds = diff.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final cartState = ref.watch(cartControllerProvider);
    final clients = data.clients;
    final selectedClient = clients.firstWhereOrNull(
      (client) => client.id == session.userId,
    );

    if (clients.isEmpty) {
      final themedData = ClientTheme.resolve(Theme.of(context));
      return Theme(
        data: themedData,
        child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Area clienti'),
                actions: [
                  const ThemeModeAction(),
                  IconButton(
                    tooltip: 'Esci',
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                    },
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Non è stato trovato alcun profilo cliente associato all\'account. Completa l\'onboarding oppure contatta il salone per essere invitato.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    if (selectedClient == null && clients.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionControllerProvider.notifier).setUser(clients.first.id);
        ref
            .read(sessionControllerProvider.notifier)
            .setSalon(clients.first.salonId);
      });
    }

    final currentClient = selectedClient ?? clients.first;
    final salon = data.salons.firstWhereOrNull(
      (salon) => salon.id == currentClient.salonId,
    );
    final salonPackages = data.packages
        .where((pkg) => pkg.salonId == currentClient.salonId)
        .toList(growable: false);
    final appointments =
        data.appointments
            .where((appointment) => appointment.clientId == currentClient.id)
            .toList();
    final now = DateTime.now();
    final upcoming =
        appointments
            .where(
              (appointment) =>
                  appointment.start.isAfter(now) &&
                  appointment.status != AppointmentStatus.cancelled &&
                  appointment.status != AppointmentStatus.noShow,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final history =
        appointments
            .where(
              (appointment) =>
                  appointment.start.isBefore(now) ||
                  appointment.status == AppointmentStatus.cancelled ||
                  appointment.status == AppointmentStatus.noShow,
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));

    final salonServices =
        data.services
            .where(
              (service) =>
                  service.salonId == currentClient.salonId && service.isActive,
            )
            .toList();
    final salonStaff = data.staff
        .where((member) => member.salonId == currentClient.salonId)
        .toList(growable: false);
    final salonFeatureFlags = salon?.featureFlags ?? const SalonFeatureFlags();
    final rawPromotions = data.promotions
        .where((promotion) => promotion.salonId == currentClient.salonId)
        .toList(growable: false);
    final promotions =
        salonFeatureFlags.clientPromotions
            ? rawPromotions
                .where((promotion) => promotion.isLiveAt(now))
                .toList(growable: false)
            : const <Promotion>[];
    final rawLastMinuteSlots = data.lastMinuteSlots
        .where((slot) => slot.salonId == currentClient.salonId)
        .toList(growable: false);
    final lastMinuteSlots =
        salonFeatureFlags.clientLastMinute
            ? rawLastMinuteSlots
                .where((slot) => slot.isActiveAt(now))
                .toList(growable: false)
            : const <LastMinuteSlot>[];
    final clientPackages = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: data.appointments,
      services: data.services,
      clientId: currentClient.id,
      salonId: currentClient.salonId,
    );
    final activePackages = clientPackages
        .where((pkg) => pkg.isActive)
        .toList(growable: false);
    final pastPackages = clientPackages
        .where((pkg) => !pkg.isActive)
        .toList(growable: false);
    final notifications =
        data.clientNotifications
            .where((notification) => notification.clientId == currentClient.id)
            .toList()
          ..sort(
            (a, b) => (b.sentAt ?? b.scheduledAt ?? b.createdAt).compareTo(
              a.sentAt ?? a.scheduledAt ?? a.createdAt,
            ),
          );
    final notificationsCount = notifications.length;
    if (_pendingShowNotifications) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _pendingShowNotifications = false);
        unawaited(
          _showNotificationsPage(context, notifications: notifications),
        );
      });
    }
    final clientSales =
        data.sales.where((sale) => sale.clientId == currentClient.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final outstandingSales =
        clientSales.where((sale) => sale.outstandingAmount > 0.01).toList();
    final outstandingTotal = outstandingSales.fold<double>(
      0,
      (sum, sale) => sum + sale.outstandingAmount,
    );
    final loyaltyStats = _calculateLoyaltyStats(currentClient, clientSales);
    final loyaltyTransactionsCount =
        clientSales
            .where(
              (sale) =>
                  sale.loyalty.resolvedEarnedPoints > 0 ||
                  sale.loyalty.redeemedPoints > 0,
            )
            .length;
    final clientQuotes = data.quotes
        .where((quote) => quote.clientId == currentClient.id)
        .toList(growable: false);
    final packagesBadgeDelta = _badgeDelta(
      _ClientBadgeTarget.packages,
      clientPackages.length,
    );
    final pendingQuotesCount =
        clientQuotes
            .where(
              (quote) =>
                  quote.status == QuoteStatus.sent &&
                  !quote.isExpired &&
                  quote.acceptedAt == null &&
                  quote.declinedAt == null,
            )
            .length;
    final clientPhotos = ref.watch(clientPhotosProvider(currentClient.id));
    final photosCount = clientPhotos.length;
    final loyaltyBadgeDelta = _badgeDelta(
      _ClientBadgeTarget.loyalty,
      loyaltyTransactionsCount,
    );
    final quotesBadgeDelta = _badgeDelta(
      _ClientBadgeTarget.quotes,
      pendingQuotesCount,
    );
    final billingBadgeDelta = _badgeDelta(
      _ClientBadgeTarget.billing,
      outstandingSales.length,
    );
    final photosBadgeDelta = _badgeDelta(
      _ClientBadgeTarget.photos,
      photosCount,
    );
    final agendaBadgeDelta = _badgeDelta(
      _ClientBadgeTarget.agenda,
      upcoming.length,
    );
    final notificationsBadgeDelta = _badgeDelta(
      _ClientBadgeTarget.notifications,
      notificationsCount,
    );
    final shouldShowLoyaltyBadge = loyaltyBadgeDelta > 0;
    final shouldShowPackagesBadge = packagesBadgeDelta > 0;
    final shouldShowQuotesBadge = quotesBadgeDelta > 0;
    final shouldShowBillingBadge = billingBadgeDelta > 0;
    final shouldShowPhotosBadge = photosBadgeDelta > 0;
    final shouldShowAgendaBadge = agendaBadgeDelta > 0;
    final shouldShowNotificationsBadge = notificationsBadgeDelta > 0;
    final hasDrawerBadge =
        shouldShowLoyaltyBadge ||
        shouldShowPackagesBadge ||
        shouldShowQuotesBadge ||
        shouldShowBillingBadge ||
        shouldShowPhotosBadge;

    final themedData = ClientTheme.resolve(Theme.of(context));
    return Theme(
      data: themedData,
      child: Builder(
        builder: (context) {
          final cartBadgeCount = cartState.items.length;
          final tabViews = <Widget>[
            _buildHomeTab(
              context: context,
              client: currentClient,
              salon: salon,
              featureFlags: salonFeatureFlags,
              notifications: notifications,
              upcoming: upcoming,
              history: history,
              services: salonServices,
              staffMembers: salonStaff,
              packagesCatalog: salonPackages,
              promotions: promotions,
              lastMinuteSlots: lastMinuteSlots,
              activePackages: activePackages,
              pastPackages: pastPackages,
              sales: clientSales,
            ),
            _buildAppointmentsTab(
              context: context,
              client: currentClient,
              upcoming: upcoming,
              history: history,
            ),
            _buildBookingTab(
              context: context,
              client: currentClient,
              salon: salon,
              seed: _bookingSheetSeed,
            ),
            _buildCartTab(
              context: context,
              client: currentClient,
              salon: salon,
              cartState: cartState,
            ),
            _buildSalonInfoTab(context: context, salon: salon),
          ];

          final colorScheme = Theme.of(context).colorScheme;
          final navigationBadgeOpacity =
              colorScheme.brightness == Brightness.dark ? 0.7 : 0.9;
          final navigationBadgeBackground = colorScheme.primary.withAlpha(
            (navigationBadgeOpacity.clamp(0.0, 1.0) * 255).round(),
          );
          final navigationBadgeTextColor = colorScheme.onPrimary;

          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Menu',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon:
                    hasDrawerBadge
                        ? Badge(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.menu_rounded),
                        )
                        : const Icon(Icons.menu_rounded),
              ),
              title: Text('Ciao ${currentClient.firstName}'),
              actions: [
                const ThemeModeAction(),
                IconButton(
                  tooltip: 'Notifiche',
                  onPressed: () {
                    unawaited(
                      _showNotificationsPage(
                        context,
                        notifications: notifications,
                      ),
                    );
                  },
                  icon: Badge.count(
                    count: notificationsBadgeDelta,
                    isLabelVisible: shouldShowNotificationsBadge,
                    child: const Icon(Icons.notifications_rounded),
                  ),
                ),
              ],
            ),
            drawer: Drawer(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDrawerHeaderSection(
                      client: currentClient,
                      salon: salon,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: StretchingOverscrollIndicator(
                          axisDirection: AxisDirection.down,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _onDrawerScrollNotification,
                            child: ListView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.only(top: 24),
                              children: [
                                _DrawerNavigationCard(
                                  icon: Icons.loyalty_rounded,
                                  label: 'Punti fedeltà',
                                  subtitle:
                                      'Saldo: ${loyaltyStats.spendable} pt',
                                  showBadge: shouldShowLoyaltyBadge,
                                  badgeCount: loyaltyBadgeDelta,
                                  onTap: () {
                                    setState(() {
                                      _acknowledgeBadge(
                                        _ClientBadgeTarget.loyalty,
                                        loyaltyTransactionsCount,
                                      );
                                    });
                                    Navigator.of(context).pop();
                                    _showLoyaltySheet(
                                      context,
                                      client: currentClient,
                                      sales: clientSales,
                                    );
                                  },
                                ),
                                _DrawerNavigationCard(
                                  icon: Icons.card_giftcard_rounded,
                                  label: 'Pacchetti',
                                  subtitle:
                                      activePackages.isEmpty
                                          ? 'Nessun pacchetto attivo'
                                          : '${activePackages.length} attivi',
                                  showBadge: shouldShowPackagesBadge,
                                  badgeCount: packagesBadgeDelta,
                                  onTap: () {
                                    setState(() {
                                      _acknowledgeBadge(
                                        _ClientBadgeTarget.packages,
                                        clientPackages.length,
                                      );
                                    });
                                    Navigator.of(context).pop();
                                    _showPackagesSheet(
                                      context,
                                      activePackages: activePackages,
                                      pastPackages: pastPackages,
                                    );
                                  },
                                ),
                                _DrawerNavigationCard(
                                  icon: Icons.description_rounded,
                                  label: 'Preventivi',
                                  subtitle: 'Rivedi e accetta le proposte',
                                  showBadge: shouldShowQuotesBadge,
                                  badgeCount: quotesBadgeDelta,
                                  onTap: () {
                                    setState(() {
                                      _acknowledgeBadge(
                                        _ClientBadgeTarget.quotes,
                                        pendingQuotesCount,
                                      );
                                    });
                                    Navigator.of(context).pop();
                                    _showQuotesSheet(context, currentClient);
                                  },
                                ),
                                _DrawerNavigationCard(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'Fatturazione',
                                  subtitle:
                                      outstandingTotal > 0
                                          ? 'Da saldare: ${NumberFormat.simpleCurrency(locale: 'it_IT').format(outstandingTotal)}'
                                          : 'Pagamenti aggiornati',
                                  showBadge: shouldShowBillingBadge,
                                  badgeCount: billingBadgeDelta,
                                  onTap: () {
                                    setState(() {
                                      _acknowledgeBadge(
                                        _ClientBadgeTarget.billing,
                                        outstandingSales.length,
                                      );
                                    });
                                    Navigator.of(context).pop();
                                    _showBillingSheet(
                                      context,
                                      client: currentClient,
                                      sales: clientSales,
                                      outstandingSales: outstandingSales,
                                      activePackages: activePackages,
                                      pastPackages: pastPackages,
                                    );
                                  },
                                ),
                                _DrawerNavigationCard(
                                  icon: Icons.photo_library_rounded,
                                  label: 'Le mie foto',
                                  subtitle:
                                      'Guarda i risultati dei trattamenti',
                                  showBadge: shouldShowPhotosBadge,
                                  badgeCount: photosBadgeDelta,
                                  onTap: () {
                                    setState(() {
                                      _acknowledgeBadge(
                                        _ClientBadgeTarget.photos,
                                        photosCount,
                                      );
                                    });
                                    Navigator.of(context).pop();
                                    _showPhotosSheet(context, currentClient);
                                  },
                                ),
                                const SizedBox(height: 12),
                                _DrawerNavigationCard(
                                  icon: Icons.settings_rounded,
                                  label: 'Impostazioni',
                                  subtitle: 'Presto disponibili',
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildDrawerFooterSection(context: context),
                  ],
                ),
              ),
            ),
            body: IndexedStack(index: _currentTab, children: tabViews),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentTab,
              onDestinationSelected: (index) {
                if (_currentTab == index && index == 2) {
                  setState(() {
                    _bookingSheetSeed++;
                  });
                  return;
                }
                setState(() {
                  _currentTab = index;
                  if (index == 1) {
                    _acknowledgeBadge(
                      _ClientBadgeTarget.agenda,
                      upcoming.length,
                    );
                  }
                });
              },
              destinations: [
                NavigationDestination(
                  icon: _navigationIcon(context, icon: Icons.home_outlined),
                  selectedIcon: _navigationIcon(
                    context,
                    icon: Icons.home,
                    selected: true,
                  ),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: _wrapWithBadge(
                    backgroundColor: navigationBadgeBackground,
                    textColor: navigationBadgeTextColor,
                    icon: _navigationIcon(
                      context,
                      icon: Icons.event_note_outlined,
                    ),
                    badgeCount: agendaBadgeDelta,
                    showBadge: shouldShowAgendaBadge,
                  ),
                  selectedIcon: _wrapWithBadge(
                    backgroundColor: navigationBadgeBackground,
                    textColor: navigationBadgeTextColor,
                    icon: _navigationIcon(
                      context,
                      icon: Icons.event_note,
                      selected: true,
                    ),
                    badgeCount: agendaBadgeDelta,
                    showBadge: shouldShowAgendaBadge,
                  ),
                  label: 'Agenda',
                ),
                NavigationDestination(
                  icon: _navigationIcon(
                    context,
                    icon: Icons.calendar_month_outlined,
                  ),
                  selectedIcon: _navigationIcon(
                    context,
                    icon: Icons.calendar_month,
                    selected: true,
                  ),
                  label: 'Prenota',
                ),
                NavigationDestination(
                  icon: Badge.count(
                    count: cartBadgeCount,
                    isLabelVisible: cartBadgeCount > 0,
                    backgroundColor: navigationBadgeBackground,
                    textColor: navigationBadgeTextColor,
                    child: _navigationIcon(
                      context,
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                  selectedIcon: Badge.count(
                    count: cartBadgeCount,
                    isLabelVisible: cartBadgeCount > 0,
                    backgroundColor: navigationBadgeBackground,
                    textColor: navigationBadgeTextColor,
                    child: _navigationIcon(
                      context,
                      icon: Icons.shopping_bag,
                      selected: true,
                    ),
                  ),
                  label: 'Carrello',
                ),
                NavigationDestination(
                  icon: _navigationIcon(
                    context,
                    icon: Icons.storefront_outlined,
                  ),
                  selectedIcon: _navigationIcon(
                    context,
                    icon: Icons.storefront,
                    selected: true,
                  ),
                  label: 'Info',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotosTab({
    required BuildContext context,
    required Client client,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClientPhotosGallery(clientId: client.id),
      ),
    );
  }

  Widget _buildHomeTab({
    required BuildContext context,
    required Client client,
    required Salon? salon,
    required SalonFeatureFlags featureFlags,
    required List<AppNotification> notifications,
    required List<Appointment> upcoming,
    required List<Appointment> history,
    required List<Service> services,
    required List<StaffMember> staffMembers,
    required List<ServicePackage> packagesCatalog,
    required List<Promotion> promotions,
    required List<LastMinuteSlot> lastMinuteSlots,
    required List<ClientPackagePurchase> activePackages,
    required List<ClientPackagePurchase> pastPackages,
    required List<Sale> sales,
  }) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final sectionTitleStyle = _sectionTitleStyle(context);
    final nextAppointment = upcoming.isEmpty ? null : upcoming.first;
    final showPromotions = featureFlags.clientPromotions;
    final showLastMinute = featureFlags.clientLastMinute;

    final nextAppointmentServices =
        nextAppointment == null
            ? const <Service>[]
            : nextAppointment.serviceIds
                .map(
                  (id) =>
                      services.firstWhereOrNull((service) => service.id == id),
                )
                .whereNotNull()
                .toList(growable: false);
    final nextAppointmentStaff =
        nextAppointment == null
            ? null
            : staffMembers.firstWhereOrNull(
              (member) => member.id == nextAppointment.staffId,
            );
    final nextAppointmentBaseLabel =
        nextAppointment == null
            ? null
            : DateFormat(
              'EEEE d MMMM • HH:mm',
              'it_IT',
            ).format(nextAppointment.start);
    final nextAppointmentLabel =
        nextAppointmentBaseLabel == null
            ? null
            : toBeginningOfSentenceCase(nextAppointmentBaseLabel);
    final nextAppointmentServiceLabel =
        nextAppointmentServices.isEmpty
            ? 'Servizio da definire'
            : nextAppointmentServices
                .map((service) => service.name)
                .join(' + ');
    final nextAppointmentStaffLabel =
        nextAppointmentStaff?.fullName ?? 'Operatore da definire';
    final nextAppointmentStaffInitials = _staffInitials(
      nextAppointmentStaffLabel,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PushTokenRegistrar(clientId: client.id),
        Text('Prossimo appuntamento', style: sectionTitleStyle),
        const SizedBox(height: 6),
        Card(
          color: theme.colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nextAppointment != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.event_available_rounded,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nextAppointmentLabel ?? '',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              nextAppointmentServiceLabel,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: nextAppointmentStaffLabel,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Semantics(
                          label: 'Operatore: $nextAppointmentStaffLabel',
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primary
                                .withOpacity(0.12),
                            child: Text(
                              nextAppointmentStaffInitials,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Nessun appuntamento in programma',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => _currentTab = 2),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Prenota ora'),
                  ),
                ],

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (showLastMinute) ...[
          Text('Last Minute', style: sectionTitleStyle),
          const SizedBox(height: 6),
          if (lastMinuteSlots.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Niente slot ora. Attiva gli avvisi!'),
              ),
            )
          else ...[
            Column(
              children:
                  lastMinuteSlots
                      .take(4)
                      .map(
                        (slot) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LastMinuteSlotCard(
                            slot: slot,
                            currency: currency,
                            countdownText: _formatCountdown(slot.start),
                            onBook:
                                () => _bookLastMinuteSlot(
                                  client,
                                  slot,
                                  services,
                                  salon: salon,
                                  overrideContext: context,
                                ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            if (lastMinuteSlots.length > 4)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _currentTab = 1),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Vedi tutti gli slot nelle prossime 2 ore'),
                ),
              ),
          ],
          const SizedBox(height: 16),
        ],

        if (showPromotions) ...[
          Text('Promozioni in corso', style: sectionTitleStyle),
          const SizedBox(height: 6),
          if (promotions.isEmpty)
            const Card(
              child: ListTile(title: Text('Nessuna promozione attiva')),
            )
          else
            _PromotionsCarousel(
              promotions: promotions,
              onPromotionTap:
                  (promotion) => _showPromotionDetails(
                    promotion,
                    overrideContext: context,
                  ),
            ),
          const SizedBox(height: 16),
        ],

        if (packagesCatalog.isNotEmpty) ...[
          Text('Pacchetti disponibili', style: sectionTitleStyle),
          const SizedBox(height: 6),
          _PackagesCarousel(
            packages: packagesCatalog,
            onAddToCart:
                (pkg) => _addPackageToCart(
                  context: context,
                  client: client,
                  salon: salon,
                  package: pkg,
                ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildAppointmentsTab({
    required BuildContext context,
    required Client client,
    required List<Appointment> upcoming,
    required List<Appointment> history,
  }) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                labelStyle: theme.textTheme.titleMedium,
                tabs: [
                  Tab(
                    text:
                        upcoming.isEmpty
                            ? 'Prossimi'
                            : 'Prossimi (${upcoming.length})',
                  ),
                  Tab(
                    text:
                        history.isEmpty
                            ? 'Storico'
                            : 'Storico (${history.length})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _AppointmentsList(
                    emptyMessage: 'Non hai appuntamenti futuri',
                    appointments: upcoming,
                    onReschedule:
                        (appointment) => _rescheduleAppointment(
                          client,
                          appointment,
                          overrideContext: context,
                        ),
                    onCancel:
                        (appointment) => _cancelAppointment(
                          appointment,
                          overrideContext: context,
                        ),
                    onDelete:
                        (appointment) => _deleteAppointment(
                          appointment,
                          overrideContext: context,
                        ),
                  ),
                  _AppointmentsList(
                    emptyMessage:
                        'Lo storico sarà disponibile dopo il primo appuntamento',
                    appointments: history,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingTab({
    required BuildContext context,
    required Client client,
    required Salon? salon,
    required int seed,
  }) {
    return SafeArea(
      child: ClientBookingSheet(
        key: ValueKey(seed),
        client: client,
        onCompleted: (appointment) {
          if (!mounted) {
            return;
          }
          final format = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Prenotazione confermata per ${format.format(appointment.start)}.',
              ),
            ),
          );
        },
        onDismiss: () {
          if (!mounted) {
            return;
          }
          setState(() => _currentTab = 0);
        },
      ),
    );
  }

  Widget _buildCartTab({
    required BuildContext context,
    required Client client,
    required Salon? salon,
    required CartState cartState,
  }) {
    final theme = Theme.of(context);
    final cartNotifier = ref.read(cartControllerProvider.notifier);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final items = cartState.items;
    final canCheckout =
        items.isNotEmpty &&
        !cartState.isProcessing &&
        salon?.stripeAccountId != null;

    Future<void> handleCheckout() async {
      if (salon == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pagamento non disponibile per questo salone.'),
          ),
        );
        return;
      }
      await _checkoutCart(context: context, client: client, salon: salon);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Il tuo carrello', style: _sectionTitleStyle(context)),
            const SizedBox(height: 10),
            if (cartState.isProcessing) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child:
                  items.isEmpty
                      ? Center(
                        child: Text(
                          'Il carrello è vuoto. Aggiungi servizi o pacchetti per iniziare.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                      : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final itemTotal = currency.format(item.totalAmount);
                          final subtitle = _cartItemSubtitle(item);
                          final canIncrement =
                              item.type != CartItemType.lastMinute;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _cartItemIcon(item.type),
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _cartItemTypeLabel(item.type),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        if (subtitle != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Text(
                                              itemTotal,
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              tooltip: 'Diminuisci quantità',
                                              color: theme.colorScheme.primary,
                                              onPressed:
                                                  cartState.isProcessing ||
                                                          item.quantity <= 1
                                                      ? null
                                                      : () => cartNotifier
                                                          .setQuantity(
                                                            item.id,
                                                            item.quantity - 1,
                                                          ),
                                              icon: const Icon(Icons.remove),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: Text(
                                                '${item.quantity}',
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Aumenta quantità',
                                              color: theme.colorScheme.primary,
                                              onPressed:
                                                  cartState.isProcessing ||
                                                          !canIncrement
                                                      ? null
                                                      : () => cartNotifier
                                                          .setQuantity(
                                                            item.id,
                                                            item.quantity + 1,
                                                          ),
                                              icon: const Icon(Icons.add),
                                            ),
                                            IconButton(
                                              tooltip: 'Rimuovi',
                                              color: theme.colorScheme.primary,
                                              onPressed:
                                                  cartState.isProcessing
                                                      ? null
                                                      : () => cartNotifier
                                                          .removeItem(item.id),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 16),
            if (items.isNotEmpty) ...[
              Row(
                children: [
                  Text('Totale', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    currency.format(cartState.totalAmount),
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                child: FilledButton.icon(
                  onPressed: canCheckout ? handleCheckout : null,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    cartState.isProcessing
                        ? 'Elaborazione...'
                        : 'Procedi al pagamento',
                  ),
                ),
              ),
            ],
            if (salon?.stripeAccountId == null) ...[
              const SizedBox(height: 12),
              Text(
                'Il pagamento online non è abilitato per questo salone.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalonInfoTab({
    required BuildContext context,
    required Salon? salon,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (salon == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nessun salone attivo associato al tuo profilo.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final description = salon.description?.trim();

    final locationLines = <String>[];
    final address = salon.address.trim();
    if (address.isNotEmpty) {
      locationLines.add(address);
    }
    final cityLineParts = <String>[];
    final postalCode = salon.postalCode?.trim();
    if (postalCode != null && postalCode.isNotEmpty) {
      cityLineParts.add(postalCode);
    }
    final city = salon.city.trim();
    if (city.isNotEmpty) {
      cityLineParts.add(city);
    }
    if (cityLineParts.isNotEmpty) {
      locationLines.add(cityLineParts.join(' '));
    }
    final locationDescription = locationLines.join('\n');
    final mapsUri = _buildMapsUri(salon, locationDescription);

    final socialEntries =
        salon.socialLinks.entries
            .map(
              (entry) => MapEntry(
                _normalizeSocialLabel(entry.key),
                entry.value.trim(),
              ),
            )
            .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
            .toList()
          ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    MapEntry<String, String>? whatsappEntry;
    final whatsappIndex = socialEntries.indexWhere(
      (entry) => entry.key.toLowerCase().contains('whatsapp'),
    );
    if (whatsappIndex != -1) {
      whatsappEntry = socialEntries.removeAt(whatsappIndex);
    }

    final contactTiles = <Widget>[];
    final phone = salon.phone.trim();
    if (phone.isNotEmpty) {
      contactTiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SalonInfoCircleIcon(scheme.primary, Icons.phone_rounded),
          title: const Text('Telefono'),
          subtitle: Text(phone),
          onTap:
              () => _launchExternalUrl(
                context,
                Uri(scheme: 'tel', path: _normalizePhone(phone)),
              ),
        ),
      );
    }
    final email = salon.email.trim();
    if (email.isNotEmpty) {
      contactTiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SalonInfoCircleIcon(
            scheme.primary,
            Icons.mail_outline_rounded,
          ),
          title: const Text('Email'),
          subtitle: Text(email),
          onTap:
              () => _launchExternalUrl(
                context,
                Uri(scheme: 'mailto', path: email),
              ),
        ),
      );
    }

    Uri? whatsappUri;
    String? whatsappSubtitle;
    if (whatsappEntry != null) {
      whatsappUri = _tryParseExternalUrl(whatsappEntry.value);
      whatsappSubtitle = whatsappEntry.value;
    }
    if (whatsappUri == null && phone.isNotEmpty) {
      whatsappUri = _buildWhatsAppUri(phone, salon.name);
      whatsappSubtitle = phone;
    }
    Widget? whatsappTile;
    if (whatsappUri != null) {
      final uri = whatsappUri;
      whatsappTile = ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _SalonInfoCircleIcon(
          scheme.primary,
          Icons.chat_rounded,
          assetPath: _whatsappLogoAsset,
        ),
        title: const Text('WhatsApp'),
        subtitle: Text(whatsappSubtitle ?? ''),
        trailing: Icon(Icons.open_in_new_rounded, color: scheme.primary),
        onTap: () => _launchExternalUrl(context, uri),
      );
    }

    final bookingLink = salon.bookingLink?.trim() ?? '';
    final bookingUri = _tryParseExternalUrl(bookingLink);
    if (bookingUri != null) {
      contactTiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SalonInfoCircleIcon(
            scheme.primary,
            Icons.event_available_rounded,
          ),
          title: const Text('Prenotazioni online'),
          subtitle: Text(bookingUri.toString()),
          trailing: Icon(Icons.open_in_new_rounded, color: scheme.primary),
          onTap: () => _launchExternalUrl(context, bookingUri),
        ),
      );
    }

    final cards = <Widget>[];

    if (description != null && description.isNotEmpty) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SalonSectionHeader(
                  icon: Icons.info_rounded,
                  title: 'Chi siamo',
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }
    if (whatsappTile != null) {
      contactTiles.insert(0, whatsappTile);
    }

    if (contactTiles.isNotEmpty) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SalonSectionHeader(
                  icon: Icons.call_rounded,
                  title: 'Contatti principali',
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < contactTiles.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 16,
                      color: scheme.primary.withOpacity(0.08),
                    ),
                  contactTiles[i],
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (locationDescription.isNotEmpty) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SalonSectionHeader(
                  icon: Icons.map_rounded,
                  title: 'Dove trovarci',
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _SalonInfoCircleIcon(
                    scheme.primary,
                    Icons.location_on_rounded,
                    assetPath: _mapsLogoAsset,
                  ),
                  title: const Text('Indirizzo'),
                  subtitle: Text(locationDescription),
                  trailing:
                      mapsUri == null
                          ? null
                          : Icon(
                            Icons.open_in_new_rounded,
                            color: scheme.primary,
                          ),
                  onTap:
                      mapsUri == null
                          ? null
                          : () => _launchExternalUrl(context, mapsUri),
                ),
                if (mapsUri != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _launchExternalUrl(context, mapsUri),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withOpacity(0.85),
                              scheme.primaryContainer.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.map_rounded,
                                color: scheme.onPrimary,
                                size: 64,
                              ),
                            ),
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    color: scheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Apri in Google Maps',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final scheduleRows = _buildScheduleRows(context, salon);
    if (scheduleRows.isNotEmpty) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SalonSectionHeader(
                  icon: Icons.access_time_rounded,
                  title: 'Orari di apertura',
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                ...scheduleRows,
              ],
            ),
          ),
        ),
      );
    }

    final socialIconButtons = <Widget>[];
    for (final entry in socialEntries) {
      final uri = _tryParseExternalUrl(entry.value);
      if (uri == null) {
        continue;
      }
      socialIconButtons.add(
        _SalonSocialIconButton(
          color: scheme.primary,
          label: _displaySocialLabel(entry.key),
          icon: _socialIconFor(entry.key),
          assetPath: _socialAssetFor(entry.key),
          onTap: () => _launchExternalUrl(context, uri),
        ),
      );
    }

    if (socialIconButtons.isNotEmpty) {
      final rowChildren = <Widget>[];
      for (var index = 0; index < socialIconButtons.length; index++) {
        rowChildren.add(socialIconButtons[index]);
        if (index < socialIconButtons.length - 1) {
          rowChildren.add(const SizedBox(width: 12));
        }
      }
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SalonSectionHeader(
                  icon: Icons.public_rounded,
                  title: 'Canali social',
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: rowChildren,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final reviewUri = _buildGoogleReviewUri(salon);
    cards.add(
      Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _SalonReviewCard(
            salonName: salon.name,
            primaryColor: scheme.primary,
            onPrimaryColor: scheme.onPrimaryContainer,
            onOpenReviews: () => _launchExternalUrl(context, reviewUri),
          ),
        ),
      ),
    );

    if (cards.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Non sono ancora disponibili informazioni sul salone. Riprova più tardi.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => cards[index],
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemCount: cards.length,
      ),
    );
  }

  Future<void> _checkoutCart({
    required BuildContext context,
    required Client client,
    required Salon salon,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final cartState = ref.read(cartControllerProvider);
    if (cartState.items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Il carrello è vuoto.')),
      );
      return;
    }

    final stripeAccountId = salon.stripeAccountId;
    if (stripeAccountId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pagamento non disponibile per questo salone.'),
        ),
      );
      return;
    }

    try {
      await ref
          .read(cartControllerProvider.notifier)
          .checkout(
            salonId: salon.id,
            clientId: client.id,
            salonStripeAccountId: stripeAccountId,
            customerId: client.stripeCustomerId,
            additionalMetadata: {
              'origin': 'client_dashboard_cart_tab',
              'itemCount': cartState.items.length,
            },
          );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Pagamento completato con successo.')),
      );
    } on StripePaymentsException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Pagamento non riuscito: ${error.toString()}')),
      );
    }
  }

  Widget _buildNotificationsTab({
    required BuildContext context,
    required List<AppNotification> notifications,
  }) {
    final theme = Theme.of(context);
    final acknowledged =
        _acknowledgedBadgeCounts[_ClientBadgeTarget.notifications] ?? 0;
    if (acknowledged != notifications.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _acknowledgeBadge(
            _ClientBadgeTarget.notifications,
            notifications.length,
          );
        });
      });
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            notifications.isEmpty
                ? Center(
                  child: Text(
                    'Nessuna notifica recente',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
                : ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationCard(notification: notification);
                  },
                ),
      ),
    );
  }

  Future<void> _showNotificationsPage(
    BuildContext context, {
    required List<AppNotification> notifications,
  }) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _acknowledgeBadge(_ClientBadgeTarget.notifications, notifications.length);
    });
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Notifiche'),
              actions: const [ThemeModeAction()],
            ),
            body: _buildNotificationsTab(
              context: routeContext,
              notifications: notifications,
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildScheduleRows(BuildContext context, Salon salon) {
    if (salon.schedule.isEmpty) {
      return const <Widget>[];
    }
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final closedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final scheduleMap = {
      for (final entry in salon.schedule) entry.weekday: entry,
    };
    final rows = <Widget>[];
    for (var index = 0; index < 7; index++) {
      final weekday = DateTime.monday + index;
      final entry = scheduleMap[weekday];
      final isOpen = entry?.isOpen ?? false;
      final range =
          isOpen
              ? _formatScheduleRange(
                localizations,
                entry?.openMinuteOfDay,
                entry?.closeMinuteOfDay,
              )
              : 'Chiuso';
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _weekdayLabel(weekday),
                  style: isOpen ? theme.textTheme.bodyMedium : closedStyle,
                ),
              ),
              Text(
                range,
                style: isOpen ? theme.textTheme.bodyMedium : closedStyle,
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunedì';
      case DateTime.tuesday:
        return 'Martedì';
      case DateTime.wednesday:
        return 'Mercoledì';
      case DateTime.thursday:
        return 'Giovedì';
      case DateTime.friday:
        return 'Venerdì';
      case DateTime.saturday:
        return 'Sabato';
      case DateTime.sunday:
        return 'Domenica';
      default:
        return 'Giorno';
    }
  }

  String _formatScheduleRange(
    MaterialLocalizations localizations,
    int? startMinutes,
    int? endMinutes,
  ) {
    final startLabel = _formatTimeLabel(localizations, startMinutes);
    final endLabel = _formatTimeLabel(localizations, endMinutes);
    if (startLabel == null || endLabel == null) {
      return 'Su appuntamento';
    }
    return '$startLabel - $endLabel';
  }

  String? _formatTimeLabel(MaterialLocalizations localizations, int? minutes) {
    if (minutes == null) {
      return null;
    }
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: true);
  }

  Uri? _buildMapsUri(Salon salon, String locationDescription) {
    if (salon.latitude != null && salon.longitude != null) {
      final query = '${salon.latitude},${salon.longitude}';
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      });
    }
    if (locationDescription.isEmpty) {
      return null;
    }
    final query = locationDescription.replaceAll('\n', ' ');
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  Uri? _buildWhatsAppUri(String phone, String salonName) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) {
      return null;
    }
    final digits =
        normalized.startsWith('+') ? normalized.substring(1) : normalized;
    if (digits.isEmpty) {
      return null;
    }
    final message = Uri.encodeComponent(
      'Ciao ${salonName.trim()}, vorrei prenotare un appuntamento.',
    );
    return Uri.parse('https://wa.me/$digits?text=$message');
  }

  Uri _buildGoogleReviewUri(Salon salon) {
    final raw = salon.googlePlaceId?.trim();
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return Uri.parse(raw);
      }
      return Uri.https('search.google.com', '/local/writereview', {
        'placeid': raw,
      });
    }

    final queryBuffer = StringBuffer(salon.name.trim());
    final city = salon.city.trim();
    if (city.isNotEmpty) {
      queryBuffer
        ..write(' ')
        ..write(city);
    }
    final query = 'Recensioni ${queryBuffer.toString()}';
    return Uri.https('www.google.com', '/search', {'q': query});
  }

  String _normalizeSocialLabel(String rawLabel) {
    final trimmed = rawLabel.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final normalized = trimmed.toLowerCase();
    if (normalized.contains('twitter') ||
        normalized.contains('x.com') ||
        normalized == 'x') {
      return 'Instagram';
    }
    if (normalized == 'instagram') {
      return 'Instagram';
    }
    if (normalized == 'facebook') {
      return 'Facebook';
    }
    if (normalized == 'tiktok') {
      return 'TikTok';
    }
    if (normalized == 'whatsapp') {
      return 'WhatsApp';
    }
    return trimmed;
  }

  String _displaySocialLabel(String label) {
    return _normalizeSocialLabel(label);
  }

  IconData _socialIconFor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('instagram') || normalized.contains('twitter')) {
      return Icons.camera_alt_rounded;
    }
    if (normalized.contains('facebook')) {
      return Icons.facebook;
    }
    if (normalized.contains('tiktok')) {
      return Icons.music_note_rounded;
    }
    if (normalized.contains('youtube')) {
      return Icons.ondemand_video_rounded;
    }
    if (normalized.contains('whatsapp')) {
      return Icons.chat_rounded;
    }
    if (normalized.contains('telegram')) {
      return Icons.send_rounded;
    }
    if (normalized.contains('linkedin')) {
      return Icons.work_outline_rounded;
    }
    if (normalized.contains('pinterest')) {
      return Icons.push_pin_rounded;
    }
    if (normalized.contains('sito') || normalized.contains('website')) {
      return Icons.language_rounded;
    }
    return Icons.language_rounded;
  }

  String? _socialAssetFor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('instagram') || normalized.contains('twitter')) {
      return _instagramLogoAsset;
    }
    if (normalized.contains('facebook')) {
      return _facebookLogoAsset;
    }
    if (normalized.contains('tiktok')) {
      return _tiktokLogoAsset;
    }
    if (normalized.contains('whatsapp')) {
      return _whatsappLogoAsset;
    }
    if (normalized.contains('map')) {
      return _mapsLogoAsset;
    }
    return null;
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]+'), '');
  }

  Uri? _tryParseExternalUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return null;
    }
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$trimmed');
    }
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    return uri;
  }

  Future<void> _launchExternalUrl(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile aprire il link richiesto.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il link: $error')),
      );
    }
  }

  Widget _buildPackagesTabView({
    required BuildContext context,
    required List<ClientPackagePurchase> activePackages,
    required List<ClientPackagePurchase> pastPackages,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _ClientPackagesSection(
          activePackages: activePackages,
          pastPackages: pastPackages,
        ),
      ),
    );
  }

  Widget _buildLoyaltyTab({
    required BuildContext context,
    required Client client,
    required List<Sale> sales,
  }) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final loyaltySales =
        sales
            .where(
              (sale) =>
                  sale.loyalty.resolvedEarnedPoints > 0 ||
                  sale.loyalty.redeemedPoints > 0,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final loyaltyStats = _calculateLoyaltyStats(client, sales);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo utilizzabile', style: _sectionTitleStyle(context)),
                const SizedBox(height: 10),
                Text(
                  '${loyaltyStats.spendable} pt',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    text: 'Punti iniziali: ',
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${loyaltyStats.initialPoints} pt',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'Punti accumulati: ',
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${loyaltyStats.totalEarned} pt',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'Punti utilizzati: ',
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${loyaltyStats.totalRedeemed} pt',
                        style: (theme.textTheme.titleMedium ??
                                const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ))
                            .copyWith(
                              color:
                                  loyaltyStats.totalRedeemed > 0
                                      ? theme.colorScheme.error
                                      : null,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Movimenti recenti', style: _sectionTitleStyle(context)),
        const SizedBox(height: 10),
        if (loyaltySales.isEmpty)
          const Card(
            child: ListTile(title: Text('Non ci sono movimenti registrati.')),
          )
        else
          ...loyaltySales.map((sale) {
            final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
            final summary = sale.loyalty;
            final net = summary.netPoints;
            final icon =
                net >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded;
            final color =
                net >= 0 ? theme.colorScheme.primary : theme.colorScheme.error;
            return Card(
              child: ListTile(
                leading: Icon(icon, color: color),
                title: Text('Vendita del $date'),
                subtitle: Text(
                  'Assegnati: ${summary.resolvedEarnedPoints} • Usati: ${summary.redeemedPoints}\nValore sconto: ${currency.format(summary.redeemedValue)}',
                ),
                trailing: Text(
                  net >= 0 ? '+$net pt' : '$net pt',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBillingTab({
    required BuildContext context,
    required Client client,
    required List<Sale> sales,
    required List<Sale> outstandingSales,
    required List<ClientPackagePurchase> activePackages,
    required List<ClientPackagePurchase> pastPackages,
  }) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final isDark = theme.brightness == Brightness.dark;
    final outstandingAccent = theme.colorScheme.error;
    final outstandingBackground = outstandingAccent.withOpacity(
      isDark ? 0.24 : 0.1,
    );
    final outstandingBorder = outstandingAccent.withOpacity(isDark ? 0.3 : 0.2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (outstandingSales.isNotEmpty) ...[
          Text('Pagamenti da completare', style: _sectionTitleStyle(context)),
          const SizedBox(height: 8),
          ...outstandingSales.map((sale) {
            final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
            final purchaseSummary = _summarizeSaleItems(sale);
            final pointsUsed = sale.loyalty.redeemedPoints;
            return Card(
              color: outstandingBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: outstandingBorder),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: outstandingAccent,
                ),
                title: Text(
                  'Acquisto del $date',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: outstandingAccent,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      purchaseSummary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: outstandingAccent,
                      ),
                    ),
                    if (pointsUsed > 0)
                      Text(
                        'Punti usati: $pointsUsed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: outstandingAccent.withOpacity(0.9),
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(sale.outstandingAmount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: outstandingAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'da saldare',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: outstandingAccent.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                isThreeLine: pointsUsed > 0,
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        Text('Acquisti recenti', style: _sectionTitleStyle(context)),
        const SizedBox(height: 8),
        if (sales.isEmpty)
          const Card(
            child: ListTile(title: Text('Non risultano acquisti registrati')),
          )
        else
          ...sales.map((sale) {
            final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
            final purchaseSummary = _summarizeSaleItems(sale);
            final pointsUsed = sale.loyalty.redeemedPoints;
            final outstanding = sale.outstandingAmount;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: Text('Acquisto del $date'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(purchaseSummary),
                    if (pointsUsed > 0)
                      Text(
                        'Punti usati: $pointsUsed',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                trailing:
                    outstanding > 0
                        ? Text(
                          'Da saldare\n${currency.format(outstanding)}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                        : Text(
                          currency.format(sale.total),
                          style: theme.textTheme.titleMedium,
                        ),
                isThreeLine: pointsUsed > 0,
              ),
            );
          }),
      ],
    );
  }

  String _summarizeSaleItems(Sale sale) {
    final quantityFormat = NumberFormat.decimalPattern('it_IT');
    final descriptions =
        sale.items
            .map((item) {
              final description = item.description.trim();
              if (description.isEmpty) {
                return null;
              }
              final quantity = item.quantity;
              final isSingle = (quantity - 1).abs() < 0.0001;
              if (isSingle) {
                return description;
              }
              final isInteger = (quantity - quantity.round()).abs() < 0.0001;
              final quantityLabel =
                  isInteger
                      ? quantity.round().toString()
                      : quantityFormat.format(quantity);
              return '$quantityLabel × $description';
            })
            .whereType<String>()
            .toList();
    if (descriptions.isEmpty) {
      return 'Dettagli acquisto non disponibili';
    }
    if (descriptions.length <= 3) {
      return descriptions.join(', ');
    }
    final remaining = descriptions.length - 3;
    final othersLabel = remaining == 1 ? 'e un altro' : 'e altri $remaining';
    return '${descriptions.take(3).join(', ')} $othersLabel';
  }

  void _showQuotesSheet(BuildContext context, Client client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom;
        return _wrapClientModal(
          context: sheetContext,
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
          builder: (modalContext) {
            final theme = Theme.of(modalContext);
            final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
            final dateFormat = DateFormat('dd/MM/yyyy');
            final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Consumer(
                builder: (consumerContext, sheetRef, _) {
                  final data = sheetRef.watch(appDataProvider);
                  final salonsById = <String, Salon>{
                    for (final salon in data.salons) salon.id: salon,
                  };
                  final quotes =
                      data.quotes
                          .where((quote) => quote.clientId == client.id)
                          .toList()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'I tuoi preventivi',
                              style: _sectionTitleStyle(modalContext),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (quotes.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              'Non sono disponibili preventivi al momento.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: quotes.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final quote = quotes[index];
                              final salonForQuote = salonsById[quote.salonId];
                              final isProcessing = _processingQuotePayments
                                  .contains(quote.id);
                              final canAcceptOnline =
                                  salonForQuote != null &&
                                  salonForQuote.canAcceptOnlinePayments &&
                                  quote.status == QuoteStatus.sent &&
                                  !quote.isExpired &&
                                  quote.acceptedAt == null &&
                                  quote.declinedAt == null &&
                                  quote.total > 0;
                              final VoidCallback? onAccept =
                                  canAcceptOnline
                                      ? () {
                                        unawaited(
                                          _acceptQuoteWithStripe(
                                            context: sheetContext,
                                            client: client,
                                            quote: quote,
                                            salon: salonForQuote,
                                          ),
                                        );
                                      }
                                      : null;
                              return _buildClientQuoteCard(
                                theme: theme,
                                currency: currency,
                                dateFormat: dateFormat,
                                dateTimeFormat: dateTimeFormat,
                                quote: quote,
                                salon: salonForQuote,
                                isProcessing: isProcessing,
                                onAcceptAndPay: onAccept,
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClientQuoteCard({
    required ThemeData theme,
    required NumberFormat currency,
    required DateFormat dateFormat,
    required DateFormat dateTimeFormat,
    required Quote quote,
    required Salon? salon,
    required bool isProcessing,
    required VoidCallback? onAcceptAndPay,
  }) {
    final isAccepted = quote.status == QuoteStatus.accepted;
    final isDeclined = quote.status == QuoteStatus.declined;
    final isExpired = quote.isExpired && !isAccepted && !isDeclined;
    final statusForBadge = isExpired ? QuoteStatus.expired : quote.status;
    final background = _quoteStatusBackground(statusForBadge, theme);
    final foreground = _quoteStatusForeground(statusForBadge, theme);
    final sentAt = quote.sentAt;
    final validUntil = quote.validUntil;
    final acceptedAt = quote.acceptedAt;
    final declinedAt = quote.declinedAt;
    final canShowPaymentAction =
        onAcceptAndPay != null && !isAccepted && !isDeclined && !isExpired;
    final salonSupportsStripe = salon?.canAcceptOnlinePayments ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quote.title?.isNotEmpty == true
                        ? quote.title!
                        : 'Preventivo ${_quoteLabel(quote)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusForBadge.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (quote.number != null && quote.number!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Numero preventivo: ${quote.number}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Creato il ${dateTimeFormat.format(quote.createdAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (sentAt != null)
              Text(
                'Inviato il ${dateTimeFormat.format(sentAt)}',
                style: theme.textTheme.bodyMedium,
              ),
            if (validUntil != null)
              Text(
                'Validità fino al ${dateFormat.format(validUntil)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: quote.isExpired ? theme.colorScheme.error : null,
                ),
              ),
            if (quote.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(quote.notes!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            ...quote.items.map((item) {
              final quantityLabel =
                  item.quantity == item.quantity.roundToDouble()
                      ? item.quantity.toInt().toString()
                      : item.quantity.toStringAsFixed(2);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$quantityLabel × ${item.description} — '
                  '${currency.format(item.total)}',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              'Totale preventivo: ${currency.format(quote.total)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isExpired) ...[
              const SizedBox(height: 12),
              Text(
                'Questo preventivo è scaduto. Contatta il salone per ricevere una nuova offerta.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (isAccepted && acceptedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Accettato il ${dateTimeFormat.format(acceptedAt)}. In salone troverai un ticket aperto per completare il pagamento.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (isDeclined && declinedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Rifiutato il ${dateTimeFormat.format(declinedAt)}. Puoi sempre richiedere un nuovo preventivo al salone.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (canShowPaymentAction) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: isProcessing ? null : onAcceptAndPay,
                icon:
                    isProcessing
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.credit_card_rounded),
                label: const Text('Accetta e paga'),
              ),
              const SizedBox(height: 8),
              Text(
                salonSupportsStripe
                    ? 'Concludi il pagamento con Stripe per attivare i servizi inclusi.'
                    : 'Il pagamento online sarà attivo non appena il salone completa la configurazione Stripe.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _quoteStatusBackground(QuoteStatus status, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (status) {
      case QuoteStatus.draft:
        return scheme.surfaceContainerHighest;
      case QuoteStatus.sent:
        return scheme.primaryContainer;
      case QuoteStatus.accepted:
        return scheme.secondaryContainer;
      case QuoteStatus.declined:
        return scheme.errorContainer;
      case QuoteStatus.expired:
        return scheme.tertiaryContainer;
    }
  }

  Color _quoteStatusForeground(QuoteStatus status, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (status) {
      case QuoteStatus.draft:
        return scheme.onSurface;
      case QuoteStatus.sent:
        return scheme.onPrimaryContainer;
      case QuoteStatus.accepted:
        return scheme.onSecondaryContainer;
      case QuoteStatus.declined:
        return scheme.onErrorContainer;
      case QuoteStatus.expired:
        return scheme.onTertiaryContainer;
    }
  }

  void _showServicesSheet(
    BuildContext context,
    Client client,
    List<Service> services,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        if (services.isEmpty) {
          return _wrapClientModal(
            context: ctx,
            builder: (modalContext) {
              return const Text('Nessun servizio configurato.');
            },
          );
        }
        final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
        return _wrapClientModal(
          context: ctx,
          builder: (modalContext) {
            final theme = Theme.of(modalContext);
            final maxHeight = MediaQuery.of(modalContext).size.height * 0.65;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servizi del salone',
                  style: _sectionTitleStyle(modalContext),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (itemContext, index) {
                      final service = services[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.08),
                          foregroundColor: theme.colorScheme.primary,
                          child: const Icon(Icons.design_services_rounded),
                        ),
                        title: Text(service.name),
                        subtitle: Text(
                          '${service.duration.inMinutes} minuti • ${currency.format(service.price)}',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openBookingSheet(
                              client,
                              preselectedService: service,
                              overrideContext: ctx,
                            );
                          },
                          child: const Text('Prenota'),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: services.length,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBillingSheet(
    BuildContext context, {
    required Client client,
    required List<Sale> sales,
    required List<Sale> outstandingSales,
    required List<ClientPackagePurchase> activePackages,
    required List<ClientPackagePurchase> pastPackages,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return _wrapClientModal(
          context: sheetContext,
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          builder: (modalContext) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: _buildBillingTab(
                context: modalContext,
                client: client,
                sales: sales,
                outstandingSales: outstandingSales,
                activePackages: activePackages,
                pastPackages: pastPackages,
              ),
            );
          },
        );
      },
    );
  }

  void _showLoyaltySheet(
    BuildContext context, {
    required Client client,
    required List<Sale> sales,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return _wrapClientModal(
          context: sheetContext,
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          builder: (modalContext) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: _buildLoyaltyTab(
                context: modalContext,
                client: client,
                sales: sales,
              ),
            );
          },
        );
      },
    );
  }

  void _showPackagesSheet(
    BuildContext context, {
    required List<ClientPackagePurchase> activePackages,
    required List<ClientPackagePurchase> pastPackages,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return _wrapClientModal(
          context: sheetContext,
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          builder: (modalContext) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: _buildPackagesTabView(
                context: modalContext,
                activePackages: activePackages,
                pastPackages: pastPackages,
              ),
            );
          },
        );
      },
    );
  }

  void _showPhotosSheet(BuildContext context, Client client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return _wrapClientModal(
          context: sheetContext,
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          builder: (modalContext) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: _buildPhotosTab(context: modalContext, client: client),
            );
          },
        );
      },
    );
  }
}

Widget _wrapClientModal({
  required BuildContext context,
  required WidgetBuilder builder,
  EdgeInsetsGeometry? padding,
}) {
  final themedData = ClientTheme.resolve(Theme.of(context));
  return Theme(
    data: themedData,
    child: Container(
      decoration: BoxDecoration(
        color: themedData.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

class ClientPhotosGallery extends ConsumerWidget {
  const ClientPhotosGallery({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final photos = ref.watch(clientPhotosProvider(clientId));
    final sortedPhotos =
        photos.toList()..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    if (sortedPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 72,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Ancora nessuna foto disponibile',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Lo staff potrà condividere qui gli scatti dedicati ai tuoi trattamenti.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Le mie foto', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Rivivi l\'evoluzione dei tuoi trattamenti con la gallery condivisa dal salone.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: sortedPhotos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final photo = sortedPhotos[index];
              return _ClientPhotoCard(photo: photo);
            },
          ),
        ),
      ],
    );
  }
}

class _ClientPhotoCard extends StatelessWidget {
  const _ClientPhotoCard({required this.photo});

  final ClientPhoto photo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'it_IT');
    final fileLabel =
        (photo.fileName != null && photo.fileName!.trim().isNotEmpty)
            ? photo.fileName!.trim()
            : 'Foto condivisa';
    return ListTile(
      onTap: () => _openPreview(context, photo),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        fileLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateFormat.format(photo.uploadedAt.toLocal()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tocca per visualizzare',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context, ClientPhoto photo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final dateFormat = DateFormat('EEEE d MMMM yyyy • HH:mm', 'it_IT');
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    photo.downloadUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateFormat.format(photo.uploadedAt.toLocal()),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (photo.notes != null && photo.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          photo.notes!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Chiudi'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PushTokenRegistrar extends ConsumerStatefulWidget {
  const _PushTokenRegistrar({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_PushTokenRegistrar> createState() =>
      _PushTokenRegistrarState();
}

class _PushTokenRegistrarState extends ConsumerState<_PushTokenRegistrar> {
  StreamSubscription<String>? _subscription;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ensureRegistered();
  }

  Future<void> _ensureRegistered() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final messaging = ref.read(firebaseMessagingProvider);
    try {
      await messaging.setAutoInitEnabled(true);
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await messaging.getToken();
      if (token != null) {
        if (kDebugMode) {
          debugPrint('FCM token (initial): $token');
        }
        await ref
            .read(appDataProvider.notifier)
            .registerClientPushToken(clientId: widget.clientId, token: token);
      }

      _subscription = messaging.onTokenRefresh.listen((freshToken) async {
        if (kDebugMode) {
          debugPrint('FCM token refreshed: $freshToken');
        }
        await ref
            .read(appDataProvider.notifier)
            .registerClientPushToken(
              clientId: widget.clientId,
              token: freshToken,
            );
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'ClientDashboardScreen',
          informationCollector:
              () => [DiagnosticsNode.message('Failed to register FCM token')],
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');
    final referenceDate =
        notification.sentAt ??
        notification.scheduledAt ??
        notification.createdAt;
    final title = notification.title ?? 'Notifica';
    final body =
        notification.body ?? (notification.payload['body'] as String? ?? '');
    final statusLabel = _statusLabel(notification.status);
    final colors = _statusColors(theme, notification.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: colors.background,
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[const SizedBox(height: 8), Text(body)],
            const SizedBox(height: 8),
            Text(
              'Aggiornata il ${dateFormat.format(referenceDate)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'Inviata';
      case 'queued':
        return 'In coda';
      case 'failed':
        return 'Errore';
      case 'skipped':
        return 'Saltata';
      case 'pending':
      default:
        return 'Programmato';
    }
  }

  ({Color background, Color foreground}) _statusColors(
    ThemeData theme,
    String status,
  ) {
    switch (status) {
      case 'sent':
        return (
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
        );
      case 'failed':
        return (
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
        );
      case 'skipped':
        return (
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurfaceVariant,
        );
      case 'queued':
        return (
          background: theme.colorScheme.tertiaryContainer,
          foreground: theme.colorScheme.onTertiaryContainer,
        );
      case 'pending':
      default:
        return (
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurface,
        );
    }
  }
}

class _PromotionsCarousel extends StatelessWidget {
  const _PromotionsCarousel({
    required this.promotions,
    required this.onPromotionTap,
  });

  final List<Promotion> promotions;
  final ValueChanged<Promotion> onPromotionTap;

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) {
      return const SizedBox.shrink();
    }
    final width = MediaQuery.of(context).size.width;
    if (promotions.length == 1) {
      final promotion = promotions.first;
      return SizedBox(
        height: 400,
        child: _PromotionCard(
          promotion: promotion,
          onTap: () => onPromotionTap(promotion),
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final promotion = promotions[index];
          return SizedBox(
            width: width * 0.78,
            child: _PromotionCard(
              promotion: promotion,
              onTap: () => onPromotionTap(promotion),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: promotions.length,
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.promotion, required this.onTap});

  final Promotion promotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: scheme.onPrimaryContainer,
    );
    final endsAt = promotion.endsAt;
    final subtitle = promotion.subtitle;
    final dateLabel =
        endsAt == null ? null : DateFormat('dd/MM', 'it_IT').format(endsAt);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer,
              scheme.primaryContainer.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dateLabel != null)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.onPrimaryContainer.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Fino al $dateLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              Text(
                promotion.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
              if (promotion.tagline != null &&
                  promotion.tagline!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  promotion.tagline!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withOpacity(0.9),
                  ),
                ),
              ],
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Scopri l\'offerta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingPaymentDialog extends StatelessWidget {
  const _ProcessingPaymentDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Elaborazione pagamento...',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Non chiudere l\'app durante il processo.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LastMinuteSlotCard extends StatefulWidget {
  const _LastMinuteSlotCard({
    required this.slot,
    required this.currency,
    required this.countdownText,
    required this.onBook,
  });

  final LastMinuteSlot slot;
  final NumberFormat currency;
  final String countdownText;
  final VoidCallback onBook;

  @override
  State<_LastMinuteSlotCard> createState() => _LastMinuteSlotCardState();
}

class _LastMinuteSlotCardState extends State<_LastMinuteSlotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final dateLabelFormat = DateFormat('EEE d MMM', 'it_IT');
    final timeLabelFormat = DateFormat('HH:mm', 'it_IT');
    final savings = widget.slot.basePrice - widget.slot.priceNow;
    final appointmentDateLabel = _capitalizeWords(
      dateLabelFormat.format(widget.slot.start),
    );
    final appointmentTimeLabel = timeLabelFormat.format(widget.slot.start);
    final operatorName = widget.slot.operatorName ?? 'Operatore da assegnare';
    final operatorInitials = _initials(operatorName);
    final discount = widget.slot.discountPercentage;
    final hasDiscount = discount != null && discount > 0;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0.95, end: 1),
      builder:
          (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
      child: Card(
        elevation: 4,
        shadowColor: scheme.primary.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.slot.serviceName, style: titleStyle),
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available_rounded,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          appointmentDateLabel,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: scheme.primary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.primary,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          appointmentTimeLabel,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: scheme.onPrimary,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasDiscount) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-${discount!.toStringAsFixed(0)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.slot.duration.inMinutes} min',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: operatorName,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Semantics(
                      label: 'Operatore: $operatorName',
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.primary.withOpacity(0.12),
                        child: Text(
                          operatorInitials,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.slot.roomName != null &&
                  widget.slot.roomName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Cabina: ${widget.slot.roomName}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.currency.format(widget.slot.priceNow),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.currency.format(widget.slot.basePrice),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.7,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (savings > 0)
                    Text(
                      'Risparmi ${widget.currency.format(savings)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (widget.slot.loyaltyPoints > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Guadagni ${widget.slot.loyaltyPoints} punti',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              ScaleTransition(
                scale: _pulseAnimation,
                child: FilledButton(
                  onPressed: widget.onBook,
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            const Text('Prenota subito'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Scade tra ${widget.countdownText}',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.right,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary
                                      .withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'Operatore da assegnare') {
      return '?';
    }
    final parts =
        trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }
}

String _capitalizeWords(String value) {
  return value
      .split(' ')
      .map((part) {
        if (part.isEmpty) {
          return part;
        }
        final first = part.substring(0, 1).toUpperCase();
        final rest = part.length > 1 ? part.substring(1) : '';
        return '$first$rest';
      })
      .join(' ');
}

class _LoyaltyStats {
  const _LoyaltyStats({
    required this.initialPoints,
    required this.totalEarned,
    required this.totalRedeemed,
    required this.spendable,
  });

  final int initialPoints;
  final int totalEarned;
  final int totalRedeemed;
  final int spendable;
}

class _AppointmentsList extends StatelessWidget {
  const _AppointmentsList({
    required this.appointments,
    required this.emptyMessage,
    this.onReschedule,
    this.onCancel,
    this.onDelete,
  });

  final List<Appointment> appointments;
  final String emptyMessage;
  final ValueChanged<Appointment>? onReschedule;
  final ValueChanged<Appointment>? onCancel;
  final ValueChanged<Appointment>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: appointments.length,
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _AppointmentCard(
          appointment: appointment,
          onReschedule:
              onReschedule != null ? () => onReschedule!(appointment) : null,
          onCancel: onCancel != null ? () => onCancel!(appointment) : null,
          onDelete: onDelete != null ? () => onDelete!(appointment) : null,
        );
      },
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({
    required this.appointment,
    this.onReschedule,
    this.onCancel,
    this.onDelete,
  });

  final Appointment appointment;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final staff = data.staff.firstWhereOrNull(
      (member) => member.id == appointment.staffId,
    );
    final services =
        appointment.serviceIds
            .map(
              (id) =>
                  data.services.firstWhereOrNull((service) => service.id == id),
            )
            .whereType<Service>()
            .toList();
    final serviceLabel =
        services.isNotEmpty
            ? services.map((service) => service.name).join(' + ')
            : 'Servizio';
    final date = DateFormat(
      'dd/MM/yyyy HH:mm',
      'it_IT',
    ).format(appointment.start);
    final canDelete = _canShowDeleteAction(appointment);
    final showDeleteAction = onDelete != null && canDelete;
    final showCancelAction = onCancel != null && !canDelete;
    final actionsAvailable =
        onReschedule != null || showCancelAction || showDeleteAction;
    final statusIndicator = _statusIndicator(context, appointment.status);
    final theme = Theme.of(context);
    final metadataStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final iconColor = metadataStyle?.color ?? theme.colorScheme.onSurface;
    final staffName = staff?.fullName ?? 'Operatore da definire';
    final staffInitials = _staffInitials(staffName);
    final staffTooltip = staffName;
    const buttonPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                statusIndicator,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceLabel, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  size: 18,
                                  color: iconColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(date, style: metadataStyle),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: staffTooltip,
                            triggerMode: TooltipTriggerMode.tap,
                            child: Semantics(
                              label: 'Operatore: $staffTooltip',
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.12),
                                child: Text(
                                  staffInitials,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actionsAvailable) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onReschedule != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: buttonPadding),
                      onPressed: onReschedule,
                      icon: const Icon(Icons.event_repeat_rounded, size: 18),
                      label: const Text('Ripianifica'),
                    ),
                  if (showCancelAction)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: buttonPadding),
                      onPressed: onCancel,
                      icon: const Icon(Icons.event_busy_rounded, size: 18),
                      label: const Text('Annulla'),
                    ),
                  if (showDeleteAction)
                    IconButton(
                      tooltip: 'Elimina appuntamento',
                      color: theme.colorScheme.error,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canShowDeleteAction(Appointment appointment) {
    final start = appointment.start;
    final now = DateTime.now();
    if (!start.isAfter(now)) {
      return false;
    }
    return start.difference(now) <= const Duration(hours: 12);
  }

  String _staffInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'Operatore da definire') {
      return '?';
    }
    final parts =
        trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  Widget _statusIndicator(BuildContext context, AppointmentStatus status) {
    final visuals = _statusVisuals(context, status);
    return Tooltip(
      message: visuals.label,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: 'Stato appuntamento: ${visuals.label}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: visuals.background,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(visuals.icon, color: visuals.foreground, size: 20),
          ),
        ),
      ),
    );
  }

  _AppointmentStatusVisual _statusVisuals(
    BuildContext context,
    AppointmentStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case AppointmentStatus.scheduled:
        return _AppointmentStatusVisual(
          label: 'Programmato',
          icon: Icons.schedule_rounded,
          foreground: scheme.primary,
          background: scheme.primary.withOpacity(0.12),
        );
      case AppointmentStatus.confirmed:
        return _AppointmentStatusVisual(
          label: 'Confermato',
          icon: Icons.verified_rounded,
          foreground: scheme.secondary,
          background: scheme.secondary.withOpacity(0.12),
        );
      case AppointmentStatus.completed:
        return _AppointmentStatusVisual(
          label: 'Completato',
          icon: Icons.task_alt_rounded,
          foreground: scheme.tertiary,
          background: scheme.tertiary.withOpacity(0.12),
        );
      case AppointmentStatus.cancelled:
        return _AppointmentStatusVisual(
          label: 'Annullato',
          icon: Icons.cancel_rounded,
          foreground: scheme.error,
          background: scheme.error.withOpacity(0.12),
        );
      case AppointmentStatus.noShow:
        return _AppointmentStatusVisual(
          label: 'No show',
          icon: Icons.error_outline_rounded,
          foreground: scheme.error,
          background: scheme.error.withOpacity(0.16),
        );
    }
  }
}

class _AppointmentStatusVisual {
  const _AppointmentStatusVisual({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
}

class _ServicesCarousel extends StatelessWidget {
  const _ServicesCarousel({
    required this.services,
    required this.onBook,
    this.onAddToCart,
  });

  final List<Service> services;
  final ValueChanged<Service> onBook;
  final ValueChanged<Service>? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final cardHeight = onAddToCart == null ? 240.0 : 288.0;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final service = services[index];
          return SizedBox(
            width: 220,
            child: Card(
              child: SizedBox(
                height: cardHeight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description ?? 'Esperienza da provare',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text('${service.duration.inMinutes} minuti'),
                      const SizedBox(height: 4),
                      Text(
                        currency.format(service.price),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () => onBook(service),
                          child: const Text('Prenota'),
                        ),
                      ),
                      if (onAddToCart != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => onAddToCart!(service),
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: const Text('Acquista'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PackagesCarousel extends StatelessWidget {
  const _PackagesCarousel({required this.packages, required this.onAddToCart});

  final List<ServicePackage> packages;
  final ValueChanged<ServicePackage> onAddToCart;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    // Allow extra height when discounts/full price labels are visible to avoid overflow.
    const baseHeight = 320.0;
    final hasExtendedPricing = packages.any(
      (pkg) => pkg.discountPercentage != null || pkg.fullPrice > pkg.price,
    );
    final cardHeight = hasExtendedPricing ? 384.0 : baseHeight;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: packages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final pkg = packages[index];
          final discount = pkg.discountPercentage;
          return SizedBox(
            width: 240,
            child: Card(
              child: SizedBox(
                height: cardHeight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ) ??
                            const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pkg.description ?? 'Pacchetto esclusivo del salone',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (discount != null) ...[
                        Chip(
                          avatar: const Icon(Icons.percent_rounded, size: 16),
                          label: Text('-${discount.toStringAsFixed(0)}%'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        currency.format(pkg.price),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (pkg.fullPrice > pkg.price)
                        Text(
                          currency.format(pkg.fullPrice),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => onAddToCart(pkg),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text('Acquista'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClientPackagesSection extends StatelessWidget {
  const _ClientPackagesSection({
    required this.activePackages,
    required this.pastPackages,
  });

  final List<ClientPackagePurchase> activePackages;
  final List<ClientPackagePurchase> pastPackages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ClientPackageGroup(
          title: 'Pacchetti in corso',
          packages: activePackages,
          isActiveGroup: true,
        ),
        const SizedBox(height: 16),
        _ClientPackageGroup(
          title: 'Pacchetti passati',
          packages: pastPackages,
          isActiveGroup: false,
        ),
      ],
    );
  }
}

class _ClientPackageGroup extends StatelessWidget {
  const _ClientPackageGroup({
    required this.title,
    required this.packages,
    required this.isActiveGroup,
  });

  final String title;
  final List<ClientPackagePurchase> packages;
  final bool isActiveGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final headingStyle = theme.textTheme.titleMedium?.copyWith(
      color:
          isActiveGroup
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
      fontWeight: isActiveGroup ? FontWeight.w600 : FontWeight.w500,
    );
    final emptyCardColor = theme.colorScheme.surfaceVariant;
    final emptyTextColor = theme.colorScheme.onSurfaceVariant;
    final emptyBorderColor = theme.colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: headingStyle),
        const SizedBox(height: 12),
        if (packages.isEmpty)
          Card(
            color: emptyCardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: emptyBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                isActiveGroup
                    ? 'Nessun pacchetto attivo al momento.'
                    : 'Non risultano pacchetti passati.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: emptyTextColor,
                ),
              ),
            ),
          )
        else
          ...packages.map(
            (purchase) => _ClientPackageCard(
              purchase: purchase,
              isActiveGroup: isActiveGroup,
              currency: currency,
              dateFormat: dateFormat,
            ),
          ),
      ],
    );
  }

  static String _paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.pos:
        return 'POS';
      case PaymentMethod.transfer:
        return 'Bonifico';
      case PaymentMethod.giftCard:
        return 'Gift card';
    }
  }

  static String _sessionLabel(ClientPackagePurchase purchase) {
    final remaining = purchase.remainingSessions;
    final total = purchase.totalSessions;
    if (remaining == null && total == null) {
      return 'Sessioni non definite';
    }
    if (total == null) {
      return 'Rimanenti: ${remaining ?? '-'}';
    }
    final remainingLabel = remaining?.toString() ?? '—';
    return '$remainingLabel / $total sessioni rimaste';
  }

  static Widget _packageStatusChip(
    BuildContext context,
    PackagePurchaseStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    TextStyle? labelStyle(Color color) {
      return textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      );
    }

    switch (status) {
      case PackagePurchaseStatus.active:
        return Chip(
          label: Text(status.label),
          labelStyle: labelStyle(scheme.onPrimaryContainer),
          backgroundColor: scheme.primaryContainer,
          side: BorderSide(color: scheme.primary.withOpacity(0.25)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case PackagePurchaseStatus.completed:
        return Chip(
          label: Text(status.label),
          labelStyle: labelStyle(scheme.onSecondaryContainer),
          backgroundColor: scheme.secondaryContainer,
          side: BorderSide(color: scheme.secondary.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case PackagePurchaseStatus.cancelled:
        return Chip(
          label: Text(status.label),
          labelStyle: labelStyle(scheme.onErrorContainer),
          backgroundColor: scheme.errorContainer,
          side: BorderSide(color: scheme.error.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    }
  }
}

class _ClientPackageCard extends StatefulWidget {
  const _ClientPackageCard({
    required this.purchase,
    required this.isActiveGroup,
    required this.currency,
    required this.dateFormat,
  });

  final ClientPackagePurchase purchase;
  final bool isActiveGroup;
  final NumberFormat currency;
  final DateFormat dateFormat;

  @override
  State<_ClientPackageCard> createState() => _ClientPackageCardState();
}

class _ClientPackageCardState extends State<_ClientPackageCard> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final purchase = widget.purchase;
    final currency = widget.currency;

    final cardColor =
        widget.isActiveGroup
            ? theme.cardTheme.color ?? scheme.surface
            : theme.colorScheme.surface;
    final borderColor =
        widget.isActiveGroup
            ? scheme.outlineVariant
            : scheme.primary.withOpacity(0.35);
    final textColor = scheme.onSurface;
    final mutedColor = textColor.withOpacity(0.72);
    final neutralChipBackground =
        widget.isActiveGroup
            ? scheme.surfaceVariant
            : scheme.primary.withOpacity(0.12);
    final neutralChipForeground =
        widget.isActiveGroup ? scheme.onSurfaceVariant : scheme.primary;

    final statusChip = _ClientPackageGroup._packageStatusChip(
      context,
      purchase.status,
    );
    final expiry = purchase.expirationDate;
    final expiryLabel =
        expiry == null
            ? 'Senza scadenza'
            : 'Scadenza: ${widget.dateFormat.format(expiry)}';
    final sessionsLabel = _ClientPackageGroup._sessionLabel(purchase);
    final outstanding = purchase.outstandingAmount;
    final isPaid = outstanding <= 0;
    final paymentLabel =
        isPaid ? 'Saldato' : 'Da saldare ${currency.format(outstanding)}';
    final paymentIcon =
        isPaid ? Icons.verified_rounded : Icons.pending_actions_rounded;
    final paymentForeground = isPaid ? scheme.primary : scheme.error;
    final paymentBackground =
        isPaid
            ? scheme.primary.withOpacity(0.15)
            : scheme.error.withOpacity(0.15);
    final servicesLabel = purchase.serviceNames.join(', ');
    final purchaseDateLabel =
        'Acquisto: ${widget.dateFormat.format(purchase.sale.createdAt)}';
    final depositFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          purchase.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expiryLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      statusChip,
                      const SizedBox(height: 8),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: mutedColor,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PackageSummaryChip(
                    icon: Icons.event_repeat_rounded,
                    label: sessionsLabel,
                    backgroundColor: neutralChipBackground,
                    foregroundColor: neutralChipForeground,
                  ),
                  _PackageSummaryChip(
                    icon: paymentIcon,
                    label: paymentLabel,
                    backgroundColor: paymentBackground,
                    foregroundColor: paymentForeground,
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: borderColor.withOpacity(0.6)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PackageSummaryChip(
                            icon: Icons.calendar_month_rounded,
                            label: purchaseDateLabel,
                            backgroundColor: neutralChipBackground,
                            foregroundColor: neutralChipForeground,
                          ),
                          _PackageSummaryChip(
                            icon: Icons.payments_rounded,
                            label:
                                'Totale: ${currency.format(purchase.totalAmount)}',
                            backgroundColor: neutralChipBackground,
                            foregroundColor: neutralChipForeground,
                          ),
                        ],
                      ),
                      if (servicesLabel.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Servizi inclusi',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          servicesLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                crossFadeState:
                    _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageSummaryChip extends StatelessWidget {
  const _PackageSummaryChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18, color: foregroundColor),
      label: Text(label),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: foregroundColor,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: backgroundColor,
      side: BorderSide(color: foregroundColor.withOpacity(0.2)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

Widget _SalonInfoCircleIcon(Color color, IconData icon, {String? assetPath}) {
  const circleRadius = 20.0;
  const circleIconSize = 24.0;
  const assetIconSize = 40.0;
  if (assetPath != null) {
    return SizedBox(
      width: assetIconSize,
      height: assetIconSize,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
  return CircleAvatar(
    radius: circleRadius,
    backgroundColor: color.withOpacity(0.12),
    child: Icon(icon, color: color, size: circleIconSize),
  );
}

class _SocialPlaceholder {
  const _SocialPlaceholder({
    required this.label,
    required this.matchKey,
    this.icon,
    this.assetPath,
  }) : assert(icon != null || assetPath != null);

  final String label;
  final String matchKey;
  final IconData? icon;
  final String? assetPath;
}

class _SalonSectionHeader extends StatelessWidget {
  const _SalonSectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.textColor,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color? textColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor =
        textColor ??
        theme.textTheme.titleMedium?.color ??
        theme.colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SalonInfoCircleIcon(color, icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: effectiveTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: effectiveTextColor.withOpacity(0.72),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SalonSocialIconButton extends StatelessWidget {
  const _SalonSocialIconButton({
    required this.color,
    required this.label,
    required this.icon,
    this.assetPath,
    required this.onTap,
  });

  final Color color;
  final String label;
  final IconData icon;
  final String? assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget =
        assetPath != null
            ? Image.asset(
              assetPath!,
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            )
            : Icon(icon, color: color, size: 36);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: iconWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalonReviewCard extends StatefulWidget {
  const _SalonReviewCard({
    required this.salonName,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.onOpenReviews,
  });

  final String salonName;
  final Color primaryColor;
  final Color onPrimaryColor;
  final VoidCallback onOpenReviews;

  @override
  State<_SalonReviewCard> createState() => _SalonReviewCardState();
}

class _SalonReviewCardState extends State<_SalonReviewCard> {
  late final TextEditingController _controller;
  int _rating = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setRating(int value) {
    setState(() => _rating = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = widget.onPrimaryColor;
    final accent = widget.primaryColor;
    final hintColor = textColor.withOpacity(0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SalonSectionHeader(
          icon: Icons.star_rate_rounded,
          title: 'Lascia una recensione',
          color: accent,
          textColor: textColor,
          subtitle: 'Condividi la tua esperienza su Google',
        ),
        const SizedBox(height: 12),
        Text(
          'Valuta ${widget.salonName}',
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isFilled = _rating >= starValue;
            return IconButton(
              tooltip: '$starValue stelle',
              onPressed: () => _setRating(starValue),
              icon: Icon(
                isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
              color: accent,
              iconSize: 28,
            );
          }),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          decoration: InputDecoration(
            hintText: 'Scrivi un commento opzionale...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(color: hintColor),
            filled: true,
            fillColor: widget.onPrimaryColor.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Apri Google Reviews'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (_rating == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Seleziona un numero di stelle prima di procedere.',
                    ),
                  ),
                );
                return;
              }
              widget.onOpenReviews();
            },
          ),
        ),
      ],
    );
  }
}

class _ClientDrawerHeader extends StatelessWidget {
  const _ClientDrawerHeader({required this.client, required this.salon});

  final Client client;
  final Salon? salon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final salonName = salon?.name;
    final salonAddress = salon?.address ?? '';
    final salonCity = salon?.city ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: onPrimary.withOpacity(0.12),
            child: Icon(Icons.person_rounded, color: onPrimary, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            'Benvenuto,',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onPrimary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            client.fullName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (salonName != null && salonName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              salonName,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (salonAddress.isNotEmpty || salonCity.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$salonAddress${salonAddress.isNotEmpty && salonCity.isNotEmpty ? ', ' : ''}$salonCity',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onPrimary.withOpacity(0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerNavigationCard extends StatelessWidget {
  const _DrawerNavigationCard({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final int badgeCount;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    Widget leading = CircleAvatar(
      radius: 22,
      backgroundColor: primary.withOpacity(0.08),
      foregroundColor: primary,
      child: Icon(icon),
    );
    if (showBadge && badgeCount > 0) {
      leading = Badge.count(
        count: badgeCount,
        isLabelVisible: true,
        alignment: AlignmentDirectional.topEnd,
        child: leading,
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
