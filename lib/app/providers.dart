import 'dart:async';

import 'package:you_book/app/router.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/data/repositories/auth_repository.dart';
import 'package:you_book/data/storage/firebase_storage_service.dart';
import 'package:you_book/domain/cart/cart_controller.dart';
import 'package:you_book/domain/cart/cart_models.dart';
import 'package:you_book/domain/entities/client_photo.dart';
import 'package:you_book/domain/entities/client_photo_collage.dart';
import 'package:you_book/domain/entities/client_registration_draft.dart';
import 'package:you_book/domain/entities/appointment_clipboard.dart';
import 'package:you_book/domain/entities/salon_setup_progress.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/services/payments/stripe_connect_service.dart';
import 'package:you_book/services/payments/stripe_payments_service.dart';
import 'package:you_book/services/notifications/notification_service.dart';
import 'package:you_book/services/whatsapp_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final storage =
      Firebase.apps.isNotEmpty
          ? ref.read(firebaseStorageServiceProvider)
          : null;
  final store = AppDataStore(currentUser: user, storage: storage);
  ref.listen<String?>(
    sessionControllerProvider.select((state) => state.salonId),
    (previous, next) {
      if (previous == next) {
        return;
      }
      unawaited(store.reloadActiveSalon());
    },
  );
  return store;
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
      ref.listen<AsyncValue<AppUser?>>(
        appUserProvider,
        (previous, next) {
          next.when(
            data: controller.updateUser,
            loading: () {},
            error: (_, __) => controller.updateUser(null),
          );
        },
        fireImmediately: true,
      );
      return controller;
    });

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  final storage = FirebaseStorage.instance;
  return FirebaseStorageService(storage);
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final firebaseInAppMessagingProvider = Provider<FirebaseInAppMessaging>((ref) {
  return FirebaseInAppMessaging.instance;
});

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: 'europe-west1');
});

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    return ThemeModeController();
  },
);

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

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError(
    'NotificationService non inizializzato: override notificationServiceProvider in main.dart',
  );
});

final notificationTapStreamProvider = StreamProvider<NotificationTap>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.onNotificationTap;
});

class ClientDashboardIntent {
  const ClientDashboardIntent({
    required this.tabIndex,
    Map<String, Object?>? payload,
  }) : payload = payload ?? const <String, Object?>{};

  final int tabIndex;
  final Map<String, Object?> payload;
}

class AdminDashboardIntent {
  const AdminDashboardIntent({
    required this.moduleId,
    Map<String, Object?>? payload,
  }) : payload = payload ?? const <String, Object?>{};

  final String moduleId;
  final Map<String, Object?> payload;
}

class ClientsModuleIntent {
  const ClientsModuleIntent({
    this.generalQuery,
    this.clientNumber,
    this.clientId,
  });

  final String? generalQuery;
  final String? clientNumber;
  final String? clientId;
}

final clientDashboardIntentProvider = StateProvider<ClientDashboardIntent?>(
  (ref) => null,
);

final adminDashboardIntentProvider = StateProvider<AdminDashboardIntent?>(
  (ref) => null,
);

final clientsModuleIntentProvider = StateProvider<ClientsModuleIntent?>(
  (ref) => null,
);

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

final clientPhotoCollagesProvider =
    Provider.family<List<ClientPhotoCollage>, String?>((ref, clientId) {
      final collages = ref.watch(
        appDataProvider.select((state) => state.clientPhotoCollages),
      );
      if (clientId == null || clientId.isEmpty) {
        return const <ClientPhotoCollage>[];
      }
      return collages
          .where((collage) => collage.clientId == clientId)
          .toList(growable: false);
    });

final salonSetupProgressProvider = Provider.family<AdminSetupProgress?, String>(
  (ref, salonId) {
    if (salonId.isEmpty) {
      return null;
    }
    final progressList = ref.watch(
      appDataProvider.select((state) => state.setupProgress),
    );
    for (final progress in progressList) {
      if (progress.salonId == salonId) {
        return progress;
      }
    }
    return null;
  },
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return createRouter(ref);
});

