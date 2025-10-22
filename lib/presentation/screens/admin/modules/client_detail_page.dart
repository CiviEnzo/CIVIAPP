import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/availability/equipment_availability.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/appointment_clipboard.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/client_questionnaire.dart';
import 'package:civiapp/domain/entities/client_photo.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/quote.dart';
import 'package:civiapp/domain/entities/payment_ticket.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/appointment_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/outstanding_payment_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_deposit_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_purchase_edit_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_sale_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/quote_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

const Set<String> _anamnesisRequiredGroupIds = {
  'grp-cardiovascular',
  'grp-pregnancy',
  'grp-general-pathologies',
  'grp-hormonal',
  'grp-allergies',
  'grp-skin',
  'grp-surgery',
  'grp-activity',
  'grp-nutrition',
  'grp-hydration',
  'grp-sleep-stress',
  'grp-skin-care',
  'grp-hair-removal',
  'grp-previous-treatments',
  'grp-goals',
  'grp-consent',
};

const Set<String> _generalHealthQuestionIds = {
  'q-cardiac-disease',
  'q-blood-pressure',
  'q-pacemaker',
  'q-heart-meds',
  'q-diabetes',
  'q-diabetes-meds',
  'q-insulin-resistance',
  'q-kidney-liver',
  'q-autoimmune',
  'q-allergies',
  'q-adverse-reactions',
  'q-pregnant',
  'q-breastfeeding',
  'q-menstrual-irregularities',
  'q-menopause',
  'q-pcos',
  'q-thyroid',
  'q-weight-history',
  'q-surgery-last12',
  'q-recent-aesthetic',
};

const Set<String> _lifestyleBooleanQuestionIds = {
  'q-activity-regular',
  'q-sedentary',
  'q-special-diet',
  'q-dietary-restrictions',
  'q-sugar-fat',
  'q-sugary-drinks',
};

const Set<String> _lifestyleTextQuestionIds = {
  'q-activity-type',
  'q-activity-frequency',
};

const Set<String> _aestheticBooleanQuestionIds = {
  'q-skin-disorders',
  'q-topical-therapies',
  'q-uses-cosmetics',
  'q-previous-treatments',
};

const Set<String> _aestheticSingleChoiceQuestionIds = {
  'q-cosmetic-source',
  'q-hair-removal-method',
};

const Set<String> _aestheticTextQuestionIds = {
  'q-products-used',
  'q-previous-treatments-notes',
};

const Set<String> _measurementNumberQuestionIds = {
  'q-fruit-veg-portions',
  'q-sleep-hours',
};

const Set<String> _measurementSingleChoiceQuestionIds = {
  'q-water-intake',
  'q-stress-level',
};

const Set<String> _noteTextQuestionIds = {
  'q-general-notes',
  'q-treatment-goals',
};

bool _canUseAnamnesisLayout(ClientQuestionnaireTemplate template) {
  final groupIds = template.groups.map((group) => group.id).toSet();
  return _anamnesisRequiredGroupIds.every(groupIds.contains);
}

class ClientDetailPage extends ConsumerStatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailPage> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == widget.clientId,
    );

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dettaglio cliente')),
        body: const Center(
          child: Text('Cliente non trovato. Aggiorna l\'elenco e riprova.'),
        ),
      );
    }

    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == client.salonId,
    );

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(client.fullName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Scheda'),
              Tab(text: 'Appuntamenti'),
              Tab(text: 'Pacchetti'),
              Tab(text: 'Preventivi'),
              Tab(text: 'Fatturazione'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Modifica scheda',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _editClient(context, client),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ProfileTab(client: client, salon: salon),
            _AppointmentsTab(clientId: client.id),
            _PackagesTab(clientId: client.id),
            _QuotesTab(clientId: client.id),
            _BillingTab(clientId: client.id),
          ],
        ),
      ),
    );
  }

  Future<void> _editClient(BuildContext context, Client client) async {
    final data = ref.read(appDataProvider);
    final salons = data.salons;
    final clients = data.clients;
    final updated = await showAppModalSheet<Client>(
      context: context,
      builder:
          (ctx) => ClientFormSheet(
            salons: salons,
            clients: clients,
            initial: client,
            defaultSalonId: client.salonId,
          ),
    );
    if (updated != null) {
      await ref.read(appDataProvider.notifier).upsertClient(updated);
    }
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.client, required this.salon});

  final Client client;
  final Salon? salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    final data = ref.watch(appDataProvider);
    final templatesForSalon = data.clientQuestionnaireTemplates
        .where((template) => template.salonId == client.salonId)
        .toList(growable: false);
    final usesAnamnesisLayout = templatesForSalon.any(_canUseAnamnesisLayout);

    final children = <Widget>[];

    final extraInfoCard = _ClientExtraDetailsCard(
      client: client,
      dateFormat: dateFormat,
      dateTimeFormat: dateTimeFormat,
    );

    if (usesAnamnesisLayout) {
      children.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final content = <Widget>[
              Expanded(
                flex: 3,
                child: _AnamnesisInfoCard(client: client, salon: salon),
              ),
              SizedBox(width: isWide ? 16 : 0),
              Expanded(flex: 2, child: const _BodyMapCard()),
            ];
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content[0], const SizedBox(height: 16), content[2]],
            );
          },
        ),
      );
      children.add(const SizedBox(height: 16));
      children.add(extraInfoCard);
      children.add(const SizedBox(height: 16));
      children.add(_ClientQuestionnaireCard(client: client));
    } else {
      children.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dati anagrafici', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Numero cliente',
                  value: client.clientNumber ?? 'Non assegnato',
                ),
                _InfoTile(
                  icon: Icons.cake_outlined,
                  label: 'Data di nascita',
                  value:
                      client.dateOfBirth == null
                          ? '—'
                          : dateFormat.format(client.dateOfBirth!),
                ),
                _InfoTile(
                  icon: Icons.phone,
                  label: 'Telefono',
                  value: client.phone,
                ),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: client.email ?? '—',
                ),
                _InfoTile(
                  icon: Icons.home_outlined,
                  label: 'Indirizzo',
                  value: client.address ?? '—',
                ),
                _InfoTile(
                  icon: Icons.work_outline,
                  label: 'Professione',
                  value: client.profession ?? '—',
                ),
                _InfoTile(
                  icon: Icons.campaign_outlined,
                  label: 'Come ci ha conosciuto',
                  value: client.referralSource ?? '—',
                ),
                _InfoTile(
                  icon: Icons.loyalty_rounded,
                  label: 'Punti fedeltà',
                  value: client.loyaltyPoints.toString(),
                ),
                if (salon != null)
                  _InfoTile(
                    icon: Icons.apartment_rounded,
                    label: 'Salone associato',
                    value: salon!.name,
                  ),
              ],
            ),
          ),
        ),
      );
      children.add(const SizedBox(height: 16));
      children.add(extraInfoCard);
      children.add(const SizedBox(height: 16));
      children.add(_ClientQuestionnaireCard(client: client));
    }

    children.add(const SizedBox(height: 16));
    children.add(_ClientPhotosCard(client: client));

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  static String _consentLabel(ConsentType type) {
    switch (type) {
      case ConsentType.marketing:
        return 'Marketing';
      case ConsentType.privacy:
        return 'Privacy';
      case ConsentType.profilazione:
        return 'Profilazione';
    }
  }
}

class _AnamnesisInfoCard extends StatelessWidget {
  const _AnamnesisInfoCard({required this.client, required this.salon});

  final Client client;
  final Salon? salon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final birthDate = client.dateOfBirth;
    final formattedBirthDate =
        birthDate == null ? '—' : dateFormat.format(birthDate);
    final age = _formatClientAge(birthDate);

    final fields = <_InfoFieldData>[
      _InfoFieldData(label: 'Nome e cognome', value: client.fullName),
      _InfoFieldData(label: 'Data di nascita', value: formattedBirthDate),
      _InfoFieldData(label: 'Età', value: age),
      _InfoFieldData(
        label: 'Numero cliente',
        value: client.clientNumber ?? '—',
      ),
      _InfoFieldData(label: 'Contatto', value: client.phone),
      _InfoFieldData(label: 'Email', value: client.email ?? '—'),
      _InfoFieldData(label: 'Indirizzo', value: client.address ?? '—'),
      _InfoFieldData(label: 'Professione', value: client.profession ?? '—'),
      _InfoFieldData(
        label: 'Come ci ha conosciuto',
        value: client.referralSource ?? '—',
      ),
      if (salon != null)
        _InfoFieldData(label: 'Salone associato', value: salon!.name),
    ];

