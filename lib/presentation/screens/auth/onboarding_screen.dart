import 'package:you_book/app/providers.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/public_salon.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/domain/entities/user_role.dart';
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
  final _cityController = TextEditingController();
  final _professionController = TextEditingController();
  String? _referralSource;
  final _dateOfBirthController = TextEditingController();
  final _salonSearchController = TextEditingController();
  final _notesController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _dateOfBirth;
  String? _gender;
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
    _cityController.dispose();
    _professionController.dispose();
    _dateOfBirthController.dispose();
    _salonSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = ref.read(sessionControllerProvider);
    _availableRoles = session.availableRoles;
    if (!_initializedFromSession) {
      final registrationDraft = ref.read(clientRegistrationDraftProvider);
      if (registrationDraft != null) {
        if (_firstNameController.text.isEmpty) {
          _firstNameController.text = registrationDraft.firstName;
        }
        if (_lastNameController.text.isEmpty) {
          _lastNameController.text = registrationDraft.lastName;
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = registrationDraft.phone;
        }
        if (registrationDraft.dateOfBirth != null && _dateOfBirth == null) {
          _dateOfBirth = registrationDraft.dateOfBirth;
          _dateOfBirthController.text = _dateFormat.format(
            registrationDraft.dateOfBirth!,
          );
        }
      }
    }
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
    final salons =
        data.discoverableSalons.isNotEmpty
            ? data.discoverableSalons
            : data.salons
                .where((salon) => salon.isPublished)
                .map(PublicSalon.fromSalon)
                .toList(growable: false);
    final staffRoles = data.staffRoles;
    final user = session.user;
    final roleLocked = user?.role != null;
    final availableRoles =
        _availableRoles.isNotEmpty ? _availableRoles : session.availableRoles;
    final roleOptions =
        availableRoles.isNotEmpty ? availableRoles : UserRole.values;
    if (_role == null) {
      if (user?.role != null) {
        _role = user!.role;
      } else if (roleOptions.isNotEmpty) {
        _role = roleOptions.first;
      }
    }
    final role = _role ?? user?.role;
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
      if (_cityController.text.isEmpty) {
        final existingCity = existingClient.city;
        if (existingCity != null && existingCity.isNotEmpty) {
          _cityController.text = existingCity;
        } else if (existingClient.address?.isNotEmpty ?? false) {
          _cityController.text = existingClient.address!;
        }
      }
      if (_addressController.text.isEmpty &&
          (existingClient.address?.isNotEmpty ?? false)) {
        _addressController.text = existingClient.address!;
      }
      if (_professionController.text.isEmpty &&
          (existingClient.profession?.isNotEmpty ?? false)) {
        _professionController.text = existingClient.profession!;
      }
      if (_notesController.text.isEmpty &&
          (existingClient.notes?.isNotEmpty ?? false)) {
        _notesController.text = existingClient.notes!;
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

    final registrationDraft = ref.watch(clientRegistrationDraftProvider);
    if (!_initializedFromSession && registrationDraft != null) {
      if (_firstNameController.text.isEmpty) {
        _firstNameController.text = registrationDraft.firstName;
      }
      if (_lastNameController.text.isEmpty) {
        _lastNameController.text = registrationDraft.lastName;
      }
      if (_phoneController.text.isEmpty) {
        _phoneController.text = registrationDraft.phone;
      }
      if (_dateOfBirth == null && registrationDraft.dateOfBirth != null) {
        _dateOfBirth = registrationDraft.dateOfBirth;
        _dateOfBirthController.text = _dateFormat.format(
          registrationDraft.dateOfBirth!,
        );
      }
    }

    final baseFirstNameRaw =
        registrationDraft?.firstName ??
        existingClient?.firstName ??
        _firstNameController.text;
    final baseLastNameRaw =
        registrationDraft?.lastName ??
        existingClient?.lastName ??
        _lastNameController.text;
    final baseEmail = user?.email ?? registrationDraft?.email ?? '';
    final existingPhone = existingClient?.phone;
    final sanitizedExistingPhone =
        existingPhone == null || existingPhone == '-' ? null : existingPhone;
    final basePhoneRaw =
        registrationDraft?.phone ??
        sanitizedExistingPhone ??
        _phoneController.text;
    final basePhone = basePhoneRaw.trim();
    final baseDateOfBirth =
        registrationDraft?.dateOfBirth ??
        existingClient?.dateOfBirth ??
        _dateOfBirth;
    if (_phoneController.text.isEmpty && basePhone.isNotEmpty) {
      _phoneController.text = basePhone;
    }
    if (_dateOfBirth == null && baseDateOfBirth != null) {
      _dateOfBirth = baseDateOfBirth;
      _dateOfBirthController.text = _dateFormat.format(baseDateOfBirth);
    }

    final baseFirstName = baseFirstNameRaw.trim();
    final baseLastName = baseLastNameRaw.trim();

    final pendingSalonIdRaw = user?.pendingSalonId;
    final userPendingSalonId =
        pendingSalonIdRaw != null && pendingSalonIdRaw.trim().isNotEmpty
            ? pendingSalonIdRaw.trim()
            : null;
    final pendingRequests =
        user == null
            ? const <SalonAccessRequest>[]
            : data.salonAccessRequests
                .where((request) => request.userId == user.uid)
                .toList(growable: false);
    final pendingRequestsPending =
        pendingRequests.where((request) => request.isPending).toList();
    if (userPendingSalonId != null &&
        pendingRequestsPending.every(
          (request) => request.salonId != userPendingSalonId,
        )) {
      final syntheticExtra = <String, dynamic>{};
      final syntheticCity = _cityController.text.trim();
      if (syntheticCity.isNotEmpty) {
        syntheticExtra['city'] = syntheticCity;
      }
      final syntheticAddress = _addressController.text.trim();
      if (syntheticAddress.isNotEmpty) {
        syntheticExtra['address'] = syntheticAddress;
      }
      final syntheticProfession = _professionController.text.trim();
      if (syntheticProfession.isNotEmpty) {
        syntheticExtra['profession'] = syntheticProfession;
      }
      final syntheticReferral = (_referralSource ?? '').trim();
      if (syntheticReferral.isNotEmpty) {
        syntheticExtra['referralSource'] = syntheticReferral;
      }
      final syntheticNotes = _notesController.text.trim();
      if (syntheticNotes.isNotEmpty) {
        syntheticExtra['notes'] = syntheticNotes;
      }
      pendingRequestsPending.add(
        SalonAccessRequest(
          id: 'local-$userPendingSalonId',
          salonId: userPendingSalonId,
          userId: user?.uid ?? '',
          firstName:
              baseFirstName.isNotEmpty
                  ? baseFirstName
                  : (user?.pendingFirstName ?? ''),
          lastName:
              baseLastName.isNotEmpty
                  ? baseLastName
                  : (user?.pendingLastName ?? ''),
          email: baseEmail,
          phone: basePhone,
          dateOfBirth: baseDateOfBirth ?? user?.pendingDateOfBirth,
          extraData: syntheticExtra,
          status: SalonAccessRequestStatus.pending,
        ),
      );
    }
    final hasPendingRequest = pendingRequestsPending.isNotEmpty;
    final firstPendingSalonId =
        pendingRequestsPending.isEmpty
            ? null
            : pendingRequestsPending.first.salonId;
    final selectedSalonId =
        _selectedSalon ?? userPendingSalonId ?? firstPendingSalonId;
    final selectedSalon =
        selectedSalonId == null
            ? null
            : salons.firstWhereOrNull((salon) => salon.id == selectedSalonId);
    final registrationSettings =
        selectedSalon?.clientRegistration ?? const ClientRegistrationSettings();
    final requiresAddress = registrationSettings.extraFields.contains(
      ClientRegistrationExtraField.address,
    );
    final requiresProfession = registrationSettings.extraFields.contains(
      ClientRegistrationExtraField.profession,
    );
    final requiresReferral = registrationSettings.extraFields.contains(
      ClientRegistrationExtraField.referralSource,
    );
    final requiresNotes = registrationSettings.extraFields.contains(
      ClientRegistrationExtraField.notes,
    );
    final requiresGender = registrationSettings.extraFields.contains(
      ClientRegistrationExtraField.gender,
    );

    if (selectedSalon != null && _salonSearchController.text.isEmpty) {
      _salonSearchController.text = selectedSalon.name;
    }

    final instructions = () {
      if (hasPendingRequest) {
        return 'La tua richiesta di accesso è stata inviata. Il salone ti abiliterà non appena la valuterà.';
      }
      if (roleLocked && role == UserRole.client) {
        return 'Seleziona il salone con cui vuoi utilizzare CiviApp e invia i tuoi dati. Sarà l\'amministratore del salone ad abilitare l\'accesso.';
      }
      if (role != null) {
        return 'Completa il profilo per continuare con CiviApp.';
      }
      return 'Nessun ruolo abilitato per questa email. Contatta un amministratore.';
    }();

    final shouldAutoSubmit =
        !_autoSubmitScheduled &&
        !roleLocked &&
        !_isSaving &&
        !hasPendingRequest &&
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
                    if (hasPendingRequest) ...[
                      const SizedBox(height: 16),
                      _buildPendingRequestCard(
                        theme,
                        pendingRequestsPending,
                        salons,
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const SizedBox(height: 24),
                    ],
                    Text('Ruolo', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (role != null)
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
                        IgnorePointer(
                          ignoring: hasPendingRequest,
                          child: DropdownMenu<String>(
                            controller: _salonSearchController,
                            initialSelection: selectedSalonId,
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
                        ),
                        if (selectedSalonId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Salon ID collegato: $selectedSalonId',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                    ],
                    if (role == UserRole.staff)
                      _buildStaffExtras(theme.textTheme, staffRoles),
                    if (role == UserRole.client) ...[
                      _buildBaseInfoCard(
                        theme.textTheme,
                        firstName: baseFirstName,
                        lastName: baseLastName,
                        email: baseEmail,
                        phone: basePhone,
                        dateOfBirth: baseDateOfBirth,
                      ),
                      const SizedBox(height: 12),
                      _buildClientExtras(
                        theme.textTheme,
                        hasSalon: selectedSalonId != null,
                        requiresAddress: requiresAddress,
                        requiresGender: requiresGender,
                        requiresProfession: requiresProfession,
                        requiresReferral: requiresReferral,
                        requiresNotes: requiresNotes,
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed:
                          _isSaving || hasPendingRequest ? null : _submit,
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                hasPendingRequest
                                    ? 'Richiesta in attesa di approvazione'
                                    : 'Invia richiesta di accesso',
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasPendingRequest
                          ? 'Puoi chiudere l\'app: riceverai una conferma quando il salone completerà l\'attivazione.'
                          : 'I dati inseriti saranno inviati al salone selezionato per permettere l\'attivazione del tuo account.',
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

  Widget _buildPendingRequestCard(
    ThemeData theme,
    List<SalonAccessRequest> requests,
    List<PublicSalon> salons,
  ) {
    final pending = requests
        .where((request) => request.isPending)
        .toList(growable: false);
    if (pending.isEmpty) {
      return Card(
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nessuna richiesta in attesa.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final salonLookup = {for (final salon in salons) salon.id: salon.name};
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    Widget buildInfoRow(String label, String value, TextTheme textTheme) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: ',
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            Expanded(child: Text(value, style: textTheme.bodySmall)),
          ],
        ),
      );
    }

    return Card(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Richiesta in attesa di approvazione',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Il salone riceverà i tuoi dati e ti abiliterà all\'accesso quando la richiesta sarà approvata.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < pending.length; i++) ...[
              () {
                final request = pending[i];
                final salonName =
                    salonLookup[request.salonId] ?? request.salonId;
                final createdLabel =
                    request.createdAt != null
                        ? dateTimeFormat.format(request.createdAt!)
                        : 'Inviata recentemente';
                final textTheme = theme.textTheme;
                final extra = request.extraData;
                final address = _stringOrNull(extra['address']);
                final profession = _stringOrNull(extra['profession']);
                final referral = _stringOrNull(extra['referralSource']);
                final notes = _stringOrNull(extra['notes']);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(salonName, style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    buildInfoRow('Richiesta creata', createdLabel, textTheme),
                    buildInfoRow(
                      'Nome',
                      '${request.firstName} ${request.lastName}',
                      textTheme,
                    ),
                    buildInfoRow('Email', request.email, textTheme),
                    if (request.phone.isNotEmpty)
                      buildInfoRow('Telefono', request.phone, textTheme),
                    if (request.dateOfBirth != null)
                      buildInfoRow(
                        'Data di nascita',
                        DateFormat('dd/MM/yyyy').format(request.dateOfBirth!),
                        textTheme,
                      ),
                    () {
                      final genderCode = _stringOrNull(extra['gender']);
                      if (genderCode == null) return const SizedBox.shrink();
                      String label;
                      switch (genderCode) {
                        case 'male':
                          label = 'Uomo';
                          break;
                        case 'female':
                          label = 'Donna';
                          break;
                        default:
                          label = 'Altro/Non specificato';
                      }
                      return buildInfoRow('Sesso', label, textTheme);
                    }(),
                    if (address != null)
                      buildInfoRow('Città di residenza', address, textTheme),
                    if (profession != null)
                      buildInfoRow('Professione', profession, textTheme),
                    if (referral != null)
                      buildInfoRow(
                        'Come ci ha conosciuto',
                        referral,
                        textTheme,
                      ),
                    if (notes != null) buildInfoRow('Note', notes, textTheme),
                  ],
                );
              }(),
              if (i != pending.length - 1) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
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

  Widget _buildBaseInfoCard(
    TextTheme textTheme, {
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required DateTime? dateOfBirth,
  }) {
    final dateLabel =
        dateOfBirth != null ? _dateFormat.format(dateOfBirth) : '—';
    final fullName = [
      firstName.trim(),
      lastName.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dati account', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            _infoRow(
              textTheme,
              'Nome completo',
              fullName.isEmpty ? '—' : fullName,
            ),
            _infoRow(
              textTheme,
              'Email',
              email.trim().isEmpty ? '—' : email.trim(),
            ),
            _infoRow(
              textTheme,
              'Telefono',
              phone.trim().isEmpty ? '—' : phone.trim(),
            ),
            _infoRow(textTheme, 'Data di nascita', dateLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildClientExtras(
    TextTheme textTheme, {
    required bool hasSalon,
    required bool requiresAddress,
    required bool requiresGender,
    required bool requiresProfession,
    required bool requiresReferral,
    required bool requiresNotes,
  }) {
    if (!hasSalon) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Seleziona un salone per completare i dati richiesti.',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }

    final fields = <Widget>[];
    void addField(Widget field) {
      if (fields.isNotEmpty) {
        fields.add(const SizedBox(height: 12));
      }
      fields.add(field);
    }

    if (requiresAddress) {
      addField(
        TextFormField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'Citta di residenza *',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          minLines: 1,
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Campo obbligatorio';
            }
            return null;
          },
        ),
      );
      addField(
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Indirizzo (opzionale)',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 2,
        ),
      );
    }

    if (requiresGender) {
      addField(
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(
            labelText: 'Sesso *',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
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
      );
    }

    if (requiresProfession) {
      addField(
        TextFormField(
          controller: _professionController,
          decoration: const InputDecoration(
            labelText: 'Professione *',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Campo obbligatorio';
            }
            return null;
          },
        ),
      );
    }

    if (requiresReferral) {
      addField(
        DropdownButtonFormField<String>(
          value: _referralSource,
          decoration: const InputDecoration(
            labelText: 'Come ci hai conosciuto? *',
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
          validator: (value) {
            if (_referralSource == null || _referralSource!.trim().isEmpty) {
              return 'Campo obbligatorio';
            }
            return null;
          },
        ),
      );
    }

    if (requiresNotes) {
      addField(
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Note *',
            border: OutlineInputBorder(),
          ),
          minLines: 3,
          maxLines: 5,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Campo obbligatorio';
            }
            return null;
          },
        ),
      );
    }

    if (fields.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Questo salone non richiede informazioni aggiuntive.',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dati aggiuntivi richiesti', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            ...fields,
          ],
        ),
      ),
    );
  }

  String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Widget _infoRow(TextTheme textTheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
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

  bool _canAutoSubmit(UserRole? role, AppUser? user, List<PublicSalon> salons) {
    if (role == null) {
      return false;
    }
    if (role == UserRole.admin) {
      return true;
    }
    final salonId =
        _selectedSalon ?? user?.pendingSalonId ?? user?.defaultSalonId;
    if (salonId == null || salonId.isEmpty) {
      return false;
    }
    final hasSalon = salons.any((salon) => salon.id == salonId);
    if (!hasSalon) {
      return false;
    }
    if (role == UserRole.staff && _composeName().isEmpty) {
      return false;
    }
    if (role == UserRole.client) {
      final selectedSalon = salons.firstWhereOrNull(
        (salon) => salon.id == salonId,
      );
      final registrationSettings =
          selectedSalon?.clientRegistration ??
          const ClientRegistrationSettings();
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.address,
      )) {
        if (_cityController.text.trim().isEmpty) {
          return false;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.profession,
      )) {
        if (_professionController.text.trim().isEmpty) {
          return false;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.referralSource,
      )) {
        if (_referralSource == null || _referralSource!.trim().isEmpty) {
          return false;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.notes,
      )) {
        if (_notesController.text.trim().isEmpty) {
          return false;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.gender,
      )) {
        if (_gender == null || _gender!.trim().isEmpty) {
          return false;
        }
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

    final salonId = _selectedSalon ?? user?.pendingSalonId;
    if (role != UserRole.admin && (salonId == null || salonId.isEmpty)) {
      _showMessage('Seleziona un salone.');
      return;
    }
    if (role == UserRole.staff && (_staffRoleId?.isEmpty ?? true)) {
      _showMessage('Seleziona una mansione per il nuovo operatore.');
      return;
    }

    final composedName = _composeName();
    if (role == UserRole.staff && composedName.isEmpty) {
      _showMessage('Inserisci nome e cognome.');
      return;
    }

    final authRepo = ref.read(authRepositoryProvider);
    final dataStore = ref.read(appDataProvider.notifier);
    final currentData = ref.read(appDataProvider);
    final registrationDraft = ref.read(clientRegistrationDraftProvider);
    final selectedSalon = currentData.salons.firstWhereOrNull(
      (salon) => salon.id == salonId,
    );
    final registrationSettings =
        selectedSalon?.clientRegistration ?? const ClientRegistrationSettings();

    if (role == UserRole.client) {
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.address,
      )) {
        if (_cityController.text.trim().isEmpty) {
          _showMessage('Inserisci la città di residenza.');
          return;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.profession,
      )) {
        if (_professionController.text.trim().isEmpty) {
          _showMessage('Inserisci la professione.');
          return;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.referralSource,
      )) {
        if (_referralSource == null || _referralSource!.trim().isEmpty) {
          _showMessage('Seleziona come ci hai conosciuto.');
          return;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.notes,
      )) {
        if (_notesController.text.trim().isEmpty) {
          _showMessage('Inserisci le note richieste.');
          return;
        }
      }
      if (registrationSettings.extraFields.contains(
        ClientRegistrationExtraField.gender,
      )) {
        if (_gender == null || _gender!.trim().isEmpty) {
          _showMessage('Seleziona il sesso.');
          return;
        }
      }
    }

    String? staffId = user?.staffId;
    String? clientId = user?.clientId;
    String? clientDisplayName;

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
          isEquipment: existingStaff?.isEquipment ?? false,
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
        final selectedSalonId = salonId;
        final normalizedEmail = user?.email?.trim().toLowerCase();
        Client? existingClient;
        if (clientId != null) {
          existingClient = currentData.clients.firstWhereOrNull(
            (client) => client.id == clientId,
          );
        }
        if (existingClient == null &&
            normalizedEmail != null &&
            normalizedEmail.isNotEmpty) {
          existingClient = currentData.clients.firstWhereOrNull((client) {
            final candidate = client.email?.trim();
            if (candidate == null || candidate.isEmpty) {
              return false;
            }
            return candidate.toLowerCase() == normalizedEmail;
          });
        }

        if (existingClient != null &&
            existingClient.salonId != selectedSalonId) {
          if (mounted) {
            setState(() => _isSaving = false);
            _showMessage(
              "Esiste gia' un cliente con questa email associato ad un altro salone. Contatta il salone per assistenza.",
            );
          }
          return;
        }

        final normalizedFirst =
            (registrationDraft?.firstName ??
                    existingClient?.firstName ??
                    _firstNameController.text)
                .trim();
        final normalizedLast =
            (registrationDraft?.lastName ??
                    existingClient?.lastName ??
                    _lastNameController.text)
                .trim();
        final displayName = [
          normalizedFirst,
          normalizedLast,
        ].where((value) => value.isNotEmpty).join(' ');
        clientDisplayName = displayName;
        final existingPhone = existingClient?.phone;
        final sanitizedExistingPhone =
            existingPhone == null || existingPhone == '-'
                ? null
                : existingPhone;
        final rawPhone =
            (registrationDraft?.phone ??
                    sanitizedExistingPhone ??
                    _phoneController.text)
                .trim();
        final city = _cityController.text.trim();
        final address = _addressController.text.trim();
        final profession = _professionController.text.trim();
        final referral = (_referralSource ?? '').trim();
        final notes = _notesController.text.trim();
        final dateOfBirth =
            registrationDraft?.dateOfBirth ??
            existingClient?.dateOfBirth ??
            _dateOfBirth;

        final extraData = <String, dynamic>{};
        if (city.isNotEmpty) {
          extraData['city'] = city;
        }
        if (address.isNotEmpty) {
          extraData['address'] = address;
        }
        if (_gender != null && _gender!.trim().isNotEmpty) {
          extraData['gender'] = _gender!.trim();
        }
        if (profession.isNotEmpty) {
          extraData['profession'] = profession;
        }
        if (referral.isNotEmpty) {
          extraData['referralSource'] = referral;
        }
        if (notes.isNotEmpty) {
          extraData['notes'] = notes;
        }

        final uid = user?.uid;
        final email =
            user?.email ?? existingClient?.email ?? registrationDraft?.email;
        if (uid == null || email == null) {
          _showMessage(
            'Impossibile inviare la richiesta. Accedi nuovamente e riprova.',
          );
          return;
        }
        await dataStore.submitSalonAccessRequest(
          salonId: selectedSalonId,
          userId: uid,
          clientId: existingClient?.id ?? user?.clientId,
          firstName: normalizedFirst,
          lastName: normalizedLast,
          email: email,
          phone: rawPhone,
          dateOfBirth: dateOfBirth,
          extraData: extraData,
        );
        await authRepo.completeUserProfile(
          role: role,
          salonIds: const [],
          staffId: staffId,
          clientId: null,
          displayName: displayName.isNotEmpty ? displayName : user?.displayName,
        );
        final fallbackDisplayName =
            displayName.isNotEmpty ? displayName : user?.displayName;
        if (user != null) {
          final updatedUser = user.copyWith(
            role: role,
            salonIds: const [],
            staffId: staffId,
            clientId: null,
            displayName: fallbackDisplayName,
            availableRoles: user.availableRoles,
            pendingSalonId: selectedSalonId,
            pendingFirstName: normalizedFirst,
            pendingLastName: normalizedLast,
            pendingPhone: rawPhone,
            pendingDateOfBirth: dateOfBirth,
          );
          ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
        }
        profileUpdated = true;
        ref.read(clientRegistrationDraftProvider.notifier).clear();
        if (!mounted) {
          return;
        }
        _showMessage(
          'Richiesta inviata al salone. Riceverai una conferma via email quando sarà approvata.',
        );
        context.go('/');
        return;
      }

      if (!profileUpdated) {
        final fallbackDisplayNameCandidate = clientDisplayName ?? '';
        final fallbackDisplayName =
            fallbackDisplayNameCandidate.isNotEmpty
                ? fallbackDisplayNameCandidate
                : (composedName.isNotEmpty ? composedName : user?.displayName);
        await authRepo.completeUserProfile(
          role: role,
          salonIds:
              role == UserRole.admin
                  ? const []
                  : [if (salonId != null) salonId],
          staffId: staffId,
          clientId: clientId,
          displayName: fallbackDisplayName,
        );
        profileUpdated = true;
      }

      final firebaseUser = user;
      if (firebaseUser != null) {
        final fallbackDisplayNameCandidate = clientDisplayName ?? '';
        final fallbackDisplayName =
            fallbackDisplayNameCandidate.isNotEmpty
                ? fallbackDisplayNameCandidate
                : (composedName.isNotEmpty ? composedName : user?.displayName);
        final updatedUser = firebaseUser.copyWith(
          role: role,
          salonIds:
              role == UserRole.admin
                  ? const []
                  : [if (salonId != null) salonId],
          staffId: staffId,
          clientId: clientId,
          displayName: fallbackDisplayName,
          email: firebaseUser.email,
          availableRoles: firebaseUser.availableRoles,
          pendingSalonId: user?.pendingSalonId,
          pendingFirstName: user?.pendingFirstName,
          pendingLastName: user?.pendingLastName,
          pendingPhone: user?.pendingPhone,
          pendingDateOfBirth: user?.pendingDateOfBirth,
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
      await performSignOut(ref);
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
