import 'package:civiapp/app/router.dart';
import 'package:civiapp/data/branding/branding_model.dart';
import 'package:civiapp/data/branding/branding_repository.dart';
import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/data/repositories/app_data_store.dart';
import 'package:civiapp/data/repositories/auth_repository.dart';
import 'package:civiapp/data/storage/firebase_storage_service.dart';
import 'package:civiapp/domain/cart/cart_controller.dart';
import 'package:civiapp/domain/cart/cart_models.dart';
import 'package:civiapp/domain/entities/client_photo.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:civiapp/services/payments/stripe_payments_service.dart';
import 'package:civiapp/services/payments/stripe_connect_service.dart';
import 'package:civiapp/services/whatsapp_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appDataProvider = StateNotifierProvider<AppDataStore, AppDataState>((
  ref,
) {
  final sessionUser = ref.watch(
    sessionControllerProvider.select((state) => state.user),
  );
  final appUser = ref.watch(appUserProvider);
  final fallbackUser = appUser.maybeWhen(
    data: (data) => data,
    orElse: () => null,
  );
  final user = sessionUser ?? fallbackUser;
  return AppDataStore(currentUser: user);
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(appDataProvider.notifier).seedWithMockDataIfEmpty();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final appUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      final controller = SessionController();
      ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
        controller.updateUser(next.value);
      }, fireImmediately: true);
      return controller;
    });

final brandingRepositoryProvider = Provider<BrandingRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return BrandingRepository(firestore);
});

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  final storage = FirebaseStorage.instance;
  return FirebaseStorageService(storage);
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final currentSalonIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionControllerProvider).salonId;
});

final whatsappServiceProvider = Provider<WhatsAppService>((ref) {
  final service = WhatsAppService();
  ref.onDispose(service.dispose);
  return service;
});

final stripePaymentsServiceProvider = Provider<StripePaymentsService>((ref) {
  return StripePaymentsService();
});

final stripeConnectServiceProvider = Provider<StripeConnectService>((ref) {
  return StripeConnectService();
});

final whatsappConfigProvider = StreamProvider.family<WhatsAppConfig?, String>((
  ref,
  salonId,
) {
  final service = ref.watch(whatsappServiceProvider);
  return service.watchConfig(salonId);
});

final salonBrandingProvider = StreamProvider<BrandingModel>((ref) {
  final salonId = ref.watch(currentSalonIdProvider);
  final repository = ref.watch(brandingRepositoryProvider);
  if (salonId == null) {
    return Stream.value(
      const BrandingModel(
        primaryColor: '#1F2937',
        accentColor: '#A855F7',
        themeMode: 'system',
      ),
    );
  }
  return repository.watchSalonBranding(salonId);
});

final salonThemeProvider = Provider.autoDispose((ref) {
  final brandingAsync = ref.watch(salonBrandingProvider);
  final base =
      brandingAsync.valueOrNull ??
      const BrandingModel(
        primaryColor: '#1F2937',
        accentColor: '#A855F7',
        themeMode: 'system',
      );
  final lightScheme = base.toColorScheme(Brightness.light);
  final darkScheme = base.toColorScheme(Brightness.dark);

  ThemeData buildTheme(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: base.appBarStyle == 'elevated' ? 4 : 0,
      ),
    );
  }

  return (
    theme: buildTheme(lightScheme),
    darkTheme: buildTheme(darkScheme),
    mode: base.resolveThemeMode(),
    branding: base,
  );
});

final clientPhotosProvider = Provider.family<List<ClientPhoto>, String?>((
  ref,
  clientId,
) {
  final photos = ref.watch(
    appDataProvider.select((state) => state.clientPhotos),
  );
  if (clientId == null || clientId.isEmpty) {
    return const <ClientPhoto>[];
  }
  return photos
      .where((photo) => photo.clientId == clientId)
      .toList(growable: false);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  return createRouter(ref);
});

final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) {
    final paymentsService = ref.watch(stripePaymentsServiceProvider);
    return CartController(paymentsService: paymentsService);
  },
);

class SessionState {
  const SessionState({this.user, this.selectedSalonId, this.selectedEntityId});

  final AppUser? user;
  final String? selectedSalonId;
  final String? selectedEntityId;

  UserRole? get role => user?.role;

  List<String> get availableSalonIds => user?.salonIds ?? const [];

  List<UserRole> get availableRoles => user?.availableRoles ?? const [];

  String? get salonId => selectedSalonId ?? user?.defaultSalonId;

  String? get userId => selectedEntityId ?? user?.linkedEntityId;

  String? get uid => user?.uid;

  bool get requiresProfile => user != null && !(user!.isProfileComplete);
}

class SessionController extends StateNotifier<SessionState> {
  SessionController() : super(const SessionState());

  void updateUser(AppUser? user) {
    if (user == null) {
      state = const SessionState();
      return;
    }

    var selectedSalon = state.selectedSalonId;
    if (selectedSalon == null || !user.salonIds.contains(selectedSalon)) {
      selectedSalon = user.defaultSalonId;
    }

    var selectedEntity = state.selectedEntityId;
    if (selectedEntity == null || state.user?.uid != user.uid) {
      selectedEntity = user.linkedEntityId;
    }

    state = SessionState(
      user: user,
      selectedSalonId: selectedSalon,
      selectedEntityId: selectedEntity,
    );
  }

  void setSalon(String? salonId) {
    state = SessionState(
      user: state.user,
      selectedSalonId: salonId,
      selectedEntityId: state.selectedEntityId,
    );
  }

  void setUser(String? userId) {
    state = SessionState(
      user: state.user,
      selectedSalonId: state.selectedSalonId,
      selectedEntityId: userId,
    );
  }
}