    final notes = client.notes?.trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dati anagrafici',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 520;
                final fieldWidth =
                    isWide
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: fields
                      .map(
                        (field) => SizedBox(
                          width: fieldWidth,
                          child: _ReadonlyField(
                            label: field.label,
                            value: field.value,
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 16),
            _ReadonlyField(
              label: 'Note cliente',
              value: notes.isEmpty ? '—' : notes,
              minLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  String _formatClientAge(DateTime? birthDate) {
    if (birthDate == null) {
      return '—';
    }
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasHadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthday) {
      age -= 1;
    }
    return age.toString();
  }
}

class _BodyMapCard extends StatelessWidget {
  const _BodyMapCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mappa corporea',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Icon(Icons.accessibility_new, size: 96),
                      Transform.scale(
                        scaleX: -1,
                        child: const Icon(Icons.accessibility_new, size: 96),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Annota visivamente le aree di interesse o allega foto dedicate dal diario cliente.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientExtraDetailsCard extends StatelessWidget {
  const _ClientExtraDetailsCard({
    required this.client,
    required this.dateFormat,
    required this.dateTimeFormat,
  });

  final Client client;
  final DateFormat dateFormat;
  final DateFormat dateTimeFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channelPrefs = client.channelPreferences;
    final chips = _buildPreferenceChips(context, channelPrefs);
    final notes = client.notes?.trim() ?? '';
    final hasNotes = notes.isNotEmpty;
    final hasConsents = client.marketedConsents.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferenze contatto',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (chips.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: chips)
            else
              Text(
                'Nessuna preferenza registrata.',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Text(
              channelPrefs.updatedAt != null
                  ? 'Ultimo aggiornamento: ${dateTimeFormat.format(channelPrefs.updatedAt!)}'
                  : 'Preferenze non ancora registrate.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Note cliente',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasNotes ? notes : 'Nessuna nota presente per questo cliente.',
              style: theme.textTheme.bodyMedium,
            ),
            if (hasConsents) ...[
              const SizedBox(height: 16),
              Text(
                'Consensi marketing',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    client.marketedConsents
                        .map(
                          (consent) => Chip(
                            avatar: const Icon(Icons.check_rounded, size: 16),
                            label: Text(
                              '${_ProfileTab._consentLabel(consent.type)} · ${dateFormat.format(consent.acceptedAt)}',
                            ),
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

  List<Widget> _buildPreferenceChips(
    BuildContext context,
    ChannelPreferences preferences,
  ) {
    Widget buildChip(bool enabled, String label, IconData icon) {
      final theme = Theme.of(context);
      final selectedBackground = theme.colorScheme.secondaryContainer;
      final selectedForeground = theme.colorScheme.onSecondaryContainer;
      final disabledBackground = theme.colorScheme.surfaceContainerHighest;
      final disabledForeground = theme.colorScheme.onSurfaceVariant;
      return Chip(
        avatar: Icon(
          icon,
          size: 16,
          color: enabled ? selectedForeground : disabledForeground,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: enabled ? selectedForeground : disabledForeground,
          ),
        ),
        backgroundColor: enabled ? selectedBackground : disabledBackground,
      );
    }

    return [
      buildChip(preferences.push, 'Push', Icons.notifications_active_rounded),
      buildChip(preferences.email, 'Email', Icons.email_rounded),
      buildChip(preferences.whatsapp, 'WhatsApp', Icons.chat_rounded),
      buildChip(preferences.sms, 'SMS', Icons.sms_rounded),
    ];
  }
}

class _InfoFieldData {
  const _InfoFieldData({required this.label, required this.value});

  final String label;
  final String value;
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
    this.minLines = 1,
  });

  final String label;
  final String value;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      initialValue: value,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _ClientPhotosCard extends ConsumerStatefulWidget {
  const _ClientPhotosCard({required this.client});

  final Client client;

  @override
  ConsumerState<_ClientPhotosCard> createState() => _ClientPhotosCardState();
}

class _ClientQuestionnaireCard extends ConsumerStatefulWidget {
  const _ClientQuestionnaireCard({required this.client});

  final Client client;

  @override
  ConsumerState<_ClientQuestionnaireCard> createState() =>
      _ClientQuestionnaireCardState();
}

class _ClientQuestionnaireCardState
    extends ConsumerState<_ClientQuestionnaireCard> {
  final _uuid = const Uuid();
  String? _selectedTemplateId;
  Map<String, _QuestionAnswerEditor> _answers =
      <String, _QuestionAnswerEditor>{};
  bool _initialized = false;
  bool _isSaving = false;
  String? _currentQuestionnaireId;
  DateTime? _currentCreatedAt;
  DateTime? _currentUpdatedAt;

  @override
  void dispose() {
    _disposeAnswers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final templates =
        data.clientQuestionnaireTemplates
            .where((template) => template.salonId == widget.client.salonId)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final questionnaires =
        data.clientQuestionnaires
            .where((item) => item.clientId == widget.client.id)
            .toList();

    _syncState(templates, questionnaires);

    final theme = Theme.of(context);

    if (templates.isEmpty) {
      return Card(
        child: ExpansionTile(
          key: ValueKey('questionnaire-${widget.client.id}'),
          initiallyExpanded: false,
          title: Text(
            'Questionario cliente',
            style: theme.textTheme.titleMedium,
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: const [
            Text(
              'Nessun modello di questionario è stato configurato per questo salone.',
            ),
          ],
        ),
      );
    }

    final selectedTemplate = templates.firstWhereOrNull(
      (template) => template.id == _selectedTemplateId,
    );
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final content = <Widget>[
      DropdownButtonFormField<String>(
        value: _selectedTemplateId,
        decoration: const InputDecoration(labelText: 'Modello questionario'),
        items:
            templates
                .map(
                  (template) => DropdownMenuItem(
                    value: template.id,
                    child: Text(
                      template.isDefault
                          ? '${template.name} (predefinito)'
                          : template.name,
                    ),
                  ),
                )
                .toList(),
        onChanged:
            (value) => _handleTemplateChange(value, templates, questionnaires),
      ),
    ];

    if (selectedTemplate?.description != null) {
      content
        ..add(const SizedBox(height: 8))
        ..add(Text(selectedTemplate!.description!));
    }

    if (_currentUpdatedAt != null) {
      content
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            'Ultimo aggiornamento: ${dateFormat.format(_currentUpdatedAt!)}',
            style: theme.textTheme.bodySmall,
          ),
        );
    } else if (_currentCreatedAt != null) {
      content
        ..add(const SizedBox(height: 8))
        ..add(
          Text(
            'Compilato il: ${dateFormat.format(_currentCreatedAt!)}',
            style: theme.textTheme.bodySmall,
          ),
        );
    }

    if (selectedTemplate != null) {
      content
        ..add(const SizedBox(height: 16))
        ..add(
          _buildQuestionnaireForm(
            template: selectedTemplate,
            questionnaires: questionnaires,
          ),
        );
    } else {
      content.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Seleziona un modello per compilare il questionario.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final subtitle =
        selectedTemplate == null
            ? null
            : Text(selectedTemplate.name, style: theme.textTheme.labelMedium);

    return Card(
      child: ExpansionTile(
        key: ValueKey('questionnaire-${widget.client.id}'),
        initiallyExpanded: true,
        title: Text('Questionario cliente', style: theme.textTheme.titleMedium),
        subtitle: subtitle,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireForm({
    required ClientQuestionnaireTemplate template,
    required List<ClientQuestionnaire> questionnaires,
  }) {
    if (_supportsAnamnesisLayout(template)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnamnesisLayout(template),
          const SizedBox(height: 16),
          _buildFormActions(template, questionnaires),
        ],
      );
    }

    final children = <Widget>[];
    for (
      var groupIndex = 0;
      groupIndex < template.groups.length;
      groupIndex++
    ) {
      final group = template.groups[groupIndex];
      children.add(
        ExpansionTile(
          key: ValueKey(group.id),
          title: Text(group.title),
          initiallyExpanded: groupIndex == 0,
          subtitle: group.description == null ? null : Text(group.description!),
          children:
              group.questions
                  .map(
                    (question) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: _buildQuestionField(question),
                    ),
                  )
                  .toList(),
        ),
      );
    }

    children.add(_buildFormActions(template, questionnaires));

    return Column(children: children);
  }

  Widget _buildFormActions(
    ClientQuestionnaireTemplate template,
    List<ClientQuestionnaire> questionnaires,
  ) {
    final templatesForSalon = ref
        .read(appDataProvider)
        .clientQuestionnaireTemplates
        .where((item) => item.salonId == widget.client.salonId)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          TextButton(
            onPressed:
                _isSaving
                    ? null
                    : () => _selectTemplate(
                      template.id,
                      templatesForSalon,
                      questionnaires,
                    ),
            child: const Text('Reimposta'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _isSaving ? null : () => _save(template, questionnaires),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSaving) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Text('Salvataggio...'),
                ] else ...[
                  const Icon(Icons.save_rounded),
                  const SizedBox(width: 8),
                  const Text('Salva questionario'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _supportsAnamnesisLayout(ClientQuestionnaireTemplate template) {
    return _canUseAnamnesisLayout(template);
  }

  Widget _buildAnamnesisLayout(ClientQuestionnaireTemplate template) {
    final theme = Theme.of(context);

    final questionsById = <String, ClientQuestionDefinition>{};
    for (final group in template.groups) {
      for (final question in group.questions) {
        questionsById[question.id] = question;
      }
    }

    ClientQuestionDefinition? question(String id) => questionsById[id];

    List<Widget> buildBooleanFields(Set<String> ids) {
      return ids
          .map(question)
          .whereType<ClientQuestionDefinition>()
          .map(_buildAnamnesisBooleanField)
          .whereType<Widget>()
          .toList(growable: false);
    }

    List<Widget> buildSingleChoiceFields(Set<String> ids) {
      return ids
          .map(question)
          .whereType<ClientQuestionDefinition>()
          .map(_buildAnamnesisSingleChoiceField)
          .whereType<Widget>()
          .toList(growable: false);
    }

    List<Widget> buildTextFields(Set<String> ids) {
      return ids
          .map(question)
          .whereType<ClientQuestionDefinition>()
          .map(_buildAnamnesisTextField)
          .whereType<Widget>()
          .toList(growable: false);
    }

    final generalHealthFields = buildBooleanFields(_generalHealthQuestionIds);
    final lifestyleBooleanFields = buildBooleanFields(
      _lifestyleBooleanQuestionIds,
    );
    final lifestyleTextFields = buildTextFields(_lifestyleTextQuestionIds);
    final aestheticBooleanFields = buildBooleanFields(
      _aestheticBooleanQuestionIds,
    );
    final aestheticSingleChoiceFields = buildSingleChoiceFields(
      _aestheticSingleChoiceQuestionIds,
    );
    final aestheticTexts = buildTextFields(_aestheticTextQuestionIds);
    final measurementNumbers = _measurementNumberQuestionIds
        .map(question)
        .whereType<ClientQuestionDefinition>()
        .map(_buildAnamnesisNumberField)
        .whereType<Widget>()
        .toList(growable: false);
    final measurementChoiceFields = buildSingleChoiceFields(
      _measurementSingleChoiceQuestionIds,
    );
    final noteTexts = buildTextFields(_noteTextQuestionIds);

    final consentBool = _buildAnamnesisBooleanField(
      question('q-consent-informed'),
      allowTristate: false,
    );
    final consentSignature = _buildAnamnesisTextField(
      question('q-client-signature'),
    );
    final consentDate = _buildAnamnesisDateField(question('q-consent-date'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 980;
        final double interColumnSpacing = wide ? 24 : 16;

        final leftSections = <Widget>[
          if (generalHealthFields.isNotEmpty)
            _anamnesisSection(
              title: 'Stato di salute generale',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._withSectionSpacing(generalHealthFields, spacing: 8),
                ],
              ),
            ),
          if (lifestyleBooleanFields.isNotEmpty ||
              lifestyleTextFields.isNotEmpty)
            _anamnesisSection(
              title: 'Stile di vita',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lifestyleBooleanFields.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSectionSpacing(
                        lifestyleBooleanFields,
                        spacing: 8,
                      ),
                    ),
                  if (lifestyleBooleanFields.isNotEmpty &&
                      lifestyleTextFields.isNotEmpty)
                    const SizedBox(height: 16),
                  if (lifestyleTextFields.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSectionSpacing(lifestyleTextFields),
                    ),
                ],
              ),
            ),
          if (aestheticBooleanFields.isNotEmpty ||
              aestheticSingleChoiceFields.isNotEmpty ||
              aestheticTexts.isNotEmpty)
            _anamnesisSection(
              title: 'Anamnesi estetica',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (aestheticBooleanFields.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSectionSpacing(
                        aestheticBooleanFields,
                        spacing: 8,
                      ),
                    ),
                  if (aestheticBooleanFields.isNotEmpty &&
                      aestheticSingleChoiceFields.isNotEmpty)
                    const SizedBox(height: 16),
                  if (aestheticSingleChoiceFields.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSectionSpacing(
                        aestheticSingleChoiceFields,
                        spacing: 12,
                      ),
                    ),
                  if ((aestheticBooleanFields.isNotEmpty ||
                          aestheticSingleChoiceFields.isNotEmpty) &&
                      aestheticTexts.isNotEmpty)
                    const SizedBox(height: 16),
                  if (aestheticTexts.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSectionSpacing(aestheticTexts),
                    ),
                ],
              ),
            ),
        ];

        final rightSections = <Widget>[
          if (measurementNumbers.isNotEmpty ||
              measurementChoiceFields.isNotEmpty)
            _anamnesisSection(
              title: 'Misurazioni e rilevazioni',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (measurementNumbers.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSectionSpacing(measurementNumbers),
                    ),
                  if (measurementNumbers.isNotEmpty &&
                      measurementChoiceFields.isNotEmpty)
                    const SizedBox(height: 16),
                  if (measurementChoiceFields.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _withSectionSpacing(
                        measurementChoiceFields,
                        spacing: 12,
                      ),
                    ),
                ],
              ),
            ),
          if (noteTexts.isNotEmpty)
            _anamnesisSection(
              title: 'Note e raccomandazioni',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _withSectionSpacing(noteTexts),
              ),
            ),
          if (consentBool != null ||
              consentSignature != null ||
              consentDate != null)
            _anamnesisSection(
              title: 'Consenso informato',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _withSectionSpacing([
                  if (consentBool != null) consentBool,
                  if (consentSignature != null) consentSignature,
                  if (consentDate != null) consentDate,
                ]),
              ),
            ),
        ];

        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _withColumnSpacing(leftSections),
        );
        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _withColumnSpacing(rightSections),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anamnesi Cliente',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Raccogli e aggiorna rapidamente i dati anamnestici del cliente.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: leftColumn),
                  SizedBox(width: interColumnSpacing),
                  Expanded(flex: 2, child: rightColumn),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [leftColumn, const SizedBox(height: 24), rightColumn],
              ),
          ],
        );
      },
    );
  }

  Widget _anamnesisSection({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  List<Widget> _withSectionSpacing(List<Widget> items, {double spacing = 12}) {
    if (items.isEmpty) {
      return items;
    }
    final result = <Widget>[];
    for (var index = 0; index < items.length; index += 1) {
      result.add(items[index]);
      if (index != items.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }

  List<Widget> _withColumnSpacing(
    List<Widget> sections, {
    double spacing = 24,
  }) {
    if (sections.isEmpty) {
      return sections;
    }
    final result = <Widget>[];
    for (var index = 0; index < sections.length; index += 1) {
      result.add(sections[index]);
      if (index != sections.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }

  Widget? _buildAnamnesisBooleanField(
    ClientQuestionDefinition? question, {
    bool allowTristate = true,
  }) {
    if (question == null) {
      return null;
    }
    final answer = _answers[question.id];
    if (answer == null) {
      return null;
    }
    final bool tristate = allowTristate && !question.isRequired;
    final bool? currentValue =
        tristate ? answer.boolValue : (answer.boolValue ?? false);

    return CheckboxListTile(
      key: ValueKey('bool-field-${question.id}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      tristate: tristate,
      title: Text(question.label),
      subtitle: question.helperText == null ? null : Text(question.helperText!),
      value: currentValue,
      onChanged: (value) {
        setState(() {
          if (tristate) {
            answer.boolValue = value;
          } else {
            answer.boolValue = value ?? false;
          }
        });
      },
    );
  }

  Widget? _buildAnamnesisSingleChoiceField(ClientQuestionDefinition? question) {
    if (question == null || question.options.isEmpty) {
      return null;
    }
    final answer = _answers[question.id];
    if (answer == null) {
      return null;
    }
    final selected = answer.optionIds.isEmpty ? null : answer.optionIds.first;

    return DropdownButtonFormField<String>(
      key: ValueKey('single-${question.id}'),
      value: selected,
      decoration: InputDecoration(
        labelText: question.label,
        helperText: question.helperText,
      ),
      items: question.options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.id,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        setState(() {
          answer.optionIds.clear();
          if (value != null) {
            answer.optionIds.add(value);
          }
        });
      },
    );
  }

  Widget? _buildAnamnesisTextField(ClientQuestionDefinition? question) {
    if (question == null) {
      return null;
    }
    final answer = _answers[question.id];
    if (answer == null) {
      return null;
    }
    final isMultiline = question.type == ClientQuestionType.textarea;
    return TextFormField(
      key: ValueKey('text-${question.id}'),
      controller: answer.textController,
      minLines: isMultiline ? 3 : 1,
      maxLines: isMultiline ? null : 1,
      decoration: InputDecoration(
        labelText: question.label,
        helperText: question.helperText,
      ),
    );
  }

  Widget? _buildAnamnesisNumberField(ClientQuestionDefinition? question) {
    if (question == null) {
      return null;
    }
    final answer = _answers[question.id];
    if (answer == null) {
      return null;
    }
    return TextFormField(
      key: ValueKey('number-${question.id}'),
      controller: answer.textController,
      decoration: InputDecoration(
        labelText: question.label,
        helperText: question.helperText,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) => answer.numberValue = double.tryParse(value.trim()),
    );
  }

  Widget? _buildAnamnesisDateField(ClientQuestionDefinition? question) {
    if (question == null) {
      return null;
    }
    final answer = _answers[question.id];
    if (answer == null) {
      return null;
    }
    final theme = Theme.of(context);
    final value = answer.dateValue;
    final formatted =
        value == null
            ? 'Seleziona data'
            : DateFormat('dd/MM/yyyy').format(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _pickDate(answer),
              icon: const Icon(Icons.event_rounded),
              label: Text(formatted),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed:
                  value == null
                      ? null
                      : () => setState(() => answer.dateValue = null),
              child: const Text('Pulisci'),
            ),
          ],
        ),
        if (question.helperText != null) ...[
          const SizedBox(height: 8),
          Text(question.helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _buildQuestionField(ClientQuestionDefinition question) {
    final answer = _answers[question.id];
    if (answer == null) {
      return const SizedBox.shrink();
    }
    final label = _questionLabel(question);

    switch (question.type) {
      case ClientQuestionType.boolean:
        return DropdownButtonFormField<bool?>(
          value: answer.boolValue,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Non compilato')),
            DropdownMenuItem<bool?>(value: true, child: Text('Si')),
            DropdownMenuItem<bool?>(value: false, child: Text('No')),
          ],
          onChanged: (value) => setState(() => answer.boolValue = value),
        );
      case ClientQuestionType.text:
        return TextFormField(
          controller: answer.textController,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
        );
      case ClientQuestionType.textarea:
        return TextFormField(
          controller: answer.textController,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          maxLines: 4,
        );
      case ClientQuestionType.singleChoice:
        final selected =
            answer.optionIds.isEmpty ? null : answer.optionIds.first;
        return DropdownButtonFormField<String>(
          value: selected,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          items:
              question.options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.id,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
          onChanged:
              (value) => setState(() {
                answer.optionIds
                  ..clear()
                  ..addAll(value == null ? const <String>[] : <String>[value]);
              }),
        );
      case ClientQuestionType.multiChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  question.options
                      .map(
                        (option) => FilterChip(
                          label: Text(option.label),
                          selected: answer.optionIds.contains(option.id),
                          onSelected:
                              (value) => setState(() {
                                if (value) {
                                  answer.optionIds.add(option.id);
                                } else {
                                  answer.optionIds.remove(option.id);
                                }
                              }),
                        ),
                      )
                      .toList(),
            ),
            if (question.helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  question.helperText!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      case ClientQuestionType.number:
        return TextFormField(
          controller: answer.textController,
          decoration: InputDecoration(
            labelText: label,
            helperText: question.helperText,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged:
              (value) => answer.numberValue = double.tryParse(value.trim()),
        );
      case ClientQuestionType.date:
        final value = answer.dateValue;
        final dateLabel =
            value == null
                ? 'Nessuna data selezionata'
                : DateFormat('dd/MM/yyyy').format(value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _pickDate(answer),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    value == null
                        ? 'Seleziona data'
                        : DateFormat('dd/MM/yyyy').format(value),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed:
                      value == null
                          ? null
                          : () => setState(() => answer.dateValue = null),
                  child: const Text('Pulisci'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (question.helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  question.helperText!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
    }
  }

  Future<void> _pickDate(_QuestionAnswerEditor answer) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: answer.dateValue ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) {
      setState(() => answer.dateValue = selected);
    }
  }

  void _handleTemplateChange(
    String? value,
    List<ClientQuestionnaireTemplate> templates,
    List<ClientQuestionnaire> questionnaires,
  ) {
    if (value == null) {
      return;
    }
    _selectTemplate(value, templates, questionnaires);
  }

  void _syncState(
    List<ClientQuestionnaireTemplate> templates,
    List<ClientQuestionnaire> questionnaires,
  ) {
    if (_isSaving) {
      return;
    }
    if (templates.isEmpty) {
      if (_selectedTemplateId != null || _answers.isNotEmpty) {
        _disposeAnswers();
        _selectedTemplateId = null;
        _currentQuestionnaireId = null;
        _currentCreatedAt = null;
        _currentUpdatedAt = null;
        _initialized = false;
      }
      return;
    }
    final selected = templates.firstWhereOrNull(
      (template) => template.id == _selectedTemplateId,
    );
    if (!_initialized || selected == null) {
      final initial = _determineInitialTemplate(templates, questionnaires);
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _selectTemplate(initial.id, templates, questionnaires);
        });
      }
      return;
    }

    final latest = _latestQuestionnaireForTemplate(questionnaires, selected.id);
    final latestUpdatedAt = latest?.updatedAt;
    if (latestUpdatedAt != _currentUpdatedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectTemplate(selected.id, templates, questionnaires);
      });
    }
  }

  ClientQuestionnaireTemplate? _determineInitialTemplate(
    List<ClientQuestionnaireTemplate> templates,
    List<ClientQuestionnaire> questionnaires,
  ) {
    if (templates.isEmpty) {
      return null;
    }
    final sorted =
        questionnaires.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final existing = sorted.firstWhereOrNull(
      (item) => templates.any((template) => template.id == item.templateId),
    );
    if (existing != null) {
      return templates.firstWhereOrNull((t) => t.id == existing.templateId);
    }
    return templates.firstWhereOrNull((template) => template.isDefault) ??
        templates.first;
  }

  ClientQuestionnaire? _latestQuestionnaireForTemplate(
    List<ClientQuestionnaire> questionnaires,
    String templateId,
  ) {
    final matches =
        questionnaires.where((item) => item.templateId == templateId).toList();
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return matches.first;
  }

  void _selectTemplate(
    String templateId,
    List<ClientQuestionnaireTemplate> templates,
    List<ClientQuestionnaire> questionnaires,
  ) {
    final template = templates.firstWhereOrNull((t) => t.id == templateId);
    if (template == null) {
      return;
    }
    final latest = _latestQuestionnaireForTemplate(questionnaires, template.id);
    final newAnswers = <String, _QuestionAnswerEditor>{};
    for (final group in template.groups) {
      for (final question in group.questions) {
        final existing = latest?.answerFor(question.id);
        newAnswers[question.id] = _QuestionAnswerEditor(
          boolValue: existing?.boolValue,
          textValue: existing?.textValue,
          optionIds: existing == null ? <String>{} : existing.optionIds.toSet(),
          numberValue: existing?.numberValue,
          dateValue: existing?.dateValue,
        );
      }
    }

    _disposeAnswers();
    setState(() {
      _selectedTemplateId = template.id;
      _answers = newAnswers;
      _currentQuestionnaireId = latest?.id;
      _currentCreatedAt = latest?.createdAt;
      _currentUpdatedAt = latest?.updatedAt;
      _initialized = true;
    });
  }

  void _disposeAnswers() {
    for (final entry in _answers.values) {
      entry.dispose();
    }
    _answers = <String, _QuestionAnswerEditor>{};
  }

  Future<void> _save(
    ClientQuestionnaireTemplate template,
    List<ClientQuestionnaire> questionnaires,
  ) async {
    final error = _validateAnswers(template);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final answers = _collectAnswers(template);
    final now = DateTime.now();
    final questionnaire = ClientQuestionnaire(
      id: _currentQuestionnaireId ?? _uuid.v4(),
      clientId: widget.client.id,
      salonId: widget.client.salonId,
      templateId: template.id,
      answers: answers,
      createdAt: _currentCreatedAt ?? now,
      updatedAt: now,
    );

    setState(() => _isSaving = true);
    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertClientQuestionnaire(questionnaire);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _currentQuestionnaireId = questionnaire.id;
        _currentCreatedAt = questionnaire.createdAt;
        _currentUpdatedAt = questionnaire.updatedAt;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Questionario aggiornato.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $error')),
      );
    }
  }

  String? _validateAnswers(ClientQuestionnaireTemplate template) {
    for (final group in template.groups) {
      for (final question in group.questions) {
        final answer = _answers[question.id];
        if (answer == null) {
          continue;
        }
        switch (question.type) {
          case ClientQuestionType.boolean:
            if (question.isRequired && answer.boolValue == null) {
              return 'Compila la domanda "${question.label}"';
            }
            break;
          case ClientQuestionType.text:
          case ClientQuestionType.textarea:
            final text = answer.textController.text.trim();
            if (question.isRequired && text.isEmpty) {
              return 'Compila la domanda "${question.label}"';
            }
            break;
          case ClientQuestionType.singleChoice:
            if (question.isRequired && answer.optionIds.isEmpty) {
              return 'Seleziona un valore per "${question.label}"';
            }
            break;
          case ClientQuestionType.multiChoice:
            if (question.isRequired && answer.optionIds.isEmpty) {
              return 'Seleziona almeno un valore per "${question.label}"';
            }
            break;
          case ClientQuestionType.number:
            final text = answer.textController.text.trim();
            if (text.isEmpty) {
              if (question.isRequired) {
                return 'Inserisci un valore numerico per "${question.label}"';
              }
            } else {
              final parsed = double.tryParse(text);
              if (parsed == null) {
                return 'Inserisci un numero valido per "${question.label}"';
              }
              answer.numberValue = parsed;
            }
            break;
          case ClientQuestionType.date:
            if (question.isRequired && answer.dateValue == null) {
              return 'Seleziona una data per "${question.label}"';
            }
            break;
        }
      }
    }
    return null;
  }

  List<ClientQuestionAnswer> _collectAnswers(
    ClientQuestionnaireTemplate template,
  ) {
    final answers = <ClientQuestionAnswer>[];
    for (final group in template.groups) {
      for (final question in group.questions) {
        final editor = _answers[question.id];
        if (editor == null) {
          continue;
        }
        switch (question.type) {
          case ClientQuestionType.boolean:
            answers.add(
              ClientQuestionAnswer(
                questionId: question.id,
                boolValue: editor.boolValue,
              ),
            );
            break;
          case ClientQuestionType.text:
          case ClientQuestionType.textarea:
            final text = editor.textController.text.trim();
            answers.add(
              ClientQuestionAnswer(
                questionId: question.id,
                textValue: text.isEmpty ? null : text,
              ),
            );
            break;
          case ClientQuestionType.singleChoice:
            final selected =
                editor.optionIds.isEmpty ? null : editor.optionIds.first;
            answers.add(
              ClientQuestionAnswer(
                questionId: question.id,
                optionIds:
                    selected == null ? const <String>[] : <String>[selected],
              ),
            );
            break;
          case ClientQuestionType.multiChoice:
            answers.add(
              ClientQuestionAnswer(
                questionId: question.id,
                optionIds: editor.optionIds.toList(growable: false),
              ),
            );
            break;
          case ClientQuestionType.number:
            final text = editor.textController.text.trim();
            final parsed = text.isEmpty ? null : double.tryParse(text);
            answers.add(
              ClientQuestionAnswer(
                questionId: question.id,
                numberValue: parsed,
              ),
            );
            break;
          case ClientQuestionType.date:
            answers.add(
              ClientQuestionAnswer(
                questionId: question.id,
                dateValue: editor.dateValue,
              ),
            );
            break;
        }
      }
    }
    return answers;
  }

  String _questionLabel(ClientQuestionDefinition question) {
    return question.isRequired ? '${question.label} *' : question.label;
  }
}

