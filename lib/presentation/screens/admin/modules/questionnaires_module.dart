import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_questionnaire.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/client_questionnaire_template_form_sheet.dart';
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
    final clients =
        data.clients
            .where((client) => client.salonId == selectedSalonId)
            .toList()
          ..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );
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
        _QuestionnaireCompletionOverviewCard(
          templates: templates,
          questionnaires: questionnaires,
          clients: clients,
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
              clients: clients,
              onAssignToClient:
                  !template.clientCanSelfComplete || clients.isEmpty
                      ? null
                      : () => _assignToClient(
                        context,
                        ref,
                        salonId: selectedSalonId,
                        templates: <ClientQuestionnaireTemplate>[template],
                        clients: clients,
                        questionnaires: questionnaires,
                        initialTemplateId: template.id,
                      ),
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
    try {
      await _persistTemplate(ref, result);
    } catch (error, stackTrace) {
      _showQuestionnaireWriteError(context, error, stackTrace);
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showAppSnackBar(
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
    try {
      await _persistTemplate(ref, result);
    } catch (error, stackTrace) {
      _showQuestionnaireWriteError(context, error, stackTrace);
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(const SnackBar(content: Text('Modifiche salvate.')));
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('"${template.name}" importato.')),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text('Import non riuscito: $error')));
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
    try {
      await _persistTemplate(ref, updated);
    } catch (error, stackTrace) {
      _showQuestionnaireWriteError(context, error, stackTrace);
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showAppSnackBar(
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
    try {
      await _persistTemplate(ref, duplicate);
    } catch (error, stackTrace) {
      _showQuestionnaireWriteError(context, error, stackTrace);
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text('Copia di "${source.name}" creata.')),
    );
  }

  Future<void> _assignToClient(
    BuildContext context,
    WidgetRef ref, {
    required String salonId,
    required List<ClientQuestionnaireTemplate> templates,
    required List<Client> clients,
    required List<ClientQuestionnaire> questionnaires,
    String? initialTemplateId,
  }) async {
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Nessun template abilitato alla compilazione cliente disponibile.',
          ),
        ),
      );
      return;
    }
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Nessun cliente disponibile nel salone.')),
      );
      return;
    }

    final request = await showDialog<_AssignQuestionnaireRequest>(
      context: context,
      builder:
          (ctx) => _AssignQuestionnaireDialog(
            templates: templates,
            clients: clients,
            initialTemplateId: initialTemplateId,
          ),
    );
    if (request == null) {
      return;
    }

    if (request.clientIds.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Seleziona almeno un cliente.')),
      );
      return;
    }

    final template = templates.firstWhereOrNull(
      (item) => item.id == request.templateId,
    );
    if (template == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Template selezionato non trovato.')),
      );
      return;
    }
    final clientsById = {for (final client in clients) client.id: client};
    final requestedClients = request.clientIds
        .map((id) => clientsById[id])
        .whereType<Client>()
        .toList(growable: false);
    if (requestedClients.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Nessun cliente valido selezionato.')),
      );
      return;
    }

    final store = ref.read(appDataProvider.notifier);
    final assignedByUserId = ref.read(sessionControllerProvider).userId;
    var createdCount = 0;
    var skippedDuplicates = 0;
    try {
      for (final client in requestedClients) {
        final duplicatePending = questionnaires.firstWhereOrNull(
          (item) =>
              item.clientId == client.id &&
              item.templateId == request.templateId &&
              item.assignedToClientApp &&
              item.isPending,
        );
        if (duplicatePending != null) {
          skippedDuplicates += 1;
          continue;
        }

        final now = DateTime.now();
        final questionnaire = ClientQuestionnaire(
          id: const Uuid().v4(),
          clientId: client.id,
          salonId: salonId,
          templateId: request.templateId,
          answers: const <ClientQuestionAnswer>[],
          createdAt: now,
          updatedAt: now,
          status: ClientQuestionnaireStatus.assigned,
          assignedToClientApp: true,
          assignedAt: now,
          assignedByUserId: assignedByUserId,
        );
        await store.upsertClientQuestionnaire(questionnaire);
        createdCount += 1;
      }
    } catch (error, stackTrace) {
      _showQuestionnaireWriteError(context, error, stackTrace);
      return;
    }

    if (!context.mounted) {
      return;
    }
    if (createdCount == 0 && skippedDuplicates > 0) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'Nessuna nuova assegnazione creata: $skippedDuplicates gia aperte per "${template.name}".',
          ),
        ),
      );
      return;
    }

    final targetLabel =
        request.assignMode == _AssignTargetMode.all
            ? 'tutti i clienti'
            : createdCount == 1
            ? requestedClients.first.fullName
            : '$createdCount clienti';
    final skippedLabel =
        skippedDuplicates > 0 ? ' ($skippedDuplicates gia aperte saltate)' : '';
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(
          'Questionario "${template.name}" assegnato a $targetLabel$skippedLabel.',
        ),
      ),
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

    try {
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
    } catch (error, stackTrace) {
      _showQuestionnaireWriteError(context, error, stackTrace);
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showAppSnackBar(
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

  void _showQuestionnaireWriteError(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'QuestionnairesModule',
      ),
    );
    if (!context.mounted) {
      return;
    }
    final message =
        error is FirebaseException && error.code == 'permission-denied'
            ? 'Permessi insufficienti per modificare i questionari del salone selezionato.'
            : 'Operazione non riuscita: $error';
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(message)));
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
      clientCanSelfComplete: template.clientCanSelfComplete,
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
      clientCanSelfComplete: map['clientCanSelfComplete'] as bool? ?? false,
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
          ],
        ),
      ),
    );
  }
}