final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) {
    final paymentsService = ref.watch(stripePaymentsServiceProvider);
    return CartController(paymentsService: paymentsService);
  },
);

final clientRegistrationDraftProvider = StateNotifierProvider<
  ClientRegistrationDraftController,
  ClientRegistrationDraft?
>((ref) => ClientRegistrationDraftController());

final clientRegistrationInProgressProvider = StateProvider<bool>(
  (ref) => false,
);

final appointmentClipboardProvider = StateProvider<AppointmentClipboard?>(
  (ref) => null,
);

Future<void> performSignOut(WidgetRef ref) async {
  final router = ref.read(appRouterProvider);
  await ref.read(authRepositoryProvider).signOut();
  ref.invalidate(appDataProvider);
  ref.invalidate(appBootstrapProvider);
  ref.invalidate(appUserProvider);
  ref.read(sessionControllerProvider.notifier).updateUser(null);
  router.go('/');
}

class SessionState {
  const SessionState({this.user, this.selectedSalonId, this.selectedEntityId});

  final AppUser? user;
  final String? selectedSalonId;
  final String? selectedEntityId;

  UserRole? get role => user?.role;

  List<String> get availableSalonIds => user?.salonIds ?? const [];

  List<UserRole> get availableRoles => user?.availableRoles ?? const [];

  bool get isEmailVerified => user?.isEmailVerified ?? false;

  bool get requiresEmailVerification {
    final currentUser = user;
    if (currentUser == null) {
      return false;
    }
    if (currentUser.role != UserRole.client) {
      return false;
    }
    if (currentUser.isEmailVerified) {
      return false;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.emailVerified) {
      return false;
    }
    return true;
  }

  String? get salonId => selectedSalonId ?? user?.defaultSalonId;

  String? get userId => selectedEntityId ?? user?.linkedEntityId;

  String? get uid => user?.uid;

  bool get requiresProfile {
    final currentUser = user;
    if (currentUser == null) {
      return false;
    }
    if (currentUser.role == UserRole.client) {
      return false;
    }
    return !currentUser.isProfileComplete;
  }
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

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    unawaited(_restoreThemeMode());
  }

  static const String _prefsKey = 'client_settings_theme_mode';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _ensurePreferences() async {
    final cached = _preferences;
    if (cached != null) {
      return cached;
    }
    final resolved = await SharedPreferences.getInstance();
    _preferences = resolved;
    return resolved;
  }

  Future<void> _restoreThemeMode() async {
    try {
      final prefs = await _ensurePreferences();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final restored = _decodeThemeMode(raw) ?? ThemeMode.system;
      if (restored != state) {
        state = restored;
      }
    } catch (_) {
      // Preferenze tema opzionali: ignora errori di ripristino.
    }
  }

  Future<void> _persistThemeMode(ThemeMode mode) async {
    try {
      final prefs = await _ensurePreferences();
      await prefs.setString(_prefsKey, _encodeThemeMode(mode));
    } catch (_) {
      // Preferenze tema opzionali: ignora errori di salvataggio.
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == state) {
      return;
    }
    state = mode;
    unawaited(_persistThemeMode(mode));
  }

  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setDarkEnabled(bool enabled) {
    setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  String _encodeThemeMode(ThemeMode mode) {
    return mode.name;
  }

  ThemeMode? _decodeThemeMode(String raw) {
    for (final mode in ThemeMode.values) {
      if (mode.name == raw || mode.toString() == raw) {
        return mode;
      }
    }
    return null;
  }
}

class ClientRegistrationDraftController
    extends StateNotifier<ClientRegistrationDraft?> {
  ClientRegistrationDraftController() : super(null);

  void save(ClientRegistrationDraft draft) {
    state = draft;
  }

  void clear() {
    state = null;
  }
}
