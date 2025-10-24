import 'package:you_book/domain/entities/loyalty_settings.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';

class SalonLoyaltySheet extends StatefulWidget {
  const SalonLoyaltySheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonLoyaltySheet> createState() => _SalonLoyaltySheetState();
}

class _SalonLoyaltySheetState extends State<SalonLoyaltySheet> {
  late bool _enabled;
  late TextEditingController _euroPerPoint;
  late TextEditingController _pointValueEuro;
  late TextEditingController _maxPercent;
  late TextEditingController _initialBalance;
  late TextEditingController _resetMonth;
  late TextEditingController _resetDay;
  late TextEditingController _timezone;
  late LoyaltyRoundingMode _roundingMode;
  late bool _autoSuggest;

  @override
  void initState() {
    super.initState();
    final loyalty = widget.salon.loyaltySettings;
    _enabled = loyalty.enabled;
    _euroPerPoint = TextEditingController(
      text: loyalty.earning.euroPerPoint.toStringAsFixed(0),
    );
    _pointValueEuro = TextEditingController(
      text: loyalty.redemption.pointValueEuro.toStringAsFixed(2),
    );
    _maxPercent = TextEditingController(
      text: (loyalty.redemption.maxPercent * 100).toStringAsFixed(0),
    );
    _initialBalance = TextEditingController(
      text: loyalty.initialBalance.toString(),
    );
    _resetMonth = TextEditingController(
      text: loyalty.expiration.resetMonth.toString(),
    );
    _resetDay = TextEditingController(
      text: loyalty.expiration.resetDay.toString(),
    );
    _timezone = TextEditingController(text: loyalty.expiration.timezone);
    _roundingMode = loyalty.earning.rounding;
    _autoSuggest = loyalty.redemption.autoSuggest;
  }

  @override
  void dispose() {
    _euroPerPoint.dispose();
    _pointValueEuro.dispose();
    _maxPercent.dispose();
    _initialBalance.dispose();
    _resetMonth.dispose();
    _resetDay.dispose();
    _timezone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_enabled) {
      Navigator.of(context).pop(
        widget.salon.copyWith(
          loyaltySettings: const LoyaltySettings(enabled: false),
        ),
      );
      return;
    }

    double? euroPerPoint = double.tryParse(
      _euroPerPoint.text.replaceAll(',', '.'),
    );
    if (euroPerPoint == null || euroPerPoint < 1) {
      _showError('Inserisci un valore valido per € per punto (>=1).');
      return;
    }

    double? pointValue = double.tryParse(
      _pointValueEuro.text.replaceAll(',', '.'),
    );
    if (pointValue == null || pointValue <= 0) {
      _showError('Inserisci un valore valido per il valore del punto.');
      return;
    }

    double? maxPercent = double.tryParse(_maxPercent.text.replaceAll(',', '.'));
    if (maxPercent == null || maxPercent <= 0 || maxPercent > 50) {
      _showError('Lo sconto massimo deve essere tra 1% e 50%.');
      return;
    }
    maxPercent /= 100;

    final initialBalance = int.tryParse(_initialBalance.text.trim()) ?? 0;
    if (initialBalance < 0) {
      _showError('Il saldo iniziale deve essere maggiore o uguale a zero.');
      return;
    }

    final resetMonth = int.tryParse(_resetMonth.text.trim()) ?? 1;
    if (resetMonth < 1 || resetMonth > 12) {
      _showError('Il mese di reset deve essere compreso tra 1 e 12.');
      return;
    }

    final resetDay = int.tryParse(_resetDay.text.trim()) ?? 1;
    if (resetDay < 1 || resetDay > 31) {
      _showError('Il giorno di reset deve essere compreso tra 1 e 31.');
      return;
    }

    final timezone =
        _timezone.text.trim().isEmpty ? 'Europe/Rome' : _timezone.text.trim();

    final settings = LoyaltySettings(
      enabled: true,
      earning: LoyaltyEarningRules(
        euroPerPoint: euroPerPoint,
        rounding: _roundingMode,
      ),
      redemption: LoyaltyRedemptionRules(
        pointValueEuro: pointValue,
        maxPercent: maxPercent,
        autoSuggest: _autoSuggest,
      ),
      initialBalance: initialBalance,
      expiration: LoyaltyExpirationRules(
        resetMonth: resetMonth,
        resetDay: resetDay,
        timezone: timezone,
      ),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(widget.salon.copyWith(loyaltySettings: settings));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DialogActionLayout(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Programma fedeltà',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Switch.adaptive(
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Attiva il programma punti e definisci le regole di earning e redemption.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: !_enabled,
            child: AnimatedOpacity(
              opacity: _enabled ? 1 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _euroPerPoint,
                          decoration: const InputDecoration(
                            labelText: '€ per punto',
                            helperText: 'Es. 10 = 1 punto ogni 10 €',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<LoyaltyRoundingMode>(
                          value: _roundingMode,
                          decoration: const InputDecoration(
                            labelText: 'Arrotondamento',
                          ),
                          items:
                              LoyaltyRoundingMode.values
                                  .map(
                                    (mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(_roundingLabel(mode)),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _roundingMode = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pointValueEuro,
                          decoration: const InputDecoration(
                            labelText: 'Valore punto (€)',
                            helperText: 'Es. 1 = 1€ di sconto per 1 punto',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxPercent,
                          decoration: const InputDecoration(
                            labelText: 'Max sconto (%)',
                            helperText: 'Percentuale massima per transazione',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Suggerisci automaticamente i punti da usare',
                    ),
                    value: _autoSuggest,
                    onChanged: (value) => setState(() => _autoSuggest = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _initialBalance,
                          decoration: const InputDecoration(
                            labelText: 'Saldo iniziale punti',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _resetMonth,
                          decoration: const InputDecoration(
                            labelText: 'Mese reset (1-12)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _resetDay,
                          decoration: const InputDecoration(
                            labelText: 'Giorno reset (1-31)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timezone,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      helperText: 'Es. Europe/Rome',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }

  String _roundingLabel(LoyaltyRoundingMode mode) {
    switch (mode) {
      case LoyaltyRoundingMode.floor:
        return 'Per difetto';
      case LoyaltyRoundingMode.round:
        return 'Matematico';
      case LoyaltyRoundingMode.ceil:
        return 'Per eccesso';
    }
  }
}
