import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ClientOverviewSection extends StatelessWidget {
  const ClientOverviewSection({
    super.key,
    required this.client,
    required this.salon,
    required this.dateFormat,
    required this.dateTimeFormat,
  });

  final Client client;
  final Salon? salon;
  final DateFormat dateFormat;
  final DateFormat dateTimeFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final birthDate = client.dateOfBirth;
    final formattedBirthDate =
        birthDate == null ? '—' : dateFormat.format(birthDate);
    final age = _formatClientAge(birthDate);
    final channelPrefs = client.channelPreferences;
    final chips = _buildPreferenceChips(context, channelPrefs);
    final notes = client.notes?.trim() ?? '';
    final hasNotes = notes.isNotEmpty;
    final hasConsents = client.marketedConsents.isNotEmpty;

    final personalFields = <_InfoFieldData>[
      _InfoFieldData(label: 'Nome e cognome', value: client.fullName),
      _InfoFieldData(label: 'Data di nascita', value: formattedBirthDate),
      _InfoFieldData(label: 'Età', value: age),
      _InfoFieldData(
        label: 'Numero cliente',
        value: client.clientNumber ?? '—',
      ),
      _InfoFieldData(label: 'Professione', value: client.profession ?? '—'),
      _InfoFieldData(
        label: 'Come ci ha conosciuto',
        value: client.referralSource ?? '—',
      ),
      _InfoFieldData(
        label: 'Punti fedeltà',
        value: client.loyaltyPoints.toString(),
      ),
      if (salon != null)
        _InfoFieldData(label: 'Salone associato', value: salon!.name),
    ];

    final contactFields = <_InfoFieldData>[
      _InfoFieldData(label: 'Telefono', value: client.phone),
      _InfoFieldData(label: 'Email', value: client.email ?? '—'),
      _InfoFieldData(label: 'Indirizzo', value: client.address ?? '—'),
      _InfoFieldData(label: 'Città', value: client.city ?? '—'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 960;
        final cardWidth =
            useTwoColumns
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: Card(
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
                      _InfoFieldsWrap(fields: personalFields),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contatti e preferenze',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoFieldsWrap(fields: contactFields),
                      const SizedBox(height: 16),
                      Text(
                        'Preferenze contatto',
                        style: theme.textTheme.titleSmall?.copyWith(
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
                        hasNotes
                            ? notes
                            : 'Nessuna nota presente per questo cliente.',
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
                                      avatar: const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        '${_consentLabel(consent.type)} · ${dateFormat.format(consent.acceptedAt)}',
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
            ),
          ],
        );
      },
    );
  }
}

class _InfoFieldsWrap extends StatelessWidget {
  const _InfoFieldsWrap({required this.fields});

  final List<_InfoFieldData> fields;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (fields.isEmpty) {
          return const SizedBox.shrink();
        }
        final isWide = constraints.maxWidth >= 520;
        final fieldWidth =
            isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map(
                (field) => SizedBox(
                  width: fieldWidth,
                  child: _ReadonlyField(label: field.label, value: field.value),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
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

class _InfoFieldData {
  const _InfoFieldData({required this.label, required this.value});

  final String label;
  final String value;
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      initialValue: value,
      minLines: 1,
      maxLines: null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
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
