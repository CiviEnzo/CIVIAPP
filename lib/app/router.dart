import 'dart:async';

import 'package:you_book/app/providers.dart';
import 'package:you_book/app/router_constants.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:you_book/presentation/screens/auth/account_deletion_screen.dart';
import 'package:you_book/presentation/screens/auth/center_registration_screen.dart';
import 'package:you_book/presentation/screens/auth/client_registration_screen.dart';
import 'package:you_book/presentation/screens/auth/first_password_change_screen.dart';
import 'package:you_book/presentation/screens/auth/onboarding_screen.dart';
import 'package:you_book/presentation/screens/auth/password_reset_screen.dart';
import 'package:you_book/presentation/screens/auth/sign_in_screen.dart';
import 'package:you_book/presentation/screens/client/client_dashboard_screen.dart';
import 'package:you_book/presentation/screens/client/client_salon_discovery_screen.dart';
import 'package:you_book/presentation/screens/staff/staff_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter(Ref ref) {
  final sessionNotifier = ref.read(sessionControllerProvider.notifier);
  final refreshNotifier = _RouterRefreshNotifier(sessionNotifier.stream);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    routes: [
      GoRoute(
        path: '/',
        name: 'sign_in',
        builder: (context, state) {
          final noticeMessage = state.uri.queryParameters[noticeQueryParam];
          final redirectPath = state.uri.queryParameters[redirectQueryParam];
          final showVerificationNotice =
              state.uri.queryParameters[verifyEmailQueryParam] == '1';
          const verificationMessage =
              'Registrazione completata. Controlla la tua email e conferma l\'indirizzo prima di accedere.';
          final message =
              noticeMessage ??
              (showVerificationNotice ? verificationMessage : null);
          return SignInScreen(notice: message, redirectPath: redirectPath);
        },
      ),
      GoRoute(
        path: '/register',
        name: 'client_register',
        builder: (context, state) => const ClientRegistrationScreen(),
      ),
      GoRoute(
        path: '/register-center',
        name: 'center_register',
        builder: (context, state) => const CenterRegistrationScreen(),
      ),
      GoRoute(
        path: '/password-reset',
        name: 'password_reset',
        builder:
            (context, state) => PasswordResetScreen(
              initialEmail: state.uri.queryParameters['email'],
            ),
      ),
      GoRoute(
        path: '/first-password-change',
        name: 'first_password_change',
        builder: (context, state) => const FirstPasswordChangeScreen(),
      ),
      GoRoute(
        path: '/eliminazione-account',
        name: 'account_deletion',
        builder: (context, state) => const AccountDeletionScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin_dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/staff',
        name: 'staff_dashboard',
        builder: (context, state) => const StaffDashboardScreen(),
      ),
      GoRoute(
        path: '/client',
        name: 'client_salons',
        builder: (context, state) => const ClientSalonDiscoveryScreen(),
      ),
      GoRoute(
        path: '/client/dashboard',
        name: 'client_dashboard',
        builder: (context, state) => const ClientDashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final registrationInProgress = ref.read(
        clientRegistrationInProgressProvider,
      );
      final centerRegistrationInProgress = ref.read(
        centerRegistrationInProgressProvider,
      );
      final isAuthenticated = session.user != null;
      final loggingIn = state.matchedLocation == '/';
      final registering = state.matchedLocation == '/register';
      final registeringCenter = state.matchedLocation == '/register-center';
      final resettingPassword = state.matchedLocation == '/password-reset';
      final changingPassword =
          state.matchedLocation == '/first-password-change';
      final deletingAccount = state.matchedLocation == '/eliminazione-account';
      final browsingClientSalons = state.matchedLocation == '/client';
      final onboarding = state.matchedLocation == '/onboarding';
      final requiresProfile = session.requiresProfile;
      final requiresEmailVerification = session.requiresEmailVerification;
      final requiresPasswordChange = session.requiresPasswordChange;
      final selectedSalonId = session.salonId;
      final hasClientProfile = session.user?.clientId != null;
      final isAdminDisabled =
          session.role == UserRole.admin && session.user?.isEnabled == false;
      final canEnterClientDashboard =
          session.role == UserRole.client &&
          selectedSalonId != null &&
          hasClientProfile &&
          session.availableSalonIds.contains(selectedSalonId);

      if (registering && registrationInProgress) {
        return null;
      }

      if (registeringCenter && centerRegistrationInProgress) {
        return null;
      }

      if (isAdminDisabled) {
        unawaited(ref.read(authRepositoryProvider).signOut());
        if (loggingIn) {
          return null;
        }
        return Uri(
          path: '/',
          queryParameters: const {
            noticeQueryParam: 'Account in attesa di abilitazione.',
          },
        ).toString();
      }

      if (!isAuthenticated) {
        if (loggingIn ||
            registering ||
            registeringCenter ||
            resettingPassword ||
            browsingClientSalons) {
          return null;
        }
        return Uri(
          path: '/',
          queryParameters: {redirectQueryParam: state.uri.toString()},
        ).toString();
      }

      if (requiresEmailVerification) {
        if (loggingIn) {
          return null;
        }
        final verifyRedirect =
            Uri(
              path: '/',
              queryParameters: {verifyEmailQueryParam: '1'},
            ).toString();
        return verifyRedirect;
      }

      if (requiresPasswordChange) {
        return changingPassword ? null : '/first-password-change';
      }

      if (requiresProfile) {
        return onboarding ? null : '/onboarding';
      }

      final destination = _pathForRole(session.role);

      if (changingPassword) {
        return destination;
      }

      if (loggingIn) {
        final redirectPath = _safeInternalRedirect(
          state.uri.queryParameters[redirectQueryParam],
        );
        if (redirectPath != null) {
          return redirectPath;
        }
        if (canEnterClientDashboard) {
          return '/client/dashboard';
        }
        return destination;
      }

      if (deletingAccount) {
        return null;
      }

      if (registering || registeringCenter || onboarding || resettingPassword) {
        return destination;
      }

      if (state.matchedLocation == '/admin' && session.role != UserRole.admin) {
        return destination;
      }
      if (state.matchedLocation == '/staff' && session.role != UserRole.staff) {
        return destination;
      }
      if (state.matchedLocation == '/client' &&
          session.role != UserRole.client) {
        return destination;
      }
      if (state.matchedLocation == '/client/dashboard' &&
          session.role != UserRole.client) {
        return destination;
      }
      if (state.matchedLocation == '/client/dashboard' &&
          session.role == UserRole.client &&
          !canEnterClientDashboard) {
        return '/client';
      }

      return null;
    },
  );
}

String? _safeInternalRedirect(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !value.startsWith('/')) {
    return null;
  }
  return value;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String _pathForRole(UserRole? role) {
  switch (role) {
    case UserRole.admin:
      return '/admin';
    case UserRole.staff:
      return '/staff';
    case UserRole.client:
      return '/client';
    case null:
      return '/';
  }
}
