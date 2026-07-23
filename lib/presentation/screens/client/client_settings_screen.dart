import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/presentation/common/app_feedback_dialog.dart';
import 'package:you_book/presentation/common/app_version_badge.dart';
import 'package:you_book/presentation/screens/client/client_theme.dart';

class ClientSettingsScreen extends ConsumerStatefulWidget {
  const ClientSettingsScreen({super.key});

  @override
  ConsumerState<ClientSettingsScreen> createState() =>
      _ClientSettingsScreenState();
}

class _ClientSettingsScreenState extends ConsumerState<ClientSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  Client? _lastSyncedClient;
  bool _hasUserEditedProfile = false;
  bool _isSavingProfile = false;
  bool _isSendingReset = false;
  bool _isSigningOut = false;
  bool _isLeavingSalon = false;
  bool _preparingSalonSwitch = false;

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
    final salons = ref.watch(appDataProvider.select((state) => state.salons));
    final currentClient = clients.firstWhereOrNull(
      (client) => client.id == session.userId,
    );
    _syncControllersFromClient(currentClient);

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
            body: Stack(
              children: [
                Positioned.fill(
                  child:
                      currentClient == null
                          ? _MissingProfileState(theme: theme)
                          : ListView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
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
                              _SettingsActionTile(
                                icon: Icons.storefront_rounded,
                                color: theme.colorScheme.primary,
                                title: 'Cambia salone',
                                subtitle:
                                    session.salonId == null
                                        ? 'Nessun salone attivo'
                                        : 'Salone attuale: ${salons.firstWhereOrNull((salon) => salon.id == session.salonId)?.name ?? session.salonId}',
                                trailing:
                                    _preparingSalonSwitch
                                        ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                onTap:
                                    _preparingSalonSwitch
                                        ? null
                                        : () => _handleSalonSwitch(
                                          themedContext,
                                          session,
                                        ),
                              ),
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    24,
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Le tue informazioni',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
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
                                                  : const Icon(
                                                    Icons.save_rounded,
                                                  ),
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
                                            minimumSize: const Size.fromHeight(
                                              48,
                                            ),
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
                                          : const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
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
                              _SettingsActionTile(
                                icon: Icons.star_rate_rounded,
                                color: theme.colorScheme.tertiary,
                                title: 'Valuta l\'app',
                                subtitle:
                                    'Apri la pagina store ufficiale di You Book',
                                onTap: () => _rateApp(themedContext),
                              ),
                              const SizedBox(height: 16),
                              _SettingsActionTile(
                                icon: Icons.feedback_rounded,
                                color: theme.colorScheme.secondary,
                                title: 'Invia feedback app',
                                subtitle:
                                    'Segnala un problema o proponi un miglioramento',
                                onTap:
                                    () => showAppFeedbackDialog(
                                      themedContext,
                                      ref,
                                      source: 'client_settings',
                                    ),
                              ),
                              const SizedBox(height: 16),
                              _SettingsActionTile(
                                icon: Icons.tips_and_updates_rounded,
                                color: theme.colorScheme.primary,
                                title: 'Rivedi walkthrough',
                                subtitle:
                                    'Mostra di nuovo la guida rapida dell\'app clienti',
                                onTap:
                                    () =>
                                        _replayClientWalkthrough(themedContext),
                              ),
                              const SizedBox(height: 16),
                              _SettingsActionTile(
                                icon: Icons.logout_rounded,
                                color: theme.colorScheme.primary,
                                title: 'Scollegati',
                                subtitle:
                                    'Esci dal tuo account su questo dispositivo',
                                trailing:
                                    _isSigningOut
                                        ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : null,
                                onTap:
                                    _isSigningOut
                                        ? null
                                        : () => _signOut(themedContext),
                              ),
                              const SizedBox(height: 12),
                              _SettingsActionTile(
                                icon: Icons.delete_forever_rounded,
                                color: theme.colorScheme.error,
                                title: 'Eliminazione account',
                                subtitle:
                                    'Conferma la cancellazione del tuo account YouBook',
                                onTap:
                                    () =>
                                        _openAccountDeletionFlow(themedContext),
                              ),
                            ],
                          ),
                ),
                const AppVersionBadge(),
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Informazioni aggiornate con successo')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingProfile = false;
      });
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Impossibile aggiornare i dati: ${error.toString()}'),
        ),
      );
    }
  }

  Future<void> _rateApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final launched = await ref
        .read(appRatingServiceProvider)
        .openStoreListing(source: 'client_settings');
    if (!mounted || launched) {
      return;
    }
    messenger.showAppSnackBar(
      const SnackBar(content: Text('Impossibile aprire lo store.')),
    );
  }

  void _replayClientWalkthrough(BuildContext context) {
    ref
        .read(clientDashboardIntentProvider.notifier)
        .state = const ClientDashboardIntent(
      tabIndex: 0,
      payload: {'type': 'client_walkthrough', 'source': 'client_settings'},
    );
    unawaited(Navigator.of(context).maybePop());
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Ti abbiamo inviato un link a $email')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
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

  void _openAccountDeletionFlow(BuildContext context) {
    GoRouter.of(context).go('/eliminazione-account');
  }

  Future<void> _signOut(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
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

    setState(() {
      _isSigningOut = true;
    });

    try {
      await performSignOut(ref);
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      scaffoldMessenger.showAppSnackBar(
        SnackBar(content: Text('Logout non riuscito: $error')),
      );
      setState(() {
        _isSigningOut = false;
      });
    }
  }

  Future<void> _handleSalonSwitch(
    BuildContext context,
    SessionState session,
  ) async {
    if (_preparingSalonSwitch) {
      return;
    }
    final uid = session.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Accesso non valido. Riprova.')),
      );
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Vuoi cambiare salone?'),
              content: const Text(
                'Verrai reindirizzato alla lista dei saloni per scegliere quello attivo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Continua'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    if (mounted) {
      setState(() => _preparingSalonSwitch = true);
    } else {
      _preparingSalonSwitch = true;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    final overlayContext = navigator.context;
    var loaderVisible = true;
    unawaited(
      showDialog<void>(
        context: overlayContext,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          return const _SettingsProgressDialog(
            message: 'Caricamento saloni in corso...',
          );
        },
      ).whenComplete(() => loaderVisible = false),
    );

    void closeLoader() {
      if (!loaderVisible) {
        return;
      }
      if (!navigator.mounted) {
        loaderVisible = false;
        return;
      }
      if (navigator.canPop()) {
        navigator.pop();
        loaderVisible = false;
      }
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(uid).get();
      final data = userDoc.data();
      if (data != null) {
        final updatedUser = AppUser.fromMap(uid, data);
        ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
      }

      ref.invalidate(appDataProvider);
      await ref.read(appDataProvider.notifier).reloadActiveSalon();
      closeLoader();
      if (!mounted) {
        return;
      }
      GoRouter.of(context).go('/client');
    } catch (error) {
      closeLoader();
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _preparingSalonSwitch = false);
      } else {
        _preparingSalonSwitch = false;
      }
    }
  }

  Future<void> _confirmLeaveSalon(
    BuildContext context,
    Client? currentClient,
  ) async {
    final session = ref.read(sessionControllerProvider);
    final user = session.user;
    final salonId = session.salonId;
    if (user == null || salonId == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Nessun salone associato all\'account.')),
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Vuoi lasciare il salone?'),
              content: const Text(
                'Potrai scegliere un nuovo salone dalla schermata iniziale dei clienti. Confermi di voler proseguire?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    setState(() => _isLeavingSalon = true);
    final router = GoRouter.of(context);

    try {
      final clientId = currentClient?.id ?? user.clientId;
      await ref
          .read(appDataProvider.notifier)
          .detachClientFromSalon(
            userId: user.uid,
            salonId: salonId,
            clientId: clientId,
          );
      ref.read(sessionControllerProvider.notifier).setSalon(null);
      ref.read(sessionControllerProvider.notifier).setUser(null);
      final updatedUser = user.copyWith(
        salonIds: const [],
        clientId: null,
        pendingSalonId: user.pendingSalonId,
        pendingFirstName: user.pendingFirstName,
        pendingLastName: user.pendingLastName,
        pendingPhone: user.pendingPhone,
        pendingDateOfBirth: user.pendingDateOfBirth,
      );
      ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
      ref.read(clientRegistrationDraftProvider.notifier).clear();
      if (!mounted) {
        return;
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      router.go('/client');
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Operazione non riuscita: ${error.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLeavingSalon = false);
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

class _SettingsIconAvatar extends StatelessWidget {
  const _SettingsIconAvatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withOpacity(0.14),
      foregroundColor: color,
      child: Icon(icon, size: 24),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: onTap,
        enabled: onTap != null,
        leading: _SettingsIconAvatar(icon: icon, color: color),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _SettingsProgressDialog extends StatelessWidget {
  const _SettingsProgressDialog({required this.message});

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
