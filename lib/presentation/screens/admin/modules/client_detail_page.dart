import 'dart:math' as math;

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_clipboard.dart';
import 'package:you_book/domain/entities/cash_flow_entry.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_questionnaire.dart';
import 'package:you_book/domain/entities/client_photo.dart';
import 'package:you_book/domain/entities/client_photo_collage.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/quote.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/appointment_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/appointment_sale_flow_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_save_feedback.dart';
import 'package:you_book/presentation/screens/admin/forms/outstanding_payment_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/package_deposit_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/package_purchase_edit_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/package_sale_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/quote_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/widgets/client_overview_section.dart';
import 'package:you_book/presentation/common/hybrid_image_picker.dart';
import 'package:you_book/presentation/screens/admin/modules/collage_editor_dialog.dart';
import 'package:you_book/presentation/screens/admin/modules/sales/sale_helpers.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';
import 'package:you_book/presentation/shared/widgets/client_notes_section.dart';
import 'package:you_book/widgets/shared/badge/status_badge.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

const double _clientStandaloneWidthThreshold = 900;
const double _clientDetailEmbeddedMinHeight = 620;

bool isCompactClientLayout(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) {
    return true;
  }
  return mediaQuery.size.width < _clientStandaloneWidthThreshold;
}

Future<bool> openClientDetailPage(
  BuildContext context, {
  required String clientId,
  int initialTabIndex = 0,
  bool popCurrent = false,
  bool compactOnly = false,
}) async {
  if (compactOnly && !isCompactClientLayout(context)) {
    return false;
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  if (popCurrent) {
    await navigator.maybePop();
  }
  await navigator.push(
    MaterialPageRoute(
      builder:
          (_) => ClientDetailPage(
            clientId: clientId,
            initialTabIndex: initialTabIndex,
          ),
    ),
  );
  return true;
}

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

class ClientDetailPage extends ConsumerWidget {
  const ClientDetailPage({
    super.key,
    required this.clientId,
    this.initialTabIndex = 0,
  });

  final String clientId;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClientDetailView(
      clientId: clientId,
      initialTabIndex: initialTabIndex,
    );
  }
}

class ClientDetailView extends ConsumerStatefulWidget {
  const ClientDetailView({
    super.key,
    required this.clientId,
    this.showAppBar = true,
    this.onClose,
    this.initialTabIndex = 0,
  });

  final String clientId;
  final bool showAppBar;
  final VoidCallback? onClose;
  final int initialTabIndex;

  @override
  ConsumerState<ClientDetailView> createState() => _ClientDetailViewState();
}

