import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/sale.dart';

class PackagePurchaseEditSheet extends ConsumerStatefulWidget {
  const PackagePurchaseEditSheet({
    super.key,
    required this.initialItem,
    required this.purchaseDate,
    this.package,
    this.usedSessionsByService = const <String, int>{},
  });

  final SaleItem initialItem;
  final DateTime purchaseDate;
  final ServicePackage? package;
  final Map<String, int> usedSessionsByService;

  @override
  ConsumerState<PackagePurchaseEditSheet> createState() =>
      _PackagePurchaseEditSheetState();
}

class _PackagePurchaseEditSheetState
    extends ConsumerState<PackagePurchaseEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late PackagePurchaseStatus _status;
  late TextEditingController _remainingSessionsController;
  int? _initialTotalSessions;
  late Map<String, int> _remainingServiceSessions;

  Set<String> get _serviceIds => _allServiceIds();

  bool get _supportsServiceBreakdown => _serviceIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _status = item.packageStatus ?? _defaultStatus(item);
    _initialTotalSessions = item.totalSessions ?? _defaultTotalSessions(item);
    _remainingServiceSessions = _buildInitialServiceSessions(item);
    final hasBreakdown = _allServiceIds(_remainingServiceSessions).isNotEmpty;
    final initialRemaining =
        hasBreakdown
            ? _remainingServiceSessions.values.fold<int>(
              0,
              (sum, value) => sum + value,
            )
            : item.remainingSessions ?? _initialTotalSessions;
    _remainingSessionsController = TextEditingController(
      text: initialRemaining?.toString() ?? '',
    );
    if (hasBreakdown) {
      _syncRemainingSessionsField();
    }
  }

  @override
  void dispose() {
    _remainingSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final data = ref.watch(appDataProvider);
    final serviceNames = {
      for (final service in data.services) service.id: service.name,
    };
    final serviceIds = _serviceIds.toList()
      ..sort(
        (a, b) => (serviceNames[a] ?? a).compareTo(serviceNames[b] ?? b),
      );
    final supportsBreakdown = serviceIds.isNotEmpty;
    final totalSessions = _initialTotalSessions;
    final outstandingAmount = _outstandingAmount();
    final remainingValue = int.tryParse(
      _remainingSessionsController.text.trim(),
    );
    final canDecrement = !supportsBreakdown && (remainingValue ?? 0) > 0;
    final canIncrement =
        !supportsBreakdown &&
        (totalSessions == null ||
            remainingValue == null ||
            remainingValue < totalSessions);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modifica pacchetto', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<PackagePurchaseStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Stato'),
              items:
                  PackagePurchaseStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() {
                    _status = value ?? _status;
                  }),
            ),
            const SizedBox(height: 12),
            Text(
              'Acconti registrati: ${currency.format(widget.initialItem.depositAmount)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (outstandingAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Rimanenza da saldare: ${currency.format(outstandingAmount)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              totalSessions == null
                  ? 'Sessioni totali registrate: non definite'
                  : 'Sessioni totali registrate: $totalSessions',
              style: theme.textTheme.bodyMedium,
            ),
            if (supportsBreakdown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sessioni rimanenti totali: ${_totalFromServices()}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _remainingSessionsController,
                    readOnly: supportsBreakdown,
                    enabled: !supportsBreakdown,
                    decoration: InputDecoration(
                      labelText: supportsBreakdown
                          ? 'Sessioni rimanenti (totale)'
                          : 'Sessioni rimanenti',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged:
                        supportsBreakdown
                            ? null
                            : (_) => setState(() {}),
                    validator: (value) {
                      if (supportsBreakdown) {
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return null;
                      }
                      final remaining = int.tryParse(value.trim());
                      if (remaining == null || remaining < 0) {
                        return 'Inserisci un numero valido';
                      }
                      final total = totalSessions;
                      if (total != null && remaining > total) {
                        return 'Maggiore delle sessioni totali';
                      }
                      return null;
                    },
                  ),
                ),
                if (!supportsBreakdown) ...[
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Aggiungi sessione rimanente',
                        onPressed:
                            canIncrement ? _incrementRemainingSessions : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                      IconButton(
                        tooltip: 'Rimuovi sessione rimanente',
                        onPressed:
                            canDecrement ? _decrementRemainingSessions : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                supportsBreakdown
                    ? 'La somma delle righe sottostanti determina il totale delle sessioni rimanenti.'
                    : 'Usa i pulsanti per aumentare o ridurre le sessioni rimanenti.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (supportsBreakdown) ...[
              const SizedBox(height: 12),
              Text(
                'Sessioni per servizio',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...serviceIds.map(
                (serviceId) => _buildServiceSessionRow(
                  context,
                  serviceId,
                  serviceNames[serviceId],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _incrementRemainingSessions() {
    _updateRemainingSessions(1);
  }

  void _decrementRemainingSessions() {
    _updateRemainingSessions(-1);
  }

  void _updateRemainingSessions(int delta) {
    final raw = _remainingSessionsController.text.trim();
    final current = raw.isEmpty ? 0 : int.tryParse(raw) ?? 0;
    var next = current + delta;
    if (next < 0) {
      next = 0;
    }
    final max = _initialTotalSessions;
    if (max != null && next > max) {
      next = max;
    }
    final nextText = next.toString();
    setState(() {
      _remainingSessionsController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    });
  }

  Widget _buildServiceSessionRow(
    BuildContext context,
    String serviceId,
    String? serviceName,
  ) {
    final theme = Theme.of(context);
    final value = _remainingServiceSessions[serviceId] ?? 0;
    final label = serviceName ?? 'Servizio non disponibile';
    final subtitle =
        serviceName == null ? 'Servizio rimosso dal catalogo' : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Rimuovi sessione da $label',
            onPressed:
                value > 0 ? () => _decrementServiceSessions(serviceId) : null,
            icon: const Icon(Icons.remove_rounded),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 48,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Aggiungi sessione a $label',
            onPressed: () => _incrementServiceSessions(serviceId),
            icon: const Icon(Icons.add_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _incrementServiceSessions(String serviceId) {
    final current = _remainingServiceSessions[serviceId] ?? 0;
    _setServiceSessions(serviceId, current + 1);
  }

  void _decrementServiceSessions(String serviceId) {
    final current = _remainingServiceSessions[serviceId] ?? 0;
    if (current <= 0) {
      return;
    }
    _setServiceSessions(serviceId, current - 1);
  }

  void _setServiceSessions(String serviceId, int value) {
    setState(() {
      final next = value < 0 ? 0 : value;
      final updated = Map<String, int>.from(_remainingServiceSessions);
      updated[serviceId] = next;
      _remainingServiceSessions = updated;
      _syncRemainingSessionsField();
    });
  }

  void _syncRemainingSessionsField() {
    final total = _totalFromServices();
    final text = total.toString();
    _remainingSessionsController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Map<String, int> _buildInitialServiceSessions(SaleItem item) {
    final manual = item.remainingPackageServiceSessions;
    if (manual.isNotEmpty) {
      return Map<String, int>.fromEntries(
        manual.entries.map(
          (entry) => MapEntry(entry.key, entry.value < 0 ? 0 : entry.value),
        ),
      );
    }
    final perPackageSessions =
        item.packageServiceSessions.isNotEmpty
            ? item.packageServiceSessions
            : widget.package?.serviceSessionCounts ?? const <String, int>{};
    if (perPackageSessions.isEmpty) {
      return <String, int>{};
    }
    final quantity = item.quantity;
    final aggregated = <String, int>{};
    perPackageSessions.forEach((id, count) {
      final total = (count * quantity).round();
      aggregated[id] = total;
    });
    final adjusted = <String, int>{};
    final allIds = {
      ...aggregated.keys,
      ...widget.usedSessionsByService.keys,
    };
    for (final id in allIds) {
      final total = aggregated[id] ?? 0;
      final used = widget.usedSessionsByService[id] ?? 0;
      final remaining = total - used;
      adjusted[id] = remaining < 0 ? 0 : remaining;
    }
    for (final id in widget.package?.serviceIds ?? const <String>[]) {
      adjusted.putIfAbsent(id, () => 0);
    }
    final targetTotal =
        item.remainingSessions ??
        adjusted.values.fold<int>(0, (sum, value) => sum + value);
    return _scaleServiceMap(adjusted, targetTotal);
  }

  Map<String, int> _scaleServiceMap(Map<String, int> base, int? target) {
    final sanitized = <String, int>{
      for (final entry in base.entries) entry.key: entry.value < 0 ? 0 : entry.value,
    };
    if (target == null) {
      return sanitized;
    }
    var desired = target;
    if (desired < 0) {
      desired = 0;
    }
    final keys = sanitized.keys.toList();
    if (keys.isEmpty) {
      return <String, int>{};
    }
    final sumBase = sanitized.values.fold<int>(0, (sum, value) => sum + value);
    if (sumBase == desired) {
      return sanitized;
    }
    if (sumBase == 0) {
      final equalShare = desired ~/ keys.length;
      final remainder = desired - equalShare * keys.length;
      final result = <String, int>{};
      for (var i = 0; i < keys.length; i++) {
        result[keys[i]] = equalShare + (i < remainder ? 1 : 0);
      }
      return result;
    }
    final allocations = sanitized.entries
        .map(
          (entry) {
            final raw = entry.value * desired / sumBase;
            final floor = raw.floor();
            return _FractionalShare(
              key: entry.key,
              value: floor,
              fraction: raw - floor,
            );
          },
        )
        .toList();
    final floorSum = allocations.fold<int>(0, (sum, item) => sum + item.value);
    var remainder = desired - floorSum;
    allocations.sort(
      (a, b) => b.fraction.compareTo(a.fraction),
    );
    var index = 0;
    while (remainder > 0 && allocations.isNotEmpty) {
      allocations[index] = allocations[index].increment();
      remainder--;
      index = (index + 1) % allocations.length;
    }
    final result = <String, int>{};
    for (final allocation in allocations) {
      result[allocation.key] = allocation.value;
    }
    return result;
  }

  int _totalFromServices() {
    return _remainingServiceSessions.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
  }

  Set<String> _allServiceIds([Map<String, int>? override]) {
    final source = override ?? _remainingServiceSessions;
    return {
      ...source.keys,
      ...widget.initialItem.packageServiceSessions.keys,
      ...?widget.package?.serviceSessionCounts.keys,
      ...?widget.package?.serviceIds,
      ...widget.usedSessionsByService.keys,
    }..removeWhere((id) => id.isEmpty);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Map<String, int> remainingPerService = const <String, int>{};
    int? remainingSessions;

    if (_supportsServiceBreakdown) {
      remainingPerService = _normalizeServiceSessions();
      remainingSessions = remainingPerService.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
    } else {
      final remainingText = _remainingSessionsController.text.trim();
      remainingSessions =
          remainingText.isEmpty ? null : int.parse(remainingText);
      if (_initialTotalSessions != null &&
          remainingSessions != null &&
          remainingSessions > _initialTotalSessions!) {
        remainingSessions = _initialTotalSessions;
      }
    }

    final updatedItem = widget.initialItem.copyWith(
      packageStatus: _status,
      remainingSessions: remainingSessions,
      remainingPackageServiceSessions: remainingPerService,
    );

    Navigator.of(context).pop(updatedItem);
  }

  Map<String, int> _normalizeServiceSessions() {
    final normalized = <String, int>{
      for (final entry in _remainingServiceSessions.entries)
        entry.key: entry.value < 0 ? 0 : entry.value,
    };
    for (final id in _serviceIds) {
      normalized.putIfAbsent(id, () => 0);
    }
    return normalized;
  }

  int? _defaultTotalSessions(SaleItem item) {
    final sessionsPerPackage =
        widget.package?.totalConfiguredSessions ??
        (item.packageServiceSessions.isNotEmpty
            ? item.packageServiceSessions.values.fold<int>(
              0,
              (sum, value) => sum + value,
            )
            : null);
    if (sessionsPerPackage == null) {
      return null;
    }
    return (sessionsPerPackage * item.quantity).round();
  }

  PackagePurchaseStatus _defaultStatus(SaleItem item) {
    final remaining = item.remainingSessions ?? _defaultTotalSessions(item);
    if (remaining != null && remaining <= 0) {
      return PackagePurchaseStatus.completed;
    }
    return PackagePurchaseStatus.active;
  }

  double _totalAmount() => widget.initialItem.amount;

  double _outstandingAmount() {
    final outstanding = _totalAmount() - widget.initialItem.depositAmount;
    return math.max(double.parse(outstanding.toStringAsFixed(2)), 0);
  }
}

class _FractionalShare {
  const _FractionalShare({
    required this.key,
    required this.value,
    required this.fraction,
  });

  final String key;
  final int value;
  final double fraction;

  _FractionalShare increment() {
    return _FractionalShare(
      key: key,
      value: value + 1,
      fraction: fraction,
    );
  }
}
