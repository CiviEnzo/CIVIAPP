import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_note.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/user_role.dart';

class ClientNotesSection extends ConsumerStatefulWidget {
  const ClientNotesSection({super.key, required this.client});

  final Client client;

  @override
  ConsumerState<ClientNotesSection> createState() => _ClientNotesSectionState();
}

class _ClientNotesSectionState extends ConsumerState<ClientNotesSection> {
  final Set<String> _saving = <String>{};
  final Set<String> _deleting = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    final role = session.role;
    if (role != UserRole.admin && role != UserRole.staff) {
      return const SizedBox.shrink();
    }
    final notes = ref.watch(clientNotesProvider(widget.client.id));
    final staff = ref.watch(appDataProvider.select((state) => state.staff));
    final sortedNotes =
        notes.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lista note', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        sortedNotes.isEmpty
                            ? 'Annotazioni interne non visibili al cliente.'
                            : '${sortedNotes.length} note interne',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _createNote(context, staff),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Aggiungi'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sortedNotes.isEmpty)
              Text('Nessuna nota presente.', style: theme.textTheme.bodyMedium)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedNotes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final note = sortedNotes[index];
                  final now = DateTime.now();
                  final canManage = _canManageNote(note, session, now);
                  final isSaving = _saving.contains(note.id);
                  final isDeleting = _deleting.contains(note.id);
                  final createdLine = _formatOperatorLine(
                    note,
                    staff,
                    dateTimeFormat,
                    isUpdated: false,
                  );
                  final updatedLine =
                      note.updatedAt == null
                          ? null
                          : _formatOperatorLine(
                            note,
                            staff,
                            dateTimeFormat,
                            isUpdated: true,
                          );
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.text,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                createdLine,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (updatedLine != null)
                                Text(
                                  updatedLine,
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        if (canManage)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Modifica nota',
                                onPressed:
                                    isSaving || isDeleting
                                        ? null
                                        : () => _editNote(context, note, staff),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Elimina nota',
                                onPressed:
                                    isSaving || isDeleting
                                        ? null
                                        : () => _deleteNote(context, note),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _canManageNote(ClientNote note, SessionState session, DateTime now) {
    if (session.role == UserRole.admin) {
      return true;
    }
    if (session.role != UserRole.staff) {
      return false;
    }
    if (note.updatedByRole == UserRole.admin) {
      return false;
    }
    final staffId = session.userId;
    if (staffId == null || staffId.isEmpty) {
      return false;
    }
    if (note.createdByRole != UserRole.staff) {
      return false;
    }
    if (note.createdById != staffId) {
      return false;
    }
    return now.difference(note.createdAt) <= const Duration(hours: 24);
  }

  String _formatOperatorLine(
    ClientNote note,
    List<StaffMember> staff,
    DateFormat format, {
    required bool isUpdated,
  }) {
    final label = isUpdated ? 'Modificata' : 'Creata';
    final timestamp = isUpdated ? note.updatedAt : note.createdAt;
    final operatorName = _resolveOperatorName(
      note,
      staff,
      isUpdated: isUpdated,
    );
    final resolvedTimestamp = timestamp ?? note.createdAt;
    return '$label da $operatorName · ${format.format(resolvedTimestamp)}';
  }

  String _resolveOperatorName(
    ClientNote note,
    List<StaffMember> staff, {
    required bool isUpdated,
  }) {
    final name = isUpdated ? note.updatedByName : note.createdByName;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    final role = isUpdated ? note.updatedByRole : note.createdByRole;
    final id = isUpdated ? note.updatedById : note.createdById;
    if (role == UserRole.staff && id != null) {
      final member = staff.firstWhereOrNull((entry) => entry.id == id);
      if (member != null) {
        return member.displayName;
      }
    }
    return role?.label ?? 'Operatore';
  }

  Future<void> _createNote(
    BuildContext context,
    List<StaffMember> staff,
  ) async {
    final text = await _promptNoteText(context, initial: null);
    if (text == null || text.trim().isEmpty) {
      return;
    }
    final operator = _currentOperator(staff);
    final note = ClientNote(
      id: const Uuid().v4(),
      salonId: widget.client.salonId,
      clientId: widget.client.id,
      text: text.trim(),
      createdAt: DateTime.now(),
      createdById: operator.id,
      createdByRole: operator.role,
      createdByName: operator.name,
    );
    await _saveNote(note);
  }

  Future<void> _editNote(
    BuildContext context,
    ClientNote note,
    List<StaffMember> staff,
  ) async {
    final updatedText = await _promptNoteText(context, initial: note.text);
    if (updatedText == null) {
      return;
    }
    final trimmed = updatedText.trim();
    if (trimmed.isEmpty || trimmed == note.text.trim()) {
      return;
    }
    final operator = _currentOperator(staff);
    final updatedNote = note.copyWith(
      text: trimmed,
      updatedAt: DateTime.now(),
      updatedById: operator.id,
      updatedByRole: operator.role,
      updatedByName: operator.name,
    );
    await _saveNote(updatedNote);
  }

  Future<void> _deleteNote(BuildContext context, ClientNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina nota'),
            content: const Text('Vuoi eliminare definitivamente questa nota?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
    );
    if (confirm != true) {
      return;
    }
    if (_deleting.contains(note.id)) {
      return;
    }
    setState(() => _deleting.add(note.id));
    try {
      await ref.read(appDataProvider.notifier).deleteClientNote(note.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile eliminare la nota: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting.remove(note.id));
      }
    }
  }

  Future<void> _saveNote(ClientNote note) async {
    if (_saving.contains(note.id)) {
      return;
    }
    setState(() => _saving.add(note.id));
    try {
      await ref.read(appDataProvider.notifier).upsertClientNote(note);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile salvare la nota: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving.remove(note.id));
      }
    }
  }

  _NoteOperator _currentOperator(List<StaffMember> staff) {
    final session = ref.read(sessionControllerProvider);
    final role = session.role ?? UserRole.staff;
    if (role == UserRole.staff) {
      final staffId = session.userId ?? session.uid ?? 'unknown';
      final member = staff.firstWhereOrNull((entry) => entry.id == staffId);
      final name =
          member?.displayName ??
          session.user?.displayName ??
          session.user?.email;
      return _NoteOperator(id: staffId, role: UserRole.staff, name: name);
    }
    final name = session.user?.displayName ?? session.user?.email;
    return _NoteOperator(
      id: session.uid ?? 'unknown',
      role: UserRole.admin,
      name: name,
    );
  }

  Future<String?> _promptNoteText(
    BuildContext context, {
    String? initial,
  }) async {
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => _ClientNoteDialog(
            initial: initial,
            title: initial == null ? 'Nuova nota' : 'Modifica nota',
          ),
    );
  }
}

class _ClientNoteDialog extends StatefulWidget {
  const _ClientNoteDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_ClientNoteDialog> createState() => _ClientNoteDialogState();
}

class _ClientNoteDialogState extends State<_ClientNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final isValid = value.text.trim().isNotEmpty;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nota',
                  hintText: 'Inserisci una nota interna',
                ),
              ),
              if (!isValid)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'La nota non può essere vuota.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final isValid = value.text.trim().isNotEmpty;
            return FilledButton(
              onPressed:
                  isValid
                      ? () => Navigator.of(context).pop(value.text.trim())
                      : null,
              child: const Text('Salva'),
            );
          },
        ),
      ],
    );
  }
}

class _NoteOperator {
  const _NoteOperator({required this.id, required this.role, this.name});

  final String id;
  final UserRole role;
  final String? name;
}
