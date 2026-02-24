import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const int _clientBillingTabIndex = 6;

class AdminOverviewModule extends ConsumerWidget {
  const AdminOverviewModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final appointments =
        data.appointments
            .where(
              (appointment) =>
                  salonId == null || appointment.salonId == salonId,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final scheduledAppointmentsCount =
        appointments
            .where(
              (appointment) =>
                  appointment.status == AppointmentStatus.scheduled,
            )
            .length;
    final upcoming =
        appointments.where((a) => a.start.isAfter(now)).take(6).toList();

    final clients =
        data.clients
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final services =
        data.services
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final packages =
        data.packages
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final sales =
        data.sales
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final clientsById = {for (final client in clients) client.id: client};

    final activePackageClientEntries =
        clients
            .map((client) {
              final purchases = resolveClientPackagePurchases(
                sales: sales,
                packages: packages,
                appointments: appointments,
                services: services,
                clientId: client.id,
                salonId: salonId,
              );
              final activePurchases =
                  purchases.where((purchase) {
                      final expired =
                          purchase.expirationDate != null &&
                          purchase.expirationDate!.isBefore(now);
                      return purchase.isActive && !expired;
                    }).toList()
                    ..sort((a, b) => a.displayName.compareTo(b.displayName));
              if (activePurchases.isEmpty) {
                return null;
              }
              return _ClientActivePackagesEntry(
                client: client,
                purchases: List.unmodifiable(activePurchases),
              );
            })
            .whereType<_ClientActivePackagesEntry>()
            .toList()
          ..sort((a, b) {
            final byCount = b.purchases.length.compareTo(a.purchases.length);
            if (byCount != 0) return byCount;
            return a.client.fullName.toLowerCase().compareTo(
              b.client.fullName.toLowerCase(),
            );
          });
    final activeClientPackagesCount = activePackageClientEntries.fold<int>(
      0,
      (total, entry) => total + entry.purchases.length,
    );
    final currentYearReceiptsCount =
        sales.where((sale) => sale.createdAt.year == now.year).length;
    final currentYearSales =
        sales.where((sale) => sale.createdAt.year == now.year).toList();
    final currentYearRevenue = currentYearSales.fold<double>(
      0,
      (total, sale) => total + sale.total,
    );
    var currentYearServicesRevenue = 0.0;
    var currentYearPackagesRevenue = 0.0;
    for (final sale in currentYearSales) {
      final serviceGross = sale.items
          .where((item) => item.referenceType == SaleReferenceType.service)
          .fold<double>(0, (sum, item) => sum + item.amount);
      final packageGross = sale.items
          .where((item) => item.referenceType == SaleReferenceType.package)
          .fold<double>(0, (sum, item) => sum + item.amount);
      final saleItemsGross = sale.items.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      final loyaltyDiscount =
          sale.loyalty.redeemedValue <= 0
              ? 0.0
              : sale.loyalty.redeemedValue > saleItemsGross
              ? saleItemsGross
              : sale.loyalty.redeemedValue;
      final serviceLoyaltyShare =
          saleItemsGross <= 0 || loyaltyDiscount <= 0
              ? 0.0
              : loyaltyDiscount * (serviceGross / saleItemsGross);
      final packageLoyaltyShare =
          saleItemsGross <= 0 || loyaltyDiscount <= 0
              ? 0.0
              : loyaltyDiscount * (packageGross / saleItemsGross);
      currentYearServicesRevenue += (serviceGross - serviceLoyaltyShare);
      currentYearPackagesRevenue += (packageGross - packageLoyaltyShare);
    }
    currentYearServicesRevenue = double.parse(
      currentYearServicesRevenue.toStringAsFixed(2),
    );
    currentYearPackagesRevenue = double.parse(
      currentYearPackagesRevenue.toStringAsFixed(2),
    );
    final posticipatedSales =
        sales
            .where(
              (sale) =>
                  (sale.paymentStatus == SalePaymentStatus.posticipated ||
                      sale.paymentStatus == SalePaymentStatus.deposit) &&
                  sale.outstandingAmount > 0.009,
            )
            .toList();
    final posticipatedRevenue = posticipatedSales.fold<double>(
      0,
      (total, sale) => total + sale.outstandingAmount,
    );
    final posticipatedClientEntries =
        groupBy(posticipatedSales, (Sale sale) => sale.clientId).entries
            .map((entry) {
              final client = clientsById[entry.key];
              if (client == null) {
                return null;
              }
              final clientSales = [...entry.value]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final outstandingAmount = clientSales.fold<double>(
                0,
                (total, sale) => total + sale.outstandingAmount,
              );
              return _ClientPosticipatedEntry(
                client: client,
                sales: List.unmodifiable(clientSales),
                outstandingAmount: outstandingAmount,
              );
            })
            .whereType<_ClientPosticipatedEntry>()
            .toList()
          ..sort((a, b) {
            final byAmount = b.outstandingAmount.compareTo(a.outstandingAmount);
            if (byAmount != 0) return byAmount;
            return a.client.fullName.toLowerCase().compareTo(
              b.client.fullName.toLowerCase(),
            );
          });
    final totalLoyaltyEarnedPoints = sales.fold<int>(
      0,
      (total, sale) => total + sale.loyalty.resolvedEarnedPoints,
    );
    final totalLoyaltyRedeemedPoints = sales.fold<int>(
      0,
      (total, sale) => total + sale.loyalty.redeemedPoints,
    );
    final totalLoyaltyPoints = clients.fold<int>(
      0,
      (total, client) => total + client.loyaltyPoints,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                title: 'Appuntamenti',
                value: scheduledAppointmentsCount.toString(),
                subtitle: 'Totale pianificati',
                icon: Icons.event_available_rounded,
                accentColor: theme.colorScheme.primary,
              ),
              _MetricCard(
                title: 'Clienti',
                value: clients.length.toString(),
                subtitle: 'Anagrafiche registrate',
                icon: Icons.people_alt_rounded,
                accentColor: theme.colorScheme.secondary,
              ),
              _MetricCard(
                title: 'Totale scontrini',
                value: currentYearReceiptsCount.toString(),
                subtitle: 'Scontrini anno ${now.year}',
                icon: Icons.receipt_long_rounded,
                accentColor: theme.colorScheme.tertiary,
              ),
              _MetricCard(
                title: 'Incasso anno',
                value: NumberFormat.simpleCurrency(
                  locale: 'it_IT',
                ).format(currentYearRevenue),
                subtitle:
                    'Servizi: ${NumberFormat.simpleCurrency(locale: 'it_IT').format(currentYearServicesRevenue)}\n'
                    'Pacchetti: ${NumberFormat.simpleCurrency(locale: 'it_IT').format(currentYearPackagesRevenue)}',
                icon: Icons.point_of_sale_rounded,
                accentColor: theme.colorScheme.error,
              ),
              _MetricCard(
                title: 'Incasso Posticipato',
                value: NumberFormat.simpleCurrency(
                  locale: 'it_IT',
                ).format(posticipatedRevenue),
                subtitle: 'Residuo da saldare',
                icon: Icons.schedule_rounded,
                accentColor: theme.colorScheme.tertiary,
                onTap:
                    posticipatedClientEntries.isEmpty
                        ? null
                        : () => _showPosticipatedClientsModal(
                          context,
                          entries: posticipatedClientEntries,
                          totalOutstanding: posticipatedRevenue,
                        ),
              ),
              _MetricCard(
                title: 'Punti',
                value: '$totalLoyaltyPoints',
                subtitle:
                    'Assegnati: $totalLoyaltyEarnedPoints • Usati: $totalLoyaltyRedeemedPoints',
                icon: Icons.loyalty_rounded,
                accentColor: theme.colorScheme.primary,
              ),
              _MetricCard(
                title: 'Pacchetti',
                value: activeClientPackagesCount.toString(),
                subtitle: 'Pacchetti attivi clienti',
                icon: Icons.card_giftcard_rounded,
                accentColor: theme.colorScheme.secondary,
                onTap:
                    activePackageClientEntries.isEmpty
                        ? null
                        : () => _showActivePackagesClientsModal(
                          context,
                          entries: activePackageClientEntries,
                          totalPackages: activeClientPackagesCount,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (upcoming.isNotEmpty) ...[
            Text('Prossimi appuntamenti', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final appointment = upcoming[index];
                  final client = data.clients.firstWhereOrNull(
                    (c) => c.id == appointment.clientId,
                  );
                  final services =
                      appointment.serviceIds
                          .map(
                            (id) => data.services.firstWhereOrNull(
                              (service) => service.id == id,
                            ),
                          )
                          .whereType<Service>()
                          .toList();
                  final staffMember = data.staff.firstWhereOrNull(
                    (s) => s.id == appointment.staffId,
                  );
                  final date = DateFormat(
                    'EEEE dd MMMM HH:mm',
                    'it_IT',
                  ).format(appointment.start);
                  final serviceLabel =
                      services.isNotEmpty
                          ? services.map((service) => service.name).join(' + ')
                          : 'Servizio';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text(
                        client?.firstName.characters.firstOrNull
                                ?.toUpperCase() ??
                            '?',
                      ),
                    ),
                    title: Text(
                      '${client?.fullName ?? 'Cliente'} • $serviceLabel',
                    ),
                    subtitle: Text(
                      '$date • ${staffMember?.fullName ?? 'Staff'}',
                    ),
                    trailing: _statusChip(appointment.status, theme),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: upcoming.length,
              ),
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Nessun appuntamento imminente',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(AppointmentStatus status, ThemeData theme) {
    Color background;
    Color foreground;
    String label;
    switch (status) {
      case AppointmentStatus.scheduled:
        background = theme.colorScheme.primaryContainer;
        foreground = theme.colorScheme.onPrimaryContainer;
        label = 'Programmato';
        break;
      case AppointmentStatus.completed:
        background = theme.colorScheme.tertiaryContainer;
        foreground = theme.colorScheme.onTertiaryContainer;
        label = 'Completato';
        break;
      case AppointmentStatus.cancelled:
        background = theme.colorScheme.errorContainer;
        foreground = theme.colorScheme.onErrorContainer;
        label = 'Annullato';
        break;
      case AppointmentStatus.noShow:
        background = theme.colorScheme.error.withValues(alpha: 0.2);
        foreground = theme.colorScheme.error;
        label = 'No show';
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground),
    );
  }

  void _showActivePackagesClientsModal(
    BuildContext context, {
    required List<_ClientActivePackagesEntry> entries,
    required int totalPackages,
  }) {
    _showClientListModal(
      context,
      title: 'Clienti con pacchetti attivi',
      subtitle: '${entries.length} clienti • $totalPackages pacchetti attivi',
      itemCount: entries.length,
      itemBuilder: (sheetContext, index) {
        final entry = entries[index];
        final packageNames = entry.purchases
            .map((purchase) => purchase.displayName)
            .toList(growable: false);
        final packagePreview = packageNames.take(3).join(', ');
        final hasMore = packageNames.length > 3;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            child: Text(
              entry.client.firstName.characters.firstOrNull?.toUpperCase() ??
                  '?',
            ),
          ),
          title: _ClientNameLink(
            parentContext: context,
            modalContext: sheetContext,
            client: entry.client,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${entry.purchases.length} pacchetti attivi'),
              if (packagePreview.isNotEmpty)
                Text(
                  hasMore ? '$packagePreview…' : packagePreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Chip(label: Text('${entry.purchases.length}')),
          isThreeLine: packagePreview.isNotEmpty,
        );
      },
    );
  }

  void _showPosticipatedClientsModal(
    BuildContext context, {
    required List<_ClientPosticipatedEntry> entries,
    required double totalOutstanding,
  }) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    _showClientListModal(
      context,
      title: 'Clienti con importi da saldare',
      subtitle:
          '${entries.length} clienti • Da incassare ${currency.format(totalOutstanding)}',
      itemCount: entries.length,
      itemBuilder: (sheetContext, index) {
        final entry = entries[index];
        final latestDate = entry.sales.first.createdAt;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            child: Text(
              entry.client.firstName.characters.firstOrNull?.toUpperCase() ??
                  '?',
            ),
          ),
          title: _ClientNameLink(
            parentContext: context,
            modalContext: sheetContext,
            client: entry.client,
            initialTabIndex: _clientBillingTabIndex,
          ),
          subtitle: Text(
            '${entry.sales.length} vendite da saldare • Ultimo movimento ${DateFormat('dd/MM/yyyy', 'it_IT').format(latestDate)}',
          ),
          trailing: Text(
            currency.format(entry.outstandingAmount),
            style: Theme.of(
              sheetContext,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  void _showClientListModal(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext sheetContext, int index) itemBuilder,
  }) {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final media = MediaQuery.of(sheetContext);
        final maxHeight = media.size.height * 0.78;
        final dialogWidth =
            media.size.width < 720 ? media.size.width * 0.94 : 680.0;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: maxHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child:
                      itemCount == 0
                          ? Center(
                            child: Text(
                              'Nessun elemento disponibile',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                          : ListView.separated(
                            itemCount: itemCount,
                            itemBuilder: itemBuilder,
                            separatorBuilder:
                                (_, __) => const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccent = accentColor ?? theme.colorScheme.primary;
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
        child:
            onTap == null
                ? _MetricCardBody(
                  title: title,
                  value: value,
                  subtitle: subtitle,
                  icon: icon,
                  effectiveAccent: effectiveAccent,
                )
                : InkWell(
                  onTap: onTap,
                  child: _MetricCardBody(
                    title: title,
                    value: value,
                    subtitle: subtitle,
                    icon: icon,
                    effectiveAccent: effectiveAccent,
                  ),
                ),
      ),
    );
  }
}

class _MetricCardBody extends StatelessWidget {
  const _MetricCardBody({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.effectiveAccent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color effectiveAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final subtitleLines = subtitle.split('\n');
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: effectiveAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: effectiveAccent, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: subtitleLines
                .map(
                  (line) => SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line,
                        maxLines: 1,
                        softWrap: false,
                        style: subtitleStyle,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ClientNameLink extends StatelessWidget {
  const _ClientNameLink({
    required this.parentContext,
    required this.modalContext,
    required this.client,
    this.initialTabIndex = 0,
  });

  final BuildContext parentContext;
  final BuildContext modalContext;
  final Client client;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          Navigator.of(modalContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            openClientDetailPage(
              parentContext,
              clientId: client.id,
              initialTabIndex: initialTabIndex,
            );
          });
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          alignment: Alignment.centerLeft,
          foregroundColor: theme.colorScheme.primary,
        ),
        child: Text(
          client.fullName,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _ClientActivePackagesEntry {
  const _ClientActivePackagesEntry({
    required this.client,
    required this.purchases,
  });

  final Client client;
  final List<ClientPackagePurchase> purchases;
}

class _ClientPosticipatedEntry {
  const _ClientPosticipatedEntry({
    required this.client,
    required this.sales,
    required this.outstandingAmount,
  });

  final Client client;
  final List<Sale> sales;
  final double outstandingAmount;
}
