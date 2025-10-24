import 'package:you_book/domain/entities/client_questionnaire.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ClientQuestionnaireTemplateFormSheet extends StatefulWidget {
  const ClientQuestionnaireTemplateFormSheet({
    super.key,
    required this.salonId,
    this.existing,
    this.isFirstTemplate = false,
  });

  final String salonId;
  final ClientQuestionnaireTemplate? existing;
  final bool isFirstTemplate;

  @override
  State<ClientQuestionnaireTemplateFormSheet> createState() =>
      _ClientQuestionnaireTemplateFormSheetState();
}

class _ClientQuestionnaireTemplateFormSheetState
    extends State<ClientQuestionnaireTemplateFormSheet> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late List<_EditableGroup> _groups;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _isDefault = existing?.isDefault ?? widget.isFirstTemplate;
    _groups =
        existing == null
            ? <_EditableGroup>[]
            : existing.groups
                .map(_EditableGroup.fromGroup)
                .toList(growable: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = MediaQuery.of(context).size.height * 0.9;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existing == null
                                ? 'Nuovo questionario'
                                : 'Modifica questionario',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome del questionario',
                            ),
                            validator:
                                (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Inserisci un nome'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Descrizione (opzionale)',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Imposta come template predefinito',
                            ),
                            subtitle: const Text(
                              'Sostituira il modello predefinito attuale',
                            ),
                            value: _isDefault,
                            onChanged:
                                (value) => setState(() => _isDefault = value),
                          ),
                          const SizedBox(height: 16),
                          if (_groups.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Aggiungi una sezione per iniziare a costruire il questionario.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          for (var i = 0; i < _groups.length; i++)
                            _buildGroupCard(index: i, group: _groups[i]),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _addGroup,
                            icon: const Icon(Icons.add),
                            label: const Text('Aggiungi sezione'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Annulla'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Salva'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupCard({required int index, required _EditableGroup group}) {
    final theme = Theme.of(context);
    final questions = group.questions;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: group.titleController,
                    decoration: InputDecoration(
                      labelText: 'Titolo sezione ${index + 1}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Sposta su',
                      onPressed: index == 0 ? null : () => _moveGroupUp(index),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Sposta giu',
                      onPressed:
                          index == _groups.length - 1
                              ? null
                              : () => _moveGroupDown(index),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Elimina sezione',
                  onPressed: () => _removeGroup(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: group.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione sezione (opzionale)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            if (questions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nessuna domanda. Aggiungi la prima domanda per questa sezione.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (var i = 0; i < questions.length; i++)
              _buildQuestionCard(
                group: group,
                questionIndex: i,
                question: questions[i],
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addQuestion(group),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Aggiungi domanda'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required _EditableGroup group,
    required int questionIndex,
    required _EditableQuestion question,
  }) {
    final requiresOptions = question.requiresOptions;
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: baseColor.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: question.labelController,
                    decoration: InputDecoration(
                      labelText: 'Domanda ${questionIndex + 1}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Sposta su',
                      onPressed:
                          questionIndex == 0
                              ? null
                              : () => _moveQuestionUp(group, questionIndex),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Sposta giu',
                      onPressed:
                          questionIndex == group.questions.length - 1
                              ? null
                              : () => _moveQuestionDown(group, questionIndex),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Elimina domanda',
                  onPressed:
                      () => _removeQuestion(group: group, index: questionIndex),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ClientQuestionType>(
              value: question.type,
              decoration: const InputDecoration(labelText: 'Tipo risposta'),
              items:
                  ClientQuestionType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_questionTypeLabel(type)),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  question.type = value;
                  if (!question.requiresOptions) {
                    for (final option in question.options) {
                      option.dispose();
                    }
                    question.options = <_EditableOption>[];
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: question.isRequired,
              title: const Text('Risposta obbligatoria'),
              onChanged: (value) => setState(() => question.isRequired = value),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: question.helperController,
              decoration: const InputDecoration(
                labelText: 'Suggerimento o note (opzionale)',
              ),
            ),
            if (requiresOptions) ...[
              const SizedBox(height: 12),
              Text(
                'Opzioni di risposta',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < question.options.length; i++)
                _buildOptionRow(
                  question: question,
                  optionIndex: i,
                  option: question.options[i],
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _addOption(question),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi opzione'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required _EditableQuestion question,
    required int optionIndex,
    required _EditableOption option,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: option.labelController,
              decoration: InputDecoration(
                labelText: 'Opzione ${optionIndex + 1}',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: option.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrizione (opzionale)',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Elimina opzione',
            onPressed:
                () => _removeOption(question: question, index: optionIndex),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  void _addGroup() {
    setState(() {
      _groups.add(
        _EditableGroup(id: _uuid.v4(), sortOrder: (_groups.length + 1) * 10),
      );
    });
  }

  void _removeGroup(int index) {
    setState(() {
      final removed = _groups.removeAt(index);
      removed.dispose();
    });
  }

  void _moveGroupUp(int index) {
    if (index <= 0) {
      return;
    }
    setState(() {
      final group = _groups.removeAt(index);
      _groups.insert(index - 1, group);
    });
  }

  void _moveGroupDown(int index) {
    if (index >= _groups.length - 1) {
      return;
    }
    setState(() {
      final group = _groups.removeAt(index);
      _groups.insert(index + 1, group);
    });
  }

  void _addQuestion(_EditableGroup group) {
    setState(() {
      group.questions.add(_EditableQuestion(id: _uuid.v4()));
    });
  }

  void _removeQuestion({required _EditableGroup group, required int index}) {
    setState(() {
      final removed = group.questions.removeAt(index);
      removed.dispose();
    });
  }

  void _moveQuestionUp(_EditableGroup group, int index) {
    if (index <= 0) {
      return;
    }
    setState(() {
      final question = group.questions.removeAt(index);
      group.questions.insert(index - 1, question);
    });
  }

  void _moveQuestionDown(_EditableGroup group, int index) {
    if (index >= group.questions.length - 1) {
      return;
    }
    setState(() {
      final question = group.questions.removeAt(index);
      group.questions.insert(index + 1, question);
    });
  }

  void _addOption(_EditableQuestion question) {
    setState(() {
      question.options.add(_EditableOption(id: _uuid.v4()));
    });
  }

  void _removeOption({
    required _EditableQuestion question,
    required int index,
  }) {
    setState(() {
      final removed = question.options.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final validationError = _validateModel();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final now = DateTime.now();
    final groups = <ClientQuestionGroup>[];
    for (var i = 0; i < _groups.length; i++) {
      final group = _groups[i];
      final title = group.titleController.text.trim();
      final description = group.descriptionController.text.trim();
      final questions = <ClientQuestionDefinition>[];
      for (final question in group.questions) {
        final label = question.labelController.text.trim();
        final helper = question.helperController.text.trim();
        final options =
            question.requiresOptions
                ? question.options
                    .map(
                      (option) => ClientQuestionOption(
                        id: option.id,
                        label: option.labelController.text.trim(),
                        description: _nullableText(
                          option.descriptionController.text,
                        ),
                      ),
                    )
                    .toList()
                : const <ClientQuestionOption>[];
        questions.add(
          ClientQuestionDefinition(
            id: question.id,
            label: label,
            type: question.type,
            helperText: helper.isEmpty ? null : helper,
            isRequired: question.isRequired,
            options: options,
          ),
        );
      }
      groups.add(
        ClientQuestionGroup(
          id: group.id,
          title: title,
          description: description.isEmpty ? null : description,
          sortOrder: i * 10,
          questions: questions,
        ),
      );
    }

    final template = ClientQuestionnaireTemplate(
      id: widget.existing?.id ?? _uuid.v4(),
      salonId: widget.salonId,
      name: _nameController.text.trim(),
      description: _nullableText(_descriptionController.text),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
      isDefault: _isDefault,
      groups: groups,
    );

    Navigator.of(context).pop(template);
  }

  String? _validateModel() {
    if (_nameController.text.trim().isEmpty) {
      return 'Inserisci un nome per il questionario';
    }
    if (_groups.isEmpty) {
      return 'Aggiungi almeno una sezione';
    }
    for (var groupIndex = 0; groupIndex < _groups.length; groupIndex++) {
      final group = _groups[groupIndex];
      final title = group.titleController.text.trim();
      if (title.isEmpty) {
        return 'Inserisci il titolo della sezione ${groupIndex + 1}';
      }
      if (group.questions.isEmpty) {
        return 'Aggiungi almeno una domanda alla sezione ${groupIndex + 1}';
      }
      for (
        var questionIndex = 0;
        questionIndex < group.questions.length;
        questionIndex++
      ) {
        final question = group.questions[questionIndex];
        if (question.labelController.text.trim().isEmpty) {
          return 'Inserisci il testo della domanda ${questionIndex + 1} nella sezione ${groupIndex + 1}';
        }
        if (question.requiresOptions) {
          if (question.options.length < 2) {
            return 'La domanda ${questionIndex + 1} della sezione ${groupIndex + 1} richiede almeno due opzioni';
          }
          for (
            var optionIndex = 0;
            optionIndex < question.options.length;
            optionIndex++
          ) {
            final option = question.options[optionIndex];
            if (option.labelController.text.trim().isEmpty) {
              return 'L\'opzione ${optionIndex + 1} della domanda ${questionIndex + 1} (sezione ${groupIndex + 1}) deve avere un nome';
            }
          }
        }
      }
    }
    return null;
  }

  String _questionTypeLabel(ClientQuestionType type) {
    switch (type) {
      case ClientQuestionType.boolean:
        return 'Si/No';
      case ClientQuestionType.text:
        return 'Testo breve';
      case ClientQuestionType.textarea:
        return 'Testo lungo';
      case ClientQuestionType.singleChoice:
        return 'Scelta singola';
      case ClientQuestionType.multiChoice:
        return 'Scelta multipla';
      case ClientQuestionType.number:
        return 'Numero';
      case ClientQuestionType.date:
        return 'Data';
    }
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _EditableGroup {
  _EditableGroup({
    required this.id,
    this.sortOrder = 0,
    String? title,
    String? description,
    List<_EditableQuestion>? questions,
  }) : titleController = TextEditingController(text: title ?? ''),
       descriptionController = TextEditingController(text: description ?? ''),
       questions = questions ?? <_EditableQuestion>[];

  factory _EditableGroup.fromGroup(ClientQuestionGroup group) {
    return _EditableGroup(
      id: group.id,
      sortOrder: group.sortOrder,
      title: group.title,
      description: group.description,
      questions: group.questions
          .map(_EditableQuestion.fromDefinition)
          .toList(growable: true),
    );
  }

  final String id;
  final int sortOrder;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final List<_EditableQuestion> questions;

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    for (final question in questions) {
      question.dispose();
    }
  }
}

class _EditableQuestion {
  _EditableQuestion({
    required this.id,
    this.type = ClientQuestionType.boolean,
    this.isRequired = false,
    String? label,
    String? helperText,
    List<_EditableOption>? options,
  }) : labelController = TextEditingController(text: label ?? ''),
       helperController = TextEditingController(text: helperText ?? ''),
       options = options ?? <_EditableOption>[];

  factory _EditableQuestion.fromDefinition(
    ClientQuestionDefinition definition,
  ) {
    return _EditableQuestion(
      id: definition.id,
      type: definition.type,
      isRequired: definition.isRequired,
      label: definition.label,
      helperText: definition.helperText,
      options: definition.options
          .map(_EditableOption.fromOption)
          .toList(growable: true),
    );
  }

  final String id;
  ClientQuestionType type;
  bool isRequired;
  final TextEditingController labelController;
  final TextEditingController helperController;
  List<_EditableOption> options;

  bool get requiresOptions =>
      type == ClientQuestionType.singleChoice ||
      type == ClientQuestionType.multiChoice;

  void dispose() {
    labelController.dispose();
    helperController.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _EditableOption {
  _EditableOption({required this.id, String? label, String? description})
    : labelController = TextEditingController(text: label ?? ''),
      descriptionController = TextEditingController(text: description ?? '');

  factory _EditableOption.fromOption(ClientQuestionOption option) {
    return _EditableOption(
      id: option.id,
      label: option.label,
      description: option.description,
    );
  }

  final String id;
  final TextEditingController labelController;
  final TextEditingController descriptionController;

  void dispose() {
    labelController.dispose();
    descriptionController.dispose();
  }
}
