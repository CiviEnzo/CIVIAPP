import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/repositories/app_data_store.dart';
import 'package:civiapp/domain/entities/last_minute_slot.dart';
import 'package:civiapp/domain/entities/promotion.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class MarketingModule extends ConsumerStatefulWidget {
  const MarketingModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<MarketingModule> createState() => _MarketingModuleState();
}

class _MarketingModuleState extends ConsumerState<MarketingModule> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salonId = widget.salonId;
    if (salonId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Seleziona un salone dal menu in alto per gestire promozioni e slot last-minute.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == salonId,
    );
    final featureFlags = salon?.featureFlags ?? const SalonFeatureFlags();
    final promotions =
        data.promotions
            .where((promotion) => promotion.salonId == salonId)
            .toList()
          ..sort((a, b) {
            final aEnds = a.endsAt ?? DateTime.utc(2100);
            final bEnds = b.endsAt ?? DateTime.utc(2100);
            return aEnds.compareTo(bEnds);
          });
    final lastMinuteSlots =
        data.lastMinuteSlots.where((slot) => slot.salonId == salonId).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final salonServices = data.services
        .where((service) => service.salonId == salonId && service.isActive)
        .sortedBy((service) => service.name.toLowerCase());
    final salonStaff = data.staff
        .where((member) => member.salonId == salonId && member.isActive)
        .sortedBy((member) => member.fullName.toLowerCase());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visibilità dashboard cliente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Promozioni visibili ai clienti'),
                    subtitle: const Text(
                      "Mostra le promo attive nella schermata principale dell'app cliente.",
                    ),
                    value: featureFlags.clientPromotions,
                    onChanged: salon == null
                        ? null
                        : (value) {
                            final AppDataStore store =
                                ref.read(appDataProvider.notifier);
                            store.updateSalonFeatureFlags(
                              salonId,
                              featureFlags.copyWith(clientPromotions: value),
                            );
                          },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Slot last-minute visibili ai clienti'),
                    subtitle: const Text(
                      'Permette ai clienti di vedere e prenotare le offerte last-minute.',
                    ),
                    value: featureFlags.clientLastMinute,
                    onChanged: salon == null
                        ? null
                        : (value) {
                            final AppDataStore store =
                                ref.read(appDataProvider.notifier);
                            store.updateSalonFeatureFlags(
                              salonId,
                              featureFlags.copyWith(clientLastMinute: value),
                            );
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _PromotionsSection(
            promotions: promotions,
            salonId: salonId,
            onCreate: () => _openPromotionForm(context, salonId: salonId),
            onEdit:
                (promotion) => _openPromotionForm(
                  context,
                  salonId: salonId,
                  existing: promotion,
                ),
            onToggleActive: (promotion, isActive) async {
              await ref
                  .read(appDataProvider.notifier)
                  .upsertPromotion(promotion.copyWith(isActive: isActive));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isActive
                        ? 'Promozione attivata.'
                        : 'Promozione disattivata.',
                  ),
                ),
              );
            },
            onDelete:
                (promotion) => _confirmPromotionDeletion(context, promotion),
          ),
          const SizedBox(height: 32),
          _LastMinuteSection(
            slots: lastMinuteSlots,
            services: salonServices,
            staff: salonStaff,
            featureFlags: salon?.featureFlags,
            onDelete: (slot) => _confirmSlotDeletion(context, slot),
          ),
        ],
      ),
    );
  }

  Future<void> _openPromotionForm(
    BuildContext context, {
    required String salonId,
    Promotion? existing,
  }) async {
    final result = await showDialog<Promotion>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PromotionDialog(salonId: salonId, initialPromotion: existing);
      },
    );
    if (result == null) {
      return;
    }
    await ref.read(appDataProvider.notifier).upsertPromotion(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? 'Promozione creata con successo.'
              : 'Promozione aggiornata con successo.',
        ),
      ),
    );
  }

  Future<void> _confirmPromotionDeletion(
    BuildContext context,
    Promotion promotion,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Elimina promozione'),
          content: Text('Vuoi eliminare la promozione "${promotion.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    await ref.read(appDataProvider.notifier).deletePromotion(promotion.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Promozione eliminata.')));
  }

  Future<void> _confirmSlotDeletion(
    BuildContext context,
    LastMinuteSlot slot,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rimuovi slot last-minute'),
          content: Text(
            'Vuoi rimuovere lo slot last-minute delle ${_dateFormat.format(slot.start)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Rimuovi'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    await ref.read(appDataProvider.notifier).deleteLastMinuteSlot(slot.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Slot last-minute rimosso.')));
  }
}

class _PromotionsSection extends StatelessWidget {
  const _PromotionsSection({
    required this.promotions,
    required this.salonId,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final List<Promotion> promotions;
  final String salonId;
  final VoidCallback onCreate;
  final void Function(Promotion promotion) onEdit;
  final void Function(Promotion promotion, bool isActive) onToggleActive;
  final void Function(Promotion promotion) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Promozioni',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuova promozione'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (promotions.isEmpty)
              const Text('Non ci sono promozioni attive per questo salone.')
            else
              Column(
                children:
                    promotions.map((promotion) {
                      final period = _promotionPeriod(promotion);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(promotion.title),
                          subtitle: Text(period),
                          leading: Switch(
                            value: promotion.isActive,
                            onChanged:
                                (value) => onToggleActive(promotion, value),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  onEdit(promotion);
                                  break;
                                case 'delete':
                                  onDelete(promotion);
                                  break;
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Modifica'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Elimina'),
                                  ),
                                ],
                          ),
                          onTap: () => onEdit(promotion),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _promotionPeriod(Promotion promotion) {
    final start = promotion.startsAt;
    final end = promotion.endsAt;
    if (start == null && end == null) {
      return promotion.isActive ? 'Attiva senza scadenza' : 'Inattiva';
    }
    final buffer = StringBuffer();
    if (start != null) {
      buffer.write('Dal ${DateFormat('dd/MM').format(start)}');
    }
    if (end != null) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write('al ${DateFormat('dd/MM').format(end)}');
    }
    if (promotion.discountPercentage > 0) {
      buffer.write(' · -${promotion.discountPercentage.toStringAsFixed(0)}%');
    }
    return buffer.toString();
  }
}

class _LastMinuteSection extends StatelessWidget {
  const _LastMinuteSection({
    required this.slots,
    required this.services,
    required this.staff,
    required this.onDelete,
    this.featureFlags,
  });

  final List<LastMinuteSlot> slots;
  final List<Service> services;
  final List<StaffMember> staff;
  final void Function(LastMinuteSlot slot) onDelete;
  final SalonFeatureFlags? featureFlags;

  @override
  Widget build(BuildContext context) {
    final staffById = {for (final member in staff) member.id: member};
    final dateFormat = DateFormat('dd/MM HH:mm', 'it_IT');
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Slot last-minute',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Flexible(
                  child: Text(
                    featureFlags?.clientLastMinute == true
                        ? 'Crea nuovi slot direttamente dal calendario appuntamenti.'
                        : 'Attiva il flag “clientLastMinute” per rendere visibili gli slot ai clienti.',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (slots.isEmpty)
              const Text(
                'Non ci sono slot last-minute configurati. Dal calendario appuntamenti puoi convertire uno slot libero in offerta express.',
              )
            else
              Column(
                children:
                    slots.map((slot) {
                      final operatorName =
                          slot.operatorId != null
                              ? staffById[slot.operatorId!]?.fullName ??
                                  'Operatore non assegnato'
                              : 'Operatore non assegnato';
                      final timeLabel =
                          '${dateFormat.format(slot.start)} · ${slot.duration.inMinutes} min';
                      final priceLabel =
                          '${currency.format(slot.priceNow)} (base ${currency.format(slot.basePrice)})';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(slot.serviceName),
                          subtitle: Text(
                            [
                              timeLabel,
                              operatorName,
                              priceLabel,
                              if (!slot.isAvailable)
                                'Prenotato da ${slot.bookedClientName?.isNotEmpty == true ? slot.bookedClientName : 'cliente'}',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Rimuovi',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => onDelete(slot),
                          ),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PromotionDialog extends StatefulWidget {
  const _PromotionDialog({required this.salonId, this.initialPromotion});

  final String salonId;
  final Promotion? initialPromotion;

  @override
  State<_PromotionDialog> createState() => _PromotionDialogState();
}

class _PromotionDialogState extends State<_PromotionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _taglineController;
  late final TextEditingController _imageController;
  late final TextEditingController _ctaController;
  late final TextEditingController _discountController;
  late final TextEditingController _priorityController;
  late DateTime? _startsAt;
  late DateTime? _endsAt;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPromotion;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _subtitleController = TextEditingController(text: initial?.subtitle ?? '');
    _taglineController = TextEditingController(text: initial?.tagline ?? '');
    _imageController = TextEditingController(text: initial?.imageUrl ?? '');
    _ctaController = TextEditingController(text: initial?.ctaUrl ?? '');
    _discountController = TextEditingController(
      text: initial?.discountPercentage.toString() ?? '0',
    );
    _priorityController = TextEditingController(
      text: initial?.priority.toString() ?? '0',
    );
    _startsAt = initial?.startsAt;
    _endsAt = initial?.endsAt;
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _taglineController.dispose();
    _imageController.dispose();
    _ctaController.dispose();
    _discountController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialPromotion == null
            ? 'Nuova promozione'
            : 'Modifica promozione',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titolo *'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Inserisci un titolo'
                            : null,
              ),
              TextFormField(
                controller: _subtitleController,
                decoration: const InputDecoration(labelText: 'Sottotitolo'),
              ),
              TextFormField(
                controller: _taglineController,
                decoration: const InputDecoration(
                  labelText: 'Tagline / messaggio',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      decoration: const InputDecoration(labelText: 'Sconto %'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null;
                        }
                        final parsed = double.tryParse(
                          value.replaceAll(',', '.'),
                        );
                        if (parsed == null || parsed < 0 || parsed > 100) {
                          return 'Inserisci un valore tra 0 e 100';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _priorityController,
                      decoration: const InputDecoration(labelText: 'Priorità'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Inizio',
                      value: _startsAt,
                      onChanged: (value) => setState(() => _startsAt = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DatePickerField(
                      label: 'Fine',
                      value: _endsAt,
                      onChanged: (value) => setState(() => _endsAt = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'URL immagine promo',
                ),
              ),
              TextFormField(
                controller: _ctaController,
                decoration: const InputDecoration(
                  labelText: 'URL call-to-action',
                ),
              ),
              SwitchListTile(
                title: const Text('Promozione attiva'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.initialPromotion == null ? 'Crea' : 'Salva'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final discount =
        double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0.0;
    final priority = int.tryParse(_priorityController.text) ?? 0;
    final promotion = (widget.initialPromotion ??
            Promotion(
              id: const Uuid().v4(),
              salonId: widget.salonId,
              title: _titleController.text.trim(),
              discountPercentage: discount,
              priority: priority,
            ))
        .copyWith(
          salonId: widget.salonId,
          title: _titleController.text.trim(),
          subtitle:
              _subtitleController.text.trim().isEmpty
                  ? null
                  : _subtitleController.text.trim(),
          tagline:
              _taglineController.text.trim().isEmpty
                  ? null
                  : _taglineController.text.trim(),
          imageUrl:
              _imageController.text.trim().isEmpty
                  ? null
                  : _imageController.text.trim(),
          ctaUrl:
              _ctaController.text.trim().isEmpty
                  ? null
                  : _ctaController.text.trim(),
          discountPercentage: discount,
          priority: priority,
          startsAt: _startsAt,
          endsAt: _endsAt,
          isActive: _isActive,
        );
    Navigator.of(context).pop(promotion);
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final display =
        value == null
            ? 'Non impostata'
            : DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(value!);
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final initialDate = value ?? now;
        final date = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (date == null) {
          onChanged(null);
          return;
        }
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
        );
        if (time == null) {
          onChanged(DateTime(date.year, date.month, date.day));
          return;
        }
        final result = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        onChanged(result);
      },
      icon: const Icon(Icons.calendar_today_rounded),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(display),
          ],
        ),
      ),
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
    );
  }
}
