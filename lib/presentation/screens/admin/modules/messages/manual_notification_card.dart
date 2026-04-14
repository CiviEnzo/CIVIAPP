import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';

class ManualNotificationCard extends ConsumerStatefulWidget {
  const ManualNotificationCard({
    super.key,
    required this.salonId,
    required this.salonName,
    required this.clients,
    required this.templates,
    this.initialSelectedClientIds,
  });

  final String? salonId;
  final String? salonName;
  final List<Client> clients;
  final List<MessageTemplate> templates;
  final Set<String>? initialSelectedClientIds;

  @override
  ConsumerState<ManualNotificationCard> createState() =>
      _ManualNotificationCardState();
}

class _ManualNotificationCardState
    extends ConsumerState<ManualNotificationCard> {
  static const String _manualTemplateOption = '__manual__';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _bodyFocusNode = FocusNode();
  final ScrollController _clientScrollController = ScrollController();
  final Set<String> _selectedClientIds = <String>{};
  String? _selectedTemplateId;
  static const String _defaultTitle = 'Messaggio da YouBook';
  static const String _defaultBody =
      'Ciao {{nome}}, questo è un messaggio di prova inviato dal salone per verificare le notifiche.';
  static const String _previewEventName = 'manual_notification_preview';

  bool _sending = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _ensureDefaultMessage();
    _initializeSelection();
  }

  void _initializeSelection() {
    final initial = widget.initialSelectedClientIds;
    if (initial == null || initial.isEmpty) {
      return;
    }
    final validIds = widget.clients.map((client) => client.id).toSet();
    final sanitized = initial.where(validIds.contains);
    if (sanitized.isEmpty) {
      return;
    }
    _selectedClientIds
      ..clear()
      ..addAll(sanitized);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _clientScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ManualNotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.clients, widget.clients)) {
      final wasSelectingAll =
          oldWidget.clients.isNotEmpty &&
          oldWidget.clients.every(
            (client) => _selectedClientIds.contains(client.id),
          );
      final currentIds = widget.clients.map((client) => client.id).toSet();
      var changed = false;
      _selectedClientIds.removeWhere((id) {
        final shouldRemove = !currentIds.contains(id);
        if (shouldRemove) {
          changed = true;
        }
        return shouldRemove;
      });
      if (wasSelectingAll && _selectedClientIds.length != currentIds.length) {
        _selectedClientIds
          ..clear()
          ..addAll(currentIds);
        changed = true;
      }
      if (changed && mounted) {
        setState(() {});
      }
    }

    if (!identical(oldWidget.templates, widget.templates) &&
        _selectedTemplateId != null &&
        widget.templates.firstWhereOrNull(
              (template) => template.id == _selectedTemplateId,
            ) ==
            null) {
      _selectedTemplateId = null;
      if (mounted) {
        setState(() {});
      }
      _ensureDefaultMessage();
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _ensureDefaultMessage({bool force = false}) {
    if (_titleController.text.trim().isEmpty || force) {
      _titleController.text = _defaultTitle;
    }
    if (_bodyController.text.trim().isEmpty || force) {
      final salonName = widget.salonName?.trim();
      final defaultBody =
          salonName != null && salonName.isNotEmpty
              ? 'Ciao {{nome}}, lo staff di $salonName ti contatta per una comunicazione.'
              : _defaultBody;
      _bodyController.text = defaultBody;
    }
  }

  void _toggleSelectAll(bool value) {
    if (_sending) {
      return;
    }
    setState(() {
      if (value) {
        _selectedClientIds
          ..clear()
          ..addAll(widget.clients.map((client) => client.id));
      } else {
        _selectedClientIds.clear();
      }
    });
  }

  void _handleTemplateSelection(String? value) {
    if (value == null || value == _manualTemplateOption) {
      if (_selectedTemplateId != null) {
        setState(() {
          _selectedTemplateId = null;
        });
      }
      _ensureDefaultMessage();
      return;
    }
    final template = widget.templates.firstWhereOrNull(
      (element) => element.id == value,
    );
    if (template == null) {
      if (_selectedTemplateId != null) {
        setState(() {
          _selectedTemplateId = null;
        });
      }
      _ensureDefaultMessage();
      return;
    }
    setState(() {
      _selectedTemplateId = template.id;
      _titleController.text = template.title;
      _bodyController.text = template.body;
    });
  }

  List<MessageTemplate> _availablePushTemplates() {
    if (widget.templates.isEmpty) {
      return const <MessageTemplate>[];
    }
    final templates =
        widget.templates
            .where(
              (template) =>
                  template.channel == MessageChannel.push && template.isActive,
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    return templates;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.salonId == null) {
      return const _ManualPanel(
        child: _ManualEmptyState(
          message: 'Seleziona un salone per inviare notifiche push ai clienti.',
        ),
      );
    }
    final isSearchActive = _searchController.text.trim().isNotEmpty;
    final filteredClients = _filteredClients();
    final pushTemplates = _availablePushTemplates();
    final dropdownValue = _selectedTemplateId ?? _manualTemplateOption;
    final totalClients = widget.clients.length;
    final allClientsSelected =
        totalClients > 0 && _selectedClientIds.length == totalClients;
    final selectedClients =
        _selectedClientIds
            .map(
              (id) =>
                  widget.clients.firstWhereOrNull((client) => client.id == id),
            )
            .whereType<Client>()
            .toList()
          ..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );

    final recipientsPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stackHeader = constraints.maxWidth < 420;
            final selectionLabel = Text(
              '${_selectedClientIds.length}/${widget.clients.length} selezionati',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            );
            if (stackHeader) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleziona clienti',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  selectionLabel,
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Seleziona clienti',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                selectionLabel,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cerca clienti per nome, telefono o email',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Icon(
              Icons.group_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed:
                widget.clients.isEmpty
                    ? null
                    : () => _toggleSelectAll(!allClientsSelected),
            icon: Icon(
              allClientsSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
            ),
            label: Text(
              allClientsSelected ? 'Deseleziona tutti' : 'Seleziona tutti',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              style: BorderStyle.solid,
            ),
          ),
          child:
              isSearchActive
                  ? _ClientSelectionList(
                    clients: filteredClients,
                    selectedIds: _selectedClientIds,
                    controller: _clientScrollController,
                    onToggle: (clientId, value) {
                      setState(() {
                        if (value) {
                          _selectedClientIds.add(clientId);
                        } else {
                          _selectedClientIds.remove(clientId);
                        }
                      });
                    },
                  )
                  : const _ClientSearchPlaceholder(),
        ),
        if (selectedClients.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (selectedClients.length <= 12)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedClients
                  .map(
                    (client) => InputChip(
                      label: Text(client.fullName),
                      onDeleted:
                          _sending
                              ? null
                              : () {
                                setState(() {
                                  _selectedClientIds.remove(client.id);
                                });
                              },
                    ),
                  )
                  .toList(growable: false),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.list_alt_outlined),
              onPressed:
                  _sending
                      ? null
                      : () => _showSelectedClientsDialog(selectedClients),
              label: Text('Mostra elenco completo (${selectedClients.length})'),
            ),
        ],
      ],
    );

    final messagePanel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Componi messaggio',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        const _ManualFieldLabel(label: 'Template messaggio'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: dropdownValue,
          decoration: const InputDecoration(isDense: true),
          items: [
            const DropdownMenuItem<String>(
              value: _manualTemplateOption,
              child: Text('Scrivi manualmente'),
            ),
            ...pushTemplates.map(
              (template) => DropdownMenuItem<String>(
                value: template.id,
                child: Text(template.title),
              ),
            ),
          ],
          onChanged: _sending ? null : _handleTemplateSelection,
        ),
        const SizedBox(height: 14),
        const _ManualFieldLabel(label: 'Titolo della notifica'),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          readOnly: _sending,
          decoration: const InputDecoration(isDense: true),
        ),
        const SizedBox(height: 14),
        const _ManualFieldLabel(label: 'Corpo del messaggio'),
        const SizedBox(height: 6),
        TextField(
          controller: _bodyController,
          focusNode: _bodyFocusNode,
          readOnly: _sending,
          maxLines: 5,
          decoration: const InputDecoration(
            isDense: true,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Segnaposti: {{nome}}   {{cognome}}   {{salone}}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color:
                  _statusIsError
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.surfaceContainerHighest,
            ),
            child: Text(
              _statusMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    _statusIsError
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _sending ? null : _sendNotification,
              icon:
                  _sending
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Invio in corso…' : 'Invia notifica'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _sending ? null : _resetForm,
              icon: const Icon(Icons.autorenew_rounded),
              label: const Text('Ripristina'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _sending ? null : _showInAppPreview,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Anteprima'),
            ),
          ],
        ),
      ],
    );

    return _ManualPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;
          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                recipientsPanel,
                const SizedBox(height: 20),
                messagePanel,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 10, child: recipientsPanel),
              const SizedBox(width: 18),
              Expanded(flex: 10, child: messagePanel),
            ],
          );
        },
      ),
    );
  }

  void _resetForm() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedClientIds.clear();
      _statusMessage = null;
      _statusIsError = false;
      _selectedTemplateId = null;
    });
    _ensureDefaultMessage(force: true);
  }

  Future<void> _showInAppPreview() async {
    if (_sending) {
      return;
    }
    if (kIsWeb) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Le anteprime In-App sono disponibili solo su Android e iOS.';
        _statusIsError = true;
      });
      return;
    }
    try {
      final messaging = ref.read(firebaseInAppMessagingProvider);
      await messaging.setMessagesSuppressed(false);
      await messaging.triggerEvent(_previewEventName);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Anteprima in-app richiesta (evento: $_previewEventName). Configura la campagna in Firebase In-App Messaging per visualizzarla sul dispositivo.';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Impossibile mostrare l\'anteprima in-app: $error';
        _statusIsError = true;
      });
    }
  }

  Future<void> _showSelectedClientsDialog(List<Client> clients) async {
    if (!mounted || clients.isEmpty) {
      return;
    }

    final controller = ScrollController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Destinatari selezionati (${clients.length})'),
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Scrollbar(
                  controller: controller,
                  child: ListView.separated(
                    controller: controller,
                    shrinkWrap: true,
                    itemBuilder: (_, index) {
                      final client = clients[index];
                      final metadata = <String>[];
                      final clientNumber = client.clientNumber;
                      if (clientNumber != null && clientNumber.isNotEmpty) {
                        metadata.add('#$clientNumber');
                      }
                      if (client.phone.isNotEmpty) {
                        metadata.add(client.phone);
                      }
                      final subtitle =
                          metadata.isEmpty
                              ? 'Telefono non disponibile'
                              : metadata.join(' · ');
                      return ListTile(
                        dense: true,
                        title: Text(client.fullName),
                        subtitle: Text(subtitle),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: clients.length,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  List<Client> _filteredClients() {
    if (widget.clients.isEmpty) {
      return const <Client>[];
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const <Client>[];
    }
    final queryNoSpaces = query.replaceAll(RegExp(r'\s+'), '');
    Iterable<Client> source = widget.clients;
    if (query.isNotEmpty) {
      source = source.where((client) {
        final fullName = '${client.firstName} ${client.lastName}'.toLowerCase();
        if (fullName.contains(query)) {
          return true;
        }
        final number = client.clientNumber?.toLowerCase();
        if (number != null && number.contains(query)) {
          return true;
        }
        if (queryNoSpaces.isEmpty) {
          return false;
        }
        final phone = client.phone.replaceAll(RegExp(r'\s+'), '');
        if (phone.contains(queryNoSpaces)) {
          return true;
        }
        return false;
      });
    }
    return source.take(50).toList();
  }

  Future<void> _sendNotification() async {
    final salonId = widget.salonId;
    if (salonId == null) {
      _setStatus('Seleziona un salone prima di inviare.', true);
      return;
    }
    if (_selectedClientIds.isEmpty) {
      _setStatus('Seleziona almeno un cliente.', true);
      return;
    }
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _setStatus('Titolo e testo della notifica sono obbligatori.', true);
      if (title.isEmpty) {
        _titleFocusNode.requestFocus();
      } else if (body.isEmpty) {
        _bodyFocusNode.requestFocus();
      }
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _statusMessage = null;
    });

    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final callable = functions.httpsCallable('sendManualPushNotification');
      final response = await callable.call(<String, dynamic>{
        'salonId': salonId,
        'clientIds': _selectedClientIds.toList(growable: false),
        'title': title,
        'body': body,
        'data': <String, String>{'type': 'manual_notification'},
      });

      final data = response.data;
      var successCount = 0;
      var failureCount = 0;
      var invalidTokenCount = 0;
      if (data is Map) {
        successCount = int.tryParse('${data['successCount'] ?? ''}') ?? 0;
        failureCount = int.tryParse('${data['failureCount'] ?? ''}') ?? 0;
        invalidTokenCount =
            int.tryParse('${data['invalidTokenCount'] ?? ''}') ?? 0;
      }

      if (!mounted) {
        return;
      }

      final buffer =
          StringBuffer()
            ..write('Invio completato: ')
            ..write('$successCount ok');
      if (failureCount > 0) {
        buffer.write(', $failureCount errori');
      }
      if (invalidTokenCount > 0) {
        buffer.write(', $invalidTokenCount token rimossi');
      }

      _setStatus(buffer.toString(), failureCount > 0);

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showAppSnackBar(
        SnackBar(
          content: Text(buffer.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.message ?? 'Invio non riuscito: ${error.code}';
      _setStatus(message, true);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setStatus('Errore imprevisto: $error', true);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Errore imprevisto: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      } else {
        _sending = false;
      }
    }
  }

  void _setStatus(String message, bool isError) {
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }
}

class _ManualPanel extends StatelessWidget {
  const _ManualPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = isAdminPhoneWidth(constraints.maxWidth) ? 14.0 : 18.0;
          return Padding(padding: EdgeInsets.all(padding), child: child);
        },
      ),
    );
  }
}

