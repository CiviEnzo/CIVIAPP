import 'package:flutter/material.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';

import 'client_search_utils.dart';

Future<Client?> showClientSearchSheet({
  required BuildContext context,
  required List<Client> clients,
  String title = 'Seleziona cliente',
  String? activeSalonId,
  String? selectedClientId,
  bool allowCreate = false,
  Future<Client?> Function()? onCreateRequested,
}) {
  return showAppModalSheet<Client>(
    context: context,
    includeCloseButton: false,
    desktopMaxWidth: 920,
    preset: AppModalSheetPreset.wide,
    builder:
        (_) => ClientSearchSheet(
          clients: clients,
          title: title,
          activeSalonId: activeSalonId,
          selectedClientId: selectedClientId,
          allowCreate: allowCreate,
          onCreateRequested: onCreateRequested,
        ),
  );
}

class ClientSearchSheet extends StatefulWidget {
  const ClientSearchSheet({
    super.key,
    required this.clients,
    this.title = 'Seleziona cliente',
    this.activeSalonId,
    this.selectedClientId,
    this.allowCreate = false,
    this.onCreateRequested,
  });

  final List<Client> clients;
  final String title;
  final String? activeSalonId;
  final String? selectedClientId;
  final bool allowCreate;
  final Future<Client?> Function()? onCreateRequested;

  @override
  State<ClientSearchSheet> createState() => _ClientSearchSheetState();
}

class _ClientSearchSheetState extends State<ClientSearchSheet> {
  final TextEditingController _generalQueryController = TextEditingController();
  final TextEditingController _clientNumberController = TextEditingController();

  List<Client> _results = const <Client>[];
  bool _creatingClient = false;

  String get _generalQuery => _generalQueryController.text.trim();
  String get _clientNumberQuery => _clientNumberController.text.trim();

  bool get _hasAnyQuery =>
      _generalQuery.isNotEmpty || _clientNumberQuery.isNotEmpty;

  bool get _hasSearchableCriteria => ClientSearchUtils.hasSearchableCriteria(
    generalQuery: _generalQuery,
    clientNumberQuery: _clientNumberQuery,
  );

  bool get _hasShortGeneralQuery => ClientSearchUtils.hasShortGeneralQuery(
    generalQuery: _generalQuery,
    clientNumberQuery: _clientNumberQuery,
  );

  @override
  void dispose() {
    _generalQueryController.dispose();
    _clientNumberController.dispose();
    super.dispose();
  }

  void _refreshResults() {
    if (!_hasSearchableCriteria) {
      setState(() => _results = const <Client>[]);
      return;
    }

    final ranked = ClientSearchUtils.rankedClients(
      clients: widget.clients,
      generalQuery: _generalQuery,
      clientNumberQuery: _clientNumberQuery,
      activeSalonId: widget.activeSalonId,
      exactNumberMatch: true,
    );
    setState(() => _results = ranked);
  }

  Future<void> _createClient() async {
    final createClient = widget.onCreateRequested;
    if (createClient == null || _creatingClient) {
      return;
    }
    setState(() => _creatingClient = true);
    try {
      final createdClient = await createClient();
      if (!mounted || createdClient == null) {
        return;
      }
      Navigator.of(context).pop(createdClient);
    } finally {
      if (mounted) {
        setState(() => _creatingClient = false);
      }
    }
  }

  void _clearSearch() {
    if (!_hasAnyQuery) {
      return;
    }
    _generalQueryController.clear();
    _clientNumberController.clear();
    setState(() => _results = const <Client>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isAppSheetPhoneLayout(context)) {
      return _buildPhoneLayout(context, theme);
    }
    return _buildDesktopLayout(context, theme);
  }

