import 'package:you_book/presentation/screens/admin/whatsapp/campaign_editor_page.dart';
import 'package:you_book/presentation/screens/admin/whatsapp/template_list_page.dart';
import 'package:you_book/presentation/screens/admin/whatsapp/whatsapp_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WhatsAppModule extends ConsumerWidget {
  const WhatsAppModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (salonId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Seleziona un salone per configurare WhatsApp.'),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 12),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Impostazioni'),
              Tab(text: 'Template'),
              Tab(text: 'Campagne'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                WhatsAppSettingsPage(salonId: salonId!),
                WhatsAppTemplateListPage(salonId: salonId!),
                WhatsAppCampaignEditorPage(salonId: salonId!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
