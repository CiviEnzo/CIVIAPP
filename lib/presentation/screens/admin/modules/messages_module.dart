import 'dart:async';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/reminder_settings.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/message_template_form_sheet.dart';
import 'package:collection/collection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MessagesModule extends ConsumerWidget {
  const MessagesModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final templates =
        data.messageTemplates
            .where((template) => salonId == null || template.salonId == salonId)
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final salons = data.salons;
    final currentSalonId =
        salonId ?? (salons.length == 1 ? salons.first.id : null);
    final reminderSettings =
        currentSalonId == null
            ? null
            : data.reminderSettings.firstWhereOrNull(
              (settings) => settings.salonId == currentSalonId,
            );
    final effectiveSettings =
        currentSalonId == null
            ? null
            : (reminderSettings ?? ReminderSettings(salonId: currentSalonId));
    final salonName =
        currentSalonId == null
            ? null
            : salons
                .firstWhereOrNull((salon) => salon.id == currentSalonId)
                ?.name;
    final clients =
        data.clients
            .where(
              (client) =>
                  currentSalonId == null || client.salonId == currentSalonId,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );

    final session = ref.watch(sessionControllerProvider);
    final canViewReminderSettings =
        currentSalonId != null &&
        session.role != null &&
        (session.role == UserRole.admin ||
            session.role == UserRole.staff ||
            session.role == UserRole.client);
    final canEditReminderSettings =
        currentSalonId != null &&
        session.role != null &&
        (session.role == UserRole.admin || session.role == UserRole.staff);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length + 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          if (!canViewReminderSettings) {
            return const SizedBox.shrink();
          }
          return _ReminderSettingsCard(
            salonId: currentSalonId,
            salonName: salonName,
            settings: effectiveSettings,
            onChanged:
                canEditReminderSettings
                    ? (updated) async {
                      await ref
                          .read(appDataProvider.notifier)
                          .upsertReminderSettings(updated);
                    }
                    : null,
          );
        }
        if (index == 1) {
          return _ManualNotificationCard(
            salonId: currentSalonId,
            salonName: salonName,
            clients: clients,
          );
        }
        if (index == 2) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed:
                  () => _openForm(
                    context,
                    ref,
                    salons: salons,
                    defaultSalonId: salonId,
                  ),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Nuovo template'),
            ),
          );
        }
        final template = templates[index - 3];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Switch(value: template.isActive, onChanged: (_) {}),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    _Badge(
                      label: _channelLabel(template.channel),
                      icon: Icons.chat_rounded,
                    ),
                    _Badge(
                      label: _usageLabel(template.usage),
                      icon: Icons.campaign_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(template.body),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        () => _openForm(
                          context,
                          ref,
                          salons: salons,
                          defaultSalonId: salonId,
                          existing: template,
                        ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Modifica template'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _channelLabel(MessageChannel channel) {
    switch (channel) {
      case MessageChannel.push:
        return 'Push';
      case MessageChannel.whatsapp:
        return 'WhatsApp';
      case MessageChannel.email:
        return 'Email';
      case MessageChannel.sms:
        return 'SMS';
    }
  }

  String _usageLabel(TemplateUsage usage) {
    switch (usage) {
      case TemplateUsage.reminder:
        return 'Promemoria';
      case TemplateUsage.followUp:
        return 'Follow up';
      case TemplateUsage.promotion:
        return 'Promozione';
      case TemplateUsage.birthday:
        return 'Compleanno';
    }
  }
}

class _ManualNotificationCard extends ConsumerStatefulWidget {
  const _ManualNotificationCard({
    required this.salonId,
    required this.salonName,
    required this.clients,
  });

  final String? salonId;
  final String? salonName;
  final List<Client> clients;

  @override
  ConsumerState<_ManualNotificationCard> createState() =>
      _ManualNotificationCardState();
}

