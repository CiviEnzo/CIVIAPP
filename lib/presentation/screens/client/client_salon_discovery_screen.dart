import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_registration_draft.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/domain/entities/user_role.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) {
      return;
    }
    setState(() {
      _searchQuery = query;
    });
  }

  bool _matchesQuery(Salon salon) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final tokens = <String>[
      salon.name,
      salon.city,
      salon.address,
      salon.email,
      salon.phone,
    ];
    return tokens.any((token) => token.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final userId = session.uid;

    final salons = data.salons
        .where((salon) => salon.status == SalonStatus.active)
        .where(_matchesQuery)
        .sorted((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final requests =
        userId == null
            ? const <SalonAccessRequest>[]
            : data.salonAccessRequests
                .where((request) => request.userId == userId)
                .toList(growable: false);

    final pendingBySalon = <String, SalonAccessRequest>{
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

    final approvedSalonIds = session.availableSalonIds.toSet();
    final hasSalons = salons.isNotEmpty;
    final useCardGrid = salons.length <= 5;

    final defaultSalonId =
        session.salonId ??
        (approvedSalonIds.isEmpty ? null : approvedSalonIds.first);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli il tuo salone'),
        automaticallyImplyLeading: false,
        actions: [
          if (approvedSalonIds.isNotEmpty)
            IconButton(
              tooltip: 'Vai al salone attivo',
              icon: const Icon(Icons.launch_rounded),
              onPressed: () => _enterSalon(context, defaultSalonId),
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
                'Benvenuto${user?.displayName != null ? ', ${user!.displayName!.split(' ').first}' : ''}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Qui puoi esplorare i saloni disponibili, inviare una richiesta di accesso e, una volta approvata, entrare direttamente nella tua area cliente.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Cerca per nome, città o contatto',
                  suffixIcon:
                      _searchQuery.isEmpty
                          ? null
                          : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                ),
              ),
              const SizedBox(height: 24),
              if (!hasSalons)
                Expanded(
                  child: Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Nessun salone disponibile al momento.'
                          : 'Nessun salone corrisponde alla tua ricerca.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (useCardGrid)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount =
                          width >= 840
                              ? 3
                              : width >= 520
                              ? 2
                              : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 4 / 3,
                        ),
                        itemBuilder: (context, index) {
                          final salon = salons[index];
                          final isApproved = approvedSalonIds.contains(
                            salon.id,
                          );
                          final pendingRequest = pendingBySalon[salon.id];
                          final rejectedRequest = rejectedBySalon[salon.id];
                          return _SalonCard(
                            salon: salon,
                            isApproved: isApproved,
                            pendingRequest: pendingRequest,
                            rejectedRequest: rejectedRequest,
                            onRequestAccess:
                                () => _startRequestFlow(context, salon, user),
                            onEnter: () => _enterSalon(context, salon.id),
                          );
                        },
                        itemCount: salons.length,
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: salons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final salon = salons[index];
                      final isApproved = approvedSalonIds.contains(salon.id);
                      final pendingRequest = pendingBySalon[salon.id];
                      final rejectedRequest = rejectedBySalon[salon.id];
                      return _SalonCard(
                        salon: salon,
                        isApproved: isApproved,
                        pendingRequest: pendingRequest,
                        rejectedRequest: rejectedRequest,
                        onRequestAccess:
                            () => _startRequestFlow(context, salon, user),
                        onEnter: () => _enterSalon(context, salon.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (pendingBySalon.isNotEmpty)
                _StatusInfoBanner(
                  icon: Icons.hourglass_top_rounded,
                  color: scheme.tertiary,
                  message:
                      'Hai ${pendingBySalon.length} richiesta'
                      '${pendingBySalon.length == 1 ? '' : 'e'} in attesa di approvazione.',
                ),
              if (approvedSalonIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                _StatusInfoBanner(
                  icon: Icons.verified_rounded,
                  color: scheme.primary,
                  message:
                      'Accesso attivo per ${approvedSalonIds.length} salone'
                      '${approvedSalonIds.length == 1 ? '' : 'i'}.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enterSalon(BuildContext context, String? salonId) async {
    if (salonId == null || salonId.isEmpty) {
      return;
    }
    ref.read(sessionControllerProvider.notifier).setSalon(salonId);
    if (!mounted) {
      return;
    }
    context.go('/client/dashboard');
  }

  Future<void> _startRequestFlow(
    BuildContext context,
    Salon salon,
    AppUser? user,
  ) async {
    final data = ref.read(appDataProvider);
    final registrationDraft = ref.read(clientRegistrationDraftProvider);
    final registrationSettings = salon.clientRegistration;
    final clients = data.clients;
    final session = ref.read(sessionControllerProvider);
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

    final initialAddress = existingClient?.address ?? '';
    final initialProfession = existingClient?.profession ?? '';
    final initialNotes = existingClient?.notes ?? '';
    final initialReferral = existingClient?.referralSource ?? '';
    final initialBirthDate =
        registrationDraft?.dateOfBirth ??
        existingClient?.dateOfBirth ??
        user?.pendingDateOfBirth;

    final requestSent =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) {
            return _SalonAccessRequestSheet(
              salon: salon,
              initialFirstName: initialFirstName,
              initialLastName: initialLastName,
              initialEmail: initialEmail,
              initialPhone: initialPhone,
              initialAddress: initialAddress,
              initialProfession: initialProfession,
              initialReferralSource: initialReferral,
              initialNotes: initialNotes,
              initialBirthDate: initialBirthDate,
              settings: registrationSettings,
            );
          },
        ) ??
        false;
    if (!requestSent || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Richiesta inviata a ${salon.name}. Ti avviseremo appena verrà approvata.',
        ),
      ),
    );
  }

  (String, String) _splitName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return ('', '');
    }
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return (parts.first, '');
    }
    final first = parts.first;
    final last = parts.skip(1).join(' ');
    return (first, last);
  }
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({
    required this.salon,
    required this.isApproved,
    required this.pendingRequest,
    required this.rejectedRequest,
    required this.onRequestAccess,
    required this.onEnter,
  });

  final Salon salon;
  final bool isApproved;
  final SalonAccessRequest? pendingRequest;
  final SalonAccessRequest? rejectedRequest;
  final VoidCallback onRequestAccess;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitleStyle = theme.textTheme.bodyMedium;
    final status = _resolveStatus();
    final cardColor =
        status == _CardStatus.approved
            ? scheme.primaryContainer
            : status == _CardStatus.pending
            ? scheme.surfaceVariant
            : scheme.surface;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            if (salon.city.isNotEmpty || salon.address.isNotEmpty) ...[
              Row(
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
              const SizedBox(height: 10),
            ],
            const Spacer(),
            Row(
              children: [
                if (status == _CardStatus.approved)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: onEnter,
                      label: const Text('Entra'),
                    ),
                  )
                else if (status == _CardStatus.pending)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.hourglass_top_rounded),
                      onPressed: null,
                      label: const Text('Richiesta in attesa'),
                    ),
                  )
                else if (status == _CardStatus.rejected)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.info_outline_rounded),
                      onPressed: onRequestAccess,
                      label: const Text('Richiedi nuovamente'),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: onRequestAccess,
                      label: const Text('Richiedi accesso'),
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
      case _CardStatus.approved:
        background = scheme.primary;
        foreground = scheme.onPrimary;
        label = 'Accesso attivo';
        icon = Icons.verified_rounded;
        break;
      case _CardStatus.pending:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        label = 'In attesa';
        icon = Icons.hourglass_bottom_rounded;
        break;
      case _CardStatus.rejected:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        label = 'Richiesta respinta';
        icon = Icons.block_rounded;
        break;
      case _CardStatus.available:
        background = scheme.surfaceVariant;
        foreground = scheme.onSurfaceVariant;
        label = 'Disponibile';
        icon = Icons.meeting_room_outlined;
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
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
    required this.initialAddress,
    required this.initialProfession,
    required this.initialReferralSource,
    required this.initialNotes,
    required this.initialBirthDate,
  });

  final Salon salon;
  final ClientRegistrationSettings settings;
  final String initialFirstName;
  final String initialLastName;
  final String initialEmail;
  final String initialPhone;
  final String initialAddress;
  final String initialProfession;
  final String initialReferralSource;
  final String initialNotes;
  final DateTime? initialBirthDate;

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
  late final TextEditingController _addressController;
  late final TextEditingController _professionController;
  late final TextEditingController _notesController;
  late final TextEditingController _referralController;
  late final TextEditingController _birthDateController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _birthDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialFirstName);
    _lastNameController = TextEditingController(text: widget.initialLastName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
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
                  'Compila i dati richiesti. Il salone potrà chiederti conferma prima di approvare l\'accesso.',
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
                    if (!RegExp(
                      r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$',
                    ).hasMatch(text)) {
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
                if (requiresAddress) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessione non valida. Effettua di nuovo l\'accesso.'),
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final extraData = <String, dynamic>{};
    if (_addressController.text.trim().isNotEmpty) {
      extraData['address'] = _addressController.text.trim();
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
        final updatedUser = AppUser(
          uid: user.uid,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossibile inviare la richiesta: ${error.toString()}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
