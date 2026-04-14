import 'package:you_book/app/providers.dart';
import 'package:you_book/services/whatsapp_service.dart';
import 'package:you_book/services/whatsapp_embedded_signup_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class WhatsAppSettingsPage extends ConsumerStatefulWidget {
  const WhatsAppSettingsPage({super.key, required this.salonId});

  final String salonId;

  @override
  ConsumerState<WhatsAppSettingsPage> createState() =>
      _WhatsAppSettingsPageState();
}

class _WhatsAppSettingsPageState extends ConsumerState<WhatsAppSettingsPage> {
  var _phase = WhatsAppEmbeddedSignupPhase.idle;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  bool _isVerificationFlowRunning = false;
  String? _activeSessionId;
  String? _activePin;
  String? _lastFlowError;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(whatsappConfigProvider(widget.salonId));
    final service = ref.watch(whatsappServiceProvider);
    final sendEndpoint = service.sendEndpoint?.toString() ?? 'Non configurato';

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorState(error: error),
      data: (config) {
        final theme = Theme.of(context);
        final isConfigured = config?.isConfigured ?? false;
        final updatedAt = config?.updatedAt?.toLocal();
        final registeredAt = config?.registeredAt?.toLocal();
        final businessId = _mask(config?.businessId);
        final wabaId = _mask(config?.wabaId);
        final phoneNumberId = config?.phoneNumberId ?? '—';
        final displayPhone = config?.displayPhoneNumber ?? '—';
        final mode = config?.mode ?? 'Non configurato';
        final updatedAtLabel =
            updatedAt != null ? updatedAt.toIso8601String() : '—';
        final registeredAtLabel =
            registeredAt != null ? registeredAt.toIso8601String() : '—';
        final onboardingStatusLabel = _formatOnboardingStatus(
          config?.onboardingStatus,
        );
        final registrationStatusLabel = _formatRegistrationStatus(
          config?.registrationStatus,
        );
        final connectionMethodLabel = _formatConnectionMethod(
          config?.connectionMethod,
        );
        final statusAccent =
            isConfigured
                ? const Color(0xFF1E8E5A)
                : config?.needsVerification == true
                ? const Color(0xFFE09A1A)
                : config?.needsReconnect == true
                ? const Color(0xFFB84A4A)
                : const Color(0xFFE09A1A);
        final accountAccent =
            isConfigured ? const Color(0xFF2E9C6A) : const Color(0xFFF0A43A);
        const technicalAccent = Color(0xFF1E6FA8);
        const endpointAccent = Color(0xFF6B57D9);
        final bannerMessage = _buildBannerMessage(config);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              _SettingsHeader(
                isConfigured: isConfigured,
                connectLabel: _primaryActionLabel(config),
                connectIcon:
                    config?.needsVerification == true
                        ? Icons.sms_rounded
                        : Icons.link_rounded,
                onConnect:
                    _isPrimaryActionEnabled(config)
                        ? () => _handlePrimaryAction(context, config)
                        : null,
                onDisconnect:
                    config?.phoneNumberId != null
                        ? () => _handleDisconnect(context)
                        : null,
                isBusy:
                    _isConnecting ||
                    _isDisconnecting ||
                    _isVerificationFlowRunning,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 980;
                  final leftColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsBoardCard(
                        title: 'Attivazione numero',
                        subtitle:
                            'Configurazione manuale del token Meta, del WABA e del numero WhatsApp Business con verifica OTP opzionale.',
                        icon: Icons.flash_on_rounded,
                        accentColor: statusAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatusChip(
                                  icon: Icons.sync_alt_rounded,
                                  label: onboardingStatusLabel,
                                  background: statusAccent.withValues(
                                    alpha: 0.14,
                                  ),
                                  foreground: statusAccent,
                                ),
                                _StatusChip(
                                  icon: Icons.verified_outlined,
                                  label: registrationStatusLabel,
                                  background: technicalAccent.withValues(
                                    alpha: 0.12,
                                  ),
                                  foreground: technicalAccent,
                                ),
                                _StatusChip(
                                  icon: Icons.account_tree_outlined,
                                  label: connectionMethodLabel,
                                  background: endpointAccent.withValues(
                                    alpha: 0.12,
                                  ),
                                  foreground: endpointAccent,
                                ),
                              ],
                            ),
                            if (bannerMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: statusAccent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: statusAccent.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  bannerMessage,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: statusAccent,
                                  ),
                                ),
                              ),
                            ],
                            if (_lastFlowError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _lastFlowError!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFB84A4A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (!kIsWeb) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Il collegamento diretto con Meta e disponibile solo dal pannello admin web.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if (config?.needsVerification == true) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed:
                                    _isVerificationFlowRunning
                                        ? null
                                        : () => _handleVerificationFlow(
                                          context,
                                          config,
                                        ),
                                icon:
                                    _isVerificationFlowRunning
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.sms_rounded),
                                label: const Text(
                                  'Richiedi codice e completa verifica',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SettingsBoardCard(
                        title: 'Account WhatsApp',
                        subtitle:
                            'Stato connessione, numero attivo e riferimenti principali del WABA collegato.',
                        icon: Icons.phone_android_rounded,
                        accentColor: accountAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatusChip(
                                  icon:
                                      isConfigured
                                          ? Icons.check_circle_outline_rounded
                                          : config?.needsReconnect == true
                                          ? Icons.warning_amber_rounded
                                          : Icons.link_off_rounded,
                                  label:
                                      isConfigured
                                          ? 'Account collegato'
                                          : config?.needsReconnect == true
                                          ? 'Ricollegamento richiesto'
                                          : 'Da configurare',
                                  background: statusAccent.withValues(
                                    alpha: 0.14,
                                  ),
                                  foreground: statusAccent,
                                ),
                                _StatusChip(
                                  icon: Icons.settings_rounded,
                                  label: mode,
                                  background: technicalAccent.withValues(
                                    alpha: 0.12,
                                  ),
                                  foreground: technicalAccent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _SettingsDetailGrid(
                              entries: [
                                _SettingsDetailEntry(
                                  label: 'Numero visualizzato',
                                  value: displayPhone,
                                ),
                                _SettingsDetailEntry(
                                  label: 'Phone Number ID',
                                  value: phoneNumberId,
                                ),
                                _SettingsDetailEntry(
                                  label: 'Business Manager ID',
                                  value: businessId,
                                ),
                                _SettingsDetailEntry(
                                  label: 'WABA ID',
                                  value: wabaId,
                                ),
                                _SettingsDetailEntry(
                                  label: 'Ultimo aggiornamento',
                                  value: updatedAtLabel,
                                ),
                                _SettingsDetailEntry(
                                  label: 'Registrato il',
                                  value: registeredAtLabel,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final rightColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsBoardCard(
                        title: 'Stato operativo',
                        subtitle:
                            'Metodo di connessione, ultimo codice richiesto e stato della registrazione del numero.',
                        icon: Icons.security_rounded,
                        accentColor: technicalAccent,
                        child: _SettingsDetailGrid(
                          entries: [
                            _SettingsDetailEntry(
                              label: 'Metodo connessione',
                              value: connectionMethodLabel,
                            ),
                            _SettingsDetailEntry(
                              label: 'Stato onboarding',
                              value: onboardingStatusLabel,
                            ),
                            _SettingsDetailEntry(
                              label: 'Stato registrazione',
                              value: registrationStatusLabel,
                            ),
                            _SettingsDetailEntry(
                              label: 'Ultimo codice',
                              value: config?.lastCodeMethod ?? '—',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SettingsBoardCard(
                        title: 'Endpoint di invio template',
                        subtitle:
                            'Endpoint HTTPS da usare per inviare template approvati tramite Cloud Functions.',
                        icon: Icons.hub_rounded,
                        accentColor: endpointAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: endpointAccent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: endpointAccent.withValues(alpha: 0.2),
                                ),
                              ),
                              child: SelectableText(
                                sendEndpoint,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  color: endpointAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed:
                                  () => _copyEndpoint(context, sendEndpoint),
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copia URL'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftColumn,
                        const SizedBox(height: 16),
                        rightColumn,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: leftColumn),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: rightColumn),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handlePrimaryAction(
    BuildContext context,
    WhatsAppConfig? config,
  ) async {
    if (config?.needsVerification == true) {
      await _handleVerificationFlow(context, config);
      return;
    }
    await _handleConnect(context, config);
  }

  Future<void> _handleConnect(
    BuildContext context,
    WhatsAppConfig? config,
  ) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Completa il collegamento dal pannello admin web di YouBook.',
          ),
        ),
      );
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);
    final manualSetup = await _promptManualSetup(
      context,
      initialConfig: config,
      initialPin: _activePin,
    );
    if (manualSetup == null || !mounted) {
      return;
    }

    setState(() {
      _isConnecting = true;
      _phase =
          manualSetup.pin != null
              ? WhatsAppEmbeddedSignupPhase.registering
              : WhatsAppEmbeddedSignupPhase.ready;
      _activePin = manualSetup.pin;
      _activeSessionId = null;
      _lastFlowError = null;
    });

    try {
      final service = ref.read(whatsappServiceProvider);
      final result = await service.configureManualSetup(
        salonId: widget.salonId,
        accessToken: manualSetup.accessToken,
        businessId: manualSetup.businessId,
        wabaId: manualSetup.wabaId,
        phoneNumberId: manualSetup.phoneNumberId,
        displayPhoneNumber: manualSetup.displayPhoneNumber,
        pin: manualSetup.pin,
      );
      if (!mounted) {
        return;
      }

      await _handleEmbeddedSignupResult(
        result,
        autoStartVerification:
            result.phase == WhatsAppEmbeddedSignupPhase.awaitingVerification,
      );
      if (!mounted) {
        return;
      }
      scaffold.showAppSnackBar(
        SnackBar(
          content: Text(
            result.phase == WhatsAppEmbeddedSignupPhase.ready
                ? 'Configurazione manuale WhatsApp salvata con successo.'
                : 'Meta richiede ancora la verifica del numero.',
          ),
        ),
      );
    } catch (error) {
      final message = _errorMessage(error);
      if (mounted) {
        setState(() {
          _phase = WhatsAppEmbeddedSignupPhase.error;
          _lastFlowError = message;
        });
      }
      scaffold.showAppSnackBar(
        SnackBar(content: Text('Errore durante il collegamento: $message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _handleVerificationFlow(
    BuildContext context,
    WhatsAppConfig? config,
  ) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'La verifica del numero e disponibile solo dal pannello admin web.',
          ),
        ),
      );
      return;
    }

    final method = await _promptCodeMethod(context);
    if (method == null || !mounted) {
      return;
    }

    setState(() {
      _isVerificationFlowRunning = true;
      _lastFlowError = null;
      _phase = WhatsAppEmbeddedSignupPhase.awaitingVerification;
    });

    final scaffold = ScaffoldMessenger.of(this.context);
    try {
      final service = ref.read(whatsappServiceProvider);
      final requestResult = await service.requestPhoneVerificationCode(
        salonId: widget.salonId,
        codeMethod: method,
        sessionId: _activeSessionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeSessionId = requestResult.sessionId ?? _activeSessionId;
      });

      final verificationCode = await _promptVerificationCode(this.context);
      if (verificationCode == null || !mounted) {
        return;
      }
      final pin = _activePin ?? await _promptPin(this.context);
      if (pin == null || !mounted) {
        return;
      }
      _activePin = pin;

      final confirmResult = await service.confirmPhoneVerificationCode(
        salonId: widget.salonId,
        verificationCode: verificationCode,
        pin: pin,
        sessionId: _activeSessionId,
      );
      if (!mounted) {
        return;
      }

      await _handleEmbeddedSignupResult(confirmResult);
      scaffold.showAppSnackBar(
        const SnackBar(
          content: Text(
            'Numero WhatsApp verificato e registrato con successo.',
          ),
        ),
      );
    } catch (error) {
      final message = _errorMessage(error);
      if (mounted) {
        setState(() {
          _phase = WhatsAppEmbeddedSignupPhase.awaitingVerification;
          _lastFlowError = message;
        });
      }
      scaffold.showAppSnackBar(
        SnackBar(content: Text('Errore durante la verifica: $message')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerificationFlowRunning = false;
        });
      }
    }
  }

  Future<void> _handleEmbeddedSignupResult(
    WhatsAppEmbeddedSignupResult result, {
    bool autoStartVerification = false,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _phase = result.phase;
      _activeSessionId = result.sessionId ?? _activeSessionId;
      _lastFlowError = null;
    });

    if (result.phase == WhatsAppEmbeddedSignupPhase.ready) {
      _activePin = null;
      return;
    }

    if (autoStartVerification) {
      await _handleVerificationFlow(context, null);
    }
  }

  Future<void> _handleDisconnect(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Disconnetti WhatsApp'),
            content: const Text(
              'Sei sicuro di voler scollegare il numero WhatsApp del salone? Dovrai ripetere l\'onboarding per inviare nuovi messaggi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Disconnetti'),
              ),
            ],
          ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isDisconnecting = true;
    });

    try {
      await ref.read(whatsappServiceProvider).disconnect(widget.salonId);
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = WhatsAppEmbeddedSignupPhase.idle;
        _activeSessionId = null;
        _activePin = null;
        _lastFlowError = null;
      });
      scaffold.showAppSnackBar(
        const SnackBar(content: Text('Account WhatsApp scollegato.')),
      );
    } catch (error) {
      scaffold.showAppSnackBar(
        SnackBar(content: Text('Errore durante la disconnessione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDisconnecting = false;
        });
      }
    }
  }

  void _copyEndpoint(BuildContext context, String endpoint) {
    if (endpoint == 'Non configurato') {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Configura SEND_ENDPOINT con --dart-define o Firebase Remote Config.',
          ),
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: endpoint));
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Endpoint copiato negli appunti.')),
    );
  }

  static String _mask(String? value) {
    if (value == null || value.isEmpty) {
      return '—';
    }
    if (value.length <= 6) {
      return value;
    }
    final suffix = value.substring(value.length - 4);
    return '•••$suffix';
  }

  bool _isPrimaryActionEnabled(WhatsAppConfig? config) {
    if (_isConnecting || _isDisconnecting || _isVerificationFlowRunning) {
      return false;
    }
    if (!kIsWeb) {
      return true;
    }
    return true;
  }

  String _primaryActionLabel(WhatsAppConfig? config) {
    if (_isConnecting) {
      return 'Salvataggio...';
    }
    if (_isVerificationFlowRunning) {
      return 'Verifica in corso...';
    }
    if (config?.needsVerification == true) {
      return 'Completa verifica numero';
    }
    if (config?.isConfigured == true) {
      return 'Aggiorna configurazione';
    }
    if (config?.needsReconnect == true) {
      return 'Configura manualmente';
    }
    return 'Configura manualmente';
  }

  String? _buildBannerMessage(WhatsAppConfig? config) {
    if (_lastFlowError != null && _lastFlowError!.isNotEmpty) {
      return _lastFlowError;
    }
    if (config?.needsReconnect == true) {
      return 'Questo salone ha una configurazione WhatsApp legacy. Inserisci manualmente token, WABA e phone number ID per passare al nuovo setup.';
    }
    if (config?.needsVerification == true) {
      return 'La configurazione e stata salvata, ma il numero non e ancora registrato. Richiedi un codice SMS o chiamata e completa la verifica.';
    }
    if (config?.isConfigured == true) {
      return 'Numero registrato e pronto per l’invio template usando il token configurato per questo salone.';
    }
    if (_phase == WhatsAppEmbeddedSignupPhase.registering) {
      return 'Configurazione manuale salvata. Completa la registrazione del numero se Meta richiede ancora OTP.';
    }
    return 'Configura manualmente access token, WABA ID e Phone Number ID del salone per inviare template con il suo numero WhatsApp Business.';
  }

  String _formatOnboardingStatus(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'ready':
        return 'Pronto';
      case 'awaiting_verification':
        return 'In attesa OTP';
      case 'registering':
        return 'Registrazione';
      case 'reconnect_required':
        return 'Da ricollegare';
      case 'error':
        return 'Errore';
      case 'disconnected':
        return 'Disconnesso';
      default:
        return 'Non configurato';
    }
  }

  String _formatRegistrationStatus(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'registered':
        return 'Registrato';
      case 'verification_required':
        return 'Verifica richiesta';
      case 'pending':
        return 'In attesa';
      case 'error':
        return 'Errore';
      default:
        return 'N/D';
    }
  }

  String _formatConnectionMethod(String? method) {
    switch ((method ?? '').trim().toLowerCase()) {
      case 'manual_setup':
        return 'Configurazione manuale';
      case 'embedded_signup':
        return 'Embedded Signup';
      case 'legacy_oauth':
        return 'Legacy OAuth';
      default:
        return 'Non impostato';
    }
  }

  Future<_ManualWhatsAppSetupInput?> _promptManualSetup(
    BuildContext context, {
    WhatsAppConfig? initialConfig,
    String? initialPin,
  }) async {
    final accessTokenController = TextEditingController();
    final businessIdController = TextEditingController(
      text: initialConfig?.businessId ?? '',
    );
    final wabaIdController = TextEditingController(
      text: initialConfig?.wabaId ?? '',
    );
    final phoneNumberIdController = TextEditingController(
      text: initialConfig?.phoneNumberId ?? '',
    );
    final displayPhoneController = TextEditingController(
      text: initialConfig?.displayPhoneNumber ?? '',
    );
    final pinController = TextEditingController(text: initialPin ?? '');

    var obscureToken = true;
    String? formError;

    final result = await showDialog<_ManualWhatsAppSetupInput>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Configura WhatsApp del salone'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inserisci i riferimenti Meta del numero del salone. Usa preferibilmente un token long-lived o system-user con permessi WhatsApp. Business Manager ID, numero visualizzato e PIN sono opzionali.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: accessTokenController,
                        obscureText: obscureToken,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Access token Meta',
                          hintText: 'EAAG...',
                          suffixIcon: IconButton(
                            onPressed:
                                () => setModalState(() {
                                  obscureToken = !obscureToken;
                                }),
                            icon: Icon(
                              obscureToken
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: wabaIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'WABA ID',
                          hintText: '123456789012345',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneNumberIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number ID',
                          hintText: '123456789012345',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: businessIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Business Manager ID',
                          hintText: 'Opzionale',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: displayPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Numero visualizzato',
                          hintText: '+39 347 123 4567',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'PIN a 6 cifre',
                          hintText:
                              'Opzionale, richiesto solo per registrare il numero',
                        ),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFB84A4A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    final accessToken = accessTokenController.text.trim();
                    final businessId = businessIdController.text.trim();
                    final wabaId = wabaIdController.text.trim();
                    final phoneNumberId = phoneNumberIdController.text.trim();
                    final displayPhone = displayPhoneController.text.trim();
                    final pin = pinController.text.trim();

                    if (accessToken.isEmpty) {
                      setModalState(() {
                        formError =
                            'Inserisci l\'access token Meta del salone.';
                      });
                      return;
                    }
                    if (wabaId.isEmpty) {
                      setModalState(() {
                        formError = 'Inserisci il WABA ID.';
                      });
                      return;
                    }
                    if (phoneNumberId.isEmpty) {
                      setModalState(() {
                        formError = 'Inserisci il Phone Number ID.';
                      });
                      return;
                    }
                    if (pin.isNotEmpty && pin.length != 6) {
                      setModalState(() {
                        formError =
                            'Se inserisci il PIN, deve contenere 6 cifre.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      _ManualWhatsAppSetupInput(
                        accessToken: accessToken,
                        businessId: businessId.isEmpty ? null : businessId,
                        wabaId: wabaId,
                        phoneNumberId: phoneNumberId,
                        displayPhoneNumber:
                            displayPhone.isEmpty ? null : displayPhone,
                        pin: pin.isEmpty ? null : pin,
                      ),
                    );
                  },
                  child: const Text('Salva configurazione'),
                ),
              ],
            );
          },
        );
      },
    );

    accessTokenController.dispose();
    businessIdController.dispose();
    wabaIdController.dispose();
    phoneNumberIdController.dispose();
    displayPhoneController.dispose();
    pinController.dispose();

    return result;
  }

  Future<String?> _promptPin(
    BuildContext context, {
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('PIN WhatsApp'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'PIN a 6 cifre',
              hintText: '123456',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (pin.length != 6) {
                  return;
                }
                Navigator.of(dialogContext).pop(pin);
              },
              child: const Text('Continua'),
            ),
          ],
        );
      },
    );
  }

  Future<WhatsAppVerificationCodeMethod?> _promptCodeMethod(
    BuildContext context,
  ) {
    return showDialog<WhatsAppVerificationCodeMethod>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Invio codice OTP'),
          content: const Text(
            'Scegli come vuoi ricevere il codice di verifica del numero WhatsApp.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            OutlinedButton(
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(WhatsAppVerificationCodeMethod.voice),
              child: const Text('Chiamata'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(WhatsAppVerificationCodeMethod.sms),
              child: const Text('SMS'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptVerificationCode(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Codice di verifica'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(
              labelText: 'Inserisci il codice ricevuto',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Conferma'),
            ),
          ],
        );
      },
    );
  }

  String _errorMessage(Object error) {
    final raw = error.toString();
    return raw.replaceFirst('WhatsAppSendException: ', '');
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.isConfigured,
    required this.connectLabel,
    required this.connectIcon,
    required this.onConnect,
    this.isBusy = false,
    this.onDisconnect,
  });

  final bool isConfigured;
  final String connectLabel;
  final IconData connectIcon;
  final VoidCallback? onConnect;
  final bool isBusy;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        isConfigured ? const Color(0xFF1E8E5A) : const Color(0xFFE09A1A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Integrazione', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      isConfigured
                          ? 'Il salone invia con il proprio numero WhatsApp Business. Controlla template, qualità account ed endpoint operativo.'
                          : 'Configura manualmente token Meta, WABA e numero WhatsApp Business del salone per inviare template con il suo brand.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusChip(
                icon:
                    isConfigured
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                label: isConfigured ? 'Collegato' : 'Da configurare',
                background: accent.withValues(alpha: 0.14),
                foreground: accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onConnect,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                icon:
                    isBusy
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(connectIcon),
                label: Text(connectLabel),
              ),
              if (onDisconnect != null)
                OutlinedButton.icon(
                  onPressed: onDisconnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB84A4A),
                    side: const BorderSide(color: Color(0xFFE0B3B3)),
                  ),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnetti'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsBoardCard extends StatelessWidget {
  const _SettingsBoardCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SettingsDetailGrid extends StatelessWidget {
  const _SettingsDetailGrid({required this.entries});

  final List<_SettingsDetailEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        if (isCompact) {
          return Column(
            children: entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SettingsDetailTile(entry: entry),
                  ),
                )
                .toList(growable: false),
          );
        }

        final rows = <Widget>[];
        for (var index = 0; index < entries.length; index += 2) {
          final leftEntry = entries[index];
          final rightEntry =
              index + 1 < entries.length ? entries[index + 1] : null;
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _SettingsDetailTile(entry: leftEntry)),
                  const SizedBox(width: 10),
                  Expanded(
                    child:
                        rightEntry != null
                            ? _SettingsDetailTile(entry: rightEntry)
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _SettingsDetailTile extends StatelessWidget {
  const _SettingsDetailTile({required this.entry});

  final _SettingsDetailEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(entry.value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _SettingsDetailEntry {
  const _SettingsDetailEntry({required this.label, required this.value});

  final String label;
  final String value;
}

class _ManualWhatsAppSetupInput {
  const _ManualWhatsAppSetupInput({
    required this.accessToken,
    required this.wabaId,
    required this.phoneNumberId,
    this.businessId,
    this.displayPhoneNumber,
    this.pin,
  });

  final String accessToken;
  final String? businessId;
  final String wabaId;
  final String phoneNumberId;
  final String? displayPhoneNumber;
  final String? pin;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(label),
      backgroundColor: background,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: foreground),
      side: BorderSide(color: foreground.withValues(alpha: 0.12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              'Errore nel caricare la configurazione WhatsApp',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
