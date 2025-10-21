import 'package:civiapp/domain/entities/loyalty_settings.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/salon_setup_progress.dart';
import 'package:flutter/material.dart';

class SalonCreateEssentialDialog extends StatefulWidget {
  const SalonCreateEssentialDialog({super.key});

  @override
  State<SalonCreateEssentialDialog> createState() =>
      _SalonCreateEssentialDialogState();
}

class _SalonCreateEssentialDialogState
    extends State<SalonCreateEssentialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _generateSalonId(String name) {
    var base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (base.isEmpty) {
      base = 'salon';
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${base}_$timestamp';
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final id = _generateSalonId(name);
    final initialChecklist = Map<String, SetupChecklistStatus>.unmodifiable({
      for (final key in SetupChecklistKeys.defaults)
        key: SetupChecklistStatus.notStarted,
    });

    final Salon salon = Salon(
      id: id,
      name: name,
      address: '',
      city: '',
      phone: phone,
      email: email,
      postalCode: null,
      bookingLink: null,
      googlePlaceId: null,
      latitude: null,
      longitude: null,
      socialLinks: const <String, String>{},
      rooms: const <SalonRoom>[],
      equipment: const <SalonEquipment>[],
      closures: const <SalonClosure>[],
      description: null,
      schedule: const <SalonDailySchedule>[],
      status: SalonStatus.active,
      loyaltySettings: const LoyaltySettings(),
      dashboardSections: const SalonDashboardSections(),
      clientRegistration: const ClientRegistrationSettings(),
      setupChecklist: initialChecklist,
    );

    Navigator.of(context).pop(salon);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crea salone', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    'Inserisci i dati essenziali. Potrai completare le altre informazioni in seguito.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome salone *',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il nome del salone';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email principale *',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'Inserisci un indirizzo email';
                      }
                      final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!regex.hasMatch(email)) {
                        return 'Inserisci un indirizzo email valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Numero di telefono *',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      if (phone.isEmpty) {
                        return 'Inserisci un numero di telefono';
                      }
                      if (phone.length < 5) {
                        return 'Numero troppo corto';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Annulla'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Crea e continua'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
