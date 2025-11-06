import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_filters.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';

class AdvancedSearchEngine {
  const AdvancedSearchEngine({
    required this.state,
    required this.now,
    this.defaultSalonId,
  });

  final AppDataState state;
  final DateTime now;
  final String? defaultSalonId;

  List<Client> apply(AdvancedSearchFilters filters) {
    final salonId = filters.salonId ?? defaultSalonId;
    final normalizedFilters =
        filters.salonId == salonId ? filters : filters.copyWith(salonId: salonId);

    final baseClients = state.clients.where((client) {
      if (salonId != null && client.salonId != salonId) {
        return false;
      }
      return true;
    }).toList(growable: false);
    if (baseClients.isEmpty) {
      return const <Client>[];
    }

    var filtered = _applyClientFilters(
      baseClients,
      normalizedFilters,
      now,
    );
    if (filtered.isEmpty) {
      return filtered;
    }

    final requiresAppointments = normalizedFilters.requiresAppointments;
    final requiresSales = normalizedFilters.requiresSales;
    final requiresPackages = normalizedFilters.requiresPackages;

    final appointments =
        requiresAppointments || requiresPackages
            ? state.appointments.where((appointment) {
              if (salonId != null && appointment.salonId != salonId) {
                return false;
              }
              return true;
            }).toList(growable: false)
            : const <Appointment>[];

    final sales =
        requiresSales || requiresPackages
            ? state.sales.where((sale) {
              if (salonId != null && sale.salonId != salonId) {
                return false;
              }
              return true;
            }).toList(growable: false)
            : const <Sale>[];

    final packages =
        requiresPackages
            ? state.packages.where((pack) {
              if (salonId != null && pack.salonId != salonId) {
                return false;
              }
              return true;
            }).toList(growable: false)
            : const <ServicePackage>[];

    final services = state.services.where((service) {
      if (salonId != null && service.salonId != salonId) {
        return false;
      }
      return true;
    }).toList(growable: false);

    final indexes = _AdvancedSearchIndexes(
      now: now,
      appointments: appointments,
      sales: sales,
      services: services,
      packages: packages,
      salonId: salonId,
    );

    if (requiresAppointments) {
      filtered = filtered
          .where((client) => indexes.matchesAppointments(client, normalizedFilters))
          .toList(growable: false);
      if (filtered.isEmpty) {
        return filtered;
      }
    }

    if (requiresSales) {
      filtered = filtered
          .where((client) => indexes.matchesSales(client, normalizedFilters))
          .toList(growable: false);
      if (filtered.isEmpty) {
        return filtered;
      }
    }

    if (requiresPackages) {
      filtered = filtered
          .where((client) => indexes.matchesPackages(client, normalizedFilters))
          .toList(growable: false);
    }

    return filtered;
  }

