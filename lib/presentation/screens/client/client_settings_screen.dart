import 'dart:async';
import 'dart:convert';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/presentation/screens/client/client_theme.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientSettingsScreen extends ConsumerStatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  ConsumerState<ClientSettingsScreen> createState() =>
      _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends ConsumerState<ClientSettingsScreen> {
  static const String _notificationPrefsKeyPrefix =
      'client_settings_notifications';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  Client? _lastSyncedClient;
  bool _hasUserEditedProfile = false;
  bool _isSavingProfile = false;
  bool _isSendingReset = false;
  bool _reminderNotificationsEnabled = true;
  bool _promotionsNotificationsEnabled = true;
  bool _lastMinuteNotificationsEnabled = true;
  String? _notificationPrefsUserId;
  bool _notificationPrefsLoaded = false;
  SharedPreferences? _notificationPreferences;

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController()..addListener(_onProfileFieldChanged);
    _lastNameController =
        TextEditingController()..addListener(_onProfileFieldChanged);
    _phoneController =
        TextEditingController()..addListener(_onProfileFieldChanged);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onProfileFieldChanged() {
    if (!_hasUserEditedProfile && mounted) {
      setState(() {
        _hasUserEditedProfile = true;
      });
    }
  }

  Future<SharedPreferences> _ensureNotificationPrefs() async {
    final cached = _notificationPreferences;
    if (cached != null) {
      return cached;
    }
    final resolved = await SharedPreferences.getInstance();
    _notificationPreferences = resolved;
    return resolved;
  }

  String _notificationPrefsKey(String userId) {
    return '$_notificationPrefsKeyPrefix::$userId';
  }

  void _requestNotificationPrefs(String? userId) {
    if (userId == null || userId.isEmpty) {
      final needsReset =
          _notificationPrefsUserId != null ||
          !_notificationPrefsLoaded ||
          !_reminderNotificationsEnabled ||
          !_promotionsNotificationsEnabled ||
          !_lastMinuteNotificationsEnabled;
      if (!needsReset) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _notificationPrefsUserId = null;
          _notificationPrefsLoaded = true;
          _reminderNotificationsEnabled = true;
          _promotionsNotificationsEnabled = true;
          _lastMinuteNotificationsEnabled = true;
        });
      });
      return;
    }

    if (_notificationPrefsUserId == userId && _notificationPrefsLoaded) {
      return;
    }

    _notificationPrefsUserId = userId;
    _notificationPrefsLoaded = false;
    Future.microtask(() => _restoreNotificationPrefs(userId));
  }

  Future<void> _restoreNotificationPrefs(String userId) async {
    SharedPreferences prefs;
    try {
      prefs = await _ensureNotificationPrefs();
    } catch (_) {
      if (!mounted || _notificationPrefsUserId != userId) {
        return;
      }
      setState(() {
        _notificationPrefsLoaded = true;
        _reminderNotificationsEnabled = true;
        _promotionsNotificationsEnabled = true;
        _lastMinuteNotificationsEnabled = true;
      });
      return;
    }

    final raw = prefs.getString(_notificationPrefsKey(userId));
    if (!mounted || _notificationPrefsUserId != userId) {
      return;
    }

    if (raw == null || raw.isEmpty) {
      setState(() {
        _notificationPrefsLoaded = true;
        _reminderNotificationsEnabled = true;
        _promotionsNotificationsEnabled = true;
        _lastMinuteNotificationsEnabled = true;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      bool _resolve(dynamic value, bool fallback) {
        if (value is bool) {
          return value;
        }
        if (value is num) {
          return value != 0;
        }
        if (value is String) {
          final lower = value.toLowerCase().trim();
          if (lower == 'true' || lower == '1') {
            return true;
          }
          if (lower == 'false' || lower == '0') {
            return false;
          }
        }
        return fallback;
      }

      if (decoded is Map<String, dynamic>) {
        setState(() {
          _notificationPrefsLoaded = true;
          _reminderNotificationsEnabled = _resolve(decoded['reminder'], true);
          _promotionsNotificationsEnabled = _resolve(
            decoded['promotions'],
            true,
          );
          _lastMinuteNotificationsEnabled = _resolve(
            decoded['lastMinute'],
            true,
          );
        });
        return;
      }
    } catch (_) {
      // Fall through to reset below.
    }

    setState(() {
      _notificationPrefsLoaded = true;
      _reminderNotificationsEnabled = true;
      _promotionsNotificationsEnabled = true;
      _lastMinuteNotificationsEnabled = true;
    });
  }

  Future<void> _persistNotificationPrefs() async {
    final userId = _notificationPrefsUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final prefs = await _ensureNotificationPrefs();
      final payload = jsonEncode({
        'reminder': _reminderNotificationsEnabled,
        'promotions': _promotionsNotificationsEnabled,
        'lastMinute': _lastMinuteNotificationsEnabled,
      });
      await prefs.setString(_notificationPrefsKey(userId), payload);
    } catch (_) {
      // Ignored: preferenze opzionali.
    }
  }

  void _updateNotificationPrefs({
    bool? reminder,
    bool? promotions,
    bool? lastMinute,
  }) {
    setState(() {
      if (reminder != null) {
        _reminderNotificationsEnabled = reminder;
      }
      if (promotions != null) {
        _promotionsNotificationsEnabled = promotions;
      }
      if (lastMinute != null) {
        _lastMinuteNotificationsEnabled = lastMinute;
      }
      _notificationPrefsLoaded = true;
    });
    unawaited(_persistNotificationPrefs());
  }

  void _syncControllersFromClient(Client? client) {
    if (client == null) {
      return;
    }

    final isDifferentClient = _lastSyncedClient?.id != client.id;
    if (!isDifferentClient && _hasUserEditedProfile) {
      return;
    }

    final alreadySynced =
        !isDifferentClient &&
        _firstNameController.text == client.firstName &&
        _lastNameController.text == client.lastName &&
        _phoneController.text == client.phone;
    if (alreadySynced) {
      _lastSyncedClient = client;
      return;
    }

    _firstNameController.value = TextEditingValue(
      text: client.firstName,
      selection: TextSelection.collapsed(offset: client.firstName.length),
    );
    _lastNameController.value = TextEditingValue(
      text: client.lastName,
      selection: TextSelection.collapsed(offset: client.lastName.length),
    );
    _phoneController.value = TextEditingValue(
      text: client.phone,
      selection: TextSelection.collapsed(offset: client.phone.length),
    );
    _lastSyncedClient = client;
    _hasUserEditedProfile = false;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final themeController = ref.read(themeModeProvider.notifier);
    final isDarkMode = themeMode == ThemeMode.dark;

    final session = ref.watch(sessionControllerProvider);
    final clients = ref.watch(appDataProvider.select((state) => state.clients));
    final currentClient = clients.firstWhereOrNull(
      (client) => client.id == session.userId,
    );
    _syncControllersFromClient(currentClient);
    _requestNotificationPrefs(session.userId);

    final themedData = ClientTheme.resolve(Theme.of(context));

    return Theme(
      data: themedData,
      child: Builder(
        builder: (themedContext) {
          final theme = Theme.of(themedContext);
          final email = currentClient?.email ?? session.user?.email;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Impostazioni'),
              centerTitle: true,
            ),
            body:
                currentClient == null
                    ? _MissingProfileState(theme: theme)
                    : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      children: [
                        Text(
                          'Personalizza la tua esperienza',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 20),
                        Card(
                          child: SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            secondary: _SettingsIconAvatar(
                              icon:
                                  isDarkMode
                                      ? Icons.dark_mode_rounded
                                      : Icons.light_mode_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              'Tema scuro',
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: const Text(
                              'Attiva il tema scuro dell\'app clienti',
                            ),
                            value: isDarkMode,
                            onChanged: themeController.setDarkEnabled,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(
                                0.15,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Notifiche',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSecondaryContainer,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Scegli quali aggiornamenti ricevere dall\'app.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSecondaryContainer
                                                      .withOpacity(0.85),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.notifications_rounded,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer
                                          .withOpacity(0.9),
                                    ),
                                  ],
                                ),
                              ),
                              _NotificationPreferenceTile(
                                icon: Icons.alarm_rounded,
                                iconColor: theme.colorScheme.primary,
                                title: 'Reminder appuntamenti',
                                subtitle:
                                    'Ricevi aggiornamenti prima dei tuoi appuntamenti',
                                value: _reminderNotificationsEnabled,
                                onChanged:
                                    (value) => _updateNotificationPrefs(
                                      reminder: value,
                                    ),
                                isFirst: true,
                              ),
                              _NotificationPreferenceTile(
                                icon: Icons.local_offer_rounded,
                                iconColor: theme.colorScheme.tertiary,
                                title: 'Promozioni',
                                subtitle: 'Scopri in anticipo offerte e novità',
                                value: _promotionsNotificationsEnabled,
                                onChanged:
                                    (value) => _updateNotificationPrefs(
                                      promotions: value,
                                    ),
                              ),
                              _NotificationPreferenceTile(
                                icon: Icons.flash_on_rounded,
                                iconColor: theme.colorScheme.secondary,
                                title: 'Last minute',
                                subtitle:
                                    'Ricevi occasioni last minute disponibili',
                                value: _lastMinuteNotificationsEnabled,
                                onChanged:
                                    (value) => _updateNotificationPrefs(
                                      lastMinute: value,
                                    ),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Le tue informazioni',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _firstNameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Inserisci il tuo nome';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _lastNameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Cognome',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Inserisci il tuo cognome';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _phoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Numero di telefono',
                                    ),
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      final trimmed = value?.trim() ?? '';
                                      if (trimmed.isEmpty) {
                                        return 'Inserisci il tuo numero di telefono';
                                      }
                                      if (trimmed.length < 6) {
                                        return 'Numero di telefono non valido';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    icon:
                                        _isSavingProfile
                                            ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      theme
                                                          .colorScheme
                                                          .onPrimary,
                                                    ),
                                              ),
                                            )
                                            : const Icon(Icons.save_rounded),
                                    label: Text(
                                      _isSavingProfile
                                          ? 'Salvataggio...'
                                          : 'Salva modifiche',
                                    ),
                                    onPressed:
                                        _isSavingProfile ||
                                                currentClient == null
                                            ? null
                                            : _hasUserEditedProfile
                                            ? () => _saveProfile(
                                              themedContext,
                                              currentClient,
                                            )
                                            : null,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            leading: _SettingsIconAvatar(
                              icon: Icons.lock_reset_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            title: const Text('Reimposta password'),
                            subtitle: Text(
                              email != null
                                  ? 'Invia un link a $email'
                                  : 'Aggiungi un indirizzo email per reimpostare la password',
                            ),
                            trailing:
                                _isSendingReset
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.chevron_right_rounded),
                            onTap:
                                email == null
                                    ? null
                                    : () => _sendPasswordReset(
                                      themedContext,
                                      email,
                                    ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            leading: _SettingsIconAvatar(
                              icon: Icons.logout_rounded,
                              color: theme.colorScheme.error,
                              backgroundOpacity: 0.18,
                            ),
                            title: const Text('Esci'),
                            subtitle: const Text(
                              'Disconnettiti dal tuo account',
                            ),
                            onTap: () async {
                              await ref.read(authRepositoryProvider).signOut();
                              if (!mounted) {
                                return;
                              }
                              Navigator.of(themedContext).pop();
                            },
                          ),
                        ),
                      ],
                    ),
          );
        },
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context, Client client) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() {
      _isSavingProfile = true;
    });

    final updatedClient = client.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );

    try {
      await ref.read(appDataProvider.notifier).upsertClient(updatedClient);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingProfile = false;
        _hasUserEditedProfile = false;
        _lastSyncedClient = updatedClient;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informazioni aggiornate con successo')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossibile aggiornare i dati: ${error.toString()}'),
        ),
      );
    }
  }

  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    setState(() {
      _isSendingReset = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(email.trim());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ti abbiamo inviato un link a $email')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invio email non riuscito: ${error.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingReset = false;
        });
      }
    }
  }
}

class _MissingProfileState extends StatelessWidget {
  const _MissingProfileState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Non riusciamo a caricare le tue informazioni in questo momento. Riprova più tardi.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _NotificationPreferenceTile extends StatelessWidget {
  const _NotificationPreferenceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(20) : Radius.zero,
      bottom: isLast ? const Radius.circular(20) : Radius.zero,
    );

    return Column(
      children: [
        if (!isFirst)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: colorScheme.outline.withOpacity(0.12),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _SettingsIconAvatar(
                    icon: icon,
                    color: iconColor,
                    backgroundOpacity:
                        theme.brightness == Brightness.dark ? 0.25 : 0.15,
                    radius: 20,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: iconColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsIconAvatar extends StatelessWidget {
  const _SettingsIconAvatar({
    required this.icon,
    required this.color,
    this.backgroundOpacity = 0.14,
    this.radius = 22,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color color;
  final double backgroundOpacity;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(backgroundOpacity),
      foregroundColor: color,
      child: Icon(icon, size: iconSize),
    );
  }
}
