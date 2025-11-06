import 'package:you_book/domain/entities/client.dart';

enum AdvancedSearchBirthdayShortcut {
  none,
  nextWeek,
  nextMonth,
}

class AdvancedSearchFilters {
  const AdvancedSearchFilters({
    this.salonId,
    this.generalQuery = '',
    this.clientNumberExact,
    this.clientNumberFrom,
    this.clientNumberTo,
    this.createdAtFrom,
    this.createdAtTo,
    this.minAge,
    this.maxAge,
    this.dateOfBirthFrom,
    this.dateOfBirthTo,
    this.birthdayShortcut = AdvancedSearchBirthdayShortcut.none,
    this.genders = const <String>{},
    this.city,
    this.profession,
    this.referralSources = const <String>{},
    this.hasEmail,
    this.hasPhone,
    this.hasNotes,
    this.onboardingStatuses = const <ClientOnboardingStatus>{},
    this.hasFirstLogin,
    this.hasPushToken,
    this.loyaltyPointsMin,
    this.loyaltyPointsMax,
    this.loyaltyUpdatedSince,
    this.totalSpentMin,
    this.totalSpentMax,
    this.totalSpentFrom,
    this.totalSpentTo,
    this.usePaidAmount = false,
    this.hasOutstandingBalance,
    this.lastPurchaseWithinDays,
    this.lastPurchaseOlderThanDays,
    this.includeSaleServiceIds = const <String>{},
    this.excludeSaleServiceIds = const <String>{},
    this.includeSaleCategoryIds = const <String>{},
    this.excludeSaleCategoryIds = const <String>{},
    this.onlyLastMinuteSales = false,
    this.upcomingAppointmentWithinDays,
    this.upcomingAppointmentServiceIds = const <String>{},
    this.upcomingAppointmentCategoryIds = const <String>{},
    this.lastCompletedWithinDays,
    this.lastCompletedOlderThanDays,
    this.lastCompletedServiceIds = const <String>{},
    this.lastCompletedCategoryIds = const <String>{},
    this.hasActivePackages,
    this.hasPackagesWithRemainingSessions,
    this.hasExpiredPackages,
  });

  final String? salonId;
  final String generalQuery;
  final String? clientNumberExact;
  final int? clientNumberFrom;
  final int? clientNumberTo;
  final DateTime? createdAtFrom;
  final DateTime? createdAtTo;
  final int? minAge;
  final int? maxAge;
  final DateTime? dateOfBirthFrom;
  final DateTime? dateOfBirthTo;
  final AdvancedSearchBirthdayShortcut birthdayShortcut;
  final Set<String> genders;
  final String? city;
  final String? profession;
  final Set<String> referralSources;
  final bool? hasEmail;
  final bool? hasPhone;
  final bool? hasNotes;
  final Set<ClientOnboardingStatus> onboardingStatuses;
  final bool? hasFirstLogin;
  final bool? hasPushToken;
  final int? loyaltyPointsMin;
  final int? loyaltyPointsMax;
  final DateTime? loyaltyUpdatedSince;
  final double? totalSpentMin;
  final double? totalSpentMax;
  final DateTime? totalSpentFrom;
  final DateTime? totalSpentTo;
  final bool usePaidAmount;
  final bool? hasOutstandingBalance;
  final int? lastPurchaseWithinDays;
  final int? lastPurchaseOlderThanDays;
  final Set<String> includeSaleServiceIds;
  final Set<String> excludeSaleServiceIds;
  final Set<String> includeSaleCategoryIds;
  final Set<String> excludeSaleCategoryIds;
  final bool onlyLastMinuteSales;
  final int? upcomingAppointmentWithinDays;
  final Set<String> upcomingAppointmentServiceIds;
  final Set<String> upcomingAppointmentCategoryIds;
  final int? lastCompletedWithinDays;
  final int? lastCompletedOlderThanDays;
  final Set<String> lastCompletedServiceIds;
  final Set<String> lastCompletedCategoryIds;
  final bool? hasActivePackages;
  final bool? hasPackagesWithRemainingSessions;
  final bool? hasExpiredPackages;

