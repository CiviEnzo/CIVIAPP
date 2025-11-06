import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_import.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/auth_repository.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_import_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ClientsModule extends ConsumerStatefulWidget {
  const ClientsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<ClientsModule> createState() => _ClientsModuleState();
}

class _ClientsModuleState extends ConsumerState<ClientsModule> {
  final Set<String> _sendingInvites = <String>{};
  final Set<String> _processingRequests = <String>{};
  final TextEditingController _generalQueryController = TextEditingController();
  final TextEditingController _clientNumberController = TextEditingController();
  ProviderSubscription<ClientsModuleIntent?>? _intentSubscription;

  String _generalQuery = '';
  String _clientNumberQuery = '';
  bool _searchPerformed = false;
  String? _searchError;
  String? _selectedClientId;
  bool _isSavingClient = false;

  @override
  void initState() {
    super.initState();
    _intentSubscription = ref.listenManual<ClientsModuleIntent?>(
      clientsModuleIntentProvider,
      (previous, next) {
        final intent = next;
        if (intent == null) {
          return;
        }
        _applyIntent(intent);
        ref.read(clientsModuleIntentProvider.notifier).state = null;
      },
    );
    final initialIntent = ref.read(clientsModuleIntentProvider);
    if (initialIntent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyIntent(initialIntent);
        ref.read(clientsModuleIntentProvider.notifier).state = null;
      });
    }
  }

  @override
  void dispose() {
    _generalQueryController.dispose();
    _clientNumberController.dispose();
    _intentSubscription?.close();
    super.dispose();
  }

  void _performSearch({bool showErrorWhenEmpty = true}) {
    final general = _generalQueryController.text.trim();
    final clientNumber = _clientNumberController.text.trim();
    final hasInput = general.isNotEmpty || clientNumber.isNotEmpty;

    setState(() {
      _generalQuery = general.toLowerCase();
      _clientNumberQuery = clientNumber.toLowerCase();
      _searchPerformed = hasInput;
      _searchError =
          showErrorWhenEmpty && !hasInput
              ? 'Inserisci almeno un criterio di ricerca'
              : null;
      if (!hasInput) {
        _selectedClientId = null;
      }
    });
  }

  void _clearSearch() {
    _generalQueryController.clear();
    _clientNumberController.clear();
    _performSearch(showErrorWhenEmpty: false);
  }

  void _handleClientTap(String clientId) {
    setState(() {
      _selectedClientId = _selectedClientId == clientId ? null : clientId;
    });
  }

  void _clearSelectedClient() {
    if (_selectedClientId == null) {
      return;
    }
    setState(() => _selectedClientId = null);
  }

  Future<void> _openClientForm({
    required List<Salon> salons,
    required List<Client> clients,
    Client? existing,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea prima un salone per associare clienti.'),
        ),
      );
      return;
    }

    final result = await showAppModalSheet<Client>(
      context: context,
      builder:
          (ctx) => ClientFormSheet(
            salons: salons,
            clients: clients,
            defaultSalonId: widget.salonId,
            initial: existing,
          ),
    );
    if (result == null) {
      return;
    }

    setState(() => _isSavingClient = true);
    Client? updated;
    try {
      await ref.read(appDataProvider.notifier).upsertClient(result);
      if (!mounted) {
        return;
      }
      if (existing == null) {
        updated = ref
            .read(appDataProvider)
            .clients
            .firstWhereOrNull((client) => client.id == result.id);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $error')),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isSavingClient = false);
      }
    }

    if (!mounted || existing != null || updated == null) {
      return;
    }

    final clientNumber = updated.clientNumber?.trim();
    if (clientNumber == null || clientNumber.isEmpty) {
      return;
    }

    _focusOnClient(updated);
  }

  void _focusOnClient(Client client) {
    setState(() {
      _generalQueryController.clear();
      _clientNumberController.text = client.clientNumber ?? '';
    });
    _performSearch(showErrorWhenEmpty: false);
    setState(() => _selectedClientId = client.id);
  }

  void _applyIntent(ClientsModuleIntent intent) {
    final general = intent.generalQuery?.trim() ?? '';
    final clientNumber = intent.clientNumber?.trim() ?? '';
    final hasInput =
        general.isNotEmpty ||
        clientNumber.isNotEmpty ||
        intent.clientId != null;

    if (_generalQueryController.text != general) {
      _generalQueryController.text = general;
    }
    if (_clientNumberController.text != clientNumber) {
      _clientNumberController.text = clientNumber;
    }

    setState(() {
      _generalQuery = general.toLowerCase();
      _clientNumberQuery = clientNumber.toLowerCase();
      _searchPerformed = hasInput;
      _searchError = null;
      _selectedClientId = intent.clientId;
    });
  }

  bool _matchesGeneralQuery(Client client) {
    if (_generalQuery.isEmpty) {
      return true;
    }
    bool contains(String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) {
        return false;
      }
      return normalized.toLowerCase().contains(_generalQuery);
    }

    return contains(client.fullName) ||
        contains(client.firstName) ||
        contains(client.lastName) ||
        contains(client.phone) ||
        contains(client.email);
  }

  bool _matchesClientNumber(Client client) {
    if (_clientNumberQuery.isEmpty) {
      return true;
    }
    final number = client.clientNumber;
    if (number == null) {
      return false;
    }
    return number.toLowerCase() == _clientNumberQuery;
  }

  String _displayName(Client client) {
    final first = client.firstName.trim();
    final last = client.lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '$first $last';
    }
    if (first.isNotEmpty) {
      return first;
    }
    if (last.isNotEmpty) {
      return last;
    }
    return 'Cliente senza nome';
  }

  String _clientInitial(Client client) {
    final first = client.firstName.trim();
    if (first.isNotEmpty) {
      final value = first.characters.firstOrNull;
      if (value != null && value.isNotEmpty) {
        return value.toUpperCase();
      }
    }
    final last = client.lastName.trim();
    if (last.isNotEmpty) {
      final value = last.characters.firstOrNull;
      if (value != null && value.isNotEmpty) {
        return value.toUpperCase();
      }
    }
    return '?';
  }

  Widget _buildPlaceholder({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessRequestsCard({
    required BuildContext context,
    required List<SalonAccessRequest> requests,
    required Map<String, Salon> salonLookup,
  }) {
    final theme = Theme.of(context);
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateFormat = DateFormat('dd/MM/yyyy');

    Widget buildInfoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }

    return Card(
      color: theme.colorScheme.surface,
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Richieste di accesso',
                  style: theme.textTheme.titleMedium,
                ),
                Chip(
                  avatar: const Icon(Icons.hourglass_empty, size: 18),
                  label: Text('${requests.length} in attesa'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < requests.length; i++) ...[
              () {
                final request = requests[i];
                final salonName =
                    salonLookup[request.salonId]?.name ?? request.salonId;
                final createdLabel =
                    request.createdAt != null
                        ? dateTimeFormat.format(request.createdAt!)
                        : 'Data non disponibile';
                final dateOfBirthLabel =
                    request.dateOfBirth != null
                        ? dateFormat.format(request.dateOfBirth!)
                        : null;
                final isProcessing = _processingRequests.contains(request.id);
                final extra = request.extraData;
                final genderCode = _stringOrNull(extra['gender']);
                final gender = _genderLabel(genderCode);
                final address = _stringOrNull(extra['address']);
                final profession = _stringOrNull(extra['profession']);
                final referral = _stringOrNull(extra['referralSource']);
                final notes = _stringOrNull(extra['notes']);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.firstName} ${request.lastName}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(salonName, style: theme.textTheme.bodyMedium),
                    buildInfoRow('Email', request.email),
                    buildInfoRow('Telefono', request.phone),
                    buildInfoRow('Creata il', createdLabel),
                    if (dateOfBirthLabel != null)
                      buildInfoRow('Data di nascita', dateOfBirthLabel),
                    if (gender != null) buildInfoRow('Sesso', gender),
                    if (address != null)
                      buildInfoRow('Citta di residenza', address),
                    if (profession != null)
                      buildInfoRow('Professione', profession),
                    if (referral != null)
                      buildInfoRow('Come ci ha conosciuto', referral),
                    if (notes != null) buildInfoRow('Note', notes),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              isProcessing
                                  ? null
                                  : () => _approveRequest(context, request),
                          icon:
                              isProcessing
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.check_circle_outline),
                          label: const Text('Approva'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              isProcessing
                                  ? null
                                  : () => _rejectRequest(context, request),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Rifiuta'),
                        ),
                      ],
                    ),
                  ],
                );
              }(),
              if (i != requests.length - 1) const Divider(),
              if (i != requests.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    BuildContext context,
    SalonAccessRequest request,
  ) async {
    if (_processingRequests.contains(request.id)) {
      return;
    }
    setState(() => _processingRequests.add(request.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(appDataProvider.notifier)
          .approveSalonAccessRequest(request: request);
      messenger.showSnackBar(
        const SnackBar(content: Text('Richiesta approvata.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante l\'approvazione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingRequests.remove(request.id));
      }
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    SalonAccessRequest request,
  ) async {
    if (_processingRequests.contains(request.id)) {
      return;
    }
    setState(() => _processingRequests.add(request.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(appDataProvider.notifier)
          .rejectSalonAccessRequest(request: request);
      messenger.showSnackBar(
        const SnackBar(content: Text('Richiesta rifiutata.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante il rifiuto: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingRequests.remove(request.id));
      }
    }
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _genderLabel(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    switch (code.trim().toLowerCase()) {
      case 'male':
        return 'Uomo';
      case 'female':
        return 'Donna';
      case 'other':
        return 'Altro/Non specificato';
      default:
        return 'Altro/Non specificato';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final salonClients =
        data.clients
            .where(
              (client) =>
                  widget.salonId == null || client.salonId == widget.salonId,
            )
            .toList()
          ..sort((a, b) => a.lastName.compareTo(b.lastName));
    final filteredClients =
        _searchPerformed
            ? salonClients
                .where(
                  (client) =>
                      _matchesGeneralQuery(client) &&
                      _matchesClientNumber(client),
                )
                .toList()
            : <Client>[];
    final theme = Theme.of(context);
    final salonLookup = {for (final salon in salons) salon.id: salon};
    final pendingRequests =
        data.salonAccessRequests
            .where(
              (request) =>
                  request.status == SalonAccessRequestStatus.pending &&
                  (widget.salonId == null || request.salonId == widget.salonId),
            )
            .toList()
          ..sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });

    final children = <Widget>[
      Card(
        color: theme.colorScheme.surface,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ricerca cliente', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _generalQueryController,
                decoration: const InputDecoration(
                  labelText: 'Nome, cognome, telefono, email',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => _performSearch(showErrorWhenEmpty: false),
                onSubmitted: (_) => _performSearch(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientNumberController,
                decoration: const InputDecoration(
                  labelText: 'Numero cliente',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => _performSearch(showErrorWhenEmpty: false),
                onSubmitted: (_) => _performSearch(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _performSearch,
                    icon: const Icon(Icons.manage_search_rounded),
                    label: const Text('Cerca'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Azzera'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        () => _openClientForm(
                          salons: salons,
                          clients: data.clients,
                        ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Nuovo cliente'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        () => _openImport(
                          context,
                          ref,
                          salons: salons,
                          clients: data.clients,
                          defaultSalonId: widget.salonId,
                        ),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Importa CSV'),
                  ),
                ],
              ),
              if (_searchError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _searchError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];

    if (false && pendingRequests.isNotEmpty) {
      children.add(
        _buildAccessRequestsCard(
          context: context,
          requests: pendingRequests,
          salonLookup: salonLookup,
        ),
      );
      children.add(const SizedBox(height: 16));
    }

    if (!_searchPerformed) {
      final message =
          salonClients.isEmpty
              ? 'Non risultano clienti registrati per questo salone. Aggiungi un nuovo cliente per iniziare.'
              : 'Inserisci almeno un criterio e avvia la ricerca per visualizzare la lista clienti.';
      children.add(
        _buildPlaceholder(
          context: context,
          icon: Icons.person_search_rounded,
          title: 'Cerca un cliente',
          message: message,
        ),
      );
    } else if (filteredClients.isEmpty) {
      final message =
          salonClients.isEmpty
              ? 'Non sono presenti clienti registrati per questo salone.'
              : 'Nessun cliente trovato. Modifica i criteri di ricerca e riprova.';
      children.add(
        _buildPlaceholder(
          context: context,
          icon: Icons.person_off_rounded,
          title: 'Nessun risultato',
          message: message,
        ),
      );
    } else {
      final selectedClient =
          _selectedClientId == null
              ? null
              : filteredClients.firstWhereOrNull(
                (client) => client.id == _selectedClientId,
              );
      final clientsToRender =
          selectedClient != null ? [selectedClient] : filteredClients;

      for (var i = 0; i < clientsToRender.length; i++) {
        final client = clientsToRender[i];
        final appointments =
            data.appointments
                .where((appointment) => appointment.clientId == client.id)
                .length;
        final purchases =
            data.sales.where((sale) => sale.clientId == client.id).length;
        final isSelected = client.id == _selectedClientId;
        final emailAvailable = client.email != null && client.email!.isNotEmpty;
        final isSending = _isSending(client.id);
        children.add(
          Card(
            color:
                isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : theme.colorScheme.surface,
            elevation: 2,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _handleClientTap(client.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          child: Text(_clientInitial(client)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _displayName(client),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'N° ${client.clientNumber}',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone),
                                    SizedBox(width: 4),
                                    Text(
                                      client.phone,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _QuickStat(
                                      icon: Icons.event_available_rounded,
                                      label: 'Appuntamenti: $appointments',
                                    ),
                                    _QuickStat(
                                      icon: Icons.shopping_bag_outlined,
                                      label: 'Acquisti: $purchases',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.end,
                              children: [
                                _buildStatusChip(context, client),
                                FilledButton.tonalIcon(
                                  onPressed:
                                      emailAvailable && !isSending
                                          ? () => _sendAccessLink(client)
                                          : null,
                                  icon:
                                      isSending
                                          ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.mail_outline_rounded,
                                          ),
                                  label: Text(
                                    emailAvailable
                                        ? 'Invia link'
                                        : 'Email assente',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      () => _openClientForm(
                                        salons: salons,
                                        clients: data.clients,
                                        existing: client,
                                      ),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('Modifica'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Scheda completa aperta sotto.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _clearSelectedClient,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Chiudi scheda'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
        if (i != clientsToRender.length - 1) {
          children.add(const SizedBox(height: 12));
        }
      }
      if (selectedClient != null) {
        children.add(const SizedBox(height: 16));
        children.add(
          ClientDetailView(
            clientId: selectedClient.id,
            showAppBar: false,
            onClose: _clearSelectedClient,
          ),
        );
      }
    }

    // Ultimi clienti (ordinati per data di creazione desc, max 20)
    final recentClients = [...salonClients]
      ..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    final latestClients = recentClients.take(20).toList();

    final listView = ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );

    // Tab 2: richieste di accesso
    final requestsTab = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingRequests.isEmpty)
          _buildPlaceholder(
            context: context,
            icon: Icons.hourglass_empty_rounded,
            title: 'Nessuna richiesta',
            message: 'Al momento non ci sono richieste di accesso in attesa.',
          )
        else
          _buildAccessRequestsCard(
            context: context,
            requests: pendingRequests,
            salonLookup: salonLookup,
          ),
      ],
    );

    // Tab 3: ultimi clienti
    final List<Widget> latestChildren = [];
    if (latestClients.isEmpty) {
      latestChildren.add(
        _buildPlaceholder(
          context: context,
          icon: Icons.people_outline_rounded,
          title: 'Nessun cliente',
          message: 'Non sono presenti clienti registrati di recente.',
        ),
      );
    } else {
      final dateFmt = DateFormat('dd/MM/yyyy');
      for (var i = 0; i < latestClients.length; i++) {
        final client = latestClients[i];
        final created = client.createdAt;
        final subtitle = created != null
            ? 'Registrato il ${dateFmt.format(created)}'
            : 'Data registrazione non disponibile';
        latestChildren.add(
          Card(
            color: theme.colorScheme.surface,
            elevation: 2,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    child: Text(_clientInitial(client)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _displayName(client),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            if (client.clientNumber != null)
                              Text(
                                'N° ${client.clientNumber}',
                                style: theme.textTheme.titleMedium,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (tabCtx) => OutlinedButton.icon(
                      onPressed: () {
                        final controller = DefaultTabController.of(tabCtx);
                        controller?.index = 0;
                        _focusOnClient(client);
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Apri'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (i != latestClients.length - 1) {
          latestChildren.add(const SizedBox(height: 12));
        }
      }
    }
    final latestTab = ListView(
      padding: const EdgeInsets.all(16),
      children: latestChildren,
    );

    return DefaultTabController(
      length: 3,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Material(
                  color: Colors.transparent,
                  child: TabBar(
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(icon: Icon(Icons.search_rounded), text: 'Ricerca'),
                      Tab(icon: Icon(Icons.how_to_reg_outlined), text: 'Richieste'),
                      Tab(icon: Icon(Icons.fiber_new_rounded), text: 'Ultimi'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    listView,
                    requestsTab,
                    latestTab,
                  ],
                ),
              ),
            ],
          ),
          if (_isSavingClient)
            Positioned.fill(
              child: AbsorbPointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSending(String clientId) => _sendingInvites.contains(clientId);

  Future<void> _sendAccessLink(Client client) async {
    final email = client.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aggiungi un'email al profilo per inviare il link."),
        ),
      );
      return;
    }
    if (_sendingInvites.contains(client.id)) {
      return;
    }

    setState(() => _sendingInvites.add(client.id));
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .sendClientInviteEmail(email);
      final nextStatus =
          client.onboardingStatus == ClientOnboardingStatus.onboardingCompleted
              ? ClientOnboardingStatus.onboardingCompleted
              : ClientOnboardingStatus.invitationSent;
      final updatedClient = client.copyWith(
        onboardingStatus: nextStatus,
        invitationSentAt: DateTime.now(),
      );
      await ref.read(appDataProvider.notifier).upsertClient(updatedClient);

      if (!mounted) {
        return;
      }
      final message =
          outcome == ClientInviteOutcome.passwordReset
              ? "Link di reset inviato a $email"
              : "Invito di accesso inviato a $email";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante l'invio del link: $error")),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingInvites.remove(client.id));
      }
    }
  }

  Widget _buildStatusChip(BuildContext context, Client client) {
    final scheme = Theme.of(context).colorScheme;
    final status = client.onboardingStatus;

    late final Color background;
    late final Color foreground;
    late final IconData icon;

    switch (status) {
      case ClientOnboardingStatus.notSent:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurface;
        icon = Icons.hourglass_empty_rounded;
        break;
      case ClientOnboardingStatus.invitationSent:
        background = scheme.primary;
        foreground = scheme.onPrimary;
        icon = Icons.outgoing_mail;
        break;
      case ClientOnboardingStatus.firstLogin:
        background = scheme.tertiary;
        foreground = scheme.onTertiary;
        icon = Icons.login_rounded;
        break;
      case ClientOnboardingStatus.onboardingCompleted:
        background = scheme.secondary;
        foreground = scheme.onSecondary;
        icon = Icons.verified_rounded;
        break;
    }

    return Chip(
      backgroundColor: background,
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(_statusLabel(status), style: TextStyle(color: foreground)),
    );
  }

  String _statusLabel(ClientOnboardingStatus status) {
    switch (status) {
      case ClientOnboardingStatus.notSent:
        return "Non inviato";
      case ClientOnboardingStatus.invitationSent:
        return "Inviata";
      case ClientOnboardingStatus.firstLogin:
        return "Primo accesso";
      case ClientOnboardingStatus.onboardingCompleted:
        return "Onboarding completato";
    }
  }
}

Future<void> _openImport(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  required List<Client> clients,
  String? defaultSalonId,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea prima un salone per associare clienti.'),
      ),
    );
    return;
  }
  final result = await showAppModalSheet<ClientImportResult>(
    context: context,
    builder:
        (ctx) => ClientImportSheet(
          salons: salons,
          clients: clients,
          defaultSalonId: defaultSalonId,
        ),
  );
  if (result == null) {
    return;
  }
  final imported = result.importedCount;
  final failed = result.failedCount;
  final message =
      failed > 0
          ? 'Import completato: $imported clienti importati, $failed non importati.'
          : '$imported clienti importati correttamente.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
