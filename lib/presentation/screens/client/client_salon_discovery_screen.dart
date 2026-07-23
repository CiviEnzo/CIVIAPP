import 'dart:async';

import 'package:collection/collection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:you_book/app/providers.dart';
import 'package:you_book/app/router_constants.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/public_salon.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/domain/entities/user_role.dart';

const _instagramLogoAsset = 'assets/social_logo/instagram.PNG';
const _tiktokLogoAsset = 'assets/social_logo/tiktok.PNG';
const _facebookLogoAsset = 'assets/social_logo/facebook.PNG';
const _whatsappLogoAsset = 'assets/social_logo/whatsapp.PNG';
const _mapsLogoAsset = 'assets/social_logo/maps.PNG';

class ClientSalonDiscoveryScreen extends ConsumerStatefulWidget {
  const ClientSalonDiscoveryScreen({super.key});

  @override
  ConsumerState<ClientSalonDiscoveryScreen> createState() =>
      _ClientSalonDiscoveryScreenState();
}

class _ClientSalonDiscoveryScreenState
    extends ConsumerState<ClientSalonDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _joiningSalonId;
  bool _initialLocationRequestScheduled = false;
  Position? _devicePosition;
  _ClientLocationStatus _locationStatus = _ClientLocationStatus.idle;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialLocationRequestScheduled) {
        return;
      }
      _initialLocationRequestScheduled = true;
      _requestCurrentLocation();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) {
      return;
    }
    setState(() => _searchQuery = next);
  }

  List<_DiscoverableSalonResult> _buildSalonResults(
    List<PublicSalon> salons, {
    Set<String> alwaysVisibleSalonIds = const <String>{},
  }) {
    final rawQuery = _searchQuery.trim();
    final hasQuery = rawQuery.isNotEmpty;
    final query = rawQuery.toLowerCase();
    final phoneQuery = _normalizePhone(rawQuery);
    final position = _devicePosition;

    final results = <_DiscoverableSalonResult>[];
    for (final salon in salons) {
      final isAlwaysVisible = alwaysVisibleSalonIds.contains(salon.id);
      if (!isAlwaysVisible &&
          (!salon.isPublished || salon.status == SalonStatus.archived)) {
        continue;
      }

      final hasAddressAndCoordinates = _hasAddressAndCoordinates(salon);
      final distanceMeters =
          position == null || !_hasValidCoordinates(salon)
              ? null
              : Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                salon.latitude!,
                salon.longitude!,
              );

      final nameRank = _nameMatchRank(salon.name, query);
      final matchesName = hasQuery && nameRank < 4;
      final matchesPhone =
          hasQuery &&
          phoneQuery.isNotEmpty &&
          _normalizePhone(salon.phone).contains(phoneQuery);

      if (hasQuery) {
        if (!isAlwaysVisible && !matchesName && !matchesPhone) {
          continue;
        }
      } else if (!isAlwaysVisible && !hasAddressAndCoordinates) {
        continue;
      }

      results.add(
        _DiscoverableSalonResult(
          salon: salon,
          distanceMeters: distanceMeters,
          matchesName: matchesName,
          matchesPhone: matchesPhone,
          hasAddressAndCoordinates: hasAddressAndCoordinates,
          sortRank:
              isAlwaysVisible
                  ? -1
                  : hasQuery
                  ? (matchesName ? nameRank : 4)
                  : (distanceMeters == null ? 1 : 0),
        ),
      );
    }

    results.sort(_compareSalonResults);
    return List<_DiscoverableSalonResult>.unmodifiable(results);
  }

  int _compareSalonResults(
    _DiscoverableSalonResult a,
    _DiscoverableSalonResult b,
  ) {
    final rankCompare = a.sortRank.compareTo(b.sortRank);
    if (rankCompare != 0) {
      return rankCompare;
    }

    final distanceCompare = _compareNullableDistance(
      a.distanceMeters,
      b.distanceMeters,
    );
    if (distanceCompare != 0) {
      return distanceCompare;
    }

    return a.salon.name.toLowerCase().compareTo(b.salon.name.toLowerCase());
  }

  int _compareNullableDistance(double? a, double? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }

  int _nameMatchRank(String name, String query) {
    if (query.isEmpty) {
      return 4;
    }
    final normalizedName = name.trim().toLowerCase();
    if (normalizedName == query) {
      return 0;
    }
    if (normalizedName.startsWith(query)) {
      return 1;
    }
    if (normalizedName.contains(query)) {
      return 2;
    }
    return 4;
  }

  bool _hasAddressAndCoordinates(PublicSalon salon) {
    return salon.address.trim().isNotEmpty && _hasValidCoordinates(salon);
  }

  bool _hasValidCoordinates(PublicSalon salon) {
    final latitude = salon.latitude;
    final longitude = salon.longitude;
    if (latitude == null || longitude == null) {
      return false;
    }
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _requestCurrentLocation() async {
    if (_searchQuery.trim().isNotEmpty) {
      return;
    }
    final session = ref.read(sessionControllerProvider);
    if (session.user == null || session.requiresEmailVerification) {
      return;
    }
    if (_locationStatus == _ClientLocationStatus.loading) {
      return;
    }

    setState(() {
      _locationStatus = _ClientLocationStatus.loading;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationStatus = _ClientLocationStatus.serviceDisabled;
          _locationMessage = 'Servizi di localizzazione disattivati.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationStatus = _ClientLocationStatus.denied;
          _locationMessage =
              'Autorizza la posizione per vedere prima i saloni piu\' vicini.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _locationStatus = _ClientLocationStatus.deniedForever;
          _locationMessage =
              'La posizione e\' bloccata. Puoi abilitarla dalle impostazioni.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _devicePosition = position;
        _locationStatus = _ClientLocationStatus.ready;
        _locationMessage = null;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationStatus = _ClientLocationStatus.unavailable;
        _locationMessage =
            'Non siamo riusciti a rilevare la posizione. Puoi cercare per nome o telefono.';
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locationStatus = _ClientLocationStatus.unavailable;
        _locationMessage =
            'Posizione non disponibile. Puoi cercare per nome o telefono.';
      });
      debugPrint('Client location lookup failed: $error');
    }
  }

  Future<void> _openLocationSettings() async {
    if (_locationStatus == _ClientLocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final userId = session.uid;
    final requiresEmailVerification = session.requiresEmailVerification;
    final isGuest = user == null || requiresEmailVerification;

    final requests =
        userId == null
            ? const <SalonAccessRequest>[]
            : data.salonAccessRequests
                .where((request) => request.userId == userId)
                .toList(growable: false);

    final rawPendingBySalon = <String, SalonAccessRequest>{
      for (final request in requests.where(
        (request) => request.status == SalonAccessRequestStatus.pending,
      ))
        request.salonId: request,
    };
    final rejectedBySalon = <String, SalonAccessRequest>{
      for (final request in requests.where(
        (request) => request.status == SalonAccessRequestStatus.rejected,
      ))
        request.salonId: request,
    };
    final approvedBySalon = <String, SalonAccessRequest>{
      for (final request in requests.where(
        (request) =>
            request.status == SalonAccessRequestStatus.approved &&
            (request.clientId?.trim().isNotEmpty ?? false),
      ))
        request.salonId: request,
    };

    final approvedSalonIds = <String>{
      ...session.availableSalonIds,
      ...approvedBySalon.keys,
    };
    final pendingBySalon = <String, SalonAccessRequest>{
      for (final entry in rawPendingBySalon.entries)
        if (!approvedSalonIds.contains(entry.key)) entry.key: entry.value,
    };

    final discoverableSalons = data.discoverableSalons;
    final fallbackSalons = data.salons
        .where((salon) => salon.isPublished)
        .map(PublicSalon.fromSalon)
        .toList(growable: false);
    final baseSalons =
        discoverableSalons.isNotEmpty ? discoverableSalons : fallbackSalons;
    final availableSalonsById = <String, PublicSalon>{
      for (final salon in baseSalons) salon.id: salon,
    };
    for (final salon in data.salons) {
      if (approvedSalonIds.contains(salon.id)) {
        availableSalonsById.putIfAbsent(
          salon.id,
          () => PublicSalon.fromSalon(salon),
        );
      }
    }
    final availableSalons = availableSalonsById.values.toList(growable: false);
    final results = _buildSalonResults(
      availableSalons,
      alwaysVisibleSalonIds: approvedSalonIds,
    );
    final hasAnyPublishedSalon = availableSalons.any(
      (salon) => salon.isPublished && salon.status != SalonStatus.archived,
    );
    final hasSalons = results.isNotEmpty;
    final isManualSearch = _searchQuery.trim().isNotEmpty;
    final showLocationBanner =
        _locationStatus != _ClientLocationStatus.ready ||
        isManualSearch ||
        (_locationMessage?.trim().isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(isGuest ? 'Scopri i saloni' : 'Scegli il tuo salone'),
        automaticallyImplyLeading: false,
        actions: [
          if (isGuest) ...[
            TextButton(
              onPressed:
                  () => context.goNamed(
                    'sign_in',
                    queryParameters: const {redirectQueryParam: '/client'},
                  ),
              child: const Text('Accedi'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/register'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Registrati'),
              ),
            ),
          ] else
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _signOut(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGuest
                    ? 'Saloni disponibili su YouBook'
                    : 'Benvenuto${user.displayName != null ? ', ${user.displayName!.split(' ').first}' : ''}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Cerca per nome o telefono',
                  suffixIcon:
                      _searchQuery.isEmpty
                          ? null
                          : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: _searchController.clear,
                          ),
                ),
              ),
              if (showLocationBanner) ...[
                const SizedBox(height: 12),
                _LocationDiscoveryBanner(
                  status: _locationStatus,
                  message: _locationMessage,
                  hasPosition: _devicePosition != null,
                  isManualSearch: isManualSearch,
                  onUseLocation: _requestCurrentLocation,
                  onOpenSettings: _openLocationSettings,
                ),
              ],
              const SizedBox(height: 16),
              if (!hasSalons)
                Expanded(
                  child: Center(
                    child: Text(
                      _emptyMessage(hasAnyPublishedSalon: hasAnyPublishedSalon),
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final salon = result.salon;
                      final isApproved = approvedSalonIds.contains(salon.id);
                      final pendingRequest =
                          isApproved ? null : pendingBySalon[salon.id];
                      final rejectedRequest = rejectedBySalon[salon.id];
                      return _SalonCard(
                        salon: salon,
                        distanceMeters: result.distanceMeters,
                        hasAddressAndCoordinates:
                            result.hasAddressAndCoordinates,
                        isApproved: isApproved,
                        isProcessing: _joiningSalonId == salon.id,
                        pendingRequest: pendingRequest,
                        rejectedRequest: rejectedRequest,
                        isGuest: isGuest,
                        onViewDetails:
                            () => _openSalonDetails(
                              salon: salon,
                              distanceMeters: result.distanceMeters,
                              hasAddressAndCoordinates:
                                  result.hasAddressAndCoordinates,
                              isApproved: isApproved,
                              isProcessing: _joiningSalonId == salon.id,
                              pendingRequest: pendingRequest,
                              rejectedRequest: rejectedRequest,
                              isGuest: isGuest,
                              user: user,
                            ),
                        onRequestAccess:
                            () => _startRequestFlow(context, salon, user),
                        onEnter: () => _enterSalon(salon.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (pendingBySalon.isNotEmpty)
                _StatusInfoBanner(
                  icon: Icons.hourglass_top,
                  color: theme.colorScheme.tertiary,
                  message:
                      'Hai ${pendingBySalon.length} richiesta'
                      '${pendingBySalon.length == 1 ? '' : 'e'} in attesa di approvazione.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSalonDetails({
    required PublicSalon salon,
    required double? distanceMeters,
    required bool hasAddressAndCoordinates,
    required bool isApproved,
    required bool isProcessing,
    required SalonAccessRequest? pendingRequest,
    required SalonAccessRequest? rejectedRequest,
    required bool isGuest,
    required AppUser? user,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (detailsContext) => _PublicSalonDetailsPage(
              salon: salon,
              distanceMeters: distanceMeters,
              hasAddressAndCoordinates: hasAddressAndCoordinates,
              isApproved: isApproved,
              isProcessing: isProcessing,
              pendingRequest: pendingRequest,
              rejectedRequest: rejectedRequest,
              isGuest: isGuest,
              onRequestAccess:
                  () => _startRequestFlow(detailsContext, salon, user),
              onEnter: () => _enterSalon(salon.id),
            ),
      ),
    );
  }

  String _emptyMessage({required bool hasAnyPublishedSalon}) {
    if (_searchQuery.trim().isNotEmpty) {
      return 'Nessun salone corrisponde alla tua ricerca per nome o telefono.';
    }
    if (!hasAnyPublishedSalon) {
      return 'Nessun salone disponibile al momento.';
    }
    return 'Nessun salone con indirizzo disponibile nella lista vicini. Cerca per nome o telefono.';
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Confermi il logout?'),
              content: const Text(
                'Verrai riportato alla schermata di accesso e dovrai reinserire le tue credenziali.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Esci'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    try {
      await performSignOut(ref);
      if (!mounted) {
        return;
      }
      context.go('/');
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text('Logout non riuscito: $error')));
    }
  }

  Future<void> _startRequestFlow(
    BuildContext context,
    PublicSalon salon,
    AppUser? user,
  ) async {
    final session = ref.read(sessionControllerProvider);
    final userId = session.uid;
    if (userId == null) {
      context.goNamed(
        'sign_in',
        queryParameters: const {redirectQueryParam: '/client'},
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final data = ref.read(appDataProvider);
    final registrationDraft = ref.read(clientRegistrationDraftProvider);
    final clients = data.clients;
    Client? existingClient;
    if (user?.clientId != null) {
      existingClient = clients.firstWhereOrNull(
        (client) => client.id == user!.clientId,
      );
    } else if (user?.email != null) {
      existingClient = clients.firstWhereOrNull((client) {
        final candidateEmail = client.email?.trim().toLowerCase();
        return candidateEmail == user!.email?.trim().toLowerCase();
      });
    }

    final initialFirstName =
        registrationDraft?.firstName ??
        existingClient?.firstName ??
        user?.pendingFirstName ??
        _splitName(user?.displayName).$1;
    final initialLastName =
        registrationDraft?.lastName ??
        existingClient?.lastName ??
        user?.pendingLastName ??
        _splitName(user?.displayName).$2;
    final sanitizedExistingPhone =
        existingClient == null || existingClient.phone == '-'
            ? null
            : existingClient.phone;
    final initialPhone =
        registrationDraft?.phone ??
        sanitizedExistingPhone ??
        user?.pendingPhone ??
        '';
    final initialEmail =
        registrationDraft?.email ?? existingClient?.email ?? user?.email ?? '';
    final initialCity = existingClient?.city ?? existingClient?.address ?? '';
    final initialAddress = existingClient?.address ?? '';
    final initialProfession = existingClient?.profession ?? '';
    final initialNotes = existingClient?.notes ?? '';
    final initialReferral = existingClient?.referralSource ?? '';
    final initialBirthDate =
        registrationDraft?.dateOfBirth ??
        existingClient?.dateOfBirth ??
        user?.pendingDateOfBirth;
    final registrationSettings = salon.clientRegistration;

    final requestSent =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) {
            return _SalonAccessRequestSheet(
              salon: salon,
              settings: registrationSettings,
              initialFirstName: initialFirstName,
              initialLastName: initialLastName,
              initialEmail: initialEmail,
              initialPhone: initialPhone,
              initialCity: initialCity,
              initialAddress: initialAddress,
              initialProfession: initialProfession,
              initialReferralSource: initialReferral,
              initialNotes: initialNotes,
              initialBirthDate: initialBirthDate,
              initialClientId: existingClient?.id ?? user?.clientId,
            );
          },
        ) ??
        false;
    if (!requestSent) {
      return;
    }
    if (!mounted) {
      return;
    }
    final messenger = scaffoldMessenger;
    if (messenger == null || !messenger.mounted) {
      return;
    }
    messenger.showAppSnackBar(
      SnackBar(
        content: Text(
          'Richiesta inviata a ${salon.name}. Riceverai una notifica quando verrà approvata.',
        ),
      ),
    );
  }

  Future<void> _enterSalon(String? salonId) async {
    if (salonId == null || salonId.isEmpty) {
      return;
    }
    if (_joiningSalonId != null) {
      if (_joiningSalonId == salonId) {
        return;
      }
      return;
    }
    final rootContext = context;
    if (mounted) {
      setState(() => _joiningSalonId = salonId);
    } else {
      _joiningSalonId = salonId;
    }
    final navigator = Navigator.of(rootContext, rootNavigator: true);
    final overlayContext = navigator.context;
    var loadingDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: overlayContext,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          return const _ProgressDialog(message: 'Sto cambiando salone...');
        },
      ).whenComplete(() => loadingDialogVisible = false),
    );

    void closeLoadingDialog() {
      if (!loadingDialogVisible) {
        return;
      }
      if (!navigator.mounted) {
        loadingDialogVisible = false;
        return;
      }
      if (navigator.canPop()) {
        navigator.pop();
        loadingDialogVisible = false;
      }
    }

    try {
      final sessionController = ref.read(sessionControllerProvider.notifier);
      final sessionState = ref.read(sessionControllerProvider);
      final currentUser = sessionState.user;
      final dataState = ref.read(appDataProvider);
      final clients = dataState.clients;

      Client? targetClient;
      String? targetClientId;
      SalonAccessRequest? approvedRequest;

      final currentClientId = currentUser?.clientId;
      if (currentClientId != null && currentClientId.isNotEmpty) {
        final currentClient = clients.firstWhereOrNull(
          (client) => client.id == currentClientId,
        );
        if (currentClient != null && currentClient.salonId == salonId) {
          targetClient = currentClient;
          targetClientId = currentClient.id;
        }
      }

      targetClient ??= clients.firstWhereOrNull(
        (client) => client.salonId == salonId,
      );
      targetClientId ??= targetClient?.id;

      final selectedEntityId = sessionState.selectedEntityId;
      if ((targetClientId == null || targetClient == null) &&
          selectedEntityId != null &&
          selectedEntityId.isNotEmpty) {
        final selectedClient = clients.firstWhereOrNull(
          (client) => client.id == selectedEntityId,
        );
        if (selectedClient != null && selectedClient.salonId == salonId) {
          targetClient = selectedClient;
          targetClientId = selectedClient.id;
        }
      }

      if (targetClientId == null || targetClientId.isEmpty) {
        approvedRequest = dataState.salonAccessRequests.firstWhereOrNull(
          (request) =>
              request.salonId == salonId &&
              request.status == SalonAccessRequestStatus.approved &&
              (request.clientId?.isNotEmpty ?? false),
        );
        targetClientId = approvedRequest?.clientId;
        if (targetClient == null && targetClientId != null) {
          targetClient = clients.firstWhereOrNull(
            (client) => client.id == targetClientId,
          );
        }
      }

      if (targetClientId == null || targetClientId.isEmpty) {
        sessionController.setUser(null);
        closeLoadingDialog();
        if (!mounted) {
          return;
        }

        final pendingRequest =
            approvedRequest ??
            dataState.salonAccessRequests.firstWhereOrNull(
              (request) =>
                  request.salonId == salonId &&
                  request.status == SalonAccessRequestStatus.approved,
            );

        final message =
            pendingRequest == null
                ? 'Non è stato trovato un profilo cliente attivo per questo salone.'
                : 'Il profilo è in fase di attivazione. Riprova tra qualche istante.';

        await showDialog<void>(
          context: overlayContext,
          useRootNavigator: true,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Profilo non disponibile'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Ok'),
                ),
              ],
            );
          },
        );
        return;
      }

      final resolvedFirstNameFallback =
          targetClient?.firstName ?? approvedRequest?.firstName;
      final resolvedLastNameFallback =
          targetClient?.lastName ?? approvedRequest?.lastName;
      final resolvedEmailFallback =
          targetClient?.email ?? approvedRequest?.email ?? currentUser?.email;
      final resolvedDisplayName = _formatDisplayName(
        resolvedFirstNameFallback,
        resolvedLastNameFallback,
        fallback: currentUser?.displayName,
      );
      final currentUid = currentUser?.uid ?? sessionState.uid;
      if (currentUid == null || currentUid.isEmpty) {
        throw StateError('Profilo utente non disponibile.');
      }

      await _activateSalonAccessOnBackend(
        salonId: salonId,
        clientId: targetClientId,
        displayName: resolvedDisplayName,
        email: resolvedEmailFallback,
      );

      sessionController.setUser(targetClientId);

      if (currentUser != null) {
        final updatedSalonIds = <String>{...currentUser.salonIds, salonId}
          ..removeWhere((value) => value.isEmpty);
        final updatedRoles =
            currentUser.availableRoles.contains(UserRole.client)
                ? currentUser.availableRoles
                : <UserRole>[...currentUser.availableRoles, UserRole.client];
        final updatedUser = currentUser.copyWith(
          role: UserRole.client,
          salonIds: updatedSalonIds.toList(growable: false),
          clientId: targetClientId,
          displayName: resolvedDisplayName,
          email: resolvedEmailFallback ?? currentUser.email,
          availableRoles: updatedRoles,
          pendingSalonId: null,
          pendingFirstName: null,
          pendingLastName: null,
          pendingPhone: null,
          pendingDateOfBirth: null,
        );
        sessionController.updateUser(updatedUser);
      } else if (currentUid.isNotEmpty) {
        final baseUser =
            sessionState.user ??
            AppUser.placeholder(
              currentUid,
              email: resolvedEmailFallback,
              isEmailVerified: true,
            );
        final updatedUser = baseUser.copyWith(
          role: UserRole.client,
          salonIds: <String>[salonId],
          clientId: targetClientId,
          displayName: resolvedDisplayName,
          email: resolvedEmailFallback ?? baseUser.email,
          availableRoles: const <UserRole>[UserRole.client],
          pendingSalonId: null,
          pendingFirstName: null,
          pendingLastName: null,
          pendingPhone: null,
          pendingDateOfBirth: null,
        );
        sessionController.updateUser(updatedUser);
      }

      sessionController.setSalon(salonId);

      ref.invalidate(appDataProvider);
      final store = ref.read(appDataProvider.notifier);
      final dataStream = store.stream;
      await store.reloadActiveSalon();

      try {
        final awaitedState = await dataStream
            .firstWhere(
              (state) =>
                  state.clients.any((client) => client.id == targetClientId),
            )
            .timeout(const Duration(seconds: 8));
        targetClient = awaitedState.clients.firstWhereOrNull(
          (client) => client.id == targetClientId,
        );
      } on TimeoutException {
        // Keep existing fallback data; navigation will continue with loader.
      } catch (_) {
        // Ignore other stream errors and fallback to best effort data.
      }

      if (mounted) {
        final sessionSnapshot = ref.read(sessionControllerProvider);
        final stabilizedUser = sessionSnapshot.user ?? currentUser;
        if (stabilizedUser != null) {
          final resolvedFirstName =
              targetClient?.firstName ?? approvedRequest?.firstName;
          final resolvedLastName =
              targetClient?.lastName ?? approvedRequest?.lastName;
          final resolvedEmail = targetClient?.email ?? approvedRequest?.email;
          final updatedSalonIds = <String>{...stabilizedUser.salonIds, salonId}
            ..removeWhere((value) => value.isEmpty);
          final updatedRoles =
              stabilizedUser.availableRoles.contains(UserRole.client)
                  ? stabilizedUser.availableRoles
                  : <UserRole>[
                    ...stabilizedUser.availableRoles,
                    UserRole.client,
                  ];
          final resolvedDisplayName = _formatDisplayName(
            resolvedFirstName,
            resolvedLastName,
            fallback: stabilizedUser.displayName,
          );
          final updatedUser = stabilizedUser.copyWith(
            role: UserRole.client,
            salonIds: updatedSalonIds.toList(growable: false),
            clientId: targetClientId,
            displayName: resolvedDisplayName,
            email: resolvedEmail ?? stabilizedUser.email,
            availableRoles: updatedRoles,
            pendingSalonId: null,
            pendingFirstName: null,
            pendingLastName: null,
            pendingPhone: null,
            pendingDateOfBirth: null,
          );
          ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
        }
      }

      closeLoadingDialog();
      ref.read(appRouterProvider).go('/client/dashboard');
    } catch (error) {
      closeLoadingDialog();
      if (!mounted) {
        return;
      }
      if (!navigator.mounted) {
        ScaffoldMessenger.maybeOf(rootContext)?.showAppSnackBar(
          SnackBar(content: Text('Cambio salone non riuscito: $error')),
        );
        return;
      }
      await showDialog<void>(
        context: overlayContext,
        useRootNavigator: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cambio salone non riuscito'),
            content: Text(
              'Non è stato possibile attivare il salone selezionato. '
              'Dettagli: $error',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Ok'),
              ),
            ],
          );
        },
      );
    } finally {
      if (_joiningSalonId == salonId) {
        if (mounted) {
          setState(() => _joiningSalonId = null);
        } else {
          _joiningSalonId = null;
        }
      }
    }
  }

  Future<void> _activateSalonAccessOnBackend({
    required String salonId,
    required String clientId,
    String? displayName,
    String? email,
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west3');
    final callable = functions.httpsCallable('activateClientSalon');
    final payload = <String, dynamic>{'salonId': salonId, 'clientId': clientId};
    if (displayName != null && displayName.trim().isNotEmpty) {
      payload['displayName'] = displayName.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }
    try {
      await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      final details =
          error.code == 'permission-denied'
              ? 'permessi insufficienti'
              : error.message ?? error.code;
      throw Exception('Aggiornamento profilo non riuscito ($details).');
    }
  }

  String? _formatDisplayName(
    String? firstName,
    String? lastName, {
    String? fallback,
  }) {
    final parts = <String>[
      if (firstName != null && firstName.trim().isNotEmpty) firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty) lastName.trim(),
    ];
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    final normalizedFallback = fallback?.trim();
    if (normalizedFallback == null || normalizedFallback.isEmpty) {
      return null;
    }
    return normalizedFallback;
  }

  (String, String) _splitName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return ('', '');
    }
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return (parts.first, '');
    }
    return (parts.first, parts.skip(1).join(' '));
  }
}