  AdvancedSearchFilters copyWith({
    String? salonId,
    String? generalQuery,
    Object? clientNumberExact = _unset,
    Object? clientNumberFrom = _unset,
    Object? clientNumberTo = _unset,
    Object? createdAtFrom = _unset,
    Object? createdAtTo = _unset,
    Object? minAge = _unset,
    Object? maxAge = _unset,
    Object? dateOfBirthFrom = _unset,
    Object? dateOfBirthTo = _unset,
    AdvancedSearchBirthdayShortcut? birthdayShortcut,
    Set<String>? genders,
    Object? city = _unset,
    Object? profession = _unset,
    Set<String>? referralSources,
    Object? hasEmail = _unset,
    Object? hasPhone = _unset,
    Object? hasNotes = _unset,
    Set<ClientOnboardingStatus>? onboardingStatuses,
    Object? hasFirstLogin = _unset,
    Object? hasPushToken = _unset,
    Object? loyaltyPointsMin = _unset,
    Object? loyaltyPointsMax = _unset,
    Object? loyaltyUpdatedSince = _unset,
    Object? totalSpentMin = _unset,
    Object? totalSpentMax = _unset,
    Object? totalSpentFrom = _unset,
    Object? totalSpentTo = _unset,
    bool? usePaidAmount,
    Object? hasOutstandingBalance = _unset,
    Object? lastPurchaseWithinDays = _unset,
    Object? lastPurchaseOlderThanDays = _unset,
    Set<String>? includeSaleServiceIds,
    Set<String>? excludeSaleServiceIds,
    Set<String>? includeSaleCategoryIds,
    Set<String>? excludeSaleCategoryIds,
    bool? onlyLastMinuteSales,
    Object? upcomingAppointmentWithinDays = _unset,
    Set<String>? upcomingAppointmentServiceIds,
    Set<String>? upcomingAppointmentCategoryIds,
    Object? lastCompletedWithinDays = _unset,
    Object? lastCompletedOlderThanDays = _unset,
    Set<String>? lastCompletedServiceIds,
    Set<String>? lastCompletedCategoryIds,
    Object? hasActivePackages = _unset,
    Object? hasPackagesWithRemainingSessions = _unset,
    Object? hasExpiredPackages = _unset,
  }) {
    return AdvancedSearchFilters(
      salonId: salonId ?? this.salonId,
      generalQuery: generalQuery ?? this.generalQuery,
      clientNumberExact:
          clientNumberExact == _unset
              ? this.clientNumberExact
              : clientNumberExact as String?,
      clientNumberFrom:
          clientNumberFrom == _unset
              ? this.clientNumberFrom
              : clientNumberFrom as int?,
      clientNumberTo:
          clientNumberTo == _unset ? this.clientNumberTo : clientNumberTo as int?,
      createdAtFrom:
          createdAtFrom == _unset
              ? this.createdAtFrom
              : createdAtFrom as DateTime?,
      createdAtTo:
          createdAtTo == _unset ? this.createdAtTo : createdAtTo as DateTime?,
      minAge: minAge == _unset ? this.minAge : minAge as int?,
      maxAge: maxAge == _unset ? this.maxAge : maxAge as int?,
      dateOfBirthFrom:
          dateOfBirthFrom == _unset
              ? this.dateOfBirthFrom
              : dateOfBirthFrom as DateTime?,
      dateOfBirthTo:
          dateOfBirthTo == _unset
              ? this.dateOfBirthTo
              : dateOfBirthTo as DateTime?,
      birthdayShortcut: birthdayShortcut ?? this.birthdayShortcut,
      genders: genders ?? this.genders,
      city: city == _unset ? this.city : city as String?,
      profession:
          profession == _unset ? this.profession : profession as String?,
      referralSources: referralSources ?? this.referralSources,
      hasEmail:
          hasEmail == _unset ? this.hasEmail : hasEmail as bool?,
      hasPhone:
          hasPhone == _unset ? this.hasPhone : hasPhone as bool?,
      hasNotes:
          hasNotes == _unset ? this.hasNotes : hasNotes as bool?,
      onboardingStatuses: onboardingStatuses ?? this.onboardingStatuses,
      hasFirstLogin:
          hasFirstLogin == _unset ? this.hasFirstLogin : hasFirstLogin as bool?,
      hasPushToken:
          hasPushToken == _unset ? this.hasPushToken : hasPushToken as bool?,
      loyaltyPointsMin:
          loyaltyPointsMin == _unset
              ? this.loyaltyPointsMin
              : loyaltyPointsMin as int?,
      loyaltyPointsMax:
          loyaltyPointsMax == _unset
              ? this.loyaltyPointsMax
              : loyaltyPointsMax as int?,
      loyaltyUpdatedSince:
          loyaltyUpdatedSince == _unset
              ? this.loyaltyUpdatedSince
              : loyaltyUpdatedSince as DateTime?,
      totalSpentMin:
          totalSpentMin == _unset
              ? this.totalSpentMin
              : totalSpentMin as double?,
      totalSpentMax:
          totalSpentMax == _unset
              ? this.totalSpentMax
              : totalSpentMax as double?,
      totalSpentFrom:
          totalSpentFrom == _unset
              ? this.totalSpentFrom
              : totalSpentFrom as DateTime?,
      totalSpentTo:
          totalSpentTo == _unset
              ? this.totalSpentTo
              : totalSpentTo as DateTime?,
      usePaidAmount: usePaidAmount ?? this.usePaidAmount,
      hasOutstandingBalance:
          hasOutstandingBalance == _unset
              ? this.hasOutstandingBalance
              : hasOutstandingBalance as bool?,
      lastPurchaseWithinDays:
          lastPurchaseWithinDays == _unset
              ? this.lastPurchaseWithinDays
              : lastPurchaseWithinDays as int?,
      lastPurchaseOlderThanDays:
          lastPurchaseOlderThanDays == _unset
              ? this.lastPurchaseOlderThanDays
              : lastPurchaseOlderThanDays as int?,
      includeSaleServiceIds:
          includeSaleServiceIds ?? this.includeSaleServiceIds,
      excludeSaleServiceIds:
          excludeSaleServiceIds ?? this.excludeSaleServiceIds,
      includeSaleCategoryIds:
          includeSaleCategoryIds ?? this.includeSaleCategoryIds,
      excludeSaleCategoryIds:
          excludeSaleCategoryIds ?? this.excludeSaleCategoryIds,
      onlyLastMinuteSales: onlyLastMinuteSales ?? this.onlyLastMinuteSales,
      upcomingAppointmentWithinDays:
          upcomingAppointmentWithinDays == _unset
              ? this.upcomingAppointmentWithinDays
              : upcomingAppointmentWithinDays as int?,
      upcomingAppointmentServiceIds:
          upcomingAppointmentServiceIds ?? this.upcomingAppointmentServiceIds,
      upcomingAppointmentCategoryIds:
          upcomingAppointmentCategoryIds ?? this.upcomingAppointmentCategoryIds,
      lastCompletedWithinDays:
          lastCompletedWithinDays == _unset
              ? this.lastCompletedWithinDays
              : lastCompletedWithinDays as int?,
      lastCompletedOlderThanDays:
          lastCompletedOlderThanDays == _unset
              ? this.lastCompletedOlderThanDays
              : lastCompletedOlderThanDays as int?,
      lastCompletedServiceIds:
          lastCompletedServiceIds ?? this.lastCompletedServiceIds,
      lastCompletedCategoryIds:
          lastCompletedCategoryIds ?? this.lastCompletedCategoryIds,
      hasActivePackages:
          hasActivePackages == _unset
              ? this.hasActivePackages
              : hasActivePackages as bool?,
      hasPackagesWithRemainingSessions:
          hasPackagesWithRemainingSessions == _unset
              ? this.hasPackagesWithRemainingSessions
              : hasPackagesWithRemainingSessions as bool?,
      hasExpiredPackages:
          hasExpiredPackages == _unset
              ? this.hasExpiredPackages
              : hasExpiredPackages as bool?,
    );
  }