class _QuestionAnswerEditor {
  _QuestionAnswerEditor({
    this.boolValue,
    String? textValue,
    Set<String>? optionIds,
    num? numberValue,
    DateTime? dateValue,
  }) : textController = TextEditingController(
         text: textValue ?? (numberValue?.toString() ?? ''),
       ),
       optionIds = optionIds ?? <String>{},
       numberValue = numberValue?.toDouble(),
       dateValue = dateValue;

  bool? boolValue;
  final TextEditingController textController;
  Set<String> optionIds;
  double? numberValue;
  DateTime? dateValue;

  void dispose() {
    textController.dispose();
  }
}

class _ClientPhotosCardState extends ConsumerState<_ClientPhotosCard> {
  final Set<String> _deleting = <String>{};
  final Set<String> _updatingNotes = <String>{};
  final TextEditingController _noteController = TextEditingController();
  bool _isUploading = false;
  final Uuid _uuid = const Uuid();
  static const int _maxUploadBytes = 10 * 1024 * 1024;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = ref.watch(clientPhotosProvider(widget.client.id));
    final sortedPhotos = photos.toList(growable: false)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    final photoCount = sortedPhotos.length;
    final subtitle =
        photoCount == 0
            ? 'Nessuna foto'
            : photoCount == 1
            ? '1 foto'
            : '$photoCount foto';

    return Card(
      child: ExpansionTile(
        key: ValueKey('photos-${widget.client.id}'),
        initiallyExpanded: true,
        title: Text('Archivio fotografico', style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Aggiorna elenco foto',
                  onPressed:
                      _isUploading
                          ? null
                          : () => ref.invalidate(
                            clientPhotosProvider(widget.client.id),
                          ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nota da allegare (opzionale)',
                  hintText: 'Esempio: Prima del trattamento viso',
                  helperText:
                      'La nota viene applicata a tutte le foto selezionate al prossimo caricamento.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _isUploading ? null : _pickAndUpload,
                  icon:
                      _isUploading
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.file_upload_outlined),
                  label: Text(
                    _isUploading ? 'Caricamento in corso…' : 'Carica foto',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (sortedPhotos.isEmpty)
                Text(
                  'Nessuna foto presente nella scheda cliente. Carica una o più immagini per iniziare.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final photo = sortedPhotos[index];
                    final isDeleting = _deleting.contains(photo.id);
                    final isUpdating = _updatingNotes.contains(photo.id);
                    return _ClientPhotoTile(
                      photo: photo,
                      isDeleting: isDeleting,
                      isUpdating: isUpdating,
                      onPreview: () => _previewPhoto(photo),
                      onEditNote: () => _editNote(photo),
                      onDelete: () => _deletePhoto(photo),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final storage = ref.read(firebaseStorageServiceProvider);
    final dataStore = ref.read(appDataProvider.notifier);
    final session = ref.read(sessionControllerProvider);
    final uploaderId = session.uid ?? 'unknown';
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    setState(() => _isUploading = true);

    try {
      var uploadedCount = 0;
      final skippedTooLarge = <String>[];
      final skippedUnreadable = <String>[];
      for (final file in result.files) {
        if (file.size > _maxUploadBytes) {
          skippedTooLarge.add(file.name);
          continue;
        }
        final Uint8List? bytes = await _resolveBytes(file);
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
          notes: note,
        );
        await dataStore.upsertClientPhoto(photo);
        uploadedCount += 1;
      }
      if (!mounted) {
        return;
      }
      if (uploadedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadedCount == 1
                  ? 'Foto caricata correttamente.'
                  : '$uploadedCount foto caricate correttamente.',
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
        ).showSnackBar(SnackBar(content: Text(messages.join('\n'))));
      }
      if (uploadedCount == 0 &&
          skippedTooLarge.isEmpty &&
          skippedUnreadable.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun file valido selezionato.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile caricare le foto: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<Uint8List?> _resolveBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    final stream = file.readStream;
    if (stream == null) {
      return null;
    }
    final builder = BytesBuilder();
    try {
      await for (final chunk in stream) {
        builder.add(chunk);
        if (builder.length > _maxUploadBytes) {
          // Stop early if the stream exceeds the allowed size.
          return null;
        }
      }
      final data = builder.takeBytes();
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deletePhoto(ClientPhoto photo) async {
    if (_deleting.contains(photo.id)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Elimina foto'),
          content: const Text(
            'La foto verrà rimossa definitivamente sia dall\'archivio sia dal cloud storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }

    final dataStore = ref.read(appDataProvider.notifier);
    final storage = ref.read(firebaseStorageServiceProvider);

    setState(() => _deleting.add(photo.id));
    try {
      await dataStore.deleteClientPhoto(photo.id);
      await storage.deleteFile(photo.storagePath);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto eliminata.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Non è stato possibile eliminare la foto: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting.remove(photo.id));
      }
    }
  }

  Future<void> _editNote(ClientPhoto photo) async {
    if (_updatingNotes.contains(photo.id)) {
      return;
    }
    final controller = TextEditingController(text: photo.notes ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modifica nota'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Annotazioni sulla foto (facoltative)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Rimuovi nota'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null) {
      return;
    }

    final updatedNote = result.isEmpty ? null : result;
    final updatedPhoto = photo.copyWith(notes: updatedNote);
    final dataStore = ref.read(appDataProvider.notifier);

    setState(() => _updatingNotes.add(photo.id));
    try {
      await dataStore.upsertClientPhoto(updatedPhoto);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nota aggiornata.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aggiornamento nota non riuscito: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingNotes.remove(photo.id));
      }
    }
  }

  void _previewPhoto(ClientPhoto photo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
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
                if (photo.notes != null && photo.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        photo.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Chiudi'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClientPhotoTile extends StatelessWidget {
  const _ClientPhotoTile({
    required this.photo,
    required this.isDeleting,
    required this.isUpdating,
    required this.onPreview,
    required this.onEditNote,
    required this.onDelete,
  });

  final ClientPhoto photo;
  final bool isDeleting;
  final bool isUpdating;
  final VoidCallback onPreview;
  final VoidCallback onEditNote;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileLabel =
        (photo.fileName != null && photo.fileName!.trim().isNotEmpty)
            ? photo.fileName!.trim()
            : 'Foto cliente';
    final uploadedAt = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(photo.uploadedAt.toLocal());

    final editAction =
        isUpdating
            ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.edit_note_outlined),
              tooltip: 'Modifica nota',
              color: theme.colorScheme.primary,
              onPressed: onEditNote,
            );

    final deleteAction =
        isDeleting
            ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Elimina foto',
              color: theme.colorScheme.error,
              onPressed: onDelete,
            );

    return ListTile(
      onTap: onPreview,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        fileLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uploadedAt,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tocca per visualizzare',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [editAction, const SizedBox(width: 8), deleteAction],
      ),
    );
  }
}

class _AppointmentsTab extends ConsumerWidget {
  const _AppointmentsTab({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();

    final appointments =
        data.appointments
            .where((appointment) => appointment.clientId == clientId)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final staff = data.staff;
    final services = data.services;
    final salons = data.salons;
    final clients = data.clients;
    final client = clients.firstWhereOrNull((item) => item.id == clientId);

    final upcoming =
        appointments
            .where((appointment) => appointment.start.isAfter(now))
            .toList();
    final history =
        appointments
            .where((appointment) => !appointment.start.isAfter(now))
            .toList()
            .reversed
            .toList();

    Future<void> openForm({Appointment? existing}) async {
      final latest = ref.read(appDataProvider);
      final sheetSalons = latest.salons.isNotEmpty ? latest.salons : salons;
      final sheetClients = latest.clients.isNotEmpty ? latest.clients : clients;
      final sheetStaff = latest.staff.isNotEmpty ? latest.staff : staff;
      final sheetServices =
          latest.services.isNotEmpty ? latest.services : services;

      final result = await showAppModalSheet<AppointmentFormResult>(
        context: context,
        builder:
            (ctx) => AppointmentFormSheet(
              salons: sheetSalons,
              clients: sheetClients,
              staff: sheetStaff,
              services: sheetServices,
              defaultSalonId: existing?.salonId ?? client?.salonId,
              defaultClientId: existing?.clientId ?? client?.id,
              initial: existing,
              enableDelete: existing != null,
            ),
      );
      if (result == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      if (result.action == AppointmentFormAction.copy) {
        ref.read(appointmentClipboardProvider.notifier).state =
            AppointmentClipboard(
              appointment: result.appointment,
              copiedAt: DateTime.now(),
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appuntamento copiato. Seleziona uno slot libero.'),
          ),
        );
        return;
      }
      if (result.action == AppointmentFormAction.delete) {
        return;
      }
      await _validateAndSaveAppointment(
        context,
        ref,
        result.appointment,
        appointments,
        sheetServices,
        sheetSalons,
      );
    }

    Future<void> createAppointment() async {
      await openForm();
    }

    Future<void> editAppointment(Appointment appointment) async {
      await openForm(existing: appointment);
    }

    Future<void> deleteAppointment(Appointment appointment) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Elimina appuntamento'),
              content: const Text(
                'Vuoi eliminare definitivamente questo appuntamento?',
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
      if (confirm != true) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(appDataProvider.notifier)
            .deleteAppointment(appointment.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Appuntamento eliminato.')),
        );
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: client == null ? null : createAppointment,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuovo appuntamento'),
          ),
        ),
        const SizedBox(height: 16),
        _AppointmentGroup(
          title: 'Appuntamenti futuri',
          emptyMessage: 'Nessun appuntamento futuro prenotato.',
          appointments: upcoming,
          staff: staff,
          services: services,
          dateFormat: dateFormat,
          currency: currency,
          enableActions: true,
          onEditAppointment: editAppointment,
          onDeleteAppointment: deleteAppointment,
        ),
        const SizedBox(height: 16),
        _AppointmentGroup(
          title: 'Appuntamenti passati',
          emptyMessage: 'Non sono presenti appuntamenti passati.',
          appointments: history,
          staff: staff,
          services: services,
          dateFormat: dateFormat,
          currency: currency,
        ),
      ],
    );
  }

  Future<bool> _validateAndSaveAppointment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    List<Appointment> fallbackAppointments,
    List<Service> fallbackServices,
    List<Salon> fallbackSalons,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = ref.read(appDataProvider);
    final existingAppointments =
        data.appointments.isNotEmpty ? data.appointments : fallbackAppointments;
    final services =
        data.services.isNotEmpty ? data.services : fallbackServices;
    final salons = data.salons.isNotEmpty ? data.salons : fallbackSalons;

    final now = DateTime.now();
    final expressPlaceholders =
        data.lastMinuteSlots
            .where((slot) {
              if (slot.salonId != appointment.salonId) {
                return false;
              }
              if (slot.operatorId != appointment.staffId) {
                return false;
              }
              if (!slot.isAvailable) {
                return false;
              }
              if (!slot.end.isAfter(now)) {
                return false;
              }
              return true;
            })
            .map(
              (slot) => Appointment(
                id: 'last-minute-${slot.id}',
                salonId: slot.salonId,
                clientId: 'last-minute-${slot.id}',
                staffId: slot.operatorId ?? appointment.staffId,
                serviceIds:
                    slot.serviceId != null && slot.serviceId!.isNotEmpty
                        ? <String>[slot.serviceId!]
                        : const <String>[],
                start: slot.start,
                end: slot.end,
                status: AppointmentStatus.scheduled,
                roomId: slot.roomId,
              ),
            )
            .toList();
    final combinedAppointments = <Appointment>[
      ...existingAppointments,
      ...expressPlaceholders,
    ];

    final hasStaffConflict = hasStaffBookingConflict(
      appointments: combinedAppointments,
      staffId: appointment.staffId,
      start: appointment.start,
      end: appointment.end,
      excludeAppointmentId: appointment.id,
    );
    if (hasStaffConflict) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare: operatore già occupato in quel periodo',
          ),
        ),
      );
      return false;
    }

    final hasClientConflict = hasClientBookingConflict(
      appointments: existingAppointments,
      clientId: appointment.clientId,
      start: appointment.start,
      end: appointment.end,
      excludeAppointmentId: appointment.id,
    );
    if (hasClientConflict) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare: il cliente ha già un appuntamento in quel periodo',
          ),
        ),
      );
      return false;
    }

    final appointmentServices =
        appointment.serviceIds
            .map((id) => services.firstWhereOrNull((item) => item.id == id))
            .whereType<Service>()
            .toList();
    if (appointmentServices.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Servizio non valido.')),
      );
      return false;
    }
    final salon = salons.firstWhereOrNull(
      (item) => item.id == appointment.salonId,
    );
    final blockingEquipment = <String>{};
    for (final service in appointmentServices) {
      final equipmentCheck = EquipmentAvailabilityChecker.check(
        salon: salon,
        service: service,
        allServices: services,
        appointments: combinedAppointments,
        start: appointment.start,
        end: appointment.end,
        excludeAppointmentId: appointment.id,
      );
      if (equipmentCheck.hasConflicts) {
        blockingEquipment.addAll(equipmentCheck.blockingEquipment);
      }
    }
    if (blockingEquipment.isNotEmpty) {
      final equipmentLabel = blockingEquipment.join(', ');
      final message =
          equipmentLabel.isEmpty
              ? 'Macchinario non disponibile per questo orario.'
              : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
      messenger.showSnackBar(
        SnackBar(content: Text('$message Scegli un altro slot.')),
      );
      return false;
    }

    try {
      await ref.read(appDataProvider.notifier).upsertAppointment(appointment);
      return true;
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $error')),
      );
      return false;
    }
  }
}

