import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:you_book/domain/legal/legal_documents.dart';

class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({
    super.key,
    this.alignment = WrapAlignment.center,
    this.dense = false,
  });

  final WrapAlignment alignment;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style =
        dense
            ? TextButton.styleFrom(visualDensity: VisualDensity.compact)
            : null;
    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: dense ? 4 : 8,
      runSpacing: dense ? 0 : 4,
      children: [
        TextButton(
          style: style,
          onPressed: () => openLegalUri(context, legalPrivacyUri),
          child: const Text('Privacy policy'),
        ),
        TextButton(
          style: style,
          onPressed: () => openLegalUri(context, legalTermsUri),
          child: const Text('Termini di utilizzo'),
        ),
      ],
    );
  }
}

class LegalAcceptanceField extends StatelessWidget {
  const LegalAcceptanceField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormField<bool>(
      validator: (_) {
        if (value) {
          return null;
        }
        return 'Devi accettare termini e privacy per continuare.';
      },
      builder: (field) {
        void updateValue(bool? nextValue) {
          if (!enabled) {
            return;
          }
          final accepted = nextValue ?? false;
          onChanged(accepted);
          field.didChange(accepted);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: enabled ? () => updateValue(!value) : null,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: value,
                    onChanged: enabled ? updateValue : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Ho letto e accetto i Termini di utilizzo e l\'Informativa privacy di YouBook.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 40),
              child: LegalLinksRow(alignment: WrapAlignment.start, dense: true),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  field.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> openLegalUri(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final launched = await launchUrl(
    uri,
    mode: LaunchMode.platformDefault,
    webOnlyWindowName: '_blank',
  );
  if (!launched) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Impossibile aprire ${uri.toString()}')),
    );
  }
}