  bool get hasAnyFilter {
    return generalQuery.trim().isNotEmpty ||
        clientNumberExact != null ||
        clientNumberFrom != null ||
        clientNumberTo != null ||
        createdAtFrom != null ||
        createdAtTo != null ||
        minAge != null ||
        maxAge != null ||
        dateOfBirthFrom != null ||
        dateOfBirthTo != null ||
        birthdayShortcut != AdvancedSearchBirthdayShortcut.none ||
        genders.isNotEmpty ||
        (city != null && city!.trim().isNotEmpty) ||
        (profession != null && profession!.trim().isNotEmpty) ||
        referralSources.isNotEmpty ||
        hasEmail != null ||
        hasPhone != null ||
        hasNotes != null ||
        onboardingStatuses.isNotEmpty ||
        hasFirstLogin != null ||
        hasPushToken != null ||
        loyaltyPointsMin != null ||
        loyaltyPointsMax != null ||
        loyaltyUpdatedSince != null ||
        totalSpentMin != null ||
        totalSpentMax != null ||
        totalSpentFrom != null ||
        totalSpentTo != null ||
        hasOutstandingBalance != null ||
        lastPurchaseWithinDays != null ||
        lastPurchaseOlderThanDays != null ||
        includeSaleServiceIds.isNotEmpty ||
        excludeSaleServiceIds.isNotEmpty ||
        includeSaleCategoryIds.isNotEmpty ||
        excludeSaleCategoryIds.isNotEmpty ||
        onlyLastMinuteSales ||
        upcomingAppointmentWithinDays != null ||
        upcomingAppointmentServiceIds.isNotEmpty ||
        upcomingAppointmentCategoryIds.isNotEmpty ||
        lastCompletedWithinDays != null ||
        lastCompletedOlderThanDays != null ||
        lastCompletedServiceIds.isNotEmpty ||
        lastCompletedCategoryIds.isNotEmpty ||
        hasActivePackages != null ||
        hasPackagesWithRemainingSessions != null ||
        hasExpiredPackages != null;
  }

