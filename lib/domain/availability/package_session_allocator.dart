import 'package:you_book/domain/entities/appointment_service_allocation.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';

/// Result of the automatic package session allocation pass.
class PackageSessionAllocationSuggestion {
  const PackageSessionAllocationSuggestion({
    required this.allocations,
    required this.uncoveredServices,
    required this.hasCoverage,
  });

  /// Allocations ready to be persisted on an appointment.
  final List<AppointmentServiceAllocation> allocations;

  /// Map of serviceId -> quantity not covered by any package.
  final Map<String, int> uncoveredServices;

  /// Whether all requested services have sufficient package coverage.
  final bool hasCoverage;
}

/// Allocator skeleton that will eventually distribute package sessions across
/// the requested services. The current implementation is a placeholder that
/// simply mirrors the requested services without assigning consumptions.
class PackageSessionAllocator {
  const PackageSessionAllocator();

  PackageSessionAllocationSuggestion suggest({
    required Map<String, int> requestedServices,
    required List<ClientPackagePurchase> availablePackages,
  }) {
    final remainingNeed = Map<String, int>.from(requestedServices);
    final consumptionPlan = <String, List<AppointmentPackageConsumption>>{};

    for (final entry in remainingNeed.entries) {
      consumptionPlan[entry.key] = <AppointmentPackageConsumption>[];
    }

    final sortedPackages = List<ClientPackagePurchase>.from(
      availablePackages.where((package) => package.isActive),
    )..sort((a, b) {
      final aExpiration = a.expirationDate ?? DateTime(9999, 1, 1);
      final bExpiration = b.expirationDate ?? DateTime(9999, 1, 1);
      final expirationCompare = aExpiration.compareTo(bExpiration);
      if (expirationCompare != 0) {
        return expirationCompare;
      }
      final aRemaining = a.effectiveRemainingSessions;
      final bRemaining = b.effectiveRemainingSessions;
      if (aRemaining != bRemaining) {
        return aRemaining.compareTo(bRemaining);
      }
      return a.sale.createdAt.compareTo(b.sale.createdAt);
    });

    for (final package in sortedPackages) {
      if (!remainingNeed.values.any((value) => value > 0)) {
        break;
      }
      final serviceIds = requestedServices.keys.where(
        (serviceId) => package.supportsService(serviceId),
      );
      if (serviceIds.isEmpty) {
        continue;
      }

      final remainingTotal = package.effectiveRemainingSessions;
      if (remainingTotal <= 0) {
        continue;
      }
      var availableCapacity = remainingTotal;

      final sortedServices =
          serviceIds.toList()..sort((a, b) {
            final needsA = remainingNeed[a] ?? 0;
            final needsB = remainingNeed[b] ?? 0;
            if (needsA != needsB) {
              return needsB.compareTo(needsA);
            }
            final remainingServiceA = package.remainingSessionsForService(a);
            final remainingServiceB = package.remainingSessionsForService(b);
            if (remainingServiceA != remainingServiceB) {
              return remainingServiceA.compareTo(remainingServiceB);
            }
            final totalA =
                package.totalSessionsForService(a) ?? remainingServiceA;
            final totalB =
                package.totalSessionsForService(b) ?? remainingServiceB;
            return totalA.compareTo(totalB);
          });

      for (final serviceId in sortedServices) {
        var need = remainingNeed[serviceId] ?? 0;
        if (need <= 0 || availableCapacity <= 0) {
          continue;
        }

        final perServiceRemaining = package.remainingSessionsForService(
          serviceId,
        );
        if (perServiceRemaining <= 0) {
          continue;
        }

        final canAllocate =
            perServiceRemaining < availableCapacity
                ? perServiceRemaining
                : availableCapacity;
        final allocation = need < canAllocate ? need : canAllocate;
        if (allocation <= 0) {
          continue;
        }

        consumptionPlan[serviceId]!.add(
          AppointmentPackageConsumption(
            packageReferenceId: package.item.referenceId,
            sessionTypeId: null,
            quantity: allocation,
          ),
        );

        need -= allocation;
        remainingNeed[serviceId] = need;
        availableCapacity -= allocation;
      }
    }

    final allocations = <AppointmentServiceAllocation>[];
    remainingNeed.forEach((serviceId, remaining) {
      final requestedQuantity = requestedServices[serviceId] ?? 0;
      allocations.add(
        AppointmentServiceAllocation(
          serviceId: serviceId,
          quantity: requestedQuantity,
          packageConsumptions: List.unmodifiable(
            consumptionPlan[serviceId] ??
                const <AppointmentPackageConsumption>[],
          ),
        ),
      );
    });

    final uncovered = Map<String, int>.fromEntries(
      remainingNeed.entries.where((entry) => entry.value > 0),
    );

    return PackageSessionAllocationSuggestion(
      allocations: allocations,
      uncoveredServices: uncovered,
      hasCoverage: uncovered.isEmpty,
    );
  }
}
