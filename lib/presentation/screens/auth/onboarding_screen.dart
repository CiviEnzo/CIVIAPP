import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const String _defaultStaffRoleId = 'estetista';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  UserRole? _role;
  String? _selectedSalon;
  String? _staffRoleId;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _professionController = TextEditingController();
  String? _referralSource;
  final _dateOfBirthController = TextEditingController();
  final _salonSearchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _dateOfBirth;
  bool _initializedFromSession = false;
  bool _isSaving = false;
  List<UserRole> _availableRoles = const <UserRole>[];
  bool _autoSubmitScheduled = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    _dateOfBirthController.dispose();
    _salonSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = ref.read(sessionControllerProvider);
    _availableRoles = session.availableRoles;
    if (_initializedFromSession) {
      return;
    }
    final user = session.user;
    if (user != null) {
      _role = user.role;
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        final parts = user.displayName!.trim().split(' ');
        if (_firstNameController.text.isEmpty) {
          _firstNameController.text = parts.first;
        }
        if (_lastNameController.text.isEmpty && parts.length > 1) {
          _lastNameController.text = parts.sublist(1).join(' ');
        }
      }
      if (user.salonIds.isNotEmpty) {
        _selectedSalon = user.salonIds.first;
      }
    }
    if (_role == null && _availableRoles.length == 1) {
      _role = _availableRoles.single;
    }
    _initializedFromSession = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final staffRoles = data.staffRoles;
    final user = session.user;
    final roleLocked = user?.role != null;
    final role = _role ?? user?.role;
    final availableRoles =
        _availableRoles.isNotEmpty ? _availableRoles : session.availableRoles;
    final roleOptions =
        availableRoles.isNotEmpty ? availableRoles : UserRole.values;
    final allowRoleChoice = !roleLocked && roleOptions.length > 1;
    final existingClient =
        user?.clientId == null
            ? null
            : data.clients.firstWhereOrNull(
              (client) => client.id == user!.clientId,
            );

    _ensureStaffRoleDefault(staffRoles);

    if (existingClient != null) {
      if (_firstNameController.text.isEmpty) {
        _firstNameController.text = existingClient.firstName;
      }
      if (_lastNameController.text.isEmpty) {
        _lastNameController.text = existingClient.lastName;
      }
      if (_phoneController.text.isEmpty &&
          existingClient.phone.isNotEmpty &&
          existingClient.phone != '-') {
        _phoneController.text = existingClient.phone;
      }
      if (_addressController.text.isEmpty &&
          (existingClient.address?.isNotEmpty ?? false)) {
        _addressController.text = existingClient.address!;
      }
      if (_professionController.text.isEmpty &&
          (existingClient.profession?.isNotEmpty ?? false)) {
        _professionController.text = existingClient.profession!;
      }
      if ((_referralSource == null || _referralSource!.isEmpty) &&
          (existingClient.referralSource?.isNotEmpty ?? false)) {
        _referralSource = existingClient.referralSource;
      }
      if (_dateOfBirth == null && existingClient.dateOfBirth != null) {
        _dateOfBirth = existingClient.dateOfBirth;
        _dateOfBirthController.text = _dateFormat.format(
          existingClient.dateOfBirth!,
        );
      }
      _selectedSalon ??= existingClient.salonId;
    }

    final selectedSalon =
        _selectedSalon == null
            ? null
            : salons.firstWhereOrNull((salon) => salon.id == _selectedSalon);

    if (selectedSalon != null && _salonSearchController.text.isEmpty) {
      _salonSearchController.text = selectedSalon.name;
    }

    final instructions = () {
      if (roleLocked && role == UserRole.client) {
        return 'Completa i tuoi dati di base e collega il salone con cui vuoi utilizzare CiviApp.';
      }
      if (allowRoleChoice) {
        return 'Seleziona il ruolo con cui vuoi utilizzare CiviApp e, se necessario, collega il salone di riferimento.';
      }
      if (role != null) {
        return 'Completa il profilo per continuare con CiviApp.';
      }
      return 'Nessun ruolo abilitato per questa email. Contatta un amministratore.';
    }();

    final shouldAutoSubmit =
        !_autoSubmitScheduled &&
        !roleLocked &&
        !allowRoleChoice &&
        !_isSaving &&
        _canAutoSubmit(role, user, salons);

    if (shouldAutoSubmit) {
      _autoSubmitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _submit();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa il profilo'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _isSaving ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Benvenuto${user?.displayName != null ? ', ${user!.displayName!.split(' ').first}' : ''}!',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(instructions, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    Text('Ruolo', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (allowRoleChoice)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            roleOptions
                                .map(
                                  (candidateRole) => ChoiceChip(
                                    label: Text(candidateRole.label),
                                    selected: _role == candidateRole,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _role = candidateRole;
                                          if (candidateRole == UserRole.admin) {
                                            _selectedSalon = null;
                                          } else if ((_selectedSalon == null ||
                                                  !_isSalonValid(
                                                    _selectedSalon!,
                                                  )) &&
                                              salons.isNotEmpty) {
                                            _selectedSalon = salons.first.id;
                                          }
                                        } else {
                                          _role = null;
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                      )
                    else if (role != null)
                      InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          role.label,
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    else
                      Text(
                        'Nessun ruolo disponibile per questa email. Contatta un amministratore.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 24),
                    if (role != UserRole.admin) ...[
                      Text(
                        'Salone di riferimento',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (salons.isEmpty)
                        Text(
                          'Nessun salone disponibile. Contatta un amministratore per farti invitare.',
                          style: theme.textTheme.bodyMedium,
                        )
                      else ...[
                        DropdownMenu<String>(
                          controller: _salonSearchController,
                          initialSelection: _selectedSalon,
                          enableFilter: true,
                          requestFocusOnTap: true,
                          leadingIcon: const Icon(Icons.search),
                          label: const Text('Cerca salone'),
                          dropdownMenuEntries:
                              salons
                                  .map(
                                    (salon) => DropdownMenuEntry<String>(
                                      value: salon.id,
                                      label: salon.name,
                                    ),
                                  )
                                  .toList(),
                          onSelected: (value) {
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _selectedSalon = value;
                              if (value != null) {
                                final name =
                                    salons
                                        .firstWhereOrNull(
                                          (salon) => salon.id == value,
                                        )
                                        ?.name;
                                if (name != null) {
                                  _salonSearchController.text = name;
                                }
                              }
                            });
                          },
                        ),
                        if (_selectedSalon != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Salon ID collegato: $_selectedSalon',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                    ],
                    if (role == UserRole.staff)
                      _buildStaffExtras(theme.textTheme, staffRoles),
                    if (role == UserRole.client)
                      _buildClientExtras(theme.textTheme),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Completa profilo'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Potrai modificare questi dati in seguito tramite l\'area amministratore.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _ensureStaffRoleDefault(List<StaffRole> roles) {
    final currentId = _staffRoleId;
    if (roles.isEmpty) {
      if (currentId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() => _staffRoleId = null);
        });
      }
      return;
    }
    if (currentId != null && roles.any((role) => role.id == currentId)) {
      return;
    }
    final fallback =
        roles.firstWhereOrNull((role) => role.id == _defaultStaffRoleId) ??
        roles.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _staffRoleId = fallback.id);
    });
  }

  Widget _buildStaffExtras(TextTheme textTheme, List<StaffRole> roles) {
    final hasRoles = roles.isNotEmpty;
    final sortedRoles = roles.sorted((a, b) {
      final priority = a.sortPriority.compareTo(b.sortPriority);
      if (priority != 0) {
        return priority;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dettagli operatore', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          controller: _firstNameController,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lastNameController,
          decoration: const InputDecoration(
            labelText: 'Cognome',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (hasRoles)
          DropdownButtonFormField<String>(
            value: _staffRoleId,
            decoration: const InputDecoration(
              labelText: 'Ruolo operativo',
              border: OutlineInputBorder(),
            ),
            items:
                sortedRoles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role.id,
                        child: Text(role.displayName),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _staffRoleId = value),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Configura prima una mansione per completare il profilo operatore.',
            ),
          ),
      ],
    );
  }

  Widget _buildClientExtras(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dettagli cliente', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          controller: _firstNameController,
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lastNameController,
          decoration: const InputDecoration(
            labelText: 'Cognome',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Telefono',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _dateOfBirthController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Data di nascita',
            suffixIcon: Icon(Icons.calendar_today_rounded),
            border: OutlineInputBorder(),
          ),
          onTap: _pickClientDateOfBirth,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Citta di residenza',
            border: OutlineInputBorder(),
          ),
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _professionController,
          decoration: const InputDecoration(
            labelText: 'Professione',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _referralSource,
          decoration: const InputDecoration(
            labelText: 'Come ci hai conosciuto?',
            border: OutlineInputBorder(),
          ),
          hint: const Text('Seleziona un\'opzione'),
          isExpanded: true,
          items:
              _buildReferralOptions()
                  .map(
                    (option) =>
                        DropdownMenuItem(value: option, child: Text(option)),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _referralSource = value?.trim()),
        ),
      ],
    );
  }

  List<String> _buildReferralOptions() {
    final options = List<String>.from(kClientReferralSourceOptions);
    if (_referralSource != null &&
        _referralSource!.isNotEmpty &&
        !options.contains(_referralSource)) {
      options.add(_referralSource!);
    }
    return options;
  }

  String _resolveClientNumber({
    required List<Client> allClients,
    required String salonId,
    Client? existingClient,
  }) {
    final existingNumber = existingClient?.clientNumber;
    if (existingNumber != null && existingNumber.isNotEmpty) {
      return existingNumber;
    }
    final clientsForSalon = allClients.where((client) {
      if (existingClient != null && client.id == existingClient.id) {
        return false;
      }
      return client.salonId == salonId;
    });
    return nextSequentialClientNumber(clientsForSalon);
  }

  Future<void> _pickClientDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('it', 'IT'),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _dateOfBirth = selected;
      _dateOfBirthController.text = _dateFormat.format(selected);
    });
  }

  bool _canAutoSubmit(UserRole? role, AppUser? user, List<Salon> salons) {
    if (role == null) {
      return false;
    }
    if (role == UserRole.admin) {
      return true;
    }
    final salonId = _selectedSalon ?? user?.defaultSalonId;
    if (salonId == null || salonId.isEmpty) {
      return false;
    }
    final hasSalon = salons.any((salon) => salon.id == salonId);
    if (!hasSalon) {
      return false;
    }
    if (_composeName().isEmpty) {
      return false;
    }
    if (role == UserRole.client) {
      if (_phoneController.text.trim().isEmpty) {
        return false;
      }
      if (_dateOfBirth == null) {
        return false;
      }
      if (_addressController.text.trim().isEmpty) {
        return false;
      }
      if (_professionController.text.trim().isEmpty) {
        return false;
      }
      if (_referralSource == null || _referralSource!.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    final session = ref.read(sessionControllerProvider);
    final user = session.user;
    final role = _role ?? user?.role;
    if (role == null) {
      _showMessage('Seleziona il ruolo.');
      return;
    }

    if (role != UserRole.admin && (_selectedSalon?.isEmpty ?? true)) {
      _showMessage('Seleziona un salone.');
      return;
    }
    if (role == UserRole.staff && (_staffRoleId?.isEmpty ?? true)) {
      _showMessage('Seleziona una mansione per il nuovo operatore.');
      return;
    }

    final composedName = _composeName();
    if (role != UserRole.admin && composedName.isEmpty) {
      _showMessage('Inserisci nome e cognome.');
      return;
    }
    if (role == UserRole.client) {
      if (_phoneController.text.trim().isEmpty) {
        _showMessage('Inserisci il numero di telefono.');
        return;
      }
      if (_dateOfBirth == null) {
        _showMessage('Seleziona la data di nascita.');
        return;
      }
      if (_addressController.text.trim().isEmpty) {
        _showMessage('Inserisci la città di residenza.');
        return;
      }
      if (_professionController.text.trim().isEmpty) {
        _showMessage('Inserisci la professione.');
        return;
      }
      if (_referralSource == null || _referralSource!.trim().isEmpty) {
        _showMessage('Seleziona come ci hai conosciuto.');
        return;
      }
    }

    final authRepo = ref.read(authRepositoryProvider);
    final dataStore = ref.read(appDataProvider.notifier);
    final currentData = ref.read(appDataProvider);
    final salonId = _selectedSalon;

    String? staffId = user?.staffId;
    String? clientId = user?.clientId;

    try {
      setState(() => _isSaving = true);

      if (role == UserRole.staff && salonId != null) {
        final resolvedStaffId = staffId ?? const Uuid().v4();
        staffId = resolvedStaffId;
        final selectedSalonId = salonId;
        final existingStaff = currentData.staff.firstWhereOrNull(
          (member) => member.id == staffId,
        );
        final existingRoleIds = existingStaff?.roleIds ?? const <String>[];
        final resolvedRoleIds =
            existingRoleIds.isNotEmpty
                ? existingRoleIds
                : <String>[_staffRoleId ?? _defaultStaffRoleId];
        final staffMember = StaffMember(
          id: resolvedStaffId,
          salonId: selectedSalonId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          roleIds: resolvedRoleIds,
          phone: existingStaff?.phone ?? user?.email,
          email: user?.email ?? existingStaff?.email,
          dateOfBirth: existingStaff?.dateOfBirth,
          vacationAllowance:
              existingStaff?.vacationAllowance ??
              StaffMember.defaultVacationAllowance,
          permissionAllowance:
              existingStaff?.permissionAllowance ??
              StaffMember.defaultPermissionAllowance,
        );
        await dataStore.upsertStaff(staffMember);
        ref.read(sessionControllerProvider.notifier).setUser(resolvedStaffId);
        ref.read(sessionControllerProvider.notifier).setSalon(selectedSalonId);
      }

      var profileUpdated = false;

      if (role == UserRole.client && salonId != null) {
        final resolvedClientId = clientId ?? const Uuid().v4();
        clientId = resolvedClientId;
        final selectedSalonId = salonId;
        final parts = composedName.split(' ');
        final first = parts.first;
        final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        final existingClient = currentData.clients.firstWhereOrNull(
          (client) => client.id == resolvedClientId,
        );
        final now = DateTime.now();
        final phone = _phoneController.text.trim();
        final address = _addressController.text.trim();
        final profession = _professionController.text.trim();
        final referral = (_referralSource ?? '').trim();
        final clientNumber = _resolveClientNumber(
          allClients: currentData.clients,
          salonId: selectedSalonId,
          existingClient: existingClient,
        );
        final dateOfBirth = _dateOfBirth ?? existingClient?.dateOfBirth;
        final selectedSalon = currentData.salons.firstWhereOrNull(
          (salon) => salon.id == selectedSalonId,
        );
        final defaultInitialBalance =
            (selectedSalon?.loyaltySettings.enabled ?? false)
                ? selectedSalon!.loyaltySettings.initialBalance
                : 0;
        final loyaltyTotalEarned = existingClient?.loyaltyTotalEarned ?? 0;
        final loyaltyTotalRedeemed = existingClient?.loyaltyTotalRedeemed ?? 0;
        final resolvedInitial =
            existingClient?.loyaltyInitialPoints ?? defaultInitialBalance;
        final storedBalance = existingClient?.loyaltyPoints ?? resolvedInitial;
        var historicNet = storedBalance - resolvedInitial;
        if (historicNet == 0 &&
            (loyaltyTotalEarned != 0 || loyaltyTotalRedeemed != 0)) {
          historicNet = loyaltyTotalEarned - loyaltyTotalRedeemed;
        }
        final nextBalance = resolvedInitial + historicNet;
        final loyaltyUpdatedAt =
            existingClient?.loyaltyUpdatedAt ?? (nextBalance > 0 ? now : null);
        final client = Client(
          id: resolvedClientId,
          salonId: selectedSalonId,
          firstName: first,
          lastName: last,
          phone: phone.isEmpty ? '-' : phone,
          clientNumber: clientNumber,
          dateOfBirth: dateOfBirth,
          address: address.isEmpty ? existingClient?.address : address,
          profession:
              profession.isEmpty ? existingClient?.profession : profession,
          referralSource:
              referral.isEmpty ? existingClient?.referralSource : referral,
          email: user?.email ?? existingClient?.email,
          loyaltyInitialPoints: resolvedInitial,
          loyaltyPoints: nextBalance,
          loyaltyUpdatedAt: loyaltyUpdatedAt,
          loyaltyTotalEarned: loyaltyTotalEarned,
          loyaltyTotalRedeemed: loyaltyTotalRedeemed,
          marketedConsents:
              existingClient?.marketedConsents ?? const <ClientConsent>[],
          notes:
              existingClient?.notes ??
              'Creato automaticamente dall\'onboarding utente',
          onboardingStatus: ClientOnboardingStatus.onboardingCompleted,
          invitationSentAt: existingClient?.invitationSentAt,
          firstLoginAt: existingClient?.firstLoginAt ?? now,
          onboardingCompletedAt: now,
        );
        await authRepo.completeUserProfile(
          role: role,
          salonIds: [selectedSalonId],
          staffId: staffId,
          clientId: resolvedClientId,
          displayName:
              composedName.isNotEmpty ? composedName : user?.displayName,
        );
        profileUpdated = true;
        await dataStore.upsertClient(client);
        ref.read(sessionControllerProvider.notifier).setUser(resolvedClientId);
        ref.read(sessionControllerProvider.notifier).setSalon(selectedSalonId);
      }

      if (!profileUpdated) {
        await authRepo.completeUserProfile(
          role: role,
          salonIds:
              role == UserRole.admin
                  ? const []
                  : [if (salonId != null) salonId],
          staffId: staffId,
          clientId: clientId,
          displayName:
              composedName.isNotEmpty ? composedName : user?.displayName,
        );
        profileUpdated = true;
      }

      final firebaseUser = user;
      if (firebaseUser != null) {
        final updatedUser = AppUser(
          uid: firebaseUser.uid,
          role: role,
          salonIds:
              role == UserRole.admin
                  ? const []
                  : [if (salonId != null) salonId],
          staffId: staffId,
          clientId: clientId,
          displayName:
              composedName.isNotEmpty ? composedName : user?.displayName,
          email: firebaseUser.email,
          availableRoles: firebaseUser.availableRoles,
        );
        ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
      }

      if (!mounted) {
        return;
      }
      context.go(_pathForRole(role));
    } catch (error) {
      _showMessage('Errore durante il salvataggio: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Errore durante il logout: $error');
    }
  }

  String _composeName() {
    final name = _firstNameController.text.trim();
    final surname = _lastNameController.text.trim();
    if (name.isEmpty && surname.isEmpty) {
      return '';
    }
    if (surname.isEmpty) {
      return name;
    }
    return '$name $surname';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isSalonValid(String id) {
    final data = ref.read(appDataProvider);
    return data.salons.any((salon) => salon.id == id);
  }

  String _pathForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '/admin';
      case UserRole.staff:
        return '/staff';
      case UserRole.client:
        return '/client';
    }
  }
}