class _ManualNotificationCardState
    extends ConsumerState<_ManualNotificationCard> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _bodyFocusNode = FocusNode();
  final ScrollController _clientScrollController = ScrollController();
  final Set<String> _selectedClientIds = <String>{};
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
  void didUpdateWidget(covariant _ManualNotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.clients, widget.clients)) {
      final currentIds = widget.clients.map((client) => client.id).toSet();
      var changed = false;
      _selectedClientIds.removeWhere((id) {
        final shouldRemove = !currentIds.contains(id);
        if (shouldRemove) {
          changed = true;
        }
        return shouldRemove;
      });
      if (changed && mounted) {
        setState(() {});
      }
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _resetForm() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedClientIds.clear();
      _statusMessage = null;
      _statusIsError = false;
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

  void _ensureDefaultMessage({bool force = false}) {
    if (force || _titleController.text.trim().isEmpty) {
      _titleController.text = _defaultTitle;
    }
    if (force || _bodyController.text.trim().isEmpty) {
      _bodyController.text = _defaultBody;
    }
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

    final filteredClients = _filteredClients();
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
    final salonName = widget.salonName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Notifiche manuali',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (salonName != null)
                  Text(salonName, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cerca clienti',
                hintText: 'Nome, cognome, numero cliente o telefono',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Svuota ricerca',
                          onPressed: () => _searchController.clear(),
                          icon: const Icon(Icons.clear),
                        ),
              ),
              textInputAction: TextInputAction.search,
            ),
            const SizedBox(height: 12),
            if (selectedClients.isNotEmpty) ...[
              Text(
                'Selezionati ${selectedClients.length} clienti',
                style: theme.textTheme.bodySmall,
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
                                    : () => setState(() {
                                      _selectedClientIds.remove(client.id);
                                    }),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 12),
            ],
            _ClientSelectionList(
              clients: filteredClients,
              selectedIds: _selectedClientIds,
              controller: _clientScrollController,
              onToggle:
                  _sending
                      ? null
                      : (clientId, shouldSelect) {
                        setState(() {
                          if (shouldSelect) {
                            _selectedClientIds.add(clientId);
                          } else {
                            _selectedClientIds.remove(clientId);
                          }
                        });
                      },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Titolo',
                hintText: 'Promozione flash, promemoria, …',
              ),
              maxLength: 120,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              focusNode: _bodyFocusNode,
              decoration: const InputDecoration(
                labelText: 'Testo della notifica',
                alignLabelWithHint: true,
              ),
              maxLength: 240,
              maxLines: 4,
              minLines: 3,
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _statusIsError ? Icons.error_outline : Icons.info_outline,
                      color:
                          _statusIsError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color:
                              _statusIsError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
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
                            width: 18,
                            height: 18,
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
          ],
        ),
      ),
    );
  }

  List<Client> _filteredClients() {
    if (widget.clients.isEmpty) {
      return const <Client>[];
    }
    final query = _searchController.text.trim().toLowerCase();
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

class _ReminderSettingsCard extends StatelessWidget {
  const _ReminderSettingsCard({
    required this.salonId,
    required this.salonName,
    required this.settings,
    this.onChanged,
  });

  final String? salonId;
  final String? salonName;
  final ReminderSettings? settings;
  final Future<void> Function(ReminderSettings)? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminder = settings;
    if (salonId == null || reminder == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Promemoria appuntamenti',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Seleziona un salone per configurare i promemoria automatici.',
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final updatedLabel =
        reminder.updatedAt != null
            ? 'Ultimo aggiornamento: ${dateFormat.format(reminder.updatedAt!)}'
            : 'Mai configurato';

    Future<void> emit(ReminderSettings updated) async {
      final callback = onChanged;
      if (callback == null) {
        return;
      }
      await callback(updated);
    }

    String formatOffsetLabel(int totalMinutes) {
      final days = totalMinutes ~/ 1440;
      final hours = (totalMinutes % 1440) ~/ 60;
      final minutes = totalMinutes % 60;
      final parts = <String>[];
      if (days > 0) {
        parts.add(days == 1 ? '1 giorno' : '$days giorni');
      }
      if (hours > 0) {
        parts.add(hours == 1 ? '1 ora' : '$hours ore');
      }
      if (minutes > 0) {
        parts.add('$minutes minuti');
      }
      if (parts.isEmpty) {
        return '$totalMinutes minuti prima';
      }
      if (parts.length == 1) {
        return '${parts.first} prima';
      }
      final last = parts.last;
      final head = parts.sublist(0, parts.length - 1).join(', ');
      return '$head e $last prima';
    }

    Future<void> updateOffsets(List<ReminderOffsetConfig> newOffsets) async {
      await emit(reminder.copyWith(offsets: newOffsets));
    }

    Future<void> updateOffsetAt(
      int index,
      ReminderOffsetConfig updated,
    ) async {
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      final next = List<ReminderOffsetConfig>.from(current)..[index] = updated;
      await updateOffsets(next);
    }

    Future<void> updateLastMinuteAudience(
      LastMinuteNotificationAudience audience,
    ) async {
      await emit(reminder.copyWith(lastMinuteNotificationAudience: audience));
    }

    Future<void> toggleBirthday(bool enabled) async {
      await emit(reminder.copyWith(birthdayEnabled: enabled));
    }

    final offsetsEntries =
        reminder.offsets.asMap().entries.toList()
          ..sort(
            (a, b) =>
                b.value.minutesBefore.compareTo(a.value.minutesBefore),
          );
    final canEditOffsets = onChanged != null;
    final canAddOffset =
        canEditOffsets &&
        reminder.offsets.length < ReminderSettings.maxOffsetsCount;

    const dayOptions = <int>[0, 1, 2, 3, 4, 5, 6, 7];
    const hourOptions = <int>[
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
    ];
    const minuteOptions = <int>[0, 15, 30, 45];

    void showValidationMessage(String message) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    ({int days, int hours, int minutes}) splitOffset(int totalMinutes) {
      final days = totalMinutes ~/ 1440;
      final hours = (totalMinutes % 1440) ~/ 60;
      final minutes = totalMinutes % 60;
      return (days: days, hours: hours, minutes: minutes);
    }

    Future<void> changeOffset({
      required int index,
      required ReminderOffsetConfig config,
      int? days,
      int? hours,
      int? minutes,
    }) async {
      final parts = splitOffset(config.minutesBefore);
      final newDays = days ?? parts.days;
      final newHours = hours ?? parts.hours;
      final newMinutes = minutes ?? parts.minutes;
      final total = (newDays * 1440) + (newHours * 60) + newMinutes;
      if (total == config.minutesBefore) {
        return;
      }
      if (total < ReminderSettings.minOffsetMinutes) {
        showValidationMessage(
          'Imposta almeno ${ReminderSettings.minOffsetMinutes} minuti.',
        );
        return;
      }
      if (total > ReminderSettings.maxOffsetMinutes) {
        showValidationMessage(
          'Il massimo consentito è di ${ReminderSettings.maxOffsetMinutes ~/ 1440} giorni.',
        );
        return;
      }
      if (total == 0) {
        showValidationMessage('Seleziona un intervallo valido.');
        return;
      }
      final duplicates = reminder.offsets.asMap().entries.any((entry) {
        if (entry.key == index) {
          return false;
        }
        return entry.value.minutesBefore == total;
      });
      if (duplicates) {
        showValidationMessage('Questo intervallo è già presente.');
        return;
      }
      final autoManagedSlug = config.id == 'M${config.minutesBefore}';
      await updateOffsetAt(
        index,
        config.copyWith(
          minutesBefore: total,
          id: autoManagedSlug ? 'M$total' : config.id,
        ),
      );
    }

    Future<void> addOffset() async {
      if (!canAddOffset) {
        return;
      }
      final existing =
          reminder.offsets.map((offset) => offset.minutesBefore).toSet();
      var candidate = ReminderSettings.minOffsetMinutes;
      while (existing.contains(candidate) &&
          candidate <= ReminderSettings.maxOffsetMinutes) {
        candidate += ReminderSettings.minOffsetMinutes;
      }
      if (candidate > ReminderSettings.maxOffsetMinutes) {
        showValidationMessage('Non ci sono altri intervalli disponibili.');
        return;
      }
      final newOffset = ReminderOffsetConfig(
        id: 'M$candidate',
        minutesBefore: candidate,
      );
      await updateOffsets(<ReminderOffsetConfig>[
        ...reminder.offsets,
        newOffset,
      ]);
    }

    Future<void> toggleOffsetActive(int index, bool active) async {
      if (!canEditOffsets) {
        return;
      }
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      await updateOffsetAt(
        index,
        current[index].copyWith(active: active),
      );
    }

    Future<void> removeOffset(int index) async {
      if (!canEditOffsets) {
        return;
      }
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      final next = List<ReminderOffsetConfig>.from(current)..removeAt(index);
      await updateOffsets(next);
    }

    Future<void> editOffsetMetadata(int index) async {
      if (!canEditOffsets) {
        return;
      }
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      final offset = current[index];
      final slugController = TextEditingController(text: offset.id);
      final titleController = TextEditingController(text: offset.title ?? '');
      final bodyController = TextEditingController(
        text: offset.bodyTemplate ?? '',
      );
      String? errorText;

      String sanitizeSlug(String value) {
        final trimmed = value.trim().toUpperCase();
        if (trimmed.isEmpty) {
          return '';
        }
        final sanitized = trimmed.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
        return sanitized.replaceAll(RegExp(r'_+'), '_');
      }

      final updated = await showDialog<ReminderOffsetConfig>(
        context: context,
        builder:
            (dialogContext) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Dettagli promemoria'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: slugController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Identificativo',
                            helperText: 'Usa lettere, numeri o _ -',
                            errorText: errorText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Titolo (facoltativo)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: bodyController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Testo (facoltativo)',
                            helperText: 'Puoi usare segnaposto come {{time}}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Annulla'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final slug = sanitizeSlug(slugController.text);
                        if (slug.isEmpty) {
                          setState(() {
                            errorText = 'Inserisci un identificativo valido.';
                          });
                          return;
                        }
                        final conflict = reminder.offsets.any(
                          (other) => other.id == slug && other.id != offset.id,
                        );
                        if (conflict) {
                          setState(() {
                            errorText =
                                'Identificativo già in uso. Scegline uno diverso.';
                          });
                          return;
                        }
                        Navigator.of(dialogContext).pop(
                          offset.copyWith(
                            id: slug,
                            title: titleController.text.trim().isEmpty
                                ? null
                                : titleController.text.trim(),
                            bodyTemplate:
                                bodyController.text.trim().isEmpty
                                    ? null
                                    : bodyController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Salva'),
                    ),
                  ],
                );
              },
            ),
      );

      if (updated != null) {
        await updateOffsetAt(index, updated);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promemoria appuntamenti', style: theme.textTheme.titleMedium),
            if (salonName != null) ...[
              const SizedBox(height: 4),
              Text(salonName!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Text(
              'Seleziona fino a ${ReminderSettings.maxOffsetsCount} promemoria automatici. Gli offset sono espressi rispetto all\'inizio appuntamento.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LastMinuteNotificationAudience>(
              value: reminder.lastMinuteNotificationAudience,
              decoration: const InputDecoration(
                labelText: 'Notifiche last-minute (predefinito)',
                helperText:
                    'Determina cosa proporre quando crei o modifichi uno slot express.',
              ),
              items:
                  LastMinuteNotificationAudience.values.map((audience) {
                    late final String label;
                    switch (audience) {
                      case LastMinuteNotificationAudience.none:
                        label = 'Chiedi ogni volta';
                        break;
                      case LastMinuteNotificationAudience.everyone:
                        label = 'Invia a tutti i clienti';
                        break;
                      case LastMinuteNotificationAudience.ownerSelection:
                        label = 'Scegli manualmente i destinatari';
                        break;
                    }
                    return DropdownMenuItem<LastMinuteNotificationAudience>(
                      value: audience,
                      child: Text(label),
                    );
                  }).toList(),
              onChanged:
                  onChanged == null
                      ? null
                      : (value) {
                        if (value != null) {
                          unawaited(updateLastMinuteAudience(value));
                        }
                      },
            ),
            const SizedBox(height: 12),
            if (offsetsEntries.isEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Nessun promemoria automatico attivo'),
                subtitle: const Text(
                  'Aggiungi un orario per inviare promemoria prima dell\'appuntamento.',
                ),
                trailing:
                    canAddOffset
                        ? IconButton(
                          tooltip: 'Aggiungi promemoria',
                          onPressed: () => unawaited(addOffset()),
                          icon: const Icon(Icons.add_alarm),
                        )
                        : null,
              )
            else
              ...offsetsEntries.map((entry) {
                final originalIndex = entry.key;
                final config = entry.value;
                final minutes = config.minutesBefore;
                final parts = splitOffset(minutes);
                final daysValues = {...dayOptions, parts.days}.toList()..sort();
                final hoursValues =
                    {...hourOptions, parts.hours}.toList()..sort();
                final minutesValues =
                    {...minuteOptions, parts.minutes}.toList()..sort();
                final defaultSlug = 'M$minutes';
                final showSlugChip = config.id != defaultSlug;
                final chips = <Widget>[
                  if (showSlugChip)
                    Chip(
                      avatar: const Icon(Icons.tag, size: 18),
                      label: Text(config.id),
                    ),
                  if (config.title != null)
                    Chip(
                      avatar: const Icon(Icons.text_fields, size: 18),
                      label: Text(config.title!),
                    ),
                ];
                return Padding(
                  padding: EdgeInsets.only(top: entry == offsetsEntries.first ? 0 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatOffsetLabel(minutes),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: config.active,
                            onChanged:
                                canEditOffsets
                                    ? (value) =>
                                        unawaited(
                                          toggleOffsetActive(
                                            originalIndex,
                                            value,
                                          ),
                                        )
                                    : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (chips.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: chips,
                        ),
                      if (config.bodyTemplate != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          config.bodyTemplate!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Giorni',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: parts.days,
                                  items:
                                      daysValues
                                          .map(
                                            (value) => DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(
                                                value == 1
                                                    ? '1 giorno'
                                                    : '$value giorni',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      canEditOffsets
                                          ? (value) {
                                            if (value != null) {
                                              unawaited(
                                                changeOffset(
                                                  index: originalIndex,
                                                  config: config,
                                                  days: value,
                                                ),
                                              );
                                            }
                                          }
                                          : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Ore',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: parts.hours,
                                  items:
                                      hoursValues
                                          .map(
                                            (value) => DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(
                                                value == 1
                                                    ? '1 ora'
                                                    : '$value ore',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      canEditOffsets
                                          ? (value) {
                                            if (value != null) {
                                              unawaited(
                                                changeOffset(
                                                  index: originalIndex,
                                                  config: config,
                                                  hours: value,
                                                ),
                                              );
                                            }
                                          }
                                          : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Minuti',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: parts.minutes,
                                  items:
                                      minutesValues
                                          .map(
                                            (value) => DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(
                                                value == 0
                                                    ? '0 minuti'
                                                    : '$value minuti',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      canEditOffsets
                                          ? (value) {
                                            if (value != null) {
                                              unawaited(
                                                changeOffset(
                                                  index: originalIndex,
                                                  config: config,
                                                  minutes: value,
                                                ),
                                              );
                                            }
                                          }
                                          : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Modifica testo',
                            onPressed:
                                canEditOffsets
                                    ? () => unawaited(
                                      editOffsetMetadata(originalIndex),
                                    )
                                    : null,
                            icon: const Icon(Icons.edit_note_outlined),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Rimuovi promemoria',
                            onPressed:
                                canEditOffsets
                                    ? () => unawaited(
                                      removeOffset(originalIndex),
                                    )
                                    : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            if (offsetsEntries.isNotEmpty) const SizedBox(height: 12),
            if (canAddOffset)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Aggiungi promemoria'),
                  onPressed: () => unawaited(addOffset()),
                ),
              ),
            if (offsetsEntries.isNotEmpty || canAddOffset)
              const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: reminder.birthdayEnabled,
              title: const Text('Auguri di compleanno'),
              subtitle: const Text(
                'Invia un messaggio push automatico il giorno del compleanno.',
              ),
              onChanged:
                  onChanged == null
                      ? null
                      : (value) => unawaited(toggleBirthday(value)),
            ),
            const SizedBox(height: 8),
            Text(updatedLabel, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  String? defaultSalonId,
  MessageTemplate? existing,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea un salone prima di definire i messaggi.'),
      ),
    );
    return;
  }
  final result = await showAppModalSheet<MessageTemplate>(
    context: context,
    builder:
        (ctx) => MessageTemplateFormSheet(
          salons: salons,
          defaultSalonId: defaultSalonId,
          initial: existing,
        ),
  );
  if (result != null) {
    await ref.read(appDataProvider.notifier).upsertTemplate(result);
  }
}