class _PublicSalonDetailsPage extends StatelessWidget {
  const _PublicSalonDetailsPage({
    required this.salon,
    required this.distanceMeters,
    required this.hasAddressAndCoordinates,
    required this.isApproved,
    required this.isProcessing,
    required this.pendingRequest,
    required this.rejectedRequest,
    required this.isGuest,
    required this.onRequestAccess,
    required this.onEnter,
  });

  final PublicSalon salon;
  final double? distanceMeters;
  final bool hasAddressAndCoordinates;
  final bool isApproved;
  final bool isProcessing;
  final SalonAccessRequest? pendingRequest;
  final SalonAccessRequest? rejectedRequest;
  final bool isGuest;
  final VoidCallback onRequestAccess;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _resolveStatus();
    final cards = _buildCards(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dettagli salone')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => cards[index],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _buildPrimaryAction(context, status),
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }

  List<Widget> _buildCards(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = salon.description?.trim();
    final locationDescription = _locationDescription();
    final mapsUri = _buildMapsUri(locationDescription);
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

    final cards = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      salon.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(status: _resolveStatus()),
                ],
              ),
              if (locationDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                _IconTextLine(
                  icon: Icons.place_outlined,
                  text: locationDescription.replaceAll('\n', ', '),
                ),
              ] else if (!hasAddressAndCoordinates) ...[
                const SizedBox(height: 12),
                const _IconTextLine(
                  icon: Icons.place_outlined,
                  text: 'Indirizzo non disponibile',
                ),
              ],
              if (distanceMeters != null) ...[
                const SizedBox(height: 8),
                _IconTextLine(
                  icon: Icons.near_me_outlined,
                  text: _formatDistance(distanceMeters!),
                ),
              ],
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(description, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    ];

    final contactTiles = <Widget>[];
    final phone = salon.phone.trim();
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
    if (whatsappUri != null) {
      final uri = whatsappUri;
      contactTiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _publicSalonInfoCircleIcon(
            scheme.primary,
            Icons.chat_rounded,
            assetPath: _whatsappLogoAsset,
          ),
          title: const Text('WhatsApp'),
          subtitle: Text(whatsappSubtitle ?? ''),
          trailing: Icon(Icons.open_in_new_rounded, color: scheme.primary),
          onTap: () => _launchExternalUrl(context, uri),
        ),
      );
    }
    if (phone.isNotEmpty) {
      contactTiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _publicSalonInfoCircleIcon(
            scheme.primary,
            Icons.phone_rounded,
          ),
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
          leading: _publicSalonInfoCircleIcon(
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
    final bookingUri = _tryParseExternalUrl(salon.bookingLink?.trim() ?? '');
    if (bookingUri != null) {
      contactTiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _publicSalonInfoCircleIcon(
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
    if (contactTiles.isNotEmpty) {
      cards.add(
        _PublicSalonInfoCard(
          icon: Icons.call_rounded,
          title: 'Contatti principali',
          children: contactTiles,
        ),
      );
    }

    final socialButtons = <Widget>[];
    for (final entry in socialEntries) {
      final uri = _tryParseExternalUrl(entry.value);
      if (uri == null) {
        continue;
      }
      socialButtons.add(
        _PublicSalonSocialIconButton(
          color: scheme.primary,
          label: _displaySocialLabel(entry.key),
          icon: _socialIconFor(entry.key),
          assetPath: _socialAssetFor(entry.key),
          onTap: () => _launchExternalUrl(context, uri),
        ),
      );
    }
    if (socialButtons.isNotEmpty) {
      cards.add(
        _PublicSalonInfoCard(
          icon: Icons.public_rounded,
          title: 'Canali social',
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: socialButtons,
            ),
          ],
        ),
      );
    }

    final scheduleRows = _buildScheduleRows(context);
    if (scheduleRows.isNotEmpty) {
      cards.add(
        _PublicSalonInfoCard(
          icon: Icons.access_time_rounded,
          title: 'Orari di apertura',
          children: scheduleRows,
        ),
      );
    }

    if (locationDescription.isNotEmpty) {
      cards.add(
        _PublicSalonInfoCard(
          icon: Icons.map_rounded,
          title: 'Dove trovarci',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _publicSalonInfoCircleIcon(
                scheme.primary,
                Icons.location_on_rounded,
                assetPath: _mapsLogoAsset,
              ),
              title: const Text('Indirizzo'),
              subtitle: Text(locationDescription),
              trailing:
                  mapsUri == null
                      ? null
                      : Icon(Icons.open_in_new_rounded, color: scheme.primary),
              onTap:
                  mapsUri == null
                      ? null
                      : () => _launchExternalUrl(context, mapsUri),
            ),
          ],
        ),
      );
    }

    if (salon.isPublished &&
        salon.showPublicCatalog &&
        (salon.publicServices.isNotEmpty || salon.publicPackages.isNotEmpty)) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _PublicCatalogPreview(
              services: salon.publicServices,
              packages: salon.publicPackages,
              isGuest: isGuest,
              isApproved: isApproved,
            ),
          ),
        ),
      );
    }

    if (cards.length == 1) {
      cards.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Non sono ancora disponibili altre informazioni pubbliche sul salone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildPrimaryAction(BuildContext context, _CardStatus status) {
    if (status == _CardStatus.approved) {
      return FilledButton.icon(
        onPressed: isProcessing ? null : onEnter,
        icon:
            isProcessing
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.arrow_forward_rounded),
        label: Text(isProcessing ? 'Accesso in corso' : 'Entra nel salone'),
      );
    }
    if (status == _CardStatus.pending) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded),
        label: const Text('Richiesta in elaborazione'),
      );
    }
    return FilledButton.icon(
      onPressed: onRequestAccess,
      icon: Icon(isGuest ? Icons.login_rounded : Icons.send_rounded),
      label: Text(
        isGuest
            ? 'Accedi per richiedere accesso'
            : status == _CardStatus.rejected
            ? 'Invia di nuovo la richiesta'
            : 'Richiedi accesso',
      ),
    );
  }

  _CardStatus _resolveStatus() {
    if (isApproved) {
      return _CardStatus.approved;
    }
    if (pendingRequest != null) {
      return _CardStatus.pending;
    }
    if (rejectedRequest != null) {
      return _CardStatus.rejected;
    }
    return _CardStatus.available;
  }

  String _locationDescription() {
    final lines = <String>[];
    final address = salon.address.trim();
    if (address.isNotEmpty) {
      lines.add(address);
    }
    final city = salon.city.trim();
    if (city.isNotEmpty) {
      lines.add(city);
    }
    return lines.join('\n');
  }

  Uri? _buildMapsUri(String locationDescription) {
    if (salon.latitude != null && salon.longitude != null) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${salon.latitude},${salon.longitude}',
      });
    }
    if (locationDescription.isEmpty) {
      return null;
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': locationDescription.replaceAll('\n', ' '),
    });
  }

  List<Widget> _buildScheduleRows(BuildContext context) {
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
}