  List<Client> _applyClientFilters(
    List<Client> clients,
    AdvancedSearchFilters filters,
    DateTime now,
  ) {
    final query = filters.generalQuery.trim().toLowerCase();
    final hasQuery = query.isNotEmpty;
    final genderFilter = filters.genders.map((value) => value.trim().toLowerCase()).toSet();
    final referralFilter =
        filters.referralSources.map((value) => value.trim().toLowerCase()).toSet();
    final cityFilter = filters.city?.trim().toLowerCase();
    final professionFilter = filters.profession?.trim().toLowerCase();
    final clientNumberExact = filters.clientNumberExact?.trim().toLowerCase();

    return clients.where((client) {
      if (filters.clientNumberExact != null) {
        final number = client.clientNumber?.trim().toLowerCase();
        if (number != clientNumberExact) {
          return false;
        }
      }

      if (filters.clientNumberFrom != null || filters.clientNumberTo != null) {
        final number = int.tryParse(client.clientNumber ?? '');
        if (number == null) {
          return false;
        }
        final from = filters.clientNumberFrom;
        final to = filters.clientNumberTo;
        if (from != null && number < from) {
          return false;
        }
        if (to != null && number > to) {
          return false;
        }
      }

      if (hasQuery && !_matchesQuery(client, query)) {
        return false;
      }

      if (filters.createdAtFrom != null || filters.createdAtTo != null) {
        final createdAt = client.createdAt;
        if (createdAt == null) {
          return false;
        }
        final from = filters.createdAtFrom;
        if (from != null && createdAt.isBefore(from)) {
          return false;
        }
        final to = filters.createdAtTo;
        if (to != null && createdAt.isAfter(to)) {
          return false;
        }
      }

      if (!_matchesAgeFilters(client, filters, now)) {
        return false;
      }

      if (!_matchesBirthdayShortcut(client, filters.birthdayShortcut, now)) {
        return false;
      }

      if (genderFilter.isNotEmpty) {
        final gender = client.gender?.trim().toLowerCase();
        if (gender == null || !genderFilter.contains(gender)) {
          return false;
        }
      }

      if (cityFilter != null && cityFilter.isNotEmpty) {
        final city = client.city?.trim().toLowerCase();
        if (city == null || !city.contains(cityFilter)) {
          return false;
        }
      }

      if (professionFilter != null && professionFilter.isNotEmpty) {
        final profession = client.profession?.trim().toLowerCase();
        if (profession == null || !profession.contains(professionFilter)) {
          return false;
        }
      }

      if (referralFilter.isNotEmpty) {
        final referral = client.referralSource?.trim().toLowerCase();
        if (referral == null || !referralFilter.contains(referral)) {
          return false;
        }
      }

      if (filters.hasEmail != null) {
        final hasEmail =
            client.email != null && client.email!.trim().isNotEmpty;
        if (hasEmail != filters.hasEmail) {
          return false;
        }
      }

      if (filters.hasPhone != null) {
        final hasPhone = client.phone.trim().isNotEmpty;
        if (hasPhone != filters.hasPhone) {
          return false;
        }
      }

      if (filters.hasNotes != null) {
        final hasNotes =
            client.notes != null && client.notes!.trim().isNotEmpty;
        if (hasNotes != filters.hasNotes) {
          return false;
        }
      }

      if (filters.onboardingStatuses.isNotEmpty &&
          !filters.onboardingStatuses.contains(client.onboardingStatus)) {
        return false;
      }

      if (filters.hasFirstLogin != null) {
        final hasFirstLogin = client.firstLoginAt != null;
        if (hasFirstLogin != filters.hasFirstLogin) {
          return false;
        }
      }

      if (filters.hasPushToken != null) {
        final hasPushTokens = client.fcmTokens.isNotEmpty;
        if (hasPushTokens != filters.hasPushToken) {
          return false;
        }
      }

      if (filters.loyaltyPointsMin != null &&
          client.loyaltyPoints < filters.loyaltyPointsMin!) {
        return false;
      }

      if (filters.loyaltyPointsMax != null &&
          client.loyaltyPoints > filters.loyaltyPointsMax!) {
        return false;
      }

      if (filters.loyaltyUpdatedSince != null) {
        final updatedAt = client.loyaltyUpdatedAt;
        if (updatedAt == null || updatedAt.isBefore(filters.loyaltyUpdatedSince!)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  bool _matchesQuery(Client client, String query) {
    bool contains(String? value) {
      if (value == null) {
        return false;
      }
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) {
        return false;
      }
      return normalized.contains(query);
    }

    return contains(client.fullName) ||
        contains(client.firstName) ||
        contains(client.lastName) ||
        contains(client.phone) ||
        contains(client.email) ||
        contains(client.city) ||
        contains(client.notes) ||
        contains(client.clientNumber);
  }

  bool _matchesAgeFilters(
    Client client,
    AdvancedSearchFilters filters,
    DateTime now,
  ) {
    if (filters.minAge == null &&
        filters.maxAge == null &&
        filters.dateOfBirthFrom == null &&
        filters.dateOfBirthTo == null) {
      return true;
    }
    final birthDate = client.dateOfBirth;
    if (birthDate == null) {
      return false;
    }

    final minAge = filters.minAge;
    final maxAge = filters.maxAge;
    if (minAge != null || maxAge != null) {
      final age = _ageInYears(birthDate, now);
      if (age == null) {
        return false;
      }
      if (minAge != null && age < minAge) {
        return false;
      }
      if (maxAge != null && age > maxAge) {
        return false;
      }
    }

    if (filters.dateOfBirthFrom != null &&
        birthDate.isBefore(filters.dateOfBirthFrom!)) {
      return false;
    }
    if (filters.dateOfBirthTo != null && birthDate.isAfter(filters.dateOfBirthTo!)) {
      return false;
    }

    return true;
  }

  bool _matchesBirthdayShortcut(
    Client client,
    AdvancedSearchBirthdayShortcut shortcut,
    DateTime now,
  ) {
    switch (shortcut) {
      case AdvancedSearchBirthdayShortcut.none:
        return true;
      case AdvancedSearchBirthdayShortcut.nextWeek:
        return _isBirthdayWithin(client, now, 7);
      case AdvancedSearchBirthdayShortcut.nextMonth:
        return _isBirthdayWithin(client, now, 30);
    }
  }

  bool _isBirthdayWithin(Client client, DateTime now, int days) {
    final birthDate = client.dateOfBirth;
    if (birthDate == null) {
      return false;
    }
    final nextBirthday = _nextBirthdayFrom(birthDate, now);
    if (nextBirthday == null) {
      return false;
    }
    final difference = nextBirthday.difference(now).inDays;
    if (difference < 0) {
      return false;
    }
    return difference <= days;
  }

  int? _ageInYears(DateTime birthDate, DateTime reference) {
    var years = reference.year - birthDate.year;
    final hasNotHadBirthdayThisYear = (reference.month < birthDate.month) ||
        (reference.month == birthDate.month && reference.day < birthDate.day);
    if (hasNotHadBirthdayThisYear) {
      years -= 1;
    }
    return years >= 0 ? years : null;
  }

  DateTime? _nextBirthdayFrom(DateTime birthDate, DateTime reference) {
    DateTime resolve(int year) {
      final safeMonth = birthDate.month;
      final lastDayOfMonth = DateTime(year, safeMonth + 1, 0).day;
      final safeDay = min(birthDate.day, lastDayOfMonth);
      return DateTime(year, safeMonth, safeDay);
    }

    var candidate = resolve(reference.year);
    if (candidate.isBefore(DateTime(reference.year, reference.month, reference.day))) {
      candidate = resolve(reference.year + 1);
    }
    return candidate;
  }
}

class _AdvancedSearchIndexes {
  _AdvancedSearchIndexes({
    required this.now,
    required List<Appointment> appointments,
    required List<Sale> sales,
    required List<Service> services,
    required List<ServicePackage> packages,
    required this.salonId,
  })  : _upcomingAppointmentsByClient = _groupUpcomingAppointments(appointments, now),
        _completedAppointmentsByClient = _groupCompletedAppointments(appointments),
        _salesByClient = _groupSales(sales),
        _serviceLookup = {for (final service in services) service.id: service},
        _packages = packages;

  final DateTime now;
  final String? salonId;
  final Map<String, List<Appointment>> _upcomingAppointmentsByClient;
  final Map<String, List<Appointment>> _completedAppointmentsByClient;
  final Map<String, List<Sale>> _salesByClient;
  final Map<String, Service> _serviceLookup;
  final List<ServicePackage> _packages;
  final Map<String, List<ClientPackagePurchase>> _packageCache =
      HashMap<String, List<ClientPackagePurchase>>();

  static Map<String, List<Appointment>> _groupUpcomingAppointments(
    List<Appointment> appointments,
    DateTime now,
  ) {
    final map = <String, List<Appointment>>{};
    for (final appointment in appointments) {
      if (appointment.status != AppointmentStatus.scheduled) {
        continue;
      }
      if (appointment.start.isBefore(now)) {
        continue;
      }
      final bucket = map.putIfAbsent(appointment.clientId, () => <Appointment>[]);
      bucket.add(appointment);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) => a.start.compareTo(b.start));
    }
    return map;
  }

  static Map<String, List<Appointment>> _groupCompletedAppointments(
    List<Appointment> appointments,
  ) {
    final map = <String, List<Appointment>>{};
    for (final appointment in appointments) {
      if (appointment.status != AppointmentStatus.completed) {
        continue;
      }
      final bucket = map.putIfAbsent(appointment.clientId, () => <Appointment>[]);
      bucket.add(appointment);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) => b.end.compareTo(a.end));
    }
    return map;
  }

