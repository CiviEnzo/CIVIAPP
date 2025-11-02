import 'dart:async';

import 'package:collection/collection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:you_book/app/providers.dart';
import 'package:you_book/app/router_constants.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/data/repositories/auth_repository.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_registration_draft.dart';
import 'package:you_book/domain/entities/public_salon.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/domain/entities/user_role.dart';

class ClientSalonDiscoveryScreen extends ConsumerStatefulWidget {
  const ClientSalonDiscoveryScreen({super.key});

  @override
  ConsumerState<ClientSalonDiscoveryScreen> createState() =>
      _ClientSalonDiscoveryScreenState();
}

class _ClientSalonDiscoveryScreenState
    extends ConsumerState<ClientSalonDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _joiningSalonId;
  bool _redirectingToSignIn = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) {
      return;
    }
    setState(() => _searchQuery = next);
  }

  bool _matchesQuery(PublicSalon salon) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final tokens = <String>[
      salon.name,
      salon.city,
      salon.address,
      salon.email,
      salon.phone,
    ];
    return tokens.any((token) => token.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final userId = session.uid;
    final requiresEmailVerification = session.requiresEmailVerification;

    if (user == null || requiresEmailVerification) {
      if (!_redirectingToSignIn) {
        _redirectingToSignIn = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final hasDraft = ref.read(clientRegistrationDraftProvider) != null;
          final shouldShowNotice = hasDraft || requiresEmailVerification;
          context.goNamed(
            'sign_in',
            queryParameters:
                shouldShowNotice
                    ? const {verifyEmailQueryParam: '1'}
                    : const <String, String>{},
          );
        });
      }
      return const SizedBox.shrink();
    }

    final discoverableSalons = data.discoverableSalons;
    final fallbackSalons = data.salons
        .where((salon) => salon.isPublished)
        .map(PublicSalon.fromSalon)
        .toList(growable: false);
    final availableSalons =
        discoverableSalons.isNotEmpty ? discoverableSalons : fallbackSalons;
    final salons = availableSalons
        .where((salon) => salon.status != SalonStatus.archived)
        .where(_matchesQuery)
        .sorted((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final requests =
        userId == null
            ? const <SalonAccessRequest>[]
            : data.salonAccessRequests
                .where((request) => request.userId == userId)
                .toList(growable: false);

    final pendingBySalon = <String, SalonAccessRequest>{
      for (final request in requests.where(
        (request) => request.status == SalonAccessRequestStatus.pending,
      ))
        request.salonId: request,
    };
    final rejectedBySalon = <String, SalonAccessRequest>{
      for (final request in requests.where(
        (request) => request.status == SalonAccessRequestStatus.rejected,
      ))
        request.salonId: request,
    };

    final approvedSalonIds = session.availableSalonIds.toSet();
    final hasSalons = salons.isNotEmpty;
    final useCardGrid = salons.length <= 5;
    final defaultSalonId =
        session.salonId ??
        (approvedSalonIds.isNotEmpty ? approvedSalonIds.first : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli il tuo salone'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Benvenuto${user?.displayName != null ? ', ${user!.displayName!.split(' ').first}' : ''}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Esplora i saloni disponibili, invia una richiesta di accesso o entra nei saloni che ti hanno già approvato.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Cerca per nome, città o contatto',
                  suffixIcon:
                      _searchQuery.isEmpty
                          ? null
                          : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: _searchController.clear,
                          ),
                ),
              ),
              const SizedBox(height: 24),
              if (!hasSalons)
                Expanded(
                  child: Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Nessun salone disponibile al momento.'
                          : 'Nessun salone corrisponde alla tua ricerca.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (useCardGrid)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount =
                          width >= 840
                              ? 3
                              : width >= 520
                              ? 2
                              : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 4 / 3,
                        ),
                        itemCount: salons.length,
                        itemBuilder: (context, index) {
                          final salon = salons[index];
                          final isApproved = approvedSalonIds.contains(
                            salon.id,
                          );
                          final pendingRequest = pendingBySalon[salon.id];
                          final rejectedRequest = rejectedBySalon[salon.id];
                          return _SalonCard(
                            salon: salon,
                            isApproved: isApproved,
                            isProcessing: _joiningSalonId == salon.id,
                            pendingRequest: pendingRequest,
                            rejectedRequest: rejectedRequest,
                            onRequestAccess:
                                () => _startRequestFlow(context, salon, user),
                            onEnter: () => _enterSalon(salon.id),
                          );
                        },
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: salons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final salon = salons[index];
                      final isApproved = approvedSalonIds.contains(salon.id);
                      final pendingRequest = pendingBySalon[salon.id];
                      final rejectedRequest = rejectedBySalon[salon.id];
                      return _SalonCard(
                        salon: salon,
                        isApproved: isApproved,
                        isProcessing: _joiningSalonId == salon.id,
                        pendingRequest: pendingRequest,
                        rejectedRequest: rejectedRequest,
                        onRequestAccess:
                            () => _startRequestFlow(context, salon, user),
                        onEnter: () => _enterSalon(salon.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (pendingBySalon.isNotEmpty)
                _StatusInfoBanner(
                  icon: Icons.hourglass_top,
                  color: theme.colorScheme.tertiary,
                  message:
                      'Hai ${pendingBySalon.length} richiesta'
                      '${pendingBySalon.length == 1 ? '' : 'e'} in attesa di approvazione.',
                ),
              if (approvedSalonIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                _StatusInfoBanner(
                  icon: Icons.verified_rounded,
                  color: theme.colorScheme.primary,
                  message:
                      'Accesso attivo per ${approvedSalonIds.length} salone'
                      '${approvedSalonIds.length == 1 ? '' : 'i'}.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Confermi il logout?'),
              content: const Text(
                'Verrai riportato alla schermata di accesso e dovrai reinserire le tue credenziali.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Esci'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    try {
      await performSignOut(ref);
      if (!mounted) {
        return;
      }
      context.go('/');
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout non riuscito: $error')));
    }
  }

  Future<void> _startRequestFlow(
    BuildContext context,
    PublicSalon salon,
    AppUser? user,
  ) async {
    final session = ref.read(sessionControllerProvider);
    final userId = session.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessione scaduta. Accedi nuovamente per proseguire.'),
        ),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final data = ref.read(appDataProvider);
    final registrationDraft = ref.read(clientRegistrationDraftProvider);
    final clients = data.clients;
    Client? existingClient;
    if (user?.clientId != null) {
      existingClient = clients.firstWhereOrNull(
        (client) => client.id == user!.clientId,
      );
    } else if (user?.email != null) {
      existingClient = clients.firstWhereOrNull((client) {
        final candidateEmail = client.email?.trim().toLowerCase();
        return candidateEmail == user!.email?.trim().toLowerCase();
      });
    }

    final initialFirstName =
        registrationDraft?.firstName ??
        existingClient?.firstName ??
        user?.pendingFirstName ??
        _splitName(user?.displayName).$1;
    final initialLastName =
        registrationDraft?.lastName ??
        existingClient?.lastName ??
        user?.pendingLastName ??
        _splitName(user?.displayName).$2;
    final sanitizedExistingPhone =
        existingClient == null || existingClient.phone == '-'
            ? null
            : existingClient.phone;
    final initialPhone =
        registrationDraft?.phone ??
        sanitizedExistingPhone ??
        user?.pendingPhone ??
        '';
    final initialEmail =
        registrationDraft?.email ?? existingClient?.email ?? user?.email ?? '';
    final initialCity = existingClient?.city ?? existingClient?.address ?? '';
    final initialAddress = existingClient?.address ?? '';
    final initialProfession = existingClient?.profession ?? '';
    final initialNotes = existingClient?.notes ?? '';
    final initialReferral = existingClient?.referralSource ?? '';
    final initialBirthDate =
        registrationDraft?.dateOfBirth ??
        existingClient?.dateOfBirth ??
        user?.pendingDateOfBirth;
    final registrationSettings = salon.clientRegistration;

    final requestSent =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) {
            return _SalonAccessRequestSheet(
              salon: salon,
              settings: registrationSettings,
              initialFirstName: initialFirstName,
              initialLastName: initialLastName,
              initialEmail: initialEmail,
              initialPhone: initialPhone,
              initialCity: initialCity,
              initialAddress: initialAddress,
              initialProfession: initialProfession,
              initialReferralSource: initialReferral,
              initialNotes: initialNotes,
              initialBirthDate: initialBirthDate,
            );
          },
        ) ??
        false;
    if (!requestSent) {
      return;
    }
    if (!mounted) {
      return;
    }
    final messenger = scaffoldMessenger;
    if (messenger == null || !messenger.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Richiesta inviata a ${salon.name}. Riceverai una notifica quando verrà approvata.',
        ),
      ),
    );
  }

  Future<void> _enterSalon(String? salonId) async {
    if (salonId == null || salonId.isEmpty) {
      return;
    }
    if (_joiningSalonId != null) {
      if (_joiningSalonId == salonId) {
        return;
      }
      return;
    }
    final rootContext = context;
    if (mounted) {
      setState(() => _joiningSalonId = salonId);
    } else {
      _joiningSalonId = salonId;
    }
    final navigator = Navigator.of(rootContext, rootNavigator: true);
    final overlayContext = navigator.context;
    var loadingDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: overlayContext,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          return const _ProgressDialog(message: 'Sto cambiando salone...');
        },
      ).whenComplete(() => loadingDialogVisible = false),
    );

    void closeLoadingDialog() {
      if (!loadingDialogVisible) {
        return;
      }
      if (!navigator.mounted) {
        loadingDialogVisible = false;
        return;
      }
      if (navigator.canPop()) {
        navigator.pop();
        loadingDialogVisible = false;
      }
    }

    try {
      final sessionController = ref.read(sessionControllerProvider.notifier);
      final sessionState = ref.read(sessionControllerProvider);
      final currentUser = sessionState.user;
      final dataState = ref.read(appDataProvider);
      final clients = dataState.clients;

      Client? targetClient;
      String? targetClientId;
      SalonAccessRequest? approvedRequest;

      final currentClientId = currentUser?.clientId;
      if (currentClientId != null && currentClientId.isNotEmpty) {
        final currentClient = clients.firstWhereOrNull(
          (client) => client.id == currentClientId,
        );
        if (currentClient != null && currentClient.salonId == salonId) {
          targetClient = currentClient;
          targetClientId = currentClient.id;
        }
      }

      targetClient ??= clients.firstWhereOrNull(
        (client) => client.salonId == salonId,
      );
      targetClientId ??= targetClient?.id;

      final selectedEntityId = sessionState.selectedEntityId;
      if ((targetClientId == null || targetClient == null) &&
          selectedEntityId != null &&
          selectedEntityId.isNotEmpty) {
        final selectedClient = clients.firstWhereOrNull(
          (client) => client.id == selectedEntityId,
        );
        if (selectedClient != null && selectedClient.salonId == salonId) {
          targetClient = selectedClient;
          targetClientId = selectedClient.id;
        }
      }

      if (targetClientId == null || targetClientId.isEmpty) {
        approvedRequest = dataState.salonAccessRequests.firstWhereOrNull(
          (request) =>
              request.salonId == salonId &&
              request.status == SalonAccessRequestStatus.approved &&
              (request.clientId?.isNotEmpty ?? false),
        );
        targetClientId = approvedRequest?.clientId;
        if (targetClient == null && targetClientId != null) {
          targetClient = clients.firstWhereOrNull(
            (client) => client.id == targetClientId,
          );
        }
      }

      if (targetClientId == null || targetClientId.isEmpty) {
        sessionController.setUser(null);
        closeLoadingDialog();
        if (!mounted) {
          return;
        }

        final pendingRequest =
            approvedRequest ??
            dataState.salonAccessRequests.firstWhereOrNull(
              (request) =>
                  request.salonId == salonId &&
                  request.status == SalonAccessRequestStatus.approved,
            );

        final message =
            pendingRequest == null
                ? 'Non è stato trovato un profilo cliente attivo per questo salone.'
                : 'Il profilo è in fase di attivazione. Riprova tra qualche istante.';

        await showDialog<void>(
          context: overlayContext,
          useRootNavigator: true,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Profilo non disponibile'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Ok'),
                ),
              ],
            );
          },
        );
        return;
      }

      final resolvedFirstNameFallback =
          targetClient?.firstName ?? approvedRequest?.firstName;
      final resolvedLastNameFallback =
          targetClient?.lastName ?? approvedRequest?.lastName;
      final resolvedEmailFallback =
          targetClient?.email ?? approvedRequest?.email ?? currentUser?.email;
      final resolvedDisplayName = _formatDisplayName(
        resolvedFirstNameFallback,
        resolvedLastNameFallback,
        fallback: currentUser?.displayName,
      );
      final currentUid = currentUser?.uid ?? sessionState.uid;
      if (currentUid == null || currentUid.isEmpty) {
        throw StateError('Profilo utente non disponibile.');
      }

      await _activateSalonAccessOnBackend(
        salonId: salonId,
        clientId: targetClientId,
        displayName: resolvedDisplayName,
        email: resolvedEmailFallback,
      );

      sessionController.setUser(targetClientId);

      if (currentUser != null) {
        final updatedSalonIds = <String>{...currentUser.salonIds, salonId}
          ..removeWhere((value) => value.isEmpty);
        final updatedRoles =
            currentUser.availableRoles.contains(UserRole.client)
                ? currentUser.availableRoles
                : <UserRole>[...currentUser.availableRoles, UserRole.client];
        final updatedUser = currentUser.copyWith(
          role: UserRole.client,
          salonIds: updatedSalonIds.toList(growable: false),
          clientId: targetClientId,
          displayName: resolvedDisplayName,
          email: resolvedEmailFallback ?? currentUser.email,
          availableRoles: updatedRoles,
          pendingSalonId: null,
          pendingFirstName: null,
          pendingLastName: null,
          pendingPhone: null,
          pendingDateOfBirth: null,
        );
        sessionController.updateUser(updatedUser);
      } else if (currentUid.isNotEmpty) {
        final baseUser =
            sessionState.user ??
            AppUser.placeholder(
              currentUid,
              email: resolvedEmailFallback,
              isEmailVerified: true,
            );
        final updatedUser = baseUser.copyWith(
          role: UserRole.client,
          salonIds: <String>[salonId],
          clientId: targetClientId,
          displayName: resolvedDisplayName,
          email: resolvedEmailFallback ?? baseUser.email,
          availableRoles: const <UserRole>[UserRole.client],
          pendingSalonId: null,
          pendingFirstName: null,
          pendingLastName: null,
          pendingPhone: null,
          pendingDateOfBirth: null,
        );
        sessionController.updateUser(updatedUser);
      }

      sessionController.setSalon(salonId);

      ref.invalidate(appDataProvider);
      final store = ref.read(appDataProvider.notifier);
      final dataStream = store.stream;
      await store.reloadActiveSalon();

      try {
        final awaitedState = await dataStream
            .firstWhere(
              (state) =>
                  state.clients.any((client) => client.id == targetClientId),
            )
            .timeout(const Duration(seconds: 8));
        targetClient = awaitedState.clients.firstWhereOrNull(
          (client) => client.id == targetClientId,
        );
      } on TimeoutException {
        // Keep existing fallback data; navigation will continue with loader.
      } catch (_) {
        // Ignore other stream errors and fallback to best effort data.
      }

      if (mounted) {
        final sessionSnapshot = ref.read(sessionControllerProvider);
        final stabilizedUser = sessionSnapshot.user ?? currentUser;
        if (stabilizedUser != null) {
          final resolvedFirstName =
              targetClient?.firstName ?? approvedRequest?.firstName;
          final resolvedLastName =
              targetClient?.lastName ?? approvedRequest?.lastName;
          final resolvedEmail = targetClient?.email ?? approvedRequest?.email;
          final updatedSalonIds = <String>{...stabilizedUser.salonIds, salonId}
            ..removeWhere((value) => value.isEmpty);
          final updatedRoles =
              stabilizedUser.availableRoles.contains(UserRole.client)
                  ? stabilizedUser.availableRoles
                  : <UserRole>[
                    ...stabilizedUser.availableRoles,
                    UserRole.client,
                  ];
          final resolvedDisplayName = _formatDisplayName(
            resolvedFirstName,
            resolvedLastName,
            fallback: stabilizedUser.displayName,
          );
          final updatedUser = stabilizedUser.copyWith(
            role: UserRole.client,
            salonIds: updatedSalonIds.toList(growable: false),
            clientId: targetClientId,
            displayName: resolvedDisplayName,
            email: resolvedEmail ?? stabilizedUser.email,
            availableRoles: updatedRoles,
            pendingSalonId: null,
            pendingFirstName: null,
            pendingLastName: null,
            pendingPhone: null,
            pendingDateOfBirth: null,
          );
          ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
        }
      }

      closeLoadingDialog();
      ref.read(appRouterProvider).go('/client/dashboard');
    } catch (error) {
      closeLoadingDialog();
      if (!mounted) {
        return;
      }
      if (!navigator.mounted) {
        ScaffoldMessenger.maybeOf(rootContext)?.showSnackBar(
          SnackBar(content: Text('Cambio salone non riuscito: $error')),
        );
        return;
      }
      await showDialog<void>(
        context: overlayContext,
        useRootNavigator: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Cambio salone non riuscito'),
            content: Text(
              'Non è stato possibile attivare il salone selezionato. '
              'Dettagli: $error',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Ok'),
              ),
            ],
          );
        },
      );
    } finally {
      if (_joiningSalonId == salonId) {
        if (mounted) {
          setState(() => _joiningSalonId = null);
        } else {
          _joiningSalonId = null;
        }
      }
    }
  }

  Future<void> _activateSalonAccessOnBackend({
    required String salonId,
    required String clientId,
    String? displayName,
    String? email,
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west3');
    final callable = functions.httpsCallable('activateClientSalon');
    final payload = <String, dynamic>{'salonId': salonId, 'clientId': clientId};
    if (displayName != null && displayName.trim().isNotEmpty) {
      payload['displayName'] = displayName.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }
    try {
      await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      final details =
          error.code == 'permission-denied'
              ? 'permessi insufficienti'
              : error.message ?? error.code;
      throw Exception('Aggiornamento profilo non riuscito ($details).');
    }
  }

  String? _formatDisplayName(
    String? firstName,
    String? lastName, {
    String? fallback,
  }) {
    final parts = <String>[
      if (firstName != null && firstName.trim().isNotEmpty) firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty) lastName.trim(),
    ];
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    final normalizedFallback = fallback?.trim();
    if (normalizedFallback == null || normalizedFallback.isEmpty) {
      return null;
    }
    return normalizedFallback;
  }

  (String, String) _splitName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return ('', '');
    }
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return (parts.first, '');
    }
    return (parts.first, parts.skip(1).join(' '));
  }
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({
    required this.salon,
    required this.isApproved,
    required this.isProcessing,
    required this.pendingRequest,
    required this.rejectedRequest,
    required this.onRequestAccess,
    required this.onEnter,
  });

  final PublicSalon salon;
  final bool isApproved;
  final bool isProcessing;
  final SalonAccessRequest? pendingRequest;
  final SalonAccessRequest? rejectedRequest;
  final VoidCallback onRequestAccess;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitleStyle = theme.textTheme.bodyMedium;
    final status = _resolveStatus();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    salon.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            if (salon.address.isNotEmpty || salon.city.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        salon.address,
                        salon.city,
                      ].where((value) => value.trim().isNotEmpty).join(', '),
                      style: subtitleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (salon.phone.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(salon.phone, style: subtitleStyle)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (salon.email.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(salon.email, style: subtitleStyle)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            const Spacer(),
            Row(
              children: [
                if (status == _CardStatus.approved)
                  Expanded(
                    child: FilledButton(
                      onPressed: isProcessing ? null : onEnter,
                      child:
                          isProcessing
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Accesso in corso'),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.arrow_forward_rounded),
                                  SizedBox(width: 12),
                                  Text('Entra nel salone'),
                                ],
                              ),
                    ),
                  )
                else if (status == _CardStatus.pending)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.hourglass_top_rounded),
                      onPressed: null,
                      label: const Text('Richiesta in elaborazione'),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: onRequestAccess,
                      label: Text(
                        status == _CardStatus.rejected
                            ? 'Invia di nuovo la richiesta'
                            : 'Richiedi accesso',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _CardStatus _resolveStatus() {
    if (isApproved) {
      return _CardStatus.approved;
    }
    if (pendingRequest != null) {
      return _CardStatus.pending;
    }
    if (rejectedRequest != null) {
      return _CardStatus.rejected;
    }
    return _CardStatus.available;
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 20),
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardStatus { available, pending, approved, rejected }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _CardStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Color? background;
    Color? foreground;
    String label;
    IconData icon;

    switch (status) {
      case _CardStatus.available:
        background = scheme.surfaceVariant;
        foreground = scheme.onSurfaceVariant;
        label = 'Disponibile';
        icon = Icons.meeting_room_outlined;
        break;
      case _CardStatus.pending:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        label = 'In attesa';
        icon = Icons.hourglass_bottom_rounded;
        break;
      case _CardStatus.approved:
        background = scheme.primary;
        foreground = scheme.onPrimary;
        label = 'Accesso attivo';
        icon = Icons.verified_rounded;
        break;
      case _CardStatus.rejected:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        label = 'Richiesta respinta';
        icon = Icons.block_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _StatusInfoBanner extends StatelessWidget {
  const _StatusInfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonAccessRequestSheet extends ConsumerStatefulWidget {
  const _SalonAccessRequestSheet({
    required this.salon,
    required this.settings,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialEmail,
    required this.initialPhone,
    required this.initialCity,
    required this.initialAddress,
    required this.initialProfession,
    required this.initialReferralSource,
    required this.initialNotes,
    required this.initialBirthDate,
  });

  final PublicSalon salon;
  final ClientRegistrationSettings settings;
  final String initialFirstName;
  final String initialLastName;
  final String initialEmail;
  final String initialPhone;
  final String initialCity;
  final String initialAddress;
  final String initialProfession;
  final String initialReferralSource;
  final String initialNotes;
  final DateTime? initialBirthDate;

  @override
  ConsumerState<_SalonAccessRequestSheet> createState() =>
      _SalonAccessRequestSheetState();
}

class _SalonAccessRequestSheetState
    extends ConsumerState<_SalonAccessRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _professionController;
  late final TextEditingController _notesController;
  late final TextEditingController _referralController;
  late final TextEditingController _birthDateController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _birthDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialFirstName);
    _lastNameController = TextEditingController(text: widget.initialLastName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
    final resolvedCity =
        widget.initialCity.isNotEmpty
            ? widget.initialCity
            : (widget.initialAddress.isNotEmpty ? widget.initialAddress : '');
    _cityController = TextEditingController(text: resolvedCity);
    _addressController = TextEditingController(text: widget.initialAddress);
    _professionController = TextEditingController(
      text: widget.initialProfession,
    );
    _notesController = TextEditingController(text: widget.initialNotes);
    _referralController = TextEditingController(
      text: widget.initialReferralSource,
    );
    _birthDateController = TextEditingController(
      text:
          widget.initialBirthDate == null
              ? ''
              : _dateFormat.format(widget.initialBirthDate!),
    );
    _birthDate = widget.initialBirthDate;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    _notesController.dispose();
    _referralController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    final settings = widget.settings;
    final requiresAddress = settings.extraFields.contains(
      ClientRegistrationExtraField.address,
    );
    final requiresProfession = settings.extraFields.contains(
      ClientRegistrationExtraField.profession,
    );
    final requiresReferral = settings.extraFields.contains(
      ClientRegistrationExtraField.referralSource,
    );
    final requiresNotes = settings.extraFields.contains(
      ClientRegistrationExtraField.notes,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Richiedi accesso a ${widget.salon.name}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed:
                          _isSubmitting
                              ? null
                              : () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Compila i dati richiesti dal salone. Riceverai una conferma quando l\'accesso sarà approvato.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Inserisci il nome';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(labelText: 'Cognome'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Inserisci il cognome';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'Inserisci l\'email';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Email non valida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono (anche WhatsApp)',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Inserisci il numero di telefono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Data di nascita',
                    hintText: 'gg/mm/aaaa',
                  ),
                  readOnly: true,
                  onTap: _pickDateOfBirth,
                ),
                if (requiresAddress) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Città di residenza',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Inserisci la città';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Indirizzo (opzionale)',
                    ),
                  ),
                ],
                if (requiresProfession) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _professionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Professione'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Inserisci la professione';
                      }
                      return null;
                    },
                  ),
                ],
                if (requiresReferral) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _referralController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Come hai conosciuto il salone?',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Campo obbligatorio';
                      }
                      return null;
                    },
                  ),
                ],
                if (requiresNotes) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note per il salone',
                    ),
                    minLines: 2,
                    maxLines: 4,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Campo obbligatorio';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon:
                      _isSubmitting
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send_rounded),
                  onPressed: _isSubmitting ? null : _submit,
                  label: Text(
                    _isSubmitting ? 'Invio in corso...' : 'Invia richiesta',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final initialDate =
        _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 25));
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _birthDate = selected;
      _birthDateController.text = _dateFormat.format(selected);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final session = ref.read(sessionControllerProvider);
    final user = session.user;
    final userId = session.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessione scaduta. Accedi nuovamente per proseguire.'),
        ),
      );
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final extraData = <String, dynamic>{};
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();
    if (city.isNotEmpty) {
      extraData['city'] = city;
    }
    if (address.isNotEmpty) {
      extraData['address'] = address;
    }
    if (_professionController.text.trim().isNotEmpty) {
      extraData['profession'] = _professionController.text.trim();
    }
    if (_referralController.text.trim().isNotEmpty) {
      extraData['referralSource'] = _referralController.text.trim();
    }
    if (_notesController.text.trim().isNotEmpty) {
      extraData['notes'] = _notesController.text.trim();
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(appDataProvider.notifier)
          .submitSalonAccessRequest(
            salonId: widget.salon.id,
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            dateOfBirth: _birthDate,
            extraData: extraData,
          );

      final authRepo = ref.read(authRepositoryProvider);
      final currentRole = user?.role ?? UserRole.client;
      await authRepo.completeUserProfile(
        role: currentRole,
        salonIds: user?.salonIds ?? const [],
        staffId: user?.staffId,
        clientId: user?.clientId,
        displayName:
            '$firstName $lastName'.trim().isEmpty
                ? user?.displayName
                : '$firstName $lastName',
      );

      if (user != null) {
        final updatedRoles =
            user.availableRoles.contains(currentRole)
                ? user.availableRoles
                : <UserRole>[...user.availableRoles, currentRole];
        final updatedUser = user.copyWith(
          role: currentRole,
          salonIds: user.salonIds,
          staffId: user.staffId,
          clientId: user.clientId,
          displayName:
              '$firstName $lastName'.trim().isEmpty
                  ? user.displayName
                  : '$firstName $lastName',
          email: email,
          availableRoles: updatedRoles,
          pendingSalonId: widget.salon.id,
          pendingFirstName: firstName,
          pendingLastName: lastName,
          pendingPhone: phone,
          pendingDateOfBirth: _birthDate,
        );
        ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
      }
      ref.read(clientRegistrationDraftProvider.notifier).clear();

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile inviare la richiesta: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
