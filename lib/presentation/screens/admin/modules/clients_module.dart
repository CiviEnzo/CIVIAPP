import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/repositories/auth_repository.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ClientsModule extends ConsumerStatefulWidget {
  const ClientsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<ClientsModule> createState() => _ClientsModuleState();
}

class _ClientsModuleState extends ConsumerState<ClientsModule> {
  final Set<String> _sendingInvites = <String>{};

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final clients =
        data.clients
            .where(
              (client) =>
                  widget.salonId == null || client.salonId == widget.salonId,
            )
            .toList()
          ..sort((a, b) => a.lastName.compareTo(b.lastName));

    if (clients.isEmpty) {
      return const Center(
        child: Text('Nessun cliente registrato per questo salone'),
      );
    }

    final salons = data.salons;
    final dateFormatter = DateFormat('dd/MM/yyyy');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed:
                  () => _openForm(
                    context,
                    ref,
                    salons: salons,
                    defaultSalonId: widget.salonId,
                  ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuovo cliente'),
            ),
          );
        }
        final client = clients[index - 1];
        final appointments =
            data.appointments
                .where((appointment) => appointment.clientId == client.id)
                .length;
        final purchases =
            data.sales.where((sale) => sale.clientId == client.id).length;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetails(context, client.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        child: Text(
                          client.firstName.characters.firstOrNull
                                  ?.toUpperCase() ??
                              '?',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              client.fullName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if (client.clientNumber != null)
                                  _InfoRow(
                                    icon: Icons.badge_outlined,
                                    text: 'N° ${client.clientNumber}',
                                  ),
                                _InfoRow(icon: Icons.phone, text: client.phone),
                                if (client.email != null)
                                  _InfoRow(
                                    icon: Icons.email,
                                    text: client.email!,
                                  ),
                                if (client.dateOfBirth != null)
                                  _InfoRow(
                                    icon: Icons.cake_outlined,
                                    text: dateFormatter.format(
                                      client.dateOfBirth!,
                                    ),
                                  ),
                                if (client.profession != null &&
                                    client.profession!.isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.work_outline_rounded,
                                    text: client.profession!,
                                  ),
                                _InfoRow(
                                  icon: Icons.loyalty_rounded,
                                  text: 'Punti: ${client.loyaltyPoints}',
                                ),
                              ],
                            ),
                            if (client.address != null &&
                                client.address!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.home_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(client.address!)),
                                  ],
                                ),
                              ),
                            if (client.referralSource != null &&
                                client.referralSource!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.campaign_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(client.referralSource!),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Appuntamenti: $appointments'),
                          Text('Acquisti: $purchases'),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            tooltip: 'Modifica cliente',
                            onPressed:
                                () => _openForm(
                                  context,
                                  ref,
                                  salons: salons,
                                  defaultSalonId: widget.salonId,
                                  existing: client,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAccessActions(context, client),
                  if (client.notes != null) ...[
                    const SizedBox(height: 12),
                    Text(client.notes!),
                  ],
                  if (client.marketedConsents.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Consensi',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          client.marketedConsents
                              .map(
                                (consent) => Chip(
                                  label: Text(
                                    '${_consentLabel(consent.type)} · ${DateFormat('dd/MM/yyyy').format(consent.acceptedAt)}',
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: clients.length + 1,
    );
  }

  bool _isSending(String clientId) => _sendingInvites.contains(clientId);

  void _openDetails(BuildContext context, String clientId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClientDetailPage(clientId: clientId)),
    );
  }

  Future<void> _sendAccessLink(Client client) async {
    final email = client.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aggiungi un'email al profilo per inviare il link."),
        ),
      );
      return;
    }
    if (_sendingInvites.contains(client.id)) {
      return;
    }

    setState(() => _sendingInvites.add(client.id));
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .sendClientInviteEmail(email);
      final nextStatus =
          client.onboardingStatus == ClientOnboardingStatus.onboardingCompleted
              ? ClientOnboardingStatus.onboardingCompleted
              : ClientOnboardingStatus.invitationSent;
      final updatedClient = client.copyWith(
        onboardingStatus: nextStatus,
        invitationSentAt: DateTime.now(),
      );
      await ref.read(appDataProvider.notifier).upsertClient(updatedClient);

      if (!mounted) {
        return;
      }
      final message =
          outcome == ClientInviteOutcome.passwordReset
              ? "Link di reset inviato a $email"
              : "Invito di accesso inviato a $email";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante l'invio del link: $error")),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingInvites.remove(client.id));
      }
    }
  }

  Widget _buildAccessActions(BuildContext context, Client client) {
    final theme = Theme.of(context);
    final isSending = _isSending(client.id);
    final emailAvailable = client.email != null && client.email!.isNotEmpty;
    final lastSentAt = client.invitationSentAt;
    final firstLoginAt = client.firstLoginAt;
    final onboardingCompletedAt = client.onboardingCompletedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed:
                  emailAvailable && !isSending
                      ? () => _sendAccessLink(client)
                      : null,
              icon:
                  isSending
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.mail_outline_rounded),
              label: Text(
                emailAvailable
                    ? "Invia link di accesso"
                    : "Email non disponibile",
              ),
            ),
            _buildStatusChip(context, client),
          ],
        ),
        if (lastSentAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Ultimo invio: ${DateFormat('dd/MM/yyyy HH:mm').format(lastSentAt)}",
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (firstLoginAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Primo accesso: ${DateFormat('dd/MM/yyyy HH:mm').format(firstLoginAt)}",
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (onboardingCompletedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Onboarding completato: ${DateFormat('dd/MM/yyyy HH:mm').format(onboardingCompletedAt)}",
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (!emailAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Aggiungi un indirizzo email per poter invitare il cliente.",
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, Client client) {
    final scheme = Theme.of(context).colorScheme;
    final status = client.onboardingStatus;

    late final Color background;
    late final Color foreground;
    late final IconData icon;

    switch (status) {
      case ClientOnboardingStatus.notSent:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurface;
        icon = Icons.hourglass_empty_rounded;
        break;
      case ClientOnboardingStatus.invitationSent:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        icon = Icons.outgoing_mail;
        break;
      case ClientOnboardingStatus.firstLogin:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        icon = Icons.login_rounded;
        break;
      case ClientOnboardingStatus.onboardingCompleted:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        icon = Icons.verified_rounded;
        break;
    }

    return Chip(
      backgroundColor: background,
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(_statusLabel(status), style: TextStyle(color: foreground)),
    );
  }

  String _statusLabel(ClientOnboardingStatus status) {
    switch (status) {
      case ClientOnboardingStatus.notSent:
        return "Non inviato";
      case ClientOnboardingStatus.invitationSent:
        return "Inviata";
      case ClientOnboardingStatus.firstLogin:
        return "Primo accesso";
      case ClientOnboardingStatus.onboardingCompleted:
        return "Onboarding completato";
    }
  }

  String _consentLabel(ConsentType type) {
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

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  String? defaultSalonId,
  Client? existing,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea prima un salone per associare clienti.'),
      ),
    );
    return;
  }
  final result = await showAppModalSheet<Client>(
    context: context,
    builder:
        (ctx) => ClientFormSheet(
          salons: salons,
          defaultSalonId: defaultSalonId,
          initial: existing,
        ),
  );
  if (result != null) {
    await ref.read(appDataProvider.notifier).upsertClient(result);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
    );
  }
}
