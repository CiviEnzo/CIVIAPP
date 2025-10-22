import 'package:civiapp/domain/entities/client.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ClientSearchSheet extends StatefulWidget {
  const ClientSearchSheet({
    super.key,
    required this.clients,
    this.title = 'Seleziona cliente',
  });

  final List<Client> clients;
  final String title;

  @override
  State<ClientSearchSheet> createState() => _ClientSearchSheetState();
}

class _ClientSearchSheetState extends State<ClientSearchSheet> {
  final TextEditingController _generalQueryController = TextEditingController();
  final TextEditingController _clientNumberController = TextEditingController();

  List<Client> _results = const <Client>[];
  bool _searchPerformed = false;
  String? _error;

  @override
  void dispose() {
    _generalQueryController.dispose();
    _clientNumberController.dispose();
    super.dispose();
  }

  void _performSearch({bool autoTriggered = false}) {
    final general = _generalQueryController.text.trim();
    final clientNumber = _clientNumberController.text.trim();

    if (general.isEmpty && clientNumber.isEmpty) {
      setState(() {
        _error =
            autoTriggered ? null : 'Inserisci almeno un criterio di ricerca';
        _searchPerformed = false;
        _results = const <Client>[];
      });
      return;
    }

    final lowerGeneral = general.toLowerCase();
    final lowerNumber = clientNumber.toLowerCase();

    bool matchesGeneral(Client client) {
      if (lowerGeneral.isEmpty) {
        return true;
      }
      bool contains(String? value) =>
          value != null && value.toLowerCase().contains(lowerGeneral);
      return contains(client.firstName) ||
          contains(client.lastName) ||
          contains(client.phone) ||
          contains(client.email);
    }

    bool matchesNumber(Client client) {
      if (lowerNumber.isEmpty) {
        return true;
      }
      final number = client.clientNumber;
      if (number == null) {
        return false;
      }
      return number.toLowerCase() == lowerNumber;
    }

    final filtered =
        widget.clients
            .where((client) => matchesGeneral(client) && matchesNumber(client))
            .toList()
          ..sort((a, b) => a.lastName.compareTo(b.lastName));

    setState(() {
      _results = filtered;
      _searchPerformed = true;
      _error = null;
    });
  }

  void _clearSearch() {
    setState(() {
      _generalQueryController.clear();
      _clientNumberController.clear();
      _results = const <Client>[];
      _searchPerformed = false;
      _error = null;
    });
  }

  void _resetError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _generalQueryController,
                decoration: const InputDecoration(
                  labelText: 'Nome, cognome, telefono, email',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  _resetError();
                  _performSearch(autoTriggered: true);
                },
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
                onChanged: (_) {
                  _resetError();
                  _performSearch(autoTriggered: true);
                },
                onSubmitted: (_) => _performSearch(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _performSearch(),
                    icon: const Icon(Icons.manage_search_rounded),
                    label: const Text('Cerca'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Azzera'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              Expanded(child: _buildResults(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (!_searchPerformed) {
      final hasClients = widget.clients.isNotEmpty;
      final message =
          hasClients
              ? 'Inserisci almeno un criterio e avvia la ricerca per vedere i clienti.'
              : 'Non ci sono clienti per il salone selezionato. Crea un cliente per continuare.';
      return _buildPlaceholder(
        context,
        icon: Icons.person_search_rounded,
        title: 'Cerca un cliente',
        message: message,
      );
    }

    if (_results.isEmpty) {
      return _buildPlaceholder(
        context,
        icon: Icons.person_off_rounded,
        title: 'Nessun risultato',
        message:
            'Nessun cliente corrisponde ai criteri. Modifica la ricerca e riprova.',
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final client = _results[index];
        final subtitleParts = <String>[];
        if (client.clientNumber != null && client.clientNumber!.isNotEmpty) {
          subtitleParts.add('N° ${client.clientNumber}');
        }
        if (client.phone.isNotEmpty) {
          subtitleParts.add(client.phone);
        }
        if (client.email != null && client.email!.isNotEmpty) {
          subtitleParts.add(client.email!);
        }

        return ListTile(
          onTap: () => Navigator.of(context).pop(client),
          leading: CircleAvatar(
            child: Text(
              client.firstName.characters.firstOrNull?.toUpperCase() ?? '?',
            ),
          ),
          title: Text(client.fullName),
          subtitle:
              subtitleParts.isNotEmpty ? Text(subtitleParts.join(' · ')) : null,
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      },
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
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
    );
  }
}
