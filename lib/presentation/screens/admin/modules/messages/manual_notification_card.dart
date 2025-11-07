import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/message_template.dart';

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
  static const String _defaultTitle = 'Messaggio di prova Civiapp';
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Notifiche manuali',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Seleziona un salone per inviare notifiche push ai clienti.',
              ),
            ],
          ),
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

    return Card(
      elevation: 2,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifiche manuali',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_selectedClientIds.length}/${widget.clients.length} selezionati',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Cerca clienti',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message:
                      allClientsSelected
                          ? 'Deseleziona tutti'
                          : 'Seleziona tutti',
                  child: IconButton(
                    icon: Icon(
                      allClientsSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                    ),
                    onPressed:
                        widget.clients.isEmpty
                            ? null
                            : () => _toggleSelectAll(!allClientsSelected),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isSearchActive)
              _ClientSelectionList(
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
            else
              _ClientSelectionList(
                clients: widget.clients,
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
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: dropdownValue,
              decoration: const InputDecoration(
                labelText: 'Template messaggio',
              ),
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
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              readOnly: _sending,
              decoration: const InputDecoration(
                labelText: 'Titolo della notifica',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              focusNode: _bodyFocusNode,
              readOnly: _sending,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Corpo del messaggio',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Segnaposto disponibili: {{nome}} · {{cognome}} · {{salone}}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
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
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _sending ? null : _sendNotification,
                  icon:
                      _sending
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Invio in corso…' : 'Invia notifica'),
                ),
                TextButton(
                  onPressed: _sending ? null : _resetForm,
                  child: const Text('Ripristina messaggio'),
                ),
                OutlinedButton.icon(
                  onPressed: _sending ? null : _showInAppPreview,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Anteprima in-app'),
                ),
              ],
            ),
            if (selectedClients.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Destinatari selezionati (${selectedClients.length})',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    selectedClients
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
                        .toList(),
              ),
            ],
          ],
        ),
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
      messenger?.showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setStatus('Errore imprevisto: $error', true);
      ScaffoldMessenger.of(context).showSnackBar(
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerLowest,
        ),
        alignment: Alignment.center,
        child: Text(
          'Nessun cliente trovato.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: Scrollbar(
        controller: controller,
        child: ListView.separated(
          controller: controller,
          padding: EdgeInsets.zero,
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
