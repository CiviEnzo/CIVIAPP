import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_app_movement.dart';
import 'package:you_book/domain/entities/client_import.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/auth_repository.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_import_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_save_feedback.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_tab.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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
  int? _clientDetailInitialTabIndex;
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
    final hasGeneralQuery = ClientSearchUtils.hasMinimumGeneralQueryLength(
      general,
    );
    final hasClientNumber = ClientSearchUtils.hasClientNumberQuery(
      clientNumber,
    );
    final hasInput = hasGeneralQuery || hasClientNumber;
    final hasShortGeneralQuery = ClientSearchUtils.hasShortGeneralQuery(
      generalQuery: general,
      clientNumberQuery: clientNumber,
    );

    setState(() {
      _generalQuery = hasGeneralQuery ? general.toLowerCase() : '';
      _clientNumberQuery = clientNumber.toLowerCase();
      _searchPerformed = hasInput;
      _searchError =
          hasShortGeneralQuery
              ? ClientSearchUtils.minSearchCriteriaMessage
              : showErrorWhenEmpty && !hasInput
              ? 'Inserisci almeno un criterio di ricerca'
              : null;
      if (!hasInput) {
        _selectedClientId = null;
        _clientDetailInitialTabIndex = null;
      }
    });
  }

  void _clearSearch() {
    _generalQueryController.clear();
    _clientNumberController.clear();
    _performSearch(showErrorWhenEmpty: false);
  }

  Future<void> _handleClientTap(String clientId) async {
    final isCompact = isCompactClientLayout(context);
    if (isCompact) {
      await openClientDetailPage(
        context,
        clientId: clientId,
        initialTabIndex: 0,
        compactOnly: true,
      );
      return;
    }
    setState(() {
      _selectedClientId = _selectedClientId == clientId ? null : clientId;
      _clientDetailInitialTabIndex = null;
    });
  }

  void _clearSelectedClient() {
    if (_selectedClientId == null) {
      return;
    }
    setState(() {
      _selectedClientId = null;
      _clientDetailInitialTabIndex = null;
    });
  }

  Future<void> _openClientForm({
    required List<Salon> salons,
    required List<Client> clients,
    Client? existing,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Crea prima un salone per associare clienti.'),
        ),
      );
      return;
    }

    final result = await showAppModalSheet<Client>(
      context: context,
      includeCloseButton: false,
      desktopMaxWidth: 980,
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
    if (!mounted) {
      return;
    }

    setState(() => _isSavingClient = true);
    late Client savedClient;
    String? warningMessage;
    try {
      final saveResult = await ref
          .read(appDataProvider.notifier)
          .upsertClient(result);
      savedClient = saveResult.client;
      warningMessage = saveResult.warningMessage?.trim();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(formatClientSaveError(error))),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isSavingClient = false);
      }
    }

    if (!mounted) {
      return;
    }

    if (warningMessage != null && warningMessage.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(warningMessage)));
    }

    if (existing != null) {
      return;
    }

    final clientNumber = savedClient.clientNumber?.trim();
    if (clientNumber == null || clientNumber.isEmpty) {
      return;
    }

    _focusOnClient(savedClient);
  }

  void _focusOnClient(Client client) {
    setState(() {
      _generalQueryController.clear();
      _clientNumberController.text = client.clientNumber ?? '';
    });
    _performSearch(showErrorWhenEmpty: false);
    setState(() {
      _selectedClientId = client.id;
      _clientDetailInitialTabIndex = null;
    });
  }

  void _applyIntent(ClientsModuleIntent intent) {
    final general = intent.generalQuery?.trim() ?? '';
    final clientNumber = intent.clientNumber?.trim() ?? '';
    final hasGeneralQuery = general.length >= 3;
    final hasClientNumber = clientNumber.isNotEmpty;
    final hasInput =
        hasGeneralQuery || hasClientNumber || intent.clientId != null;

    if (_generalQueryController.text != general) {
      _generalQueryController.text = general;
    }
    if (_clientNumberController.text != clientNumber) {
      _clientNumberController.text = clientNumber;
    }

    setState(() {
      _generalQuery = hasGeneralQuery ? general.toLowerCase() : '';
      _clientNumberQuery = clientNumber.toLowerCase();
      _searchPerformed = hasInput;
      _searchError = null;
      _selectedClientId = intent.clientId;
      _clientDetailInitialTabIndex = intent.detailTabIndex;
    });
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

  bool _matchesGeneralQuery(Client client) {
    if (_generalQuery.isEmpty) {
      return true;
    }

    final tokens = _generalQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return true;
    }

    bool contains(String? value, String token) {
      final normalized = value?.trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) {
        return false;
      }
      return normalized.contains(token);
    }

    return tokens.every(
      (token) =>
          contains(client.fullName, token) ||
          contains(client.firstName, token) ||
          contains(client.lastName, token) ||
          contains(client.phone, token) ||
          contains(client.email, token) ||
          contains(client.clientNumber, token),
    );
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

  Widget _buildClientIdentity(BuildContext context, Client client) {
    final theme = Theme.of(context);
    final email = client.email?.trim();
    final clientNumber = client.clientNumber?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _displayName(client),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (clientNumber != null && clientNumber.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Cliente #$clientNumber',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          (email != null && email.isNotEmpty) ? email : 'Email non disponibile',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
      elevation: 0,
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    Text(
                      salonName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                    const SizedBox(height: 10),
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
              if (i != requests.length - 1) ...[
                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 16),
              ],
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
    final preview = _buildApprovalPreview(
      request,
      ref.read(appDataProvider).clients,
    );
    final blockingMessage = preview.blockingMessage;
    if (blockingMessage != null) {
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Contatti duplicati'),
              content: Text(blockingMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Ok'),
                ),
              ],
            ),
      );
      return;
    }
    final confirmed = await _confirmApproval(context, preview);
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _processingRequests.add(request.id));
    final messenger = ScaffoldMessenger.of(this.context);
    try {
      await ref
          .read(appDataProvider.notifier)
          .approveSalonAccessRequest(request: request);
      messenger.showAppSnackBar(
        SnackBar(content: Text(preview.successMessage)),
      );
    } catch (error) {
      messenger.showAppSnackBar(
        SnackBar(content: Text('Errore durante l\'approvazione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingRequests.remove(request.id));
      }
    }
  }

  Future<bool?> _confirmApproval(
    BuildContext context,
    _AccessRequestApprovalPreview preview,
  ) {
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Conferma approvazione'),
            content: Text(preview.confirmationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Approva'),
              ),
            ],
          ),
    );
  }

  _AccessRequestApprovalPreview _buildApprovalPreview(
    SalonAccessRequest request,
    List<Client> clients,
  ) {
    final salonClients = clients
        .where((client) => client.salonId == request.salonId)
        .toList(growable: false);
    final normalizedEmail = _normalizeEmail(request.email);
    final normalizedPhone = _normalizePhone(request.phone);
    final emailMatches =
        normalizedEmail == null
            ? const <Client>[]
            : salonClients
                .where(
                  (client) => _normalizeEmail(client.email) == normalizedEmail,
                )
                .toList(growable: false);
    final phoneMatches =
        normalizedPhone.isEmpty
            ? const <Client>[]
            : salonClients
                .where(
                  (client) => _normalizePhone(client.phone) == normalizedPhone,
                )
                .toList(growable: false);

    if (emailMatches.isNotEmpty && phoneMatches.isNotEmpty) {
      final phoneIds = phoneMatches.map((client) => client.id).toSet();
      final overlap = emailMatches
          .where((client) => phoneIds.contains(client.id))
          .toList(growable: false);
      if (overlap.isEmpty) {
        return _AccessRequestApprovalPreview.blocked(
          'Email e telefono risultano associati a clienti diversi. '
          'Correggi o unisci i clienti prima di approvare la richiesta.',
        );
      }
      return _AccessRequestApprovalPreview.existing(overlap.first);
    }

    final matchesById = <String, Client>{
      for (final client in emailMatches) client.id: client,
      for (final client in phoneMatches) client.id: client,
    };
    if (matchesById.isNotEmpty) {
      return _AccessRequestApprovalPreview.existing(matchesById.values.first);
    }
    return const _AccessRequestApprovalPreview.newClient();
  }

  static String? _normalizeEmail(Object? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
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
      messenger.showAppSnackBar(
        const SnackBar(content: Text('Richiesta rifiutata.')),
      );
    } catch (error) {
      messenger.showAppSnackBar(
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
          ..sort((a, b) {
            final lastNameCompare = a.lastName.toLowerCase().compareTo(
              b.lastName.toLowerCase(),
            );
            if (lastNameCompare != 0) {
              return lastNameCompare;
            }
            return a.firstName.toLowerCase().compareTo(
              b.firstName.toLowerCase(),
            );
          });
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
    final selectedClient =
        _selectedClientId == null
            ? null
            : filteredClients.firstWhereOrNull(
              (client) => client.id == _selectedClientId,
            );
    final showDetailOnly = selectedClient != null && _searchPerformed;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    final clientEntries = <_ClientTableEntry>[];
    if (_searchPerformed && !showDetailOnly && filteredClients.isNotEmpty) {
      final filteredClientIds =
          filteredClients.map((client) => client.id).toSet();
      final completedAppointmentsByClient = <String, List<Appointment>>{};
      for (final appointment in data.appointments) {
        if (widget.salonId != null && appointment.salonId != widget.salonId) {
          continue;
        }
        if (appointment.status != AppointmentStatus.completed) {
          continue;
        }
        if (!filteredClientIds.contains(appointment.clientId)) {
          continue;
        }
        completedAppointmentsByClient
            .putIfAbsent(appointment.clientId, () => <Appointment>[])
            .add(appointment);
      }

      final salesByClient = <String, List<Sale>>{};
      for (final sale in data.sales) {
        if (widget.salonId != null && sale.salonId != widget.salonId) {
          continue;
        }
        if (!filteredClientIds.contains(sale.clientId)) {
          continue;
        }
        salesByClient.putIfAbsent(sale.clientId, () => <Sale>[]).add(sale);
      }

      for (final client in filteredClients) {
        final completedVisits =
            completedAppointmentsByClient[client.id] ?? const <Appointment>[];
        DateTime? lastVisit;
        for (final appointment in completedVisits) {
          if (lastVisit == null || appointment.start.isAfter(lastVisit)) {
            lastVisit = appointment.start;
          }
        }
        final sales = salesByClient[client.id] ?? const <Sale>[];
        final totalSpent = sales.fold<double>(
          0,
          (sum, sale) => sum + sale.total,
        );
        clientEntries.add(
          _ClientTableEntry(
            client: client,
            visits: completedVisits.length,
            lastVisit: lastVisit,
            totalSpent: totalSpent,
          ),
        );
      }
    }

    final newClientsThisMonth =
        salonClients.where((client) {
          final createdAt = client.createdAt;
          return createdAt != null && !createdAt.isBefore(currentMonthStart);
        }).length;
    final activeAppClientIds = _collectActiveAppClientIds(
      salonClients: salonClients,
      clientAppMovements: data.clientAppMovements,
    );
    final appActiveClients = activeAppClientIds.length;
    final recentClients = [...salonClients]..sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    final latestClients = recentClients.take(20).toList();

    final pagePadding = EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width < 720 ? 12 : 16,
      16,
      MediaQuery.sizeOf(context).width < 720 ? 12 : 16,
      24,
    );

    final Widget searchTabContent =
        showDetailOnly
            ? ListView(
              padding: pagePadding,
              children: [_buildSelectedClientSection(client: selectedClient)],
            )
            : ListView(
              padding: pagePadding,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 1080;
                    final generalField = TextField(
                      key: const ValueKey('clients_search_general_field'),
                      controller: _generalQueryController,
                      textInputAction: TextInputAction.search,
                      onChanged:
                          (_) => _performSearch(showErrorWhenEmpty: false),
                      onSubmitted: (_) => _performSearch(),
                      decoration: InputDecoration(
                        hintText: 'Cerca cliente...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.4,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    );

                    final numberField = TextField(
                      controller: _clientNumberController,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.number,
                      onChanged:
                          (_) => _performSearch(showErrorWhenEmpty: false),
                      onSubmitted: (_) => _performSearch(),
                      decoration: InputDecoration(
                        hintText: 'Numero cliente',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.4,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    );

                    final filterButton = Builder(
                      builder:
                          (tabContext) => OutlinedButton.icon(
                            onPressed:
                                () => DefaultTabController.of(
                                  tabContext,
                                ).animateTo(1),
                            icon: const Icon(Icons.filter_alt_outlined),
                            label: const Text('Filtri'),
                          ),
                    );

                    final exportButton = OutlinedButton.icon(
                      onPressed:
                          !_searchPerformed || clientEntries.isEmpty
                              ? null
                              : () => _exportClients(
                                clientEntries,
                                activeAppClientIds,
                              ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Esporta'),
                    );

                    final clearButton =
                        _generalQuery.isEmpty && _clientNumberQuery.isEmpty
                            ? null
                            : TextButton.icon(
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Azzera'),
                            );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          generalField,
                          const SizedBox(height: 12),
                          numberField,
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              filterButton,
                              exportButton,
                              if (clearButton != null) clearButton,
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(flex: 5, child: generalField),
                        const SizedBox(width: 12),
                        SizedBox(width: 220, child: numberField),
                        const SizedBox(width: 12),
                        filterButton,
                        const SizedBox(width: 12),
                        exportButton,
                        if (clearButton != null) ...[
                          const SizedBox(width: 8),
                          clearButton,
                        ],
                      ],
                    );
                  },
                ),
                if (_searchError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _searchError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final hideSummaryCards =
                        _searchPerformed && constraints.maxWidth < 760;
                    if (hideSummaryCards) {
                      return const SizedBox(height: 16);
                    }

                    final isCompact = constraints.maxWidth < 760;
                    final cardWidth =
                        isCompact
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 24) / 3;
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        Wrap(
                          key: const ValueKey('clients_search_summary_cards'),
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _ClientsSummaryCard(
                              width: cardWidth,
                              title: 'Clienti Totali',
                              value: salonClients.length.toString(),
                            ),
                            _ClientsSummaryCard(
                              width: cardWidth,
                              title: 'Nuovi (Mese)',
                              value: '+$newClientsThisMonth',
                              valueColor: const Color(0xFF16A34A),
                            ),
                            _ClientsSummaryCard(
                              width: cardWidth,
                              title: 'App Attiva',
                              value: appActiveClients.toString(),
                              valueColor: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
                if (!_searchPerformed)
                  _buildPlaceholder(
                    context: context,
                    icon: Icons.person_search_rounded,
                    title: 'Cerca un cliente',
                    message:
                        salonClients.isEmpty
                            ? 'Non risultano clienti registrati per questo salone. Aggiungi un nuovo cliente per iniziare.'
                            : 'Inserisci nome, contatto o numero cliente per visualizzare la lista clienti.',
                  )
                else if (clientEntries.isEmpty)
                  _buildPlaceholder(
                    context: context,
                    icon: Icons.person_off_rounded,
                    title: 'Nessun risultato',
                    message:
                        salonClients.isEmpty
                            ? 'Non sono presenti clienti registrati per questo salone.'
                            : 'Nessun cliente trovato. Modifica i criteri di ricerca e riprova.',
                  )
                else
                  _buildClientTableCard(
                    context: context,
                    entries: clientEntries,
                    dateFormat: dateFormat,
                    activeAppClientIds: activeAppClientIds,
                  ),
              ],
            );

    final requestsTab = ListView(
      padding: pagePadding,
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
      for (var i = 0; i < latestClients.length; i++) {
        final client = latestClients[i];
        final created = client.createdAt;
        final subtitle =
            created != null
                ? 'Registrato il ${dateFormat.format(created)}'
                : 'Data registrazione non disponibile';
        latestChildren.add(
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 520;
                  final avatar = CircleAvatar(
                    radius: 22,
                    child: Text(_clientInitial(client)),
                  );
                  final info = Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              _displayName(client),
                              style: theme.textTheme.titleMedium,
                            ),
                            if (client.clientNumber != null)
                              Text(
                                'N° ${client.clientNumber}',
                                style: theme.textTheme.titleMedium,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                  final action = Builder(
                    builder:
                        (tabContext) => OutlinedButton.icon(
                          onPressed: () async {
                            DefaultTabController.of(tabContext).animateTo(0);
                            final isCompact = isCompactClientLayout(context);
                            if (isCompact) {
                              await _handleClientTap(client.id);
                            } else {
                              _focusOnClient(client);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Apri'),
                        ),
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [avatar, const SizedBox(width: 12), info],
                        ),
                        const SizedBox(height: 12),
                        action,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      info,
                      const SizedBox(width: 8),
                      action,
                    ],
                  );
                },
              ),
            ),
          ),
        );
        if (i != latestClients.length - 1) {
          latestChildren.add(const SizedBox(height: 12));
        }
      }
    }

    final latestTab = ListView(padding: pagePadding, children: latestChildren);

    return DefaultTabController(
      length: 4,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: pagePadding.copyWith(bottom: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 780;
                    final addButton = FilledButton.icon(
                      onPressed:
                          () => _openClientForm(
                            salons: salons,
                            clients: data.clients,
                          ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Aggiungi Cliente'),
                    );

                    if (isCompact) {
                      return SizedBox(width: double.infinity, child: addButton);
                    }

                    return Row(children: [const Spacer(), addButton]);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pagePadding.left,
                  0,
                  pagePadding.right,
                  12,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: theme.colorScheme.onPrimaryContainer,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(icon: Icon(Icons.search_rounded), text: 'Ricerca'),
                      Tab(
                        icon: Icon(Icons.filter_alt_rounded),
                        text: 'Ricerca avanzata',
                      ),
                      Tab(
                        icon: Icon(Icons.how_to_reg_outlined),
                        text: 'Richieste',
                      ),
                      Tab(icon: Icon(Icons.fiber_new_rounded), text: 'Ultimi'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    searchTabContent,
                    AdvancedSearchTab(
                      salonId: widget.salonId,
                      onCreateClient:
                          () => _openClientForm(
                            salons: salons,
                            clients: data.clients,
                          ),
                      onImportClients:
                          () => _openImport(
                            context,
                            ref,
                            salons: salons,
                            clients: data.clients,
                            defaultSalonId: widget.salonId,
                          ),
                      onEditClient:
                          (client) => _openClientForm(
                            salons: salons,
                            clients: data.clients,
                            existing: client,
                          ),
                      onSendInvite: _sendAccessLink,
                      isSendingInvite: _isSending,
                    ),
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
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportClients(
    List<_ClientTableEntry> entries,
    Set<String> activeAppClientIds,
  ) async {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Nessun cliente da esportare.')),
      );
      return;
    }
    final dateFormat = DateFormat('dd/MM/yyyy');
    final rows = <List<String>>[
      [
        'Numero cliente',
        'Nome',
        'Email',
        'Telefono',
        'Visite',
        'Ultima visita',
        'Spesa totale',
        'Stato app',
      ],
    ];
    for (final entry in entries) {
      rows.add([
        entry.client.clientNumber ?? '',
        _displayName(entry.client),
        entry.client.email ?? '',
        entry.client.phone,
        entry.visits.toString(),
        entry.lastVisit == null ? '' : dateFormat.format(entry.lastVisit!),
        entry.totalSpent.toStringAsFixed(2),
        _appStatusLabel(entry.client, activeAppClientIds),
      ]);
    }
    try {
      final converter = const ListToCsvConverter(fieldDelimiter: ';');
      final csv = converter.convert(rows);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'clienti_youbook_$timestamp.csv';
      final csvBytes = Uint8List.fromList(utf8.encode(csv));
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(csvBytes, mimeType: 'text/csv', name: fileName),
          ],
          subject: 'Esportazione clienti',
          text: 'File generato dal modulo clienti di youbook.',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile esportare i clienti: $error')),
      );
    }
  }

  Widget _buildClientTableCard({
    required BuildContext context,
    required List<_ClientTableEntry> entries,
    required DateFormat dateFormat,
    required Set<String> activeAppClientIds,
  }) {
    final theme = Theme.of(context);
    final headerBackground = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.72);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 920;
        if (isCompact) {
          return Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  decoration: BoxDecoration(
                    color: headerBackground,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Elenco clienti',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nessun cliente trovato per i filtri correnti.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        _buildCompactClientCard(
                          context: context,
                          entry: entries[i],
                          dateFormat: dateFormat,
                          activeAppClientIds: activeAppClientIds,
                        ),
                        if (i != entries.length - 1)
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          );
        }

        final tableWidth =
            constraints.maxWidth < 1040 ? 1040.0 : constraints.maxWidth;

        return Card(
          elevation: 0,
          color: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    Container(
                      color: headerBackground,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: const [
                          _TableHeaderCell(label: 'Cliente', flex: 4),
                          _TableHeaderCell(label: 'Telefono', flex: 3),
                          _TableHeaderCell(label: 'Visite', flex: 2),
                          _TableHeaderCell(label: 'Ultima Visita', flex: 3),
                          _TableHeaderCell(label: 'Spesa Totale', flex: 3),
                          _TableHeaderCell(label: 'App', flex: 3),
                          _TableHeaderCell(label: 'Azioni', flex: 2),
                        ],
                      ),
                    ),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'Nessun cliente trovato per i filtri correnti.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < entries.length; i++) ...[
                            _buildDesktopClientRow(
                              context: context,
                              entry: entries[i],
                              dateFormat: dateFormat,
                              activeAppClientIds: activeAppClientIds,
                            ),
                            if (i != entries.length - 1)
                              Divider(
                                height: 1,
                                color: theme.colorScheme.outlineVariant,
                              ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopClientRow({
    required BuildContext context,
    required _ClientTableEntry entry,
    required DateFormat dateFormat,
    required Set<String> activeAppClientIds,
  }) {
    final theme = Theme.of(context);
    final client = entry.client;
    final isSelected = client.id == _selectedClientId;
    final hasInstalledApp = _hasInstalledApp(client, activeAppClientIds);
    final emailAvailable = client.email?.trim().isNotEmpty == true;
    final isSending = _isSending(client.id);
    final canSendAppLink = emailAvailable && !isSending && !hasInstalledApp;

    return Material(
      color:
          isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
              : Colors.transparent,
      child: InkWell(
        onTap: () => _handleClientTap(client.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(flex: 4, child: _buildClientIdentity(context, client)),
              Expanded(
                flex: 3,
                child: Text(client.phone, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${entry.visits}',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  entry.lastVisit == null
                      ? '—'
                      : dateFormat.format(entry.lastVisit!),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _formatCurrency(entry.totalSpent),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildAppStatusChip(context, client, activeAppClientIds),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Apri scheda',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _handleClientTap(client.id),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip:
                          hasInstalledApp
                              ? 'App gia scaricata'
                              : emailAvailable
                              ? 'Invia link app'
                              : 'Email non disponibile',
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          canSendAppLink ? () => _sendAccessLink(client) : null,
                      icon:
                          isSending
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(
                                Icons.mail_outline_rounded,
                                size: 18,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactClientCard({
    required BuildContext context,
    required _ClientTableEntry entry,
    required DateFormat dateFormat,
    required Set<String> activeAppClientIds,
  }) {
    final theme = Theme.of(context);
    final client = entry.client;
    final isSelected = client.id == _selectedClientId;
    final hasInstalledApp = _hasInstalledApp(client, activeAppClientIds);
    final emailAvailable = client.email?.trim().isNotEmpty == true;
    final isSending = _isSending(client.id);
    final canSendAppLink = emailAvailable && !isSending && !hasInstalledApp;

    Widget infoRow(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: valueColor == null ? null : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color:
          isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.26)
              : Colors.transparent,
      child: InkWell(
        onTap: () => _handleClientTap(client.id),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildClientIdentity(context, client)),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Apri scheda',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _handleClientTap(client.id),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip:
                            hasInstalledApp
                                ? 'App gia scaricata'
                                : emailAvailable
                                ? 'Invia link app'
                                : 'Email non disponibile',
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            canSendAppLink
                                ? () => _sendAccessLink(client)
                                : null,
                        icon:
                            isSending
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 18,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
              infoRow('Telefono', client.phone),
              infoRow('Visite', '${entry.visits}'),
              infoRow(
                'Ultima visita',
                entry.lastVisit == null
                    ? '—'
                    : dateFormat.format(entry.lastVisit!),
              ),
              infoRow(
                'Spesa totale',
                _formatCurrency(entry.totalSpent),
                valueColor: theme.colorScheme.primary,
              ),
              infoRow('App', _appStatusLabel(client, activeAppClientIds)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedClientSection({required Client client}) {
    return ClientDetailView(
      key: ValueKey(
        'client-detail-${client.id}-${_clientDetailInitialTabIndex ?? 0}',
      ),
      clientId: client.id,
      showAppBar: false,
      onClose: _clearSelectedClient,
      initialTabIndex: _clientDetailInitialTabIndex ?? 0,
    );
  }

  String _formatCurrency(double value) {
    final decimalDigits = value == value.roundToDouble() ? 0 : 2;
    return NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: decimalDigits,
    ).format(value);
  }

  Set<String> _collectActiveAppClientIds({
    required Iterable<Client> salonClients,
    required Iterable<ClientAppMovement> clientAppMovements,
  }) {
    final allowedClientIds = salonClients.map((client) => client.id).toSet();
    final activeClientIds = <String>{};

    for (final client in salonClients) {
      if (client.fcmTokens.isNotEmpty) {
        activeClientIds.add(client.id);
      }
    }

    for (final movement in clientAppMovements) {
      if (widget.salonId != null && movement.salonId != widget.salonId) {
        continue;
      }
      if (!allowedClientIds.contains(movement.clientId)) {
        continue;
      }
      activeClientIds.add(movement.clientId);
    }

    return activeClientIds;
  }

  bool _hasInstalledApp(Client client, Set<String> activeAppClientIds) {
    return activeAppClientIds.contains(client.id);
  }

  bool _hasInvitationLink(Client client) {
    return client.onboardingStatus == ClientOnboardingStatus.invitationSent ||
        client.invitationSentAt != null;
  }

  String _appStatusLabel(Client client, Set<String> activeAppClientIds) {
    if (_hasInstalledApp(client, activeAppClientIds)) {
      return 'Scaricata';
    }
    if (_hasInvitationLink(client)) {
      return 'Link inviato';
    }
    return 'Non scaricata';
  }

  Widget _buildAppStatusChip(
    BuildContext context,
    Client client,
    Set<String> activeAppClientIds,
  ) {
    final theme = Theme.of(context);
    final hasInstalledApp = _hasInstalledApp(client, activeAppClientIds);
    final hasInvitationLink = _hasInvitationLink(client);

    late final Color background;
    late final Color foreground;
    late final IconData icon;

    if (hasInstalledApp) {
      background = const Color(0xFFE7F6EC);
      foreground = const Color(0xFF166534);
      icon = Icons.download_done_rounded;
    } else if (hasInvitationLink) {
      background = const Color(0xFFFFF4DB);
      foreground = const Color(0xFF92400E);
      icon = Icons.mark_email_unread_outlined;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = theme.colorScheme.onSurfaceVariant;
      icon = Icons.phone_iphone_outlined;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Text(
              _appStatusLabel(client, activeAppClientIds),
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSending(String clientId) => _sendingInvites.contains(clientId);

  Future<void> _sendAccessLink(Client client) async {
    final email = client.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      ).showAppSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text("Errore durante l'invio del link: $error")),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingInvites.remove(client.id));
      }
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
    ScaffoldMessenger.of(context).showAppSnackBar(
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
  if (!context.mounted) {
    return;
  }
  if (result == null) {
    return;
  }
  final imported = result.importedCount;
  final failed = result.failedCount;
  final message =
      failed > 0
          ? 'Import completato: $imported clienti importati, $failed non importati.'
          : '$imported clienti importati correttamente.';
  ScaffoldMessenger.of(
    context,
  ).showAppSnackBar(SnackBar(content: Text(message)));
}

class _ClientTableEntry {
  const _ClientTableEntry({
    required this.client,
    required this.visits,
    required this.lastVisit,
    required this.totalSpent,
  });

  final Client client;
  final int visits;
  final DateTime? lastVisit;
  final double totalSpent;
}

class _AccessRequestApprovalPreview {
  const _AccessRequestApprovalPreview.newClient()
    : client = null,
      blockingMessage = null;

  const _AccessRequestApprovalPreview.existing(this.client)
    : blockingMessage = null;

  const _AccessRequestApprovalPreview.blocked(this.blockingMessage)
    : client = null;

  final Client? client;
  final String? blockingMessage;

  String get confirmationMessage {
    final existing = client;
    if (existing == null) {
      return 'La richiesta verra approvata e verra creato un nuovo cliente nel salone. '
          'Il cliente potra completare l\'attivazione dall\'app.';
    }
    return 'La richiesta verra approvata e collegata al cliente esistente '
        '${existing.fullName}. I dati del cliente potranno essere aggiornati con i contatti inviati nella richiesta.';
  }

  String get successMessage {
    final existing = client;
    if (existing == null) {
      return 'Richiesta approvata e nuovo cliente creato.';
    }
    return 'Richiesta approvata e collegata a ${existing.fullName}.';
  }
}

class _ClientsSummaryCard extends StatelessWidget {
  const _ClientsSummaryCard({
    required this.width,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final double width;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell({required this.label, required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