  static Map<String, List<Sale>> _groupSales(List<Sale> sales) {
    final map = <String, List<Sale>>{};
    for (final sale in sales) {
      final bucket = map.putIfAbsent(sale.clientId, () => <Sale>[]);
      bucket.add(sale);
    }
    for (final entry in map.entries) {
      entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return map;
  }

  List<Appointment> _upcomingAppointmentsFor(String clientId) {
    return _upcomingAppointmentsByClient[clientId] ?? const <Appointment>[];
  }

  List<Appointment> _completedAppointmentsFor(String clientId) {
    return _completedAppointmentsByClient[clientId] ?? const <Appointment>[];
  }

  List<Sale> _salesFor(String clientId) {
    return _salesByClient[clientId] ?? const <Sale>[];
  }

  String? _serviceCategoryId(String serviceId) {
    final service = _serviceLookup[serviceId];
    return service?.categoryId;
  }

  bool matchesAppointments(Client client, AdvancedSearchFilters filters) {
    final futureAppointments = _upcomingAppointmentsFor(client.id);
    final completedAppointments = _completedAppointmentsFor(client.id);

    if (filters.upcomingAppointmentWithinDays != null ||
        filters.upcomingAppointmentServiceIds.isNotEmpty ||
        filters.upcomingAppointmentCategoryIds.isNotEmpty) {
      final withinDays = filters.upcomingAppointmentWithinDays ?? 365;
      final limit = now.add(Duration(days: withinDays));
      final matchesFuture = futureAppointments.any((appointment) {
        if (appointment.start.isAfter(limit)) {
          return false;
        }
        return _matchesAppointmentServices(
          appointment,
          filters.upcomingAppointmentServiceIds,
          filters.upcomingAppointmentCategoryIds,
        );
      });
      if (!matchesFuture) {
        return false;
      }
    }

    Iterable<Appointment> relevantCompleted = completedAppointments;
    if (filters.lastCompletedServiceIds.isNotEmpty ||
        filters.lastCompletedCategoryIds.isNotEmpty) {
      relevantCompleted = relevantCompleted.where(
        (appointment) => _matchesAppointmentServices(
          appointment,
          filters.lastCompletedServiceIds,
          filters.lastCompletedCategoryIds,
        ),
      );
    }

    if (filters.lastCompletedWithinDays != null) {
      final threshold = now.subtract(Duration(days: filters.lastCompletedWithinDays!));
      final matchesRecent = relevantCompleted.any(
        (appointment) => appointment.end.isAfter(threshold) || appointment.end.isAtSameMomentAs(threshold),
      );
      if (!matchesRecent) {
        return false;
      }
    }

    if (filters.lastCompletedOlderThanDays != null) {
      final threshold = now.subtract(Duration(days: filters.lastCompletedOlderThanDays!));
      final last = relevantCompleted.isEmpty ? null : relevantCompleted.first;
      if (last != null && !last.end.isBefore(threshold)) {
        return false;
      }
    }

    return true;
  }

  bool _matchesAppointmentServices(
    Appointment appointment,
    Set<String> serviceIds,
    Set<String> categoryIds,
  ) {
    if (serviceIds.isEmpty && categoryIds.isEmpty) {
      return true;
    }
    final services = appointment.serviceIds;
    if (services.isEmpty) {
      return false;
    }
    if (serviceIds.isNotEmpty && services.any(serviceIds.contains)) {
      if (categoryIds.isEmpty) {
        return true;
      }
      return services.any((serviceId) {
        final categoryId = _serviceCategoryId(serviceId);
        if (categoryId == null) {
          return false;
        }
        return categoryIds.contains(categoryId);
      });
    }
    if (categoryIds.isNotEmpty) {
      return services.any((serviceId) {
        final categoryId = _serviceCategoryId(serviceId);
        if (categoryId == null) {
          return false;
        }
        return categoryIds.contains(categoryId);
      });
    }
    return false;
  }

  bool matchesSales(Client client, AdvancedSearchFilters filters) {
    final sales = _salesFor(client.id);

    if (filters.onlyLastMinuteSales &&
        !sales.any((sale) {
          final source = sale.source?.toLowerCase();
          return source != null && source.contains('last-minute');
        })) {
      return false;
    }

    if (filters.totalSpentMin != null ||
        filters.totalSpentMax != null ||
        filters.totalSpentFrom != null ||
        filters.totalSpentTo != null) {
      final total = _totalSpent(
        sales,
        filters.totalSpentFrom,
        filters.totalSpentTo,
        filters.usePaidAmount,
      );
      final minAmount = filters.totalSpentMin;
      if (minAmount != null && total + 1e-6 < minAmount) {
        return false;
      }
      final maxAmount = filters.totalSpentMax;
      if (maxAmount != null && total - 1e-6 > maxAmount) {
        return false;
      }
    }

    if (filters.hasOutstandingBalance != null) {
      final hasOutstanding = sales.any((sale) => sale.outstandingAmount > 0);
      if (hasOutstanding != filters.hasOutstandingBalance) {
        return false;
      }
    }

    if (filters.lastPurchaseWithinDays != null) {
      final limit = now.subtract(Duration(days: filters.lastPurchaseWithinDays!));
      final lastSale = _lastSaleDate(sales);
      if (lastSale == null || lastSale.isBefore(limit)) {
        return false;
      }
    }

    if (filters.lastPurchaseOlderThanDays != null) {
      final limit = now.subtract(Duration(days: filters.lastPurchaseOlderThanDays!));
      final relevantSales = _filteredSalesForInclusions(sales, filters);
      final lastSale = _lastSaleDate(relevantSales);
      if (lastSale != null && !lastSale.isBefore(limit)) {
        return false;
      }
    }

    if (filters.includeSaleServiceIds.isNotEmpty ||
        filters.excludeSaleServiceIds.isNotEmpty ||
        filters.includeSaleCategoryIds.isNotEmpty ||
        filters.excludeSaleCategoryIds.isNotEmpty) {
      if (!_matchSaleItemsAgainstFilters(sales, filters)) {
        return false;
      }
    }

    return true;
  }

  double _totalSpent(
    List<Sale> sales,
    DateTime? from,
    DateTime? to,
    bool usePaidAmount,
  ) {
    if (sales.isEmpty) {
      return 0;
    }
    return sales.fold<double>(0, (sum, sale) {
      if (from != null && sale.createdAt.isBefore(from)) {
        return sum;
      }
      if (to != null && sale.createdAt.isAfter(to)) {
        return sum;
      }
      final amount = usePaidAmount ? sale.paidAmount : sale.total;
      return sum + amount;
    });
  }

  DateTime? _lastSaleDate(List<Sale> sales) {
    if (sales.isEmpty) {
      return null;
    }
    return sales.first.createdAt;
  }

  List<Sale> _filteredSalesForInclusions(
    List<Sale> sales,
    AdvancedSearchFilters filters,
  ) {
    if (filters.includeSaleServiceIds.isEmpty &&
        filters.includeSaleCategoryIds.isEmpty) {
      return sales;
    }
    return sales
        .where((sale) {
          for (final item in sale.items) {
            if (item.referenceType != SaleReferenceType.service) {
              continue;
            }
            if (filters.includeSaleServiceIds.contains(item.referenceId)) {
              return true;
            }
            final categoryId = _serviceCategoryId(item.referenceId);
            if (categoryId != null &&
                filters.includeSaleCategoryIds.contains(categoryId)) {
              return true;
            }
          }
          return false;
        })
        .toList(growable: false);
  }

  bool _matchSaleItemsAgainstFilters(
    List<Sale> sales,
    AdvancedSearchFilters filters,
  ) {
    var includesService = filters.includeSaleServiceIds.isEmpty;
    var includesCategory = filters.includeSaleCategoryIds.isEmpty;

    for (final sale in sales) {
      for (final item in sale.items) {
        if (item.referenceType != SaleReferenceType.service) {
          continue;
        }
        final serviceId = item.referenceId;
        if (!includesService &&
            filters.includeSaleServiceIds.contains(serviceId)) {
          includesService = true;
        }
        final categoryId = _serviceCategoryId(serviceId);
        if (!includesCategory &&
            categoryId != null &&
            filters.includeSaleCategoryIds.contains(categoryId)) {
          includesCategory = true;
        }
        if (filters.excludeSaleServiceIds.contains(serviceId)) {
          return false;
        }
        if (categoryId != null &&
            filters.excludeSaleCategoryIds.contains(categoryId)) {
          return false;
        }
      }
    }

    if (filters.includeSaleServiceIds.isNotEmpty && !includesService) {
      return false;
    }
    if (filters.includeSaleCategoryIds.isNotEmpty && !includesCategory) {
      return false;
    }

    return true;
  }

  bool matchesPackages(Client client, AdvancedSearchFilters filters) {
    final purchases = _packagesFor(client.id);
    if (filters.hasActivePackages != null) {
      final hasActive = purchases.any((purchase) {
        final expired =
            purchase.expirationDate != null &&
            purchase.expirationDate!.isBefore(now);
        return purchase.status == PackagePurchaseStatus.active && !expired;
      });
      if (hasActive != filters.hasActivePackages) {
        return false;
      }
    }

    if (filters.hasPackagesWithRemainingSessions != null) {
      final hasRemaining = purchases.any(
        (purchase) => purchase.remainingSessions != null
            ? purchase.remainingSessions! > 0
            : purchase.effectiveRemainingSessions > 0,
      );
      if (hasRemaining != filters.hasPackagesWithRemainingSessions) {
        return false;
      }
    }

    if (filters.hasExpiredPackages != null) {
      final hasExpired = purchases.any(
        (purchase) =>
            purchase.expirationDate != null &&
            purchase.expirationDate!.isBefore(now),
      );
      if (hasExpired != filters.hasExpiredPackages) {
        return false;
      }
    }

    return true;
  }

  List<ClientPackagePurchase> _packagesFor(String clientId) {
    return _packageCache.putIfAbsent(clientId, () {
      final clientSales = _salesFor(clientId);
      if (clientSales.isEmpty) {
        return const <ClientPackagePurchase>[];
      }
      final appointments = <Appointment>[
        ..._completedAppointmentsFor(clientId),
        ..._upcomingAppointmentsFor(clientId),
      ];
      return resolveClientPackagePurchases(
        sales: clientSales,
        packages: _packages,
        appointments: appointments,
        services: _serviceLookup.values.toList(growable: false),
        clientId: clientId,
        salonId: salonId,
      );
    });
  }
}