  Widget _buildPhoneLayout(BuildContext context, ThemeData theme) {
    return AppMobileSheetPageScaffold(
      title: widget.title,
      actions:
          widget.allowCreate
              ? [
                TextButton(
                  onPressed: _creatingClient ? null : _createClient,
                  child: Text(_creatingClient ? 'Apro...' : 'Nuovo'),
                ),
              ]
              : const <Widget>[],
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _ClientSearchFilterHeaderDelegate(
              minExtent: 248,
              maxExtent: 248,
              child: Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhoneSearchField(
                      context,
                      label: 'Ricerca cliente',
                      controller: _generalQueryController,
                      hintText: 'Nome, cognome, telefono o email',
                      prefixIcon: Icons.search_rounded,
                      onClear: () {
                        _generalQueryController.clear();
                        _refreshResults();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildPhoneSearchField(
                      context,
                      label: 'Numero cliente',
                      controller: _clientNumberController,
                      hintText: 'Numero cliente',
                      prefixIcon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      onClear: () {
                        _clientNumberController.clear();
                        _refreshResults();
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _buildHelperText(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (_hasAnyQuery)
                          TextButton(
                            onPressed: _clearSearch,
                            child: const Text('Azzera'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._buildPhoneResultSlivers(context),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, ThemeData theme) {
    return DialogActionLayout(
      title: widget.title,
      trailing:
          widget.allowCreate
              ? TextButton.icon(
                onPressed: _creatingClient ? null : _createClient,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(_creatingClient ? 'Apro...' : 'Nuovo cliente'),
              )
              : null,
      scrollBody: false,
      bodyPadding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      body: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 680;
                final generalField = TextField(
                  controller: _generalQueryController,
                  decoration: InputDecoration(
                    labelText: 'Nome, cognome, telefono o email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon:
                        _generalQuery.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'Pulisci ricerca',
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _generalQueryController.clear();
                                _refreshResults();
                              },
                            ),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => _refreshResults(),
                );
                final numberField = TextField(
                  controller: _clientNumberController,
                  decoration: InputDecoration(
                    labelText: 'Numero cliente',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon:
                        _clientNumberQuery.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'Pulisci ricerca',
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _clientNumberController.clear();
                                _refreshResults();
                              },
                            ),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => _refreshResults(),
                );

                if (isStacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      generalField,
                      const SizedBox(height: 12),
                      numberField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: generalField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: numberField),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _buildHelperText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_hasAnyQuery)
                  TextButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('Azzera'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
      actions: const [],
    );
  }

  Widget _buildPhoneSearchField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required VoidCallback onClear,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.search,
          onChanged: (_) => _refreshResults(),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon),
            suffixIcon:
                controller.text.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Pulisci ricerca',
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: onClear,
                    ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _buildHelperText() {
    if (widget.clients.isEmpty) {
      return 'Non ci sono clienti disponibili per la selezione corrente.';
    }
    if (_hasShortGeneralQuery) {
      return ClientSearchUtils.minSearchCriteriaMessage;
    }
    if (_hasSearchableCriteria) {
      final label = _results.length == 1 ? 'cliente' : 'clienti';
      return '${_results.length} $label trovati';
    }
    return 'Digita almeno 3 caratteri oppure un numero cliente per iniziare.';
  }

  Widget _buildResults(BuildContext context) {
    if (widget.clients.isEmpty) {
      return _buildPlaceholder(
        context,
        icon: Icons.group_off_rounded,
        title: 'Nessun cliente disponibile',
        message: 'Crea un cliente per poterlo associare rapidamente.',
      );
    }

    if (!_hasAnyQuery) {
      return _buildPlaceholder(
        context,
        icon: Icons.person_search_rounded,
        title: 'Cerca un cliente',
        message:
            'Usa nome, cognome, telefono, email o il numero cliente per trovare rapidamente la scheda giusta.',
      );
    }

    if (_hasShortGeneralQuery) {
      return _buildPlaceholder(
        context,
        icon: Icons.short_text_rounded,
        title: 'Ricerca troppo corta',
        message: ClientSearchUtils.minSearchCriteriaMessage,
      );
    }

    if (_results.isEmpty) {
      return _buildPlaceholder(
        context,
        icon: Icons.person_off_rounded,
        title: 'Nessun risultato',
        message:
            'Nessun cliente corrisponde ai criteri inseriti. Prova a cambiare ricerca.',
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final client = _results[index];
        return _buildClientTile(context, client);
      },
    );
  }

  List<Widget> _buildPhoneResultSlivers(BuildContext context) {
    if (widget.clients.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPlaceholder(
            context,
            icon: Icons.group_off_rounded,
            title: 'Nessun cliente disponibile',
            message: 'Crea un cliente per poterlo associare rapidamente.',
          ),
        ),
      ];
    }

    if (!_hasAnyQuery) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPlaceholder(
            context,
            icon: Icons.person_search_rounded,
            title: 'Cerca un cliente',
            message:
                'Usa nome, cognome, telefono, email o il numero cliente per trovare rapidamente la scheda giusta.',
          ),
        ),
      ];
    }

    if (_hasShortGeneralQuery) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPlaceholder(
            context,
            icon: Icons.short_text_rounded,
            title: 'Ricerca troppo corta',
            message: ClientSearchUtils.minSearchCriteriaMessage,
          ),
        ),
      ];
    }

    if (_results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPlaceholder(
            context,
            icon: Icons.person_off_rounded,
            title: 'Nessun risultato',
            message:
                'Nessun cliente corrisponde ai criteri inseriti. Prova a cambiare ricerca.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        sliver: SliverList.separated(
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final client = _results[index];
            return _buildClientTile(context, client);
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
        ),
      ),
    ];
  }

  Widget _buildClientTile(BuildContext context, Client client) {
    final theme = Theme.of(context);
    final isSelected = client.id == widget.selectedClientId;
    final isPreferredSalon =
        widget.activeSalonId != null &&
        widget.activeSalonId!.isNotEmpty &&
        client.salonId == widget.activeSalonId;

    return Material(
      color:
          isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
              : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(client),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor:
                    isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                child: Text(_initialsFor(client)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          client.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (client.clientNumber != null &&
                            client.clientNumber!.isNotEmpty)
                          _buildTag(
                            context,
                            label: 'N° ${client.clientNumber}',
                            highlighted: isSelected,
                          ),
                        if (isPreferredSalon)
                          _buildTag(
                            context,
                            label: 'Salone attivo',
                            highlighted: true,
                          ),
                        if (isSelected)
                          _buildTag(
                            context,
                            label: 'Selezionato',
                            highlighted: true,
                          ),
                      ],
                    ),
                    if (client.phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.call_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              client.phone.trim(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (client.email != null && client.email!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                client.email!.trim(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(
    BuildContext context, {
    required String label,
    required bool highlighted,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            highlighted
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color:
              highlighted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

  String _initialsFor(Client client) {
    final fullName = client.fullName.trim();
    if (fullName.isEmpty) {
      return '?';
    }
    return String.fromCharCode(fullName.runes.first).toUpperCase();
  }
}

class _ClientSearchFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ClientSearchFilterHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow:
            overlapsContent
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : const [],
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_ClientSearchFilterHeaderDelegate oldDelegate) {
    return minExtent != oldDelegate.minExtent ||
        maxExtent != oldDelegate.maxExtent ||
        child != oldDelegate.child;
  }
}
