import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_questionnaire.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;

class ClientAssignedQuestionnairesScreen extends ConsumerWidget {
  const ClientAssignedQuestionnairesScreen({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final templatesById = {
      for (final template in data.clientQuestionnaireTemplates.where(
        (item) => item.salonId == client.salonId,
      ))
        template.id: template,
    };
    final questionnaires =
        data.clientQuestionnaires
            .where(
              (item) => item.clientId == client.id && item.assignedToClientApp,
            )
            .toList()
          ..sort((a, b) {
            if (a.isPending != b.isPending) {
              return a.isPending ? -1 : 1;
            }
            final aDate = a.assignedAt ?? a.updatedAt;
            final bDate = b.assignedAt ?? b.updatedAt;
            return bDate.compareTo(aDate);
          });

    final pendingCount = questionnaires.where((item) => item.isPending).length;
    final completedCount =
        questionnaires.where((item) => item.isCompleted).length;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Questionari assegnati')),
      body:
          questionnaires.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Non ci sono questionari assegnati da compilare al momento.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ClientStatPill(
                            icon: Icons.pending_actions_rounded,
                            label: 'Da compilare',
                            value: pendingCount.toString(),
                          ),
                          _ClientStatPill(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Completati',
                            value: completedCount.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...questionnaires.map((questionnaire) {
                    final template = templatesById[questionnaire.templateId];
                    final assignedDate =
                        questionnaire.assignedAt ?? questionnaire.createdAt;
                    final statusLabel =
                        questionnaire.isCompleted
                            ? 'Completato'
                            : questionnaire.isDraft
                            ? 'Bozza salvata'
                            : 'Da compilare';
                    final statusColor =
                        questionnaire.isCompleted
                            ? Colors.green
                            : questionnaire.isDraft
                            ? Colors.blue
                            : Colors.orange;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          12,
                          12,
                          12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.12),
                          foregroundColor: statusColor,
                          child: Icon(
                            questionnaire.isCompleted
                                ? Icons.task_alt_rounded
                                : Icons.edit_note_rounded,
                          ),
                        ),
                        title: Text(template?.name ?? 'Questionario'),
                        subtitle: Text(
                          template == null
                              ? 'Template non disponibile'
                              : '$statusLabel • assegnato il ${dateFormat.format(assignedDate)}',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed:
                              template == null
                                  ? null
                                  : () async {
                                    final saved = await Navigator.of(
                                      context,
                                    ).push<bool>(
                                      MaterialPageRoute<bool>(
                                        builder:
                                            (_) =>
                                                _ClientQuestionnaireEditorPage(
                                                  template: template,
                                                  questionnaire: questionnaire,
                                                ),
                                      ),
                                    );
                                    if (saved == true && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showAppSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Questionario salvato.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          child: Text(
                            questionnaire.isCompleted
                                ? 'Apri'
                                : questionnaire.isDraft
                                ? 'Continua'
                                : 'Compila',
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
    );
  }
}

class _ClientStatPill extends StatelessWidget {
  const _ClientStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientQuestionnaireEditorPage extends ConsumerStatefulWidget {
  const _ClientQuestionnaireEditorPage({
    required this.template,
    required this.questionnaire,
  });

  final ClientQuestionnaireTemplate template;
  final ClientQuestionnaire questionnaire;

  @override
  ConsumerState<_ClientQuestionnaireEditorPage> createState() =>
      _ClientQuestionnaireEditorPageState();
}

class _ClientQuestionnaireEditorPageState
    extends ConsumerState<_ClientQuestionnaireEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, _QuestionDraft> _drafts = <String, _QuestionDraft>{};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final group in widget.template.groups) {
      for (final question in group.questions) {
        final existing = widget.questionnaire.answerFor(question.id);
        _drafts[question.id] = _QuestionDraft.fromAnswer(existing);
      }
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignedAt =
        widget.questionnaire.assignedAt ?? widget.questionnaire.createdAt;
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.template.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    if ((widget.template.description ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(widget.template.description!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Assegnato il ${dateFormat.format(assignedAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final group in widget.template.groups)
              _buildGroupCard(context, group),
            const SizedBox(height: 8),
            if (widget.questionnaire.isCompleted)
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveCompleted,
                icon:
                    _isSaving
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving ? 'Salvataggio...' : 'Aggiorna questionario',
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _saveDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salva bozza'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveCompleted,
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(_isSaving ? 'Salvataggio...' : 'Completa'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, ClientQuestionGroup group) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: theme.textTheme.titleMedium),
            if ((group.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(group.description!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            for (final question in group.questions)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildQuestionField(context, question),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionField(
    BuildContext context,
    ClientQuestionDefinition question,
  ) {
    final draft = _drafts[question.id]!;
    final label = question.isRequired ? '${question.label} *' : question.label;
    switch (question.type) {
      case ClientQuestionType.boolean:
        return DropdownButtonFormField<bool>(
          value: draft.boolValue,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          items: const [
            DropdownMenuItem<bool>(value: true, child: Text('Si')),
            DropdownMenuItem<bool>(value: false, child: Text('No')),
          ],
          onChanged: (value) => setState(() => draft.boolValue = value),
          validator: (_) => _validateQuestion(question, draft),
        );
      case ClientQuestionType.text:
        return TextFormField(
          controller: draft.textController,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          validator: (_) => _validateQuestion(question, draft),
        );
      case ClientQuestionType.textarea:
        return TextFormField(
          controller: draft.textController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
            alignLabelWithHint: true,
          ),
          validator: (_) => _validateQuestion(question, draft),
        );
      case ClientQuestionType.singleChoice:
        return DropdownButtonFormField<String>(
          value: draft.singleOptionId,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          items: [
            ...question.options.map(
              (option) => DropdownMenuItem<String>(
                value: option.id,
                child: Text(option.label),
              ),
            ),
          ],
          onChanged: (value) => setState(() => draft.singleOptionId = value),
          validator: (_) => _validateQuestion(question, draft),
        );
      case ClientQuestionType.multiChoice:
        return FormField<Set<String>>(
          initialValue: draft.multiOptionIds,
          validator: (_) => _validateQuestion(question, draft),
          builder: (field) {
            return InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                helperText: question.helperText,
                errorText: field.errorText,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    question.options.map((option) {
                      final selected = draft.multiOptionIds.contains(option.id);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: selected,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(option.label),
                        subtitle:
                            option.description == null
                                ? null
                                : Text(option.description!),
                        onChanged: (value) {
                          setState(() {
                            if (value ?? false) {
                              draft.multiOptionIds.add(option.id);
                            } else {
                              draft.multiOptionIds.remove(option.id);
                            }
                          });
                          field.didChange(draft.multiOptionIds);
                        },
                      );
                    }).toList(),
              ),
            );
          },
        );
      case ClientQuestionType.number:
        return TextFormField(
          controller: draft.numberController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          validator: (_) => _validateQuestion(question, draft),
        );
      case ClientQuestionType.date:
        return FormField<DateTime?>(
          initialValue: draft.dateValue,
          validator: (_) => _validateQuestion(question, draft),
          builder: (field) {
            final formatted =
                draft.dateValue == null
                    ? 'Seleziona data'
                    : DateFormat('dd/MM/yyyy').format(draft.dateValue!);
            return InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                helperText: question.helperText,
                errorText: field.errorText,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(formatted)),
                  TextButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: draft.dateValue ?? now,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (picked == null) {
                        return;
                      }
                      setState(() => draft.dateValue = picked);
                      field.didChange(picked);
                    },
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: const Text('Seleziona'),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  String? _validateQuestion(
    ClientQuestionDefinition question,
    _QuestionDraft draft,
  ) {
    if (!question.isRequired) {
      if (question.type == ClientQuestionType.number &&
          draft.numberController.text.trim().isNotEmpty &&
          num.tryParse(draft.numberController.text.trim()) == null) {
        return 'Inserisci un numero valido';
      }
      return null;
    }
    switch (question.type) {
      case ClientQuestionType.boolean:
        return draft.boolValue == null ? 'Campo obbligatorio' : null;
      case ClientQuestionType.text:
      case ClientQuestionType.textarea:
        return draft.textController.text.trim().isEmpty
            ? 'Campo obbligatorio'
            : null;
      case ClientQuestionType.singleChoice:
        return (draft.singleOptionId ?? '').isEmpty
            ? 'Campo obbligatorio'
            : null;
      case ClientQuestionType.multiChoice:
        return draft.multiOptionIds.isEmpty
            ? 'Seleziona almeno un\'opzione'
            : null;
      case ClientQuestionType.number:
        final raw = draft.numberController.text.trim();
        if (raw.isEmpty) {
          return 'Campo obbligatorio';
        }
        return num.tryParse(raw) == null ? 'Inserisci un numero valido' : null;
      case ClientQuestionType.date:
        return draft.dateValue == null ? 'Campo obbligatorio' : null;
    }
  }

  Future<void> _saveDraft() => _save(complete: false);

  Future<void> _saveCompleted() => _save(complete: true);

  List<ClientQuestionAnswer> _collectAnswers() {
    final answers = <ClientQuestionAnswer>[];
    for (final group in widget.template.groups) {
      for (final question in group.questions) {
        final draft = _drafts[question.id]!;
        final answer = draft.toAnswer(questionId: question.id);
        if (answer.hasValue) {
          answers.add(answer);
        }
      }
    }
    return answers;
  }

  Future<void> _save({required bool complete}) async {
    if (complete && !_formKey.currentState!.validate()) {
      return;
    }
    final answers = _collectAnswers();

    final now = DateTime.now();
    final updated = widget.questionnaire.copyWith(
      answers: answers,
      updatedAt: now,
      status:
          complete
              ? ClientQuestionnaireStatus.completed
              : ClientQuestionnaireStatus.draft,
      completedAt: complete ? now : null,
    );

    setState(() => _isSaving = true);
    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertClientQuestionnaire(updated);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      final code = error is FirebaseException ? error.code : 'unknown';
      final message = error is FirebaseException ? error.message : '$error';
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito [$code]: $message')),
      );
    }
  }
}

class _QuestionDraft {
  _QuestionDraft({
    bool? boolValue,
    String? textValue,
    Iterable<String>? optionIds,
    num? numberValue,
    DateTime? dateValue,
  }) : boolValue = boolValue,
       textController = TextEditingController(text: textValue ?? ''),
       numberController = TextEditingController(
         text: numberValue == null ? '' : numberValue.toString(),
       ),
       multiOptionIds = <String>{...?optionIds},
       singleOptionId =
           optionIds == null || optionIds.isEmpty ? null : optionIds.first,
       dateValue = dateValue;

  factory _QuestionDraft.fromAnswer(ClientQuestionAnswer? answer) {
    return _QuestionDraft(
      boolValue: answer?.boolValue,
      textValue: answer?.textValue,
      optionIds: answer?.optionIds,
      numberValue: answer?.numberValue,
      dateValue: answer?.dateValue,
    );
  }

  bool? boolValue;
  final TextEditingController textController;
  final TextEditingController numberController;
  final Set<String> multiOptionIds;
  String? singleOptionId;
  DateTime? dateValue;

  ClientQuestionAnswer toAnswer({required String questionId}) {
    final text = textController.text.trim();
    final numberRaw = numberController.text.trim();
    final resolvedSingle = (singleOptionId ?? '').trim();
    final optionIds =
        resolvedSingle.isNotEmpty
            ? <String>[resolvedSingle]
            : multiOptionIds.toList(growable: false);
    return ClientQuestionAnswer(
      questionId: questionId,
      boolValue: boolValue,
      textValue: text.isEmpty ? null : text,
      optionIds: optionIds,
      numberValue: numberRaw.isEmpty ? null : num.tryParse(numberRaw),
      dateValue: dateValue,
    );
  }

  void dispose() {
    textController.dispose();
    numberController.dispose();
  }
}
