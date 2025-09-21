import 'package:civiapp/app/router.dart';
import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/data/repositories/app_data_store.dart';
import 'package:civiapp/data/repositories/auth_repository.dart';
import 'package:civiapp/domain/entities/user_role.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return createRouter(ref);
});

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