class _PublicSalonInfoCard extends StatelessWidget {
  const _PublicSalonInfoCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PublicSalonSectionHeader(
              icon: icon,
              title: title,
              color: scheme.primary,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 16,
                  color: scheme.primary.withValues(alpha: 0.08),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _PublicSalonSectionHeader extends StatelessWidget {
  const _PublicSalonSectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _publicSalonInfoCircleIcon(color, icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconTextLine extends StatelessWidget {
  const _IconTextLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _PublicSalonSocialIconButton extends StatelessWidget {
  const _PublicSalonSocialIconButton({
    required this.color,
    required this.label,
    required this.icon,
    required this.onTap,
    this.assetPath,
  });

  final Color color;
  final String label;
  final IconData icon;
  final String? assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget =
        assetPath != null
            ? Image.asset(
              assetPath!,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            )
            : Icon(icon, color: color, size: 32);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}

Widget _publicSalonInfoCircleIcon(
  Color color,
  IconData icon, {
  String? assetPath,
}) {
  if (assetPath != null) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
  return CircleAvatar(
    radius: 20,
    backgroundColor: color.withValues(alpha: 0.12),
    child: Icon(icon, color: color, size: 24),
  );
}

String _formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  final kilometers = meters / 1000;
  if (kilometers < 10) {
    return '${kilometers.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${kilometers.round()} km';
}

String _normalizePhone(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9+]+'), '');
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
  return uri;
}

Future<void> _launchExternalUrl(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && messenger != null && messenger.mounted) {
    messenger.showAppSnackBar(
      SnackBar(content: Text('Impossibile aprire ${uri.toString()}')),
    );
  }
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
  return null;
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({
    required this.salon,
    required this.distanceMeters,
    required this.hasAddressAndCoordinates,
    required this.isApproved,
    required this.isProcessing,
    required this.pendingRequest,
    required this.rejectedRequest,
    required this.isGuest,
    required this.onViewDetails,
    required this.onRequestAccess,
    required this.onEnter,
  });

  final PublicSalon salon;
  final double? distanceMeters;
  final bool hasAddressAndCoordinates;
  final bool isApproved;
  final bool isProcessing;
  final SalonAccessRequest? pendingRequest;
  final SalonAccessRequest? rejectedRequest;
  final bool isGuest;
  final VoidCallback onViewDetails;
  final VoidCallback onRequestAccess;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitleStyle = theme.textTheme.bodyMedium;
    final status = _resolveStatus();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    salon.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            if (salon.address.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        salon.address,
                        salon.city,
                      ].where((value) => value.trim().isNotEmpty).join(', '),
                      style: subtitleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ] else if (!hasAddressAndCoordinates) ...[
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Indirizzo non disponibile',
                      style: subtitleStyle?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (distanceMeters != null) ...[
              Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatDistance(distanceMeters!),
                      style: subtitleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (salon.phone.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(salon.phone, style: subtitleStyle)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (salon.email.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(salon.email, style: subtitleStyle)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            _PublicCatalogPreview(
              services:
                  salon.isPublished && salon.showPublicCatalog
                      ? salon.publicServices
                      : const <PublicSalonService>[],
              packages:
                  salon.isPublished && salon.showPublicCatalog
                      ? salon.publicPackages
                      : const <PublicSalonPackage>[],
              isGuest: isGuest,
              isApproved: isApproved,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: onViewDetails,
                label: const Text('Dettagli salone'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (status == _CardStatus.approved)
                  Expanded(
                    child: FilledButton(
                      onPressed: isProcessing ? null : onEnter,
                      child:
                          isProcessing
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Accesso in corso'),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.arrow_forward_rounded),
                                  SizedBox(width: 12),
                                  Text('Entra nel salone'),
                                ],
                              ),
                    ),
                  )
                else if (status == _CardStatus.pending)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.hourglass_top_rounded),
                      onPressed: null,
                      label: const Text('Richiesta in elaborazione'),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(
                        isGuest ? Icons.login_rounded : Icons.send_rounded,
                      ),
                      onPressed: onRequestAccess,
                      label: Text(
                        isGuest
                            ? 'Accedi per richiedere accesso'
                            : status == _CardStatus.rejected
                            ? 'Invia di nuovo la richiesta'
                            : 'Richiedi accesso',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _CardStatus _resolveStatus() {
    if (isApproved) {
      return _CardStatus.approved;
    }
    if (pendingRequest != null) {
      return _CardStatus.pending;
    }
    if (rejectedRequest != null) {
      return _CardStatus.rejected;
    }
    return _CardStatus.available;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final kilometers = meters / 1000;
    if (kilometers < 10) {
      return '${kilometers.toStringAsFixed(1).replaceAll('.', ',')} km';
    }
    return '${kilometers.round()} km';
  }
}

class _PublicCatalogPreview extends StatelessWidget {
  const _PublicCatalogPreview({
    required this.services,
    required this.packages,
    required this.isGuest,
    required this.isApproved,
  });

  final List<PublicSalonService> services;
  final List<PublicSalonPackage> packages;
  final bool isGuest;
  final bool isApproved;

  @override
  Widget build(BuildContext context) {
    final hasServices = services.isNotEmpty;
    final hasPackages = packages.isNotEmpty;
    if (!hasServices && !hasPackages) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    const maxPreviewItems = 3;
    final visibleServices = services
        .take(maxPreviewItems)
        .toList(growable: false);
    final remainingPreviewSlots = maxPreviewItems - visibleServices.length;
    final visiblePackages = packages
        .take(remainingPreviewSlots)
        .toList(growable: false);
    final hiddenCount =
        (services.length - visibleServices.length) +
        (packages.length - visiblePackages.length);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Catalogo',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showCatalogSheet(context),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Vedi tutto'),
                ),
              ],
            ),
            if (hasServices) ...[
              const SizedBox(height: 8),
              ...visibleServices.map((service) {
                return _PublicCatalogRow(
                  icon: Icons.spa_outlined,
                  title: service.name,
                  trailing: currency.format(service.price),
                  subtitle: _serviceSubtitle(service),
                );
              }),
            ],
            if (hasPackages) ...[
              const SizedBox(height: 8),
              ...visiblePackages.map((pkg) {
                return _PublicCatalogRow(
                  icon: Icons.local_offer_outlined,
                  title: pkg.name,
                  trailing: currency.format(pkg.price),
                  subtitle: _packageSubtitle(pkg),
                );
              }),
            ],
            if (hiddenCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '+$hiddenCount altri elementi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _serviceSubtitle(PublicSalonService service) {
    final parts = <String>[
      if (service.category.trim().isNotEmpty) service.category.trim(),
      if (service.durationMinutes > 0) '${service.durationMinutes} min',
    ];
    return parts.join(' • ');
  }

  String _packageSubtitle(PublicSalonPackage pkg) {
    final parts = <String>[
      if (pkg.sessionCount != null && pkg.sessionCount! > 0)
        '${pkg.sessionCount} sessioni',
      if (pkg.validDays != null && pkg.validDays! > 0)
        'validita ${pkg.validDays} giorni',
      if (pkg.discountPercentage != null && pkg.discountPercentage! > 0)
        '-${pkg.discountPercentage!.toStringAsFixed(0)}%',
    ];
    return parts.join(' • ');
  }

  void _showCatalogSheet(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    'Catalogo pubblico',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isApproved
                        ? 'Entra nel salone per prenotare o acquistare.'
                        : isGuest
                        ? 'Accedi per prenotare o acquistare.'
                        : 'Richiedi accesso per prenotare o acquistare.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Servizi', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...services.map((service) {
                      return _PublicCatalogSheetTile(
                        icon: Icons.spa_outlined,
                        title: service.name,
                        subtitle: [
                          _serviceSubtitle(service),
                          if (service.description?.trim().isNotEmpty == true)
                            service.description!.trim(),
                        ].where((value) => value.isNotEmpty).join('\n'),
                        price: currency.format(service.price),
                      );
                    }),
                  ],
                  if (packages.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Pacchetti', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...packages.map((pkg) {
                      return _PublicCatalogSheetTile(
                        icon: Icons.local_offer_outlined,
                        title: pkg.name,
                        subtitle: [
                          _packageSubtitle(pkg),
                          if (pkg.description?.trim().isNotEmpty == true)
                            pkg.description!.trim(),
                        ].where((value) => value.isNotEmpty).join('\n'),
                        price: currency.format(pkg.price),
                      );
                    }),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PublicCatalogRow extends StatelessWidget {
  const _PublicCatalogRow({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicCatalogSheetTile extends StatelessWidget {
  const _PublicCatalogSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Text(
          price,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DiscoverableSalonResult {
  const _DiscoverableSalonResult({
    required this.salon,
    required this.distanceMeters,
    required this.matchesName,
    required this.matchesPhone,
    required this.hasAddressAndCoordinates,
    required this.sortRank,
  });

  final PublicSalon salon;
  final double? distanceMeters;
  final bool matchesName;
  final bool matchesPhone;
  final bool hasAddressAndCoordinates;
  final int sortRank;
}

enum _ClientLocationStatus {
  idle,
  loading,
  ready,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

class _LocationDiscoveryBanner extends StatelessWidget {
  const _LocationDiscoveryBanner({
    required this.status,
    required this.message,
    required this.hasPosition,
    required this.isManualSearch,
    required this.onUseLocation,
    required this.onOpenSettings,
  });

  final _ClientLocationStatus status;
  final String? message;
  final bool hasPosition;
  final bool isManualSearch;
  final VoidCallback onUseLocation;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final action = _action();
    final actionCallback =
        _actionOpensSettings ? onOpenSettings : onUseLocation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _leadingIcon(context),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _text(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed:
                  status == _ClientLocationStatus.loading
                      ? null
                      : actionCallback,
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }

  Widget _leadingIcon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (status == _ClientLocationStatus.loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final icon =
        hasPosition
            ? Icons.near_me_rounded
            : status == _ClientLocationStatus.serviceDisabled ||
                status == _ClientLocationStatus.deniedForever
            ? Icons.location_off_rounded
            : Icons.my_location_rounded;
    return Icon(icon, size: 20, color: scheme.onSurfaceVariant);
  }

  String _text() {
    if (isManualSearch) {
      return 'Ricerca manuale attiva: mostriamo risultati per nome o telefono.';
    }
    if (message != null && message!.trim().isNotEmpty) {
      return message!;
    }
    switch (status) {
      case _ClientLocationStatus.ready:
        return '';
      case _ClientLocationStatus.loading:
        return 'Rilevamento posizione in corso...';
      case _ClientLocationStatus.idle:
        return 'Usa la posizione per vedere prima i saloni piu\' vicini.';
      case _ClientLocationStatus.denied:
        return 'Autorizza la posizione per vedere prima i saloni piu\' vicini.';
      case _ClientLocationStatus.deniedForever:
        return 'La posizione e\' bloccata. Puoi abilitarla dalle impostazioni.';
      case _ClientLocationStatus.serviceDisabled:
        return 'Servizi di localizzazione disattivati.';
      case _ClientLocationStatus.unavailable:
        return 'Posizione non disponibile. Puoi cercare per nome o telefono.';
    }
  }

  String? _action() {
    if (isManualSearch || hasPosition) {
      return null;
    }
    switch (status) {
      case _ClientLocationStatus.idle:
      case _ClientLocationStatus.denied:
      case _ClientLocationStatus.unavailable:
        return 'Usa posizione';
      case _ClientLocationStatus.deniedForever:
      case _ClientLocationStatus.serviceDisabled:
        return 'Impostazioni';
      case _ClientLocationStatus.loading:
      case _ClientLocationStatus.ready:
        return null;
    }
  }

  bool get _actionOpensSettings =>
      status == _ClientLocationStatus.deniedForever ||
      status == _ClientLocationStatus.serviceDisabled;
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 20),
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardStatus { available, pending, approved, rejected }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _CardStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Color? background;
    Color? foreground;
    String label;
    IconData icon;

    switch (status) {
      case _CardStatus.available:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        label = 'Disponibile';
        icon = Icons.meeting_room_outlined;
        break;
      case _CardStatus.pending:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        label = 'In attesa';
        icon = Icons.hourglass_bottom_rounded;
        break;
      case _CardStatus.approved:
        background = scheme.primary;
        foreground = scheme.onPrimary;
        label = 'Accesso attivo';
        icon = Icons.verified_rounded;
        break;
      case _CardStatus.rejected:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        label = 'Richiesta respinta';
        icon = Icons.block_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _StatusInfoBanner extends StatelessWidget {
  const _StatusInfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonAccessRequestSheet extends ConsumerStatefulWidget {
  const _SalonAccessRequestSheet({
    required this.salon,
    required this.settings,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialEmail,
    required this.initialPhone,
    required this.initialCity,
    required this.initialAddress,
    required this.initialProfession,
    required this.initialReferralSource,
    required this.initialNotes,
    required this.initialBirthDate,
    this.initialClientId,
  });

  final PublicSalon salon;
  final ClientRegistrationSettings settings;
  final String initialFirstName;
  final String initialLastName;
  final String initialEmail;
  final String initialPhone;
  final String initialCity;
  final String initialAddress;
  final String initialProfession;
  final String initialReferralSource;
  final String initialNotes;
  final DateTime? initialBirthDate;
  final String? initialClientId;

  @override
  ConsumerState<_SalonAccessRequestSheet> createState() =>
      _SalonAccessRequestSheetState();
}

class _SalonAccessRequestSheetState
    extends ConsumerState<_SalonAccessRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _professionController;
  late final TextEditingController _notesController;
  late final TextEditingController _referralController;
  late final TextEditingController _birthDateController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _birthDate;
  String? _gender;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialFirstName);
    _lastNameController = TextEditingController(text: widget.initialLastName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
    final resolvedCity =
        widget.initialCity.isNotEmpty
            ? widget.initialCity
            : (widget.initialAddress.isNotEmpty ? widget.initialAddress : '');
    _cityController = TextEditingController(text: resolvedCity);
    _addressController = TextEditingController(text: widget.initialAddress);
    _professionController = TextEditingController(
      text: widget.initialProfession,
    );
    _notesController = TextEditingController(text: widget.initialNotes);
    _referralController = TextEditingController(
      text: widget.initialReferralSource,
    );
    _birthDateController = TextEditingController(
      text:
          widget.initialBirthDate == null
              ? ''
              : _dateFormat.format(widget.initialBirthDate!),
    );
    _birthDate = widget.initialBirthDate;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    _notesController.dispose();
    _referralController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    final settings = widget.settings;
    final requiresAddress = settings.extraFields.contains(
      ClientRegistrationExtraField.address,
    );
    final requiresProfession = settings.extraFields.contains(
      ClientRegistrationExtraField.profession,
    );
    final requiresReferral = settings.extraFields.contains(
      ClientRegistrationExtraField.referralSource,
    );
    final requiresNotes = settings.extraFields.contains(
      ClientRegistrationExtraField.notes,
    );
    final requiresGender = settings.extraFields.contains(
      ClientRegistrationExtraField.gender,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Richiedi accesso a ${widget.salon.name}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed:
                          _isSubmitting
                              ? null
                              : () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Compila i dati richiesti dal salone. Riceverai una conferma quando l\'accesso sarà approvato.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Inserisci il nome';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Cognome'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Inserisci il cognome';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'Inserisci l\'email';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Email non valida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono (anche WhatsApp)',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Inserisci il numero di telefono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Data di nascita',
                    hintText: 'gg/mm/aaaa',
                  ),
                  readOnly: true,
                  onTap: _pickDateOfBirth,
                ),
                if (requiresGender) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sesso'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Uomo')),
                      DropdownMenuItem(value: 'female', child: Text('Donna')),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Altro/Non specificato'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Campo obbligatorio';
                      }
                      return null;
                    },
                  ),
                ],
                if (requiresAddress) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Città di residenza',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Inserisci la città';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Indirizzo (opzionale)',
                    ),
                  ),
                ],
                if (requiresProfession) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _professionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Professione'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Inserisci la professione';
                      }
                      return null;
                    },
                  ),
                ],
                if (requiresReferral) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _referralController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Come hai conosciuto il salone?',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Campo obbligatorio';
                      }
                      return null;
                    },
                  ),
                ],
                if (requiresNotes) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note per il salone',
                    ),
                    minLines: 2,
                    maxLines: 4,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Campo obbligatorio';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon:
                      _isSubmitting
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send_rounded),
                  onPressed: _isSubmitting ? null : _submit,
                  label: Text(
                    _isSubmitting ? 'Invio in corso...' : 'Invia richiesta',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final initialDate =
        _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 25));
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _birthDate = selected;
      _birthDateController.text = _dateFormat.format(selected);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final session = ref.read(sessionControllerProvider);
    final user = session.user;
    final userId = session.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Sessione scaduta. Accedi nuovamente per proseguire.'),
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final extraData = <String, dynamic>{};
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();
    if (city.isNotEmpty) {
      extraData['city'] = city;
    }
    if (address.isNotEmpty) {
      extraData['address'] = address;
    }
    if (_gender != null && _gender!.trim().isNotEmpty) {
      extraData['gender'] = _gender!.trim();
    }
    if (_professionController.text.trim().isNotEmpty) {
      extraData['profession'] = _professionController.text.trim();
    }
    if (_referralController.text.trim().isNotEmpty) {
      extraData['referralSource'] = _referralController.text.trim();
    }
    if (_notesController.text.trim().isNotEmpty) {
      extraData['notes'] = _notesController.text.trim();
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(appDataProvider.notifier)
          .submitSalonAccessRequest(
            salonId: widget.salon.id,
            userId: userId,
            clientId: widget.initialClientId ?? user?.clientId,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            dateOfBirth: _birthDate,
            extraData: extraData,
          );

      final authRepo = ref.read(authRepositoryProvider);
      final currentRole = user?.role ?? UserRole.client;
      await authRepo.completeUserProfile(
        role: currentRole,
        salonIds: user?.salonIds ?? const [],
        staffId: user?.staffId,
        clientId: user?.clientId,
        displayName:
            '$firstName $lastName'.trim().isEmpty
                ? user?.displayName
                : '$firstName $lastName',
      );

      if (user != null) {
        final updatedRoles =
            user.availableRoles.contains(currentRole)
                ? user.availableRoles
                : <UserRole>[...user.availableRoles, currentRole];
        final updatedUser = user.copyWith(
          role: currentRole,
          salonIds: user.salonIds,
          staffId: user.staffId,
          clientId: user.clientId,
          displayName:
              '$firstName $lastName'.trim().isEmpty
                  ? user.displayName
                  : '$firstName $lastName',
          email: email,
          availableRoles: updatedRoles,
          pendingSalonId: widget.salon.id,
          pendingFirstName: firstName,
          pendingLastName: lastName,
          pendingPhone: phone,
          pendingDateOfBirth: _birthDate,
        );
        ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
      }
      ref.read(clientRegistrationDraftProvider.notifier).clear();

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile inviare la richiesta: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
