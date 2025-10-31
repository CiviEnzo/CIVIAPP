import 'package:you_book/app/providers.dart';
import 'package:you_book/app/router_constants.dart';
import 'package:you_book/domain/entities/client_registration_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ClientRegistrationScreen extends ConsumerStatefulWidget {
  const ClientRegistrationScreen({super.key});

  @override
  ConsumerState<ClientRegistrationScreen> createState() =>
      _ClientRegistrationScreenState();
}

class _ClientRegistrationScreenState
    extends ConsumerState<ClientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;
  bool _isLoading = false;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrazione cliente')),
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
                        'Crea il tuo account cliente',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inserisci email e password per creare il tuo account. Dopo l\'accesso potrai scegliere il salone e inviare una richiesta di registrazione che verrà approvata dall\'amministratore.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _firstNameController,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il nome';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Cognome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il cognome';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateOfBirthController,
                        decoration: const InputDecoration(
                          labelText: 'Data di nascita',
                          prefixIcon: Icon(Icons.cake_outlined),
                          helperText: 'Formato richiesto: gg/mm/aaaa',
                        ),
                        keyboardType: TextInputType.datetime,
                        textInputAction: TextInputAction.next,
                        inputFormatters: const [_DateInputFormatter()],
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Inserisci la data di nascita';
                          }
                          if (_parseDate(text) == null) {
                            return 'Formato non valido. Usa gg/mm/aaaa';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Numero di telefono',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il numero di telefono';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
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
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon:
                            _isLoading
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                                : const Icon(Icons.person_add_rounded),
                        label: const Text('Registrati'),
                        onPressed: _isLoading ? null : _register,
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
    ref.read(clientRegistrationInProgressProvider.notifier).state = true;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final dateOfBirthText = _dateOfBirthController.text.trim();
    final dateOfBirth = _parseDate(dateOfBirthText);
    final composedDisplayName = [
      firstName,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ');
    try {
      await ref
          .read(authRepositoryProvider)
          .registerClient(
            email: email,
            password: password,
            displayName:
                composedDisplayName.isEmpty ? null : composedDisplayName,
          );
      if (!mounted) {
        return;
      }
      ref
          .read(clientRegistrationDraftProvider.notifier)
          .save(
            ClientRegistrationDraft(
              firstName: firstName,
              lastName: lastName,
              email: email,
              phone: phone,
              dateOfBirth: dateOfBirth,
            ),
          );
      if (!mounted) return;
      context.goNamed(
        'sign_in',
        queryParameters: const {verifyEmailQueryParam: '1'},
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      ref.read(clientRegistrationInProgressProvider.notifier).state = false;
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

  DateTime? _parseDate(String input) {
    if (input.isEmpty) {
      return null;
    }
    try {
      return _dateFormat.parseStrict(input);
    } catch (_) {
      return null;
    }
  }
}

class _DateInputFormatter extends TextInputFormatter {
  const _DateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