class _QuestionnaireCompletionOverviewCard extends StatelessWidget {
  const _QuestionnaireCompletionOverviewCard({
    required this.templates,
    required this.questionnaires,
    required this.clients,
  });

  final List<ClientQuestionnaireTemplate> templates;
  final List<ClientQuestionnaire> questionnaires;
  final List<Client> clients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templatesById = {
      for (final template in templates) template.id: template,
    };
    final clientsById = {for (final client in clients) client.id: client};
    final assignedApp = questionnaires
        .where((item) => item.assignedToClientApp)
        .toList(growable: false);
    final completed = assignedApp.where((item) => item.isCompleted).toList();
    final pending =
        assignedApp.where((item) => item.isPending).toList()..sort((a, b) {
          final aDate = a.assignedAt ?? a.createdAt;
          final bDate = b.assignedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        });

    final completionRate =
        assignedApp.isEmpty
            ? 0
            : ((completed.length / assignedApp.length) * 100).round();
    final reachableTemplates =
        templates.where((item) => item.clientCanSelfComplete).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panoramica compilazioni cliente',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Monitoraggio delle assegnazioni compilabili dall\'app cliente.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(
                  icon: Icons.article_outlined,
                  label: 'Template',
                  value: templates.length.toString(),
                  subtitle: '$reachableTemplates self-service',
                ),
                _StatChip(
                  icon: Icons.assignment_rounded,
                  label: 'Assegnati',
                  value: assignedApp.length.toString(),
                  subtitle:
                      '${clients.isEmpty ? 0 : assignedApp.map((e) => e.clientId).toSet().length} clienti',
                ),
                _StatChip(
                  icon: Icons.pending_actions_rounded,
                  label: 'Aperti',
                  value: pending.length.toString(),
                ),
                _StatChip(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Completati',
                  value: completed.length.toString(),
                  subtitle: '$completionRate%',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (pending.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Nessun questionario assegnato in attesa di compilazione.',
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'In attesa di compilazione',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.hourglass_top_rounded, size: 18),
                    label: Text('${pending.length} aperti'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Apri elenco questionari in attesa',
                    onPressed:
                        () => _showPendingQuestionnairesDialog(
                          context,
                          pending: pending,
                          clientsById: clientsById,
                          templatesById: templatesById,
                        ),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Apri l\'elenco completo dei questionari ancora da compilare.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPendingQuestionnairesDialog(
    BuildContext context, {
    required List<ClientQuestionnaire> pending,
    required Map<String, Client> clientsById,
    required Map<String, ClientQuestionnaireTemplate> templatesById,
  }) async {
    final dateFormat = DateFormat('dd/MM/yyyy');
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('In attesa di compilazione (${pending.length})'),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child:
                  pending.isEmpty
                      ? const Text('Nessun questionario aperto.')
                      : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: pending.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = pending[index];
                            final client = clientsById[item.clientId];
                            final template = templatesById[item.templateId];
                            final assignedDate =
                                item.assignedAt ?? item.createdAt;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.schedule_rounded),
                              title: Text(client?.fullName ?? 'Cliente'),
                              subtitle: Text(
                                '${template?.name ?? 'Questionario'} • assegnato ${dateFormat.format(assignedDate)}',
                              ),
                              trailing: const Chip(label: Text('Aperto')),
                            );
                          },
                        ),
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignQuestionnaireRequest {
  const _AssignQuestionnaireRequest({
    required this.templateId,
    required this.clientIds,
    required this.assignMode,
  });

  final String templateId;
  final List<String> clientIds;
  final _AssignTargetMode assignMode;
}

