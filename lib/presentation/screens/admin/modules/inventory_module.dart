import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/inventory_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class InventoryModule extends ConsumerStatefulWidget {
  const InventoryModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<InventoryModule> createState() => _InventoryModuleState();
}

class _InventoryModuleState extends ConsumerState<InventoryModule> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyCritical = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final items =
        data.inventoryItems
            .where(
              (item) =>
                  widget.salonId == null || item.salonId == widget.salonId,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final filteredItems =
        items.where((item) {
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.toLowerCase().trim();
            if (!item.name.toLowerCase().contains(query) &&
                !item.category.toLowerCase().contains(query)) {
              return false;
            }
          }
          if (_onlyCritical) {
            return _status(item) != _InventoryStatus.available;
          }
          return true;
        }).toList();

    final currencyNoDecimals = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 0,
    );
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 2,
    );
    final lowStockCount =
        items
            .where((item) => _status(item) == _InventoryStatus.lowStock)
            .length;
    final outOfStockCount =
        items
            .where((item) => _status(item) == _InventoryStatus.outOfStock)
            .length;
    final inventoryValue = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.cost),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final action = FilledButton.icon(
              onPressed:
                  () => _openForm(
                    context,
                    ref,
                    salons: salons,
                    defaultSalonId: widget.salonId,
                  ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4AD31),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Aggiungi Prodotto'),
            );
            if (constraints.maxWidth < kAdminPhoneBreakpoint) {
              return SizedBox(width: double.infinity, child: action);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Spacer(), action],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 1180
                    ? 4
                    : constraints.maxWidth >= kAdminTwoColumnBreakpoint
                    ? 2
                    : 1;
            final tileWidth =
                columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - (10 * (columns - 1))) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _MetricCard(
                    label: 'Prodotti Totali',
                    value: '${items.length}',
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _MetricCard(
                    label: 'Valore Inventario',
                    value: currencyNoDecimals.format(inventoryValue),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _MetricCard(
                    label: 'Scorte Basse',
                    value: '$lowStockCount',
                    valueColor: const Color(0xFFE19C2E),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _MetricCard(
                    label: 'Esauriti',
                    value: '$outOfStockCount',
                    valueColor: const Color(0xFFDE4040),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        AdminResponsiveToolbar(
          primary: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'cerca prodotto...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          secondary: OutlinedButton.icon(
            onPressed: () => setState(() => _onlyCritical = !_onlyCritical),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              side: BorderSide(
                color:
                    _onlyCritical
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
              ),
            ),
            icon: const Icon(Icons.filter_alt_outlined, size: 18),
            label: Text(_onlyCritical ? 'Filtri: critici' : 'Filtri'),
          ),
          secondaryFullWidthOnStack: true,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompactTable = constraints.maxWidth < 760;
            if (isCompactTable) {
              return Container(
                key: const ValueKey('inventory_mobile_list'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (filteredItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 22,
                        ),
                        child: Text(
                          'Nessun prodotto trovato',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    for (final item in filteredItems) ...[
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: _InventoryMobileCard(
                          item: item,
                          currency: currency,
                          onEdit:
                              () => _openForm(
                                context,
                                ref,
                                salons: salons,
                                defaultSalonId: widget.salonId,
                                existing: item,
                              ),
                          onIncreaseStock: () => _increaseStock(ref, item),
                        ),
                      ),
                      if (item != filteredItems.last)
                        Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.6),
                        ),
                    ],
                  ],
                ),
              );
            }

            return Container(
              key: const ValueKey('inventory_table_view'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 4, child: Text('Prodotto')),
                        Expanded(flex: 2, child: Text('Giacenza')),
                        Expanded(flex: 2, child: Text('Prezzo')),
                        Expanded(flex: 3, child: Text('Stato')),
                        Expanded(flex: 2, child: Text('Azioni')),
                      ],
                    ),
                  ),
                  if (filteredItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 22,
                      ),
                      child: Text(
                        'Nessun prodotto trovato',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  for (final item in filteredItems) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.category,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color:
                                        _status(item) ==
                                                _InventoryStatus.available
                                            ? null
                                            : const Color(0xFFE19C2E),
                                  ),
                                ),
                                Text(
                                  'Min: ${item.threshold.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currency.format(item.sellingPrice),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _InventoryStatusChip(
                                status: _status(item),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Wrap(
                              spacing: 2,
                              children: [
                                IconButton(
                                  tooltip: 'Modifica',
                                  visualDensity: VisualDensity.compact,
                                  onPressed:
                                      () => _openForm(
                                        context,
                                        ref,
                                        salons: salons,
                                        defaultSalonId: widget.salonId,
                                        existing: item,
                                      ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Aggiungi giacenza',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _increaseStock(ref, item),
                                  icon: const Icon(Icons.add, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item != filteredItems.last)
                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.6),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _increaseStock(WidgetRef ref, InventoryItem item) async {
    final updated = InventoryItem(
      id: item.id,
      salonId: item.salonId,
      name: item.name,
      category: item.category,
      quantity: item.quantity + 1,
      unit: item.unit,
      threshold: item.threshold,
      cost: item.cost,
      sellingPrice: item.sellingPrice,
      updatedAt: DateTime.now(),
    );
    await ref.read(appDataProvider.notifier).upsertInventoryItem(updated);
  }
}

enum _InventoryStatus { available, lowStock, outOfStock }

_InventoryStatus _status(InventoryItem item) {
  if (item.quantity <= 0) {
    return _InventoryStatus.outOfStock;
  }
  if (item.quantity <= item.threshold) {
    return _InventoryStatus.lowStock;
  }
  return _InventoryStatus.available;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryMobileCard extends StatelessWidget {
  const _InventoryMobileCard({
    required this.item,
    required this.currency,
    required this.onEdit,
    required this.onIncreaseStock,
  });

  final InventoryItem item;
  final NumberFormat currency;
  final VoidCallback onEdit;
  final VoidCallback onIncreaseStock;

  @override
  Widget build(BuildContext context) {
    final quantityColor =
        _status(item) == _InventoryStatus.available
            ? null
            : const Color(0xFFE19C2E);
    return _InventoryMobileSummaryCard(
      title: item.name,
      subtitle: item.category,
      rows: [
        _InventoryMobileSummaryRow(
          label: 'Giacenza',
          value: '${item.quantity.toStringAsFixed(0)} ${item.unit}',
          subtitle: 'Min: ${item.threshold.toStringAsFixed(0)}',
          valueColor: quantityColor,
        ),
        _InventoryMobileSummaryRow(
          label: 'Prezzo',
          value: currency.format(item.sellingPrice),
        ),
        _InventoryMobileSummaryRow(
          label: 'Stato',
          child: _InventoryStatusChip(status: _status(item)),
        ),
      ],
      actions: [
        _InventoryMobileActionButton(
          tooltip: 'Modifica',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        _InventoryMobileActionButton(
          tooltip: 'Aggiungi giacenza',
          icon: Icons.add,
          onPressed: onIncreaseStock,
        ),
      ],
    );
  }
}

class _InventoryMobileSummaryCard extends StatelessWidget {
  const _InventoryMobileSummaryCard({
    required this.title,
    required this.subtitle,
    required this.rows,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final List<Widget> rows;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ...rows,
        if (actions.isNotEmpty) ...[
          Divider(height: 24, color: theme.dividerColor.withValues(alpha: 0.7)),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 8, runSpacing: 8, children: actions),
          ),
        ],
      ],
    );
  }
}

class _InventoryMobileSummaryRow extends StatelessWidget {
  const _InventoryMobileSummaryRow({
    required this.label,
    this.value,
    this.subtitle,
    this.child,
    this.valueColor,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;
  final String? subtitle;
  final Widget? child;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget buildValue({required bool stacked}) {
      return child ??
          Column(
            crossAxisAlignment:
                stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                value!,
                textAlign: stacked ? TextAlign.start : TextAlign.right,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  textAlign: stacked ? TextAlign.start : TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackRow = constraints.maxWidth < 340;
          if (stackRow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                buildValue(stacked: true),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.topRight,
                  child: buildValue(stacked: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryMobileActionButton extends StatelessWidget {
  const _InventoryMobileActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        foregroundColor: theme.colorScheme.onSurface,
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _InventoryStatusChip extends StatelessWidget {
  const _InventoryStatusChip({required this.status});

  final _InventoryStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final IconData icon;
    late final Color bgColor;
    late final Color fgColor;

    switch (status) {
      case _InventoryStatus.available:
        label = 'Disponibile';
        icon = Icons.check_circle_outline_rounded;
        bgColor = const Color(0xFFE0F4E7);
        fgColor = const Color(0xFF32935A);
      case _InventoryStatus.lowStock:
        label = 'Scorta Bassa';
        icon = Icons.warning_amber_rounded;
        bgColor = const Color(0xFFFFF1DD);
        fgColor = const Color(0xFFE19C2E);
      case _InventoryStatus.outOfStock:
        label = 'Esaurito';
        icon = Icons.cancel_outlined;
        bgColor = const Color(0xFFFBE7E7);
        fgColor = const Color(0xFFDE4040);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fgColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
    ScaffoldMessenger.of(context).showAppSnackBar(
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
