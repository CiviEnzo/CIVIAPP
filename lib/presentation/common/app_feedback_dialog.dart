import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/services/feedback/app_feedback_service.dart';

Future<void> showAppFeedbackDialog(
  BuildContext context,
  WidgetRef ref, {
  required String source,
}) {
  unawaited(
    ref.read(appTelemetryServiceProvider).logFeedbackStarted(source: source),
  );
  return showDialog<void>(
    context: context,
    builder: (_) => _AppFeedbackDialog(source: source),
  );
}

class _AppFeedbackDialog extends ConsumerStatefulWidget {
  const _AppFeedbackDialog({required this.source});

  final String source;

  @override
  ConsumerState<_AppFeedbackDialog> createState() => _AppFeedbackDialogState();
}

class _AppFeedbackDialogState extends ConsumerState<_AppFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  AppFeedbackCategory _category = AppFeedbackCategory.bug;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Feedback app'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<AppFeedbackCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: AppFeedbackCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    _isSubmitting
                        ? null
                        : (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                enabled: !_isSubmitting,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Messaggio',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.length < 8) {
                    return 'Scrivi almeno 8 caratteri.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Invieremo anche versione app, piattaforma e account per diagnosticare il problema.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon:
              _isSubmitting
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.send_rounded),
          label: Text(_isSubmitting ? 'Invio...' : 'Invia'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final session = ref.read(sessionControllerProvider);

    try {
      await ref
          .read(appFeedbackServiceProvider)
          .submitFeedback(
            category: _category,
            message: _messageController.text,
            source: widget.source,
            userRole: session.user?.role?.name,
            contextEntityId: session.userId,
          );
      if (!mounted) {
        return;
      }
      navigator.pop();
      messenger.showAppSnackBar(
        const SnackBar(content: Text('Feedback inviato. Grazie.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      messenger.showAppSnackBar(
        SnackBar(content: Text('Invio feedback non riuscito: $error')),
      );
    }
  }
}