enum _AssignTargetMode { all, multi }

class _AssignQuestionnaireDialog extends StatefulWidget {
  const _AssignQuestionnaireDialog({
    required this.templates,
    required this.clients,
    this.initialTemplateId,
  });

  final List<ClientQuestionnaireTemplate> templates;
  final List<Client> clients;
  final String? initialTemplateId;

  @override
  State<_AssignQuestionnaireDialog> createState() =>
      _AssignQuestionnaireDialogState();
}

class _AssignQuestionnaireDialogState
    extends State<_AssignQuestionnaireDialog> {
  late String _selectedTemplateId;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedClientIds = <String>{};
  _AssignTargetMode _assignMode = _AssignTargetMode.multi;

  @override
  void initState() {
    super.initState();
    _selectedTemplateId =
        widget.templates
            .firstWhereOrNull(
              (template) => template.id == widget.initialTemplateId,
            )
            ?.id ??
        widget.templates.first.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredClients =
        query.isEmpty
            ? widget.clients
            : widget.clients
                .where((client) {
                  final name = client.fullName.toLowerCase();
                  final phone = client.phone.toLowerCase();
                  final email = (client.email ?? '').toLowerCase();
                  return name.contains(query) ||
                      phone.contains(query) ||
                      email.contains(query);
                })
                .toList(growable: false);
    final filteredIds = filteredClients.map((c) => c.id).toSet();
    final selectedFilteredCount =
        _selectedClientIds.where(filteredIds.contains).length;
    final canSelectFiltered =
        filteredClients.isNotEmpty &&
        selectedFilteredCount < filteredClients.length;

    return AlertDialog(
      title: const Text('Assegna questionario a cliente'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.templates.length == 1)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Template questionario',
                ),
                child: Text(widget.templates.first.name),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedTemplateId,
                decoration: const InputDecoration(
                  labelText: 'Template questionario',
                ),
                items:
                    widget.templates
                        .map(
                          (template) => DropdownMenuItem<String>(
                            value: template.id,
                            child: Text(template.name),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _selectedTemplateId = value);
                },
              ),
            const SizedBox(height: 12),
            Text('Destinatari', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<_AssignTargetMode>(
              segments: const [
                ButtonSegment<_AssignTargetMode>(
                  value: _AssignTargetMode.all,
                  icon: Icon(Icons.groups_rounded),
                  label: Text('Tutti i clienti'),
                ),
                ButtonSegment<_AssignTargetMode>(
                  value: _AssignTargetMode.multi,
                  icon: Icon(Icons.manage_search_rounded),
                  label: Text('Ricerca + multiselezione'),
                ),
              ],
              selected: <_AssignTargetMode>{_assignMode},
              onSelectionChanged: (selection) {
                final next = selection.firstOrNull;
                if (next == null) {
                  return;
                }
                setState(() => _assignMode = next);
              },
            ),
            const SizedBox(height: 12),
            if (_assignMode == _AssignTargetMode.all)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Verrà assegnato a ${widget.clients.length} clienti del salone.',
                ),
              )
            else ...[
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  labelText: 'Cerca cliente',
                  hintText: 'Nome, telefono o email',
                  suffixIcon:
                      _searchController.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Pulisci',
                            onPressed: () => setState(_searchController.clear),
                            icon: const Icon(Icons.close_rounded),
                          ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Selezionati: ${_selectedClientIds.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed:
                        _selectedClientIds.isEmpty
                            ? null
                            : () => setState(_selectedClientIds.clear),
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Azzera'),
                  ),
                  TextButton.icon(
                    onPressed:
                        filteredClients.isEmpty
                            ? null
                            : () {
                              setState(() {
                                if (canSelectFiltered) {
                                  _selectedClientIds.addAll(filteredIds);
                                } else {
                                  _selectedClientIds.removeAll(filteredIds);
                                }
                              });
                            },
                    icon: Icon(
                      canSelectFiltered
                          ? Icons.done_all_rounded
                          : Icons.remove_done_rounded,
                    ),
                    label: Text(
                      canSelectFiltered
                          ? 'Seleziona filtrati'
                          : 'Deseleziona filtrati',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    filteredClients.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Nessun cliente trovato.'),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            final selected = _selectedClientIds.contains(
                              client.id,
                            );
                            final subtitleParts = <String>[
                              if (client.phone.trim().isNotEmpty)
                                client.phone.trim(),
                              if ((client.email ?? '').trim().isNotEmpty)
                                (client.email ?? '').trim(),
                            ];
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              value: selected,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(client.fullName),
                              subtitle:
                                  subtitleParts.isEmpty
                                      ? null
                                      : Text(subtitleParts.join(' • ')),
                              onChanged: (value) {
                                setState(() {
                                  if (value ?? false) {
                                    _selectedClientIds.add(client.id);
                                  } else {
                                    _selectedClientIds.remove(client.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Il questionario comparira nel drawer dell\'app cliente e potra essere compilato in autonomia.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed:
              _assignMode == _AssignTargetMode.multi &&
                      _selectedClientIds.isEmpty
                  ? null
                  : () {
                    final clientIds =
                        _assignMode == _AssignTargetMode.all
                            ? widget.clients
                                .map((client) => client.id)
                                .toList(growable: false)
                            : _selectedClientIds.toList(growable: false);
                    Navigator.of(context).pop(
                      _AssignQuestionnaireRequest(
                        templateId: _selectedTemplateId,
                        clientIds: clientIds,
                        assignMode: _assignMode,
                      ),
                    );
                  },
          icon: const Icon(Icons.send_rounded),
          label: const Text('Assegna'),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.questionnaires,
    required this.clients,
    required this.onAssignToClient,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.onSetDefault,
  });

  final ClientQuestionnaireTemplate template;
  final List<ClientQuestionnaire> questionnaires;
  final List<Client> clients;
  final VoidCallback? onAssignToClient;
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
    final assignedAppQuestionnaires = questionnaires
        .where(
          (item) => item.templateId == template.id && item.assignedToClientApp,
        )
        .toList(growable: false);
    final pendingCount =
        assignedAppQuestionnaires.where((item) => item.isPending).length;
    final completedCount =
        assignedAppQuestionnaires.where((item) => item.isCompleted).length;
    final assignedClientIds =
        assignedAppQuestionnaires.map((item) => item.clientId).toSet();
    final coverageLabel =
        clients.isEmpty
            ? null
            : '${assignedClientIds.length}/${clients.length} clienti';

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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (template.isDefault)
                            const Chip(
                              label: Text('Predefinito'),
                              avatar: Icon(Icons.star_rounded, size: 18),
                            ),
                          if (template.clientCanSelfComplete)
                            const Chip(
                              label: Text('Cliente app'),
                              avatar: Icon(Icons.smartphone_rounded, size: 18),
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
                if (assignedAppQuestionnaires.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pending_actions_rounded, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Assegnati app: $completedCount completati, $pendingCount aperti',
                      ),
                    ],
                  ),
                if (coverageLabel != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups_rounded, size: 18),
                      const SizedBox(width: 4),
                      Text('Copertura: $coverageLabel'),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (template.clientCanSelfComplete)
                  FilledButton.tonalIcon(
                    onPressed: onAssignToClient,
                    icon: const Icon(Icons.assignment_ind_rounded),
                    label: const Text('Assegna a cliente'),
                  ),
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
                    ScaffoldMessenger.of(context).showAppSnackBar(
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
              ScaffoldMessenger.of(context).showAppSnackBar(
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
