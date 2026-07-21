import 'dart:async';
import 'dart:typed_data';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_day_checklist.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_photo.dart';
import 'package:you_book/domain/entities/client_questionnaire.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_absence_request.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/presentation/common/app_version_badge.dart';
import 'package:you_book/presentation/common/app_feedback_dialog.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/common/theme_mode_action.dart';
import 'package:you_book/presentation/common/hybrid_image_picker.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_calendar_view.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_anomaly.dart';
import 'package:you_book/presentation/screens/staff/forms/staff_absence_request_form_sheet.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';
import 'package:you_book/presentation/shared/widgets/client_notes_section.dart';
import 'package:collection/collection.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

enum _StaffSupportAction { rateApp, feedback }

class _AppointmentDetailSheet extends ConsumerWidget {
  const _AppointmentDetailSheet({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == appointment.clientId,
    );
    final appointmentServices =
        appointment.serviceIds
            .map(
              (id) =>
                  data.services.firstWhereOrNull((element) => element.id == id),
            )
            .whereType<Service>()
            .toList();
    final serviceLabel =
        appointmentServices.isNotEmpty
            ? appointmentServices.map((service) => service.name).join(' + ')
            : 'Servizio';
    final staff = data.staff.firstWhereOrNull(
      (element) => element.id == appointment.staffId,
    );
    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == appointment.salonId,
    );
    final room = salon?.rooms.firstWhereOrNull(
      (element) => element.id == appointment.roomId,
    );

