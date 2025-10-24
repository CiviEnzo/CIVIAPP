import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/promotions/promotion_editor_dialog.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
                    onChanged:
                        salon == null
                            ? null
                            : (value) {
                              final AppDataStore store = ref.read(
                                appDataProvider.notifier,
                              );
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
                    onChanged:
                        salon == null
                            ? null
                            : (value) {
                              final AppDataStore store = ref.read(
                                appDataProvider.notifier,
                              );
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
            onCreate:
                () =>
                    _openPromotionForm(context, salonId: salonId, salon: salon),
            onEdit:
                (promotion) => _openPromotionForm(
                  context,
                  salonId: salonId,
                  salon: salon,
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
    Salon? salon,
    Promotion? existing,
  }) async {
    final result = await showDialog<Promotion>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PromotionEditorDialog(
          salonId: salonId,
          salon: salon,
          initialPromotion: existing,
        );
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
