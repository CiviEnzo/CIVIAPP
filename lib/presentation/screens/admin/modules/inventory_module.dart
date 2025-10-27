import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/inventory_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class InventoryModule extends ConsumerWidget {
  const InventoryModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final items =
        data.inventoryItems
            .where((item) => salonId == null || item.salonId == salonId)
            .toList()
          ..sort((a, b) => a.category.compareTo(b.category));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed:
                  () => _openForm(
                    context,
                    ref,
                    salons: salons,
                    defaultSalonId: salonId,
                  ),
              icon: const Icon(Icons.add_box_rounded),
              label: const Text('Nuovo articolo'),
            ),
          );
        }
        final item = items[index - 1];
        final alert = item.quantity <= item.threshold;
        final progress =
            item.threshold == 0
                ? 1.0
                : (item.quantity / (item.threshold * 2)).clamp(0.0, 1.0);
        final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(item.category),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantità: ${item.quantity.toStringAsFixed(0)} ${item.unit}',
                          ),
                          Text(
                            'Soglia minima: ${item.threshold.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            color:
                                alert
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Costo: ${currency.format(item.cost)}'),
                        Text('Prezzo: ${currency.format(item.sellingPrice)}'),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          onPressed:
                              () => _openForm(
                                context,
                                ref,
                                salons: salons,
                                defaultSalonId: salonId,
                                existing: item,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (item.updatedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ultimo aggiornamento: ${DateFormat('dd/MM/yyyy').format(item.updatedAt!)}',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  String? defaultSalonId,
  InventoryItem? existing,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea un salone prima di gestire il magazzino.'),
      ),
    );
    return;
  }
  final result = await showAppModalSheet<InventoryItem>(
    context: context,
    builder:
        (ctx) => InventoryFormSheet(
          salons: salons,
          defaultSalonId: defaultSalonId,
          initial: existing,
        ),
  );
  if (result != null) {
    await ref.read(appDataProvider.notifier).upsertInventoryItem(result);
  }
}
