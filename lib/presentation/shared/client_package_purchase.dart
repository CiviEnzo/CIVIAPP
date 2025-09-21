import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:collection/collection.dart';

class ClientPackagePurchase {
  ClientPackagePurchase({
    required this.sale,
    required this.item,
    required this.itemIndex,
    required this.package,
    required this.usedSessions,
    required this.serviceNames,
  });

  final Sale sale;
  final SaleItem item;
  final int itemIndex;
  final ServicePackage? package;
  final int usedSessions;
  final List<String> serviceNames;

  /// Prefer the package name from catalog, fallback to the sale item description.
  String get displayName => package?.name ?? item.description;

  double get totalAmount => item.amount;

  double get depositAmount => item.depositAmount;

  List<PackageDeposit> get deposits => item.deposits;

  double get outstandingAmount {
    final deposit = depositAmount;
    final outstanding = totalAmount - deposit;
    return outstanding <= 0 ? 0 : outstanding;
  }

  int? get totalSessions {
    if (item.totalSessions != null) {
      return item.totalSessions;
    }
    final sessionsPerPackage =
        package?.totalConfiguredSessions ??
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

  int? get remainingSessions {
    if (item.remainingSessions != null) {
      return item.remainingSessions;
    }
    final total = totalSessions;
    if (total == null) {
      return null;
    }
    final remaining = total - usedSessions;
    return remaining <= 0 ? 0 : remaining;
  }

  DateTime? get expirationDate {
    if (item.expirationDate != null) {
      return item.expirationDate;
    }
    final validityDays = package?.validDays;
    if (validityDays == null) {
      return null;
    }
    return sale.createdAt.add(Duration(days: validityDays));
  }

  PackagePurchaseStatus get status {
    final stored = item.packageStatus;
    if (stored != null) {
      return stored;
    }
    final remaining = remainingSessions;
    if (remaining != null && remaining <= 0) {
      return PackagePurchaseStatus.completed;
    }
    return PackagePurchaseStatus.active;
  }

  PackagePaymentStatus get paymentStatus =>
      item.packagePaymentStatus ??
      (item.depositAmount > 0 && outstandingAmount > 0
          ? PackagePaymentStatus.deposit
          : PackagePaymentStatus.paid);

  bool get isActive => status == PackagePurchaseStatus.active;

  /// Determine if the purchase can be applied to the provided service.
  bool supportsService(String serviceId) {
    if (item.packageServiceSessions.isNotEmpty) {
      return item.packageServiceSessions.containsKey(serviceId);
    }
    final packageSessions = package?.serviceSessionCounts;
    if (packageSessions != null && packageSessions.isNotEmpty) {
      return packageSessions.containsKey(serviceId);
    }
    final configuredServices = package?.serviceIds;
    if (configuredServices != null && configuredServices.isNotEmpty) {
      return configuredServices.contains(serviceId);
    }
    // When nothing is configured assume the package is generic and can cover the service.
    return true;
  }

  int get effectiveRemainingSessions => remainingSessions ?? totalSessions ?? 0;
}

List<ClientPackagePurchase> resolveClientPackagePurchases({
  required List<Sale> sales,
  required List<ServicePackage> packages,
  required List<Appointment> appointments,
  required List<Service> services,
  required String clientId,
  String? salonId,
}) {
  final usageByPackage = <String, int>{};
  for (final appointment in appointments.where(
    (appt) =>
        appt.clientId == clientId &&
        (salonId == null || appt.salonId == salonId) &&
        appt.status == AppointmentStatus.completed,
  )) {
    final packageId = appointment.packageId;
    if (packageId == null) continue;
    usageByPackage.update(packageId, (value) => value + 1, ifAbsent: () => 1);
  }

  final purchases = <ClientPackagePurchase>[];
  for (final sale in sales.where(
    (sale) =>
        sale.clientId == clientId &&
        (salonId == null || sale.salonId == salonId),
  )) {
    for (var index = 0; index < sale.items.length; index++) {
      final item = sale.items[index];
      if (item.referenceType != SaleReferenceType.package) {
        continue;
      }
      final package = packages.firstWhereOrNull(
        (element) => element.id == item.referenceId,
      );
      final consumedSessions = usageByPackage[item.referenceId] ?? 0;
      final sessionSource =
          item.packageServiceSessions.isNotEmpty
              ? item.packageServiceSessions
              : package?.serviceSessionCounts ?? const <String, int>{};
      final serviceNames = <String>[];
      if (sessionSource.isNotEmpty) {
        for (final entry in sessionSource.entries) {
          final service = services.firstWhereOrNull(
            (element) => element.id == entry.key,
          );
          final label = service?.name ?? entry.key;
          final totalSessions = (entry.value * item.quantity).round();
          serviceNames.add('$label ($totalSessions sessioni)');
        }
      } else {
        serviceNames.addAll(
          (package?.serviceIds ?? const <String>[])
              .map(
                (id) =>
                    services
                        .firstWhereOrNull((service) => service.id == id)
                        ?.name,
              )
              .nonNulls,
        );
      }
      serviceNames.sort();
      purchases.add(
        ClientPackagePurchase(
          sale: sale,
          item: item,
          itemIndex: index,
          package: package,
          usedSessions: consumedSessions,
          serviceNames: serviceNames,
        ),
      );
    }
  }
  purchases.sort((a, b) => b.sale.createdAt.compareTo(a.sale.createdAt));
  return purchases;
}
