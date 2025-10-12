import 'package:civiapp/app/providers.dart';
import 'package:civiapp/services/whatsapp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class WhatsAppSettingsPage extends ConsumerWidget {
  const WhatsAppSettingsPage({
    super.key,
    required this.salonId,
  });

  final String salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(whatsappConfigProvider(salonId));
    final service = ref.watch(whatsappServiceProvider);
    final sendEndpoint = service.sendEndpoint?.toString() ?? 'Non configurato';

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorState(error: error),
      data: (config) {
        final isConfigured = config?.isConfigured ?? false;
        final updatedAt = config?.updatedAt?.toLocal();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _SettingsHeader(
                isConfigured: isConfigured,
                onConnect: () => _handleConnect(context, ref),
                onDisconnect:
                    isConfigured
                        ? () => _handleDisconnect(context, ref)
                        : null,
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Configurazione corrente',
                children: [
                  _InfoTile(
                    label: 'Modalità',
                    value: config?.mode ?? 'Non configurato',
                  ),
                  _InfoTile(
                    label: 'Business Manager ID',
                    value: _mask(config?.businessId),
                  ),
                  _InfoTile(
                    label: 'WABA ID',
                    value: _mask(config?.wabaId),
                  ),
                  _InfoTile(
                    label: 'Phone Number ID',
                    value: config?.phoneNumberId ?? '—',
                  ),
                  _InfoTile(
                    label: 'Numero visualizzato',
                    value: config?.displayPhoneNumber ?? '—',
                  ),
                  _InfoTile(
                    label: 'Secret token',
                    value: _mask(config?.tokenSecretId),
                  ),
                  _InfoTile(
                    label: 'Verify token (Secret Manager)',
                    value: _mask(config?.verifyTokenSecretId),
                  ),
                  _InfoTile(
                    label: 'Ultimo aggiornamento',
                    value: updatedAt != null
                        ? updatedAt.toIso8601String()
                        : '—',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Endpoint di invio template',
                children: [
                  const Text(
                    'Utilizza questo endpoint HTTPS per inviare template approvati tramite Cloud Functions.',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    sendEndpoint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _copyEndpoint(context, sendEndpoint),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copia URL'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleConnect(BuildContext context, WidgetRef ref) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await ref.read(whatsappServiceProvider).openOAuthFlow(salonId);
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Richiesta di collegamento avviata. Completa il flow nel browser.'),
        ),
      );
    } on Exception catch (error) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Impossibile aprire il collegamento: $error')),
      );
    }
  }

  Future<void> _handleDisconnect(BuildContext context, WidgetRef ref) async {
    final scaffold = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnetti WhatsApp'),
        content: const Text(
          'Sei sicuro di voler scollegare il numero WhatsApp del salone? Dovrai ripetere l\'onboarding per inviare nuovi messaggi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnetti'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await ref.read(whatsappServiceProvider).disconnect(salonId);
      scaffold.showSnackBar(
        const SnackBar(content: Text('Account WhatsApp scollegato.')),
      );
    } on Exception catch (error) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Errore durante la disconnessione: $error')),
      );
    }
  }

  void _copyEndpoint(BuildContext context, String endpoint) {
    if (endpoint == 'Non configurato') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Configura SEND_ENDPOINT con --dart-define o Firebase Remote Config.'),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: endpoint));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Endpoint copiato negli appunti.')),
    );
  }

  static String _mask(String? value) {
    if (value == null || value.isEmpty) {
      return '—';
    }
    if (value.length <= 6) {
      return value;
    }
    final suffix = value.substring(value.length - 4);
    return '•••$suffix';
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.isConfigured,
    required this.onConnect,
    this.onDisconnect,
  });

  final bool isConfigured;
  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stato integrazione',
                  style: theme.textTheme.titleLarge,
                ),
                Chip(
                  label: Text(isConfigured ? 'Collegato' : 'Da configurare'),
                  backgroundColor:
                      isConfigured ? colorScheme.primaryContainer : colorScheme.surfaceVariant,
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: isConfigured
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isConfigured
                  ? 'Il salone invia con il proprio numero WhatsApp Business. Ricordati di verificare i template e monitorare i crediti.'
                  : 'Collega un account WhatsApp Business (WABA) tramite OAuth per inviare template con il brand del salone.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(isConfigured ? 'Ricollega account' : 'Collega account'),
                ),
                if (onDisconnect != null)
                  OutlinedButton.icon(
                    onPressed: onDisconnect,
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Disconnetti'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              'Errore nel caricare la configurazione WhatsApp',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
