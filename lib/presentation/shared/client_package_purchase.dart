import 'dart:math' as math;

import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:collection/collection.dart';

class ClientPackagePurchase {
  ClientPackagePurchase({
    required this.sale,
    required this.item,
    required this.itemIndex,
    required this.package,
    required this.usedSessions,
    required this.usedSessionsByService,
    required this.serviceNames,
  });

  final Sale sale;
  final SaleItem item;
  final int itemIndex;
  final ServicePackage? package;
  final int usedSessions;
  final Map<String, int> usedSessionsByService;
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
    final explicit = item.totalSessions;
    if (explicit != null) {
      return explicit;
    }

    final configured = package?.totalConfiguredSessions;
    if (configured != null) {
      final total = configured * item.quantity;
      return total.isFinite ? total.round() : null;
    }

    final serviceIds = <String>{
      ...package?.serviceSessionCounts?.keys ?? const <String>{},
      ...item.packageServiceSessions.keys,
      ...item.remainingPackageServiceSessions.keys,
      ...usedSessionsByService.keys,
    }..removeWhere((id) => id.isEmpty);

    if (serviceIds.isEmpty) {
      return null;
    }

    var sum = 0;
    var hasAny = false;
    for (final serviceId in serviceIds) {
      final totalForService = totalSessionsForService(serviceId);
      if (totalForService != null) {
        sum += totalForService;
        hasAny = true;
      }
    }
    if (!hasAny) {
      return null;
    }
    return sum;
  }

  int? get remainingSessions {
    final remainingByService = item.remainingPackageServiceSessions;
    if (remainingByService.isNotEmpty) {
      return remainingByService.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
    }

    if (item.remainingSessions != null) {
      return item.remainingSessions;
    }

    if (item.packageServiceSessions.isNotEmpty) {
      final baseline = item.packageServiceSessions.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      final effective = baseline - usedSessions;
      return effective <= 0 ? 0 : effective;
    }

    final total = totalSessions;
    if (total == null) {
      return null;
    }
    final remaining = total - usedSessions;
    return remaining <= 0 ? 0 : remaining;
  }

  int remainingSessionsForService(String serviceId) {
    final byService = item.remainingPackageServiceSessions;
    if (byService.isNotEmpty && byService.containsKey(serviceId)) {
      return byService[serviceId]!;
    }

    if (item.packageServiceSessions.containsKey(serviceId)) {
      final baseline = item.packageServiceSessions[serviceId] ?? 0;
      final used = usedSessionsByService[serviceId] ?? 0;
      final remaining = baseline - used;
      return remaining <= 0 ? 0 : remaining;
    }

    final total = totalSessionsForService(serviceId);
    final used = usedSessionsByService[serviceId] ?? 0;

    if (total != null) {
      final remaining = total - used;
      return remaining <= 0 ? 0 : remaining;
    }

    // Fallback when totals are unknown: preserve the overall remaining snapshot.
    return math.max(0, effectiveRemainingSessions - used);
  }

  int? totalSessionsForService(String serviceId) {
    final packageSessions = package?.serviceSessionCounts;
    if (packageSessions != null && packageSessions.isNotEmpty) {
      final configured = packageSessions[serviceId];
      if (configured != null) {
        return (configured * item.quantity).round();
      }
    }

    if (item.packageServiceSessions.isNotEmpty) {
      final remaining = item.packageServiceSessions[serviceId];
      if (remaining != null) {
        final used = usedSessionsByService[serviceId] ?? 0;
        final estimated = remaining + used;
        return estimated > 0 ? estimated : null;
      }
    }

    if (item.remainingPackageServiceSessions.isNotEmpty) {
      final remaining = item.remainingPackageServiceSessions[serviceId];
      if (remaining != null) {
        final used = usedSessionsByService[serviceId] ?? 0;
        final estimated = remaining + used;
        return estimated > 0 ? estimated : null;
      }
    }

    return null;
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
  final totalUsageByPackage = <String, int>{};
  final usageByPackageAndService = <String, Map<String, int>>{};
  for (final appointment in appointments.where(
    (appt) =>
        appt.clientId == clientId &&
        (salonId == null || appt.salonId == salonId) &&
        appt.status == AppointmentStatus.completed,
  )) {
    if (appointment.hasPackageConsumptions) {
      for (final allocation in appointment.serviceAllocations) {
        final serviceId = allocation.serviceId;
        if (serviceId.isEmpty) continue;
        for (final consumption in allocation.packageConsumptions) {
          final packageId = consumption.packageReferenceId;
          if (packageId.isEmpty) continue;
          final quantity = consumption.quantity <= 0 ? 1 : consumption.quantity;
          totalUsageByPackage.update(
            packageId,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
          final serviceUsage = usageByPackageAndService.putIfAbsent(
            packageId,
            () => <String, int>{},
          );
          serviceUsage.update(
            serviceId,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        }
      }
      continue;
    }
    final legacyPackageId = appointment.packageId;
    if (legacyPackageId == null) continue;
    totalUsageByPackage.update(
      legacyPackageId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    final serviceUsage = usageByPackageAndService.putIfAbsent(
      legacyPackageId,
      () => <String, int>{},
    );
    final serviceId = appointment.serviceId;
    if (serviceId.isNotEmpty) {
      serviceUsage.update(serviceId, (value) => value + 1, ifAbsent: () => 1);
    }
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
      final consumedSessions = totalUsageByPackage[item.referenceId] ?? 0;
      final consumedByService =
          usageByPackageAndService[item.referenceId] ?? const <String, int>{};
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
          usedSessionsByService: consumedByService,
          serviceNames: serviceNames,
        ),
      );
    }
  }
  purchases.sort((a, b) => b.sale.createdAt.compareTo(a.sale.createdAt));
  return purchases;
}
