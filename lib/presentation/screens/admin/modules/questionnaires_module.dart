import 'dart:convert';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/client_questionnaire.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_questionnaire_template_form_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class QuestionnairesModule extends ConsumerWidget {
  const QuestionnairesModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);
    final selectedSalonId = salonId;

    if (selectedSalonId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Seleziona un salone per gestire i questionari cliente.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final templates =
        data.clientQuestionnaireTemplates
            .where((template) => template.salonId == selectedSalonId)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final questionnaires =
        data.clientQuestionnaires
            .where((item) => item.salonId == selectedSalonId)
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed:
                    () => _createTemplate(
                      context,
                      ref,
                      selectedSalonId,
                      templates.isEmpty,
                    ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuovo questionario'),
              ),
              OutlinedButton.icon(
                onPressed: () => _importTemplate(context, ref, selectedSalonId),
                icon: const Icon(Icons.file_upload_rounded),
                label: const Text('Importa modello'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (templates.isEmpty)
          _EmptyState(
            onCreate:
                () => _createTemplate(context, ref, selectedSalonId, true),
          )
        else
          ...templates.map(
            (template) => _TemplateCard(
              template: template,
              questionnaires: questionnaires,
              onEdit: () => _editTemplate(context, ref, template),
              onDuplicate:
                  () => _duplicateTemplate(context, ref, template, templates),
              onDelete: () => _deleteTemplate(context, ref, template),
              onSetDefault:
                  template.isDefault
                      ? null
                      : () => _setDefault(context, ref, template),
            ),
          ),
      ],
    );
  }

  Future<void> _createTemplate(
    BuildContext context,
    WidgetRef ref,
    String salonId,
    bool isFirstTemplate,
  ) async {
    final result = await showAppModalSheet<ClientQuestionnaireTemplate>(
      context: context,
      builder:
          (ctx) => ClientQuestionnaireTemplateFormSheet(
            salonId: salonId,
            isFirstTemplate: isFirstTemplate,
          ),
    );
    if (result == null) {
      return;
    }
    await _persistTemplate(ref, result);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Questionario salvato con successo.')),
    );
  }

  Future<void> _editTemplate(
    BuildContext context,
    WidgetRef ref,
    ClientQuestionnaireTemplate template,
  ) async {
    final result = await showAppModalSheet<ClientQuestionnaireTemplate>(
      context: context,
      builder:
          (ctx) => ClientQuestionnaireTemplateFormSheet(
            salonId: template.salonId,
            existing: template,
          ),
    );
    if (result == null) {
      return;
    }
    await _persistTemplate(ref, result);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Modifiche salvate.')));
  }

  Future<void> _importTemplate(
    BuildContext context,
    WidgetRef ref,
    String salonId,
  ) async {
    final result = await showDialog<_ImportTemplateResult>(
      context: context,
      builder: (ctx) => const _ImportTemplateDialog(),
    );
    if (result == null) {
      return;
    }

    try {
      final template = _deserializeTemplate(
        result.rawJson,
        salonId: salonId,
        markAsDefault: result.markAsDefault,
      );
      await _persistTemplate(ref, template);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${template.name}" importato.')));
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import non riuscito: $error')));
    }
  }

  Future<void> _setDefault(
    BuildContext context,
    WidgetRef ref,
    ClientQuestionnaireTemplate template,
  ) async {
    final updated = template.copyWith(
      isDefault: true,
      updatedAt: DateTime.now(),
    );
    await _persistTemplate(ref, updated);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${template.name}" impostato come modello predefinito.'),
      ),
    );
  }

  Future<void> _duplicateTemplate(
    BuildContext context,
    WidgetRef ref,
    ClientQuestionnaireTemplate source,
    List<ClientQuestionnaireTemplate> existing,
  ) async {
    final duplicate = _cloneTemplate(source, existing);
    await _persistTemplate(ref, duplicate);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copia di "${source.name}" creata.')),
    );
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    ClientQuestionnaireTemplate template,
  ) async {
    final data = ref.read(appDataProvider);
    final associated =
        data.clientQuestionnaires
            .where((item) => item.templateId == template.id)
            .toList();
    final fallback = data.clientQuestionnaireTemplates
        .where(
          (item) => item.salonId == template.salonId && item.id != template.id,
        )
        .sorted(
          (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
            a.updatedAt ?? DateTime(2000),
          ),
        )
        .firstWhereOrNull((_) => true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina questionario'),
            content: Text(
              associated.isEmpty
                  ? 'Confermi l\'eliminazione del questionario "${template.name}"?'
                  : 'Il questionario "${template.name}" e associato a ${associated.length} schede cliente. Eliminandolo verranno rimossi anche i dati compilati. Vuoi procedere?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }

    final store = ref.read(appDataProvider.notifier);
    await store.deleteClientQuestionnaireTemplate(template.id);
    for (final questionnaire in associated) {
      await store.deleteClientQuestionnaire(questionnaire.id);
    }

    if (template.isDefault && fallback != null) {
      await store.upsertClientQuestionnaireTemplate(
        fallback.copyWith(isDefault: true, updatedAt: DateTime.now()),
      );
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Questionario "${template.name}" eliminato.')),
    );
  }

  Future<void> _persistTemplate(
    WidgetRef ref,
    ClientQuestionnaireTemplate template,
  ) async {
    final store = ref.read(appDataProvider.notifier);
    if (template.isDefault) {
      final current = ref.read(appDataProvider).clientQuestionnaireTemplates;
      final conflicting =
          current
              .where(
                (item) =>
                    item.salonId == template.salonId &&
                    item.id != template.id &&
                    item.isDefault,
              )
              .toList();
      for (final other in conflicting) {
        await store.upsertClientQuestionnaireTemplate(
          other.copyWith(isDefault: false, updatedAt: DateTime.now()),
        );
      }
    }
    await store.upsertClientQuestionnaireTemplate(template);
  }

  ClientQuestionnaireTemplate _cloneTemplate(
    ClientQuestionnaireTemplate template,
    List<ClientQuestionnaireTemplate> existing,
  ) {
    final uuid = const Uuid();
    final now = DateTime.now();
    final newName = _resolveCopyName(template.name, existing);
    final groups =
        template.groups.map((group) {
          final newGroupId = uuid.v4();
          final questions =
              group.questions.map((question) {
                final newQuestionId = uuid.v4();
                final options =
                    question.options
                        .map(
                          (option) => ClientQuestionOption(
                            id: uuid.v4(),
                            label: option.label,
                            description: option.description,
                          ),
                        )
                        .toList();
                return ClientQuestionDefinition(
                  id: newQuestionId,
                  label: question.label,
                  type: question.type,
                  helperText: question.helperText,
                  isRequired: question.isRequired,
                  options: options,
                );
              }).toList();
          return ClientQuestionGroup(
            id: newGroupId,
            title: group.title,
            description: group.description,
            sortOrder: group.sortOrder,
            questions: questions,
          );
        }).toList();

    return ClientQuestionnaireTemplate(
      id: uuid.v4(),
      salonId: template.salonId,
      name: newName,
      description: template.description,
      createdAt: now,
      updatedAt: now,
      isDefault: false,
      groups: groups,
    );
  }

  String _resolveCopyName(
    String baseName,
    List<ClientQuestionnaireTemplate> templates,
  ) {
    final existing = templates.map((item) => item.name).toSet();
    var candidate = '$baseName (copia)';
    var counter = 2;
    while (existing.contains(candidate)) {
      candidate = '$baseName (copia $counter)';
      counter += 1;
    }
    return candidate;
  }

  ClientQuestionnaireTemplate _deserializeTemplate(
    String jsonSource, {
    required String salonId,
    required bool markAsDefault,
  }) {
    dynamic decoded;
    try {
      decoded = json.decode(jsonSource);
    } catch (error) {
      throw FormatException('JSON non valido: $error');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Il file deve contenere un oggetto JSON.');
    }
    final map = decoded;
    final uuid = const Uuid();
    final name = (map['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw const FormatException('Campo "name" mancante o vuoto.');
    }
    final description = (map['description'] as String?)?.trim();
    final groupsRaw = map['groups'];
    if (groupsRaw is! List) {
      throw const FormatException('Campo "groups" mancante o non valido.');
    }

    final groups = <ClientQuestionGroup>[];
    for (final groupEntry in groupsRaw) {
      if (groupEntry is! Map<String, dynamic>) {
        throw const FormatException('Ogni gruppo deve essere un oggetto.');
      }
      final groupId = (groupEntry['id'] as String?)?.trim() ?? uuid.v4();
      final groupTitle = (groupEntry['title'] as String?)?.trim();
      if (groupTitle == null || groupTitle.isEmpty) {
        throw FormatException('Titolo mancante per il gruppo $groupId.');
      }
      final groupDescription = (groupEntry['description'] as String?)?.trim();
      final sortOrder =
          (groupEntry['sortOrder'] as num?)?.toInt() ?? groups.length * 10;

      final questionsRaw = groupEntry['questions'];
      if (questionsRaw is! List) {
        throw FormatException(
          'Il gruppo "$groupTitle" deve contenere la lista "questions".',
        );
      }
      final questions = <ClientQuestionDefinition>[];
      for (final questionEntry in questionsRaw) {
        if (questionEntry is! Map<String, dynamic>) {
          throw FormatException(
            'Ogni domanda del gruppo "$groupTitle" deve essere un oggetto.',
          );
        }
        final questionId =
            (questionEntry['id'] as String?)?.trim() ?? uuid.v4();
        final label = (questionEntry['label'] as String?)?.trim();
        if (label == null || label.isEmpty) {
          throw FormatException(
            'Domanda senza etichetta nel gruppo "$groupTitle".',
          );
        }
        final typeRaw = (questionEntry['type'] as String?)?.trim();
        final type = _parseQuestionType(typeRaw, label);
        final helperText = (questionEntry['helperText'] as String?)?.trim();
        final isRequired = questionEntry['isRequired'] as bool? ?? false;

        final options = <ClientQuestionOption>[];
        final optionsRaw = questionEntry['options'];
        if (optionsRaw != null) {
          if (optionsRaw is! List) {
            throw FormatException(
              'Le opzioni della domanda "$label" devono essere una lista.',
            );
          }
          for (final optionEntry in optionsRaw) {
            if (optionEntry is! Map<String, dynamic>) {
              throw FormatException(
                'Le opzioni della domanda "$label" devono essere oggetti.',
              );
            }
            final optionId =
                (optionEntry['id'] as String?)?.trim() ?? uuid.v4();
            final optionLabel = (optionEntry['label'] as String?)?.trim();
            if (optionLabel == null || optionLabel.isEmpty) {
              throw FormatException(
                'Opzione senza etichetta nella domanda "$label".',
              );
            }
            final optionDescription =
                (optionEntry['description'] as String?)?.trim();
            options.add(
              ClientQuestionOption(
                id: optionId,
                label: optionLabel,
                description: optionDescription,
              ),
            );
          }
        }

        questions.add(
          ClientQuestionDefinition(
            id: questionId,
            label: label,
            type: type,
            helperText: helperText,
            isRequired: isRequired,
            options: options,
          ),
        );
      }

      groups.add(
        ClientQuestionGroup(
          id: groupId,
          title: groupTitle,
          description:
              groupDescription?.isEmpty ?? true ? null : groupDescription,
          sortOrder: sortOrder,
          questions: questions,
        ),
      );
    }

    final now = DateTime.now();
    return ClientQuestionnaireTemplate(
      id: (map['id'] as String?)?.trim() ?? uuid.v4(),
      salonId: salonId,
      name: name,
      description: description?.isEmpty ?? true ? null : description,
      isDefault: markAsDefault || (map['isDefault'] as bool? ?? false),
      createdAt: now,
      updatedAt: now,
      groups: groups,
    );
  }

  ClientQuestionType _parseQuestionType(String? value, String label) {
    if (value != null) {
      final normalized = value.trim().toLowerCase();
      for (final type in ClientQuestionType.values) {
        if (type.name.toLowerCase() == normalized) {
          return type;
        }
      }
    }
    throw FormatException('Tipo domanda non supportato per "$label".');
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nessun questionario configurato',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea il primo modello per registrare anamnesi e consenso dei clienti.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crea questionario'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.questionnaires,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.onSetDefault,
  });

  final ClientQuestionnaireTemplate template;
  final List<ClientQuestionnaire> questionnaires;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final sectionCount = template.groups.length;
    final questionCount = template.groups.fold<int>(
      0,
      (total, group) => total + group.questions.length,
    );
    final usageCount =
        questionnaires.where((item) => item.templateId == template.id).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.name,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          if (template.isDefault)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Chip(
                                label: Text('Predefinito'),
                                avatar: Icon(Icons.star_rounded, size: 18),
                              ),
                            ),
                        ],
                      ),
                      if (template.description != null) ...[
                        const SizedBox(height: 8),
                        Text(template.description!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_agenda_rounded, size: 18),
                    const SizedBox(width: 4),
                    Text('$sectionCount sezioni'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.help_outline_rounded, size: 18),
                    const SizedBox(width: 4),
                    Text('$questionCount domande'),
                  ],
                ),
                if (template.updatedAt != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Aggiornato ${dateFormat.format(template.updatedAt!)}',
                      ),
                    ],
                  ),
                if (usageCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, size: 18),
                      const SizedBox(width: 4),
                      Text('$usageCount schede cliente'),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifica'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Duplica'),
                ),
                if (onSetDefault != null)
                  OutlinedButton.icon(
                    onPressed: onSetDefault,
                    icon: const Icon(Icons.star_outline_rounded),
                    label: const Text('Imposta predefinito'),
                  ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Elimina'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportTemplateResult {
  const _ImportTemplateResult({
    required this.rawJson,
    required this.markAsDefault,
  });

  final String rawJson;
  final bool markAsDefault;
}

class _ImportTemplateDialog extends StatefulWidget {
  const _ImportTemplateDialog();

  @override
  State<_ImportTemplateDialog> createState() => _ImportTemplateDialogState();
}

class _ImportTemplateDialogState extends State<_ImportTemplateDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _markAsDefault = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importa modello'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Incolla qui il JSON del modello',
                alignLabelWithHint: true,
              ),
              autofocus: true,
              maxLines: 12,
              minLines: 6,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _markAsDefault,
              onChanged:
                  (value) => setState(() => _markAsDefault = value ?? false),
              title: const Text('Imposta come modello predefinito'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nessun testo negli appunti.'),
                      ),
                    );
                    return;
                  }
                  setState(() => _controller.text = data!.text!.trim());
                },
                icon: const Icon(Icons.paste_rounded),
                label: const Text('Incolla dagli appunti'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final raw = _controller.text.trim();
            if (raw.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Inserisci un JSON valido.')),
              );
              return;
            }
            Navigator.of(context).pop(
              _ImportTemplateResult(
                rawJson: raw,
                markAsDefault: _markAsDefault,
              ),
            );
          },
          child: const Text('Importa'),
        ),
      ],
    );
  }
}
