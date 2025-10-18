import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';

class SalonIntegrationsSheet extends StatelessWidget {
  const SalonIntegrationsSheet({super.key, required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Integrazioni', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                tooltip: 'Chiudi',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Gestisci le integrazioni principali del salone. Alcune azioni apriranno schermate dedicate.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.chat_rounded),
            title: const Text('WhatsApp Business'),
            subtitle: Text(
              salon.socialLinks.containsKey('WhatsApp')
                  ? 'Collegato come ${salon.socialLinks['WhatsApp']}'
                  : 'Non configurato',
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              Navigator.of(context).maybePop();
              // La navigazione reale sarà gestita dal chiamante (es. aprire modulo dedicato).
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.credit_card_rounded),
            title: const Text('Stripe'),
            subtitle: Text(
              salon.stripeAccountId == null
                  ? 'Pagamento online non attivo'
                  : 'Account collegato (${salon.stripeAccountId})',
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              Navigator.of(context).maybePop();
            },
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Chiudi'),
            ),
          ),
        ],
      ),
    );
  }
}
