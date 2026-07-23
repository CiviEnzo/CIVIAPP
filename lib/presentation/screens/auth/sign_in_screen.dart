import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:you_book/presentation/common/auth_error_messages.dart';
import 'package:you_book/presentation/screens/auth/legal_links.dart';
import 'package:you_book/presentation/common/app_version_badge.dart';
import 'package:url_launcher/url_launcher.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.notice, this.redirectPath});

  final String? notice;
  final String? redirectPath;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  static const _supportEmail = 'info@civiapp.it';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late final TapGestureRecognizer _supportEmailTapRecognizer;
  bool _isObscured = true;
  bool _isLoading = false;
  bool _noticeScheduled = false;
  ProviderSubscription<SessionState>? _sessionSubscription;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _supportEmailTapRecognizer.dispose();
    _closeSessionSubscription();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _supportEmailTapRecognizer =
        TapGestureRecognizer()..onTap = _openSupportEmail;
    _scheduleNotice();
  }

  @override
  void didUpdateWidget(SignInScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice != widget.notice) {
      _noticeScheduled = false;
      _scheduleNotice();
    }
  }

  void _scheduleNotice() {
    if (_noticeScheduled) {
      return;
    }
    final message = widget.notice;
    if (message == null || message.isEmpty) {
      return;
    }
    _noticeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showAppSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Accedi a YouBook',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Usa l\'email collegata al tuo salone o al tuo profilo cliente. Dopo l\'accesso ti porteremo automaticamente nell\'area corretta.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Se sei un cliente puoi anche cercare un salone senza account e registrarti quando vuoi prenotare.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.tonalIcon(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => context.go('/register'),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Registrati come cliente'),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              onEditingComplete:
                                  () => _passwordFocusNode.requestFocus(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Inserisci l\'email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _isObscured,
                              focusNode: _passwordFocusNode,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed:
                                      () => setState(
                                        () => _isObscured = !_isObscured,
                                      ),
                                  icon: Icon(
                                    _isObscured
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submitFromKeyboard(),
                              autocorrect: false,
                              enableSuggestions: false,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Inserisci la password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _isLoading ? null : _signIn,
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Accedi'),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _goToPasswordReset,
                              child: const Text('Password dimenticata?'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : () => context.go('/client'),
                              icon: const Icon(Icons.search_rounded),
                              label: const Text(
                                'Scopri i saloni senza account',
                              ),
                            ),
                            const SizedBox(height: 12),
                            /*OutlinedButton.icon(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () => context.go('/register-center'),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Registrati come centro'),
                        ),
                        const SizedBox(height: 12),*/
                            Text.rich(
                              TextSpan(
                                text:
                                    'Accesso riservato a clienti, operatori e amministratori abilitati. Se il tuo account non e\' ancora attivo, contatta il salone; se sei amministratore di salone, scrivi a ',
                                children: [
                                  TextSpan(
                                    text: _supportEmail,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: _supportEmailTapRecognizer,
                                    mouseCursor: SystemMouseCursors.click,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const LegalLinksRow(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const AppVersionBadge(),
        ],
      ),
    );
  }

  void _submitFromKeyboard() {
    if (_isLoading) {
      return;
    }
    _signIn();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (_handleExistingSession()) {
      return;
    }

    _ensureSessionListener();

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    var didFail = false;
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(email, password);
      if (!mounted) {
        return;
      }
      if (_handleExistingSession()) {
        return;
      }
    } on Exception catch (error) {
      didFail = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(italianLoginErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      if (didFail) {
        _closeSessionSubscription();
      }
    }
  }

  void _ensureSessionListener() {
    if (_sessionSubscription != null) {
      return;
    }
    _sessionSubscription = ref.listenManual<SessionState>(
      sessionControllerProvider,
      (previous, next) {
        if (!mounted) {
          _closeSessionSubscription();
          return;
        }
        if (next.user == null) {
          return;
        }
        _navigateForSession(next);
      },
    );
  }

  bool _handleExistingSession() {
    if (!mounted) {
      return false;
    }
    final session = ref.read(sessionControllerProvider);
    if (session.user == null) {
      return false;
    }
    _navigateForSession(session);
    return true;
  }

  void _navigateForSession(SessionState session) {
    if (!mounted) {
      _closeSessionSubscription();
      return;
    }
    if (session.role == UserRole.admin && session.user?.isEnabled == false) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Account in attesa di abilitazione.')),
      );
      _closeSessionSubscription();
      return;
    }
    final router = ref.read(appRouterProvider);
    router.go(_destinationForSession(session));
    _closeSessionSubscription();
  }

  String _destinationForSession(SessionState session) {
    final redirectPath = _safeInternalRedirect(widget.redirectPath);
    if (session.requiresPasswordChange) {
      return '/first-password-change';
    }
    if (redirectPath != null && !session.requiresProfile) {
      return redirectPath;
    }
    if (session.requiresProfile) {
      return '/onboarding';
    }
    switch (session.role) {
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

  String? _safeInternalRedirect(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !value.startsWith('/')) {
      return null;
    }
    return value;
  }

  void _closeSessionSubscription() {
    _sessionSubscription?.close();
    _sessionSubscription = null;
  }

  void _goToPasswordReset() {
    final email = _emailController.text.trim();
    final params = <String, dynamic>{};
    if (email.isNotEmpty) {
      params['email'] = email;
    }
    context.goNamed('password_reset', queryParameters: params);
  }

  Future<void> _openSupportEmail() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final launched = await launchUrl(
      Uri(scheme: 'mailto', path: _supportEmail),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && messenger != null && messenger.mounted) {
      messenger.showAppSnackBar(
        const SnackBar(content: Text('Impossibile aprire il client email.')),
      );
    }
  }
}
