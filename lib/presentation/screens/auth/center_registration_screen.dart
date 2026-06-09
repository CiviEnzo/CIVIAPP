import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/app/router_constants.dart';
import 'package:you_book/presentation/screens/auth/legal_links.dart';

class CenterRegistrationScreen extends ConsumerStatefulWidget {
  const CenterRegistrationScreen({super.key});

  @override
  ConsumerState<CenterRegistrationScreen> createState() =>
      _CenterRegistrationScreenState();
}

class _CenterRegistrationScreenState
    extends ConsumerState<CenterRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salonNameController = TextEditingController();
  final _salonAddressController = TextEditingController();
  final _salonCityController = TextEditingController();
  final _salonPhoneController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;
  bool _isLoading = false;
  bool _hasAcceptedLegalTerms = false;

  @override
  void dispose() {
    _salonNameController.dispose();
    _salonAddressController.dispose();
    _salonCityController.dispose();
    _salonPhoneController.dispose();
    _adminNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrazione centro')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
                        'Crea il tuo centro',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Compila i dati del centro e dell\'amministratore. La richiesta verrà verificata e l\'account sarà abilitato dopo approvazione.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Text('Dati centro', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _salonNameController,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome centro',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il nome del centro';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _salonAddressController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Indirizzo',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci l\'indirizzo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _salonCityController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Città',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci la città';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _salonPhoneController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Telefono',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il numero di telefono';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Dati amministratore',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _adminNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome e cognome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il nome dell\'amministratore';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email amministratore',
                          prefixIcon: Icon(Icons.email_outlined),
                          helperText:
                              'Useremo questa email anche come contatto del centro.',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Inserisci l\'email';
                          }
                          if (!text.contains('@') || !text.contains('.')) {
                            return 'Email non valida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _isPasswordObscured,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(
                                  () =>
                                      _isPasswordObscured =
                                          !_isPasswordObscured,
                                ),
                            icon: Icon(
                              _isPasswordObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) {
                          final text = value ?? '';
                          if (text.isEmpty) {
                            return 'Inserisci la password';
                          }
                          if (text.length < 6) {
                            return 'La password deve contenere almeno 6 caratteri';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _isConfirmObscured,
                        decoration: InputDecoration(
                          labelText: 'Conferma password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(
                                  () =>
                                      _isConfirmObscured = !_isConfirmObscured,
                                ),
                            icon: Icon(
                              _isConfirmObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) {
                          final text = value ?? '';
                          if (text.isEmpty) {
                            return 'Conferma la password';
                          }
                          if (text != _passwordController.text) {
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
                        onPressed: _isLoading ? null : _register,
                        child:
                            _isLoading
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Invia richiesta'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Hai già un account? Accedi'),
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    ref.read(centerRegistrationInProgressProvider.notifier).state = true;

    final salonName = _salonNameController.text.trim();
    final salonAddress = _salonAddressController.text.trim();
    final salonCity = _salonCityController.text.trim();
    final salonPhone = _salonPhoneController.text.trim();
    final adminName = _adminNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await ref
          .read(authRepositoryProvider)
          .registerCenterAdmin(
            email: email,
            password: password,
            displayName: adminName,
            salonName: salonName,
            salonAddress: salonAddress,
            salonCity: salonCity,
            salonPhone: salonPhone,
            acceptedLegalTerms: _hasAcceptedLegalTerms,
          );
      if (!mounted) return;
      await _resetLocalSession();
      if (!mounted) return;
      context.goNamed(
        'sign_in',
        queryParameters: const {
          noticeQueryParam:
              'Richiesta inviata. Il tuo account sarà abilitato dopo verifica.',
        },
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      ref.read(centerRegistrationInProgressProvider.notifier).state = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(Exception error) {
    final message = error.toString();
    if (message.contains('email-already-in-use')) {
      return 'Esiste già un account con questa email.';
    }
    if (message.contains('invalid-email')) {
      return 'Email non valida. Verifica e riprova.';
    }
    if (message.contains('weak-password')) {
      return 'La password è troppo debole. Usa almeno 6 caratteri.';
    }
    if (message.contains('network-request-failed')) {
      return 'Impossibile completare la registrazione. Controlla la connessione.';
    }
    return 'Registrazione non riuscita: $message';
  }

  Future<void> _resetLocalSession() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(appUserProvider);
    ref.invalidate(appDataProvider);
    ref.invalidate(appBootstrapProvider);
    ref.invalidate(sessionControllerProvider);
  }
}