    final now = DateTime.now();
    final historyThreshold = now.subtract(const Duration(days: 730));
    final historyAppointments =
        data.appointments
            .where(
              (appt) =>
                  appt.clientId == appointment.clientId &&
                  appt.id != appointment.id &&
                  appt.start.isAfter(historyThreshold) &&
                  appt.start.isBefore(now),
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final upcomingAppointments =
        data.appointments
            .where(
              (appt) =>
                  appt.clientId == appointment.clientId &&
                  appt.id != appointment.id &&
                  appt.start.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final purchases =
        resolveClientPackagePurchases(
          sales: data.sales,
          packages: data.packages,
          appointments: data.appointments,
          services: data.services,
          clientId: appointment.clientId,
          salonId: appointment.salonId,
        ).where((purchase) => purchase.isActive).toList();

    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final timeFormatter = DateFormat('HH:mm');
    final currencyFormatter = NumberFormat.simpleCurrency(locale: 'it_IT');

    final startLabel = dateFormatter.format(appointment.start);
    final endLabel = timeFormatter.format(appointment.end);
    final durationLabel = _formatDuration(appointment.duration);
    final roomLabel = room?.name ?? 'Non assegnata';
    final notes = appointment.notes?.trim();
    final notesLabel =
        (notes == null || notes.isEmpty) ? 'Nessuna nota' : notes;

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final detailContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Data e ora',
                  value: '$startLabel • $endLabel',
                ),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Durata',
                  value: durationLabel,
                ),
                if (staff != null)
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Staff',
                    value: staff.fullName,
                  ),
                _InfoRow(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Cabina',
                  value: roomLabel,
                ),
                _InfoRow(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Note',
                  value: notesLabel,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Scheda cliente', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (client == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.person_off_outlined),
              title: Text('Cliente non disponibile'),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.fullName, style: theme.textTheme.titleMedium),
                  if (client.clientNumber != null &&
                      client.clientNumber!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Codice cliente: ${client.clientNumber}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefono',
                    value: client.phone,
                  ),
                  if (client.email != null && client.email!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: client.email!,
                    ),
                  if (client.notes != null && client.notes!.trim().isNotEmpty)
                    _InfoRow(
                      icon: Icons.note_alt_outlined,
                      label: 'Note cliente',
                      value: client.notes!.trim(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClientNotesSection(client: client),
          const SizedBox(height: 16),
          Text('Questionari cliente', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _StaffClientQuestionnairesSection(client: client),
          const SizedBox(height: 16),
          Text('Foto cliente', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _StaffClientPhotosSection(client: client),
        ],
        const SizedBox(height: 16),
        Text('Pacchetti attivi', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (purchases.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('Nessun pacchetto attivo'),
            ),
          )
        else
          ...purchases.map((purchase) {
            final remaining = purchase.remainingSessions;
            final totalSessions = purchase.totalSessions;
            String sessionsLabel;
            if (remaining != null && totalSessions != null) {
              sessionsLabel = '$remaining / $totalSessions sessioni';
            } else if (remaining != null) {
              sessionsLabel = '$remaining sessioni residue';
            } else {
              sessionsLabel = 'Sessioni non disponibili';
            }
            final expiration = purchase.expirationDate;
            final expirationLabel =
                expiration != null
                    ? DateFormat('dd/MM/yyyy').format(expiration)
                    : 'Nessuna scadenza';
            return Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(purchase.displayName),
                subtitle: Text('$sessionsLabel • $expirationLabel'),
                trailing: Text(
                  currencyFormatter.format(purchase.totalAmount),
                  style: theme.textTheme.labelMedium,
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        Text('Prossimi appuntamenti', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (upcomingAppointments.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.event_available_outlined),
              title: Text('Nessun appuntamento in programma'),
            ),
          )
        else
          ...upcomingAppointments.take(5).map((appt) {
            final upcomingService = data.services.firstWhereOrNull(
              (service) => service.id == appt.serviceId,
            );
            final upcomingDate = dateFormatter.format(appt.start);
            return _AppointmentSummaryCard(
              icon: Icons.calendar_month_outlined,
              title: upcomingService?.name ?? 'Servizio',
              subtitle: upcomingDate,
              status: appt.status,
            );
          }),
        const SizedBox(height: 16),
        if (historyAppointments.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.history_toggle_off_outlined),
              title: Text('Nessun appuntamento nello storico'),
            ),
          )
        else
          Card(
            child: ExpansionTile(
              title: const Text('Storico appuntamenti (ultimi 24 mesi)'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children:
                  historyAppointments.map((appt) {
                    final historyService = data.services.firstWhereOrNull(
                      (service) => service.id == appt.serviceId,
                    );
                    final historyStaff = data.staff.firstWhereOrNull(
                      (member) => member.id == appt.staffId,
                    );
                    final historyDate = dateFormatter.format(appt.start);
                    final historyDuration = _formatDuration(appt.duration);
                    final subtitleParts = [historyDate, historyDuration];
                    if (historyStaff != null) {
                      subtitleParts.add(historyStaff.fullName);
                    }
                    return _AppointmentSummaryCard(
                      margin: const EdgeInsets.only(top: 8),
                      icon: Icons.history_rounded,
                      title: historyService?.name ?? 'Servizio',
                      subtitle: subtitleParts.join(' • '),
                      status: appt.status,
                    );
                  }).toList(),
            ),
          ),
      ],
    );

    if (isAppSheetPhoneLayout(context)) {
      return AppMobileSheetPageScaffold(
        title: 'Dettaglio appuntamento',
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: detailContent,
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Text('Dettagli appuntamento', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              detailContent,
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffClientQuestionnairesSection extends ConsumerWidget {
  const _StaffClientQuestionnairesSection({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final templates =
        data.clientQuestionnaireTemplates
            .where((template) => template.salonId == client.salonId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final templatesById = {
      for (final template in templates) template.id: template,
    };
    final questionnaires =
        data.clientQuestionnaires
            .where((item) => item.clientId == client.id)
            .where((item) => item.isCompleted)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (questionnaires.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.list_alt_rounded),
          title: Text('Nessun questionario compilato'),
        ),
      );
    }

    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      children:
          questionnaires.map((questionnaire) {
            final template = templatesById[questionnaire.templateId];
            final updatedLabel = dateFormat.format(questionnaire.updatedAt);
            final createdLabel = dateFormat.format(questionnaire.createdAt);
            final subtitle =
                questionnaire.updatedAt.isAfter(questionnaire.createdAt)
                    ? 'Aggiornato il $updatedLabel'
                    : 'Compilato il $createdLabel';
            return Card(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  template?.name ?? 'Questionario cliente',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _QuestionnaireAnswerList(
                      template: template,
                      questionnaire: questionnaire,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

class _QuestionnaireAnswerList extends StatelessWidget {
  const _QuestionnaireAnswerList({
    required this.template,
    required this.questionnaire,
  });

  final ClientQuestionnaireTemplate? template;
  final ClientQuestionnaire questionnaire;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answersById = {
      for (final answer in questionnaire.answers) answer.questionId: answer,
    };

    if (template == null) {
      final answered =
          questionnaire.answers.where((answer) => answer.hasValue).toList();
      if (answered.isEmpty) {
        return Text(
          'Nessuna risposta disponibile.',
          style: theme.textTheme.bodySmall,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            answered
                .map(
                  (answer) => _QuestionAnswerRow(
                    label: 'Domanda ${answer.questionId}',
                    value: _fallbackAnswerLabel(answer),
                  ),
                )
                .toList(),
      );
    }

    final children = <Widget>[];
    for (final group in template!.groups) {
      final groupAnswers = <Widget>[];
      for (final question in group.questions) {
        final answer = answersById[question.id];
        if (answer == null || !answer.hasValue) {
          continue;
        }
        final value = _formatAnswer(answer, question);
        if (value == null || value.isEmpty) {
          continue;
        }
        groupAnswers.add(
          _QuestionAnswerRow(label: question.label, value: value),
        );
      }
      if (groupAnswers.isNotEmpty) {
        children
          ..add(Text(group.title, style: theme.textTheme.titleSmall))
          ..add(const SizedBox(height: 8))
          ..addAll(groupAnswers)
          ..add(const SizedBox(height: 12));
      }
    }

    if (children.isEmpty) {
      return Text(
        'Nessuna risposta disponibile.',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _fallbackAnswerLabel(ClientQuestionAnswer answer) {
    if (answer.boolValue != null) {
      return answer.boolValue! ? 'Sì' : 'No';
    }
    if (answer.textValue != null && answer.textValue!.trim().isNotEmpty) {
      return answer.textValue!.trim();
    }
    if (answer.optionIds.isNotEmpty) {
      return answer.optionIds.join(', ');
    }
    if (answer.numberValue != null) {
      return answer.numberValue!.toString();
    }
    if (answer.dateValue != null) {
      return DateFormat('dd/MM/yyyy').format(answer.dateValue!);
    }
    return '-';
  }

  static String? _formatAnswer(
    ClientQuestionAnswer answer,
    ClientQuestionDefinition question,
  ) {
    switch (question.type) {
      case ClientQuestionType.boolean:
        if (answer.boolValue == null) {
          return null;
        }
        return answer.boolValue! ? 'Sì' : 'No';
      case ClientQuestionType.text:
      case ClientQuestionType.textarea:
        final text = answer.textValue?.trim();
        return text == null || text.isEmpty ? null : text;
      case ClientQuestionType.singleChoice:
      case ClientQuestionType.multiChoice:
        if (answer.optionIds.isEmpty) {
          return null;
        }
        final labels =
            answer.optionIds
                .map(
                  (id) =>
                      question.options
                          .firstWhereOrNull((option) => option.id == id)
                          ?.label ??
                      id,
                )
                .toList();
        return labels.join(', ');
      case ClientQuestionType.number:
        return answer.numberValue?.toString();
      case ClientQuestionType.date:
        return answer.dateValue == null
            ? null
            : DateFormat('dd/MM/yyyy').format(answer.dateValue!);
    }
  }
}

class _QuestionAnswerRow extends StatelessWidget {
  const _QuestionAnswerRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StaffClientPhotosSection extends ConsumerStatefulWidget {
  const _StaffClientPhotosSection({required this.client});

  final Client client;

  @override
  ConsumerState<_StaffClientPhotosSection> createState() =>
      _StaffClientPhotosSectionState();
}

class _StaffClientPhotosSectionState
    extends ConsumerState<_StaffClientPhotosSection> {
  static const int _maxUploadBytes = 10 * 1024 * 1024;
  static const List<ClientPhotoSetType> _orderedPhotoSets =
      <ClientPhotoSetType>[
        ClientPhotoSetType.front,
        ClientPhotoSetType.back,
        ClientPhotoSetType.right,
        ClientPhotoSetType.left,
      ];
  final Uuid _uuid = const Uuid();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = ref.watch(clientPhotosProvider(widget.client.id));
    final grouped = <ClientPhotoSetType, List<ClientPhoto>>{};
    for (final type in _orderedPhotoSets) {
      grouped[type] =
          photos.where((photo) => photo.setType == type).toList()
            ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    }
    final otherPhotos =
        photos.where((photo) => photo.setType == null).toList()
          ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    final completedSets =
        grouped.values
            .where(
              (setPhotos) => setPhotos.any((photo) => photo.isSetActiveVersion),
            )
            .length;

    final summary =
        photos.isEmpty
            ? 'Nessuna foto disponibile'
            : '$completedSets/4 set completati · ${photos.length} foto';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Archivio fotografico',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(summary, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Aggiorna elenco foto',
                  onPressed:
                      _isUploading
                          ? null
                          : () => ref.invalidate(
                            clientPhotosProvider(widget.client.id),
                          ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isUploading ? null : () => _pickAndUploadFullSet(),
                  icon: const Icon(Icons.grid_on_outlined),
                  label: const Text('Carica set completo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _orderedPhotoSets
                    .map((type) {
                      final setPhotos = grouped[type] ?? const <ClientPhoto>[];
                      final activePhoto = _resolveActivePhoto(setPhotos);
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _StaffPhotoSetTile(
                          label: _setLabel(type),
                          activePhoto: activePhoto,
                          totalPhotos: setPhotos.length,
                          isUploading: _isUploading,
                          onPreview:
                              activePhoto == null
                                  ? null
                                  : () => _showPhotoPreview(activePhoto),
                          onShowHistory: () => _showSetHistory(type, setPhotos),
                          onUpload: () => _pickAndUpload(type),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            if (otherPhotos.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Altre foto', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: otherPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final photo = otherPhotos[index];
                  return _StaffPhotoListTile(
                    photo: photo,
                    onPreview: () => _showPhotoPreview(photo),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ClientPhotoSetType setType) async {
    final selectedFile = await _pickSingleImageFile();
    if (selectedFile == null) {
      return;
    }
    final assignments = <_PhotoSetAssignment>[
      _PhotoSetAssignment(setType: setType, file: selectedFile),
    ];
    await _uploadAssignments(assignments, setLabel: _setLabel(setType));
  }

  Future<void> _pickAndUploadFullSet() async {
    final files = await _pickImageFiles(maxSelection: _orderedPhotoSets.length);
    if (files.isEmpty) {
      return;
    }
    if (files.length < _orderedPhotoSets.length) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Seleziona quattro foto per coprire Frontale, Dietro, Destra e Sinistra.',
          ),
        ),
      );
      return;
    }
    final assignments = <_PhotoSetAssignment>[];
    for (var i = 0; i < _orderedPhotoSets.length; i++) {
      assignments.add(
        _PhotoSetAssignment(setType: _orderedPhotoSets[i], file: files[i]),
      );
    }
    await _uploadAssignments(assignments, setLabel: 'set completo');
  }

  Future<void> _uploadAssignments(
    List<_PhotoSetAssignment> assignments, {
    required String setLabel,
  }) async {
    if (assignments.isEmpty) {
      return;
    }
    final storage = ref.read(firebaseStorageServiceProvider);
    final dataStore = ref.read(appDataProvider.notifier);
    final session = ref.read(sessionControllerProvider);
    final uploaderId = session.uid ?? 'unknown';
    final existingPhotos = ref.read(clientPhotosProvider(widget.client.id));
    final Map<ClientPhotoSetType, int> nextVersionIndex = {};
    for (final assignment in assignments) {
      nextVersionIndex.putIfAbsent(
        assignment.setType,
        () => _nextVersionSeed(existingPhotos, assignment.setType),
      );
    }
    final Map<ClientPhotoSetType, String> lastUploadedBySet = {};

    setState(() => _isUploading = true);
    try {
      var uploadedCount = 0;
      final skippedTooLarge = <String>[];
      final skippedUnreadable = <String>[];

      for (final assignment in assignments) {
        final file = assignment.file;
        if (file.sizeBytes > _maxUploadBytes) {
          skippedTooLarge.add(file.name);
          continue;
        }
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          skippedUnreadable.add(file.name);
          continue;
        }
        final upload = await storage.uploadClientPhoto(
          salonId: widget.client.salonId,
          clientId: widget.client.id,
          photoId: _uuid.v4(),
          uploaderId: uploaderId,
          data: bytes,
          fileName: file.name,
        );
        final versionIndex = nextVersionIndex[assignment.setType]!;
        nextVersionIndex[assignment.setType] = versionIndex + 1;
        final photo = ClientPhoto(
          id: upload.photoId,
          salonId: upload.salonId,
          clientId: upload.clientId,
          storagePath: upload.storagePath,
          downloadUrl: upload.downloadUrl,
          uploadedAt: upload.uploadedAt,
          uploadedBy: upload.uploadedBy,
          fileName: upload.fileName,
          contentType: upload.contentType,
          sizeBytes: upload.sizeBytes,
          setType: assignment.setType,
          setVersionIndex: versionIndex,
          isSetActiveVersion: true,
        );
        await dataStore.upsertClientPhoto(photo);
        lastUploadedBySet[assignment.setType] = photo.id;
        uploadedCount += 1;
      }

      for (final entry in lastUploadedBySet.entries) {
        await dataStore.activateClientPhotoVersion(
          clientId: widget.client.id,
          setType: entry.key,
          photoId: entry.value,
        );
      }

      if (!mounted) {
        return;
      }
      if (uploadedCount > 0) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              uploadedCount == assignments.length
                  ? 'Foto caricate correttamente nel $setLabel.'
                  : '$uploadedCount foto caricate nel $setLabel.',
            ),
          ),
        );
      }
      if (skippedTooLarge.isNotEmpty || skippedUnreadable.isNotEmpty) {
        final messages = <String>[];
        if (skippedTooLarge.isNotEmpty) {
          messages.add(
            'File troppo grandi (>${_maxUploadBytes ~/ (1024 * 1024)} MB): ${skippedTooLarge.join(', ')}',
          );
        }
        if (skippedUnreadable.isNotEmpty) {
          messages.add('File non leggibili: ${skippedUnreadable.join(', ')}');
        }
        ScaffoldMessenger.of(
          context,
        ).showAppSnackBar(SnackBar(content: Text(messages.join('\n'))));
      }
      if (uploadedCount == 0 &&
          skippedTooLarge.isEmpty &&
          skippedUnreadable.isEmpty) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(content: Text('Nessun file valido selezionato.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile caricare le foto: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<_PickedClientImage?> _pickSingleImageFile() async {
    final file = await pickSingleImageFile(confirmButtonText: 'Seleziona');
    if (file == null) {
      return null;
    }
    int sizeBytes = 0;
    try {
      sizeBytes = await file.length();
    } catch (_) {
      sizeBytes = 0;
    }
    Uint8List? bytes;
    if (sizeBytes == 0 || sizeBytes <= _maxUploadBytes) {
      bytes = await _resolveXFileBytes(file);
      if (sizeBytes == 0) {
        sizeBytes = bytes?.length ?? 0;
      }
    }
    return _PickedClientImage(
      name: file.name.isEmpty ? 'Foto cliente' : file.name,
      sizeBytes: sizeBytes,
      bytes: bytes,
    );
  }

  Future<List<_PickedClientImage>> _pickImageFiles({int? maxSelection}) async {
    final selectedFiles = await pickMultipleImageFiles(
      confirmButtonText: 'Seleziona',
      limit: maxSelection,
    );
    if (selectedFiles.isEmpty) {
      return const <_PickedClientImage>[];
    }
    if (maxSelection != null && selectedFiles.length > maxSelection) {
      if (!mounted) {
        return const <_PickedClientImage>[];
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'Puoi selezionare al massimo $maxSelection foto per questa operazione.',
          ),
        ),
      );
      return const <_PickedClientImage>[];
    }
    final files = <_PickedClientImage>[];
    for (final file in selectedFiles) {
      int sizeBytes = 0;
      try {
        sizeBytes = await file.length();
      } catch (_) {
        sizeBytes = 0;
      }
      Uint8List? bytes;
      if (sizeBytes == 0 || sizeBytes <= _maxUploadBytes) {
        bytes = await _resolveXFileBytes(file);
        if (sizeBytes == 0) {
          sizeBytes = bytes?.length ?? 0;
        }
      }
      files.add(
        _PickedClientImage(
          name: file.name.isEmpty ? 'Foto cliente' : file.name,
          sizeBytes: sizeBytes,
          bytes: bytes,
        ),
      );
    }
    return files;
  }

  Future<Uint8List?> _resolveXFileBytes(XFile file) async {
    try {
      final data = await file.readAsBytes();
      if (data.length > _maxUploadBytes) {
        return null;
      }
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  int _nextVersionSeed(List<ClientPhoto> existing, ClientPhotoSetType type) {
    var maxVersion = 0;
    for (final photo in existing) {
      if (photo.setType != type) {
        continue;
      }
      final version = photo.setVersionIndex ?? 0;
      if (version > maxVersion) {
        maxVersion = version;
      }
    }
    return maxVersion + 1;
  }

  ClientPhoto? _resolveActivePhoto(List<ClientPhoto> photos) {
    if (photos.isEmpty) {
      return null;
    }
    for (final photo in photos) {
      if (photo.isSetActiveVersion) {
        return photo;
      }
    }
    return photos.first;
  }

  void _showPhotoPreview(ClientPhoto photo) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final width = MediaQuery.sizeOf(context).width;
        final height = MediaQuery.sizeOf(context).height;
        final maxWidth = width * 0.85;
        final maxHeight = height * 0.7;
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      photo.downloadUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(photo.uploadedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSetHistory(ClientPhotoSetType type, List<ClientPhoto> setPhotos) {
    final sorted = List<ClientPhoto>.from(setPhotos)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child:
                  sorted.isEmpty
                      ? const Text('Nessuna foto disponibile per questo set.')
                      : ListView.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final photo = sorted[index];
                          return _StaffPhotoListTile(
                            photo: photo,
                            onPreview: () {
                              Navigator.of(context).pop();
                              _showPhotoPreview(photo);
                            },
                          );
                        },
                      ),
            ),
          ),
    );
  }

  String _setLabel(ClientPhotoSetType type) {
    switch (type) {
      case ClientPhotoSetType.front:
        return 'Frontale';
      case ClientPhotoSetType.back:
        return 'Dietro';
      case ClientPhotoSetType.right:
        return 'Destra';
      case ClientPhotoSetType.left:
        return 'Sinistra';
    }
  }
}

class _StaffPhotoSetTile extends StatelessWidget {
  const _StaffPhotoSetTile({
    required this.label,
    required this.activePhoto,
    required this.totalPhotos,
    required this.isUploading,
    required this.onUpload,
    required this.onShowHistory,
    this.onPreview,
  });

  final String label;
  final ClientPhoto? activePhoto;
  final int totalPhotos;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onShowHistory;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: totalPhotos == 0 ? null : onShowHistory,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    activePhoto == null
                        ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                          ),
                          child: const Icon(Icons.photo_outlined, size: 32),
                        )
                        : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              activePhoto!.downloadUrl,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '$totalPhotos',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalPhotos == 0 ? 'Nessuna foto' : '$totalPhotos foto',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Carica foto',
                  onPressed: isUploading ? null : onUpload,
                  icon: const Icon(Icons.upload_rounded),
                ),
              ],
            ),
            if (activePhoto != null && onPreview != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onPreview,
                  child: const Text('Apri'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffPhotoListTile extends StatelessWidget {
  const _StaffPhotoListTile({required this.photo, required this.onPreview});

  final ClientPhoto photo;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onPreview,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photo.downloadUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(
        DateFormat('dd/MM/yyyy HH:mm').format(photo.uploadedAt),
        style: theme.textTheme.bodyMedium,
      ),
      subtitle:
          photo.fileName == null || photo.fileName!.trim().isEmpty
              ? null
              : Text(photo.fileName!),
      trailing: const Icon(Icons.open_in_full_rounded),
    );
  }
}

class _PhotoSetAssignment {
  const _PhotoSetAssignment({required this.setType, required this.file});

  final ClientPhotoSetType setType;
  final _PickedClientImage file;
}

class _PickedClientImage {
  const _PickedClientImage({
    required this.name,
    required this.sizeBytes,
    required this.bytes,
  });

  final String name;
  final int sizeBytes;
  final Uint8List? bytes;
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final staffMembers = data.staff;
    final staffId = session.user?.staffId ?? session.userId;
    final selectedStaff = staffMembers.firstWhereOrNull(
      (member) => member.id == staffId,
    );

    if (staffMembers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (selectedStaff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const Center(
          child: Text('Nessun profilo staff collegato a questo account.'),
        ),
      );
    }

    final staffAbsences =
        data.staffAbsences
            .where((absence) => absence.staffId == selectedStaff?.id)
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final staffAbsenceRequests =
        data.staffAbsenceRequests.toList()..sort((a, b) {
          final left = a.createdAt ?? a.start;
          final right = b.createdAt ?? b.start;
          return right.compareTo(left);
        });
    final staffShifts =
        data.shifts
            .where((shift) => shift.staffId == selectedStaff?.id)
            .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Ciao ${selectedStaff?.fullName.split(' ').first ?? 'Staff'}',
          ),
          bottom: const TabBar(
            tabs: [Tab(text: 'Agenda'), Tab(text: 'Ferie & Permessi')],
          ),
          actions: [
            PopupMenuButton<_StaffSupportAction>(
              tooltip: 'Supporto',
              icon: const Icon(Icons.support_agent_rounded),
              onSelected: (action) {
                switch (action) {
                  case _StaffSupportAction.rateApp:
                    unawaited(_rateApp());
                    break;
                  case _StaffSupportAction.feedback:
                    unawaited(
                      showAppFeedbackDialog(
                        context,
                        ref,
                        source: 'staff_dashboard_app_bar',
                      ),
                    );
                    break;
                }
              },
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: _StaffSupportAction.rateApp,
                      child: ListTile(
                        leading: Icon(Icons.star_rate_rounded),
                        title: Text('Valuta l\'app'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _StaffSupportAction.feedback,
                      child: ListTile(
                        leading: Icon(Icons.feedback_rounded),
                        title: Text('Invia feedback app'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
            ),
            const ThemeModeAction(),
            IconButton(
              tooltip: 'Esci',
              onPressed: () async {
                await performSignOut(ref);
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: TabBarView(
                children: [
                  _AgendaView(
                    staff: selectedStaff,
                    appointments: data.appointments,
                    absences: data.staffAbsences,
                    shifts: data.shifts,
                  ),
                  _AbsenceView(
                    staff: selectedStaff,
                    absences: staffAbsences,
                    requests: staffAbsenceRequests,
                    shifts: staffShifts,
                  ),
                ],
              ),
            ),
            const AppVersionBadge(),
          ],
        ),
      ),
    );
  }

  Future<void> _rateApp() async {
    final launched = await ref
        .read(appRatingServiceProvider)
        .openStoreListing(source: 'staff_dashboard_app_bar');
    if (!mounted || launched) {
      return;
    }
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Impossibile aprire lo store.')),
    );
  }
}

class _TodayView extends ConsumerWidget {
  const _TodayView({required this.appointments});

  final List<Appointment> appointments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider);
    final sortedAppointments = List<Appointment>.from(appointments)
      ..sort((a, b) => a.start.compareTo(b.start));
    final now = DateTime.now();
    final nextAppointment = sortedAppointments.firstWhereOrNull(
      (appointment) => appointment.end.isAfter(now),
    );
    final nextClient =
        nextAppointment == null
            ? null
            : data.clients.firstWhereOrNull(
              (client) => client.id == nextAppointment.clientId,
            );
    final nextServices =
        nextAppointment == null
            ? const <Service>[]
            : nextAppointment.serviceIds
                .map(
                  (id) => data.services.firstWhereOrNull(
                    (service) => service.id == id,
                  ),
                )
                .whereType<Service>()
                .toList();
    final nextServiceLabel =
        nextServices.isNotEmpty
            ? nextServices.map((service) => service.name).join(' + ')
            : 'Servizio';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nextAppointment != null) ...[
            Text('Prossimo appuntamento', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _NextAppointmentCard(
              clientName: nextClient?.fullName ?? 'Cliente',
              clientInitial:
                  nextClient?.firstName.characters.firstOrNull?.toUpperCase() ??
                  '?',
              serviceLabel: nextServiceLabel,
              durationLabel: _formatDuration(nextAppointment.duration),
              timeLabel:
                  '${DateFormat('HH:mm').format(nextAppointment.start)} - ${DateFormat('HH:mm').format(nextAppointment.end)}',
              onTap: () => _showAppointmentDetails(context, nextAppointment),
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _TodayCard(
                icon: Icons.event_available_rounded,
                title: 'Appuntamenti di oggi',
                value: '${sortedAppointments.length}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Agenda di oggi', style: theme.textTheme.titleLarge),
              Text(
                '${sortedAppointments.length} appuntamenti',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sortedAppointments.isEmpty)
            const Card(child: ListTile(title: Text('Nessun appuntamento oggi')))
          else
            ...sortedAppointments.map((appointment) {
              final client = data.clients.firstWhereOrNull(
                (client) => client.id == appointment.clientId,
              );
              final services =
                  appointment.serviceIds
                      .map(
                        (id) => data.services.firstWhereOrNull(
                          (service) => service.id == id,
                        ),
                      )
                      .whereType<Service>()
                      .toList();
              final serviceLabel =
                  services.isNotEmpty
                      ? services.map((service) => service.name).join(' + ')
                      : 'Servizio';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      client?.firstName.characters.firstOrNull?.toUpperCase() ??
                          '?',
                    ),
                  ),
                  title: Text(client?.fullName ?? 'Cliente'),
                  subtitle: Text(
                    '$serviceLabel · ${DateFormat('HH:mm').format(appointment.start)}',
                  ),
                  trailing: const Icon(Icons.navigate_next_rounded),
                  onTap: () => _showAppointmentDetails(context, appointment),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showAppointmentDetails(
    BuildContext context,
    Appointment appointment,
  ) {
    return showAppModalSheet<void>(
      context: context,
      builder: (ctx) => _AppointmentDetailSheet(appointment: appointment),
    );
  }
}

class _AgendaView extends ConsumerStatefulWidget {
  const _AgendaView({
    required this.staff,
    required this.appointments,
    required this.absences,
    required this.shifts,
  });

  final StaffMember? staff;
  final List<Appointment> appointments;
  final List<StaffAbsence> absences;
  final List<Shift> shifts;

  @override
  ConsumerState<_AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends ConsumerState<_AgendaView> {
  static const String _agendaScopePreferenceKey = 'staff_agenda_scope';
  static const String _agendaShowEquipmentPreferenceKey =
      'staff_agenda_show_equipment';
  static final DateFormat _dayLabelFormat = DateFormat(
    'EEEE dd MMMM yyyy',
    'it_IT',
  );
  late DateTime _anchorDate;
  AppointmentCalendarScope _scope = AppointmentCalendarScope.day;
  bool _showEquipmentOperators = true;
  DateTime? _scrollToDate;
  int _scrollToDateRequestId = 0;

  @override
  void initState() {
    super.initState();
    _anchorDate = DateUtils.dateOnly(DateTime.now());
    unawaited(_restoreAgendaScope());
    unawaited(_restoreEquipmentPreference());
  }

  Future<void> _restoreAgendaScope() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_agendaScopePreferenceKey);
    final restored = AppointmentCalendarScope.values.firstWhereOrNull(
      (scope) => scope.name == stored,
    );
    if (!mounted) {
      return;
    }
    if (restored != null) {
      setState(() {
        _scope = restored;
      });
    }
  }

  Future<void> _restoreEquipmentPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_agendaShowEquipmentPreferenceKey);
    if (!mounted) {
      return;
    }
    if (stored != null) {
      setState(() {
        _showEquipmentOperators = stored;
      });
    }
  }

  Future<void> _persistAgendaScope() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_agendaScopePreferenceKey, _scope.name);
  }

  Future<void> _persistEquipmentPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _agendaShowEquipmentPreferenceKey,
      _showEquipmentOperators,
    );
  }

  void _updateScope(AppointmentCalendarScope scope) {
    if (scope == _scope) {
      return;
    }
    setState(() {
      _scope = scope;
    });
    unawaited(_persistAgendaScope());
  }

  void _toggleEquipmentOperators([bool? value]) {
    setState(() {
      _showEquipmentOperators = value ?? !_showEquipmentOperators;
    });
    unawaited(_persistEquipmentPreference());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('it', 'IT'),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (_scope == AppointmentCalendarScope.week) {
        _anchorDate = _startOfWeek(picked);
      } else {
        _anchorDate = DateUtils.dateOnly(picked);
      }
    });
  }

  void _shiftRange(int delta) {
    final stepDays = _scope == AppointmentCalendarScope.day ? 1 : 7;
    setState(() {
      _anchorDate = DateUtils.dateOnly(
        _anchorDate.add(Duration(days: stepDays * delta)),
      );
    });
  }

  void _goToToday() {
    final now = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _anchorDate = now;
      if (_scope == AppointmentCalendarScope.week) {
        _scrollToDate = now;
        _scrollToDateRequestId += 1;
      } else {
        _scrollToDate = null;
      }
    });
  }

  Future<void> _showAppointmentDetails(
    BuildContext context,
    Appointment appointment,
  ) {
    return showAppModalSheet<void>(
      context: context,
      builder: (ctx) => _AppointmentDetailSheet(appointment: appointment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    if (staff == null) {
      return const Center(child: Text('Seleziona un membro dello staff'));
    }
    final data = ref.watch(appDataProvider);
    final isDayScope = _scope == AppointmentCalendarScope.day;
    final rangeStart = isDayScope ? _anchorDate : _startOfWeek(_anchorDate);
    final rangeEnd = rangeStart.add(Duration(days: isDayScope ? 1 : 7));
    final rangeLabel =
        isDayScope
            ? _dayLabelFormat.format(rangeStart)
            : _formatWeekRange(rangeStart);
    const fabIcon = Icons.tune_rounded;
    const fabTooltip = 'Opzioni agenda';

    final equipmentOperators =
        data.staff
            .where(
              (member) =>
                  member.isEquipment &&
                  (staff.salonId == null || member.salonId == staff.salonId),
            )
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final visibleStaff = <StaffMember>[
      staff,
      if (_showEquipmentOperators)
        ...equipmentOperators.where((member) => member.id != staff.id),
    ];
    final visibleStaffIds = visibleStaff.map((member) => member.id).toSet();
    final allVisibleAppointments =
        widget.appointments
            .where(
              (appointment) => visibleStaffIds.contains(appointment.staffId),
            )
            .toList();

    final visibleAppointments =
        allVisibleAppointments
            .where(
              (appointment) => _dateRangesOverlap(
                appointment.start,
                appointment.end,
                rangeStart,
                rangeEnd,
              ),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final visibleShifts =
        widget.shifts
            .where(
              (shift) =>
                  visibleStaffIds.contains(shift.staffId) &&
                  _dateRangesOverlap(
                    shift.start,
                    shift.end,
                    rangeStart,
                    rangeEnd,
                  ),
            )
            .toList();
    final visibleAbsences =
        widget.absences
            .where(
              (absence) =>
                  visibleStaffIds.contains(absence.staffId) &&
                  _dateRangesOverlap(
                    absence.start,
                    absence.end,
                    rangeStart,
                    rangeEnd,
                  ),
            )
            .toList();

    final salonsById = {for (final salon in data.salons) salon.id: salon};
    final roomsById = <String, String>{};
    for (final salon in data.salons) {
      for (final room in salon.rooms) {
        roomsById[room.id] = room.name;
      }
    }
    final selectedSalon =
        staff.salonId == null
            ? null
            : data.salons.firstWhereOrNull(
              (salon) => salon.id == staff.salonId,
            );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _StaffAgendaToolbar(
            label: rangeLabel,
            onPrevious: () => _shiftRange(-1),
            onNext: () => _shiftRange(1),
            onToday: _goToToday,
            onPickDate: _pickDate,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            children: [
              AppointmentCalendarView(
                anchorDate: rangeStart,
                scope: _scope,
                weekLayout: AppointmentWeekLayoutMode.detailed,
                appointments: visibleAppointments,
                allAppointments: allVisibleAppointments,
                lastMinutePlaceholders: const [],
                lastMinuteSlots: const [],
                staff: visibleStaff,
                clients: data.clients,
                clientsWithOutstandingPayments: const <String>{},
                services: data.services,
                serviceCategories: data.serviceCategories,
                shifts: visibleShifts,
                absences: visibleAbsences,
                roles: data.staffRoles,
                schedule: selectedSalon?.schedule,
                roomsById: roomsById,
                salonsById: salonsById,
                selectedSalonId: staff.salonId,
                visibleWeekdays: const {
                  DateTime.monday,
                  DateTime.tuesday,
                  DateTime.wednesday,
                  DateTime.thursday,
                  DateTime.friday,
                  DateTime.saturday,
                  DateTime.sunday,
                },
                lockedAppointmentReasons: const <String, String>{},
                anomalies: const <String, Set<AppointmentAnomalyType>>{},
                statusColor:
                    (status) => _appointmentStatusColor(context, status),
                dayChecklists: const <DateTime, AppointmentDayChecklist>{},
                onReschedule: (_) async {},
                onEdit:
                    (appointment) =>
                        _showAppointmentDetails(context, appointment),
                onCreate: (_) {},
                readOnly: true,
                showStaffHeader: visibleStaff.length > 1,
                slotMinutes: 15,
                interactionSlotMinutes: 15,
                scrollToDate: _scrollToDate,
                scrollToDateRequestId: _scrollToDateRequestId,
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: SafeArea(
                  minimum: const EdgeInsets.only(bottom: 8),
                  child: MenuAnchor(
                    alignmentOffset: const Offset(0, -8),
                    builder: (context, controller, child) {
                      return FloatingActionButton(
                        tooltip: fabTooltip,
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        child: Icon(fabIcon),
                      );
                    },
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(
                          Icons.calendar_view_day_rounded,
                        ),
                        trailingIcon:
                            _scope == AppointmentCalendarScope.day
                                ? const Icon(Icons.check_rounded)
                                : null,
                        onPressed:
                            () => _updateScope(AppointmentCalendarScope.day),
                        child: const Text('Visione giorno'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.view_week_rounded),
                        trailingIcon:
                            _scope == AppointmentCalendarScope.week
                                ? const Icon(Icons.check_rounded)
                                : null,
                        onPressed:
                            () => _updateScope(AppointmentCalendarScope.week),
                        child: const Text('Visione settimana'),
                      ),
                      const Divider(height: 1),
                      MenuItemButton(
                        leadingIcon: const Icon(
                          Icons.precision_manufacturing_rounded,
                        ),
                        trailingIcon:
                            _showEquipmentOperators
                                ? const Icon(Icons.check_rounded)
                                : null,
                        onPressed:
                            equipmentOperators.isEmpty
                                ? null
                                : () => _toggleEquipmentOperators(),
                        child: const Text('Mostra macchinari'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffAgendaToolbar extends StatelessWidget {
  const _StaffAgendaToolbar({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onPickDate,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const dense = VisualDensity(horizontal: -2, vertical: -2);

    return Row(
      children: [
        IconButton(
          tooltip: 'Periodo precedente',
          onPressed: onPrevious,
          visualDensity: dense,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: dense,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: onToday,
                    child: const Text('Oggi'),
                  ),
                  IconButton(
                    tooltip: 'Vai a data',
                    onPressed: onPickDate,
                    visualDensity: dense,
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.event_available_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Periodo successivo',
          onPressed: onNext,
          visualDensity: dense,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _AbsenceView extends ConsumerWidget {
  const _AbsenceView({
    required this.staff,
    required this.absences,
    required this.requests,
    required this.shifts,
  });

  final StaffMember? staff;
  final List<StaffAbsence> absences;
  final List<StaffAbsenceRequest> requests;
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (staff == null) {
      return const Center(child: Text('Seleziona un membro dello staff'));
    }

    final theme = Theme.of(context);
    final pendingRequests =
        requests.where((request) => request.status.isPending).toList();
    final historyRequests =
        requests.where((request) => !request.status.isPending).toList();
    const historyPreviewLimit = 3;
    final historyPreview = historyRequests.take(historyPreviewLimit).toList();
    final showHistoryButton = historyRequests.isNotEmpty;
    final shiftsByDay = _groupShiftsByDay(shifts);
    final holidaysCache = <int, Set<DateTime>>{};
    Set<DateTime> holidaysForYear(int year) {
      return holidaysCache.putIfAbsent(
        year,
        () => _nationalHolidaysForYear(year),
      );
    }

    final summary = _calculateAbsenceSummary(
      staff: staff!,
      absences: absences,
      shiftsByDay: shiftsByDay,
      holidaysForYear: holidaysForYear,
      referenceYear: DateTime.now().year,
    );

    final vacationAndPermissions =
        absences
            .where(
              (absence) =>
                  absence.type == StaffAbsenceType.vacation ||
                  absence.type == StaffAbsenceType.permission,
            )
            .toList();
    final sickLeaves =
        absences
            .where((absence) => absence.type == StaffAbsenceType.sickLeave)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Richieste ferie & permessi', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openAbsenceRequestForm(context, staff: staff!),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuova richiesta'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AbsenceSummaryCard(
                  icon: Icons.beach_access_rounded,
                  title: 'Ferie',
                  value: _formatDays(summary.vacationRemaining),
                  subtitle:
                      'Usate ${_formatDays(summary.vacationUsed)} su ${staff!.vacationAllowance} giorni',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AbsenceSummaryCard(
                  icon: Icons.event_busy_rounded,
                  title: 'Permessi',
                  value: _formatDays(summary.permissionRemaining),
                  subtitle:
                      'Usati ${_formatDays(summary.permissionUsed)} su ${staff!.permissionAllowance} giorni',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (pendingRequests.isEmpty && historyPreview.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.event_available_outlined),
                title: Text('Nessuna richiesta inviata'),
              ),
            )
          else ...[
            if (pendingRequests.isNotEmpty) ...[
              Text(
                'In attesa (${pendingRequests.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...pendingRequests.map(
                (request) => _AbsenceRequestCard(
                  request: request,
                  onCancel: () => _confirmCancelRequest(context, ref, request),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (historyPreview.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Storico recente', style: theme.textTheme.titleMedium),
                  if (showHistoryButton)
                    TextButton(
                      onPressed:
                          () =>
                              _openAbsenceHistory(context, requests: requests),
                      child: const Text('Vedi storico'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...historyPreview.map(
                (request) => _AbsenceRequestCard(
                  request: request,
                  onCancel:
                      request.status.isPending
                          ? () => _confirmCancelRequest(context, ref, request)
                          : null,
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          _AbsenceSection(
            title: 'Ferie & Permessi',
            absences: vacationAndPermissions,
            emptyLabel: 'Nessuna assenza registrata',
            emptyIcon: Icons.event_available_outlined,
            shiftsByDay: shiftsByDay,
            holidaysForYear: holidaysForYear,
          ),
          _AbsenceSection(
            title: 'Malattie',
            absences: sickLeaves,
            emptyLabel: 'Nessuna malattia registrata',
            emptyIcon: Icons.healing_outlined,
            shiftsByDay: shiftsByDay,
            holidaysForYear: holidaysForYear,
          ),
        ],
      ),
    );
  }
}

class _AbsenceRequestCard extends StatelessWidget {
  const _AbsenceRequestCard({required this.request, this.onCancel});

  final StaffAbsenceRequest request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = request.notes?.trim();
    final adminNote = request.adminNote?.trim();
    final showNotes = notes != null && notes.isNotEmpty;
    final showAdminNote =
        adminNote != null && adminNote.isNotEmpty && !request.status.isPending;
    final rangeLabel = _formatRequestRange(request.start, request.end);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_absenceIcon(request.type)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.type.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(rangeLabel, style: theme.textTheme.bodySmall),
                  if (showNotes) ...[
                    const SizedBox(height: 4),
                    Text(notes, style: theme.textTheme.bodySmall),
                  ],
                  if (showAdminNote) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Risposta admin: $adminNote',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _requestStatusChip(request.status, context),
                if (onCancel != null)
                  TextButton(onPressed: onCancel, child: const Text('Annulla')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openAbsenceRequestForm(
  BuildContext context, {
  required StaffMember staff,
}) {
  return showAppModalSheet<void>(
    context: context,
    builder:
        (_) =>
            StaffAbsenceRequestFormSheet(staff: staff, salonId: staff.salonId),
  );
}

Future<void> _openAbsenceHistory(
  BuildContext context, {
  required List<StaffAbsenceRequest> requests,
}) {
  return showAppModalSheet<void>(
    context: context,
    includeCloseButton: false,
    builder: (_) => _AbsenceHistorySheet(requests: requests),
  );
}

Future<void> _confirmCancelRequest(
  BuildContext context,
  WidgetRef ref,
  StaffAbsenceRequest request,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Annulla richiesta'),
          content: const Text(
            'Vuoi annullare questa richiesta di ferie/permesso?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Si, annulla'),
            ),
          ],
        ),
  );
  if (confirmed != true) {
    return;
  }

  await ref
      .read(appDataProvider.notifier)
      .cancelStaffAbsenceRequest(request: request);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(const SnackBar(content: Text('Richiesta annullata.')));
  }
}

class _AbsenceSection extends StatelessWidget {
  const _AbsenceSection({
    required this.title,
    required this.absences,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.shiftsByDay,
    required this.holidaysForYear,
  });

  final String title;
  final List<StaffAbsence> absences;
  final String emptyLabel;
  final IconData emptyIcon;
  final Map<DateTime, List<Shift>> shiftsByDay;
  final Set<DateTime> Function(int year) holidaysForYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (absences.isEmpty)
          Card(
            child: ListTile(leading: Icon(emptyIcon), title: Text(emptyLabel)),
          )
        else
          ...absences.map((absence) {
            final daysLabel = _formatDays(
              _absenceWorkingDays(absence, shiftsByDay, holidaysForYear),
            );
            final rangeLabel = _formatAbsenceRange(absence);
            final notes = absence.notes?.trim();
            final hasValidNotes = notes != null && notes.isNotEmpty;
            return Card(
              child: ListTile(
                leading: Icon(_absenceIcon(absence.type)),
                title: Text(
                  '${absence.type.label} · $daysLabel',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rangeLabel),
                    if (hasValidNotes)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(notes, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
                isThreeLine: hasValidNotes,
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AbsenceHistorySheet extends ConsumerWidget {
  const _AbsenceHistorySheet({required this.requests});

  final List<StaffAbsenceRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body =
        requests.isEmpty
            ? const Card(
              child: ListTile(
                leading: Icon(Icons.event_available_outlined),
                title: Text('Nessuna richiesta disponibile'),
              ),
            )
            : Column(
              children:
                  requests
                      .map(
                        (request) => _AbsenceRequestCard(
                          request: request,
                          onCancel:
                              request.status.isPending
                                  ? () => _confirmCancelRequest(
                                    context,
                                    ref,
                                    request,
                                  )
                                  : null,
                        ),
                      )
                      .toList(),
            );

    return DialogActionLayout(
      title: 'Storico richieste',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [body],
      ),
      actions: const [],
    );
  }
}

class _AbsenceSummaryCard extends StatelessWidget {
  const _AbsenceSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

_AbsenceSummary _calculateAbsenceSummary({
  required StaffMember staff,
  required Iterable<StaffAbsence> absences,
  required Map<DateTime, List<Shift>> shiftsByDay,
  required Set<DateTime> Function(int year) holidaysForYear,
  required int referenceYear,
}) {
  double vacation = 0;
  double permissions = 0;
  final rangeStart = DateTime(referenceYear, 1, 1);
  final rangeEnd = DateTime(referenceYear + 1, 1, 1);

  for (final absence in absences) {
    final days = _absenceWorkingDays(
      absence,
      shiftsByDay,
      holidaysForYear,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    if (days <= 0) {
      continue;
    }
    switch (absence.type) {
      case StaffAbsenceType.vacation:
        vacation += days;
        break;
      case StaffAbsenceType.permission:
        permissions += days;
        break;
      case StaffAbsenceType.sickLeave:
        break;
    }
  }

  final vacationRemaining =
      (staff.vacationAllowance.toDouble() - vacation)
          .clamp(0, double.infinity)
          .toDouble();
  final permissionRemaining =
      (staff.permissionAllowance.toDouble() - permissions)
          .clamp(0, double.infinity)
          .toDouble();

  return _AbsenceSummary(
    vacationUsed: vacation,
    permissionUsed: permissions,
    vacationRemaining: vacationRemaining,
    permissionRemaining: permissionRemaining,
  );
}

String _formatDays(double value) {
  final isInteger = value == value.roundToDouble();
  if (isInteger) {
    final count = value.round();
    final suffix = count == 1 ? 'giorno' : 'giorni';
    return '$count $suffix';
  }
  return '${value.toStringAsFixed(1)} giorni';
}

IconData _absenceIcon(StaffAbsenceType type) {
  switch (type) {
    case StaffAbsenceType.vacation:
      return Icons.beach_access_outlined;
    case StaffAbsenceType.permission:
      return Icons.schedule_outlined;
    case StaffAbsenceType.sickLeave:
      return Icons.healing_outlined;
  }
}

String _formatAbsenceRange(StaffAbsence absence) {
  final dayFormatter = DateFormat('dd/MM/yyyy');
  final timeFormatter = DateFormat('HH:mm');

  final startDay = dayFormatter.format(absence.start);
  final endDay = dayFormatter.format(absence.end);

  if (absence.isSingleDay) {
    if (absence.isAllDay) {
      return startDay;
    }
    final startTime = timeFormatter.format(absence.start);
    final endTime = timeFormatter.format(absence.end);
    return '$startDay • $startTime-$endTime';
  }

  if (absence.isAllDay) {
    return '$startDay → $endDay';
  }

  final startTime = timeFormatter.format(absence.start);
  final endTime = timeFormatter.format(absence.end);
  return '$startDay → $endDay • $startTime-$endTime';
}

String _formatRequestRange(DateTime start, DateTime end) {
  final dayFormatter = DateFormat('dd/MM/yyyy');
  final timeFormatter = DateFormat('HH:mm');
  final startDay = dayFormatter.format(start);
  final endDay = dayFormatter.format(end);
  final isSingleDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  final isAllDay =
      start.hour == 0 &&
      start.minute == 0 &&
      end.hour == 23 &&
      end.minute == 59;

  if (isSingleDay) {
    if (isAllDay) {
      return startDay;
    }
    return '$startDay • ${timeFormatter.format(start)}-${timeFormatter.format(end)}';
  }

  if (isAllDay) {
    return '$startDay → $endDay';
  }

  return '$startDay → $endDay • ${timeFormatter.format(start)}-${timeFormatter.format(end)}';
}

double _absenceWorkingDays(
  StaffAbsence absence,
  Map<DateTime, List<Shift>> shiftsByDay,
  Set<DateTime> Function(int year) holidaysForYear, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  var start = absence.start;
  var end = absence.end;

  if (rangeStart != null && end.isBefore(rangeStart)) {
    return 0;
  }
  if (rangeEnd != null && !start.isBefore(rangeEnd)) {
    return 0;
  }
  if (rangeStart != null && start.isBefore(rangeStart)) {
    start = rangeStart;
  }
  if (rangeEnd != null && !end.isBefore(rangeEnd)) {
    end = rangeEnd.subtract(const Duration(microseconds: 1));
  }
  if (!end.isAfter(start)) {
    return 0;
  }

  final startDay = _dateOnly(start);
  final endDay = _dateOnly(end);
  var currentDay = startDay;
  double total = 0;

  while (!currentDay.isAfter(endDay)) {
    final shifts = shiftsByDay[currentDay];
    if (shifts == null || shifts.isEmpty) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }
    if (holidaysForYear(currentDay.year).contains(currentDay)) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    final dayStart = currentDay;
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayAbsenceStart = start.isAfter(dayStart) ? start : dayStart;
    final dayAbsenceEnd = end.isBefore(dayEnd) ? end : dayEnd;

    if (!dayAbsenceEnd.isAfter(dayAbsenceStart)) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    if (absence.isAllDay) {
      total += 1;
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    var totalShiftMinutes = 0;
    var overlapMinutes = 0;
    for (final shift in shifts) {
      final shiftStart =
          shift.start.isBefore(dayStart) ? dayStart : shift.start;
      final shiftEnd = shift.end.isAfter(dayEnd) ? dayEnd : shift.end;
      if (!shiftEnd.isAfter(shiftStart)) {
        continue;
      }

      totalShiftMinutes += shiftEnd.difference(shiftStart).inMinutes;
      overlapMinutes += _overlapMinutes(
        dayAbsenceStart,
        dayAbsenceEnd,
        shiftStart,
        shiftEnd,
      );
    }

    if (totalShiftMinutes <= 0) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    final fraction = overlapMinutes / totalShiftMinutes;
    if (fraction > 0) {
      total += fraction.clamp(0, 1);
    }

    currentDay = currentDay.add(const Duration(days: 1));
  }

  return total;
}

Map<DateTime, List<Shift>> _groupShiftsByDay(Iterable<Shift> shifts) {
  final map = <DateTime, List<Shift>>{};
  for (final shift in shifts) {
    final day = _dateOnly(shift.start);
    map.putIfAbsent(day, () => <Shift>[]).add(shift);
  }
  return map;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _overlapMinutes(
  DateTime startA,
  DateTime endA,
  DateTime startB,
  DateTime endB,
) {
  final start = startA.isAfter(startB) ? startA : startB;
  final end = endA.isBefore(endB) ? endA : endB;
  if (!end.isAfter(start)) {
    return 0;
  }
  return end.difference(start).inMinutes;
}

Set<DateTime> _nationalHolidaysForYear(int year) {
  final dates = <DateTime>{
    DateTime(year, 1, 1), // Capodanno
    DateTime(year, 1, 6), // Epifania
    DateTime(year, 4, 25), // Liberazione
    DateTime(year, 5, 1), // Festa del lavoro
    DateTime(year, 6, 2), // Festa della Repubblica
    DateTime(year, 8, 15), // Ferragosto
    DateTime(year, 11, 1), // Ognissanti
    DateTime(year, 12, 8), // Immacolata
    DateTime(year, 12, 25), // Natale
    DateTime(year, 12, 26), // Santo Stefano
  };

  final easterMonday = _calculateEasterSunday(
    year,
  ).add(const Duration(days: 1));
  dates.add(_dateOnly(easterMonday));

  return dates.map(_dateOnly).toSet();
}

DateTime _calculateEasterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

class _AbsenceSummary {
  const _AbsenceSummary({
    required this.vacationUsed,
    required this.permissionUsed,
    required this.vacationRemaining,
    required this.permissionRemaining,
  });

  final double vacationUsed;
  final double permissionUsed;
  final double vacationRemaining;
  final double permissionRemaining;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentSummaryCard extends StatelessWidget {
  const _AppointmentSummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.margin,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppointmentStatus status;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
    final statusChip = _appointmentStatusChip(status, context);

    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 8),
                  statusChip,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 12),
                statusChip,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.clientName,
    required this.clientInitial,
    required this.serviceLabel,
    required this.durationLabel,
    required this.timeLabel,
    this.onTap,
  });

  final String clientName;
  final String clientInitial;
  final String serviceLabel;
  final String durationLabel;
  final String timeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onPrimaryContainer,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onPrimaryContainer,
    );
    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onPrimaryContainer.withOpacity(0.8),
    );

    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.onPrimaryContainer.withOpacity(0.12),
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(clientInitial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName, style: titleStyle),
                    const SizedBox(height: 4),
                    Text('$serviceLabel · $durationLabel', style: bodyStyle),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: scheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(timeLabel, style: secondaryStyle),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.navigate_next_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _appointmentStatusChip(AppointmentStatus status, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case AppointmentStatus.scheduled:
      return Chip(
        label: const Text('Programmato'),
        backgroundColor: scheme.primaryContainer,
      );
    case AppointmentStatus.completed:
      return Chip(
        label: const Text('Completato'),
        backgroundColor: scheme.tertiaryContainer,
      );
    case AppointmentStatus.cancelled:
      return Chip(
        label: const Text('Annullato'),
        backgroundColor: scheme.errorContainer,
      );
    case AppointmentStatus.noShow:
      return Chip(
        label: const Text('No show'),
        backgroundColor: scheme.error.withOpacity(0.1),
      );
  }
}

Color _appointmentStatusColor(BuildContext context, AppointmentStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case AppointmentStatus.scheduled:
      return scheme.primary;
    case AppointmentStatus.completed:
      return scheme.tertiary;
    case AppointmentStatus.cancelled:
      return scheme.onSurfaceVariant;
    case AppointmentStatus.noShow:
      return scheme.error.withAlpha(180);
  }
}

Widget _requestStatusChip(
  StaffAbsenceRequestStatus status,
  BuildContext context,
) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case StaffAbsenceRequestStatus.pending:
      return Chip(
        label: const Text('In attesa'),
        backgroundColor: scheme.secondaryContainer,
      );
    case StaffAbsenceRequestStatus.approved:
      return Chip(
        label: const Text('Approvata'),
        backgroundColor: scheme.tertiaryContainer,
      );
    case StaffAbsenceRequestStatus.rejected:
      return Chip(
        label: const Text('Rifiutata'),
        backgroundColor: scheme.errorContainer,
      );
    case StaffAbsenceRequestStatus.cancelled:
      return Chip(
        label: const Text('Annullata'),
        backgroundColor: scheme.surfaceVariant,
      );
  }
}

DateTime _startOfWeek(DateTime date) {
  final normalized = DateUtils.dateOnly(date);
  final delta = normalized.weekday - DateTime.monday;
  return normalized.subtract(Duration(days: delta));
}

String _formatWeekRange(DateTime weekStart) {
  final startLabel = DateFormat('dd MMM', 'it_IT').format(weekStart);
  final endLabel = DateFormat(
    'dd MMM yyyy',
    'it_IT',
  ).format(weekStart.add(const Duration(days: 6)));
  return '$startLabel - $endLabel';
}

bool _dateRangesOverlap(
  DateTime start,
  DateTime end,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
}

String _formatDuration(Duration duration) {
  final hours = duration.inMinutes / 60;
  return '${hours.toStringAsFixed(1)} h';
}
