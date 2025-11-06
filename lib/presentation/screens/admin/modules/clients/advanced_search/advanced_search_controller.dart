import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_engine.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_filters.dart';

class AdvancedClientSearchState {
  const AdvancedClientSearchState({
    required this.filters,
    required this.results,
    required this.hasSearched,
    required this.isApplying,
    this.error,
  });

  factory AdvancedClientSearchState.initial({String? salonId}) {
    return AdvancedClientSearchState(
      filters: AdvancedSearchFilters(salonId: salonId),
      results: const <Client>[],
      hasSearched: false,
      isApplying: false,
      error: null,
    );
  }

  final AdvancedSearchFilters filters;
  final List<Client> results;
  final bool hasSearched;
  final bool isApplying;
  final String? error;

  AdvancedClientSearchState copyWith({
    AdvancedSearchFilters? filters,
    List<Client>? results,
    bool? hasSearched,
    bool? isApplying,
    Object? error = _sentinel,
  }) {
    return AdvancedClientSearchState(
      filters: filters ?? this.filters,
      results: results ?? this.results,
      hasSearched: hasSearched ?? this.hasSearched,
      isApplying: isApplying ?? this.isApplying,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}

class AdvancedClientSearchController
    extends StateNotifier<AdvancedClientSearchState> {
  AdvancedClientSearchController(this.ref, {this.salonId})
      : super(AdvancedClientSearchState.initial(salonId: salonId));

  final Ref ref;
  final String? salonId;

  void updateFilters(AdvancedSearchFilters filters, {bool autoApply = true}) {
    final normalized =
        salonId != null ? filters.copyWith(salonId: salonId) : filters;
    state = state.copyWith(filters: normalized);
    if (state.hasSearched && autoApply) {
      _applyFilters(autoTriggered: true);
    }
  }

  void updateFilter(void Function(AdvancedSearchFiltersBuilder builder) fn) {
    final builder = AdvancedSearchFiltersBuilder.from(state.filters);
    fn(builder);
    updateFilters(builder.build());
  }

  void apply() {
    _applyFilters(autoTriggered: false);
  }

  void clear() {
    state = AdvancedClientSearchState.initial(salonId: salonId);
  }

  void _applyFilters({required bool autoTriggered}) {
    final filters = state.filters;
    final data = ref.read(appDataProvider);
    final engine = AdvancedSearchEngine(
      state: data,
      now: DateTime.now(),
      defaultSalonId: salonId,
    );

    state = state.copyWith(isApplying: true, error: null);
    try {
      final results = engine.apply(filters);
      state = state.copyWith(
        isApplying: false,
        results: results,
        hasSearched: true,
        error: null,
      );
    } catch (error, stack) {
      state = state.copyWith(
        isApplying: false,
        error: error.toString(),
        hasSearched: autoTriggered ? state.hasSearched : true,
      );
      // ignore: avoid_print
      print('Advanced search failed: $error\n$stack');
    }
  }
}

final advancedClientSearchControllerProvider =
    StateNotifierProvider.autoDispose
        .family<AdvancedClientSearchController, AdvancedClientSearchState, String?>(
  (ref, salonId) {
    final controller = AdvancedClientSearchController(ref, salonId: salonId);
    ref.listen<AppDataState>(
      appDataProvider,
      (previous, next) {
        if (controller.mounted && controller.state.hasSearched) {
          controller.apply();
        }
      },
      fireImmediately: false,
    );
    return controller;
  },
);

typedef AdvancedSearchFiltersBuilderCallback = void Function(
  AdvancedSearchFiltersBuilder builder,
);

class AdvancedSearchFiltersBuilder {
  AdvancedSearchFiltersBuilder.from(AdvancedSearchFilters filters)
      : salonId = filters.salonId,
        generalQuery = filters.generalQuery,
        clientNumberExact = filters.clientNumberExact,
        clientNumberFrom = filters.clientNumberFrom,
        clientNumberTo = filters.clientNumberTo,
        createdAtFrom = filters.createdAtFrom,
        createdAtTo = filters.createdAtTo,
        minAge = filters.minAge,
        maxAge = filters.maxAge,
        dateOfBirthFrom = filters.dateOfBirthFrom,
        dateOfBirthTo = filters.dateOfBirthTo,
        birthdayShortcut = filters.birthdayShortcut,
        genders = Set<String>.from(filters.genders),
        city = filters.city,
        profession = filters.profession,
        referralSources = Set<String>.from(filters.referralSources),
        hasEmail = filters.hasEmail,
        hasPhone = filters.hasPhone,
        hasNotes = filters.hasNotes,
        onboardingStatuses = Set<ClientOnboardingStatus>.from(
          filters.onboardingStatuses,
        ),
        hasFirstLogin = filters.hasFirstLogin,
        hasPushToken = filters.hasPushToken,
        loyaltyPointsMin = filters.loyaltyPointsMin,
        loyaltyPointsMax = filters.loyaltyPointsMax,
        loyaltyUpdatedSince = filters.loyaltyUpdatedSince,
        totalSpentMin = filters.totalSpentMin,
        totalSpentMax = filters.totalSpentMax,
        totalSpentFrom = filters.totalSpentFrom,
        totalSpentTo = filters.totalSpentTo,
        usePaidAmount = filters.usePaidAmount,
        hasOutstandingBalance = filters.hasOutstandingBalance,
        lastPurchaseWithinDays = filters.lastPurchaseWithinDays,
        lastPurchaseOlderThanDays = filters.lastPurchaseOlderThanDays,
        includeSaleServiceIds = Set<String>.from(filters.includeSaleServiceIds),
        excludeSaleServiceIds = Set<String>.from(filters.excludeSaleServiceIds),
        includeSaleCategoryIds = Set<String>.from(filters.includeSaleCategoryIds),
        excludeSaleCategoryIds = Set<String>.from(filters.excludeSaleCategoryIds),
        onlyLastMinuteSales = filters.onlyLastMinuteSales,
        upcomingAppointmentWithinDays = filters.upcomingAppointmentWithinDays,
        upcomingAppointmentServiceIds = Set<String>.from(
          filters.upcomingAppointmentServiceIds,
        ),
        upcomingAppointmentCategoryIds = Set<String>.from(
          filters.upcomingAppointmentCategoryIds,
        ),
        lastCompletedWithinDays = filters.lastCompletedWithinDays,
        lastCompletedOlderThanDays = filters.lastCompletedOlderThanDays,
        lastCompletedServiceIds = Set<String>.from(filters.lastCompletedServiceIds),
        lastCompletedCategoryIds = Set<String>.from(
          filters.lastCompletedCategoryIds,
        ),
        hasActivePackages = filters.hasActivePackages,
        hasPackagesWithRemainingSessions = filters.hasPackagesWithRemainingSessions,
        hasExpiredPackages = filters.hasExpiredPackages;

  String? salonId;
  String generalQuery;
  String? clientNumberExact;
  int? clientNumberFrom;
  int? clientNumberTo;
  DateTime? createdAtFrom;
  DateTime? createdAtTo;
  int? minAge;
  int? maxAge;
  DateTime? dateOfBirthFrom;
  DateTime? dateOfBirthTo;
  AdvancedSearchBirthdayShortcut birthdayShortcut;
  Set<String> genders;
  String? city;
  String? profession;
  Set<String> referralSources;
  bool? hasEmail;
  bool? hasPhone;
  bool? hasNotes;
  Set<ClientOnboardingStatus> onboardingStatuses;
  bool? hasFirstLogin;
  bool? hasPushToken;
  int? loyaltyPointsMin;
  int? loyaltyPointsMax;
  DateTime? loyaltyUpdatedSince;
  double? totalSpentMin;
  double? totalSpentMax;
  DateTime? totalSpentFrom;
  DateTime? totalSpentTo;
  bool usePaidAmount;
  bool? hasOutstandingBalance;
  int? lastPurchaseWithinDays;
  int? lastPurchaseOlderThanDays;
  Set<String> includeSaleServiceIds;
  Set<String> excludeSaleServiceIds;
  Set<String> includeSaleCategoryIds;
  Set<String> excludeSaleCategoryIds;
  bool onlyLastMinuteSales;
  int? upcomingAppointmentWithinDays;
  Set<String> upcomingAppointmentServiceIds;
  Set<String> upcomingAppointmentCategoryIds;
  int? lastCompletedWithinDays;
  int? lastCompletedOlderThanDays;
  Set<String> lastCompletedServiceIds;
  Set<String> lastCompletedCategoryIds;
  bool? hasActivePackages;
  bool? hasPackagesWithRemainingSessions;
  bool? hasExpiredPackages;

  AdvancedSearchFilters build() {
    return AdvancedSearchFilters(
      salonId: salonId,
      generalQuery: generalQuery,
      clientNumberExact: clientNumberExact,
      clientNumberFrom: clientNumberFrom,
      clientNumberTo: clientNumberTo,
      createdAtFrom: createdAtFrom,
      createdAtTo: createdAtTo,
      minAge: minAge,
      maxAge: maxAge,
      dateOfBirthFrom: dateOfBirthFrom,
      dateOfBirthTo: dateOfBirthTo,
      birthdayShortcut: birthdayShortcut,
      genders: genders,
      city: city,
      profession: profession,
      referralSources: referralSources,
      hasEmail: hasEmail,
      hasPhone: hasPhone,
      hasNotes: hasNotes,
      onboardingStatuses: onboardingStatuses,
      hasFirstLogin: hasFirstLogin,
      hasPushToken: hasPushToken,
      loyaltyPointsMin: loyaltyPointsMin,
      loyaltyPointsMax: loyaltyPointsMax,
      loyaltyUpdatedSince: loyaltyUpdatedSince,
      totalSpentMin: totalSpentMin,
      totalSpentMax: totalSpentMax,
      totalSpentFrom: totalSpentFrom,
      totalSpentTo: totalSpentTo,
      usePaidAmount: usePaidAmount,
      hasOutstandingBalance: hasOutstandingBalance,
      lastPurchaseWithinDays: lastPurchaseWithinDays,
      lastPurchaseOlderThanDays: lastPurchaseOlderThanDays,
      includeSaleServiceIds: includeSaleServiceIds,
      excludeSaleServiceIds: excludeSaleServiceIds,
      includeSaleCategoryIds: includeSaleCategoryIds,
      excludeSaleCategoryIds: excludeSaleCategoryIds,
      onlyLastMinuteSales: onlyLastMinuteSales,
      upcomingAppointmentWithinDays: upcomingAppointmentWithinDays,
      upcomingAppointmentServiceIds: upcomingAppointmentServiceIds,
      upcomingAppointmentCategoryIds: upcomingAppointmentCategoryIds,
      lastCompletedWithinDays: lastCompletedWithinDays,
      lastCompletedOlderThanDays: lastCompletedOlderThanDays,
      lastCompletedServiceIds: lastCompletedServiceIds,
      lastCompletedCategoryIds: lastCompletedCategoryIds,
      hasActivePackages: hasActivePackages,
      hasPackagesWithRemainingSessions: hasPackagesWithRemainingSessions,
      hasExpiredPackages: hasExpiredPackages,
    );
  }
}