class _ManualFieldLabel extends StatelessWidget {
  const _ManualFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _ManualEmptyState extends StatelessWidget {
  const _ManualEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ClientSearchPlaceholder extends StatelessWidget {
  const _ClientSearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 260,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_outlined,
                size: 34,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Digita nel campo di ricerca per selezionare i clienti.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientSelectionList extends StatelessWidget {
  const _ClientSelectionList({
    required this.clients,
    required this.selectedIds,
    required this.controller,
    required this.onToggle,
  });

  final List<Client> clients;
  final Set<String> selectedIds;
  final ScrollController controller;
  final void Function(String clientId, bool shouldSelect)? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (clients.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            'Nessun cliente trovato.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: Scrollbar(
        controller: controller,
        child: ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: clients.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final client = clients[index];
            final selected = selectedIds.contains(client.id);
            final hasTokens = client.fcmTokens.isNotEmpty;
            final pushEnabled = client.channelPreferences.push;
            final canToggle = onToggle != null && hasTokens && pushEnabled;

            final metadata = <String>[];
            final clientNumber = client.clientNumber;
            if (clientNumber != null && clientNumber.isNotEmpty) {
              metadata.add('#$clientNumber');
            }
            if (client.phone.isNotEmpty) {
              metadata.add(client.phone);
            }
            final primaryLine =
                metadata.isEmpty
                    ? 'Telefono non disponibile'
                    : metadata.join(' · ');

            final subtitles = <Widget>[Text(primaryLine)];

            if (!pushEnabled) {
              subtitles.add(
                Text(
                  'Notifiche push disattivate dal cliente',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              );
            } else if (!hasTokens) {
              subtitles.add(
                Text(
                  'Nessun dispositivo registrato',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              );
            } else {
              subtitles.add(
                Text(
                  'Dispositivi registrati: ${client.fcmTokens.length}',
                  style: theme.textTheme.bodySmall,
                ),
              );
            }

            return CheckboxListTile(
              value: selected,
              onChanged:
                  canToggle
                      ? (value) => onToggle?.call(client.id, value ?? false)
                      : null,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(client.fullName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: subtitles,
              ),
              secondary:
                  !hasTokens || !pushEnabled
                      ? Icon(
                        Icons.notifications_off_outlined,
                        color: theme.colorScheme.error,
                      )
                      : const Icon(Icons.notifications_active_outlined),
            );
          },
        ),
      ),
    );
  }
}