class _AppointmentGroup extends StatelessWidget {
  const _AppointmentGroup({
    required this.title,
    required this.emptyMessage,
    required this.appointments,
    required this.staff,
    required this.services,
    required this.dateFormat,
    required this.currency,
    this.enableActions = false,
    this.onEditAppointment,
    this.onDeleteAppointment,
  });

  final String title;
  final String emptyMessage;
  final List<Appointment> appointments;
  final List<StaffMember> staff;
  final List<Service> services;
  final DateFormat dateFormat;
  final NumberFormat currency;
  final bool enableActions;
  final Future<void> Function(Appointment appointment)? onEditAppointment;
  final Future<void> Function(Appointment appointment)? onDeleteAppointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showActions =
        enableActions &&
        (onEditAppointment != null || onDeleteAppointment != null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (appointments.isEmpty)
              Text(emptyMessage, style: theme.textTheme.bodyMedium)
            else
              ...appointments.map((appointment) {
                final appointmentServices =
                    appointment.serviceIds
                        .map(
                          (id) => services.firstWhereOrNull(
                            (element) => element.id == id,
                          ),
                        )
                        .whereType<Service>()
                        .toList();
                final operator = staff.firstWhereOrNull(
                  (element) => element.id == appointment.staffId,
                );
                final statusChip = _statusChip(context, appointment.status);
                final amount =
                    appointmentServices.isNotEmpty
                        ? appointmentServices
                            .map((service) => service.price)
                            .fold<double>(0, (value, price) => value + price)
                        : null;
                final packageLabel =
                    appointment.packageId == null
                        ? null
                        : 'Pacchetto #${appointment.packageId}';
                final serviceLabel =
                    appointmentServices.isNotEmpty
                        ? appointmentServices
                            .map((service) => service.name)
                            .join(' + ')
                        : 'Servizio';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    // Allow enough vertical space when actions are visible.
                    isThreeLine: packageLabel != null || showActions,
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(serviceLabel),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateFormat.format(appointment.start)),
                        Text(
                          'Operatore: ${operator?.fullName ?? 'Da assegnare'}',
                        ),
                        if (packageLabel != null) Text(packageLabel),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (amount != null) ...[
                          Text(
                            currency.format(amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.end,
                          children: [
                            statusChip,
                            if (showActions && onEditAppointment != null)
                              IconButton(
                                tooltip: 'Modifica appuntamento',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                onPressed: () async {
                                  await onEditAppointment!(appointment);
                                },
                              ),
                            if (showActions && onDeleteAppointment != null)
                              IconButton(
                                tooltip: 'Elimina appuntamento',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  await onDeleteAppointment!(appointment);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, AppointmentStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case AppointmentStatus.scheduled:
        return Chip(
          label: const Text('Programmato'),
          backgroundColor: scheme.primaryContainer,
        );
      case AppointmentStatus.confirmed:
        return Chip(
          label: const Text('Confermato'),
          backgroundColor: scheme.secondaryContainer,
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
          backgroundColor: scheme.error.withValues(alpha: 0.1),
        );
    }
  }
}

class _PackagesTab extends ConsumerStatefulWidget {
  const _PackagesTab({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends ConsumerState<_PackagesTab> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == widget.clientId,
    );
    if (client == null) {
      return const Center(child: Text('Cliente non trovato.'));
    }
    final purchases = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: data.appointments,
      services: data.services,
      clientId: client.id,
    );
    final active = purchases.where((item) => item.isActive).toList();
    final expired = purchases.where((item) => !item.isActive).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              /*  FilledButton.tonalIcon(
                onPressed: () => _createCustomPackage(context, client),
                icon: const Icon(Icons.design_services_rounded),
                label: const Text('Personalizza pacchetto'),
              ),
              FilledButton.icon(
                onPressed: () => _registerPackagePurchase(context, client),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Aggiungi pacchetto'),
              ),*/
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PackageGroup(
          title: 'Pacchetti in corso',
          items: active,
          onEdit: (purchase) => _editPackage(client, purchase),
          onDelete: (purchase) => _deletePackage(client, purchase),
          onAddDeposit: (purchase) => _addDeposit(client, purchase),
          onDeleteDeposit:
              (purchase, deposit) => _removeDeposit(client, purchase, deposit),
        ),
        const SizedBox(height: 16),
        _PackageGroup(
          title: 'Pacchetti passati',
          items: expired,
          onEdit: (purchase) => _editPackage(client, purchase),
          onAddDeposit: null,
          onDeleteDeposit: null,
        ),
      ],
    );
  }

  Future<void> _registerPackagePurchase(
    BuildContext context,
    Client client,
  ) async {
    final data = ref.read(appDataProvider);
    final packages =
        data.packages.where((pkg) => pkg.salonId == client.salonId).toList();
    if (packages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun pacchetto disponibile per questo salone.'),
        ),
      );
      return;
    }

    final sale = await showAppModalSheet<Sale>(
      context: context,
      builder:
          (ctx) => PackageSaleFormSheet(client: client, packages: packages),
    );
    if (!mounted) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (sale != null) {
      await ref.read(appDataProvider.notifier).upsertSale(sale);
      await _registerDepositCashFlow(client, sale);
    }
  }

  Future<void> _createCustomPackage(BuildContext context, Client client) async {
    final data = ref.read(appDataProvider);
    final salonId = client.salonId;

    var salons = data.salons.where((salon) => salon.id == salonId).toList();
    if (salons.isEmpty) {
      salons = data.salons;
    }

    var services =
        data.services.where((service) => service.salonId == salonId).toList();
    if (services.isEmpty) {
      services = data.services;
    }
    if (salons.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun salone disponibile per creare un pacchetto.'),
        ),
      );
      return;
    }

    if (services.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun servizio disponibile per creare un pacchetto personalizzato.',
          ),
        ),
      );
      return;
    }

    final defaultSalonId = salonId;
    final customPackage = await showAppModalSheet<ServicePackage>(
      context: context,
      builder:
          (ctx) => PackageFormSheet(
            salons: salons,
            services: services,
            defaultSalonId: defaultSalonId,
          ),
    );

    if (customPackage == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final sale = await showAppModalSheet<Sale>(
      context: context,
      builder:
          (ctx) =>
              PackageSaleFormSheet(client: client, packages: [customPackage]),
    );

    if (sale == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await ref.read(appDataProvider.notifier).upsertSale(sale);
    await _registerDepositCashFlow(client, sale);
  }

  Future<void> _registerDepositCashFlow(Client client, Sale sale) async {
    final depositItems = sale.items.where(
      (item) =>
          item.referenceType == SaleReferenceType.package &&
          item.depositAmount > 0,
    );
    double depositTotal = 0;
    final descriptions = <String>[];
    for (final item in depositItems) {
      final amount = item.depositAmount;
      depositTotal += amount;
      if (item.description.isNotEmpty) {
        descriptions.add(item.description);
      }
    }
    final normalized = double.parse(depositTotal.toStringAsFixed(2));
    if (normalized <= 0) {
      return;
    }

    final isPaid = depositItems.any(
      (item) => item.packagePaymentStatus == PackagePaymentStatus.paid,
    );
    final description =
        isPaid
            ? (descriptions.isEmpty
                ? 'Saldato pacchetto cliente ${client.fullName}'
                : 'Saldato pacchetti: ${descriptions.join(', ')}')
            : (descriptions.isEmpty
                ? 'Acconto pacchetto cliente ${client.fullName}'
                : 'Acconto pacchetti: ${descriptions.join(', ')}');
    await _recordCashFlowEntry(
      client: client,
      amount: normalized,
      description: description,
      date: sale.createdAt,
    );
  }

  Future<void> _addDeposit(
    Client client,
    ClientPackagePurchase purchase,
  ) async {
    final outstanding = double.parse(
      purchase.outstandingAmount.toStringAsFixed(2),
    );
    if (outstanding <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il pacchetto è già saldato.')),
      );
      return;
    }

    final deposit = await showAppModalSheet<PackageDeposit>(
      context: context,
      builder: (ctx) => PackageDepositFormSheet(maxAmount: outstanding),
    );

    if (deposit == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    var recordedDeposit = deposit;
    final deposits = [...purchase.item.deposits, recordedDeposit];
    var updatedItem = _updateItemWithDeposits(
      purchase.item,
      deposits,
      purchase.totalAmount,
    );

    final packageLabel = purchase.package?.name ?? purchase.item.description;
    final isSettled =
        updatedItem.packagePaymentStatus == PackagePaymentStatus.paid;

    if (isSettled) {
      recordedDeposit = recordedDeposit.copyWith(note: 'Saldato');
      deposits[deposits.length - 1] = recordedDeposit;
      updatedItem = _updateItemWithDeposits(
        purchase.item,
        deposits,
        purchase.totalAmount,
      );
    }

    await _persistUpdatedItem(purchase, updatedItem);
    await _recordCashFlowEntry(
      client: client,
      amount: recordedDeposit.amount,
      description:
          isSettled
              ? 'Saldato pacchetto $packageLabel'
              : 'Acconto pacchetto $packageLabel',
      date: recordedDeposit.date,
    );
  }

  Future<void> _editPackage(
    Client client,
    ClientPackagePurchase purchase,
  ) async {
    final updatedItem = await showAppModalSheet<SaleItem>(
      context: context,
      builder:
          (ctx) => PackagePurchaseEditSheet(
            initialItem: purchase.item,
            purchaseDate: purchase.sale.createdAt,
            package: purchase.package,
          ),
    );
    if (updatedItem == null) {
      return;
    }

    await _persistUpdatedItem(purchase, updatedItem);
    await _handleDepositAdjustments(client, purchase, updatedItem);
  }

  Future<void> _deletePackage(
    Client client,
    ClientPackagePurchase purchase,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina pacchetto'),
            content: const Text(
              'Vuoi davvero eliminare questo pacchetto? L\'operazione può essere annullata entro pochi secondi.',
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
    if (confirm != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final notifier = ref.read(appDataProvider.notifier);
    final originalSale = purchase.sale;
    final updatedItems = [...originalSale.items]..removeAt(purchase.itemIndex);

    if (updatedItems.isEmpty) {
      await notifier.deleteSale(originalSale.id);
    } else {
      final updatedSale = originalSale.copyWith(
        items: updatedItems,
        total: updatedItems.fold<double>(0, (sum, item) => sum + item.amount),
      );
      await notifier.upsertSale(updatedSale);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pacchetto rimosso'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () async {
            await ref.read(appDataProvider.notifier).upsertSale(originalSale);
          },
        ),
      ),
    );

    final reversal = double.parse(
      purchase.item.depositAmount.toStringAsFixed(2),
    );
    if (reversal > 0.01) {
      await _recordCashFlowEntry(
        client: client,
        amount: -reversal,
        description:
            'Storno completo pacchetto ${purchase.package?.name ?? purchase.item.description}',
      );
    }
  }

  SaleItem _updateItemWithDeposits(
    SaleItem original,
    List<PackageDeposit> deposits,
    double totalAmount,
  ) {
    final depositSum = deposits.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final outstanding = double.parse(
      (totalAmount - depositSum).toStringAsFixed(2),
    );
    final nextStatus =
        outstanding <= 0
            ? PackagePaymentStatus.paid
            : PackagePaymentStatus.deposit;
    return original.copyWith(
      deposits: deposits,
      packagePaymentStatus: nextStatus,
    );
  }

  Future<Sale> _persistUpdatedItem(
    ClientPackagePurchase purchase,
    SaleItem updatedItem,
  ) async {
    final items = [...purchase.sale.items];
    items[purchase.itemIndex] = updatedItem;
    final updatedSale = purchase.sale.copyWith(
      items: items,
      total: items.fold<double>(0, (sum, item) => sum + item.amount),
    );
    await ref.read(appDataProvider.notifier).upsertSale(updatedSale);
    return updatedSale;
  }

  Future<void> _removeDeposit(
    Client client,
    ClientPackagePurchase purchase,
    PackageDeposit deposit,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Storna acconto'),
            content: Text(
              'Vuoi stornare l\'acconto da ${NumberFormat.simpleCurrency(locale: 'it_IT').format(deposit.amount)}? Verrà registrato un movimento negativo in cassa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Conferma'),
              ),
            ],
          ),
    );
    if (confirm != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final remainingDeposits =
        purchase.deposits.where((entry) => entry.id != deposit.id).toList();
    final updatedItem = _updateItemWithDeposits(
      purchase.item,
      remainingDeposits,
      purchase.totalAmount,
    );

    await _persistUpdatedItem(purchase, updatedItem);
    await _recordCashFlowEntry(
      client: client,
      amount: -deposit.amount,
      description:
          'Storno acconto ${purchase.package?.name ?? purchase.item.description}',
      date: DateTime.now(),
    );
  }

  Future<void> _handleDepositAdjustments(
    Client client,
    ClientPackagePurchase originalPurchase,
    SaleItem updatedItem,
  ) async {
    final totalAmount = originalPurchase.totalAmount;
    final originalItem = originalPurchase.item;
    final packageName =
        originalPurchase.package?.name ?? originalItem.description;

    var itemToPersist = updatedItem;
    if (itemToPersist.packagePaymentStatus == PackagePaymentStatus.paid) {
      final outstanding = double.parse(
        (totalAmount - itemToPersist.depositAmount).toStringAsFixed(2),
      );
      if (outstanding > 0.01) {
        final settlementDeposit = PackageDeposit(
          id: const Uuid().v4(),
          amount: outstanding,
          date: DateTime.now(),
          note: 'Saldato',
          paymentMethod:
              itemToPersist.deposits.isNotEmpty
                  ? itemToPersist.deposits.last.paymentMethod
                  : originalPurchase.sale.paymentMethod,
        );
        itemToPersist = _updateItemWithDeposits(itemToPersist, [
          ...itemToPersist.deposits,
          settlementDeposit,
        ], totalAmount);
      } else {
        itemToPersist = _updateItemWithDeposits(
          itemToPersist,
          itemToPersist.deposits,
          totalAmount,
        );
      }
    } else {
      itemToPersist = _updateItemWithDeposits(
        itemToPersist,
        itemToPersist.deposits,
        totalAmount,
      );
    }

    final originalDeposit = originalItem.depositAmount;
    final newDeposit = itemToPersist.depositAmount;
    final deltaDeposit = double.parse(
      (newDeposit - originalDeposit).toStringAsFixed(2),
    );

    await _persistUpdatedItem(originalPurchase, itemToPersist);

    if (deltaDeposit.abs() >= 0.01) {
      final originalStatus = _effectivePaymentStatus(originalItem, totalAmount);
      final newStatus = _effectivePaymentStatus(itemToPersist, totalAmount);

      final description =
          deltaDeposit > 0 &&
                  newStatus == PackagePaymentStatus.paid &&
                  originalStatus != PackagePaymentStatus.paid
              ? 'Saldato pacchetto $packageName'
              : deltaDeposit >= 0
              ? 'Acconto aggiuntivo $packageName'
              : 'Storno acconto $packageName';

      await _recordCashFlowEntry(
        client: client,
        amount: deltaDeposit,
        description: description,
      );
    }
  }

  PackagePaymentStatus _effectivePaymentStatus(
    SaleItem item,
    double totalAmount,
  ) {
    final stored = item.packagePaymentStatus;
    if (stored != null) {
      return stored;
    }
    final deposit = item.depositAmount;
    final outstanding = math.max(totalAmount - deposit, 0);
    if (deposit > 0 && outstanding > 0) {
      return PackagePaymentStatus.deposit;
    }
    return PackagePaymentStatus.paid;
  }

  Future<void> _recordCashFlowEntry({
    required Client client,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final normalized = double.parse(amount.toStringAsFixed(2));
    if (normalized.abs() < 0.01) {
      return;
    }
    final entry = CashFlowEntry(
      id: const Uuid().v4(),
      salonId: client.salonId,
      type: normalized >= 0 ? CashFlowType.income : CashFlowType.expense,
      amount: normalized.abs(),
      date: date ?? DateTime.now(),
      createdAt: DateTime.now(),
      description: description,
      category: 'Acconti',
    );
    await ref.read(appDataProvider.notifier).upsertCashFlowEntry(entry);
  }
}

