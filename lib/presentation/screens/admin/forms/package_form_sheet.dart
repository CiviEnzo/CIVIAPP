import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:flutter/material.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PackageFormSheet extends StatefulWidget {
  const PackageFormSheet({
    super.key,
    required this.salons,
    required this.services,
    this.initial,
    this.defaultSalonId,
    this.defaultShowOnClientDashboard,
  });

  final List<Salon> salons;
  final List<Service> services;
  final ServicePackage? initial;
  final String? defaultSalonId;
  final bool? defaultShowOnClientDashboard;

  @override
  State<PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _price;
  late TextEditingController _discountPercentage;
  late TextEditingController _sessionCount;
  late TextEditingController _validDays;
  late TextEditingController _serviceSearch;
  String? _salonId;
  final Set<String> _selectedServices = {};
  final Map<String, TextEditingController> _serviceControllers = {};
  final Map<String, int> _serviceSessions = {};
  bool _isUpdatingSessionCount = false;
  bool _sessionCountEdited = false;
  double _fullPrice = 0;
  bool _finalPriceEdited = false;
  bool _isUpdatingFinalPrice = false;
  bool _isUpdatingDiscount = false;
  late bool _showOnClientDashboard;
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency(
    locale: 'it_IT',
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _price = TextEditingController(
      text: initial != null ? initial.price.toStringAsFixed(2) : '',
    );
    _discountPercentage = TextEditingController(
      text:
          initial?.discountPercentage != null
              ? initial!.discountPercentage!.toStringAsFixed(2)
              : '',
    );
    final initialSessions =
        initial?.totalConfiguredSessions ?? initial?.sessionCount;
    _sessionCount = TextEditingController(
      text: initialSessions?.toString() ?? '',
    );
    _validDays = TextEditingController(
      text: initial?.validDays?.toString() ?? '',
    );
    _fullPrice = initial?.fullPrice ?? initial?.price ?? 0;
    _finalPriceEdited = initial != null && initial.discountPercentage == null;
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _showOnClientDashboard =
        initial?.showOnClientDashboard ??
        widget.defaultShowOnClientDashboard ??
        true;
    _selectedServices.addAll(initial?.serviceIds ?? []);
    if (initial?.serviceSessionCounts.isNotEmpty ?? false) {
      _serviceSessions.addAll(initial!.serviceSessionCounts);
      _selectedServices.addAll(initial.serviceSessionCounts.keys);
    }
    _sessionCount.addListener(_handleSessionCountChanged);
    _price.addListener(_handlePriceChanged);
    _discountPercentage.addListener(_handleDiscountChanged);
    _serviceSearch = TextEditingController()
      ..addListener(() {
        if (!mounted) return;
        setState(() {});
      });
    _syncSalonDependencies();
    _recalculateFullPrice(notify: false);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.removeListener(_handlePriceChanged);
    _price.dispose();
    _discountPercentage.removeListener(_handleDiscountChanged);
    _discountPercentage.dispose();
    _sessionCount.removeListener(_handleSessionCountChanged);
    _sessionCount.dispose();
    _validDays.dispose();
    _serviceSearch.dispose();
    for (final controller in _serviceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salonServices =
        widget.services.where((service) => service.salonId == _salonId).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final totalSessions = _currentSessionTotal();
    final discountValue = _currentDiscount();
    final finalPriceValue = _currentFinalPrice();
    final savings = _fullPrice > 0 ? _fullPrice - finalPriceValue : 0;

    return DialogActionLayout(
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuovo pacchetto' : 'Modifica pacchetto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome del pacchetto'
                          : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Prezzo pieno: ${_currencyFormat.format(_fullPrice)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (discountValue != null && discountValue > 0 && savings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Risparmio: ${_currencyFormat.format(savings)} (sconto ${discountValue.toStringAsFixed(2)}%)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _discountPercentage,
              decoration: const InputDecoration(labelText: 'Sconto (%)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Prezzo finale (€)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _validDays,
              decoration: const InputDecoration(labelText: 'Validità (giorni)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _showOnClientDashboard,
              onChanged: (value) {
                setState(() {
                  _showOnClientDashboard = value;
                });
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostra nel dashboard cliente'),
              subtitle: const Text(
                'Quando disattivato il pacchetto resta disponibile solo per preventivi e vendite interne.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              totalSessions > 0
                  ? 'Servizi inclusi ($totalSessions sessioni)'
                  : 'Servizi inclusi',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._buildServiceInputs(context, salonServices),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }

  void _syncSalonDependencies() {
    final salonId = _salonId;
    final allowedIds =
        salonId == null
            ? <String>{}
            : widget.services
                .where((service) => service.salonId == salonId)
                .map((service) => service.id)
                .toSet();
    _selectedServices.removeWhere((id) => !allowedIds.contains(id));
    _serviceSessions.removeWhere((id, _) => !allowedIds.contains(id));
    for (final entry in _serviceControllers.entries) {
      if (!allowedIds.contains(entry.key)) {
        entry.value.clear();
      }
    }
    _recalculateSessionCountFromServices();
  }

  List<Widget> _buildServiceInputs(
    BuildContext context,
    List<Service> services,
  ) {
    final theme = Theme.of(context);
    if (_salonId == null) {
      return [
        Text(
          'Nessun salone associato. Impossibile mostrare i servizi disponibili.',
          style: theme.textTheme.bodyMedium,
        ),
      ];
    }
    if (services.isEmpty) {
      return [
        Text(
          'Nessun servizio associato al salone selezionato.',
          style: theme.textTheme.bodyMedium,
        ),
      ];
    }

    final query = _serviceSearch.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? services
        : services.where((service) {
            final name = service.name.toLowerCase();
            final desc = (service.description ?? '').toLowerCase();
            final cat = (service.category).toLowerCase();
            return name.contains(query) || desc.contains(query) || cat.contains(query);
          }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final Map<String, List<Service>> byCategory = {};
    for (final service in filtered) {
      final label = service.category.trim().isEmpty ? 'Altro' : service.category.trim();
      byCategory.putIfAbsent(label, () => <Service>[]).add(service);
    }
    final sortedCategoryLabels = byCategory.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final widgets = <Widget>[];
    widgets.add(
      TextField(
        controller: _serviceSearch,
        decoration: InputDecoration(
          hintText: 'Cerca servizi...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _serviceSearch.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Pulisci',
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _serviceSearch.clear();
                  },
                ),
        ),
        textInputAction: TextInputAction.search,
      ),
    );
    widgets.add(const SizedBox(height: 8));

    if (sortedCategoryLabels.isEmpty) {
      widgets.add(
        Text(
          'Nessun servizio corrisponde alla ricerca.',
          style: theme.textTheme.bodyMedium,
        ),
      );
      return widgets;
    }

    for (final label in sortedCategoryLabels) {
      final items = byCategory[label]!;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          '$label (${items.length})',
          style: theme.textTheme.titleSmall,
        ),
      ));
      for (final service in items) {
        final selected = _selectedServices.contains(service.id);
        final controller = _controllerForService(service.id);
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (value) => _toggleService(service, value ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (service.description != null && service.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            service.description!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: controller,
                    enabled: selected,
                    decoration: const InputDecoration(
                      labelText: 'Sessioni',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (!selected) {
                        return null;
                      }
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Obbligatorio';
                      }
                      final numeric = int.tryParse(trimmed);
                      if (numeric == null || numeric <= 0) {
                        return 'Valore non valido';
                      }
                      return null;
                    },
                    onChanged: (value) => _onServiceSessionsChanged(service.id, value),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  TextEditingController _controllerForService(String serviceId) {
    return _serviceControllers.putIfAbsent(
      serviceId,
      () => TextEditingController(
        text: _serviceSessions[serviceId]?.toString() ?? '',
      ),
    );
  }

  void _toggleService(Service service, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedServices.add(service.id);
        final current = _serviceSessions[service.id];
        final controller = _controllerForService(service.id);
        if (current != null && current > 0) {
          controller.text = current.toString();
        } else {
          controller.text = '1';
          _serviceSessions[service.id] = 1;
        }
      } else {
        _selectedServices.remove(service.id);
        _serviceSessions.remove(service.id);
        _serviceControllers[service.id]?.clear();
      }
    });
    _recalculateSessionCountFromServices();
    _recalculateFullPrice();
  }

  void _onServiceSessionsChanged(String serviceId, String value) {
    if (!_selectedServices.contains(serviceId)) {
      return;
    }
    final numeric = int.tryParse(value.trim());
    setState(() {
      if (numeric == null || numeric <= 0) {
        _serviceSessions.remove(serviceId);
      } else {
        _serviceSessions[serviceId] = numeric;
      }
    });
    _recalculateSessionCountFromServices();
    _recalculateFullPrice();
  }

  void _handleSessionCountChanged() {
    if (_isUpdatingSessionCount) {
      return;
    }
    _sessionCountEdited = _sessionCount.text.trim().isNotEmpty;
  }

  void _handlePriceChanged() {
    if (_isUpdatingFinalPrice) {
      return;
    }
    _finalPriceEdited = true;
    _updateDiscountFromFinalPrice();
    setState(() {});
  }

  void _handleDiscountChanged() {
    if (_isUpdatingDiscount) {
      return;
    }
    final discount = _parseDouble(_discountPercentage.text);
    if (discount == null || discount < 0) {
      _finalPriceEdited = false;
      _isUpdatingDiscount = true;
      if (_discountPercentage.text.isNotEmpty) {
        _discountPercentage.clear();
      }
      _isUpdatingDiscount = false;
      _applyDiscountToPrice();
      setState(() {});
      return;
    }

    final normalized = discount.clamp(0, 100).toDouble();
    if ((normalized - discount).abs() > 0.001) {
      _isUpdatingDiscount = true;
      _discountPercentage.text = normalized.toStringAsFixed(2);
      _discountPercentage.selection = TextSelection.fromPosition(
        TextPosition(offset: _discountPercentage.text.length),
      );
      _isUpdatingDiscount = false;
    }

    _finalPriceEdited = false;
    _applyDiscountToPrice();
    setState(() {});
  }

  void _recalculateSessionCountFromServices() {
    if (_sessionCountEdited) {
      return;
    }
    if (_serviceSessions.isEmpty && _selectedServices.isNotEmpty) {
      return;
    }
    final total = _serviceSessions.entries
        .where((entry) => _selectedServices.contains(entry.key))
        .fold<int>(0, (sum, entry) => sum + entry.value);
    _isUpdatingSessionCount = true;
    if (total > 0) {
      _sessionCount.text = total.toString();
    } else if (_serviceSessions.isEmpty) {
      _sessionCount.clear();
    }
    _isUpdatingSessionCount = false;
  }

  void _recalculateFullPrice({bool notify = true}) {
    if (_serviceSessions.isEmpty && _selectedServices.isNotEmpty) {
      if (!notify) {
        _syncPricingWithFullPrice();
      } else {
        setState(_syncPricingWithFullPrice);
      }
      return;
    }
    final total = _calculateFullPriceValue();
    if (!notify) {
      _fullPrice = total;
      _syncPricingWithFullPrice();
      return;
    }
    setState(() {
      _fullPrice = total;
      _syncPricingWithFullPrice();
    });
  }

  void _syncPricingWithFullPrice() {
    if (_finalPriceEdited) {
      _updateDiscountFromFinalPrice();
    } else {
      _applyDiscountToPrice();
    }
  }

  double _calculateFullPriceValue() {
    var total = 0.0;
    for (final serviceId in _selectedServices) {
      final sessions = _serviceSessions[serviceId] ?? 1;
      if (sessions <= 0) {
        continue;
      }
      final service = _findServiceById(serviceId);
      if (service == null) {
        continue;
      }
      total += service.price * sessions;
    }
    return total;
  }

  void _applyDiscountToPrice() {
    final discount = _parseDouble(_discountPercentage.text);
    double? finalPrice;

    if (_fullPrice <= 0) {
      if (discount == null || discount <= 0) {
        finalPrice = null;
      } else {
        finalPrice = 0;
      }
    } else if (discount == null || discount <= 0) {
      finalPrice = _fullPrice;
    } else {
      final normalized = discount.clamp(0, 100).toDouble();
      finalPrice = _fullPrice * (1 - normalized / 100);
      if (finalPrice < 0) {
        finalPrice = 0;
      }
    }

    _isUpdatingFinalPrice = true;
    if (finalPrice == null) {
      _price.clear();
    } else {
      _price.text = finalPrice.toStringAsFixed(2);
    }
    _price.selection = TextSelection.fromPosition(
      TextPosition(offset: _price.text.length),
    );
    _isUpdatingFinalPrice = false;
  }

  void _updateDiscountFromFinalPrice() {
    final finalPrice = _parseDouble(_price.text);
    double? discount;

    if (_fullPrice <= 0 || finalPrice == null || finalPrice <= 0) {
      discount = null;
    } else if (finalPrice >= _fullPrice) {
      discount = null;
    } else {
      discount = ((_fullPrice - finalPrice) / _fullPrice) * 100;
    }

    _isUpdatingDiscount = true;
    if (discount == null || discount <= 0) {
      _discountPercentage.clear();
    } else {
      _discountPercentage.text = discount.toStringAsFixed(2);
    }
    _discountPercentage.selection = TextSelection.fromPosition(
      TextPosition(offset: _discountPercentage.text.length),
    );
    _isUpdatingDiscount = false;
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  double _currentFinalPrice() {
    return _parseDouble(_price.text) ?? 0;
  }

  double? _currentDiscount() {
    final discount = _parseDouble(_discountPercentage.text);
    if (discount == null) {
      return null;
    }
    if (discount <= 0) {
      return null;
    }
    return discount.clamp(0, 100).toDouble();
  }

  int _currentSessionTotal() {
    final manual = int.tryParse(_sessionCount.text.trim());
    if (manual != null && manual > 0) {
      return manual;
    }
    return _serviceSessions.entries
        .where((entry) => _selectedServices.contains(entry.key))
        .fold<int>(0, (sum, entry) => sum + entry.value);
  }

  Service? _findServiceById(String serviceId) {
    for (final service in widget.services) {
      if (service.id == serviceId) {
        return service;
      }
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un salone')));
      return;
    }

    final selectedServiceIds = _selectedServices.toList();
    final serviceSessions = <String, int>{};
    for (final serviceId in selectedServiceIds) {
      final text = _serviceControllers[serviceId]?.text.trim() ?? '';
      final sessions = int.tryParse(text);
      if (sessions != null && sessions > 0) {
        serviceSessions[serviceId] = sessions;
      }
    }

    final totalFromServices =
        serviceSessions.isEmpty
            ? null
            : serviceSessions.values.fold<int>(0, (sum, value) => sum + value);
    final manualSessionsText = _sessionCount.text.trim();
    final parsedSessionCount =
        manualSessionsText.isEmpty ? null : int.tryParse(manualSessionsText);
    final resolvedFinalPrice = _parseDouble(_price.text) ?? 0;
    final resolvedDiscount = _parseDouble(_discountPercentage.text);
    final discountPercentage =
        (resolvedDiscount == null || resolvedDiscount <= 0 || _fullPrice <= 0)
            ? null
            : resolvedDiscount.clamp(0, 100).toDouble();

    final pkg = ServicePackage(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      price: resolvedFinalPrice,
      fullPrice: _fullPrice,
      discountPercentage: discountPercentage,
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      serviceIds: selectedServiceIds,
      sessionCount: totalFromServices ?? parsedSessionCount,
      validDays:
          _validDays.text.trim().isEmpty
              ? null
              : int.tryParse(_validDays.text.trim()),
      serviceSessionCounts: serviceSessions,
      showOnClientDashboard: _showOnClientDashboard,
      isGeneratedFromServiceBuilder:
          widget.initial?.isGeneratedFromServiceBuilder ?? false,
    );

    Navigator.of(context).pop(pkg);
  }
}