class _ClientDetailViewState extends ConsumerState<ClientDetailView> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == widget.clientId,
    );

    if (client == null) {
      const notFound = Text(
        'Cliente non trovato. Aggiorna l\'elenco e riprova.',
        textAlign: TextAlign.center,
      );
      if (widget.showAppBar) {
        return Scaffold(
          appBar: AppBar(title: const Text('Dettaglio cliente')),
          body: const Center(child: notFound),
        );
      }
      return Card(
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: notFound),
        ),
      );
    }

    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == client.salonId,
    );
    final tabDefinitions = _buildTabDefinitions();
    final tabViews = [
      _ProfileTab(client: client, salon: salon),
      _QuestionnaireTab(client: client),
      _PhotoArchiveTab(client: client),
      _AppointmentsTab(clientId: client.id),
      _PackagesTab(clientId: client.id),
      _QuotesTab(clientId: client.id),
      _BillingTab(clientId: client.id),
    ];

    final initialTabIndex =
        widget.initialTabIndex.clamp(0, tabDefinitions.length - 1).toInt();
    final theme = Theme.of(context);
    final embeddedHeight = math.max(
      _clientDetailEmbeddedMinHeight,
      MediaQuery.of(context).size.height * 0.68,
    );

    final shell = DefaultTabController(
      initialIndex: initialTabIndex,
      length: tabDefinitions.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, widget.showAppBar ? 20 : 0, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, client: client, salonName: salon?.name),
                const SizedBox(height: 18),
                _buildTabBar(context, tabDefinitions),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.75,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (widget.showAppBar)
            Expanded(child: TabBarView(children: tabViews))
          else
            SizedBox(
              height: embeddedHeight,
              child: TabBarView(children: tabViews),
            ),
        ],
      ),
    );

    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(child: shell),
      );
    }

    return shell;
  }

  Widget _buildHeader(
    BuildContext context, {
    required Client client,
    String? salonName,
  }) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[];
    final clientNumber = client.clientNumber?.trim();
    if (clientNumber != null && clientNumber.isNotEmpty) {
      subtitleParts.add('Cliente #$clientNumber');
    }
    if (salonName != null && salonName.trim().isNotEmpty) {
      subtitleParts.add(salonName.trim());
    }
    final subtitle =
        subtitleParts.isEmpty ? 'Scheda cliente' : subtitleParts.join(' · ');
    final canOpenContacts =
        client.phone.trim().isNotEmpty ||
        (client.email?.trim().isNotEmpty ?? false);
    final closeAction = _resolveCloseAction(context);

    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Torna indietro',
          onPressed: closeAction,
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            foregroundColor: theme.colorScheme.onSurface,
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.fullName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed:
              canOpenContacts ? () => _showContactSheet(context, client) : null,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('Messaggio'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: () => _editClient(context, client),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Modifica'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }

  VoidCallback? _resolveCloseAction(BuildContext context) {
    if (widget.onClose != null) {
      return widget.onClose;
    }
    final navigator = Navigator.maybeOf(context);
    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator != null && navigator.canPop()) {
      return () => navigator.maybePop();
    }
    if (rootNavigator != null &&
        rootNavigator != navigator &&
        rootNavigator.canPop()) {
      return () => rootNavigator.maybePop();
    }
    return null;
  }

  Future<void> _editClient(BuildContext context, Client client) async {
    final data = ref.read(appDataProvider);
    final salons = data.salons;
    final clients = data.clients;
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showAppModalSheet<Client>(
      context: context,
      includeCloseButton: false,
      desktopMaxWidth: 980,
      builder:
          (ctx) => ClientFormSheet(
            salons: salons,
            clients: clients,
            initial: client,
            defaultSalonId: client.salonId,
          ),
    );
    if (!mounted || updated == null) {
      return;
    }

    try {
      final saveResult = await ref
          .read(appDataProvider.notifier)
          .upsertClient(updated);
      final warningMessage = saveResult.warningMessage?.trim();
      if (!mounted || warningMessage == null || warningMessage.isEmpty) {
        return;
      }
      messenger.showAppSnackBar(SnackBar(content: Text(warningMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showAppSnackBar(
        SnackBar(content: Text(formatClientSaveError(error))),
      );
    }
  }

  Future<void> _showContactSheet(BuildContext context, Client client) async {
    final preferences = client.channelPreferences;
    final channels = <({IconData icon, String label, bool enabled})>[
      (
        icon: Icons.phone_android_rounded,
        label: 'Push',
        enabled: preferences.push,
      ),
      (icon: Icons.email_outlined, label: 'Email', enabled: preferences.email),
      (
        icon: Icons.chat_bubble_outline_rounded,
        label: 'WhatsApp',
        enabled: preferences.whatsapp,
      ),
      (icon: Icons.sms_outlined, label: 'SMS', enabled: preferences.sms),
    ];
    final phone = client.phone.trim();
    final email = client.email?.trim();

    Widget buildSheetContent(
      BuildContext sheetContext, {
      required bool showHeader,
    }) {
      final theme = Theme.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              'Contatti cliente',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              client.fullName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (phone.isNotEmpty)
            _buildContactRow(
              sheetContext,
              icon: Icons.phone_outlined,
              label: 'Telefono',
              value: phone,
            ),
          if (email != null && email.isNotEmpty) ...[
            if (phone.isNotEmpty) const SizedBox(height: 10),
            _buildContactRow(
              sheetContext,
              icon: Icons.alternate_email_rounded,
              label: 'Email',
              value: email,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Canali preferiti',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: channels
                .map(
                  (channel) => Chip(
                    avatar: Icon(
                      channel.icon,
                      size: 16,
                      color:
                          channel.enabled
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(channel.label),
                    backgroundColor:
                        channel.enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerLow,
                    labelStyle: TextStyle(
                      color:
                          channel.enabled
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      );
    }

    await showAppModalSheet<void>(
      context: context,
      builder: (ctx) {
        if (isAppSheetPhoneLayout(ctx)) {
          return AppMobileSheetPageScaffold(
            title: 'Contatti cliente',
            subtitle: client.fullName,
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: buildSheetContent(ctx, showHeader: false),
            ),
          );
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: buildSheetContent(ctx, showHeader: true),
          ),
        );
      },
    );
  }

  Widget _buildContactRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copia',
            onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            icon: const Icon(Icons.content_copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  List<_ClientTabDefinition> _buildTabDefinitions() => const [
    _ClientTabDefinition(label: 'Scheda', icon: Icons.person),
    _ClientTabDefinition(label: 'Questionario', icon: Icons.list_alt_rounded),
    _ClientTabDefinition(
      label: 'Archivio foto',
      icon: Icons.photo_library_outlined,
    ),
    _ClientTabDefinition(label: 'Appuntamenti', icon: Icons.calendar_month),
    _ClientTabDefinition(label: 'Pacchetti', icon: Icons.card_giftcard_rounded),
    _ClientTabDefinition(label: 'Preventivi', icon: Icons.description_rounded),
    _ClientTabDefinition(
      label: 'Fatturazione',
      icon: Icons.receipt_long_rounded,
    ),
  ];

  Widget _buildTabBar(BuildContext context, List<_ClientTabDefinition> tabs) {
    final theme = Theme.of(context);
    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      padding: EdgeInsets.zero,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      labelColor: theme.colorScheme.onPrimary,
      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: theme.textTheme.labelLarge,
      tabs:
          tabs
              .map(
                (tab) => Tab(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(tab.label),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _ClientTabDefinition {
  const _ClientTabDefinition({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.client, required this.salon});

  final Client client;
  final Salon? salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    final data = ref.watch(appDataProvider);
    final templatesForSalon = data.clientQuestionnaireTemplates
        .where((template) => template.salonId == client.salonId)
        .toList(growable: false);
    final usesAnamnesisLayout = templatesForSalon.any(_canUseAnamnesisLayout);

    final children = <Widget>[];

    final overviewSection = ClientOverviewSection(
      client: client,
      salon: salon,
      dateFormat: dateFormat,
      dateTimeFormat: dateTimeFormat,
    );

    if (usesAnamnesisLayout) {
      children.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final content = <Widget>[
              Expanded(flex: 3, child: overviewSection),
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
    } else {
      children.add(overviewSection);
    }

    children.add(const SizedBox(height: 16));
    children.add(ClientNotesSection(client: client));

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: children,
    );
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

class _QuestionnaireTab extends StatelessWidget {
  const _QuestionnaireTab({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [_ClientQuestionnaireCard(client: client)],
    );
  }
}

class _PhotoArchiveTab extends StatelessWidget {
  const _PhotoArchiveTab({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [_ClientPhotosCard(client: client)],
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
  bool _isAssigningQuestionnaires = false;
  bool _showQuestionnaireEditor = false;
  _QuestionnaireDashboardFilter _dashboardFilter =
      _QuestionnaireDashboardFilter.assigned;
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
              Text('Questionario cliente', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Nessun modello di questionario è stato configurato per questo salone.',
              ),
            ],
          ),
        ),
      );
    }

    final selectedTemplate = templates.firstWhereOrNull(
      (template) => template.id == _selectedTemplateId,
    );
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final summaries = {
      for (final template in templates)
        template.id: _summarizeQuestionnaireTemplate(template, questionnaires),
    };
    final filteredTemplates = _filterTemplatesForDashboard(
      templates,
      summaries,
      _dashboardFilter,
    );
    final effectiveTemplates =
        filteredTemplates.isEmpty ? templates : filteredTemplates;
    final activeTemplate =
        effectiveTemplates.firstWhereOrNull(
          (template) => template.id == selectedTemplate?.id,
        ) ??
        effectiveTemplates.firstOrNull;
    final activeSummary =
        activeTemplate == null ? null : summaries[activeTemplate.id];

    if (activeTemplate != null &&
        activeTemplate.id != _selectedTemplateId &&
        !_isSaving &&
        !_isAssigningQuestionnaires) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _selectTemplate(activeTemplate.id, templates, questionnaires);
      });
    }

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1120;
            final managementHeader = _buildQuestionnaireManagementHeader(
              templates: templates,
              filteredTemplates: effectiveTemplates,
              activeTemplate: activeTemplate,
              activeSummary: activeSummary,
              summaries: summaries,
              questionnaires: questionnaires,
              dateFormat: dateFormat,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                managementHeader,
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 280,
                        child: _buildQuestionnaireTemplateList(
                          templates: effectiveTemplates,
                          allTemplates: templates,
                          questionnaires: questionnaires,
                          summaries: summaries,
                          dateFormat: dateFormat,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildQuestionnaireDetailPanel(
                          template: activeTemplate,
                          summary: activeSummary,
                          allTemplates: templates,
                          questionnaires: questionnaires,
                          dateFormat: dateFormat,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildQuestionnaireTemplateList(
                    templates: effectiveTemplates,
                    allTemplates: templates,
                    questionnaires: questionnaires,
                    summaries: summaries,
                    dateFormat: dateFormat,
                  ),
                  const SizedBox(height: 16),
                  _buildQuestionnaireDetailPanel(
                    template: activeTemplate,
                    summary: activeSummary,
                    allTemplates: templates,
                    questionnaires: questionnaires,
                    dateFormat: dateFormat,
                  ),
                ],
                if (_showQuestionnaireEditor && activeTemplate != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Editor questionario',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuestionnaireForm(
                    template: activeTemplate,
                    questionnaires: questionnaires,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestionnaireManagementHeader({
    required List<ClientQuestionnaireTemplate> templates,
    required List<ClientQuestionnaireTemplate> filteredTemplates,
    required ClientQuestionnaireTemplate? activeTemplate,
    required _QuestionnaireTemplateSummary? activeSummary,
    required Map<String, _QuestionnaireTemplateSummary> summaries,
    required List<ClientQuestionnaire> questionnaires,
    required DateFormat dateFormat,
  }) {
    final theme = Theme.of(context);
    final assignedCount =
        summaries.values
            .where((summary) => summary.latestQuestionnaire != null)
            .length;
    final availableCount =
        summaries.values
            .where((summary) => summary.latestQuestionnaire == null)
            .length;
    final allCount = templates.length;
    final canAssignCurrent =
        activeTemplate != null &&
        activeTemplate.clientCanSelfComplete &&
        !(activeSummary?.hasOpenAppAssignment ?? true) &&
        !_isAssigningQuestionnaires;
    final canExportCurrent =
        activeTemplate != null &&
        activeSummary?.latestQuestionnaire != null &&
        (activeSummary?.answeredQuestions ?? 0) > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed:
                    canExportCurrent
                        ? () {
                          final template = activeTemplate;
                          final questionnaire =
                              activeSummary!.latestQuestionnaire!;
                          _exportQuestionnaireAnswers(
                            template: template,
                            questionnaire: questionnaire,
                          );
                        }
                        : null,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Esporta risposte'),
              ),
              FilledButton.icon(
                onPressed:
                    canAssignCurrent
                        ? () {
                          final template = activeTemplate;
                          _assignQuestionnaireToViewedClient(
                            templateId: template.id,
                            templates: templates,
                            questionnaires: questionnaires,
                          );
                        }
                        : null,
                icon:
                    _isAssigningQuestionnaires
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add_rounded, size: 18),
                label: const Text('Assegna nuovo'),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Text(
                  'Gestione questionari',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assegna e monitora i questionari compilati dal cliente.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: actions),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gestione questionari',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Assegna e monitora i questionari compilati dal cliente.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    actions,
                  ],
                ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _buildQuestionnaireFilterTab(
                    label: 'Assegnati',
                    count: assignedCount,
                    filter: _QuestionnaireDashboardFilter.assigned,
                  ),
                  _buildQuestionnaireFilterTab(
                    label: 'Disponibili',
                    count: availableCount,
                    filter: _QuestionnaireDashboardFilter.available,
                  ),
                  _buildQuestionnaireFilterTab(
                    label: 'Tutti',
                    count: allCount,
                    filter: _QuestionnaireDashboardFilter.all,
                  ),
                ],
              ),
              if (filteredTemplates.isEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Nessun questionario in questa vista.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestionnaireFilterTab({
    required String label,
    required int count,
    required _QuestionnaireDashboardFilter filter,
  }) {
    final theme = Theme.of(context);
    final selected = _dashboardFilter == filter;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (_dashboardFilter == filter) {
          return;
        }
        setState(() {
          _dashboardFilter = filter;
          _showQuestionnaireEditor = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: theme.textTheme.labelLarge?.copyWith(
            color:
                selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionnaireTemplateList({
    required List<ClientQuestionnaireTemplate> templates,
    required List<ClientQuestionnaireTemplate> allTemplates,
    required List<ClientQuestionnaire> questionnaires,
    required Map<String, _QuestionnaireTemplateSummary> summaries,
    required DateFormat dateFormat,
  }) {
    if (templates.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: templates.indexed
          .map((entry) {
            final template = entry.$2;
            final summary = summaries[template.id]!;
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.$1 == templates.length - 1 ? 0 : 12,
              ),
              child: _buildQuestionnaireTemplateCard(
                template: template,
                summary: summary,
                allTemplates: allTemplates,
                questionnaires: questionnaires,
                dateFormat: dateFormat,
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildQuestionnaireTemplateCard({
    required ClientQuestionnaireTemplate template,
    required _QuestionnaireTemplateSummary summary,
    required List<ClientQuestionnaireTemplate> allTemplates,
    required List<ClientQuestionnaire> questionnaires,
    required DateFormat dateFormat,
  }) {
    final theme = Theme.of(context);
    final selected = template.id == _selectedTemplateId;
    final progressColor = _progressColorForSummary(summary, theme);
    final statusLabel = _summaryStatusLabel(summary);
    final statusColor = _summaryStatusForeground(summary, theme);
    final latestEvent =
        summary.latestQuestionnaire?.assignedAt ??
        summary.latestQuestionnaire?.updatedAt ??
        summary.latestQuestionnaire?.createdAt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectTemplate(template.id, allTemplates, questionnaires),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (summary.progressPercent == 100)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Colors.green.shade600,
                    )
                  else if (selected)
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (template.isDefault)
                    _buildQuestionnaireBadge(
                      label: 'Predefinito',
                      foreground: Colors.green.shade700,
                      background: Colors.green.shade50,
                    ),
                  _buildQuestionnaireBadge(
                    label: statusLabel,
                    foreground: statusColor,
                    background: statusColor.withValues(alpha: 0.12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Progresso',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.progressPercent}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: summary.progressPercent / 100,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                latestEvent == null
                    ? 'Nessuna assegnazione'
                    : 'Assegnato: ${dateFormat.format(latestEvent)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionnaireDetailPanel({
    required ClientQuestionnaireTemplate? template,
    required _QuestionnaireTemplateSummary? summary,
    required List<ClientQuestionnaireTemplate> allTemplates,
    required List<ClientQuestionnaire> questionnaires,
    required DateFormat dateFormat,
  }) {
    final theme = Theme.of(context);
    if (template == null || summary == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          'Seleziona un questionario per vedere il dettaglio.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final canAssign =
        template.clientCanSelfComplete &&
        !summary.hasOpenAppAssignment &&
        !_isAssigningQuestionnaires;
    final progressColor = _progressColorForSummary(summary, theme);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
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
                    Text(
                      template.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (template.isDefault)
                          _buildQuestionnaireBadge(
                            label: 'Predefinito',
                            foreground: Colors.green.shade700,
                            background: Colors.green.shade50,
                          ),
                        _buildQuestionnaireBadge(
                          label: _summaryStatusLabel(summary),
                          foreground: _summaryStatusForeground(summary, theme),
                          background: _summaryStatusForeground(
                            summary,
                            theme,
                          ).withValues(alpha: 0.12),
                        ),
                        _buildQuestionnaireBadge(
                          label: '${summary.progressPercent}%',
                          foreground: progressColor,
                          background: progressColor.withValues(alpha: 0.12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Apri questionario',
                    onPressed:
                        () => setState(
                          () =>
                              _showQuestionnaireEditor =
                                  !_showQuestionnaireEditor,
                        ),
                    icon: Icon(
                      _showQuestionnaireEditor
                          ? Icons.visibility_off_outlined
                          : Icons.edit_rounded,
                    ),
                  ),
                  if (template.clientCanSelfComplete)
                    IconButton(
                      tooltip:
                          summary.hasOpenAppAssignment
                              ? 'Già assegnato in app'
                              : 'Invia in app',
                      onPressed:
                          canAssign
                              ? () => _assignQuestionnaireToViewedClient(
                                templateId: template.id,
                                templates: allTemplates,
                                questionnaires: questionnaires,
                              )
                              : null,
                      icon: const Icon(Icons.near_me_outlined),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final columns =
                  constraints.maxWidth >= 860
                      ? 3
                      : constraints.maxWidth >= 540
                      ? 2
                      : 1;
              final itemWidth =
                  columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildQuestionnaireStatCard(
                      value: '${summary.totalSections}',
                      label: 'Sezioni',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildQuestionnaireStatCard(
                      value: '${summary.totalQuestions}',
                      label: 'Domande',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildQuestionnaireStatCard(
                      value: '${summary.answeredQuestions}',
                      label: 'Risposte',
                      valueColor: progressColor,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Sezioni questionario',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...summary.sectionSummaries.indexed.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom:
                    entry.$1 == summary.sectionSummaries.length - 1 ? 0 : 10,
              ),
              child: _buildQuestionnaireSectionTile(
                index: entry.$1 + 1,
                section: entry.$2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      () => setState(
                        () =>
                            _showQuestionnaireEditor =
                                !_showQuestionnaireEditor,
                      ),
                  child: Text(
                    _showQuestionnaireEditor
                        ? 'Chiudi questionario'
                        : 'Apri questionario',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed:
                      canAssign
                          ? () => _assignQuestionnaireToViewedClient(
                            templateId: template.id,
                            templates: allTemplates,
                            questionnaires: questionnaires,
                          )
                          : null,
                  child: Text(
                    summary.hasOpenAppAssignment
                        ? 'Già assegnato'
                        : 'Invia in app',
                  ),
                ),
              ),
            ],
          ),
          if (summary.latestQuestionnaire != null) ...[
            const SizedBox(height: 12),
            Text(
              summary.latestQuestionnaire!.assignedAt != null
                  ? 'Assegnato: ${dateFormat.format(summary.latestQuestionnaire!.assignedAt!)}'
                  : 'Ultimo aggiornamento: ${dateFormat.format(summary.latestQuestionnaire!.updatedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionnaireBadge({
    required String label,
    required Color foreground,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuestionnaireStatCard({
    required String value,
    required String label,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireSectionTile({
    required int index,
    required _QuestionnaireSectionSummary section,
  }) {
    final theme = Theme.of(context);
    final color = _progressColorForPercent(section.progressPercent, theme);
    final completed = section.progressPercent == 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                completed
                    ? Icon(Icons.check_rounded, size: 16, color: color)
                    : Text(
                      '$index',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.group.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${section.answeredQuestions} / ${section.totalQuestions} risposte completate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: section.progressPercent / 100,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  List<ClientQuestionnaireTemplate> _filterTemplatesForDashboard(
    List<ClientQuestionnaireTemplate> templates,
    Map<String, _QuestionnaireTemplateSummary> summaries,
    _QuestionnaireDashboardFilter filter,
  ) {
    return templates
        .where((template) {
          final summary = summaries[template.id];
          if (summary == null) {
            return filter == _QuestionnaireDashboardFilter.all;
          }
          switch (filter) {
            case _QuestionnaireDashboardFilter.assigned:
              return summary.latestQuestionnaire != null;
            case _QuestionnaireDashboardFilter.available:
              return summary.latestQuestionnaire == null;
            case _QuestionnaireDashboardFilter.all:
              return true;
          }
        })
        .toList(growable: false);
  }

  _QuestionnaireTemplateSummary _summarizeQuestionnaireTemplate(
    ClientQuestionnaireTemplate template,
    List<ClientQuestionnaire> questionnaires,
  ) {
    final latest = _latestQuestionnaireForTemplate(questionnaires, template.id);
    final sections = <_QuestionnaireSectionSummary>[];
    var totalQuestions = 0;
    var answeredQuestions = 0;

    for (final group in template.groups) {
      final groupTotal = group.questions.length;
      final groupAnswered =
          group.questions.where((question) {
            final answer = latest?.answerFor(question.id);
            return answer?.hasValue ?? false;
          }).length;
      totalQuestions += groupTotal;
      answeredQuestions += groupAnswered;
      sections.add(
        _QuestionnaireSectionSummary(
          group: group,
          totalQuestions: groupTotal,
          answeredQuestions: groupAnswered,
        ),
      );
    }

    final progressPercent =
        totalQuestions == 0
            ? 0
            : ((answeredQuestions / totalQuestions) * 100).round();
    final hasOpenAppAssignment =
        latest?.assignedToClientApp == true && latest!.isPending;

    return _QuestionnaireTemplateSummary(
      template: template,
      latestQuestionnaire: latest,
      totalSections: template.groups.length,
      totalQuestions: totalQuestions,
      answeredQuestions: answeredQuestions,
      progressPercent: progressPercent,
      hasOpenAppAssignment: hasOpenAppAssignment,
      sectionSummaries: sections,
    );
  }

  Color _progressColorForSummary(
    _QuestionnaireTemplateSummary summary,
    ThemeData theme,
  ) {
    return _progressColorForPercent(summary.progressPercent, theme);
  }

  Color _progressColorForPercent(int percent, ThemeData theme) {
    if (percent >= 100) {
      return Colors.green.shade600;
    }
    if (percent > 0) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.outline;
  }

  String _summaryStatusLabel(_QuestionnaireTemplateSummary summary) {
    if (summary.progressPercent >= 100) {
      return 'Completato';
    }
    if (summary.latestQuestionnaire != null || summary.hasOpenAppAssignment) {
      return 'In modifica';
    }
    return 'Da compilare';
  }

  Color _summaryStatusForeground(
    _QuestionnaireTemplateSummary summary,
    ThemeData theme,
  ) {
    if (summary.progressPercent >= 100) {
      return Colors.green.shade700;
    }
    if (summary.latestQuestionnaire != null || summary.hasOpenAppAssignment) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.onSurfaceVariant;
  }

  Future<void> _exportQuestionnaireAnswers({
    required ClientQuestionnaireTemplate template,
    required ClientQuestionnaire questionnaire,
  }) async {
    final buffer =
        StringBuffer()
          ..writeln('Questionario: ${template.name}')
          ..writeln('Cliente: ${widget.client.fullName}');
    for (final group in template.groups) {
      buffer
        ..writeln()
        ..writeln(group.title);
      for (final question in group.questions) {
        final answer = questionnaire.answerFor(question.id);
        buffer.writeln(
          '- ${question.label}: ${_formatAnswerForExport(question, answer)}',
        );
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Risposte copiate negli appunti.')),
    );
  }

  String _formatAnswerForExport(
    ClientQuestionDefinition question,
    ClientQuestionAnswer? answer,
  ) {
    if (answer == null || !answer.hasValue) {
      return 'Non compilato';
    }
    switch (question.type) {
      case ClientQuestionType.boolean:
        return answer.boolValue == true
            ? 'Si'
            : answer.boolValue == false
            ? 'No'
            : 'Non compilato';
      case ClientQuestionType.text:
      case ClientQuestionType.textarea:
        return answer.textValue?.trim().isNotEmpty == true
            ? answer.textValue!.trim()
            : 'Non compilato';
      case ClientQuestionType.singleChoice:
      case ClientQuestionType.multiChoice:
        final labels = question.options
            .where((option) => answer.optionIds.contains(option.id))
            .map((option) => option.label)
            .toList(growable: false);
        return labels.isEmpty ? 'Non compilato' : labels.join(', ');
      case ClientQuestionType.number:
        return answer.numberValue?.toString() ?? 'Non compilato';
      case ClientQuestionType.date:
        return answer.dateValue == null
            ? 'Non compilato'
            : DateFormat('dd/MM/yyyy').format(answer.dateValue!);
    }
  }

  bool _hasOpenPendingAppAssignment(
    List<ClientQuestionnaire> questionnaires,
    String templateId,
  ) {
    return questionnaires.any(
      (item) =>
          item.clientId == widget.client.id &&
          item.templateId == templateId &&
          item.assignedToClientApp &&
          item.isPending,
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
        _buildQuestionGroupCard(
          group: group,
          initiallyExpanded: groupIndex == 0,
        ),
      );
    }

    children.add(_buildFormActions(template, questionnaires));

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final maxWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 640.0;
        final columns =
            maxWidth >= 1500
                ? 3
                : maxWidth >= 980
                ? 2
                : 1;
        final groupWidth =
            columns == 1
                ? maxWidth
                : (maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            ...children
                .take(children.length - 1)
                .map((child) => SizedBox(width: groupWidth, child: child)),
            SizedBox(width: maxWidth, child: children.last),
          ],
        );
      },
    );
  }

  Widget _buildQuestionGroupCard({
    required ClientQuestionGroup group,
    required bool initiallyExpanded,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: ExpansionTile(
        key: ValueKey(group.id),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        initiallyExpanded: initiallyExpanded,
        title: Text(
          group.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle:
            group.description == null
                ? null
                : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(group.description!),
                ),
        children: group.questions
            .map(
              (question) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildQuestionField(question),
              ),
            )
            .toList(growable: false),
      ),
    );
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
    final openAppAssignments =
        questionnaires
            .where((item) => item.assignedToClientApp && item.isPending)
            .length;
    final currentTemplateOpenAssignment = _hasOpenPendingAppAssignment(
      questionnaires,
      template.id,
    );
    final isBusy = _isSaving || _isAssigningQuestionnaires;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final statusRow = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.pending_actions_rounded, size: 18),
                label: Text('Assegnazioni app aperte: $openAppAssignments'),
              ),
              if (currentTemplateOpenAssignment)
                const Chip(
                  avatar: Icon(Icons.smartphone_rounded, size: 18),
                  label: Text('Template corrente già assegnato in app'),
                ),
            ],
          );
          final actions = Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed:
                    isBusy
                        ? null
                        : () => _selectTemplate(
                          template.id,
                          templatesForSalon,
                          questionnaires,
                        ),
                child: const Text('Reimposta'),
              ),
              FilledButton(
                onPressed:
                    isBusy ? null : () => _save(template, questionnaires),
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
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: statusRow),
                const SizedBox(width: 16),
                actions,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusRow,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignQuestionnaireToViewedClient({
    required String templateId,
    required List<ClientQuestionnaireTemplate> templates,
    required List<ClientQuestionnaire> questionnaires,
  }) async {
    if (_isAssigningQuestionnaires) {
      return;
    }
    final template = templates.firstWhereOrNull(
      (item) => item.id == templateId,
    );
    if (template == null || !template.clientCanSelfComplete) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Template non disponibile per assegnazione in app.'),
        ),
      );
      return;
    }
    if (_hasOpenPendingAppAssignment(questionnaires, templateId)) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'Esiste gia un\'assegnazione aperta per "${template.name}".',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final questionnaire = ClientQuestionnaire(
      id: _uuid.v4(),
      clientId: widget.client.id,
      salonId: widget.client.salonId,
      templateId: templateId,
      answers: const <ClientQuestionAnswer>[],
      createdAt: now,
      updatedAt: now,
      status: ClientQuestionnaireStatus.assigned,
      assignedToClientApp: true,
      assignedAt: now,
      assignedByUserId: ref.read(sessionControllerProvider).userId,
    );

    setState(() => _isAssigningQuestionnaires = true);

    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertClientQuestionnaire(questionnaire);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Assegnazione non riuscita: $error')),
      );
      setState(() => _isAssigningQuestionnaires = false);
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _isAssigningQuestionnaires = false);
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(
          'Questionario "${template.name}" assegnato a ${widget.client.fullName}.',
        ),
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
      isExpanded: true,
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
          isExpanded: true,
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
          isExpanded: true,
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

  void _syncState(
    List<ClientQuestionnaireTemplate> templates,
    List<ClientQuestionnaire> questionnaires,
  ) {
    if (_isSaving || _isAssigningQuestionnaires) {
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
      _showQuestionnaireEditor = false;
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
      ).showAppSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final answers = _collectAnswers(template);
    final now = DateTime.now();
    final existingQuestionnaire =
        _currentQuestionnaireId == null
            ? null
            : questionnaires.firstWhereOrNull(
              (item) => item.id == _currentQuestionnaireId,
            );
    final questionnaire = ClientQuestionnaire(
      id: _currentQuestionnaireId ?? _uuid.v4(),
      clientId: widget.client.id,
      salonId: widget.client.salonId,
      templateId: template.id,
      answers: answers,
      createdAt: _currentCreatedAt ?? now,
      updatedAt: now,
      status: ClientQuestionnaireStatus.completed,
      assignedToClientApp: existingQuestionnaire?.assignedToClientApp ?? false,
      assignedAt: existingQuestionnaire?.assignedAt,
      assignedByUserId: existingQuestionnaire?.assignedByUserId,
      completedAt: now,
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Questionario aggiornato.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
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

enum _QuestionnaireDashboardFilter { assigned, available, all }

class _QuestionnaireTemplateSummary {
  const _QuestionnaireTemplateSummary({
    required this.template,
    required this.latestQuestionnaire,
    required this.totalSections,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.progressPercent,
    required this.hasOpenAppAssignment,
    required this.sectionSummaries,
  });

  final ClientQuestionnaireTemplate template;
  final ClientQuestionnaire? latestQuestionnaire;
  final int totalSections;
  final int totalQuestions;
  final int answeredQuestions;
  final int progressPercent;
  final bool hasOpenAppAssignment;
  final List<_QuestionnaireSectionSummary> sectionSummaries;
}

class _QuestionnaireSectionSummary {
  const _QuestionnaireSectionSummary({
    required this.group,
    required this.totalQuestions,
    required this.answeredQuestions,
  });

  final ClientQuestionGroup group;
  final int totalQuestions;
  final int answeredQuestions;

  int get progressPercent {
    if (totalQuestions == 0) {
      return 0;
    }
    return ((answeredQuestions / totalQuestions) * 100).round();
  }
}

class _ClientPhotosCardState extends ConsumerState<_ClientPhotosCard> {
  final Set<String> _deleting = <String>{};
  final Set<String> _deletingCollages = <String>{};
  final Set<String> _updatingNotes = <String>{};
  final TextEditingController _noteController = TextEditingController();
  bool _isUploading = false;
  bool _areCollagesExpanded = false;
  ClientPhotoPrivacyConfirmation? _photoPrivacyConfirmation;
  final Uuid _uuid = const Uuid();
  static const int _maxUploadBytes = 10 * 1024 * 1024;
  static const String _photoPrivacyConfirmationVersion =
      'photo-privacy-2026-06-05';
  static const List<ClientPhotoSetType> _orderedPhotoSets =
      <ClientPhotoSetType>[
        ClientPhotoSetType.front,
        ClientPhotoSetType.back,
        ClientPhotoSetType.right,
        ClientPhotoSetType.left,
      ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = ref.watch(clientPhotosProvider(widget.client.id));
    final collages = ref.watch(clientPhotoCollagesProvider(widget.client.id));
    final Map<ClientPhotoSetType, List<ClientPhoto>> grouped =
        <ClientPhotoSetType, List<ClientPhoto>>{};
    for (final type in _orderedPhotoSets) {
      final setPhotos =
          photos.where((photo) => photo.setType == type).toList()
            ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      grouped[type] = setPhotos;
    }
    final otherPhotos =
        photos.where((photo) => photo.setType == null).toList()
          ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    final sortedCollages =
        collages.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final photoCount = photos.length;
    final collageCount = collages.length;
    final completedSets =
        grouped.values.where((list) {
          for (final photo in list) {
            if (photo.isSetActiveVersion) {
              return true;
            }
          }
          return false;
        }).length;

    late final String subtitle;
    if (photoCount == 0) {
      subtitle =
          collageCount == 0 ? 'Nessuna foto' : '0 foto · $collageCount collage';
    } else {
      final base = '$completedSets/4 set completati · $photoCount foto';
      subtitle = collageCount == 0 ? base : '$base · $collageCount collage';
    }

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
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final actions = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
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
                    FilledButton.icon(
                      onPressed: () => _openCollageEditor(),
                      icon: const Icon(Icons.auto_awesome_motion, size: 18),
                      label: const Text('Crea collage'),
                    ),
                  ],
                );
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Archivio fotografico',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 14),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 14.0;
                final columns =
                    constraints.maxWidth >= 1040
                        ? 4
                        : constraints.maxWidth >= 720
                        ? 2
                        : 1;
                final tileWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _orderedPhotoSets
                      .map((type) {
                        final setPhotos =
                            grouped[type] ?? const <ClientPhoto>[];
                        final activePhoto = _resolveActivePhoto(setPhotos);
                        return SizedBox(
                          width: tileWidth,
                          child: _ClientPhotoSetPreview(
                            label: _setLabel(type),
                            isComplete: activePhoto != null,
                            activePhoto: activePhoto,
                            isUploading: _isUploading,
                            onUpload: () => _pickAndUpload(type),
                            onShowHistory: () => _showSetHistory(type),
                            onPreviewActive:
                                activePhoto == null
                                    ? null
                                    : () => _previewPhoto(activePhoto),
                            isDeletingSet: setPhotos.any(
                              (photo) => _deleting.contains(photo.id),
                            ),
                            onDeleteSet:
                                setPhotos.isEmpty
                                    ? null
                                    : () => _deletePhotoSet(type),
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : () => _pickAndUploadFullSet(),
                icon: const Icon(Icons.grid_on_outlined, size: 18),
                label: const Text('Carica set completo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (sortedCollages.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCollagesSection(theme, sortedCollages),
            ],
            if (otherPhotos.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Altre foto', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: otherPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final photo = otherPhotos[index];
                  final isDeleting = _deleting.contains(photo.id);
                  final isUpdating = _updatingNotes.contains(photo.id);
                  return _ClientPhotoTile(
                    photo: photo,
                    isDeleting: isDeleting,
                    isUpdating: isUpdating,
                    isActiveVersion: photo.isSetActiveVersion,
                    setLabel:
                        photo.setType != null
                            ? _setLabel(photo.setType!)
                            : null,
                    versionIndex: photo.setVersionIndex,
                    onPreview: () => _previewPhoto(photo),
                    onEditNote: () => _editNote(photo),
                    onDelete: () => _deletePhoto(photo),
                    onSetActive:
                        photo.setType != null && !photo.isSetActiveVersion
                            ? () => _setActiveVersion(photo)
                            : null,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollagesSection(
    ThemeData theme,
    List<ClientPhotoCollage> sortedCollages,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap:
                  () => setState(
                    () => _areCollagesExpanded = !_areCollagesExpanded,
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collage salvati',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sortedCollages.length} collage',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: _areCollagesExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child:
                  _areCollagesExpanded
                      ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedCollages.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final collage = sortedCollages[index];
                            final isDeleting = _deletingCollages.contains(
                              collage.id,
                            );
                            return _ClientCollageTile(
                              collage: collage,
                              isDeleting: isDeleting,
                              onPreview: () => _previewCollage(collage),
                              onDelete: () => _deleteCollage(collage),
                            );
                          },
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Future<ClientPhotoPrivacyConfirmation?>
  _requestPhotoPrivacyConfirmation() async {
    final session = ref.read(sessionControllerProvider);
    final cached = _photoPrivacyConfirmation;
    if (cached != null) {
      return cached.copyWith(
        confirmedAt: DateTime.now(),
        confirmedBy: session.uid ?? cached.confirmedBy,
      );
    }
    var purpose = ClientPhotoPrivacyPurpose.treatmentDocumentation;
    var legalBasis = ClientPhotoLegalBasis.contractOrPrecontract;
    var specialCategoryRisk = true;
    var accepted = false;

    final confirmation = await showDialog<ClientPhotoPrivacyConfirmation>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Responsabilita privacy salone'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conferma una sola volta per questa sessione di lavoro sull archivio foto. Ogni foto caricata salvera finalita, base giuridica e autore della conferma.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ClientPhotoPrivacyPurpose>(
                      initialValue: purpose,
                      decoration: const InputDecoration(
                        labelText: 'Finalita',
                        border: OutlineInputBorder(),
                      ),
                      items: ClientPhotoPrivacyPurpose.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_photoPurposeLabel(value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged:
                          (value) => setDialogState(() {
                            if (value != null) {
                              purpose = value;
                              if (value ==
                                  ClientPhotoPrivacyPurpose
                                      .marketingPublication) {
                                legalBasis =
                                    ClientPhotoLegalBasis.explicitConsent;
                              }
                            }
                          }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ClientPhotoLegalBasis>(
                      key: ValueKey<String>(legalBasis.name),
                      initialValue: legalBasis,
                      decoration: const InputDecoration(
                        labelText: 'Base giuridica dichiarata dal salone',
                        border: OutlineInputBorder(),
                      ),
                      items: ClientPhotoLegalBasis.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_photoLegalBasisLabel(value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged:
                          (value) => setDialogState(() {
                            if (value != null) {
                              legalBasis = value;
                            }
                          }),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: specialCategoryRisk,
                      onChanged:
                          (value) => setDialogState(
                            () => specialCategoryRisk = value ?? true,
                          ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Foto potenzialmente sensibile'),
                      subtitle: const Text(
                        'Usa questa opzione per foto che possono mostrare corpo, pelle, trattamenti o condizioni fisiche.',
                      ),
                    ),
                    CheckboxListTile(
                      value: accepted,
                      onChanged:
                          (value) =>
                              setDialogState(() => accepted = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Confermo la responsabilita privacy del salone',
                      ),
                      subtitle: const Text(
                        'Il cliente ha ricevuto l informativa e il salone dispone della base giuridica indicata. Le foto non saranno usate per riconoscimento biometrico automatico o training AI.',
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
                  onPressed:
                      accepted
                          ? () {
                            Navigator.of(dialogContext).pop(
                              ClientPhotoPrivacyConfirmation(
                                purpose: purpose,
                                legalBasis: legalBasis,
                                confirmedAt: DateTime.now(),
                                confirmedBy: session.uid ?? 'unknown',
                                confirmationVersion:
                                    _photoPrivacyConfirmationVersion,
                                specialCategoryRisk: specialCategoryRisk,
                                biometricProcessing: false,
                              ),
                            );
                          }
                          : null,
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmation != null && mounted) {
      setState(() => _photoPrivacyConfirmation = confirmation);
    }
    return confirmation;
  }

  Future<void> _pickAndUpload(ClientPhotoSetType setType) async {
    final privacy = await _requestPhotoPrivacyConfirmation();
    if (privacy == null || !mounted) {
      return;
    }
    final selectedFile = await _pickSingleImageFile();
    if (selectedFile == null) {
      return;
    }
    final files = <_PickedClientImage>[selectedFile];

    final existing = ref.read(clientPhotosProvider(widget.client.id));
    final setPhotos = existing
        .where((photo) => photo.setType == setType)
        .toList(growable: false);
    var maxVersion = 0;
    for (final photo in setPhotos) {
      final version = photo.setVersionIndex ?? 0;
      if (version > maxVersion) {
        maxVersion = version;
      }
    }
    var nextVersionIndex = maxVersion + 1;

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
      String? lastUploadedPhotoId;
      for (final file in files) {
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
          setType: setType,
          setVersionIndex: nextVersionIndex,
          isSetActiveVersion: true,
          privacy: privacy,
        );
        await dataStore.upsertClientPhoto(photo);
        uploadedCount += 1;
        lastUploadedPhotoId = photo.id;
        nextVersionIndex += 1;
      }
      if (lastUploadedPhotoId != null) {
        await _tryActivatePhotoVersion(
          clientId: widget.client.id,
          setType: setType,
          photoId: lastUploadedPhotoId,
        );
      }
      if (!mounted) {
        return;
      }
      if (uploadedCount > 0) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              uploadedCount == 1
                  ? 'Foto caricata correttamente nel set ${_setLabel(setType)}.'
                  : '$uploadedCount foto caricate nel set ${_setLabel(setType)}.',
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
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _tryActivatePhotoVersion({
    required String clientId,
    required ClientPhotoSetType setType,
    required String photoId,
  }) async {
    try {
      await ref
          .read(appDataProvider.notifier)
          .activateClientPhotoVersion(
            clientId: clientId,
            setType: setType,
            photoId: photoId,
          );
      return true;
    } catch (error) {
      debugPrint('Client photo version activation skipped: $error');
      return false;
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
    final setType = photo.setType;
    final wasActive = photo.isSetActiveVersion;
    ClientPhoto? fallbackVersion;
    if (setType != null && wasActive) {
      final siblings = ref
          .read(clientPhotosProvider(widget.client.id))
          .where(
            (element) => element.id != photo.id && element.setType == setType,
          )
          .toList(growable: false);
      siblings.sort((a, b) {
        final versionA = a.setVersionIndex ?? 0;
        final versionB = b.setVersionIndex ?? 0;
        if (versionA != versionB) {
          return versionB.compareTo(versionA);
        }
        return b.uploadedAt.compareTo(a.uploadedAt);
      });
      if (siblings.isNotEmpty) {
        fallbackVersion = siblings.first;
      }
    }

    setState(() => _deleting.add(photo.id));
    try {
      await dataStore.deleteClientPhoto(photo.id);
      await storage.deleteFile(photo.storagePath);
      final fallback = fallbackVersion;
      if (fallback != null && fallback.setType != null) {
        await _tryActivatePhotoVersion(
          clientId: widget.client.id,
          setType: fallback.setType!,
          photoId: fallback.id,
        );
      }
      if (!mounted) {
        return;
      }
      final successMessage =
          fallbackVersion == null
              ? 'Foto eliminata.'
              : 'Foto eliminata. Versione precedente impostata come attiva.';
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
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

  Future<void> _deletePhotoSet(ClientPhotoSetType setType) async {
    final photos = ref
        .read(clientPhotosProvider(widget.client.id))
        .where((photo) => photo.setType == setType)
        .toList(growable: false);
    if (photos.isEmpty || photos.any((photo) => _deleting.contains(photo.id))) {
      return;
    }

    final setLabel = _setLabel(setType);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Elimina set $setLabel'),
          content: Text(
            'Verranno eliminate definitivamente ${photos.length} foto del set $setLabel, incluse le versioni storiche, sia dall archivio sia dal cloud storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina set'),
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
    final deletingIds = photos.map((photo) => photo.id).toSet();

    setState(() => _deleting.addAll(deletingIds));
    try {
      for (final photo in photos) {
        await dataStore.deleteClientPhoto(photo.id);
        await storage.deleteFile(photo.storagePath);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text('Set $setLabel eliminato.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Non è stato possibile eliminare il set: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting.removeAll(deletingIds));
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
      ).showAppSnackBar(const SnackBar(content: Text('Nota aggiornata.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final mediaQuery = MediaQuery.of(dialogContext);
        final uploadedAtLabel = DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(photo.uploadedAt.toLocal());
        final titleParts = <String>[
          if (photo.setType != null) _setLabel(photo.setType!),
          if (photo.setVersionIndex != null) 'v${photo.setVersionIndex}',
        ];
        final title =
            titleParts.isEmpty
                ? (photo.fileName?.trim().isNotEmpty ?? false)
                    ? photo.fileName!.trim()
                    : 'Anteprima foto'
                : titleParts.join(' • ');
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(mediaQuery.size.width - 36, 920),
                maxHeight: mediaQuery.size.height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Caricata il $uploadedAtLabel',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox.expand(
                            child: Center(
                              child: Image.network(
                                photo.downloadUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  final expectedBytes =
                                      loadingProgress.expectedTotalBytes;
                                  final loadedBytes =
                                      loadingProgress.cumulativeBytesLoaded;
                                  final value =
                                      expectedBytes == null
                                          ? null
                                          : loadedBytes / expectedBytes;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(value: value),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Caricamento foto…',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: Colors.white70),
                                      ),
                                    ],
                                  );
                                },
                                errorBuilder:
                                    (_, __, ___) => Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white70,
                                            size: 40,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Impossibile mostrare la foto.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (photo.notes != null && photo.notes!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Note foto',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              photo.notes!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  Future<void> _showSetHistory(ClientPhotoSetType setType) async {
    final setLabel = _setLabel(setType);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final sheetHeight = mediaQuery.size.height * 0.7;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: mediaQuery.viewInsets.bottom + 16,
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final photos = ref.watch(
                  clientPhotosProvider(widget.client.id),
                );
                final setPhotos =
                    photos.where((photo) => photo.setType == setType).toList()
                      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

                if (setPhotos.isEmpty) {
                  return SizedBox(
                    height: mediaQuery.size.height * 0.4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Versioni $setLabel',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Chiudi',
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Non sono ancora presenti versioni salvate per questo set.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox(
                  height: sheetHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Versioni $setLabel',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: setPhotos.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final photo = setPhotos[index];
                            final isDeleting = _deleting.contains(photo.id);
                            final isUpdating = _updatingNotes.contains(
                              photo.id,
                            );
                            return _ClientPhotoTile(
                              photo: photo,
                              isDeleting: isDeleting,
                              isUpdating: isUpdating,
                              isActiveVersion: photo.isSetActiveVersion,
                              setLabel:
                                  photo.setType != null
                                      ? _setLabel(photo.setType!)
                                      : null,
                              versionIndex: photo.setVersionIndex,
                              onPreview: () => _previewPhoto(photo),
                              onEditNote: () => _editNote(photo),
                              onDelete: () => _deletePhoto(photo),
                              onSetActive:
                                  photo.isSetActiveVersion
                                      ? null
                                      : () => _setActiveVersion(photo),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _setActiveVersion(ClientPhoto photo) async {
    final setType = photo.setType;
    if (setType == null) {
      return;
    }
    final dataStore = ref.read(appDataProvider.notifier);
    try {
      await dataStore.activateClientPhotoVersion(
        clientId: widget.client.id,
        setType: setType,
        photoId: photo.id,
      );
      if (!mounted) {
        return;
      }
      final versionSuffix =
          photo.setVersionIndex == null ? '' : ' (v${photo.setVersionIndex})';
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            '${_setLabel(setType)} aggiornato$versionSuffix come versione attiva.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Impossibile impostare la versione attiva: $error'),
        ),
      );
    }
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

  String _orientationLabel(ClientPhotoCollageOrientation orientation) {
    switch (orientation) {
      case ClientPhotoCollageOrientation.vertical:
        return 'Verticale';
      case ClientPhotoCollageOrientation.horizontal:
        return 'Orizzontale';
    }
  }

  static String _photoPurposeLabel(ClientPhotoPrivacyPurpose purpose) {
    switch (purpose) {
      case ClientPhotoPrivacyPurpose.treatmentDocumentation:
        return 'Documentazione trattamento';
      case ClientPhotoPrivacyPurpose.beforeAfterComparison:
        return 'Confronto prima/dopo';
      case ClientPhotoPrivacyPurpose.clientAppSharing:
        return 'Condivisione con cliente';
      case ClientPhotoPrivacyPurpose.marketingPublication:
        return 'Marketing o pubblicazione';
    }
  }

  static String _photoLegalBasisLabel(ClientPhotoLegalBasis basis) {
    switch (basis) {
      case ClientPhotoLegalBasis.contractOrPrecontract:
        return 'Contratto o misure precontrattuali';
      case ClientPhotoLegalBasis.explicitConsent:
        return 'Consenso esplicito';
      case ClientPhotoLegalBasis.legalObligation:
        return 'Obbligo di legge';
      case ClientPhotoLegalBasis.legitimateInterest:
        return 'Legittimo interesse';
    }
  }

  Future<void> _openCollageEditor() async {
    final initialNote = _noteController.text.trim();
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final useDedicatedPage =
        size.shortestSide < 600 && (size.width < 700 || size.height < 900);

    final result =
        useDedicatedPage
            ? await Navigator.of(context).push<String?>(
              MaterialPageRoute<String?>(
                fullscreenDialog: true,
                builder:
                    (_) => CollageEditorDialog(
                      client: widget.client,
                      initialNote: initialNote.isEmpty ? null : initialNote,
                    ),
              ),
            )
            : await showDialog<String?>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) {
                return Dialog.fullscreen(
                  child: CollageEditorDialog(
                    client: widget.client,
                    initialNote: initialNote.isEmpty ? null : initialNote,
                  ),
                );
              },
            );
    if (!mounted || result == null || result.isEmpty) {
      return;
    }
    final message = result;
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(message)));
  }

  void _previewCollage(ClientPhotoCollage collage) {
    final imageUrl = collage.downloadUrl ?? collage.thumbnailUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Anteprima collage non disponibile.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final mediaQuery = MediaQuery.of(dialogContext);
        final titleDate = DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(collage.createdAt.toLocal());
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(18),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(mediaQuery.size.width - 36, 920),
                maxHeight: mediaQuery.size.height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Collage del $titleDate',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _orientationLabel(collage.orientation),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox.expand(
                            child: Center(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  final expectedBytes =
                                      loadingProgress.expectedTotalBytes;
                                  final loadedBytes =
                                      loadingProgress.cumulativeBytesLoaded;
                                  final value =
                                      expectedBytes == null
                                          ? null
                                          : loadedBytes / expectedBytes;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(value: value),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Caricamento collage…',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: Colors.white70),
                                      ),
                                    ],
                                  );
                                },
                                errorBuilder:
                                    (_, __, ___) => Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white70,
                                            size: 40,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Impossibile mostrare il collage.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dettagli collage',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Orientamento: ${_orientationLabel(collage.orientation)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prima: ${collage.primaryPlacement.photoId}\nFoto B: ${collage.secondaryPlacement.photoId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (collage.notes != null &&
                              collage.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Note collage',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    collage.notes!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteCollage(ClientPhotoCollage collage) async {
    if (_deletingCollages.contains(collage.id)) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Elimina collage'),
          content: const Text(
            'Il collage verrà rimosso definitivamente dall\'archivio cliente.',
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

    setState(() => _deletingCollages.add(collage.id));
    try {
      await dataStore.deleteClientPhotoCollage(collage.id);
      if (collage.storagePath != null && collage.storagePath!.isNotEmpty) {
        await storage.deleteFile(collage.storagePath!);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(const SnackBar(content: Text('Collage eliminato.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile eliminare il collage: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingCollages.remove(collage.id));
      }
    }
  }

  Future<void> _pickAndUploadFullSet() async {
    final privacy = await _requestPhotoPrivacyConfirmation();
    if (privacy == null || !mounted) {
      return;
    }
    final files = await _pickImageFiles(maxSelection: _orderedPhotoSets.length);
    if (files.isEmpty) {
      return;
    }
    if (files.length < _orderedPhotoSets.length) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Seleziona quattro foto per coprire Frontale, Dietro, Destra e Sinistra.',
          ),
        ),
      );
      return;
    }
    final assignments = await _showFullSetAssignmentDialog(files);
    if (assignments == null || assignments.isEmpty) {
      return;
    }

    final storage = ref.read(firebaseStorageServiceProvider);
    final dataStore = ref.read(appDataProvider.notifier);
    final session = ref.read(sessionControllerProvider);
    final uploaderId = session.uid ?? 'unknown';
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;
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
          notes: note,
          setType: assignment.setType,
          setVersionIndex: versionIndex,
          isSetActiveVersion: true,
          privacy: privacy,
        );
        await dataStore.upsertClientPhoto(photo);
        lastUploadedBySet[assignment.setType] = photo.id;
        uploadedCount += 1;
      }

      for (final entry in lastUploadedBySet.entries) {
        await _tryActivatePhotoVersion(
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
              uploadedCount == _orderedPhotoSets.length
                  ? 'Set fotografico caricato correttamente.'
                  : '$uploadedCount foto del set caricate correttamente.',
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
        SnackBar(content: Text('Impossibile caricare il set: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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

  Future<List<_PhotoSetAssignment>?> _showFullSetAssignmentDialog(
    List<_PickedClientImage> files,
  ) async {
    return showDialog<List<_PhotoSetAssignment>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final List<ClientPhotoSetType?> selections =
            List<ClientPhotoSetType?>.generate(
              files.length,
              (index) =>
                  index < _orderedPhotoSets.length
                      ? _orderedPhotoSets[index]
                      : null,
            );
        String? error;
        return StatefulBuilder(
          builder: (context, setState) {
            void validateSelection() {
              if (selections.any((element) => element == null)) {
                setState(() {
                  error = 'Associa ogni file a un set.';
                });
                return;
              }
              final uniqueCount =
                  selections.whereType<ClientPhotoSetType>().toSet().length;
              if (uniqueCount != selections.length) {
                setState(() {
                  error = 'Ogni set può essere utilizzato una sola volta.';
                });
                return;
              }
              setState(() => error = null);
              Navigator.of(dialogContext).pop(
                List<_PhotoSetAssignment>.generate(
                  files.length,
                  (index) => _PhotoSetAssignment(
                    file: files[index],
                    setType: selections[index]!,
                  ),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Associa le foto ai set'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Abbina ogni file alla vista corretta (Frontale, Dietro, Destra, Sinistra).',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < files.length; i++) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              margin: const EdgeInsets.only(right: 12, top: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: theme.colorScheme.surfaceVariant,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  files[i].bytes != null &&
                                          files[i].bytes!.isNotEmpty
                                      ? Image.memory(
                                        files[i].bytes!,
                                        fit: BoxFit.cover,
                                      )
                                      : const Icon(Icons.photo_outlined),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<ClientPhotoSetType>(
                                    isExpanded: true,
                                    value: selections[i],
                                    decoration: const InputDecoration(
                                      labelText: 'Set assegnato',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _orderedPhotoSets
                                        .map(
                                          (type) => DropdownMenuItem(
                                            value: type,
                                            child: Text(_setLabel(type)),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      setState(() {
                                        selections[i] = value;
                                        error = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => validateSelection(),
                  child: const Text('Conferma set'),
                ),
              ],
            );
          },
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
    required this.isActiveVersion,
    this.setLabel,
    this.versionIndex,
    required this.onPreview,
    required this.onEditNote,
    required this.onDelete,
    this.onSetActive,
  });

  final ClientPhoto photo;
  final bool isDeleting;
  final bool isUpdating;
  final bool isActiveVersion;
  final String? setLabel;
  final int? versionIndex;
  final VoidCallback onPreview;
  final VoidCallback onEditNote;
  final VoidCallback onDelete;
  final VoidCallback? onSetActive;

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

    final activateAction =
        onSetActive == null
            ? null
            : IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.history_toggle_off),
              tooltip: 'Imposta come versione attiva',
              color: theme.colorScheme.primary,
              onPressed: onSetActive,
            );

    final actionChildren = <Widget>[];
    if (activateAction != null) {
      actionChildren
        ..add(activateAction)
        ..add(const SizedBox(width: 8));
    }
    actionChildren
      ..add(editAction)
      ..add(const SizedBox(width: 8))
      ..add(deleteAction);

    final metaDetails = <String>[];
    if (setLabel != null && setLabel!.isNotEmpty) {
      metaDetails.add('Set $setLabel');
    }
    if (versionIndex != null && versionIndex! > 0) {
      metaDetails.add('Versione ${versionIndex!}');
    }

    return ListTile(
      onTap: onPreview,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              fileLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isActiveVersion)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ),
        ],
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Caricata il $uploadedAt',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (metaDetails.isNotEmpty)
            Text(metaDetails.join(' · '), style: theme.textTheme.bodySmall),
          Text(
            isActiveVersion ? 'Versione attiva' : 'Versione storica',
            style: theme.textTheme.labelSmall?.copyWith(
              color:
                  isActiveVersion
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (photo.notes != null && photo.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                photo.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: actionChildren),
    );
  }
}

class _ClientPhotoSetPreview extends StatelessWidget {
  const _ClientPhotoSetPreview({
    required this.label,
    required this.isComplete,
    required this.activePhoto,
    required this.isUploading,
    required this.onUpload,
    required this.onShowHistory,
    this.isDeletingSet = false,
    this.onDeleteSet,
    this.onPreviewActive,
  });

  final String label;
  final bool isComplete;
  final ClientPhoto? activePhoto;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onShowHistory;
  final bool isDeletingSet;
  final VoidCallback? onDeleteSet;
  final VoidCallback? onPreviewActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview =
        activePhoto == null
            ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nessuna foto caricata',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
            : GestureDetector(
              onTap: onPreviewActive,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  activePhoto!.downloadUrl,
                  fit: BoxFit.cover,
                ),
              ),
            );
    final updatedAt = activePhoto?.uploadedAt;
    final updatedLabel =
        updatedAt == null
            ? 'Nessuna foto caricata'
            : 'Aggiornato il ${DateFormat('dd/MM/yyyy HH:mm').format(updatedAt.toLocal())}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isDeletingSet)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              Icon(
                isComplete ? Icons.check_circle_rounded : Icons.photo_outlined,
                size: 16,
                color:
                    isComplete
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              if (onDeleteSet != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Elimina set',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: theme.colorScheme.error,
                  onPressed: onDeleteSet,
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPreviewActive,
            child: Ink(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Center(child: preview),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          updatedLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isUploading ? null : onUpload,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Carica'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShowHistory,
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('Storico'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClientCollageTile extends StatelessWidget {
  const _ClientCollageTile({
    required this.collage,
    required this.isDeleting,
    required this.onPreview,
    required this.onDelete,
  });

  final ClientPhotoCollage collage;
  final bool isDeleting;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              tooltip: 'Elimina collage',
              color: theme.colorScheme.error,
              onPressed: onDelete,
            );

    final previewUrl = collage.thumbnailUrl ?? collage.downloadUrl;
    final previewThumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child:
          previewUrl == null || previewUrl.isEmpty
              ? Container(
                width: 72,
                height: 72,
                color: theme.colorScheme.surfaceVariant,
                child: Icon(
                  Icons.photo_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
              : Image.network(
                previewUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
    );

    return ListTile(
      onTap: onPreview,
      leading: previewThumbnail,
      title: Text(
        'Collage ${DateFormat('dd/MM/yyyy').format(collage.createdAt.toLocal())}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (collage.notes != null && collage.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                collage.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
      trailing: deleteAction,
    );
  }
}

class _PhotoSetAssignment {
  const _PhotoSetAssignment({required this.file, required this.setType});

  final _PickedClientImage file;
  final ClientPhotoSetType setType;
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
    final upcomingAppointmentNumberById = <String, int>{
      for (var index = 0; index < upcoming.length; index++)
        upcoming[index].id: index + 1,
    };
    final historyAppointmentNumberById = <String, int>{
      for (var index = 0; index < appointments.length; index++)
        appointments[index].id: index + 1,
    };

    Future<void> openForm({Appointment? existing}) async {
      final latest = ref.read(appDataProvider);
      final sheetSalons = latest.salons.isNotEmpty ? latest.salons : salons;
      final sheetClients = latest.clients.isNotEmpty ? latest.clients : clients;
      final sheetStaff = latest.staff.isNotEmpty ? latest.staff : staff;
      final sheetServices =
          latest.services.isNotEmpty ? latest.services : services;
      final sheetCategories =
          latest.serviceCategories.isNotEmpty
              ? latest.serviceCategories
              : data.serviceCategories;

      final result = await showAppModalSheet<AppointmentFormResult>(
        context: context,
        includeCloseButton: false,
        desktopMaxWidth: 1160,
        builder:
            (ctx) => AppointmentSaleFlowSheet(
              salons: sheetSalons,
              clients: sheetClients,
              staff: sheetStaff,
              services: sheetServices,
              serviceCategories: sheetCategories,
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
        final copiedAppointment = result.appointment.copyWith(
          status: AppointmentStatus.scheduled,
          notes: null,
        );
        ref
            .read(appointmentClipboardProvider.notifier)
            .state = AppointmentClipboard(
          appointment: copiedAppointment,
          copiedAt: DateTime.now(),
        );
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Appuntamento copiato. Seleziona uno slot libero.'),
          ),
        );
        return;
      }
      if (result.action == AppointmentFormAction.delete) {
        return;
      }
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
        messenger.showAppSnackBar(
          const SnackBar(content: Text('Appuntamento eliminato.')),
        );
      } catch (error) {
        messenger.showAppSnackBar(
          SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
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
          appointmentNumberById: upcomingAppointmentNumberById,
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
          appointmentNumberById: historyAppointmentNumberById,
        ),
      ],
    );
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
    required this.appointmentNumberById,
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
  final Map<String, int> appointmentNumberById;
  final bool enableActions;
  final Future<void> Function(Appointment appointment)? onEditAppointment;
  final Future<void> Function(Appointment appointment)? onDeleteAppointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showActions =
        enableActions &&
        (onEditAppointment != null || onDeleteAppointment != null);
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final rows = appointments
        .map((appointment) {
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
          final appointmentNumber = appointmentNumberById[appointment.id] ?? 0;
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
          final start = appointment.start.toLocal();
          final end = appointment.end.toLocal();
          final appointmentLabel =
              DateUtils.isSameDay(start, end)
                  ? '${dateFormat.format(start)} - ${timeFormat.format(end)}'
                  : '${dateFormat.format(start)} • ${dateFormat.format(end)}';
          final statusInfo = _statusBadge(appointment.status);
          return _AppointmentCompactRowData(
            appointmentNumber: appointmentNumber,
            serviceLabel: serviceLabel,
            appointmentLabel: appointmentLabel,
            operatorLabel: operator?.fullName ?? 'Da assegnare',
            packageLabel: packageLabel,
            amountLabel: amount != null ? currency.format(amount) : '—',
            status: statusInfo.status,
            statusLabel: statusInfo.label,
            onEdit:
                showActions && onEditAppointment != null
                    ? () async {
                      await onEditAppointment!(appointment);
                    }
                    : null,
            onDelete:
                showActions && onDeleteAppointment != null
                    ? () async {
                      await onDeleteAppointment!(appointment);
                    }
                    : null,
          );
        })
        .toList(growable: false);

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
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (appointments.isEmpty)
              Text(emptyMessage, style: theme.textTheme.bodyMedium)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 860) {
                    return Column(
                      children: rows
                          .asMap()
                          .entries
                          .map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom:
                                      index == rows.length - 1
                                          ? BorderSide.none
                                          : BorderSide(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .outlineVariant,
                                          ),
                                ),
                              ),
                              child: _AppointmentCompactMobileRow(row: row),
                            );
                          })
                          .toList(growable: false),
                    );
                  }

                  final columns = <DataColumn>[
                    const DataColumn(label: Text('N.')),
                    const DataColumn(label: Text('Appuntamento')),
                    const DataColumn(label: Text('Servizio')),
                    const DataColumn(label: Text('Operatore')),
                    const DataColumn(label: Text('Importo')),
                    const DataColumn(label: Text('Stato')),
                  ];
                  if (showActions) {
                    columns.add(const DataColumn(label: Text('Azioni')));
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 72,
                        columns: columns,
                        rows: rows
                            .map((row) {
                              final cells = <DataCell>[
                                DataCell(
                                  Text(
                                    row.appointmentNumberLabel,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(Text(row.appointmentLabel)),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 180,
                                      maxWidth: 280,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.serviceLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (row.packageLabel != null)
                                          Text(
                                            row.packageLabel!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row.operatorLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row.amountLabel,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  StatusBadge(
                                    status: row.status,
                                    label: row.statusLabel,
                                  ),
                                ),
                              ];
                              if (showActions) {
                                cells.add(
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (row.onEdit != null)
                                          IconButton(
                                            tooltip: 'Modifica appuntamento',
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                            ),
                                            onPressed: row.onEdit,
                                          ),
                                        if (row.onDelete != null)
                                          IconButton(
                                            tooltip: 'Elimina appuntamento',
                                            visualDensity:
                                                VisualDensity.compact,
                                            color: theme.colorScheme.error,
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                            ),
                                            onPressed: row.onDelete,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return DataRow(cells: cells);
                            })
                            .toList(growable: false),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  _AppointmentStatusBadgeData _statusBadge(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.scheduled:
        return const _AppointmentStatusBadgeData(
          status: BadgeStatus.pending,
          label: 'Programmato',
        );
      case AppointmentStatus.completed:
        return const _AppointmentStatusBadgeData(
          status: BadgeStatus.success,
          label: 'Completato',
        );
      case AppointmentStatus.cancelled:
        return const _AppointmentStatusBadgeData(
          status: BadgeStatus.cancelled,
          label: 'Annullato',
        );
      case AppointmentStatus.noShow:
        return const _AppointmentStatusBadgeData(
          status: BadgeStatus.cancelled,
          label: 'No show',
        );
    }
  }
}

class _AppointmentCompactRowData {
  const _AppointmentCompactRowData({
    required this.appointmentNumber,
    required this.serviceLabel,
    required this.appointmentLabel,
    required this.operatorLabel,
    required this.amountLabel,
    required this.status,
    required this.statusLabel,
    this.packageLabel,
    this.onEdit,
    this.onDelete,
  });

  final int appointmentNumber;
  final String serviceLabel;
  final String appointmentLabel;
  final String operatorLabel;
  final String amountLabel;
  final BadgeStatus status;
  final String statusLabel;
  final String? packageLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String get appointmentNumberLabel =>
      appointmentNumber > 0 ? '#$appointmentNumber' : '—';
}

class _AppointmentStatusBadgeData {
  const _AppointmentStatusBadgeData({
    required this.status,
    required this.label,
  });

  final BadgeStatus status;
  final String label;
}

class _AppointmentCompactMobileRow extends StatelessWidget {
  const _AppointmentCompactMobileRow({required this.row});

  final _AppointmentCompactRowData row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _AppointmentMobileDataField(
          label: 'N. appuntamento',
          value: row.appointmentNumberLabel,
          valueColor: scheme.primary,
        ),
        _AppointmentMobileDataField(
          label: 'Appuntamento',
          value: row.appointmentLabel,
        ),
        _AppointmentMobileDataField(
          label: 'Servizio',
          value: row.serviceLabel,
          subtitle: row.packageLabel,
        ),
        _AppointmentMobileDataField(
          label: 'Operatore',
          value: row.operatorLabel,
        ),
        _AppointmentMobileDataField(
          label: 'Importo',
          value: row.amountLabel,
          valueColor: scheme.primary,
        ),
        _AppointmentMobileDataFieldWidget(
          label: 'Stato',
          child: StatusBadge(status: row.status, label: row.statusLabel),
        ),
        if (row.onEdit != null || row.onDelete != null)
          _AppointmentMobileDataFieldWidget(
            label: 'Azioni',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (row.onEdit != null)
                  IconButton(
                    tooltip: 'Modifica appuntamento',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    onPressed: row.onEdit,
                  ),
                if (row.onDelete != null)
                  IconButton(
                    tooltip: 'Elimina appuntamento',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: scheme.error,
                    onPressed: row.onDelete,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AppointmentMobileDataField extends StatelessWidget {
  const _AppointmentMobileDataField({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _AppointmentMobileDataFieldWidget extends StatelessWidget {
  const _AppointmentMobileDataFieldWidget({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}

class _PackagesTab extends ConsumerStatefulWidget {
  const _PackagesTab({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends ConsumerState<_PackagesTab> {
  bool _historyExpanded = false;

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
    final servicesById = {
      for (final service in data.services) service.id: service,
    };
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final active = <ClientPackagePurchase>[];
    final expiring = <ClientPackagePurchase>[];
    final history = <ClientPackagePurchase>[];

    for (final purchase in purchases) {
      if (_isPackageArchived(purchase)) {
        history.add(purchase);
        continue;
      }
      if (_isPackageExpiringSoon(purchase)) {
        expiring.add(purchase);
      } else {
        active.add(purchase);
      }
    }

    int currentSortValue(ClientPackagePurchase purchase) {
      final expiry = purchase.expirationDate;
      if (expiry == null) {
        return 1 << 30;
      }
      return DateUtils.dateOnly(expiry).millisecondsSinceEpoch;
    }

    active.sort((a, b) {
      final compare = currentSortValue(a).compareTo(currentSortValue(b));
      if (compare != 0) {
        return compare;
      }
      return b.sale.createdAt.compareTo(a.sale.createdAt);
    });
    expiring.sort((a, b) {
      final compare = currentSortValue(a).compareTo(currentSortValue(b));
      if (compare != 0) {
        return compare;
      }
      return b.sale.createdAt.compareTo(a.sale.createdAt);
    });
    history.sort((a, b) => b.sale.createdAt.compareTo(a.sale.createdAt));

    final currentPackages = [...active, ...expiring];
    final availableServices = currentPackages.fold<int>(0, (sum, purchase) {
      final activeServices =
          _resolvePackageServiceUsage(
            purchase,
            servicesById,
          ).where((usage) => usage.remaining > 0 || usage.total == null).length;
      return sum + activeServices;
    });
    final currentValue = currentPackages.fold<double>(
      0,
      (sum, purchase) => sum + purchase.totalAmount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        _PackageOverviewMetrics(
          activeCount: active.length,
          availableServicesCount: availableServices,
          totalValue: currentValue,
          currency: currency,
        ),
        const SizedBox(height: 24),
        _PackageGroup(
          title: 'Pacchetti attivi',
          items: currentPackages,
          servicesById: servicesById,
          onEdit: (purchase) => _editPackage(client, purchase),
          onDelete: (purchase) => _deletePackage(client, purchase),
          onAddDeposit: (purchase) => _addDeposit(client, purchase),
          onDeleteDeposit:
              (purchase, deposit) => _removeDeposit(client, purchase, deposit),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 28),
          Card(
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _historyExpanded,
                onExpansionChanged:
                    (value) => setState(() => _historyExpanded = value),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                title: Text(
                  'Storico pacchetti',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${history.length} ${history.length == 1 ? 'pacchetto archiviato' : 'pacchetti archiviati'}',
                ),
                children: [
                  _CompactListSection<ClientPackagePurchase>(
                    items: history,
                    showTitle: false,
                    itemBuilder: (context, purchase, isCompact, showDivider) {
                      void onEdit() => _editPackage(client, purchase);
                      return _BillingCompactRowWidget(
                        data: _buildPackageHistoryRowData(
                          currency,
                          DateFormat('dd/MM/yyyy'),
                          purchase,
                          onTap: onEdit,
                        ),
                        isCompact: isCompact,
                        showDivider: showDivider,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  _BillingCompactRowData _buildPackageHistoryRowData(
    NumberFormat currency,
    DateFormat dateFormat,
    ClientPackagePurchase purchase, {
    VoidCallback? onTap,
  }) {
    final purchaseDate = dateFormat.format(purchase.sale.createdAt);
    final expiry = purchase.expirationDate;
    final lifecycle = _packageLifecycleBadgeData(purchase);
    final payment = _packagePaymentBadgeData(purchase);
    final deposit = _packageDepositTotal(purchase);
    final detailsSubtitleParts = <String>[
      'Pagamento: ${payment.label}',
      'Metodo: ${_PackageGroup._paymentLabel(purchase.sale.paymentMethod)}',
      if (deposit > 0.009) 'Versato ${currency.format(deposit)}',
      if (purchase.outstandingAmount > 0.009)
        'Residuo ${currency.format(purchase.outstandingAmount)}',
    ];

    return _BillingCompactRowData(
      dateLabel: purchaseDate,
      titleLabel: purchase.displayName,
      titleSubtitle:
          purchase.serviceNames.isNotEmpty
              ? purchase.serviceNames.join(', ')
              : null,
      detailsLabel:
          expiry == null
              ? 'Scadenza: senza limite'
              : 'Scadenza: ${dateFormat.format(expiry)}',
      detailsSubtitle: detailsSubtitleParts.join(' • '),
      amountLabel: currency.format(purchase.totalAmount),
      amountSubtitle:
          purchase.outstandingAmount > 0.009
              ? 'Residuo ${currency.format(purchase.outstandingAmount)}'
              : payment.label,
      status: lifecycle.status,
      statusLabel: lifecycle.label,
      onTap: onTap,
      onAction: onTap,
      actionIcon: Icons.edit_rounded,
      actionTooltip: 'Modifica pacchetto',
    );
  }

  double _packageDepositTotal(ClientPackagePurchase purchase) {
    final deposits = purchase.deposits;
    final depositsSum = deposits.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final expectedDeposit = double.parse(
      purchase.depositAmount.toStringAsFixed(2),
    );
    var result = 0.0;
    if (depositsSum > result + 0.009) {
      result = double.parse(depositsSum.toStringAsFixed(2));
    }
    if (expectedDeposit > result + 0.009) {
      result = expectedDeposit;
    }
    return result;
  }

  bool _isPackageArchived(ClientPackagePurchase purchase) {
    if (purchase.status == PackagePurchaseStatus.completed ||
        purchase.status == PackagePurchaseStatus.cancelled) {
      return true;
    }
    final expiry = purchase.expirationDate;
    if (expiry == null) {
      return false;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(expiry).isBefore(today);
  }

  bool _isPackageExpiringSoon(ClientPackagePurchase purchase) {
    if (_isPackageArchived(purchase) ||
        purchase.status != PackagePurchaseStatus.active) {
      return false;
    }
    final expiry = purchase.expirationDate;
    if (expiry == null) {
      return false;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final daysUntilExpiry = DateUtils.dateOnly(expiry).difference(today).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  }

  // ignore: unused_element
  Future<void> _registerPackagePurchase(
    BuildContext context,
    Client client,
  ) async {
    final data = ref.read(appDataProvider);
    final packages =
        data.packages.where((pkg) => pkg.salonId == client.salonId).toList();
    if (packages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
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

  // ignore: unused_element
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Nessun salone disponibile per creare un pacchetto.'),
        ),
      );
      return;
    }

    if (services.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      includeCloseButton: false,
      desktopMaxWidth: 1180,
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
      ScaffoldMessenger.of(context).showAppSnackBar(
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
            usedSessionsByService: purchase.usedSessionsByService,
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

    ScaffoldMessenger.of(context).clearAppSnackBars();
    ScaffoldMessenger.of(context).showAppSnackBar(
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
      clientId: client.id,
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Preventivo ${_quoteLabel(quote)} salvato.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Preventivo ${_quoteLabel(updated)} aggiornato.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Preventivo ${_quoteLabel(quote)} eliminato.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Preventivo inviato via $channelsLabel.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'Preventivo ${_quoteLabel(quote)} accettato: registrata la vendita.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Preventivo ${_quoteLabel(quote)} rifiutato.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'Preventivo ${_quoteLabel(quote)} impostato su "Inviato".',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
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

    final pdfFile = XFile.fromData(
      pdfBytes,
      mimeType: 'application/pdf',
      name: fileName,
    );

    final shareMessage = _buildQuoteShareMessage(
      client: client,
      quote: quote,
      currency: currency,
      salon: salon,
      downloadUrl: uploadResult.downloadUrl,
      selectedChannels: shareableChannels.toList(growable: false),
    );

    final shareResult = await Share.shareXFiles(
      [pdfFile],
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
    final salonName = _sanitizePdfText(salon?.name ?? 'YouBook');
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
                  child: Text(
                    effectiveStatus.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: statusColors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColors.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    currency.format(quote.total),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: statusColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                if (onMarkSent != null)
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : onMarkSent,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Segna inviato'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                if (onSend != null)
                  FilledButton.icon(
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
                  OutlinedButton.icon(
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                    ),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                if (onDelete != null)
                  OutlinedButton.icon(
                    onPressed: (_isBusy || isDeleting) ? null : onDelete,
                    icon:
                        isDeleting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_outline_rounded),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
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
      if ((sale.paymentStatus != SalePaymentStatus.deposit &&
              sale.paymentStatus != SalePaymentStatus.posticipated) ||
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Crea un salone prima di registrare una vendita.'),
        ),
      );
      return;
    }

    final sale = await showAppModalSheet<Sale>(
      context: context,
      includeCloseButton: false,
      desktopMaxWidth: 1160,
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
            serviceLinesCreateSessionsByDefault: true,
          ),
    );

    if (sale == null) {
      return;
    }

    final store = ref.read(appDataProvider.notifier);
    await store.upsertSale(sale);
    await recordSaleCashFlow(ref: ref, sale: sale, clients: clients);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(const SnackBar(content: Text('Vendita registrata.')));
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
    if (paymentStatus != SalePaymentStatus.paid) {
      var remaining =
          paymentStatus == SalePaymentStatus.posticipated
              ? 0.0
              : _normalizeCurrency(paidAmount);
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
                  child: _buildSummaryValue(theme, label: '', value: ''),
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
                    label: 'Punti utilizzati',
                    value: '$loyaltyRedeemed punti',
                    emphasize: loyaltyRedeemed < 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Saldo utilizzabile',
                    value: '$loyaltySpendable punti',
                  ),
                ),

                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: '',
                    value: '',
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
        _buildBillingCompactListSection<_OutstandingSale>(
          context,
          title: 'Vendite con acconto',
          items: outstandingSales,
          itemBuilder: (context, outstandingSale, isCompact, showDivider) {
            void onTap() => _editSalePayment(
              context: context,
              ref: ref,
              sale: outstandingSale.sale,
              clients: clients,
              staff: staff,
            );
            return _BillingCompactRowWidget(
              data: _buildOutstandingSaleRowData(
                currency,
                dateTimeFormat,
                staff,
                outstandingSale,
                onTap: onTap,
              ),
              isCompact: isCompact,
              showDivider: showDivider,
            );
          },
        ),
      );
    }

    if (openTickets.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(
        _buildBillingCompactListSection<PaymentTicket>(
          context,
          title: 'Ticket aperti',
          items: openTickets,
          itemBuilder: (context, ticket, isCompact, showDivider) {
            void onTap() => _openTicketSale(
              context: context,
              ref: ref,
              ticket: ticket,
              clients: clients,
              staff: staff,
              services: services,
            );
            return _BillingCompactRowWidget(
              data: _buildTicketRowData(
                currency,
                dateTimeFormat,
                services,
                staff,
                ticket,
                onTap: onTap,
              ),
              isCompact: isCompact,
              showDivider: showDivider,
            );
          },
        ),
      );
    }

    if (outstandingPackages.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(
        _buildBillingCompactListSection<ClientPackagePurchase>(
          context,
          title: 'Pacchetti con saldo residuo',
          items: outstandingPackages,
          itemBuilder: (context, purchase, isCompact, showDivider) {
            void onTap() => _editSalePayment(
              context: context,
              ref: ref,
              sale: purchase.sale,
              clients: clients,
              staff: staff,
            );
            return _BillingCompactRowWidget(
              data: _buildOutstandingPackageRowData(
                currency,
                dateFormat,
                purchase,
                onTap: onTap,
              ),
              isCompact: isCompact,
              showDivider: showDivider,
            );
          },
        ),
      );
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
    ).showAppSnackBar(const SnackBar(content: Text('Acconto stornato.')));
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
    final initialItem = SaleItem(
      referenceId: ticket.serviceId,
      referenceType: SaleReferenceType.service,
      description: matchedService?.name ?? ticket.serviceName ?? 'Servizio',
      quantity: 1,
      unitPrice: normalizedTotal ?? rawTotal,
    );
    final data = ref.read(appDataProvider);
    final store = ref.read(appDataProvider.notifier);

    final sale = await showAppModalSheet<Sale>(
      context: context,
      includeCloseButton: false,
      desktopMaxWidth: 1160,
      builder:
          (ctx) => SaleFormSheet(
            salons: data.salons,
            clients: clients,
            staff: staff,
            services: services,
            packages: data.packages,
            inventoryItems: data.inventoryItems,
            sales: data.sales,
            defaultSalonId: ticket.salonId,
            initialClientId: ticket.clientId,
            initialItems: [initialItem],
            initialNotes: ticket.notes,
            initialStaffId: ticket.staffId,
          ),
    );

    if (sale == null) {
      return;
    }

    await store.upsertSale(sale);
    await recordSaleCashFlow(ref: ref, sale: sale, clients: clients);

    await store.closePaymentTicket(ticket.id, saleId: sale.id);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(const SnackBar(content: Text('Vendita registrata.')));
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
      clientId: sale.clientId,
    );
    await ref.read(appDataProvider.notifier).upsertCashFlowEntry(entry);
  }

  Widget _buildBillingCompactListSection<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required Widget Function(
      BuildContext context,
      T item,
      bool isCompact,
      bool showDivider,
    )
    itemBuilder,
    bool showTitle = true,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle) ...[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (!isCompact) const _BillingCompactHeader(),
                  for (var index = 0; index < items.length; index++)
                    itemBuilder(
                      context,
                      items[index],
                      isCompact,
                      index < items.length - 1,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  _BillingCompactRowData _buildOutstandingSaleRowData(
    NumberFormat currency,
    DateFormat dateTimeFormat,
    List<StaffMember> staff,
    _OutstandingSale outstandingSale, {
    VoidCallback? onTap,
  }) {
    final sale = outstandingSale.sale;
    final saleDate = dateTimeFormat.format(sale.createdAt);
    final status = _salePaymentStatusBadgeData(sale.paymentStatus);
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

    return _BillingCompactRowData(
      dateLabel: saleDate,
      titleLabel:
          sale.invoiceNumber?.trim().isNotEmpty == true
              ? sale.invoiceNumber!.trim()
              : 'Vendita',
      titleSubtitle:
          preview.isNotEmpty
              ? remaining > 0
                  ? '$preview (+$remaining)'
                  : preview
              : null,
      detailsLabel:
          'Metodo: ${_PackageGroup._paymentLabel(sale.paymentMethod)}',
      detailsSubtitle: subtitleLines.join(' • '),
      amountLabel: currency.format(outstandingSale.outstanding),
      amountSubtitle: 'Incassato ${currency.format(depositTotal)}',
      status: status.status,
      statusLabel: status.label,
      onTap: onTap,
      onAction: onTap,
      actionIcon: Icons.payments_outlined,
      actionTooltip: 'Registra incasso',
    );
  }

  _BillingCompactRowData _buildTicketRowData(
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

    return _BillingCompactRowData(
      dateLabel: appointmentLabel,
      titleLabel: serviceName,
      detailsLabel:
          operator == null ? 'Operatore da assegnare' : operator.fullName,
      detailsSubtitle:
          ticket.notes?.trim().isNotEmpty == true
              ? 'Note: ${ticket.notes!.trim()}'
              : null,
      amountLabel:
          amount != null && amount > 0
              ? currency.format(amount)
              : 'Importo n/d',
      amountSubtitle: 'Residuo da incassare',
      status: BadgeStatus.pending,
      statusLabel: 'Aperto',
      onTap: onTap,
      onAction: onTap,
      actionIcon: Icons.open_in_new_rounded,
      actionTooltip: 'Apri ticket',
    );
  }

  _BillingCompactRowData _buildOutstandingPackageRowData(
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
    return _BillingCompactRowData(
      dateLabel: purchaseDate,
      titleLabel: purchase.displayName,
      titleSubtitle:
          purchase.serviceNames.isNotEmpty
              ? purchase.serviceNames.join(', ')
              : null,
      detailsLabel: 'Metodo: $paymentMethod',
      detailsSubtitle:
          deposit > 0 ? 'Acconto versato: ${currency.format(deposit)}' : null,
      amountLabel: currency.format(purchase.outstandingAmount),
      amountSubtitle: 'Da saldare',
      status: BadgeStatus.pending,
      statusLabel: 'Saldo residuo',
      onTap: onTap,
      onAction: onTap,
      actionIcon: Icons.payments_outlined,
      actionTooltip: 'Registra incasso',
    );
  }

  _BillingStatusBadgeData _salePaymentStatusBadgeData(
    SalePaymentStatus status,
  ) {
    switch (status) {
      case SalePaymentStatus.deposit:
        return const _BillingStatusBadgeData(
          status: BadgeStatus.pending,
          label: 'Acconto',
        );
      case SalePaymentStatus.paid:
        return const _BillingStatusBadgeData(
          status: BadgeStatus.success,
          label: 'Pagato',
        );
      case SalePaymentStatus.posticipated:
        return const _BillingStatusBadgeData(
          status: BadgeStatus.info,
          label: 'Posticipato',
        );
    }
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
            _buildBillingCompactListSection<Sale>(
              context,
              title: 'Storico pagamenti',
              items: sales,
              showTitle: false,
              itemBuilder: (context, sale, isCompact, showDivider) {
                final deposits = _collectSaleDeposits(sale);
                return _PaymentHistoryTile(
                  key: ValueKey('payment-history-${sale.id}'),
                  sale: sale,
                  currency: currency,
                  theme: theme,
                  dateTimeFormat: dateTimeFormat,
                  deposits: deposits,
                  isCompact: isCompact,
                  showDivider: showDivider,
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
                );
              },
            ),
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

class _BillingStatusBadgeData {
  const _BillingStatusBadgeData({required this.status, required this.label});

  final BadgeStatus status;
  final String label;
}

class _BillingCompactRowData {
  const _BillingCompactRowData({
    required this.dateLabel,
    required this.titleLabel,
    required this.detailsLabel,
    required this.amountLabel,
    required this.status,
    required this.statusLabel,
    this.titleSubtitle,
    this.detailsSubtitle,
    this.amountSubtitle,
    this.onTap,
    this.onAction,
    this.actionIcon,
    this.actionTooltip,
  });

  final String dateLabel;
  final String titleLabel;
  final String detailsLabel;
  final String amountLabel;
  final BadgeStatus status;
  final String statusLabel;
  final String? titleSubtitle;
  final String? detailsSubtitle;
  final String? amountSubtitle;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final String? actionTooltip;
}

class _CompactListSection<T> extends StatelessWidget {
  const _CompactListSection({
    required this.items,
    required this.itemBuilder,
    this.title,
    this.showTitle = true,
  });

  final String? title;
  final List<T> items;
  final bool showTitle;
  final Widget Function(
    BuildContext context,
    T item,
    bool isCompact,
    bool showDivider,
  )
  itemBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle && title != null) ...[
              Text(title!, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (!isCompact) const _BillingCompactHeader(),
                  for (var index = 0; index < items.length; index++)
                    itemBuilder(
                      context,
                      items[index],
                      isCompact,
                      index < items.length - 1,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BillingCompactHeader extends StatelessWidget {
  const _BillingCompactHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Data', style: style)),
          Expanded(flex: 3, child: Text('Voce', style: style)),
          Expanded(flex: 4, child: Text('Dettagli', style: style)),
          Expanded(
            flex: 2,
            child: Text('Importo', style: style, textAlign: TextAlign.end),
          ),
          Expanded(flex: 2, child: Text('Stato', style: style)),
          const SizedBox(
            width: 56,
            child: Text('Azioni', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _BillingCompactRowWidget extends StatelessWidget {
  const _BillingCompactRowWidget({
    required this.data,
    required this.isCompact,
    this.showDivider = true,
  });

  final _BillingCompactRowData data;
  final bool isCompact;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant;
    final child =
        isCompact ? _buildMobileLayout(context) : _buildDesktopLayout(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom:
              showDivider ? BorderSide(color: borderColor) : BorderSide.none,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: data.onTap, child: child),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(data.dateLabel)),
          Expanded(
            flex: 3,
            child: _buildTextBlock(
              context,
              title: data.titleLabel,
              subtitle: data.titleSubtitle,
            ),
          ),
          Expanded(
            flex: 4,
            child: _buildTextBlock(
              context,
              title: data.detailsLabel,
              subtitle: data.detailsSubtitle,
              emphasizeTitle: false,
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildTextBlock(
                context,
                title: data.amountLabel,
                subtitle: data.amountSubtitle,
                alignEnd: true,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: data.status, label: data.statusLabel),
            ),
          ),
          SizedBox(
            width: 56,
            child:
                data.onAction == null || data.actionIcon == null
                    ? const SizedBox.shrink()
                    : IconButton(
                      tooltip: data.actionTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: data.onAction,
                      icon: Icon(data.actionIcon),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        children: [
          _BillingMobileDataField(label: 'Data', value: data.dateLabel),
          _BillingMobileDataField(
            label: 'Voce',
            value: data.titleLabel,
            subtitle: data.titleSubtitle,
          ),
          _BillingMobileDataField(
            label: 'Dettagli',
            value: data.detailsLabel,
            subtitle: data.detailsSubtitle,
          ),
          _BillingMobileDataField(
            label: 'Importo',
            value: data.amountLabel,
            subtitle: data.amountSubtitle,
            valueColor: scheme.primary,
          ),
          _BillingMobileDataFieldWidget(
            label: 'Stato',
            child: StatusBadge(status: data.status, label: data.statusLabel),
          ),
          if (data.onAction != null && data.actionIcon != null)
            _BillingMobileDataFieldWidget(
              label: 'Azioni',
              child: IconButton(
                tooltip: data.actionTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: data.onAction,
                icon: Icon(data.actionIcon),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextBlock(
    BuildContext context, {
    required String title,
    String? subtitle,
    bool emphasizeTitle = true,
    bool alignEnd = false,
  }) {
    final theme = Theme.of(context);
    final crossAxisAlignment =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: emphasizeTitle ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _BillingMobileDataField extends StatelessWidget {
  const _BillingMobileDataField({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _BillingMobileDataFieldWidget extends StatelessWidget {
  const _BillingMobileDataFieldWidget({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryTile extends StatefulWidget {
  const _PaymentHistoryTile({
    required this.sale,
    required this.currency,
    required this.theme,
    required this.dateTimeFormat,
    required this.deposits,
    required this.isCompact,
    required this.showDivider,
    this.onDeleteDeposit,
    super.key,
  });

  final Sale sale;
  final NumberFormat currency;
  final ThemeData theme;
  final DateFormat dateTimeFormat;
  final List<_SaleDepositEntry> deposits;
  final bool isCompact;
  final bool showDivider;
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
    final itemDescriptions =
        sale.items
            .map((item) => item.description)
            .where((value) => value.isNotEmpty)
            .toList();
    final preview = itemDescriptions.take(3).join(', ');
    final remaining = math.max(itemDescriptions.length - 3, 0);
    final titleLabel =
        sale.invoiceNumber?.trim().isNotEmpty == true
            ? sale.invoiceNumber!.trim()
            : 'Vendita';
    final titleSubtitle =
        preview.isEmpty
            ? null
            : remaining > 0
            ? '$preview (+$remaining)'
            : preview;
    final details =
        StringBuffer()
          ..write('Metodo: ${_PackageGroup._paymentLabel(sale.paymentMethod)}')
          ..write(' • Articoli: ${sale.items.length}');
    if (sale.discountAmount > 0) {
      details.write(
        ' • Sconto: ${widget.currency.format(sale.discountAmount)}',
      );
    }
    final detailSubtitleParts = <String>[
      if (sale.notes != null && sale.notes!.isNotEmpty) 'Note: ${sale.notes}',
      if (sale.paymentStatus == SalePaymentStatus.deposit)
        'Incassato ${widget.currency.format(sale.paidAmount)} • Residuo ${widget.currency.format(sale.outstandingAmount)}',
      if (hasDeposits)
        _expanded ? 'Movimenti visibili' : 'Tocca per vedere i movimenti',
    ];
    final status = switch (sale.paymentStatus) {
      SalePaymentStatus.deposit => const _BillingStatusBadgeData(
        status: BadgeStatus.pending,
        label: 'Acconto',
      ),
      SalePaymentStatus.paid => const _BillingStatusBadgeData(
        status: BadgeStatus.success,
        label: 'Pagato',
      ),
      SalePaymentStatus.posticipated => const _BillingStatusBadgeData(
        status: BadgeStatus.info,
        label: 'Posticipato',
      ),
    };
    final rowData = _BillingCompactRowData(
      dateLabel: widget.dateTimeFormat.format(sale.createdAt),
      titleLabel: titleLabel,
      titleSubtitle: titleSubtitle,
      detailsLabel: details.toString(),
      detailsSubtitle:
          detailSubtitleParts.isEmpty ? null : detailSubtitleParts.join(' • '),
      amountLabel: widget.currency.format(sale.total),
      amountSubtitle:
          sale.paymentStatus == SalePaymentStatus.deposit
              ? 'Incassato ${widget.currency.format(sale.paidAmount)}'
              : null,
      status: status.status,
      statusLabel: status.label,
      onTap: _toggle,
      onAction: _toggle,
      actionIcon:
          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
      actionTooltip: hasDeposits ? 'Mostra movimenti' : 'Dettaglio pagamento',
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom:
              widget.showDivider
                  ? BorderSide(color: scheme.outlineVariant)
                  : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          _BillingCompactRowWidget(
            data: rowData,
            isCompact: widget.isCompact,
            showDivider: false,
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildDepositsSection(
                scheme,
                widget.currency,
                widget.dateTimeFormat,
                widget.deposits,
                widget.onDeleteDeposit,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepositsSection(
    ColorScheme scheme,
    NumberFormat currency,
    DateFormat dateFormat,
    List<_SaleDepositEntry> deposits,
    Future<void> Function(_SaleDepositEntry entry)? onDeleteDeposit,
  ) {
    final background = scheme.surface;
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
          if (!widget.isCompact) const _BillingCompactHeader(),
          for (var index = 0; index < deposits.length; index++)
            _DepositRow(
              entry: deposits[index],
              currency: currency,
              dateFormat: dateFormat,
              isCompact: widget.isCompact,
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
    required this.isCompact,
    this.showDivider = false,
    this.onDelete,
  });

  final _SaleDepositEntry entry;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final bool isCompact;
  final bool showDivider;
  final Future<void> Function(_SaleDepositEntry entry)? onDelete;

  @override
  Widget build(BuildContext context) {
    final status = switch (entry.movementType) {
      SalePaymentType.settlement => const _BillingStatusBadgeData(
        status: BadgeStatus.success,
        label: 'Saldo',
      ),
      SalePaymentType.deposit => const _BillingStatusBadgeData(
        status: BadgeStatus.pending,
        label: 'Acconto',
      ),
      null => const _BillingStatusBadgeData(
        status: BadgeStatus.info,
        label: 'Movimento',
      ),
    };
    final details = <String>[
      _PackageGroup._paymentLabel(entry.paymentMethod),
      if (entry.recordedBy != null && entry.recordedBy!.isNotEmpty)
        'Operatore: ${entry.recordedBy}',
    ].join(' • ');

    return _BillingCompactRowWidget(
      data: _BillingCompactRowData(
        dateLabel: dateFormat.format(entry.date),
        titleLabel: entry.movementType?.label ?? 'Movimento',
        titleSubtitle: entry.itemDescription,
        detailsLabel: details,
        detailsSubtitle:
            entry.note != null && entry.note!.isNotEmpty
                ? 'Nota: ${entry.note}'
                : null,
        amountLabel: currency.format(entry.amount),
        status: status.status,
        statusLabel: status.label,
        onAction: onDelete == null ? null : () => onDelete?.call(entry),
        actionIcon: onDelete == null ? null : Icons.undo_rounded,
        actionTooltip: onDelete == null ? null : 'Storna acconto',
      ),
      isCompact: isCompact,
      showDivider: showDivider,
    );
  }
}

class _PackageGroup extends StatelessWidget {
  const _PackageGroup({
    required this.title,
    required this.items,
    required this.servicesById,
    this.onEdit,
    this.onDelete,
    this.onAddDeposit,
    this.onDeleteDeposit,
  });

  final String title;
  final List<ClientPackagePurchase> items;
  final Map<String, Service> servicesById;
  final ValueChanged<ClientPackagePurchase>? onEdit;
  final ValueChanged<ClientPackagePurchase>? onDelete;
  final ValueChanged<ClientPackagePurchase>? onAddDeposit;
  final void Function(ClientPackagePurchase, PackageDeposit)? onDeleteDeposit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (items.isNotEmpty)
              Text(
                '${items.length} ${items.length == 1 ? 'pacchetto' : 'pacchetti'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title.contains('attivi')
                        ? 'Nessun pacchetto attivo o in scadenza per questo cliente.'
                        : 'Non risultano pacchetti archiviati per questo cliente.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 18.0;
              final available = constraints.maxWidth;
              if (available < 780) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children:
                      items
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    entry.key == items.length - 1 ? 0 : spacing,
                              ),
                              child: _PackageTile(
                                purchase: entry.value,
                                currency: currency,
                                dateFormat: dateFormat,
                                servicesById: servicesById,
                                onEdit: onEdit,
                                onDelete: onDelete,
                                onAddDeposit: onAddDeposit,
                                onDeleteDeposit: onDeleteDeposit,
                              ),
                            ),
                          )
                          .toList(),
                );
              }

              const minTileWidth = 420.0;
              final estimatedColumns =
                  ((available + spacing) / (minTileWidth + spacing)).floor();
              final columns = math.max(1, math.min(2, estimatedColumns));
              final tileWidth = (available - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children:
                    items
                        .map(
                          (purchase) => SizedBox(
                            width: tileWidth,
                            child: _PackageTile(
                              purchase: purchase,
                              currency: currency,
                              dateFormat: dateFormat,
                              servicesById: servicesById,
                              onEdit: onEdit,
                              onDelete: onDelete,
                              onAddDeposit: onAddDeposit,
                              onDeleteDeposit: onDeleteDeposit,
                            ),
                          ),
                        )
                        .toList(),
              );
            },
          ),
      ],
    );
  }

  static String _paymentLabel(PaymentMethod method) {
    return method.label;
  }
}

class _ServiceUsageSummary {
  const _ServiceUsageSummary({
    required this.serviceId,
    required this.name,
    required this.total,
    required this.used,
    required this.remaining,
  });

  final String serviceId;
  final String name;
  final int? total;
  final int used;
  final int remaining;

  String get usageLabel {
    if (total == null) {
      return 'Rimanenti $remaining • Usate $used';
    }
    return '$remaining / $total rimanenti • Usate $used';
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.purchase,
    required this.currency,
    required this.dateFormat,
    required this.servicesById,
    this.onEdit,
    this.onDelete,
    this.onAddDeposit,
    this.onDeleteDeposit,
  });

  final ClientPackagePurchase purchase;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final Map<String, Service> servicesById;
  final ValueChanged<ClientPackagePurchase>? onEdit;
  final ValueChanged<ClientPackagePurchase>? onDelete;
  final ValueChanged<ClientPackagePurchase>? onAddDeposit;
  final void Function(ClientPackagePurchase, PackageDeposit)? onDeleteDeposit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expiry = purchase.expirationDate;
    final serviceUsage = _resolvePackageServiceUsage(purchase, servicesById);
    final outstanding = double.parse(
      purchase.outstandingAmount.toStringAsFixed(2),
    );
    final canAddDeposit = onAddDeposit != null && outstanding > 0;
    final lifecycle = _packageLifecycleBadgeData(purchase);
    final payment = _packagePaymentBadgeData(purchase);
    final accentColor = _packageAccentColor(scheme, lifecycle.status);
    final totalRemainingServices = serviceUsage.fold<int>(
      0,
      (sum, usage) => sum + math.max(usage.remaining, 0),
    );
    final hasSyntheticDeposit =
        purchase.deposits.isEmpty && purchase.depositAmount > 0;
    final paymentEntries =
        purchase.deposits.isNotEmpty
            ? purchase.deposits
            : hasSyntheticDeposit
            ? [
              PackageDeposit(
                id: 'legacy-${purchase.sale.id}-${purchase.itemIndex}',
                amount: purchase.depositAmount,
                date: purchase.sale.createdAt,
                note: outstanding > 0 ? 'Acconto iniziale' : 'Saldo iniziale',
                paymentMethod: purchase.sale.paymentMethod,
              ),
            ]
            : const <PackageDeposit>[];
    final actionButtonColor = theme.colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.75)),
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
                  child: Text(
                    purchase.package?.name ?? purchase.item.description,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        _PackageIconActionButton(
                          tooltip: 'Modifica pacchetto',
                          icon: Icons.edit_rounded,
                          color: actionButtonColor,
                          onPressed: () => onEdit?.call(purchase),
                        ),
                      if (onDelete != null)
                        _PackageIconActionButton(
                          tooltip: 'Elimina pacchetto',
                          icon: Icons.delete_outline_rounded,
                          color: scheme.error,
                          onPressed: () => onDelete?.call(purchase),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  status: lifecycle.status,
                  label: lifecycle.label,
                  size: BadgeSize.sm,
                ),
                StatusBadge(
                  status: payment.status,
                  label: payment.label,
                  size: BadgeSize.sm,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PackageInfoPanel(
              children: [
                _PackageInfoCell(
                  label: 'Prezzo',
                  value: currency.format(purchase.totalAmount),
                  valueColor: theme.colorScheme.primary,
                ),
                _PackageInfoCell(
                  label: 'Acquisto',
                  value: dateFormat.format(purchase.sale.createdAt),
                ),
                _PackageInfoCell(
                  label: 'Scadenza',
                  value:
                      expiry == null
                          ? 'Senza scadenza'
                          : dateFormat.format(expiry),
                  valueColor:
                      lifecycle.label == 'In scadenza'
                          ? const Color(0xFFEA580C)
                          : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 620;
                final servicesSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PackageSectionHeader(
                      icon: Icons.inventory_2_outlined,
                      title: 'Servizi',
                      trailing: Text(
                        '$totalRemainingServices disp.',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (serviceUsage.isEmpty)
                      _PackageEmptyPanel(
                        icon: Icons.inventory_2_outlined,
                        message: 'Nessun servizio associato al pacchetto.',
                      )
                    else
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < serviceUsage.length;
                            index++
                          )
                            Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == serviceUsage.length - 1 ? 0 : 10,
                              ),
                              child: _PackageServiceUsageTile(
                                usage: serviceUsage[index],
                                accentColor: accentColor,
                              ),
                            ),
                        ],
                      ),
                  ],
                );
                final paymentsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PackageSectionHeader(
                      icon: Icons.payments_outlined,
                      title: 'Pagamenti',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${paymentEntries.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (canAddDeposit) ...[
                            const SizedBox(width: 6),
                            _PackageIconActionButton(
                              tooltip: 'Registra acconto',
                              icon: Icons.add_card_rounded,
                              color: theme.colorScheme.primary,
                              onPressed: () => onAddDeposit?.call(purchase),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (paymentEntries.isEmpty)
                      _PackageEmptyPanel(
                        icon: Icons.receipt_long_outlined,
                        message: 'Nessun pagamento registrato.',
                      )
                    else
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < paymentEntries.length;
                            index++
                          )
                            Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == paymentEntries.length - 1 ? 0 : 10,
                              ),
                              child: _PackagePaymentTile(
                                amountLabel: currency.format(
                                  paymentEntries[index].amount,
                                ),
                                dateLabel: dateFormat.format(
                                  paymentEntries[index].date,
                                ),
                                paymentMethodLabel: _PackageGroup._paymentLabel(
                                  paymentEntries[index].paymentMethod,
                                ),
                                note: paymentEntries[index].note,
                                onDelete:
                                    onDeleteDeposit == null ||
                                            hasSyntheticDeposit
                                        ? null
                                        : () => onDeleteDeposit?.call(
                                          purchase,
                                          paymentEntries[index],
                                        ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    _PackageTotalsPanel(
                      totalLabel: currency.format(purchase.totalAmount),
                      outstandingLabel:
                          outstanding > 0
                              ? 'Residuo: ${currency.format(outstanding)}'
                              : null,
                    ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      servicesSection,
                      const SizedBox(height: 20),
                      paymentsSection,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: servicesSection),
                    const SizedBox(width: 16),
                    Expanded(child: paymentsSection),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageOverviewMetrics extends StatelessWidget {
  const _PackageOverviewMetrics({
    required this.activeCount,
    required this.availableServicesCount,
    required this.totalValue,
    required this.currency,
  });

  final int activeCount;
  final int availableServicesCount;
  final double totalValue;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final cards = [
          _PackageMetricCard(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF16A34A),
            value: '$activeCount',
            label: 'Pacchetti attivi',
          ),
          _PackageMetricCard(
            icon: Icons.widgets_outlined,
            iconColor: const Color(0xFFEA580C),
            value: '$availableServicesCount',
            label: 'Servizi disponibili',
          ),
          _PackageMetricCard(
            icon: Icons.payments_outlined,
            iconColor: const Color(0xFFCA8A04),
            value: currency.format(totalValue),
            label: 'Valore totale',
          ),
        ];

        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(height: spacing),
                cards[index],
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: spacing),
              Expanded(child: cards[index]),
            ],
          ],
        );
      },
    );
  }
}

class _PackageMetricCard extends StatelessWidget {
  const _PackageMetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _PackageInfoPanel extends StatelessWidget {
  const _PackageInfoPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  children[index],
                ],
              ],
            );
          }

          return Row(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: 16),
                Expanded(child: children[index]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PackageInfoCell extends StatelessWidget {
  const _PackageInfoCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _PackageSectionHeader extends StatelessWidget {
  const _PackageSectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PackageEmptyPanel extends StatelessWidget {
  const _PackageEmptyPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageServiceUsageTile extends StatelessWidget {
  const _PackageServiceUsageTile({
    required this.usage,
    required this.accentColor,
  });

  final _ServiceUsageSummary usage;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double? progress =
        usage.total == null || usage.total == 0
            ? null
            : (usage.used / usage.total!).clamp(0.0, 1.0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  usage.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${usage.remaining}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          if (progress != null) const SizedBox(height: 8),
          Text(
            usage.total == null
                ? 'Utilizzate: ${usage.used}'
                : '${usage.used}/${usage.total}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagePaymentTile extends StatelessWidget {
  const _PackagePaymentTile({
    required this.amountLabel,
    required this.dateLabel,
    required this.paymentMethodLabel,
    this.note,
    this.onDelete,
  });

  final String amountLabel;
  final String dateLabel;
  final String paymentMethodLabel;
  final String? note;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deleteCallback = onDelete;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0x1A22C55E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFF15803D),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amountLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel • $paymentMethodLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (deleteCallback != null)
            _PackageIconActionButton(
              tooltip: 'Storna acconto',
              icon: Icons.undo_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: deleteCallback,
            ),
        ],
      ),
    );
  }
}

class _PackageTotalsPanel extends StatelessWidget {
  const _PackageTotalsPanel({required this.totalLabel, this.outstandingLabel});

  final String totalLabel;
  final String? outstandingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Totale:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  totalLabel,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (outstandingLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              outstandingLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageIconActionButton extends StatelessWidget {
  const _PackageIconActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

List<_ServiceUsageSummary> _resolvePackageServiceUsage(
  ClientPackagePurchase purchase,
  Map<String, Service> servicesById,
) {
  final serviceIds = <String>{
    ...purchase.item.packageServiceSessions.keys,
    ...purchase.item.remainingPackageServiceSessions.keys,
    ...purchase.package?.serviceSessionCounts.keys ?? const <String>{},
    ...purchase.package?.serviceIds ?? const <String>[],
    ...purchase.usedSessionsByService.keys,
  }..removeWhere((id) => id.isEmpty);

  if (serviceIds.isEmpty) {
    return const <_ServiceUsageSummary>[];
  }

  final usage = <_ServiceUsageSummary>[];
  for (final serviceId in serviceIds) {
    final service = servicesById[serviceId];
    final total = purchase.totalSessionsForService(serviceId);
    final remaining = math.max(
      0,
      purchase.remainingSessionsForService(serviceId),
    );
    final usedFromMap = purchase.usedSessionsByService[serviceId] ?? 0;
    final computedUsed =
        total != null ? math.max(0, total - remaining) : usedFromMap;
    final used = math.max(usedFromMap, computedUsed);
    usage.add(
      _ServiceUsageSummary(
        serviceId: serviceId,
        name: service?.name ?? serviceId,
        total: total,
        used: used,
        remaining: remaining,
      ),
    );
  }

  usage.sort((a, b) => a.name.compareTo(b.name));
  return usage;
}

_BillingStatusBadgeData _packageLifecycleBadgeData(
  ClientPackagePurchase purchase,
) {
  if (purchase.status == PackagePurchaseStatus.cancelled) {
    return const _BillingStatusBadgeData(
      status: BadgeStatus.cancelled,
      label: 'Annullato',
    );
  }
  if (purchase.status == PackagePurchaseStatus.completed) {
    return const _BillingStatusBadgeData(
      status: BadgeStatus.success,
      label: 'Completato',
    );
  }
  if (_isPackageExpired(purchase)) {
    return const _BillingStatusBadgeData(
      status: BadgeStatus.inactive,
      label: 'Scaduto',
    );
  }
  if (_isPackageExpiringSoon(purchase)) {
    return const _BillingStatusBadgeData(
      status: BadgeStatus.pending,
      label: 'In scadenza',
    );
  }
  return const _BillingStatusBadgeData(
    status: BadgeStatus.success,
    label: 'Attivo',
  );
}

_BillingStatusBadgeData _packagePaymentBadgeData(
  ClientPackagePurchase purchase,
) {
  if (purchase.item.isServiceSessionCredit) {
    if (purchase.sale.outstandingAmount > 0.009) {
      return const _BillingStatusBadgeData(
        status: BadgeStatus.cancelled,
        label: 'Non saldato',
      );
    }
    return const _BillingStatusBadgeData(
      status: BadgeStatus.success,
      label: 'Saldato',
    );
  }

  if (purchase.outstandingAmount > 0.009) {
    return const _BillingStatusBadgeData(
      status: BadgeStatus.cancelled,
      label: 'Non saldato',
    );
  }
  return const _BillingStatusBadgeData(
    status: BadgeStatus.success,
    label: 'Saldato',
  );
}

bool _isPackageExpired(ClientPackagePurchase purchase) {
  final expiry = purchase.expirationDate;
  if (expiry == null) {
    return false;
  }
  final today = DateUtils.dateOnly(DateTime.now());
  return DateUtils.dateOnly(expiry).isBefore(today);
}

bool _isPackageExpiringSoon(ClientPackagePurchase purchase) {
  if (purchase.status != PackagePurchaseStatus.active ||
      _isPackageExpired(purchase)) {
    return false;
  }
  final expiry = purchase.expirationDate;
  if (expiry == null) {
    return false;
  }
  final today = DateUtils.dateOnly(DateTime.now());
  final daysUntilExpiry = DateUtils.dateOnly(expiry).difference(today).inDays;
  return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
}

Color _packageAccentColor(ColorScheme scheme, BadgeStatus status) {
  switch (status) {
    case BadgeStatus.pending:
      return const Color(0xFFEA580C);
    case BadgeStatus.cancelled:
      return scheme.error;
    case BadgeStatus.inactive:
      return scheme.onSurfaceVariant;
    case BadgeStatus.info:
      return const Color(0xFF1D4ED8);
    case BadgeStatus.success:
    case BadgeStatus.active:
      return const Color(0xFF16A34A);
  }
}