class _QuotesTab extends ConsumerStatefulWidget {
  const _QuotesTab({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_QuotesTab> createState() => _QuotesTabState();
}

class _QuotesTabState extends ConsumerState<_QuotesTab> {
  final Set<String> _sendingQuotes = <String>{};
  final Set<String> _updatingQuotes = <String>{};
  final Set<String> _deletingQuotes = <String>{};

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == widget.clientId,
    );

    if (client == null) {
      return const Center(child: Text('Cliente non trovato.'));
    }

    final quotes =
        data.quotes.where((quote) => quote.clientId == widget.clientId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == client.salonId,
    );
    if (salon == null) {
      return const Center(
        child: Text('Salone associato al cliente non disponibile.'),
      );
    }
    final services = data.services
        .where((service) => service.salonId == client.salonId)
        .toList(growable: false);
    final salonPackages = data.packages
        .where((pkg) => pkg.salonId == client.salonId)
        .toList(growable: false);
    final inventory = data.inventoryItems
        .where((item) => item.salonId == client.salonId)
        .toList(growable: false);
    final userRole = ref.watch(
      sessionControllerProvider.select((state) => state.role),
    );
    final canSendQuotes =
        userRole == UserRole.admin || userRole == UserRole.staff;

    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed:
                () => _createQuote(
                  context,
                  client: client,
                  salon: salon,
                  existingQuotes: quotes,
                  services: services,
                  packages: salonPackages,
                  inventory: inventory,
                  allSalons: data.salons,
                ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuovo preventivo'),
          ),
        ),
        const SizedBox(height: 16),
        if (quotes.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Non ci sono preventivi registrati.'),
              subtitle: Text('Crea il primo preventivo per questo cliente.'),
            ),
          )
        else
          ...quotes.map(
            (quote) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuoteCard(
                quote: quote,
                currency: currency,
                dateFormat: dateFormat,
                isSending: _sendingQuotes.contains(quote.id),
                isUpdating: _updatingQuotes.contains(quote.id),
                isDeleting: _deletingQuotes.contains(quote.id),
                onEdit:
                    quote.isEditable
                        ? () => _editQuote(
                          context,
                          quote: quote,
                          client: client,
                          salon: salon,
                          existingQuotes: quotes,
                          services: services,
                          packages: salonPackages,
                          inventory: inventory,
                          allSalons: data.salons,
                        )
                        : null,
                onSend:
                    quote.status == QuoteStatus.accepted || !canSendQuotes
                        ? null
                        : () => _sendQuote(
                          context,
                          quote: quote,
                          client: client,
                          currency: currency,
                        ),
                onMarkSent:
                    quote.status == QuoteStatus.draft
                        ? () => _markQuoteSentManual(context, quote)
                        : null,
                onAccept:
                    quote.status == QuoteStatus.accepted
                        ? null
                        : () => _acceptQuote(context, quote),
                onDecline:
                    (quote.status == QuoteStatus.declined ||
                            quote.status == QuoteStatus.accepted)
                        ? null
                        : () => _declineQuote(context, quote),
                onDelete: () => _deleteQuote(context, quote),
              ),
            ),
          ),
      ],
    );
  }

  List<MessageChannel> _preferredChannels(ChannelPreferences preferences) {
    final channels = <MessageChannel>[];
    if (preferences.email) {
      channels.add(MessageChannel.email);
    }
    if (preferences.whatsapp) {
      channels.add(MessageChannel.whatsapp);
    }
    if (preferences.sms) {
      channels.add(MessageChannel.sms);
    }
    if (preferences.push) {
      channels.add(MessageChannel.push);
    }
    return channels;
  }

  String _quoteLabel(Quote quote) {
    final number = quote.number;
    if (number != null && number.isNotEmpty) {
      return number;
    }
    return '#${quote.id.substring(0, 6)}';
  }

  Future<void> _createQuote(
    BuildContext context, {
    required Client client,
    required Salon salon,
    required List<Quote> existingQuotes,
    required List<Service> services,
    required List<ServicePackage> packages,
    required List<InventoryItem> inventory,
    required List<Salon> allSalons,
  }) async {
    final quote = await showAppModalSheet<Quote>(
      context: context,
      builder:
          (ctx) => QuoteFormSheet(
            client: client,
            salon: salon,
            existingQuotes: existingQuotes,
            services: services,
            packages: packages,
            inventoryItems: inventory,
            salons: allSalons,
          ),
    );
    if (quote == null) {
      return;
    }
    try {
      await ref.read(appDataProvider.notifier).upsertQuote(quote);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preventivo ${_quoteLabel(quote)} salvato.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $error')),
      );
    }
  }

  Future<void> _editQuote(
    BuildContext context, {
    required Quote quote,
    required Client client,
    required Salon salon,
    required List<Quote> existingQuotes,
    required List<Service> services,
    required List<ServicePackage> packages,
    required List<InventoryItem> inventory,
    required List<Salon> allSalons,
  }) async {
    final otherQuotes =
        existingQuotes.where((item) => item.id != quote.id).toList();
    final updated = await showAppModalSheet<Quote>(
      context: context,
      builder:
          (ctx) => QuoteFormSheet(
            client: client,
            salon: salon,
            existingQuotes: otherQuotes,
            services: services,
            packages: packages,
            inventoryItems: inventory,
            salons: allSalons,
            initial: quote,
          ),
    );
    if (updated == null) {
      return;
    }
    try {
      await ref.read(appDataProvider.notifier).upsertQuote(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preventivo ${_quoteLabel(updated)} aggiornato.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento: $error')),
      );
    }
  }

  Future<void> _deleteQuote(BuildContext context, Quote quote) async {
    if (_deletingQuotes.contains(quote.id)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina preventivo'),
            content: Text(
              'Vuoi eliminare in modo permanente il preventivo ${_quoteLabel(quote)}? ',
            ),
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

    setState(() => _deletingQuotes.add(quote.id));
    try {
      await ref.read(appDataProvider.notifier).deleteQuote(quote.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preventivo ${_quoteLabel(quote)} eliminato.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingQuotes.remove(quote.id));
      }
    }
  }

  Future<void> _sendQuote(
    BuildContext context, {
    required Quote quote,
    required Client client,
    required NumberFormat currency,
  }) async {
    if (_sendingQuotes.contains(quote.id)) {
      return;
    }
    if (!_canCurrentUserSendQuotes()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non hai i permessi necessari per inviare preventivi.'),
        ),
      );
      return;
    }
    final preferred = _preferredChannels(client.channelPreferences);
    final available =
        preferred.isEmpty ? MessageChannel.values.toList() : preferred;
    final defaultSelection =
        quote.sentChannels.isNotEmpty ? quote.sentChannels : available;

    final selected = await _pickChannels(
      context: context,
      available: available,
      initiallySelected: defaultSelection,
    );
    if (selected == null || selected.isEmpty) {
      return;
    }

    setState(() => _sendingQuotes.add(quote.id));
    try {
      final pdfStoragePath = await _generateAndShareQuotePdf(
        context: context,
        quote: quote,
        client: client,
        currency: currency,
        channels: selected,
      );

      await ref
          .read(appDataProvider.notifier)
          .markQuoteSent(
            quote.id,
            viaChannels: selected,
            pdfStoragePath: pdfStoragePath,
          );
      if (!mounted) {
        return;
      }
      final channelsLabel = selected.map(_QuoteCard.labelForChannel).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preventivo inviato via $channelsLabel.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'invio: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingQuotes.remove(quote.id));
      }
    }
  }

  Future<void> _acceptQuote(BuildContext context, Quote quote) async {
    if (_updatingQuotes.contains(quote.id)) {
      return;
    }
    setState(() => _updatingQuotes.add(quote.id));
    try {
      await ref.read(appDataProvider.notifier).acceptQuote(quote.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preventivo ${_quoteLabel(quote)} accettato: registrata la vendita.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'aggiornamento: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingQuotes.remove(quote.id));
      }
    }
  }

  Future<void> _declineQuote(BuildContext context, Quote quote) async {
    if (_updatingQuotes.contains(quote.id)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rifiuta preventivo'),
            content: Text(
              'Vuoi segnare il preventivo ${_quoteLabel(quote)} come rifiutato?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Conferma'),
              ),
            ],
          ),
    );
    if (confirm != true) {
      return;
    }

    setState(() => _updatingQuotes.add(quote.id));
    try {
      await ref.read(appDataProvider.notifier).declineQuote(quote.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preventivo ${_quoteLabel(quote)} rifiutato.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'aggiornamento: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingQuotes.remove(quote.id));
      }
    }
  }

  Future<void> _markQuoteSentManual(BuildContext context, Quote quote) async {
    if (_updatingQuotes.contains(quote.id)) {
      return;
    }
    setState(() => _updatingQuotes.add(quote.id));
    try {
      await ref.read(appDataProvider.notifier).markQuoteSentManual(quote.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preventivo ${_quoteLabel(quote)} impostato su "Inviato".',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'aggiornamento: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingQuotes.remove(quote.id));
      }
    }
  }

  Future<List<MessageChannel>?> _pickChannels({
    required BuildContext context,
    required List<MessageChannel> available,
    required List<MessageChannel> initiallySelected,
  }) {
    final effectiveAvailable =
        available.isEmpty ? MessageChannel.values.toList() : available;
    final initialSelection =
        initiallySelected
            .where((channel) => effectiveAvailable.contains(channel))
            .toSet();

    return showAppModalSheet<List<MessageChannel>>(
      context: context,
      builder: (ctx) {
        final selections = Set<MessageChannel>.from(initialSelection);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invia preventivo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Seleziona i canali preferenziali:'),
                    const SizedBox(height: 8),
                    ...effectiveAvailable.map(
                      (channel) => CheckboxListTile(
                        value: selections.contains(channel),
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              selections.add(channel);
                            } else {
                              selections.remove(channel);
                            }
                          });
                        },
                        title: Text(_QuoteCard.labelForChannel(channel)),
                        secondary: Icon(_QuoteCard.iconForChannel(channel)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Annulla'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed:
                              selections.isEmpty
                                  ? null
                                  : () => Navigator.of(context).pop(
                                    List<MessageChannel>.unmodifiable(
                                      selections,
                                    ),
                                  ),
                          child: const Text('Invia'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _generateAndShareQuotePdf({
    required BuildContext context,
    required Quote quote,
    required Client client,
    required NumberFormat currency,
    required List<MessageChannel> channels,
  }) async {
    if (kIsWeb) {
      throw StateError(
        'La generazione e la condivisione del PDF è disponibile solo da app mobile o desktop.',
      );
    }

    final shareableChannels = channels.where(_supportsManualShare).toSet();
    final unsupportedChannels =
        channels.where((channel) => !_supportsManualShare(channel)).toSet();

    if (unsupportedChannels.isNotEmpty && mounted) {
      final unsupportedLabel = unsupportedChannels
          .map(_QuoteCard.labelForChannel)
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'I canali $unsupportedLabel non sono ancora gestiti automaticamente. '
            'Generiamo comunque il PDF per l\'invio manuale.',
          ),
        ),
      );
    }

    if (shareableChannels.isEmpty) {
      throw StateError(
        'Seleziona almeno un canale supportato (Email, WhatsApp o SMS) per condividere il PDF.',
      );
    }

    final data = ref.read(appDataProvider);
    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == quote.salonId,
    );

    final pdfBytes = await _buildQuotePdf(
      quote: quote,
      client: client,
      salon: salon,
      currency: currency,
    );

    final storageService = ref.read(firebaseStorageServiceProvider);
    final fileName = _buildQuoteFileName(quote);
    final uploadResult = await storageService.uploadQuotePdf(
      salonId: quote.salonId,
      quoteId: quote.id,
      clientId: client.id,
      quoteNumber: quote.number,
      fileName: fileName,
      data: pdfBytes,
    );

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(pdfBytes, flush: true);

    final shareMessage = _buildQuoteShareMessage(
      client: client,
      quote: quote,
      currency: currency,
      salon: salon,
      downloadUrl: uploadResult.downloadUrl,
      selectedChannels: shareableChannels.toList(growable: false),
    );

    final shareResult = await Share.shareXFiles(
      [XFile(tempFile.path, mimeType: 'application/pdf', name: fileName)],
      subject: 'Preventivo ${quote.number ?? _quoteLabel(quote)}',
      text: shareMessage,
    );

    if (shareResult.status == ShareResultStatus.unavailable) {
      throw StateError('Nessuna app disponibile per condividere il PDF.');
    }

    return uploadResult.storagePath;
  }

  bool _supportsManualShare(MessageChannel channel) {
    switch (channel) {
      case MessageChannel.email:
      case MessageChannel.whatsapp:
      case MessageChannel.sms:
        return true;
      case MessageChannel.push:
        return false;
    }
  }

  bool _canCurrentUserSendQuotes() {
    final role = ref.read(sessionControllerProvider).role;
    return role == UserRole.admin || role == UserRole.staff;
  }

  String _sanitizePdfText(String? input) {
    if (input == null || input.isEmpty) {
      return '';
    }
    const replacements = {
      'à': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
      'À': 'A',
      'È': 'E',
      'É': 'E',
      'Ì': 'I',
      'Ò': 'O',
      'Ù': 'U',
      'ç': 'c',
      'Ç': 'C',
      'ß': 'ss',
      'œ': 'oe',
      'Œ': 'OE',
      '’': "'",
      '‘': "'",
      '‚': "'",
      '‛': "'",
      '“': '"',
      '”': '"',
      '„': '"',
      '«': '"',
      '»': '"',
      '€': 'EUR',
    };
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final replacement = replacements[char];
      if (replacement != null) {
        buffer.write(replacement);
      } else if ((rune >= 32 && rune <= 126) || rune == 10 || rune == 13) {
        buffer.write(char);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }

  Future<Uint8List> _buildQuotePdf({
    required Quote quote,
    required Client client,
    required Salon? salon,
    required NumberFormat currency,
  }) async {
    final document = pw.Document();
    final label = quote.number ?? _quoteLabel(quote);
    final dateFormat = DateFormat('dd MMMM yyyy', 'it_IT');
    final dateTimeFormat = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    final validUntil = quote.validUntil;

    final currencySymbol =
        currency.currencySymbol == '€' ? 'EUR' : currency.currencySymbol;
    final sanitizedSalonName = _sanitizePdfText(salon?.name ?? 'Preventivo');
    final sanitizedQuoteTitle =
        label.isEmpty
            ? _sanitizePdfText('Preventivo')
            : _sanitizePdfText('Preventivo $label');
    final sanitizedClientName = _sanitizePdfText(client.fullName);
    final sanitizedClientPhone = _sanitizePdfText(client.phone);
    final sanitizedClientEmail = _sanitizePdfText(client.email);
    final sanitizedCreatedAt = _sanitizePdfText(
      'Creato il ${dateTimeFormat.format(quote.createdAt)}',
    );
    final sanitizedValidUntil =
        validUntil == null
            ? null
            : _sanitizePdfText(
              'Valido fino al ${dateFormat.format(validUntil)}',
            );
    final sanitizedSentAt =
        quote.sentAt == null
            ? null
            : _sanitizePdfText(
              'Ultimo invio ${dateTimeFormat.format(quote.sentAt!)}',
            );
    final itemsTable = <List<String>>[
      [
        '#',
        _sanitizePdfText('Descrizione'),
        _sanitizePdfText('Qta'),
        _sanitizePdfText('Prezzo unit.'),
        _sanitizePdfText('Totale'),
      ],
      ...quote.items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        return [
          index.toString(),
          _sanitizePdfText(item.description),
          _sanitizePdfText(_QuoteCard._formatQuantity(item.quantity)),
          _sanitizePdfText(
            '${currencySymbol} ${item.unitPrice.toStringAsFixed(2)}',
          ),
          _sanitizePdfText(
            '${currencySymbol} ${item.total.toStringAsFixed(2)}',
          ),
        ];
      }),
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sanitizedSalonName,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      sanitizedQuoteTitle,
                      style: pw.TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _sanitizePdfText('Cliente'),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(sanitizedClientName),
                        pw.Text(sanitizedClientPhone),
                        if (client.email != null && client.email!.isNotEmpty)
                          pw.Text(sanitizedClientEmail),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _sanitizePdfText('Dettagli'),
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(sanitizedCreatedAt),
                        if (sanitizedValidUntil != null)
                          pw.Text(sanitizedValidUntil),
                        if (sanitizedSentAt != null) pw.Text(sanitizedSentAt),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Table.fromTextArray(
                data: itemsTable,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                cellHeight: 24,
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(0.9),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                },
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey600,
                        width: 0.6,
                      ),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              _sanitizePdfText('Totale'),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              _sanitizePdfText(
                                '${currencySymbol} ${quote.total.toStringAsFixed(2)}',
                              ),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (quote.notes?.isNotEmpty == true) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  _sanitizePdfText('Note'),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(_sanitizePdfText(quote.notes)),
              ],
            ],
      ),
    );

    return await document.save();
  }

  String _buildQuoteFileName(Quote quote) {
    final raw = quote.number ?? _quoteLabel(quote);
    final sanitized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final fallback = quote.id.length > 8 ? quote.id.substring(0, 8) : quote.id;
    return 'preventivo-${sanitized.isEmpty ? fallback : sanitized}.pdf';
  }

  String _buildQuoteShareMessage({
    required Client client,
    required Quote quote,
    required NumberFormat currency,
    Salon? salon,
    String? downloadUrl,
    required List<MessageChannel> selectedChannels,
  }) {
    final buffer = StringBuffer();
    final label = quote.number ?? _quoteLabel(quote);
    final currencySymbol =
        currency.currencySymbol == '€' ? 'EUR' : currency.currencySymbol;
    final validUntil = quote.validUntil;
    final salonName = _sanitizePdfText(salon?.name ?? 'Civiapp');
    final sanitizedFirstName = _sanitizePdfText(client.firstName);
    buffer.writeln('Ciao $sanitizedFirstName,');
    buffer.writeln();
    buffer.writeln(
      'ti inviamo il preventivo $label del salone $salonName '
      'per un totale di $currencySymbol ${quote.total.toStringAsFixed(2)}.',
    );
    if (validUntil != null) {
      final format = DateFormat('dd MMMM yyyy', 'it_IT');
      buffer.writeln(
        'Validita fino al ${_sanitizePdfText(format.format(validUntil))}.',
      );
    }
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      buffer.writeln('Puoi consultarlo anche online: $downloadUrl');
    }
    buffer.writeln();
    buffer.writeln(
      'Canali scelti: ${selectedChannels.map(_QuoteCard.labelForChannel).join(', ')}.',
    );
    buffer.writeln();
    buffer.writeln('Grazie e a presto!');
    return buffer.toString();
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.currency,
    required this.dateFormat,
    required this.isSending,
    required this.isUpdating,
    required this.isDeleting,
    this.onEdit,
    this.onSend,
    this.onMarkSent,
    this.onAccept,
    this.onDecline,
    this.onDelete,
  });

  final Quote quote;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final bool isSending;
  final bool isUpdating;
  final bool isDeleting;
  final VoidCallback? onEdit;
  final VoidCallback? onSend;
  final VoidCallback? onMarkSent;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onDelete;

  static String labelForChannel(MessageChannel channel) {
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

  static IconData iconForChannel(MessageChannel channel) {
    switch (channel) {
      case MessageChannel.push:
        return Icons.notifications_active_rounded;
      case MessageChannel.whatsapp:
        return Icons.chat_rounded;
      case MessageChannel.email:
        return Icons.email_rounded;
      case MessageChannel.sms:
        return Icons.sms_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStatus =
        quote.isExpired && quote.status != QuoteStatus.accepted
            ? QuoteStatus.expired
            : quote.status;
    final statusColors = _QuoteStatusColors.resolve(effectiveStatus, theme);

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
                    quote.title?.isNotEmpty == true
                        ? quote.title!
                        : 'Preventivo ${quote.number ?? ''}'.trim(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColors.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    effectiveStatus.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (quote.number != null && quote.number!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Numero: ${quote.number}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Creato il ${dateFormat.format(quote.createdAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (quote.sentAt != null)
              Text(
                'Inviato il ${dateFormat.format(quote.sentAt!)}',
                style: theme.textTheme.bodyMedium,
              ),
            if (quote.validUntil != null)
              Text(
                'Valido fino al ${dateFormat.format(quote.validUntil!)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      quote.isExpired
                          ? theme.colorScheme.error
                          : theme.textTheme.bodyMedium?.color,
                ),
              ),
            if (quote.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(quote.notes!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            for (final item in quote.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_formatQuantity(item.quantity)} × ${item.description} — '
                  '${currency.format(item.total)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Totale: ${currency.format(quote.total)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (quote.saleId != null && quote.saleId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Vendita collegata: ${quote.saleId}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (quote.stripePaymentIntentId != null &&
                quote.stripePaymentIntentId!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'PaymentIntent: ${quote.stripePaymentIntentId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (quote.sentChannels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    quote.sentChannels
                        .map(
                          (channel) => Chip(
                            avatar: Icon(iconForChannel(channel), size: 16),
                            label: Text(labelForChannel(channel)),
                          ),
                        )
                        .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (onEdit != null)
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Modifica'),
                  ),
                if (onMarkSent != null)
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : onMarkSent,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Segna inviato'),
                  ),
                if (onSend != null)
                  FilledButton.tonalIcon(
                    onPressed: _isBusy ? null : onSend,
                    icon:
                        isSending
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Invia PDF'),
                  ),
                if (onAccept != null)
                  FilledButton.icon(
                    onPressed: _isBusy ? null : onAccept,
                    icon:
                        isUpdating
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_rounded),
                    label: const Text('Accetta'),
                  ),
                if (onDecline != null)
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : onDecline,
                    icon:
                        isUpdating
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.close_rounded),
                    label: const Text('Rifiuta'),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: (_isBusy || isDeleting) ? null : onDelete,
                    icon:
                        isDeleting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_outline_rounded),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    label: const Text('Elimina'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isBusy => isSending || isUpdating || isDeleting;

  static String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }
}

class _QuoteStatusColors {
  const _QuoteStatusColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  static _QuoteStatusColors resolve(QuoteStatus status, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (status) {
      case QuoteStatus.draft:
        return _QuoteStatusColors(
          background: scheme.surfaceVariant,
          foreground: scheme.onSurfaceVariant,
        );
      case QuoteStatus.sent:
        return _QuoteStatusColors(
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        );
      case QuoteStatus.accepted:
        return _QuoteStatusColors(
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        );
      case QuoteStatus.declined:
        return _QuoteStatusColors(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        );
      case QuoteStatus.expired:
        return _QuoteStatusColors(
          background: scheme.tertiaryContainer,
          foreground: scheme.onTertiaryContainer,
        );
    }
  }
}

class _BillingTab extends ConsumerWidget {
  const _BillingTab({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == clientId,
    );

    if (client == null) {
      return const Center(child: Text('Cliente non trovato.'));
    }

    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    final sales =
        data.sales.where((sale) => sale.clientId == clientId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalPaid = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
    int resolveLoyaltyValue(int? stored, int aggregated) {
      if (stored == null) {
        return aggregated;
      }
      if (stored == 0 && aggregated != 0) {
        return aggregated;
      }
      return stored;
    }

    final aggregatedEarned = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.resolvedEarnedPoints,
    );
    final aggregatedRedeemed = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.redeemedPoints,
    );
    final totalEarnedPoints = resolveLoyaltyValue(
      client.loyaltyTotalEarned,
      aggregatedEarned,
    );
    final totalRedeemedPoints = resolveLoyaltyValue(
      client.loyaltyTotalRedeemed,
      aggregatedRedeemed,
    );
    final initialPoints = client.loyaltyInitialPoints;
    final computedSpendable =
        initialPoints + totalEarnedPoints - totalRedeemedPoints;
    final loyaltySpendable = _resolveSpendableBalance(
      stored: client.loyaltyPoints,
      computed: computedSpendable,
    );

    final packages = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: data.appointments,
      services: data.services,
      clientId: clientId,
    );

    final outstandingPackages =
        packages.where((purchase) => purchase.outstandingAmount > 0).toList()
          ..sort((a, b) => b.outstandingAmount.compareTo(a.outstandingAmount));

    final outstandingSales = <_OutstandingSale>[];
    for (final sale in sales) {
      if (sale.paymentStatus != SalePaymentStatus.deposit ||
          sale.outstandingAmount <= 0) {
        continue;
      }
      final packageOutstanding = _packageOutstandingAmount(sale);
      final residual = _normalizeCurrency(
        sale.outstandingAmount - packageOutstanding,
      );
      if (residual > 0.009) {
        outstandingSales.add(
          _OutstandingSale(sale: sale, outstanding: residual),
        );
      }
    }
    outstandingSales.sort(
      (a, b) => b.sale.createdAt.compareTo(a.sale.createdAt),
    );

    final openTickets =
        data.paymentTickets
            .where(
              (ticket) =>
                  ticket.clientId == clientId &&
                  ticket.status == PaymentTicketStatus.open,
            )
            .toList()
          ..sort((a, b) => a.appointmentStart.compareTo(b.appointmentStart));

    final outstandingPackagesTotal = outstandingPackages.fold<double>(
      0,
      (sum, purchase) => sum + purchase.outstandingAmount,
    );

    final outstandingSalesTotal = outstandingSales.fold<double>(
      0,
      (sum, entry) => sum + entry.outstanding,
    );

    final outstandingTicketsTotal = openTickets.fold<double>(
      0,
      (sum, ticket) => sum + (ticket.expectedTotal ?? 0),
    );

    final outstandingTotal =
        outstandingPackagesTotal +
        outstandingSalesTotal +
        outstandingTicketsTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed:
                () => _registerSale(
                  context: context,
                  ref: ref,
                  client: client,
                  salons: data.salons,
                  clients: data.clients,
                  staff: data.staff,
                  services: data.services,
                  packages: data.packages,
                  inventory: data.inventoryItems,
                  sales: data.sales,
                ),
            icon: const Icon(Icons.point_of_sale_rounded),
            label: const Text('Registra vendita'),
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryCard(
          theme,
          currency,
          totalPaid: totalPaid,
          outstandingTotal: outstandingTotal,
          loyaltyInitial: initialPoints,
          loyaltySpendable: loyaltySpendable,
          loyaltyEarned: totalEarnedPoints,
          loyaltyRedeemed: totalRedeemedPoints,
        ),
        const SizedBox(height: 16),
        _buildOutstandingCard(
          context,
          ref,
          theme,
          currency,
          dateFormat,
          dateTimeFormat,
          outstandingSales,
          outstandingPackages,
          openTickets,
          data.services,
          data.staff,
          data.clients,
        ),
        const SizedBox(height: 16),
        _buildHistoryCard(context, ref, theme, currency, dateTimeFormat, sales),
      ],
    );
  }

  Future<void> _registerSale({
    required BuildContext context,
    required WidgetRef ref,
    required Client client,
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
    required List<ServicePackage> packages,
    required List<InventoryItem> inventory,
    required List<Sale> sales,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea un salone prima di registrare una vendita.'),
        ),
      );
      return;
    }

    final sale = await showAppModalSheet<Sale>(
      context: context,
      builder:
          (ctx) => SaleFormSheet(
            salons: salons,
            clients: clients,
            staff: staff,
            services: services,
            packages: packages,
            inventoryItems: inventory,
            sales: sales,
            defaultSalonId: client.salonId,
            initialClientId: client.id,
          ),
    );

    if (sale == null) {
      return;
    }

    final store = ref.read(appDataProvider.notifier);
    await store.upsertSale(sale);
    await _recordSaleCashFlow(ref: ref, sale: sale, clients: clients);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vendita registrata.')));
  }

  Future<void> _recordSaleCashFlow({
    required WidgetRef ref,
    required Sale sale,
    required List<Client> clients,
  }) async {
    final cashPortion =
        sale.paymentStatus == SalePaymentStatus.deposit
            ? sale.paidAmount
            : sale.total;
    final normalized = _normalizeCurrency(cashPortion);
    if (normalized <= 0) {
      return;
    }
    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final description =
        sale.paymentStatus == SalePaymentStatus.deposit
            ? 'Acconto vendita a $clientName'
            : 'Vendita a $clientName';
    await _recordCashFlowEntry(
      ref: ref,
      sale: sale,
      amount: normalized,
      description: description,
      date: sale.createdAt,
    );
  }

  double _packageOutstandingAmount(Sale sale) {
    var total = 0.0;
    for (final item in sale.items) {
      if (item.referenceType != SaleReferenceType.package) {
        continue;
      }
      final outstanding = item.amount - item.depositAmount;
      if (outstanding > 0) {
        total += outstanding;
      }
    }
    return _normalizeCurrency(total);
  }

  double _normalizeCurrency(double value) {
    if (value <= 0) {
      return 0;
    }
    return double.parse(value.toStringAsFixed(2));
  }

  List<SaleItem> _applyPackagePaymentDistribution({
    required List<SaleItem> items,
    required SalePaymentStatus paymentStatus,
    required double paidAmount,
  }) {
    if (!items.any((item) => item.referenceType == SaleReferenceType.package)) {
      return items;
    }

    final updated = <SaleItem>[];
    if (paymentStatus == SalePaymentStatus.deposit) {
      var remaining = _normalizeCurrency(paidAmount);
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          final lineTotal = item.amount;
          final applied = _normalizeCurrency(
            remaining <= 0
                ? 0
                : remaining >= lineTotal
                ? lineTotal
                : remaining,
          );
          remaining = _normalizeCurrency(remaining - applied);
          final packageStatus =
              applied >= lineTotal - 0.009
                  ? PackagePaymentStatus.paid
                  : PackagePaymentStatus.deposit;
          updated.add(
            item.copyWith(
              depositAmount: applied,
              packagePaymentStatus: packageStatus,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    } else {
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          updated.add(
            item.copyWith(
              depositAmount: _normalizeCurrency(item.amount),
              packagePaymentStatus: PackagePaymentStatus.paid,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    }
    return updated;
  }

  List<_SaleDepositEntry> _collectSaleDeposits(Sale sale) {
    final entries = <_SaleDepositEntry>[];
    if (sale.paymentHistory.isNotEmpty) {
      for (final movement in sale.paymentHistory) {
        if (movement.amount <= 0) {
          continue;
        }
        entries.add(
          _SaleDepositEntry(
            id: movement.id,
            amount: _normalizeCurrency(movement.amount),
            date: movement.date,
            paymentMethod: movement.paymentMethod,
            note: movement.note,
            recordedBy: movement.recordedBy,
            movementType: movement.type,
          ),
        );
      }
    } else {
      for (final item in sale.items) {
        if (item.deposits.isEmpty) {
          continue;
        }
        final itemLabel =
            item.description.trim().isEmpty ? null : item.description.trim();
        for (final deposit in item.deposits) {
          if (deposit.amount <= 0) {
            continue;
          }
          entries.add(
            _SaleDepositEntry(
              id: deposit.id,
              amount: _normalizeCurrency(deposit.amount),
              date: deposit.date,
              paymentMethod: deposit.paymentMethod,
              note: deposit.note,
              itemDescription: itemLabel,
            ),
          );
        }
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  List<PackageDeposit> _alignDepositsToAmount(
    List<PackageDeposit> deposits,
    double targetAmount,
  ) {
    final normalizedTarget = _normalizeCurrency(targetAmount);
    if (normalizedTarget <= 0 || deposits.isEmpty) {
      return normalizedTarget <= 0 ? const <PackageDeposit>[] : deposits;
    }

    final sorted = [...deposits]..sort((a, b) => a.date.compareTo(b.date));
    final result = <PackageDeposit>[];
    var remaining = normalizedTarget;

    for (final deposit in sorted) {
      if (remaining <= 0.009) {
        break;
      }
      final amount = _normalizeCurrency(deposit.amount);
      if (amount <= remaining + 0.009) {
        result.add(deposit.copyWith(amount: amount));
        remaining = _normalizeCurrency(remaining - amount);
      } else {
        result.add(deposit.copyWith(amount: remaining));
        remaining = 0;
        break;
      }
    }

    if (remaining > 0.009 && result.isNotEmpty) {
      final lastIndex = result.length - 1;
      final last = result[lastIndex];
      result[lastIndex] = last.copyWith(
        amount: _normalizeCurrency(last.amount + remaining),
      );
    }

    return result;
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    NumberFormat currency, {
    required double totalPaid,
    required double outstandingTotal,
    required int loyaltyInitial,
    required int loyaltySpendable,
    required int loyaltyEarned,
    required int loyaltyRedeemed,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riepilogo incassi', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Incassato',
                    value: currency.format(totalPaid),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Da incassare',
                    value: currency.format(outstandingTotal),
                    emphasize: outstandingTotal > 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Saldo utilizzabile',
                    value: '$loyaltySpendable pt',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Punti iniziali',
                    value: '$loyaltyInitial pt',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Punti accumulati',
                    value: '$loyaltyEarned pt',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Punti utilizzati',
                    value: '$loyaltyRedeemed pt',
                    emphasize: loyaltyRedeemed > 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _resolveSpendableBalance({required int stored, required int computed}) {
    final normalizedStored = stored < 0 ? 0 : stored;
    final normalizedComputed = computed < 0 ? 0 : computed;
    if (normalizedStored == normalizedComputed) {
      return normalizedStored;
    }
    if (normalizedComputed == 0 && normalizedStored != 0) {
      return normalizedStored;
    }
    return normalizedComputed;
  }

  Widget _buildSummaryValue(
    ThemeData theme, {
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    final baseStyle =
        theme.textTheme.titleLarge ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
    final valueStyle =
        emphasize
            ? baseStyle.copyWith(color: theme.colorScheme.error)
            : baseStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildOutstandingCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateFormat,
    DateFormat dateTimeFormat,
    List<_OutstandingSale> outstandingSales,
    List<ClientPackagePurchase> outstandingPackages,
    List<PaymentTicket> openTickets,
    List<Service> services,
    List<StaffMember> staff,
    List<Client> clients,
  ) {
    if (openTickets.isEmpty &&
        outstandingPackages.isEmpty &&
        outstandingSales.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.verified_rounded),
          title: Text('Nessun pagamento in sospeso'),
        ),
      );
    }

    final content = <Widget>[
      Text('Pagamenti da saldare', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
    ];

    var hasSection = false;

    void addSectionSpacingIfNeeded() {
      if (!hasSection) {
        hasSection = true;
        return;
      }
      content.add(const SizedBox(height: 16));
      content.add(const Divider());
      content.add(const SizedBox(height: 16));
    }

    if (outstandingSales.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(
        Text('Vendite con acconto', style: theme.textTheme.titleSmall),
      );
      content.add(const SizedBox(height: 8));
      for (var index = 0; index < outstandingSales.length; index++) {
        final outstandingSale = outstandingSales[index];
        content.add(
          _buildOutstandingSaleTile(
            theme,
            currency,
            dateTimeFormat,
            staff,
            outstandingSale,
            onTap:
                () => _editSalePayment(
                  context: context,
                  ref: ref,
                  sale: outstandingSale.sale,
                  clients: clients,
                  staff: staff,
                ),
          ),
        );
        if (index < outstandingSales.length - 1) {
          content.add(const SizedBox(height: 12));
        }
      }
    }

    if (openTickets.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(Text('Ticket aperti', style: theme.textTheme.titleSmall));
      content.add(const SizedBox(height: 8));
      for (var index = 0; index < openTickets.length; index++) {
        final ticket = openTickets[index];
        content.add(
          _buildTicketTile(
            theme,
            currency,
            dateTimeFormat,
            services,
            staff,
            ticket,
            onTap:
                () => _openTicketSale(
                  context: context,
                  ref: ref,
                  ticket: ticket,
                  clients: clients,
                  staff: staff,
                  services: services,
                ),
          ),
        );
        if (index < openTickets.length - 1) {
          content.add(const SizedBox(height: 12));
        }
      }
    }

    if (outstandingPackages.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(
        Text('Pacchetti con saldo residuo', style: theme.textTheme.titleSmall),
      );
      content.add(const SizedBox(height: 8));
      for (var index = 0; index < outstandingPackages.length; index++) {
        final purchase = outstandingPackages[index];
        content.add(
          _buildOutstandingPackageTile(
            theme,
            currency,
            dateFormat,
            purchase,
            onTap:
                () => _editSalePayment(
                  context: context,
                  ref: ref,
                  sale: purchase.sale,
                  clients: clients,
                  staff: staff,
                ),
          ),
        );
        if (index < outstandingPackages.length - 1) {
          content.add(const SizedBox(height: 12));
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      ),
    );
  }

  Future<void> _editSalePayment({
    required BuildContext context,
    required WidgetRef ref,
    required Sale sale,
    required List<Client> clients,
    required List<StaffMember> staff,
  }) async {
    final outstanding = _normalizeCurrency(sale.outstandingAmount);
    if (outstanding <= 0) {
      return;
    }

    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final staffOptions =
        staff.where((member) => member.salonId == sale.salonId).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final saleStaffName =
        staffOptions
            .firstWhereOrNull((member) => member.id == sale.staffId)
            ?.fullName ??
        staff.firstWhereOrNull((member) => member.id == sale.staffId)?.fullName;
    final result = await showAppModalSheet<OutstandingPaymentResult>(
      context: context,
      builder:
          (ctx) => OutstandingPaymentFormSheet(
            title: 'Registra incasso',
            subtitle: 'Residuo disponibile: ${currency.format(outstanding)}',
            outstandingAmount: outstanding,
            initialAmount: outstanding,
            staff: staffOptions,
            initialStaffId: sale.staffId,
            staffName: saleStaffName,
            currency: currency,
          ),
    );

    if (result == null) {
      return;
    }

    final additional = _normalizeCurrency(result.amount);
    if (additional <= 0) {
      return;
    }

    final timestamp = DateTime.now();
    final nextPaidAmount = _normalizeCurrency(sale.paidAmount + additional);
    final nextStatus =
        nextPaidAmount >= sale.total - 0.009
            ? SalePaymentStatus.paid
            : SalePaymentStatus.deposit;

    final updatedItems = _applyPackagePaymentDistribution(
      items: sale.items,
      paymentStatus: nextStatus,
      paidAmount: nextPaidAmount,
    );

    final enrichedItems = <SaleItem>[];
    for (var index = 0; index < updatedItems.length; index++) {
      final updatedItem = updatedItems[index];
      final originalItem = sale.items[index];
      if (updatedItem.referenceType != SaleReferenceType.package) {
        enrichedItems.add(updatedItem);
        continue;
      }

      final previousDeposit = _normalizeCurrency(originalItem.depositAmount);
      final currentDeposit = _normalizeCurrency(updatedItem.depositAmount);
      final delta = _normalizeCurrency(currentDeposit - previousDeposit);
      if (delta <= 0.009) {
        enrichedItems.add(updatedItem);
        continue;
      }

      final deposits = [...updatedItem.deposits];
      if (deposits.isEmpty && previousDeposit > 0.009) {
        deposits.add(
          PackageDeposit(
            id: const Uuid().v4(),
            amount: previousDeposit,
            date: sale.createdAt,
            note: 'Acconto iniziale',
            paymentMethod: sale.paymentMethod,
          ),
        );
      }
      deposits.add(
        PackageDeposit(
          id: const Uuid().v4(),
          amount: delta,
          date: timestamp,
          note:
              updatedItem.packagePaymentStatus == PackagePaymentStatus.paid
                  ? 'Saldo registrato'
                  : 'Acconto registrato',
          paymentMethod: result.method,
        ),
      );

      enrichedItems.add(
        updatedItem.copyWith(
          deposits: deposits,
          depositAmount: updatedItem.depositAmount,
        ),
      );
    }

    final store = ref.read(appDataProvider.notifier);
    final selectedStaff = staffOptions.firstWhereOrNull(
      (member) => member.id == result.staffId,
    );
    final recorder =
        selectedStaff?.fullName ??
        store.currentUser?.displayName ??
        store.currentUser?.uid;
    final movementType =
        nextStatus == SalePaymentStatus.paid
            ? SalePaymentType.settlement
            : SalePaymentType.deposit;
    final movements =
        sale.paymentHistory.isNotEmpty
            ? [...sale.paymentHistory]
            : <SalePaymentMovement>[];
    if (movements.isEmpty) {
      final legacyDeposit = _totalSaleDeposits(sale);
      if (legacyDeposit > 0.009) {
        final initialType =
            sale.paymentStatus == SalePaymentStatus.paid
                ? SalePaymentType.settlement
                : SalePaymentType.deposit;
        final legacyRecorder =
            staff
                .firstWhereOrNull((member) => member.id == sale.staffId)
                ?.fullName;
        movements.add(
          SalePaymentMovement(
            id: const Uuid().v4(),
            amount: legacyDeposit,
            type: initialType,
            date: sale.createdAt,
            paymentMethod: sale.paymentMethod,
            recordedBy: legacyRecorder,
            note:
                initialType == SalePaymentType.deposit
                    ? 'Acconto iniziale (storico)'
                    : 'Saldo iniziale (storico)',
          ),
        );
      }
    }
    movements.add(
      SalePaymentMovement(
        id: const Uuid().v4(),
        amount: additional,
        type: movementType,
        date: timestamp,
        paymentMethod: result.method,
        recordedBy: recorder,
        note:
            movementType == SalePaymentType.deposit
                ? 'Acconto registrato'
                : 'Saldo registrato',
      ),
    );
    movements.sort((a, b) => a.date.compareTo(b.date));

    final updatedSale = sale.copyWith(
      paidAmount: nextPaidAmount,
      paymentStatus: nextStatus,
      items: enrichedItems,
      paymentMethod: result.method,
      staffId: result.staffId ?? sale.staffId,
      paymentHistory: movements,
    );

    await store.upsertSale(updatedSale);

    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final isFinal =
        nextStatus == SalePaymentStatus.paid ||
        updatedSale.outstandingAmount <= 0.009;
    final description =
        isFinal
            ? 'Saldo vendita a $clientName'
            : 'Acconto vendita a $clientName';

    await _recordCashFlowEntry(
      ref: ref,
      sale: updatedSale,
      amount: additional,
      description: description,
      date: timestamp,
    );
  }

  Future<void> _reverseSaleDeposit({
    required BuildContext context,
    required WidgetRef ref,
    required Sale sale,
    required _SaleDepositEntry deposit,
    required NumberFormat currency,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Storna acconto'),
            content: Text(
              'Vuoi stornare l\'acconto da ${currency.format(deposit.amount)}? Verrà registrato un movimento negativo in cassa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Conferma'),
              ),
            ],
          ),
    );

    if (confirm != true) {
      return;
    }

    final amount = _normalizeCurrency(deposit.amount);
    if (amount <= 0) {
      return;
    }

    final movement = sale.paymentHistory.firstWhereOrNull(
      (entry) => entry.id == deposit.id,
    );
    final movements =
        sale.paymentHistory.isEmpty
            ? <SalePaymentMovement>[]
            : [...sale.paymentHistory];
    if (movement != null) {
      movements.removeWhere((entry) => entry.id == movement.id);
    }

    var nextPaidAmount = sale.paidAmount - amount;
    if (nextPaidAmount < 0) {
      nextPaidAmount = 0;
    }
    nextPaidAmount = _normalizeCurrency(nextPaidAmount);

    final nextStatus =
        nextPaidAmount >= sale.total - 0.009
            ? SalePaymentStatus.paid
            : SalePaymentStatus.deposit;

    final distributedItems = _applyPackagePaymentDistribution(
      items: sale.items,
      paymentStatus: nextStatus,
      paidAmount: nextPaidAmount,
    );

    final adjustedItems = <SaleItem>[];
    for (var index = 0; index < distributedItems.length; index++) {
      final updatedItem = distributedItems[index];
      if (updatedItem.referenceType != SaleReferenceType.package) {
        adjustedItems.add(updatedItem);
        continue;
      }
      final originalItem = sale.items[index];
      var deposits = originalItem.deposits;
      if (deposits.isNotEmpty) {
        deposits = deposits.where((entry) => entry.id != deposit.id).toList();
      }
      final alignedDeposits = _alignDepositsToAmount(
        deposits,
        updatedItem.depositAmount,
      );
      adjustedItems.add(updatedItem.copyWith(deposits: alignedDeposits));
    }

    movements.sort((a, b) => a.date.compareTo(b.date));

    var loyaltySummary = sale.loyalty;
    var discountAmount = sale.discountAmount;
    var totalAmount = sale.total;
    final loyaltyDiscount = _normalizeCurrency(sale.loyalty.redeemedValue);

    if (nextPaidAmount <= 0.009 &&
        (loyaltySummary.redeemedPoints != 0 ||
            loyaltySummary.earnedPoints != 0)) {
      loyaltySummary = SaleLoyaltySummary();
      if (loyaltyDiscount > 0) {
        discountAmount = _normalizeCurrency(discountAmount - loyaltyDiscount);
        totalAmount = _normalizeCurrency(totalAmount + loyaltyDiscount);
      }
    }

    final updatedSale = sale.copyWith(
      paidAmount: nextPaidAmount,
      paymentStatus: nextStatus,
      items: adjustedItems,
      paymentHistory: movements,
      loyalty: loyaltySummary,
      discountAmount: discountAmount,
      total: totalAmount,
    );

    final store = ref.read(appDataProvider.notifier);
    await store.upsertSale(updatedSale);

    final clients = ref.read(appDataProvider).clients;
    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final description =
        deposit.movementType == SalePaymentType.settlement
            ? 'Storno saldo vendita a $clientName'
            : 'Storno acconto vendita a $clientName';

    await _recordCashFlowEntry(
      ref: ref,
      sale: updatedSale,
      amount: -amount,
      description: description,
      date: DateTime.now(),
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Acconto stornato.')));
  }

  Future<void> _openTicketSale({
    required BuildContext context,
    required WidgetRef ref,
    required PaymentTicket ticket,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
  }) async {
    final matchedService = services.firstWhereOrNull(
      (service) => service.id == ticket.serviceId,
    );
    final rawTotal = ticket.expectedTotal ?? matchedService?.price ?? 0;
    final normalizedTotal = rawTotal > 0 ? _normalizeCurrency(rawTotal) : null;
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final store = ref.read(appDataProvider.notifier);
    final staffOptions =
        staff.where((member) => member.salonId == ticket.salonId).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final saleStaffName =
        staffOptions
            .firstWhereOrNull((member) => member.id == ticket.staffId)
            ?.fullName ??
        staff
            .firstWhereOrNull((member) => member.id == ticket.staffId)
            ?.fullName;

    final result = await showAppModalSheet<OutstandingPaymentResult>(
      context: context,
      builder:
          (ctx) => OutstandingPaymentFormSheet(
            title: 'Registra incasso',
            subtitle:
                normalizedTotal == null
                    ? 'Inserisci l\'importo da incassare'
                    : 'Totale previsto: ${currency.format(normalizedTotal)}',
            outstandingAmount: normalizedTotal ?? double.infinity,
            initialAmount: normalizedTotal,
            staff: staffOptions,
            initialStaffId: ticket.staffId,
            staffName: saleStaffName,
            currency: currency,
          ),
    );

    if (result == null) {
      return;
    }

    final paidAmount = _normalizeCurrency(result.amount);
    if (paidAmount <= 0) {
      return;
    }

    final selectedStaff = staffOptions.firstWhereOrNull(
      (member) => member.id == result.staffId,
    );
    final recorder =
        selectedStaff?.fullName ??
        store.currentUser?.displayName ??
        store.currentUser?.uid;

    final saleTotal = normalizedTotal ?? paidAmount;
    final status =
        paidAmount >= saleTotal - 0.009
            ? SalePaymentStatus.paid
            : SalePaymentStatus.deposit;
    final creationDate = DateTime.now();
    final movementType =
        status == SalePaymentStatus.paid
            ? SalePaymentType.settlement
            : SalePaymentType.deposit;
    final paymentMovements = <SalePaymentMovement>[
      SalePaymentMovement(
        id: const Uuid().v4(),
        amount: paidAmount,
        type: movementType,
        date: creationDate,
        paymentMethod: result.method,
        recordedBy: recorder,
        note:
            movementType == SalePaymentType.deposit
                ? 'Incasso ticket (acconto)'
                : 'Incasso ticket (saldo)',
      ),
    ];

    final sale = Sale(
      id: const Uuid().v4(),
      salonId: ticket.salonId,
      clientId: ticket.clientId,
      items: [
        SaleItem(
          referenceId: ticket.serviceId,
          referenceType: SaleReferenceType.service,
          description: matchedService?.name ?? ticket.serviceName ?? 'Servizio',
          quantity: 1,
          unitPrice: saleTotal,
        ),
      ],
      total: saleTotal,
      createdAt: creationDate,
      paymentMethod: result.method,
      paymentStatus: status,
      paidAmount: status == SalePaymentStatus.paid ? saleTotal : paidAmount,
      invoiceNumber: null,
      notes: ticket.notes,
      discountAmount: 0,
      staffId: result.staffId ?? ticket.staffId,
      paymentHistory: paymentMovements,
    );

    await store.upsertSale(sale);

    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final description =
        status == SalePaymentStatus.deposit
            ? 'Acconto vendita a $clientName'
            : 'Vendita a $clientName';

    await _recordCashFlowEntry(
      ref: ref,
      sale: sale,
      amount: paidAmount,
      description: description,
      date: creationDate,
    );

    await store.closePaymentTicket(ticket.id, saleId: sale.id);
  }

  Future<void> _recordCashFlowEntry({
    required WidgetRef ref,
    required Sale sale,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final magnitude = _normalizeCurrency(amount.abs());
    if (magnitude <= 0) {
      return;
    }
    final type = amount >= 0 ? CashFlowType.income : CashFlowType.expense;
    final entry = CashFlowEntry(
      id: const Uuid().v4(),
      salonId: sale.salonId,
      type: type,
      amount: magnitude,
      date: date ?? DateTime.now(),
      createdAt: DateTime.now(),
      description: description,
      category: 'Vendite',
      staffId: sale.staffId,
    );
    await ref.read(appDataProvider.notifier).upsertCashFlowEntry(entry);
  }

  Widget _buildOutstandingSaleTile(
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateTimeFormat,
    List<StaffMember> staff,
    _OutstandingSale outstandingSale, {
    VoidCallback? onTap,
  }) {
    final sale = outstandingSale.sale;
    final saleDate = dateTimeFormat.format(sale.createdAt);
    final staffMember =
        sale.staffId == null
            ? null
            : staff.firstWhereOrNull((member) => member.id == sale.staffId);
    final items =
        sale.items
            .map((item) => item.description)
            .where((value) => value.isNotEmpty)
            .toList();
    final preview = items.take(2).join(', ');
    final remaining = math.max(items.length - 2, 0);
    final depositTotal = _totalSaleDeposits(sale);
    final subtitleLines = <String>[
      'Metodo: ${_PackageGroup._paymentLabel(sale.paymentMethod)} • Incassato ${currency.format(depositTotal)} di ${currency.format(sale.total)}',
    ];
    if (staffMember != null) {
      subtitleLines.add('Operatore: ${staffMember.fullName}');
    }
    if (preview.isNotEmpty) {
      subtitleLines.add(
        remaining > 0 ? 'Voci: $preview (+$remaining)' : 'Voci: $preview',
      );
    }
    if (sale.notes != null && sale.notes!.isNotEmpty) {
      subtitleLines.add('Note: ${sale.notes}');
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.point_of_sale_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text('Vendita del $saleDate'),
      subtitle: Text(subtitleLines.join('\n')),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currency.format(outstandingSale.outstanding),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Residuo da incassare', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTicketTile(
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateTimeFormat,
    List<Service> services,
    List<StaffMember> staff,
    PaymentTicket ticket, {
    VoidCallback? onTap,
  }) {
    final service = services.firstWhereOrNull(
      (element) => element.id == ticket.serviceId,
    );
    final serviceName = ticket.serviceName ?? service?.name ?? 'Servizio';
    final operator =
        ticket.staffId == null
            ? null
            : staff.firstWhereOrNull((member) => member.id == ticket.staffId);
    final appointmentLabel = dateTimeFormat.format(ticket.appointmentStart);
    final amount = ticket.expectedTotal;
    final subtitleParts = <String>['Appuntamento: $appointmentLabel'];
    if (operator != null) {
      subtitleParts.add('Operatore: ${operator.fullName}');
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.receipt_long_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(serviceName),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount != null && amount > 0
                ? currency.format(amount)
                : 'Importo n/d',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Residuo da incassare', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOutstandingPackageTile(
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateFormat,
    ClientPackagePurchase purchase, {
    VoidCallback? onTap,
  }) {
    final purchaseDate = dateFormat.format(purchase.sale.createdAt);
    final deposit = _packageDepositTotal(purchase);
    final paymentMethod = _PackageGroup._paymentLabel(
      purchase.sale.paymentMethod,
    );
    final info = <String>['Acquisto: $purchaseDate', 'Metodo: $paymentMethod'];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.card_membership_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(purchase.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.join(' • ')),
          if (deposit > 0) Text('Acconto versato: ${currency.format(deposit)}'),
          if (purchase.serviceNames.isNotEmpty)
            Text('Servizi: ${purchase.serviceNames.join(', ')}'),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currency.format(purchase.outstandingAmount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Da saldare', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  double _totalSaleDeposits(Sale sale) {
    final history = sale.paymentHistory;
    final depositsFromHistory = history
        .where((movement) => movement.type == SalePaymentType.deposit)
        .fold<double>(0, (sum, movement) => sum + movement.amount);
    if (depositsFromHistory > 0.009) {
      return _normalizeCurrency(depositsFromHistory);
    }
    final depositsFromItems = sale.items.fold<double>(
      0,
      (sum, item) => sum + item.depositAmount,
    );
    if (depositsFromItems > 0.009) {
      return _normalizeCurrency(depositsFromItems);
    }
    if (sale.paymentStatus == SalePaymentStatus.deposit &&
        sale.paidAmount > 0) {
      return _normalizeCurrency(sale.paidAmount);
    }
    return 0;
  }

  double _packageDepositTotal(ClientPackagePurchase purchase) {
    final deposits = purchase.deposits;
    final depositsSum = deposits.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final expectedDeposit = _normalizeCurrency(purchase.depositAmount);
    var result = 0.0;
    if (depositsSum > result + 0.009) {
      result = _normalizeCurrency(depositsSum);
    }
    if (expectedDeposit > result + 0.009) {
      result = expectedDeposit;
    }
    final saleLevelDeposits = _totalSaleDeposits(purchase.sale);
    if (saleLevelDeposits > result + 0.009) {
      result = saleLevelDeposits;
    }
    return result;
  }

  Widget _buildHistoryCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateTimeFormat,
    List<Sale> sales,
  ) {
    if (sales.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('Nessun pagamento registrato'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Storico pagamenti', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(sales.length, (index) {
              final sale = sales[index];
              final saleDate = dateTimeFormat.format(sale.createdAt);
              final itemDescriptions =
                  sale.items
                      .map((item) => item.description)
                      .where((value) => value.isNotEmpty)
                      .toList();
              final preview = itemDescriptions.take(3).join(', ');
              final remaining = math.max(itemDescriptions.length - 3, 0);
              final details =
                  StringBuffer()
                    ..write(
                      'Metodo: ${_PackageGroup._paymentLabel(sale.paymentMethod)}',
                    )
                    ..write(' • Stato: ${sale.paymentStatus.label}')
                    ..write(' • Articoli: ${sale.items.length}');
              if (sale.invoiceNumber != null &&
                  sale.invoiceNumber!.isNotEmpty) {
                details.write(' • Documento: ${sale.invoiceNumber}');
              }
              if (sale.discountAmount > 0) {
                details.write(
                  ' • Sconto: ${currency.format(sale.discountAmount)}',
                );
              }
              final subtitleLines = <String>[details.toString()];
              if (preview.isNotEmpty) {
                subtitleLines.add(
                  remaining > 0
                      ? 'Elementi: $preview (+$remaining)'
                      : 'Elementi: $preview',
                );
              }
              if (sale.notes != null && sale.notes!.isNotEmpty) {
                subtitleLines.add('Note: ${sale.notes}');
              }
              if (sale.paymentStatus == SalePaymentStatus.deposit) {
                subtitleLines.add(
                  'Incassato: ${currency.format(sale.paidAmount)} · Residuo: ${currency.format(sale.outstandingAmount)}',
                );
              }
              final deposits = _collectSaleDeposits(sale);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == sales.length - 1 ? 0 : 12,
                ),
                child: _PaymentHistoryTile(
                  key: ValueKey('payment-history-${sale.id}'),
                  sale: sale,
                  title: 'Vendita del $saleDate',
                  subtitleLines: subtitleLines,
                  currency: currency,
                  theme: theme,
                  dateTimeFormat: dateTimeFormat,
                  deposits: deposits,
                  onDeleteDeposit:
                      deposits.isEmpty
                          ? null
                          : (entry) => _reverseSaleDeposit(
                            context: context,
                            ref: ref,
                            sale: sale,
                            deposit: entry,
                            currency: currency,
                          ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OutstandingSale {
  const _OutstandingSale({required this.sale, required this.outstanding});

  final Sale sale;
  final double outstanding;
}

class _SaleDepositEntry {
  const _SaleDepositEntry({
    required this.id,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.note,
    this.itemDescription,
    this.recordedBy,
    this.movementType,
  });

  final String id;
  final double amount;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? itemDescription;
  final String? recordedBy;
  final SalePaymentType? movementType;
}

class _PaymentHistoryTile extends StatefulWidget {
  const _PaymentHistoryTile({
    required this.sale,
    required this.title,
    required this.subtitleLines,
    required this.currency,
    required this.theme,
    required this.dateTimeFormat,
    required this.deposits,
    this.onDeleteDeposit,
    super.key,
  });

  final Sale sale;
  final String title;
  final List<String> subtitleLines;
  final NumberFormat currency;
  final ThemeData theme;
  final DateFormat dateTimeFormat;
  final List<_SaleDepositEntry> deposits;
  final Future<void> Function(_SaleDepositEntry entry)? onDeleteDeposit;

  @override
  State<_PaymentHistoryTile> createState() => _PaymentHistoryTileState();
}

class _PaymentHistoryTileState extends State<_PaymentHistoryTile> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final hasDeposits = widget.deposits.isNotEmpty;
    final scheme = widget.theme.colorScheme;
    final trailingAmount =
        sale.paymentStatus == SalePaymentStatus.deposit
            ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.currency.format(sale.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Incassato ${widget.currency.format(sale.paidAmount)}',
                  style: widget.theme.textTheme.bodySmall,
                ),
              ],
            )
            : Text(
              widget.currency.format(sale.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: ValueKey('payment-history-tile-${sale.id}'),
          contentPadding: EdgeInsets.zero,
          onTap: _toggle,
          leading: CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(Icons.payment_rounded, color: scheme.primary),
          ),
          title: Text(widget.title),
          subtitle: Text(widget.subtitleLines.join('\n')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              trailingAmount,
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color:
                    hasDeposits
                        ? widget.theme.iconTheme.color
                        : widget.theme.disabledColor,
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
            child: _buildDepositsSection(
              scheme,
              widget.currency,
              widget.dateTimeFormat,
              widget.deposits,
              widget.onDeleteDeposit,
            ),
          ),
      ],
    );
  }

  Widget _buildDepositsSection(
    ColorScheme scheme,
    NumberFormat currency,
    DateFormat dateFormat,
    List<_SaleDepositEntry> deposits,
    Future<void> Function(_SaleDepositEntry entry)? onDeleteDeposit,
  ) {
    final background = scheme.surfaceContainerHighest;
    final outline = scheme.outlineVariant.withOpacity(0.6);
    final theme = widget.theme;
    if (deposits.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outline, width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nessun movimento registrato',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outline, width: 0.5),
      ),
      child: Column(
        children: [
          for (var index = 0; index < deposits.length; index++)
            _DepositRow(
              entry: deposits[index],
              currency: currency,
              dateFormat: dateFormat,
              showDivider: index < deposits.length - 1,
              onDelete: onDeleteDeposit,
            ),
        ],
      ),
    );
  }
}

class _DepositRow extends StatelessWidget {
  const _DepositRow({
    required this.entry,
    required this.currency,
    required this.dateFormat,
    this.showDivider = false,
    this.onDelete,
  });

  final _SaleDepositEntry entry;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final bool showDivider;
  final Future<void> Function(_SaleDepositEntry entry)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.savings_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.movementType == null
                          ? currency.format(entry.amount)
                          : '${currency.format(entry.amount)} • ${entry.movementType!.label}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        dateFormat.format(entry.date),
                        _PackageGroup._paymentLabel(entry.paymentMethod),
                        if (entry.recordedBy != null &&
                            entry.recordedBy!.isNotEmpty)
                          'Operatore: ${entry.recordedBy}',
                      ].join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (entry.itemDescription != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.itemDescription!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Nota: ${entry.note}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Storna acconto',
                  icon: const Icon(Icons.undo_rounded),
                  onPressed: () => onDelete?.call(entry),
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: scheme.outlineVariant.withOpacity(0.5),
          ),
      ],
    );
  }
}

class _PackageGroup extends StatelessWidget {
  const _PackageGroup({
    required this.title,
    required this.items,
    this.onEdit,
    this.onDelete,
    this.onAddDeposit,
    this.onDeleteDeposit,
  });

  final String title;
  final List<ClientPackagePurchase> items;
  final ValueChanged<ClientPackagePurchase>? onEdit;
  final ValueChanged<ClientPackagePurchase>? onDelete;
  final ValueChanged<ClientPackagePurchase>? onAddDeposit;
  final void Function(ClientPackagePurchase, PackageDeposit)? onDeleteDeposit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                title.contains('corso')
                    ? 'Nessun pacchetto attivo per il cliente.'
                    : 'Non risultano pacchetti passati registrati.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...items.map((purchase) {
                final expiry = purchase.expirationDate;
                final sessionLabel = _sessionLabel(purchase);
                final servicesLabel = purchase.serviceNames.join(', ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              purchase.package?.name ??
                                  purchase.item.description,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (onEdit != null || onDelete != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (onEdit != null)
                                  IconButton(
                                    tooltip: 'Modifica pacchetto',
                                    icon: const Icon(Icons.edit_rounded),
                                    onPressed: () => onEdit?.call(purchase),
                                  ),
                                if (onDelete != null)
                                  IconButton(
                                    tooltip: 'Elimina pacchetto',
                                    icon: const Icon(Icons.delete_rounded),
                                    onPressed: () => onDelete?.call(purchase),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _statusChip(context, purchase.status),
                          _Chip(
                            label: purchase.paymentStatus.label,
                            icon:
                                purchase.paymentStatus ==
                                        PackagePaymentStatus.deposit
                                    ? Icons.savings_rounded
                                    : Icons.verified_rounded,
                          ),
                          if (purchase.depositAmount > 0)
                            _Chip(
                              label:
                                  'Acconto: ${currency.format(purchase.depositAmount)}',
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                          if (purchase.outstandingAmount > 0)
                            _Chip(
                              label:
                                  'Da saldare: ${currency.format(purchase.outstandingAmount)}',
                              icon: Icons.pending_actions_rounded,
                            ),
                          _Chip(
                            label: currency.format(purchase.totalAmount),
                            icon: Icons.euro_rounded,
                          ),
                          _Chip(
                            label: _paymentLabel(purchase.sale.paymentMethod),
                            icon: Icons.payments_rounded,
                          ),
                          _Chip(
                            label:
                                'Acquisto: ${dateFormat.format(purchase.sale.createdAt)}',
                            icon: Icons.calendar_today_rounded,
                          ),
                          _Chip(
                            label:
                                expiry == null
                                    ? 'Senza scadenza'
                                    : 'Scadenza: ${dateFormat.format(expiry)}',
                            icon: Icons.timer_outlined,
                          ),
                          _Chip(
                            label: sessionLabel,
                            icon: Icons.event_repeat_rounded,
                          ),
                        ],
                      ),
                      if (servicesLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Servizi inclusi: $servicesLabel'),
                      ],
                      if (purchase.deposits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Acconti', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Column(
                          children:
                              purchase.deposits.map((deposit) {
                                final subtitleBuffer = StringBuffer(
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(deposit.date)} • ${_paymentLabel(deposit.paymentMethod)}',
                                );
                                if (deposit.note != null &&
                                    deposit.note!.isNotEmpty) {
                                  subtitleBuffer
                                    ..write('\n')
                                    ..write(deposit.note);
                                }
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(currency.format(deposit.amount)),
                                  subtitle: Text(subtitleBuffer.toString()),
                                  trailing:
                                      onDeleteDeposit == null
                                          ? null
                                          : IconButton(
                                            tooltip: 'Storna acconto',
                                            icon: const Icon(
                                              Icons.undo_rounded,
                                            ),
                                            onPressed:
                                                () => onDeleteDeposit?.call(
                                                  purchase,
                                                  deposit,
                                                ),
                                          ),
                                );
                              }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  static String _paymentLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.pos:
        return 'POS';
      case PaymentMethod.transfer:
        return 'Bonifico';
      case PaymentMethod.giftCard:
        return 'Gift card';
    }
  }

  static String _sessionLabel(ClientPackagePurchase purchase) {
    final remaining = purchase.remainingSessions;
    final total = purchase.totalSessions;
    if (remaining == null && total == null) {
      return 'Sessioni non definite';
    }
    if (total == null) {
      return 'Rimanenti: ${remaining ?? '-'}';
    }
    final remainingLabel = remaining?.toString() ?? '—';
    return '$remainingLabel / $total sessioni rimaste';
  }

  static Widget _statusChip(
    BuildContext context,
    PackagePurchaseStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    late final Color background;
    late final Color foreground;
    late final IconData icon;

    switch (status) {
      case PackagePurchaseStatus.active:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        icon = Icons.play_arrow_rounded;
        break;
      case PackagePurchaseStatus.completed:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        icon = Icons.check_circle_rounded;
        break;
      case PackagePurchaseStatus.cancelled:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        icon = Icons.cancel_rounded;
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(status.label, style: TextStyle(color: foreground)),
      backgroundColor: background,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: scheme.surfaceContainerHighest,
      avatar: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      label: Text(label),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