  bool get requiresAppointments {
    return upcomingAppointmentWithinDays != null ||
        upcomingAppointmentServiceIds.isNotEmpty ||
        upcomingAppointmentCategoryIds.isNotEmpty ||
        lastCompletedWithinDays != null ||
        lastCompletedOlderThanDays != null ||
        lastCompletedServiceIds.isNotEmpty ||
        lastCompletedCategoryIds.isNotEmpty;
  }

  bool get requiresSales {
    return totalSpentMin != null ||
        totalSpentMax != null ||
        totalSpentFrom != null ||
        totalSpentTo != null ||
        hasOutstandingBalance != null ||
        lastPurchaseWithinDays != null ||
        lastPurchaseOlderThanDays != null ||
        includeSaleServiceIds.isNotEmpty ||
        excludeSaleServiceIds.isNotEmpty ||
        includeSaleCategoryIds.isNotEmpty ||
        excludeSaleCategoryIds.isNotEmpty ||
        onlyLastMinuteSales ||
        hasActivePackages == true ||
        hasPackagesWithRemainingSessions == true ||
        hasExpiredPackages == true;
  }

  bool get requiresPackages {
    return hasActivePackages != null ||
        hasPackagesWithRemainingSessions != null ||
        hasExpiredPackages != null;
  }
}

const Object _unset = Object();
