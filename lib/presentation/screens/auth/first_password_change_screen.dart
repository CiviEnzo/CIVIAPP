import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/screens/auth/legal_links.dart';

class FirstPasswordChangeScreen extends ConsumerStatefulWidget {
  const FirstPasswordChangeScreen({super.key});

  @override
  ConsumerState<FirstPasswordChangeScreen> createState() =>
      _FirstPasswordChangeScreenState();
}

class _FirstPasswordChangeScreenState
    extends ConsumerState<FirstPasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _hasAcceptedLegalTerms = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(sessionControllerProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambio password'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : () => performSignOut(ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Esci'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Imposta una nuova password',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.email ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Password temporanea',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(
                                  () => _obscureCurrent = !_obscureCurrent,
                                ),
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Inserisci la password temporanea';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Nuova password',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            onPressed:
                                () =>
                                    setState(() => _obscureNew = !_obscureNew),
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Conferma nuova password',
                          prefixIcon: const Icon(Icons.done_all_rounded),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value != _newPasswordController.text) {
                            return 'Le password non coincidono';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      LegalAcceptanceField(
                        value: _hasAcceptedLegalTerms,
                        enabled: !_isLoading,
                        onChanged:
                            (value) =>
                                setState(() => _hasAcceptedLegalTerms = value),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Continua'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) {
      return 'Usa almeno 8 caratteri';
    }
    if (password == _currentPasswordController.text) {
      return 'Scegli una password diversa da quella temporanea';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .completeRequiredPasswordChange(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
            acceptedLegalTerms: _hasAcceptedLegalTerms,
          );
      if (!mounted) {
        return;
      }
      final session = ref.read(sessionControllerProvider);
      final user = session.user;
      if (user != null) {
        ref
            .read(sessionControllerProvider.notifier)
            .updateUser(user.copyWith(mustChangePassword: false));
      }
      ref.invalidate(appUserProvider);
      ref.read(appRouterProvider).go(_destinationForRole(session.role));
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(Exception error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Password temporanea non corretta.';
        case 'weak-password':
          return 'La nuova password e troppo debole.';
        case 'requires-recent-login':
          return 'Sessione scaduta. Esci e accedi di nuovo.';
      }
    }
    if (error is FirebaseFunctionsException) {
      return 'Password aggiornata, ma completamento non riuscito. Riprova usando la nuova password.';
    }
    return 'Cambio password non riuscito: $error';
  }
}

String _destinationForRole(UserRole? role) {
  switch (role) {
    case UserRole.admin:
      return '/admin';
    case UserRole.staff:
      return '/staff';
    case UserRole.client:
      return '/client';
    case null:
      return '/';
  }
}
