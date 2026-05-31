import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/presentation/common/app_version_badge.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  final _confirmationController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final email = user?.email?.trim();
    final roleLabel = switch (user?.role?.name) {
      'admin' => 'Amministratore',
      'staff' => 'Operatore',
      'client' => 'Cliente',
      _ => 'Account',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eliminazione account'),
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed: _isDeleting ? null : () => context.go(_fallbackPath()),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
                children: [
                  Icon(
                    Icons.delete_forever_rounded,
                    size: 42,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Richiesta eliminazione account YouBook',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email == null || email.isEmpty
                        ? '$roleLabel collegato.'
                        : '$roleLabel collegato a $email.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cosa succede',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _DeletionInfoRow(
                            icon: Icons.person_remove_alt_1_rounded,
                            text:
                                'L\'account di accesso viene eliminato da Firebase Authentication.',
                          ),
                          const _DeletionInfoRow(
                            icon: Icons.folder_delete_rounded,
                            text:
                                'I dati personali collegati al profilo vengono rimossi.',
                          ),
                          const _DeletionInfoRow(
                            icon: Icons.receipt_long_rounded,
                            text:
                                'Alcuni dati fiscali o amministrativi possono essere conservati se richiesto dalla legge.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmationController,
                    enabled: !_isDeleting,
                    decoration: const InputDecoration(
                      labelText: 'Scrivi ELIMINA per confermare',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _deleteAccount(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _isDeleting ? null : _deleteAccount,
                    icon:
                        _isDeleting
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_forever_rounded),
                    label: Text(
                      _isDeleting
                          ? 'Eliminazione in corso...'
                          : 'Conferma eliminazione account',
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _isDeleting ? null : () => context.go(_fallbackPath()),
                    child: const Text('Annulla'),
                  ),
                ],
              ),
            ),
          ),
          const AppVersionBadge(),
        ],
      ),
    );
  }

  String _fallbackPath() {
    final role = ref.read(sessionControllerProvider).role;
    return switch (role?.name) {
      'admin' => '/admin',
      'staff' => '/staff',
      'client' => '/client',
      _ => '/',
    };
  }

  Future<void> _deleteAccount() async {
    final confirmation = _confirmationController.text.trim().toUpperCase();
    if (confirmation != 'ELIMINA') {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Scrivi ELIMINA per confermare.')),
      );
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west3');
      await functions.httpsCallable('deleteCurrentUserAccount').call({
        'confirmation': confirmation,
      });
      if (!mounted) {
        return;
      }
      await performSignOut(ref);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Account eliminato correttamente.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(_messageForFunctionsError(error))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Eliminazione non riuscita: $error')),
      );
    }
  }

  String _messageForFunctionsError(FirebaseFunctionsException error) {
    return switch (error.code) {
      'unauthenticated' => 'Sessione scaduta. Accedi di nuovo.',
      'invalid-argument' => 'Conferma non valida.',
      _ => error.message ?? 'Eliminazione non riuscita.',
    };
  }
}

class _DeletionInfoRow extends StatelessWidget {
  const _DeletionInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
