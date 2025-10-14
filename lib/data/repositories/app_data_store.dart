import 'dart:async';
import 'dart:collection';

import 'package:civiapp/data/mappers/firestore_mappers.dart';
import 'package:civiapp/data/mock_data.dart';
import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/app_notification.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/client_questionnaire.dart';
import 'package:civiapp/domain/entities/client_photo.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/last_minute_slot.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/promotion.dart';
import 'package:civiapp/domain/entities/quote.dart';
import 'package:civiapp/domain/entities/payment_ticket.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/service_category.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:civiapp/domain/entities/reminder_settings.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class AppDataStore extends StateNotifier<AppDataState> {
  AppDataStore({FirebaseFirestore? firestore, AppUser? currentUser})
    : _firestore =
          Firebase.apps.isNotEmpty
              ? (firestore ?? FirebaseFirestore.instance)
              : null,
      _currentUser = currentUser,
      _hasAuthenticatedUser = currentUser != null,
      super(
        Firebase.apps.isNotEmpty
            ? AppDataState.initial()
            : AppDataState(
              salons: List.unmodifiable(MockData.salons),
              staff: List.unmodifiable(MockData.staffMembers),
              staffRoles: List.unmodifiable(MockData.staffRoles),
              clients: List.unmodifiable(MockData.clients),
              serviceCategories: List.unmodifiable(MockData.serviceCategories),
              services: List.unmodifiable(MockData.services),
              packages: List.unmodifiable(MockData.packages),
              appointments: List.unmodifiable(MockData.appointments),
              quotes: List.unmodifiable(MockData.quotes),
              paymentTickets: List.unmodifiable(MockData.paymentTickets),
              inventoryItems: List.unmodifiable(MockData.inventoryItems),
              sales: List.unmodifiable(MockData.sales),
              cashFlowEntries: List.unmodifiable(MockData.cashFlowEntries),
              messageTemplates: List.unmodifiable(MockData.messageTemplates),
              reminderSettings: List.unmodifiable(MockData.reminderSettings),
              clientNotifications: const [],
              shifts: List.unmodifiable(MockData.shifts),
              staffAbsences: List.unmodifiable(MockData.staffAbsences),
              publicStaffAbsences: List.unmodifiable(
                MockData.publicStaffAbsences,
              ),
              users: const [],
              clientPhotos: List.unmodifiable(MockData.clientPhotos),
              clientQuestionnaireTemplates: List.unmodifiable(
                MockData.clientQuestionnaireTemplates,
              ),
              clientQuestionnaires: List.unmodifiable(
                MockData.clientQuestionnaires,
              ),
              promotions: List.unmodifiable(MockData.promotions),
              lastMinuteSlots: List.unmodifiable(MockData.lastMinuteSlots),
            ),
      ) {
    final firestore = _firestore;
    if (firestore != null && currentUser != null) {
      _subscriptions = _initializeSubscriptions(currentUser);
      _ensurePublicMirrorsIfNeeded(currentUser);
    } else {
      _subscriptions = <StreamSubscription>[];
    }

    if (_firestore == null) {
      _cachedPromotions = state.promotions;
      _cachedLastMinuteSlots = state.lastMinuteSlots;
      _refreshFeatureFilteredCollections();
    }
  }

  final FirebaseFirestore? _firestore;
  final AppUser? _currentUser;
  final bool _hasAuthenticatedUser;
  FirebaseAuth? _adminAuth;
  Future<FirebaseAuth?>? _adminAuthFuture;
  late final List<StreamSubscription> _subscriptions;
  bool _onboardingSyncScheduled = false;
  bool _isSyncingOnboardingStatus = false;
  bool _hasEnsuredPublicMirrors = false;
  List<Promotion> _cachedPromotions = const <Promotion>[];
  List<LastMinuteSlot> _cachedLastMinuteSlots = const <LastMinuteSlot>[];

  static const int _firestoreChunkSize = 10;
  static const String _defaultStaffRoleId = 'estetista';
  static const String _unknownStaffRoleId = 'staff-role-unknown';

  AppUser? get currentUser => _currentUser;

  List<StreamSubscription> _initializeSubscriptions(AppUser currentUser) {
    final firestore = _firestore;
    if (firestore == null) {
      return <StreamSubscription>[];
    }

    final role = currentUser.role;
    final salonIds = _normalizedSalonIds(currentUser);
    final subscriptions = <StreamSubscription>[];

    void addAll(List<StreamSubscription> items) {
      subscriptions.addAll(items);
    }

    if (role == null || salonIds.isEmpty) {
      subscriptions.add(
        _listenCollection<Salon>(firestore.collection('salons'), salonFromDoc, (
          items,
        ) {
          state = state.copyWith(salons: items);
          _refreshFeatureFilteredCollections();
        }),
      );
      subscriptions.add(
        _listenCollection<ServiceCategory>(
          firestore.collection('service_categories'),
          serviceCategoryFromDoc,
          (items) =>
              state = state.copyWith(
                serviceCategories: items.sortedByDisplayOrder(),
              ),
        ),
      );
      subscriptions.add(
        _listenCollection<Quote>(
          firestore.collection('quotes'),
          quoteFromDoc,
          (items) => state = state.copyWith(quotes: items),
        ),
      );

      subscriptions.add(
        _listenCollection<Promotion>(
          firestore.collection('promotions'),
          promotionFromDoc,
          _onPromotionsData,
        ),
      );

      subscriptions.add(
        _listenCollection<LastMinuteSlot>(
          firestore.collection('last_minute_slots'),
          lastMinuteSlotFromDoc,
          _onLastMinuteSlotsData,
        ),
      );
    } else {
      addAll(
        _listenDocumentsByIds<Salon>(
          firestore: firestore,
          collectionPath: 'salons',
          documentIds: salonIds,
          fromDoc: salonFromDoc,
          onData: (items) {
            state = state.copyWith(salons: items);
            _refreshFeatureFilteredCollections();
          },
        ),
      );
    }

    if (role == null) {
      subscriptions.add(
        _listenCollection<StaffRole>(
          firestore.collection('staff_roles'),
          staffRoleFromDoc,
          (items) {
            final merged = <String, StaffRole>{
              for (final roleItem in MockData.staffRoles) roleItem.id: roleItem,
            };
            for (final roleItem in items) {
              merged[roleItem.id] = roleItem;
            }
            final sorted =
                merged.values.toList()..sort((a, b) {
                  final priorityCompare = a.sortPriority.compareTo(
                    b.sortPriority,
                  );
                  if (priorityCompare != 0) {
                    return priorityCompare;
                  }
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });
            state = state.copyWith(staffRoles: List.unmodifiable(sorted));
          },
        ),
      );
    } else if (role == UserRole.admin) {
      final allowedSalonIds =
          salonIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();

      _updateScopedStaffRoles(const <StaffRole>[], allowedSalonIds);

      subscriptions.add(
        _listenCollection<StaffRole>(
          firestore.collection('staff_roles'),
          staffRoleFromDoc,
          (items) => _updateScopedStaffRoles(items, allowedSalonIds),
        ),
      );
    } else if (state.staffRoles.isEmpty) {
      state = state.copyWith(
        staffRoles: List.unmodifiable(MockData.staffRoles),
      );
    }

    if (role == UserRole.admin || role == UserRole.staff) {
      addAll(
        _listenCollectionBySalonIds<StaffMember>(
          firestore: firestore,
          collectionPath: 'staff',
          salonIds: salonIds,
          fromDoc: staffFromDoc,
          onData: (items) => state = state.copyWith(staff: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<Client>(
          firestore: firestore,
          collectionPath: 'clients',
          salonIds: salonIds,
          fromDoc: clientFromDoc,
          onData: (items) {
            state = state.copyWith(clients: items);
            _scheduleClientOnboardingSync();
          },
        ),
      );

      addAll(
        _listenCollectionBySalonIds<ServiceCategory>(
          firestore: firestore,
          collectionPath: 'service_categories',
          salonIds: salonIds,
          fromDoc: serviceCategoryFromDoc,
          onData:
              (items) =>
                  state = state.copyWith(
                    serviceCategories: items.sortedByDisplayOrder(),
                  ),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<Service>(
          firestore: firestore,
          collectionPath: 'services',
          salonIds: salonIds,
          fromDoc: serviceFromDoc,
          onData: (items) => state = state.copyWith(services: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<ServicePackage>(
          firestore: firestore,
          collectionPath: 'packages',
          salonIds: salonIds,
          fromDoc: packageFromDoc,
          onData: (items) => state = state.copyWith(packages: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<Promotion>(
          firestore: firestore,
          collectionPath: 'promotions',
          salonIds: salonIds,
          fromDoc: promotionFromDoc,
          onData: _onPromotionsData,
        ),
      );

      addAll(
        _listenCollectionBySalonIds<LastMinuteSlot>(
          firestore: firestore,
          collectionPath: 'last_minute_slots',
          salonIds: salonIds,
          fromDoc: lastMinuteSlotFromDoc,
          onData: _onLastMinuteSlotsData,
        ),
      );

      addAll(
        _listenClientShifts(
          firestore: firestore,
          salonIds: salonIds,
          onData: (items) => state = state.copyWith(shifts: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<Appointment>(
          firestore: firestore,
          collectionPath: 'appointments',
          salonIds: salonIds,
          fromDoc: appointmentFromDoc,
          onData: (items) => state = state.copyWith(appointments: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<Quote>(
          firestore: firestore,
          collectionPath: 'quotes',
          salonIds: salonIds,
          fromDoc: quoteFromDoc,
          onData: (items) => state = state.copyWith(quotes: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<InventoryItem>(
          firestore: firestore,
          collectionPath: 'inventory',
          salonIds: salonIds,
          fromDoc: inventoryFromDoc,
          onData: (items) => state = state.copyWith(inventoryItems: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<Sale>(
          firestore: firestore,
          collectionPath: 'sales',
          salonIds: salonIds,
          fromDoc: saleFromDoc,
          onData: (items) => state = state.copyWith(sales: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<ClientPhoto>(
          firestore: firestore,
          collectionPath: 'client_photos',
          salonIds: salonIds,
          fromDoc: clientPhotoFromDoc,
          onData: (items) => state = state.copyWith(clientPhotos: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<PaymentTicket>(
          firestore: firestore,
          collectionPath: 'payment_tickets',
          salonIds: salonIds,
          fromDoc: paymentTicketFromDoc,
          onData: (items) => state = state.copyWith(paymentTickets: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<CashFlowEntry>(
          firestore: firestore,
          collectionPath: 'cash_flows',
          salonIds: salonIds,
          fromDoc: cashFlowFromDoc,
          onData: (items) => state = state.copyWith(cashFlowEntries: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<MessageTemplate>(
          firestore: firestore,
          collectionPath: 'message_templates',
          salonIds: salonIds,
          fromDoc: messageTemplateFromDoc,
          onData: (items) => state = state.copyWith(messageTemplates: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<ClientQuestionnaireTemplate>(
          firestore: firestore,
          collectionPath: 'client_questionnaire_templates',
          salonIds: salonIds,
          fromDoc: clientQuestionnaireTemplateFromDoc,
          onData:
              (items) =>
                  state = state.copyWith(clientQuestionnaireTemplates: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<ClientQuestionnaire>(
          firestore: firestore,
          collectionPath: 'client_questionnaires',
          salonIds: salonIds,
          fromDoc: clientQuestionnaireFromDoc,
          onData:
              (items) => state = state.copyWith(clientQuestionnaires: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<ReminderSettings>(
          firestore: firestore,
          collectionPath: 'reminder_settings',
          salonIds: salonIds,
          fromDoc: reminderSettingsFromDoc,
          onData: (items) => state = state.copyWith(reminderSettings: items),
        ),
      );

      addAll(
        _listenCollectionBySalonIds<StaffAbsence>(
          firestore: firestore,
          collectionPath: 'staff_absences',
          salonIds: salonIds,
          fromDoc: staffAbsenceFromDoc,
          onData: (items) => state = state.copyWith(staffAbsences: items),
        ),
      );

      if (salonIds.isNotEmpty) {
        addAll(
          _listenChunkedQueries<AppUser>(
            firestore: firestore,
            values: salonIds,
            queryBuilder:
                (chunk) => firestore
                    .collection('users')
                    .where('salonIds', arrayContainsAny: chunk),
            fromDoc:
                (doc) =>
                    AppUser.fromMap(doc.id, doc.data() ?? <String, dynamic>{}),
            onData: _updateUsers,
          ),
        );
      } else {
        _updateUsers(const <AppUser>[]);
      }
    } else if (role == UserRole.client) {
      bool hasSalonSubscriptions = false;

      state = state.copyWith(reminderSettings: const []);

      final clientId = currentUser.clientId;
      if (clientId != null && clientId.isNotEmpty) {
        subscriptions.add(
          _listenCollection<AppNotification>(
            firestore
                .collection('message_outbox')
                .where('clientId', isEqualTo: clientId)
                .where('channel', isEqualTo: MessageChannel.push.name)
                .orderBy('scheduledAt', descending: true),
            appNotificationFromDoc,
            (items) => state = state.copyWith(clientNotifications: items),
          ),
        );
        subscriptions.add(
          _listenCollection<Quote>(
            firestore
                .collection('quotes')
                .where('clientId', isEqualTo: clientId)
                .orderBy('createdAt', descending: true),
            quoteFromDoc,
            (items) => state = state.copyWith(quotes: items),
          ),
        );
      } else {
        state = state.copyWith(clientNotifications: const []);
        state = state.copyWith(quotes: const []);
      }

      void subscribeSalonCollections(List<String> rawSalonIds) {
        if (hasSalonSubscriptions) {
          return;
        }
        final normalizedSalonIds = rawSalonIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);
        if (normalizedSalonIds.isEmpty) {
          return;
        }
        hasSalonSubscriptions = true;
        addAll(
          _listenCollectionBySalonIds<StaffMember>(
            firestore: firestore,
            collectionPath: 'staff',
            salonIds: normalizedSalonIds,
            fromDoc: staffFromDoc,
            onData: (items) => state = state.copyWith(staff: items),
          ),
        );

        addAll(
          _listenCollectionBySalonIds<ServiceCategory>(
            firestore: firestore,
            collectionPath: 'service_categories',
            salonIds: normalizedSalonIds,
            fromDoc: serviceCategoryFromDoc,
            onData:
                (items) =>
                    state = state.copyWith(
                      serviceCategories: items.sortedByDisplayOrder(),
                    ),
          ),
        );

        addAll(
          _listenCollectionBySalonIds<Service>(
            firestore: firestore,
            collectionPath: 'services',
            salonIds: normalizedSalonIds,
            fromDoc: serviceFromDoc,
            onData: (items) => state = state.copyWith(services: items),
          ),
        );

        addAll(
          _listenCollectionBySalonIds<ServicePackage>(
            firestore: firestore,
            collectionPath: 'packages',
            salonIds: normalizedSalonIds,
            fromDoc: packageFromDoc,
            onData: (items) => state = state.copyWith(packages: items),
          ),
        );

        addAll(
          _listenCollectionBySalonIds<Promotion>(
            firestore: firestore,
            collectionPath: 'promotions',
            salonIds: normalizedSalonIds,
            fromDoc: promotionFromDoc,
            onData: _onPromotionsData,
          ),
        );

        addAll(
          _listenCollectionBySalonIds<LastMinuteSlot>(
            firestore: firestore,
            collectionPath: 'last_minute_slots',
            salonIds: normalizedSalonIds,
            fromDoc: lastMinuteSlotFromDoc,
            onData: _onLastMinuteSlotsData,
          ),
        );

        addAll(
          _listenCollectionBySalonIds<Shift>(
            firestore: firestore,
            collectionPath: 'shifts',
            salonIds: normalizedSalonIds,
            fromDoc: shiftFromDoc,
            onData: (items) => state = state.copyWith(shifts: items),
          ),
        );

        addAll(
          _listenCollectionBySalonIds<StaffAbsence>(
            firestore: firestore,
            collectionPath: 'public_staff_absences',
            salonIds: normalizedSalonIds,
            fromDoc: staffAbsenceFromDoc,
            onData:
                (items) => state = state.copyWith(publicStaffAbsences: items),
          ),
        );

        addAll(
          _listenCollectionBySalonIds<ClientQuestionnaireTemplate>(
            firestore: firestore,
            collectionPath: 'client_questionnaire_templates',
            salonIds: normalizedSalonIds,
            fromDoc: clientQuestionnaireTemplateFromDoc,
            onData:
                (items) =>
                    state = state.copyWith(clientQuestionnaireTemplates: items),
          ),
        );
      }

      subscribeSalonCollections(salonIds);

      if (clientId != null && clientId.isNotEmpty) {
        subscriptions.add(
          _listenDocument<Client>(
            firestore.collection('clients').doc(clientId),
            clientFromDoc,
            (Client? client) {
              state = state.copyWith(
                clients:
                    client == null
                        ? const <Client>[]
                        : List.unmodifiable(<Client>[client]),
              );
              if (!hasSalonSubscriptions && client != null) {
                final salonId = client.salonId.trim();
                if (salonId.isNotEmpty) {
                  subscribeSalonCollections(<String>[salonId]);
                }
              }
            },
          ),
        );

        subscriptions.add(
          _listenCollection<Sale>(
            firestore
                .collection('sales')
                .where('clientId', isEqualTo: clientId),
            saleFromDoc,
            (items) => state = state.copyWith(sales: items),
          ),
        );

        subscriptions.add(
          _listenCollection<Appointment>(
            firestore
                .collection('appointments')
                .where('clientId', isEqualTo: clientId),
            appointmentFromDoc,
            (items) => state = state.copyWith(appointments: items),
          ),
        );

        subscriptions.add(
          _listenCollection<ClientPhoto>(
            firestore
                .collection('client_photos')
                .where('clientId', isEqualTo: clientId)
                .orderBy('uploadedAt', descending: true),
            clientPhotoFromDoc,
            (items) => state = state.copyWith(clientPhotos: items),
          ),
        );

        subscriptions.add(
          _listenCollection<ClientQuestionnaire>(
            firestore
                .collection('client_questionnaires')
                .where('clientId', isEqualTo: clientId),
            clientQuestionnaireFromDoc,
            (items) => state = state.copyWith(clientQuestionnaires: items),
          ),
        );
      } else {
        state = state.copyWith(
          clients: const <Client>[],
          appointments: const <Appointment>[],
          sales: const <Sale>[],
          clientPhotos: const <ClientPhoto>[],
          clientQuestionnaires: const <ClientQuestionnaire>[],
        );
      }

      _updateUsers(const <AppUser>[]);
    } else {
      _updateUsers(const <AppUser>[]);
    }

    return subscriptions;
  }

  List<StreamSubscription> _listenCollectionBySalonIds<T>({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required List<String> salonIds,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) fromDoc,
    required void Function(List<T>) onData,
  }) {
    return _listenChunkedQueries<T>(
      firestore: firestore,
      values: salonIds,
      queryBuilder:
          (chunk) => firestore
              .collection(collectionPath)
              .where('salonId', whereIn: chunk),
      fromDoc: fromDoc,
      onData: onData,
    );
  }

  List<StreamSubscription> _listenClientShifts({
    required FirebaseFirestore firestore,
    required List<String> salonIds,
    required void Function(List<Shift>) onData,
  }) {
    final normalized = salonIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      onData(const <Shift>[]);
      return <StreamSubscription>[];
    }

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final horizon = DateTime(
      now.year + 1,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final lowerBound = Timestamp.fromDate(dayStart);
    final upperBound = Timestamp.fromDate(horizon);

    final aggregated = <String, Shift>{};
    final salonDocIds = <String, Set<String>>{};
    final subscriptions = <StreamSubscription>[];

    void emit() {
      final sorted =
          aggregated.values.toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      onData(List.unmodifiable(sorted));
    }

    for (final salonId in normalized) {
      salonDocIds[salonId] = <String>{};
      final query = firestore
          .collection('shifts')
          .where('salonId', isEqualTo: salonId)
          .where('start', isGreaterThanOrEqualTo: lowerBound)
          .where('start', isLessThan: upperBound)
          .orderBy('start');

      final subscription = query.snapshots().listen(
        (snapshot) {
          var changed = false;
          final updatedIds = <String>{};
          for (final doc in snapshot.docs) {
            updatedIds.add(doc.id);
            aggregated[doc.id] = shiftFromDoc(doc);
            changed = true;
          }

          final previousIds = salonDocIds[salonId] ?? <String>{};
          for (final removedId in previousIds.difference(updatedIds)) {
            if (aggregated.remove(removedId) != null) {
              changed = true;
            }
          }

          salonDocIds[salonId] = updatedIds;
          if (changed) {
            emit();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _handleQueryError(
            query,
            error,
            stackTrace,
            onPermissionDenied: () {
              var changed = false;
              final previousIds = salonDocIds[salonId] ?? <String>{};
              for (final docId in previousIds) {
                if (aggregated.remove(docId) != null) {
                  changed = true;
                }
              }
              salonDocIds[salonId] = <String>{};
              if (changed || aggregated.isEmpty) {
                emit();
              }
            },
          );
        },
      );
      subscriptions.add(subscription);
    }

    emit();
    return subscriptions;
  }

  List<StreamSubscription> _listenDocumentsByIds<T>({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required List<String> documentIds,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) fromDoc,
    required void Function(List<T>) onData,
  }) {
    return _listenChunkedQueries<T>(
      firestore: firestore,
      values: documentIds,
      queryBuilder:
          (chunk) => firestore
              .collection(collectionPath)
              .where(FieldPath.documentId, whereIn: chunk),
      fromDoc: fromDoc,
      onData: onData,
    );
  }

  List<StreamSubscription> _listenChunkedQueries<T>({
    required FirebaseFirestore firestore,
    required List<String> values,
    required Query<Map<String, dynamic>> Function(List<String> chunk)
    queryBuilder,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) fromDoc,
    required void Function(List<T>) onData,
  }) {
    final normalized = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) {
      onData(List.unmodifiable(<T>[]));
      return <StreamSubscription>[];
    }

    final chunks = _splitIntoChunks(normalized);
    final aggregated = <String, T>{};
    final chunkDocIds = <int, Set<String>>{};
    final subscriptions = <StreamSubscription>[];

    void emit() {
      final sortedEntries =
          aggregated.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      onData(List.unmodifiable(sortedEntries.map((entry) => entry.value)));
    }

    for (var index = 0; index < chunks.length; index++) {
      final chunk = chunks[index];
      chunkDocIds[index] = <String>{};
      final query = queryBuilder(chunk);
      final subscription = query.snapshots().listen(
        (snapshot) {
          var changed = false;
          final updatedIds = <String>{};
          for (final doc in snapshot.docs) {
            updatedIds.add(doc.id);
            aggregated[doc.id] = fromDoc(doc);
            changed = true;
          }

          final previousIds = chunkDocIds[index] ?? <String>{};
          for (final removedId in previousIds.difference(updatedIds)) {
            if (aggregated.remove(removedId) != null) {
              changed = true;
            }
          }

          chunkDocIds[index] = updatedIds;
          if (changed) {
            emit();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _handleQueryError(
            query,
            error,
            stackTrace,
            onPermissionDenied: () {
              var changed = false;
              final previousIds = chunkDocIds[index] ?? <String>{};
              for (final docId in previousIds) {
                if (aggregated.remove(docId) != null) {
                  changed = true;
                }
              }
              chunkDocIds[index] = <String>{};
              if (changed || aggregated.isEmpty) {
                emit();
              }
            },
          );
        },
      );
      subscriptions.add(subscription);
    }

    emit();
    return subscriptions;
  }

  List<List<String>> _splitIntoChunks(List<String> values) {
    if (values.length <= _firestoreChunkSize) {
      return <List<String>>[values];
    }
    final chunks = <List<String>>[];
    for (var index = 0; index < values.length; index += _firestoreChunkSize) {
      final end =
          (index + _firestoreChunkSize) > values.length
              ? values.length
              : index + _firestoreChunkSize;
      chunks.add(values.sublist(index, end));
    }
    return chunks;
  }

  StaffAbsence _publicStaffAbsenceForCache(StaffAbsence absence) {
    return StaffAbsence(
      id: absence.id,
      salonId: absence.salonId,
      staffId: absence.staffId,
      type: absence.type,
      start: absence.start,
      end: absence.end,
      notes: null,
    );
  }

  Map<String, dynamic> _publicStaffAbsenceToMap(StaffAbsence absence) {
    return {
      'salonId': absence.salonId,
      'staffId': absence.staffId,
      'type': absence.type.name,
      'start': Timestamp.fromDate(absence.start),
      'end': Timestamp.fromDate(absence.end),
    };
  }

  Future<void> _syncPublicStaffAbsenceRemote(StaffAbsence absence) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }
    await firestore
        .collection('public_staff_absences')
        .doc(absence.id)
        .set(_publicStaffAbsenceToMap(absence));
  }

  void _ensurePublicMirrorsIfNeeded(AppUser user) {
    if (_hasEnsuredPublicMirrors) {
      return;
    }
    if (_firestore == null) {
      return;
    }
    if (user.role == UserRole.client || user.role == null) {
      return;
    }
    _hasEnsuredPublicMirrors = true;
    unawaited(_backfillPublicCollections(user));
  }

  Future<void> _backfillPublicCollections(AppUser user) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }
    final salonIds = _normalizedSalonIds(user);
    if (salonIds.isEmpty) {
      return;
    }
    try {
      for (final chunk in _splitIntoChunks(salonIds)) {
        final absencesSnapshot =
            await firestore
                .collection('staff_absences')
                .where('salonId', whereIn: chunk)
                .get();
        if (absencesSnapshot.docs.isNotEmpty) {
          final batch = firestore.batch();
          for (final doc in absencesSnapshot.docs) {
            final absence = staffAbsenceFromDoc(doc);
            batch.set(
              firestore.collection('public_staff_absences').doc(absence.id),
              _publicStaffAbsenceToMap(absence),
            );
          }
          await batch.commit();
        }
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Failed to backfill public availability: ${error.message}');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'AppDataStore',
          informationCollector:
              () => [DiagnosticsProperty<List<String>>('Salon IDs', salonIds)],
        ),
      );
    }
  }

  StreamSubscription _listenDocument<T>(
    DocumentReference<Map<String, dynamic>> reference,
    T Function(DocumentSnapshot<Map<String, dynamic>>) fromDoc,
    void Function(T?) onData,
  ) {
    return reference.snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          onData(fromDoc(snapshot));
        } else {
          onData(null);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          debugPrint(
            'Firestore permission denied for document ${reference.path}. Returning null.',
          );
          onData(null);
          return;
        }
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'AppDataStore',
            informationCollector:
                () => [
                  DiagnosticsProperty<String>(
                    'Failed document',
                    reference.path,
                  ),
                ],
          ),
        );
      },
    );
  }

  List<String> _normalizedSalonIds(AppUser user) {
    final result = <String>[];
    for (final id in user.salonIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || result.contains(trimmed)) {
        continue;
      }
      result.add(trimmed);
    }
    return result;
  }

  void _updateUsers(List<AppUser> users) {
    final merged = <String, AppUser>{};
    for (final user in users) {
      merged[user.uid] = user;
    }
    final current = _currentUser;
    if (current != null && !merged.containsKey(current.uid)) {
      merged[current.uid] = current;
    }
    state = state.copyWith(users: List.unmodifiable(merged.values));

    final role = _currentUser?.role;
    if (role == UserRole.admin || role == UserRole.staff) {
      state = state.copyWith(clientNotifications: const []);

      _scheduleClientOnboardingSync();
    }
  }

  void _onPromotionsData(List<Promotion> items) {
    _cachedPromotions = items;
    _refreshFeatureFilteredCollections();
  }

  void _onLastMinuteSlotsData(List<LastMinuteSlot> items) {
    _cachedLastMinuteSlots = items;
    _refreshFeatureFilteredCollections();
  }

  void _refreshFeatureFilteredCollections() {
    final sortedPromotions =
        _cachedPromotions.toList()..sort((a, b) {
          final priorityCompare = b.priority.compareTo(a.priority);
          if (priorityCompare != 0) {
            return priorityCompare;
          }
          final endA = a.endsAt ?? DateTime.utc(2100);
          final endB = b.endsAt ?? DateTime.utc(2100);
          final endCompare = endA.compareTo(endB);
          if (endCompare != 0) {
            return endCompare;
          }
          return a.id.compareTo(b.id);
        });

    final sortedLastMinuteSlots =
        _cachedLastMinuteSlots.toList()..sort((a, b) {
          final startCompare = a.start.compareTo(b.start);
          if (startCompare != 0) {
            return startCompare;
          }
          return a.id.compareTo(b.id);
        });

    state = state.copyWith(
      promotions: List.unmodifiable(sortedPromotions),
      lastMinuteSlots: List.unmodifiable(sortedLastMinuteSlots),
    );
  }

  Set<String> _enabledSalonIds(
    bool Function(SalonFeatureFlags flags) predicate,
  ) {
    final result = <String>{};
    for (final salon in state.salons) {
      if (!predicate(salon.featureFlags)) {
        continue;
      }
      final id = salon.id.trim();
      if (id.isEmpty) {
        continue;
      }
      result.add(id);
    }
    return result;
  }

  void _updateScopedStaffRoles(
    List<StaffRole> remoteRoles,
    Set<String> allowedSalonIds,
  ) {
    final normalizedSalonIds =
        allowedSalonIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();

    final merged = <String, StaffRole>{
      for (final role in MockData.staffRoles) role.id: role,
    };

    for (final role in remoteRoles) {
      final salonId = role.salonId?.trim();
      final include =
          role.isDefault ||
          (salonId != null &&
              salonId.isNotEmpty &&
              normalizedSalonIds.contains(salonId));
      if (!include) {
        continue;
      }
      merged[role.id] = role;
    }

    final sorted =
        merged.values.toList()..sort((a, b) {
          final priorityCompare = a.sortPriority.compareTo(b.sortPriority);
          if (priorityCompare != 0) {
            return priorityCompare;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

    state = state.copyWith(staffRoles: List.unmodifiable(sorted));
  }

  void _handleQueryError(
    Query<Map<String, dynamic>> query,
    Object error,
    StackTrace stackTrace, {
    VoidCallback? onPermissionDenied,
  }) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      debugPrint(
        'Firestore permission denied for query ${query.toString()}. Returning empty list.',
      );
      onPermissionDenied?.call();
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'AppDataStore',
        informationCollector:
            () => [
              DiagnosticsProperty<String>('Failed query', query.toString()),
            ],
      ),
    );
  }

  Future<void> _ensureCurrentUserLinkedToSalon(String salonId) async {
    final firestore = _firestore;
    final currentUser = _currentUser;
    if (firestore == null || currentUser == null) {
      return;
    }
    if (currentUser.role != UserRole.admin) {
      return;
    }
    final trimmedId = salonId.trim();
    if (trimmedId.isEmpty || currentUser.salonIds.contains(trimmedId)) {
      return;
    }
    await firestore.collection('users').doc(currentUser.uid).set({
      'salonIds': FieldValue.arrayUnion(<String>[trimmedId]),
    }, SetOptions(merge: true));
  }

  StreamSubscription _listenCollection<T>(
    Query<Map<String, dynamic>> query,
    T Function(DocumentSnapshot<Map<String, dynamic>>) fromDoc,
    void Function(List<T>) onData,
  ) {
    return query.snapshots().listen(
      (snapshot) {
        final items = snapshot.docs.map(fromDoc).toList(growable: false);
        onData(List.unmodifiable(items));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          debugPrint(
            'Firestore permission denied for query ${query.toString()}. Returning empty list.',
          );
          onData(List.unmodifiable(<T>[]));
          return;
        }
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'AppDataStore',
            informationCollector:
                () => [
                  DiagnosticsProperty<String>('Failed query', query.toString()),
                ],
          ),
        );
      },
    );
  }

  void _scheduleClientOnboardingSync() {
    if (_onboardingSyncScheduled ||
        _firestore == null ||
        !_hasAuthenticatedUser) {
      return;
    }
    if (state.clients.isEmpty || state.users.isEmpty) {
      return;
    }
    _onboardingSyncScheduled = true;
    scheduleMicrotask(() async {
      _onboardingSyncScheduled = false;
      await _syncClientOnboardingStatus();
    });
  }

  Future<void> _syncClientOnboardingStatus() async {
    if (_isSyncingOnboardingStatus) {
      return;
    }
    if (_firestore == null || !_hasAuthenticatedUser) {
      return;
    }
    if (state.clients.isEmpty || state.users.isEmpty) {
      return;
    }

    final users = state.users;
    final List<Client> updates = [];

    for (final client in state.clients) {
      final email = client.email?.toLowerCase();
      if (email == null || email.isEmpty) {
        continue;
      }

      final matchingUser = users.firstWhereOrNull((user) {
        final userEmail = user.email?.toLowerCase();
        if (userEmail == null || userEmail.isEmpty) {
          return false;
        }
        return user.role == UserRole.client && userEmail == email;
      });

      if (matchingUser == null) {
        continue;
      }

      var updatedClient = client;
      var changed = false;

      if (client.onboardingStatus == ClientOnboardingStatus.notSent ||
          client.onboardingStatus == ClientOnboardingStatus.invitationSent) {
        final timestamp = client.firstLoginAt ?? DateTime.now();
        updatedClient = updatedClient.copyWith(
          onboardingStatus: ClientOnboardingStatus.firstLogin,
          firstLoginAt: timestamp,
        );
        changed = true;
      } else if (client.onboardingStatus == ClientOnboardingStatus.firstLogin &&
          client.firstLoginAt == null) {
        updatedClient = updatedClient.copyWith(firstLoginAt: DateTime.now());
        changed = true;
      }

      final linkedToClient =
          matchingUser.clientId != null &&
          matchingUser.clientId!.isNotEmpty &&
          matchingUser.clientId == client.id;

      if (linkedToClient &&
          updatedClient.onboardingStatus !=
              ClientOnboardingStatus.onboardingCompleted) {
        final completedAt =
            updatedClient.onboardingCompletedAt ?? DateTime.now();
        updatedClient = updatedClient.copyWith(
          onboardingStatus: ClientOnboardingStatus.onboardingCompleted,
          onboardingCompletedAt: completedAt,
          firstLoginAt: updatedClient.firstLoginAt ?? completedAt,
        );
        changed = true;
      }

      if (changed) {
        updates.add(updatedClient);
      }
    }

    if (updates.isEmpty) {
      return;
    }

    _isSyncingOnboardingStatus = true;
    try {
      for (final client in updates) {
        await upsertClient(client);
      }
    } finally {
      _isSyncingOnboardingStatus = false;
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> upsertSalon(Salon salon) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(salons: [salon]);
      return;
    }
    await firestore.collection('salons').doc(salon.id).set(salonToMap(salon));
    await _ensureCurrentUserLinkedToSalon(salon.id);
  }

  Future<void> updateSalonFeatureFlags(
    String salonId,
    SalonFeatureFlags featureFlags,
  ) async {
    final firestore = _firestore;
    if (firestore != null) {
      await firestore.collection('salons').doc(salonId).set({
        'featureFlags': featureFlags.toMap(),
      }, SetOptions(merge: true));
    }

    final currentSalon = state.salons.firstWhereOrNull(
      (salon) => salon.id == salonId,
    );
    if (currentSalon != null) {
      final updatedSalon = currentSalon.copyWith(featureFlags: featureFlags);
      _upsertLocal(salons: <Salon>[updatedSalon]);
      _refreshFeatureFilteredCollections();
    }
  }

  Future<void> deleteSalon(String salonId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteSalonLocal(salonId);
      return;
    }
    final batch = firestore.batch();
    batch.delete(firestore.collection('salons').doc(salonId));
    await _deleteCollectionWhere('staff', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere('clients', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere('services', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere('packages', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere(
      'appointments',
      'salonId',
      salonId,
      batch: batch,
    );
    await _deleteCollectionWhere('inventory', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere('sales', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere('quotes', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere(
      'cash_flows',
      'salonId',
      salonId,
      batch: batch,
    );
    await _deleteCollectionWhere(
      'staff_roles',
      'salonId',
      salonId,
      batch: batch,
    );
    await _deleteCollectionWhere(
      'message_templates',
      'salonId',
      salonId,
      batch: batch,
    );
    await _deleteCollectionWhere('shifts', 'salonId', salonId, batch: batch);
    await _deleteCollectionWhere(
      'staff_absences',
      'salonId',
      salonId,
      batch: batch,
    );
    await batch.commit();
  }

  Future<void> upsertStaffRole(StaffRole role) async {
    final userRole = _currentUser?.role;
    final firestore = _firestore;
    if (firestore == null || userRole != UserRole.admin) {
      _upsertLocal(staffRoles: [role]);
      return;
    }
    try {
      await firestore
          .collection('staff_roles')
          .doc(role.id)
          .set(staffRoleToMap(role));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          'Permission denied writing staff role ${role.id}. Falling back to local update.',
        );
        _upsertLocal(staffRoles: [role]);
        return;
      }
      rethrow;
    }
  }

  Future<void> deleteStaffRole(String roleId) async {
    final userRole = _currentUser?.role;
    final firestore = _firestore;
    final fallbackRoleId = _resolveFallbackRoleId(roleId);
    if (firestore == null || userRole != UserRole.admin) {
      _deleteStaffRoleLocal(roleId, fallbackRoleId: fallbackRoleId);
      return;
    }

    try {
      final batch = firestore.batch();
      final rolesRef = firestore.collection('staff_roles').doc(roleId);
      batch.delete(rolesRef);

      final staffQuery =
          await firestore
              .collection('staff')
              .where('roleId', isEqualTo: roleId)
              .get();
      for (final doc in staffQuery.docs) {
        final data = doc.data();
        final rawRoleIds = data['roleIds'];
        final currentRoleIds =
            rawRoleIds is Iterable
                ? rawRoleIds
                    .map((dynamic value) => value.toString())
                    .where((value) => value != roleId)
                    .toList()
                : <String>[];
        if (currentRoleIds.contains(fallbackRoleId)) {
          currentRoleIds.removeWhere((value) => value == fallbackRoleId);
        }
        currentRoleIds.insert(0, fallbackRoleId);
        batch.update(doc.reference, {
          'roleId': fallbackRoleId,
          'role': fallbackRoleId,
          'roleIds': currentRoleIds,
        });
      }

      final servicesQuery =
          await firestore
              .collection('services')
              .where('staffRoles', arrayContains: roleId)
              .get();
      for (final doc in servicesQuery.docs) {
        final data = doc.data();
        final rawRoles = data['staffRoles'];
        final updatedRoles =
            rawRoles is Iterable
                ? rawRoles
                    .map((dynamic value) => value.toString())
                    .where((value) => value != roleId)
                    .toList()
                : const <String>[];
        batch.update(doc.reference, {'staffRoles': updatedRoles});
      }

      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          'Permission denied deleting staff role $roleId. Applying local fallback.',
        );
        _deleteStaffRoleLocal(roleId, fallbackRoleId: fallbackRoleId);
        return;
      }
      rethrow;
    }
  }

  Future<void> upsertStaff(StaffMember staffMember) async {
    final existingStaff = state.staff.firstWhereOrNull(
      (member) => member.id == staffMember.id,
    );
    final sanitizedRoleIdsSet = LinkedHashSet<String>();
    for (final roleId in staffMember.roleIds) {
      final trimmed = roleId.trim();
      if (trimmed.isNotEmpty) {
        sanitizedRoleIdsSet.add(trimmed);
      }
    }
    final sanitizedRoleIds = sanitizedRoleIdsSet.toList();
    if (sanitizedRoleIds.isEmpty) {
      sanitizedRoleIds.add(_resolveFallbackRoleId(''));
    }
    final normalizedStaff =
        listEquals(sanitizedRoleIds, staffMember.roleIds)
            ? staffMember
            : staffMember.copyWith(roleIds: sanitizedRoleIds);
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(staff: [normalizedStaff]);
      return;
    }
    await firestore
        .collection('staff')
        .doc(normalizedStaff.id)
        .set(staffToMap(normalizedStaff));
    await _ensureStaffUser(normalizedStaff, previous: existingStaff);
  }

  Future<void> deleteStaff(String staffId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteStaffLocal(staffId);
      return;
    }
    try {
      await firestore.collection('staff').doc(staffId).delete();
      final appointments =
          await firestore
              .collection('appointments')
              .where('staffId', isEqualTo: staffId)
              .get();
      for (final doc in appointments.docs) {
        await doc.reference.update({'staffId': ''});
      }
      final shifts =
          await firestore
              .collection('shifts')
              .where('staffId', isEqualTo: staffId)
              .get();
      for (final doc in shifts.docs) {
        await doc.reference.delete();
      }
      final absences =
          await firestore
              .collection('staff_absences')
              .where('staffId', isEqualTo: staffId)
              .get();
      for (final doc in absences.docs) {
        await doc.reference.delete();
      }
      final cashFlows =
          await firestore
              .collection('cash_flows')
              .where('staffId', isEqualTo: staffId)
              .get();
      for (final doc in cashFlows.docs) {
        await doc.reference.update({'staffId': null});
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          'Permission denied deleting staff $staffId. Applying local fallback.',
        );
        _deleteStaffLocal(staffId);
        return;
      }
      rethrow;
    }
  }

  Future<void> _ensureStaffUser(
    StaffMember staff, {
    StaffMember? previous,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }
    final email = staff.email?.trim();
    if (email == null || email.isEmpty) {
      return;
    }

    final usersCollection = firestore.collection('users');
    DocumentSnapshot<Map<String, dynamic>>? existingUserDoc;

    try {
      final existingByStaff =
          await usersCollection
              .where('staffId', isEqualTo: staff.id)
              .limit(1)
              .get();
      if (existingByStaff.docs.isNotEmpty) {
        existingUserDoc = existingByStaff.docs.first;
      } else {
        final existingByEmail =
            await usersCollection
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
        if (existingByEmail.docs.isNotEmpty) {
          existingUserDoc = existingByEmail.docs.first;
        }
      }

      if (existingUserDoc != null) {
        await usersCollection.doc(existingUserDoc.id).set({
          'staffId': staff.id,
          'displayName': staff.fullName,
          'email': email,
          'role': UserRole.staff.name,
          'roles': FieldValue.arrayUnion(<String>[UserRole.staff.name]),
          'availableRoles': FieldValue.arrayUnion(<String>[
            UserRole.staff.name,
          ]),
          'salonId': staff.salonId,
          'salonIds': FieldValue.arrayUnion(<String>[staff.salonId]),
        }, SetOptions(merge: true));
        return;
      }

      // Skip creating a new auth user if this is an update and we couldn't find
      // an existing account — assume onboarding will handle it.
      if (previous != null) {
        return;
      }

      final auth = await _getAdminAuth();
      if (auth == null) {
        return;
      }

      String? uid;
      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: _generateTemporaryPassword(),
        );
        uid = credential.user?.uid;
      } on FirebaseAuthException catch (error) {
        if (error.code == 'email-already-in-use') {
          final existingByEmail =
              await usersCollection
                  .where('email', isEqualTo: email)
                  .limit(1)
                  .get();
          if (existingByEmail.docs.isNotEmpty) {
            uid = existingByEmail.docs.first.id;
          }
        } else {
          debugPrint('Failed to create staff auth user: ${error.message}');
        }
      }

      if (uid == null) {
        return;
      }

      await usersCollection.doc(uid).set({
        'role': UserRole.staff.name,
        'roles': <String>[UserRole.staff.name],
        'availableRoles': <String>[UserRole.staff.name],
        'staffId': staff.id,
        'salonIds': <String>[staff.salonId],
        'salonId': staff.salonId,
        'displayName': staff.fullName,
        'email': email,
      });

      try {
        await auth.sendPasswordResetEmail(email: email);
      } on FirebaseAuthException catch (error) {
        debugPrint('Unable to send reset email to $email: ${error.message}');
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'AppDataStore',
          informationCollector:
              () => [
                DiagnosticsProperty<String>('Context', 'ensureStaffUser'),
                DiagnosticsProperty<String>('Staff ID', staff.id),
              ],
        ),
      );
    }
  }

  Future<void> upsertClient(Client client) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(clients: [client]);
      return;
    }
    await firestore
        .collection('clients')
        .doc(client.id)
        .set(clientToMap(client));
  }

  Future<void> upsertClientPhoto(ClientPhoto photo) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(clientPhotos: <ClientPhoto>[photo]);
      return;
    }
    await firestore
        .collection('client_photos')
        .doc(photo.id)
        .set(clientPhotoToMap(photo));
  }

  Future<void> deleteClient(String clientId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteClientLocal(clientId);
      return;
    }
    await firestore.collection('clients').doc(clientId).delete();
    await _deleteCollectionWhere('appointments', 'clientId', clientId);
    await _deleteCollectionWhere('sales', 'clientId', clientId);
    await _deleteCollectionWhere('payment_tickets', 'clientId', clientId);
    await _deleteCollectionWhere('client_photos', 'clientId', clientId);
    await _deleteCollectionWhere('quotes', 'clientId', clientId);
  }

  Future<void> deleteClientPhoto(String photoId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteClientPhotoLocal(photoId);
      return;
    }
    await firestore.collection('client_photos').doc(photoId).delete();
  }

  Future<void> upsertService(Service service) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(services: [service]);
      return;
    }
    await firestore
        .collection('services')
        .doc(service.id)
        .set(serviceToMap(service));
  }

  Future<void> upsertServiceCategory(ServiceCategory category) async {
    final previous = state.serviceCategories.firstWhereOrNull(
      (item) => item.id == category.id,
    );
    final hasNameChanged = previous == null || previous.name != category.name;
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(serviceCategories: [category]);
      if (hasNameChanged) {
        _updateLocalServicesCategoryName(
          categoryId: category.id,
          categoryName: category.name,
          previousCategoryName: previous?.name,
          salonId: category.salonId,
        );
      }
      return;
    }

    final isAdmin = _currentUser?.role == UserRole.admin;

    try {
      await firestore
          .collection('service_categories')
          .doc(category.id)
          .set(serviceCategoryToMap(category));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          'Permission denied writing service category ${category.id}.',
        );
        throw StateError('permission-denied');
      }
      rethrow;
    }

    _upsertLocal(serviceCategories: [category]);

    if (hasNameChanged && isAdmin) {
      try {
        await _syncServiceCategoryNameRemote(
          categoryId: category.id,
          categoryName: category.name,
        );
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          rethrow;
        }
        return;
      }
      _updateLocalServicesCategoryName(
        categoryId: category.id,
        categoryName: category.name,
        previousCategoryName: previous?.name,
        salonId: category.salonId,
      );
    }
  }

  Future<void> deleteServiceCategory(String categoryId) async {
    final category = state.serviceCategories.firstWhereOrNull(
      (item) => item.id == categoryId,
    );
    if (category == null) {
      return;
    }
    final isUsed = state.services.any((service) {
      if (service.salonId != category.salonId) {
        return false;
      }
      if (service.categoryId == categoryId) {
        return true;
      }
      return service.categoryId == null &&
          service.category.toLowerCase() == category.name.toLowerCase();
    });
    if (isUsed) {
      throw StateError('category-in-use');
    }

    final firestore = _firestore;
    if (firestore == null) {
      _deleteServiceCategoryLocal(categoryId);
      return;
    }
    try {
      await firestore.collection('service_categories').doc(categoryId).delete();
      _deleteServiceCategoryLocal(categoryId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Permission denied deleting service category $categoryId.');
        throw StateError('permission-denied');
      }
      rethrow;
    }
  }

  Future<void> deleteService(String serviceId) async {
    final firestore = _firestore;
    final service = state.services.firstWhereOrNull(
      (item) => item.id == serviceId,
    );
    String? salonId = service?.salonId;
    final hasAppointments = state.appointments.any(
      (appointment) => appointment.serviceIds.contains(serviceId),
    );
    if (hasAppointments) {
      throw StateError('service-in-appointments');
    }
    final isReferencedInPackages = state.packages.any(
      (package) => package.serviceIds.contains(serviceId),
    );
    if (isReferencedInPackages) {
      throw StateError('service-in-packages');
    }
    if (firestore == null) {
      _deleteServiceLocal(serviceId);
      return;
    }
    try {
      if (salonId == null || salonId.isEmpty) {
        final remoteSnapshot =
            await firestore.collection('services').doc(serviceId).get();
        final remoteData = remoteSnapshot.data();
        final remoteSalonId = remoteData != null ? remoteData['salonId'] : null;
        if (remoteSalonId is String && remoteSalonId.isNotEmpty) {
          salonId = remoteSalonId;
        }
      }
      await firestore.collection('services').doc(serviceId).delete();
      Query<Map<String, dynamic>> packagesQuery = firestore
          .collection('packages')
          .where('serviceIds', arrayContains: serviceId);
      if (salonId != null && salonId.isNotEmpty) {
        packagesQuery = packagesQuery.where('salonId', isEqualTo: salonId);
      }
      final packages = await packagesQuery.get();
      for (final doc in packages.docs) {
        final current = List<String>.from(
          doc.data()['serviceIds'] as List<dynamic>,
        );
        current.removeWhere((id) => id == serviceId);
        await doc.reference.update({'serviceIds': current});
      }
      await _deleteCollectionWhere('appointments', 'serviceId', serviceId);
      await _deleteCollectionWhere('payment_tickets', 'serviceId', serviceId);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint('Permission denied deleting service $serviceId.');
        throw StateError('permission-denied');
      }
      rethrow;
    }

    _deleteServiceLocal(serviceId);
  }

  Future<void> upsertPackage(ServicePackage servicePackage) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(packages: [servicePackage]);
      return;
    }
    await firestore
        .collection('packages')
        .doc(servicePackage.id)
        .set(packageToMap(servicePackage));
  }

  Future<void> deletePackage(String packageId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deletePackageLocal(packageId);
      return;
    }
    await firestore.collection('packages').doc(packageId).delete();
  }

  Future<void> upsertPromotion(Promotion promotion) async {
    final firestore = _firestore;
    final payload = promotionToMap(promotion);
    if (firestore != null) {
      await firestore
          .collection('promotions')
          .doc(promotion.id)
          .set(payload, SetOptions(merge: true));
    }
    _cachedPromotions = _merge(_cachedPromotions, <Promotion>[
      promotion,
    ], (item) => item.id);
    _upsertLocal(promotions: <Promotion>[promotion]);
    _refreshFeatureFilteredCollections();
  }

  Future<void> deletePromotion(String promotionId) async {
    final firestore = _firestore;
    if (firestore != null) {
      await firestore.collection('promotions').doc(promotionId).delete();
    }
    _deletePromotionLocal(promotionId);
    _cachedPromotions =
        _cachedPromotions.where((item) => item.id != promotionId).toList();
    _refreshFeatureFilteredCollections();
  }

  Future<void> upsertLastMinuteSlot(LastMinuteSlot slot) async {
    final staffId = slot.operatorId?.trim();
    if (staffId == null || staffId.isEmpty) {
      throw StateError('Seleziona un operatore per lo slot last-minute.');
    }
    final now = DateTime.now();
    final slotEnd = slot.end;
    final hasStaffConflict =
        slot.isAvailable &&
        hasStaffBookingConflict(
          appointments: state.appointments,
          staffId: staffId,
          start: slot.start,
          end: slotEnd,
        );
    if (hasStaffConflict) {
      throw StateError('Operatore già occupato in quell\'intervallo.');
    }
    final overlappingSlot =
        slot.isAvailable
            ? _cachedLastMinuteSlots.firstWhereOrNull((existing) {
              if (existing.id == slot.id) {
                return false;
              }
              if (existing.operatorId != staffId) {
                return false;
              }
              if (!existing.isAvailable) {
                return false;
              }
              if (!existing.end.isAfter(now)) {
                return false;
              }
              return appointmentsOverlap(
                start: existing.start,
                end: existing.end,
                otherStart: slot.start,
                otherEnd: slotEnd,
              );
            })
            : null;
    if (overlappingSlot != null) {
      throw StateError('Esiste già uno slot last-minute per questo orario.');
    }

    final firestore = _firestore;
    final payload = lastMinuteSlotToMap(slot);
    if (firestore != null) {
      await firestore
          .collection('last_minute_slots')
          .doc(slot.id)
          .set(payload, SetOptions(merge: true));
    }
    _cachedLastMinuteSlots = _merge(_cachedLastMinuteSlots, <LastMinuteSlot>[
      slot,
    ], (item) => item.id);
    _upsertLocal(lastMinuteSlots: <LastMinuteSlot>[slot]);
    _refreshFeatureFilteredCollections();
  }

  Future<void> deleteLastMinuteSlot(String slotId) async {
    final firestore = _firestore;
    if (firestore != null) {
      await firestore.collection('last_minute_slots').doc(slotId).delete();
    }
    _deleteLastMinuteSlotLocal(slotId);
    _cachedLastMinuteSlots =
        _cachedLastMinuteSlots.where((item) => item.id != slotId).toList();
    _refreshFeatureFilteredCollections();
  }

  Future<_LastMinuteBookingResult> _bookLastMinuteAppointment(
    Appointment appointment,
    String slotId,
  ) async {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable('bookLastMinuteSlot');

    final clientName =
        state.clients
            .firstWhereOrNull((client) => client.id == appointment.clientId)
            ?.fullName;

    final payload = {
      'slotId': slotId,
      'appointment': {
        'id': appointment.id,
        'salonId': appointment.salonId,
        'clientId': appointment.clientId,
        'staffId': appointment.staffId,
        'serviceId':
            appointment.serviceId.isNotEmpty ? appointment.serviceId : null,
        'serviceIds': appointment.serviceIds,
        'start': appointment.start.toUtc().toIso8601String(),
        'end': appointment.end.toUtc().toIso8601String(),
        'status': appointment.status.name,
        'notes': appointment.notes,
        'packageId': appointment.packageId,
        'roomId': appointment.roomId,
      },
      'clientName': clientName,
    };

    try {
      final response = await callable.call(payload);
      final data = Map<String, dynamic>.from(response.data as Map);
      final appointmentMap = Map<String, dynamic>.from(
        data['appointment'] as Map,
      );
      final slotMap =
          data['slot'] != null
              ? Map<String, dynamic>.from(data['slot'] as Map)
              : null;

      final bookedAppointment = _appointmentFromCallableMap(appointmentMap);
      final bookedSlot = slotMap != null ? _slotFromCallableMap(slotMap) : null;

      return _LastMinuteBookingResult(
        appointment: bookedAppointment,
        slot: bookedSlot,
      );
    } on FirebaseFunctionsException catch (error) {
      final message = error.message ?? 'Slot last-minute non disponibile.';
      throw StateError(message);
    } catch (error) {
      throw StateError('Prenotazione last-minute non riuscita: $error');
    }
  }

  Future<void> upsertAppointment(
    Appointment appointment, {
    String? consumeLastMinuteSlotId,
  }) async {
    final isAdmin = _currentUser?.role == UserRole.admin;

    if (!isAdmin && consumeLastMinuteSlotId != null) {
      final bookingResult = await _bookLastMinuteAppointment(
        appointment,
        consumeLastMinuteSlotId,
      );
      _upsertLocal(
        appointments: <Appointment>[bookingResult.appointment],
        lastMinuteSlots:
            bookingResult.slot != null
                ? <LastMinuteSlot>[bookingResult.slot!]
                : null,
      );
      return;
    }

    final resolvedAppointment = appointment.copyWith(
      lastMinuteSlotId: appointment.lastMinuteSlotId ?? consumeLastMinuteSlotId,
    );

    final previous = state.appointments.firstWhereOrNull(
      (item) => item.id == resolvedAppointment.id,
    );
    final now = DateTime.now();
    if (resolvedAppointment.end.isAfter(now)) {
      final combinedAppointments = <Appointment>[
        ...state.appointments,
        ..._blockingLastMinuteAppointments(
          salonId: resolvedAppointment.salonId,
          staffId: resolvedAppointment.staffId,
          ignoreSlotId: consumeLastMinuteSlotId,
          reference: now,
        ),
      ];
      final hasStaffConflict = hasStaffBookingConflict(
        appointments: combinedAppointments,
        staffId: resolvedAppointment.staffId,
        start: resolvedAppointment.start,
        end: resolvedAppointment.end,
        excludeAppointmentId: resolvedAppointment.id,
      );
      if (hasStaffConflict) {
        throw StateError('Operatore già occupato in quel periodo');
      }
      final hasClientConflict = hasClientBookingConflict(
        appointments: state.appointments,
        clientId: resolvedAppointment.clientId,
        start: resolvedAppointment.start,
        end: resolvedAppointment.end,
        excludeAppointmentId: resolvedAppointment.id,
      );
      if (hasClientConflict) {
        throw StateError('Cliente già impegnato in quel periodo');
      }
    }
    final shouldConsumeSession =
        resolvedAppointment.packageId != null &&
        resolvedAppointment.status == AppointmentStatus.completed &&
        (previous == null || previous.status != AppointmentStatus.completed);
    if (shouldConsumeSession) {
      await _consumePackageSession(resolvedAppointment);
    }

    final shouldCreateTicket = _shouldCreatePaymentTicket(
      appointment: resolvedAppointment,
      previous: previous,
    );
    final shouldRemoveTicket =
        previous?.status == AppointmentStatus.completed &&
        resolvedAppointment.status != AppointmentStatus.completed;
    final ticket =
        shouldCreateTicket ? _buildPaymentTicket(resolvedAppointment) : null;

    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(
        appointments: <Appointment>[resolvedAppointment],
        paymentTickets: ticket != null ? [ticket] : null,
      );
      if (shouldRemoveTicket) {
        _deletePaymentTicketLocal(resolvedAppointment.id);
      }
      await _markLastMinuteSlotBooking(
        slotId: consumeLastMinuteSlotId,
        appointment: resolvedAppointment,
      );
      return;
    }
    await firestore
        .collection('appointments')
        .doc(resolvedAppointment.id)
        .set(appointmentToMap(resolvedAppointment));
    if (ticket != null) {
      await upsertPaymentTicket(ticket);
    }
    if (shouldRemoveTicket) {
      await deletePaymentTicket(resolvedAppointment.id);
    }
    await _markLastMinuteSlotBooking(
      slotId: consumeLastMinuteSlotId,
      appointment: resolvedAppointment,
    );
  }

  bool _shouldCreatePaymentTicket({
    required Appointment appointment,
    Appointment? previous,
  }) {
    if (appointment.status != AppointmentStatus.completed) {
      return false;
    }
    if (appointment.packageId != null) {
      return false;
    }
    if (previous?.status == AppointmentStatus.completed) {
      return false;
    }
    final existingTicket = state.paymentTickets.firstWhereOrNull(
      (ticket) => ticket.appointmentId == appointment.id,
    );
    if (existingTicket != null) {
      return false;
    }
    return true;
  }

  PaymentTicket _buildTicketFromQuote(Quote quote, String ticketId) {
    final now = DateTime.now();
    final primaryItem = quote.items.isNotEmpty ? quote.items.first : null;
    final fallbackName =
        quote.number != null ? 'Preventivo ${quote.number}' : 'Preventivo';
    final serviceName =
        quote.title?.isNotEmpty == true
            ? quote.title!
            : (primaryItem?.description ?? fallbackName);
    final serviceId =
        (primaryItem?.serviceId != null && primaryItem!.serviceId!.isNotEmpty)
            ? primaryItem.serviceId!
            : ticketId;

    return PaymentTicket(
      id: ticketId,
      salonId: quote.salonId,
      appointmentId: ticketId,
      clientId: quote.clientId,
      serviceId: serviceId,
      staffId: null,
      appointmentStart: now,
      appointmentEnd: now,
      createdAt: now,
      status: PaymentTicketStatus.open,
      expectedTotal: quote.total,
      serviceName: serviceName,
      notes: quote.notes,
    );
  }

  PaymentTicket _buildPaymentTicket(Appointment appointment) {
    final services =
        appointment.serviceIds
            .map(
              (serviceId) => state.services.firstWhereOrNull(
                (item) => item.id == serviceId,
              ),
            )
            .whereType<Service>()
            .toList();
    final service = services.isNotEmpty ? services.first : null;
    final aggregatedName =
        services.isEmpty
            ? service?.name
            : services.map((s) => s.name).join(' + ');
    final aggregatedPrice =
        services.isEmpty
            ? service?.price
            : services.fold<double>(0, (sum, srv) => sum + srv.price);
    return PaymentTicket(
      id: appointment.id,
      salonId: appointment.salonId,
      appointmentId: appointment.id,
      clientId: appointment.clientId,
      serviceId: appointment.serviceId,
      staffId: appointment.staffId,
      appointmentStart: appointment.start,
      appointmentEnd: appointment.end,
      createdAt: DateTime.now(),
      expectedTotal: aggregatedPrice,
      serviceName: aggregatedName,
      notes: appointment.notes,
    );
  }

  Future<void> _consumePackageSession(Appointment appointment) async {
    final packageId = appointment.packageId;
    if (packageId == null) {
      return;
    }

    if (appointment.serviceIds.length != 1) {
      return;
    }

    final relevantSales = state.sales.where(
      (sale) =>
          sale.clientId == appointment.clientId &&
          sale.salonId == appointment.salonId,
    );

    if (relevantSales.isEmpty) {
      return;
    }

    final packageIndex = {for (final pkg in state.packages) pkg.id: pkg};

    final candidates = <_PackageConsumptionCandidate>[];
    for (final sale in relevantSales) {
      for (var index = 0; index < sale.items.length; index++) {
        final item = sale.items[index];
        if (item.referenceType != SaleReferenceType.package) {
          continue;
        }
        if (item.referenceId != packageId) {
          continue;
        }

        final matchedPackage = packageIndex[item.referenceId];
        if (!_packageSupportsService(
          item,
          matchedPackage,
          appointment.serviceId,
        )) {
          continue;
        }

        final totalSessions = _computePackageTotalSessions(
          item,
          matchedPackage,
        );
        if (totalSessions == null || totalSessions <= 0) {
          continue;
        }

        final remainingSessions = item.remainingSessions ?? totalSessions;
        if (remainingSessions <= 0) {
          continue;
        }

        final expirationDate = _packageExpirationDate(
          sale,
          item,
          matchedPackage,
        );

        candidates.add(
          _PackageConsumptionCandidate(
            sale: sale,
            item: item,
            itemIndex: index,
            totalSessions: totalSessions,
            remainingSessions: remainingSessions,
            expirationDate: expirationDate,
            servicePackage: matchedPackage,
          ),
        );
      }
    }

    if (candidates.isEmpty) {
      return;
    }

    candidates.sort((a, b) {
      final aExpiration = a.expirationDate ?? DateTime(9999, 1, 1);
      final bExpiration = b.expirationDate ?? DateTime(9999, 1, 1);
      final expirationCompare = aExpiration.compareTo(bExpiration);
      if (expirationCompare != 0) {
        return expirationCompare;
      }
      return a.sale.createdAt.compareTo(b.sale.createdAt);
    });

    final bestCandidate = candidates.first;
    final updatedRemaining = bestCandidate.remainingSessions - 1;
    final clampedRemaining = updatedRemaining < 0 ? 0 : updatedRemaining;
    final currentStatus = bestCandidate.item.packageStatus;
    PackagePurchaseStatus? nextStatus;
    if (currentStatus == PackagePurchaseStatus.cancelled) {
      nextStatus = PackagePurchaseStatus.cancelled;
    } else if (clampedRemaining <= 0) {
      nextStatus = PackagePurchaseStatus.completed;
    } else if (currentStatus == null) {
      nextStatus = PackagePurchaseStatus.active;
    }

    final updatedItem = bestCandidate.item.copyWith(
      remainingSessions: clampedRemaining,
      packageStatus: nextStatus ?? currentStatus,
    );

    final updatedItems = bestCandidate.sale.items.toList(growable: true);
    updatedItems[bestCandidate.itemIndex] = updatedItem;
    final updatedSale = bestCandidate.sale.copyWith(items: updatedItems);

    await upsertSale(updatedSale);
  }

  int? _computePackageTotalSessions(
    SaleItem item,
    ServicePackage? servicePackage,
  ) {
    if (item.totalSessions != null) {
      return item.totalSessions;
    }

    int? sessionsPerPackage;
    if (item.packageServiceSessions.isNotEmpty) {
      sessionsPerPackage = item.packageServiceSessions.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
    }

    sessionsPerPackage ??=
        servicePackage?.totalConfiguredSessions ?? servicePackage?.sessionCount;

    if (sessionsPerPackage == null) {
      return null;
    }

    return (sessionsPerPackage * item.quantity).round();
  }

  bool _packageSupportsService(
    SaleItem item,
    ServicePackage? servicePackage,
    String serviceId,
  ) {
    if (item.packageServiceSessions.isNotEmpty) {
      return item.packageServiceSessions.containsKey(serviceId);
    }

    final configuredSessions = servicePackage?.serviceSessionCounts;
    if (configuredSessions != null && configuredSessions.isNotEmpty) {
      return configuredSessions.containsKey(serviceId);
    }

    final configuredServices = servicePackage?.serviceIds;
    if (configuredServices != null && configuredServices.isNotEmpty) {
      return configuredServices.contains(serviceId);
    }

    return true;
  }

  DateTime? _packageExpirationDate(
    Sale sale,
    SaleItem item,
    ServicePackage? servicePackage,
  ) {
    if (item.expirationDate != null) {
      return item.expirationDate;
    }
    final validDays = servicePackage?.validDays;
    if (validDays == null) {
      return null;
    }
    return sale.createdAt.add(Duration(days: validDays));
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteAppointmentLocal(appointmentId);
      await deletePaymentTicket(appointmentId);
      return;
    }
    await firestore.collection('appointments').doc(appointmentId).delete();
    await firestore
        .collection('public_appointments')
        .doc(appointmentId)
        .delete();
    _deleteAppointmentLocal(appointmentId);
    await deletePaymentTicket(appointmentId);
  }

  Future<void> upsertQuote(Quote quote) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(quotes: <Quote>[quote]);
      return;
    }
    await firestore.collection('quotes').doc(quote.id).set(quoteToMap(quote));
    _upsertLocal(quotes: <Quote>[quote]);
  }

  Future<void> deleteQuote(String quoteId) async {
    final existing = state.quotes.firstWhereOrNull(
      (item) => item.id == quoteId,
    );
    final ticketId = existing?.ticketId;
    final firestore = _firestore;
    if (firestore == null) {
      _deleteQuoteLocal(quoteId);
      if (ticketId != null && ticketId.isNotEmpty) {
        _deletePaymentTicketLocal(ticketId);
      }
      return;
    }
    await firestore.collection('quotes').doc(quoteId).delete();
    _deleteQuoteLocal(quoteId);
    if (ticketId != null && ticketId.isNotEmpty) {
      await deletePaymentTicket(ticketId);
    }
  }

  Future<void> markQuoteSent(
    String quoteId, {
    required List<MessageChannel> viaChannels,
    DateTime? sentAt,
    String? pdfStoragePath,
  }) async {
    final quote = state.quotes.firstWhereOrNull((item) => item.id == quoteId);
    if (quote == null) {
      throw StateError('Preventivo non trovato');
    }
    final now = sentAt ?? DateTime.now();
    final updated = quote.copyWith(
      status:
          quote.status == QuoteStatus.accepted
              ? quote.status
              : QuoteStatus.sent,
      sentAt: now,
      sentChannels: viaChannels,
      acceptedAt: quote.acceptedAt,
      declinedAt: null,
      pdfStoragePath: pdfStoragePath,
      updatedAt: now,
    );
    await upsertQuote(updated);
  }

  Future<void> markQuoteSentManual(String quoteId) async {
    final quote = state.quotes.firstWhereOrNull((item) => item.id == quoteId);
    if (quote == null) {
      throw StateError('Preventivo non trovato');
    }
    if (quote.status == QuoteStatus.accepted ||
        quote.status == QuoteStatus.declined) {
      return;
    }
    final now = DateTime.now();
    final updated = quote.copyWith(
      status: QuoteStatus.sent,
      sentAt: now,
      sentChannels: quote.sentChannels,
      updatedAt: now,
    );
    await upsertQuote(updated);
  }

  Future<void> acceptQuote(String quoteId) async {
    final quote = state.quotes.firstWhereOrNull((item) => item.id == quoteId);
    if (quote == null) {
      throw StateError('Preventivo non trovato');
    }
    if (quote.status == QuoteStatus.accepted) {
      return;
    }
    final now = DateTime.now();
    final sale = _buildSaleFromQuote(quote, now);
    final ticketId = quote.ticketId ?? 'quote-${quote.id}';
    final existingTicket = state.paymentTickets.firstWhereOrNull(
      (ticket) => ticket.id == ticketId,
    );
    final ticket = (existingTicket ?? _buildTicketFromQuote(quote, ticketId))
        .copyWith(
          status: PaymentTicketStatus.closed,
          closedAt: now,
          saleId: sale.id,
          expectedTotal: sale.total,
          notes: quote.notes,
          serviceName:
              quote.title?.isNotEmpty == true
                  ? quote.title
                  : (existingTicket?.serviceName ??
                      (quote.items.isNotEmpty
                          ? quote.items.first.description
                          : 'Preventivo')),
        );
    final updated = quote.copyWith(
      status: QuoteStatus.accepted,
      acceptedAt: now,
      declinedAt: null,
      ticketId: ticketId,
      saleId: sale.id,
      updatedAt: now,
    );
    await upsertSale(sale);
    await upsertQuote(updated);
    await upsertPaymentTicket(ticket);
  }

  Sale _buildSaleFromQuote(Quote quote, DateTime saleDate) {
    final servicesById = {
      for (final service in state.services) service.id: service,
    };
    final packagesById = {for (final pkg in state.packages) pkg.id: pkg};
    final saleItems = <SaleItem>[];
    for (final item in quote.items) {
      saleItems.add(
        _saleItemFromQuoteItem(
          quote: quote,
          item: item,
          saleDate: saleDate,
          servicesById: servicesById,
          packagesById: packagesById,
        ),
      );
    }
    final total = double.parse(
      saleItems
          .fold<double>(0, (sum, entry) => sum + entry.amount)
          .toStringAsFixed(2),
    );
    return Sale(
      id: const Uuid().v4(),
      salonId: quote.salonId,
      clientId: quote.clientId,
      items: saleItems,
      total: total,
      createdAt: saleDate,
      paymentStatus: SalePaymentStatus.deposit,
      paidAmount: 0,
      notes: quote.notes,
    );
  }

  SaleItem _saleItemFromQuoteItem({
    required Quote quote,
    required QuoteItem item,
    required DateTime saleDate,
    required Map<String, Service> servicesById,
    required Map<String, ServicePackage> packagesById,
  }) {
    final quantity = double.parse(item.quantity.toStringAsFixed(2));
    final unitPrice = double.parse(item.unitPrice.toStringAsFixed(2));
    final packageId = item.packageId;
    if (packageId != null && packageId.isNotEmpty) {
      final package = packagesById[packageId];
      final serviceSessions =
          package?.serviceSessionCounts ?? const <String, int>{};
      final perPackageSessions = package?.totalConfiguredSessions;
      int? totalSessions;
      if (perPackageSessions != null) {
        final computed = perPackageSessions * quantity;
        if (computed.isFinite) {
          totalSessions = computed.round();
        }
      }
      final expiration =
          package?.validDays != null
              ? saleDate.add(Duration(days: package!.validDays!))
              : null;
      return SaleItem(
        referenceId: packageId,
        referenceType: SaleReferenceType.package,
        description: item.description,
        quantity: quantity,
        unitPrice: unitPrice,
        totalSessions: totalSessions,
        remainingSessions: totalSessions,
        packageStatus: PackagePurchaseStatus.active,
        packagePaymentStatus: PackagePaymentStatus.deposit,
        expirationDate: expiration,
        packageServiceSessions: serviceSessions,
      );
    }

    final serviceId = item.serviceId;
    if (serviceId != null && serviceId.isNotEmpty) {
      final service = servicesById[serviceId];
      final description =
          item.description.isNotEmpty
              ? item.description
              : (service?.name ?? 'Servizio');
      return SaleItem(
        referenceId: serviceId,
        referenceType: SaleReferenceType.service,
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
      );
    }

    final fallbackId = 'quote-${quote.id}-${item.id}';
    return SaleItem(
      referenceId: fallbackId,
      referenceType: SaleReferenceType.service,
      description: item.description,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  Future<void> declineQuote(String quoteId) async {
    final quote = state.quotes.firstWhereOrNull((item) => item.id == quoteId);
    if (quote == null) {
      throw StateError('Preventivo non trovato');
    }
    if (quote.status == QuoteStatus.declined) {
      return;
    }
    final now = DateTime.now();
    final updated = quote.copyWith(
      status: QuoteStatus.declined,
      declinedAt: now,
      acceptedAt: null,
      updatedAt: now,
    );
    await upsertQuote(updated);
  }

  Future<void> upsertInventoryItem(InventoryItem item) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(inventoryItems: [item]);
      return;
    }
    await firestore
        .collection('inventory')
        .doc(item.id)
        .set(inventoryToMap(item));
  }

  Future<void> deleteInventoryItem(String itemId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteInventoryItemLocal(itemId);
      return;
    }
    await firestore.collection('inventory').doc(itemId).delete();
  }

  Future<void> upsertSale(Sale sale) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(sales: [sale]);
      return;
    }
    await firestore.collection('sales').doc(sale.id).set(saleToMap(sale));
    _upsertLocal(sales: [sale]);
  }

  Future<void> deleteSale(String saleId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteSaleLocal(saleId);
      return;
    }
    await firestore.collection('sales').doc(saleId).delete();
  }

  Future<void> upsertPaymentTicket(PaymentTicket ticket) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(paymentTickets: [ticket]);
      return;
    }
    await firestore
        .collection('payment_tickets')
        .doc(ticket.id)
        .set(paymentTicketToMap(ticket));
    _upsertLocal(paymentTickets: [ticket]);
  }

  Future<void> deletePaymentTicket(String ticketId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deletePaymentTicketLocal(ticketId);
      return;
    }
    await firestore.collection('payment_tickets').doc(ticketId).delete();
    _deletePaymentTicketLocal(ticketId);
  }

  Future<void> closePaymentTicket(String ticketId, {String? saleId}) async {
    final ticket = state.paymentTickets.firstWhereOrNull(
      (item) => item.id == ticketId,
    );
    if (ticket == null || ticket.status == PaymentTicketStatus.closed) {
      return;
    }
    final updated = ticket.copyWith(
      status: PaymentTicketStatus.closed,
      closedAt: DateTime.now(),
      saleId: saleId ?? ticket.saleId,
    );
    await upsertPaymentTicket(updated);
  }

  Future<void> upsertCashFlowEntry(CashFlowEntry entry) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(cashFlowEntries: [entry]);
      return;
    }
    await firestore
        .collection('cash_flows')
        .doc(entry.id)
        .set(cashFlowToMap(entry));
    _upsertLocal(cashFlowEntries: [entry]);
  }

  Future<void> deleteCashFlowEntry(String entryId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteCashFlowEntryLocal(entryId);
      return;
    }
    await firestore.collection('cash_flows').doc(entryId).delete();
  }

  Future<void> upsertTemplate(MessageTemplate template) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(messageTemplates: [template]);
      return;
    }
    await firestore
        .collection('message_templates')
        .doc(template.id)
        .set(messageTemplateToMap(template));
  }

  Future<void> upsertClientQuestionnaireTemplate(
    ClientQuestionnaireTemplate template,
  ) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(
        clientQuestionnaireTemplates: <ClientQuestionnaireTemplate>[template],
      );
      return;
    }
    await firestore
        .collection('client_questionnaire_templates')
        .doc(template.id)
        .set(clientQuestionnaireTemplateToMap(template));
  }

  Future<void> deleteClientQuestionnaireTemplate(String templateId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteClientQuestionnaireTemplateLocal(templateId);
      return;
    }
    await firestore
        .collection('client_questionnaire_templates')
        .doc(templateId)
        .delete();
  }

  Future<void> upsertClientQuestionnaire(
    ClientQuestionnaire questionnaire,
  ) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(clientQuestionnaires: <ClientQuestionnaire>[questionnaire]);
      return;
    }
    await firestore
        .collection('client_questionnaires')
        .doc(questionnaire.id)
        .set(clientQuestionnaireToMap(questionnaire));
  }

  Future<void> deleteClientQuestionnaire(String questionnaireId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteClientQuestionnaireLocal(questionnaireId);
      return;
    }
    await firestore
        .collection('client_questionnaires')
        .doc(questionnaireId)
        .delete();
  }

  Future<void> upsertReminderSettings(ReminderSettings settings) async {
    final now = DateTime.now();
    final updated = settings.copyWith(
      updatedAt: now,
      updatedBy: _currentUser?.uid,
    );

    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(reminderSettings: [updated]);
      return;
    }

    await firestore
        .collection('reminder_settings')
        .doc(updated.salonId)
        .set(reminderSettingsToMap(updated), SetOptions(merge: true));

    _upsertLocal(reminderSettings: [updated]);
  }

  Future<void> registerClientPushToken({
    required String clientId,
    required String token,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    final existingClient = state.clients.firstWhereOrNull(
      (client) => client.id == clientId,
    );
    final existingTokens = existingClient?.fcmTokens ?? const <String>[];
    if (existingTokens.contains(normalizedToken)) {
      return;
    }

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('clients').doc(clientId).set({
          'fcmTokens': FieldValue.arrayUnion(<String>[normalizedToken]),
        }, SetOptions(merge: true));
      } on FirebaseException catch (error, stackTrace) {
        if (error.code == 'permission-denied') {
          debugPrint(
            'Permission denied while registering push token: ${error.message}',
          );
          return;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    final updatedClientTokens = <String>{
      ...existingTokens,
      normalizedToken,
    }.toList(growable: false);
    final updatedClient = existingClient?.copyWith(
      fcmTokens: List<String>.unmodifiable(updatedClientTokens),
    );

    if (updatedClient != null) {
      _upsertLocal(clients: <Client>[updatedClient]);
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteTemplateLocal(templateId);
      return;
    }
    await firestore.collection('message_templates').doc(templateId).delete();
  }

  Future<void> upsertShift(Shift shift) async {
    await upsertShifts([shift]);
  }

  Future<void> upsertShifts(List<Shift> shifts) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(shifts: shifts);
      return;
    }
    final batch = firestore.batch();
    for (final shift in shifts) {
      batch.set(
        firestore.collection('shifts').doc(shift.id),
        shiftToMap(shift),
      );
    }
    await batch.commit();
  }

  Future<void> deleteShift(String shiftId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteShiftLocal(shiftId);
      return;
    }
    await firestore.collection('shifts').doc(shiftId).delete();
  }

  Future<void> deleteShiftsByIds(Iterable<String> shiftIds) async {
    final normalized =
        shiftIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (normalized.isEmpty) {
      return;
    }
    final firestore = _firestore;
    if (firestore == null) {
      for (final id in normalized) {
        _deleteShiftLocal(id);
      }
      return;
    }
    final batch = firestore.batch();
    for (final id in normalized) {
      batch.delete(firestore.collection('shifts').doc(id));
    }
    await batch.commit();
  }

  Future<void> upsertStaffAbsence(StaffAbsence absence) async {
    final firestore = _firestore;
    if (firestore == null) {
      _upsertLocal(
        staffAbsences: [absence],
        publicStaffAbsences: [_publicStaffAbsenceForCache(absence)],
      );
      return;
    }
    await firestore
        .collection('staff_absences')
        .doc(absence.id)
        .set(staffAbsenceToMap(absence));
    await _syncPublicStaffAbsenceRemote(absence);
  }

  Future<void> deleteStaffAbsence(String absenceId) async {
    final firestore = _firestore;
    if (firestore == null) {
      _deleteStaffAbsenceLocal(absenceId);
      return;
    }
    await firestore.collection('staff_absences').doc(absenceId).delete();
    await firestore.collection('public_staff_absences').doc(absenceId).delete();
    _deleteStaffAbsenceLocal(absenceId);
  }

  Future<void> seedWithMockDataIfEmpty() async {
    final firestore = _firestore;
    if (firestore == null || !_hasAuthenticatedUser) {
      return;
    }
    try {
      final salonsSnapshot =
          await firestore.collection('salons').limit(1).get();
      if (salonsSnapshot.docs.isNotEmpty) {
        return;
      }
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied') {
        debugPrint('Skipping mock data seed: ${error.message}');
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    for (final salon in MockData.salons) {
      await upsertSalon(salon);
    }
    for (final role in MockData.staffRoles) {
      await upsertStaffRole(role);
    }
    for (final staff in MockData.staffMembers) {
      await upsertStaff(staff);
    }
    for (final client in MockData.clients) {
      await upsertClient(client);
    }
    for (final photo in MockData.clientPhotos) {
      await upsertClientPhoto(photo);
    }
    for (final category in MockData.serviceCategories) {
      await upsertServiceCategory(category);
    }
    for (final service in MockData.services) {
      await upsertService(service);
    }
    for (final pkg in MockData.packages) {
      await upsertPackage(pkg);
    }
    for (final appointment in MockData.appointments) {
      await upsertAppointment(appointment);
    }
    for (final quote in MockData.quotes) {
      await upsertQuote(quote);
    }
    for (final item in MockData.inventoryItems) {
      await upsertInventoryItem(item);
    }
    for (final sale in MockData.sales) {
      await upsertSale(sale);
    }
    for (final ticket in MockData.paymentTickets) {
      await upsertPaymentTicket(ticket);
    }
    for (final entry in MockData.cashFlowEntries) {
      await upsertCashFlowEntry(entry);
    }
    for (final template in MockData.messageTemplates) {
      await upsertTemplate(template);
    }
    for (final template in MockData.clientQuestionnaireTemplates) {
      await upsertClientQuestionnaireTemplate(template);
    }
    for (final settings in MockData.reminderSettings) {
      await upsertReminderSettings(settings);
    }
    for (final shift in MockData.shifts) {
      await upsertShift(shift);
    }
    for (final absence in MockData.staffAbsences) {
      await upsertStaffAbsence(absence);
    }
    for (final questionnaire in MockData.clientQuestionnaires) {
      await upsertClientQuestionnaire(questionnaire);
    }
  }

  Future<void> _deleteCollectionWhere(
    String collection,
    String field,
    String value, {
    WriteBatch? batch,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }
    final querySnapshot =
        await firestore
            .collection(collection)
            .where(field, isEqualTo: value)
            .get();
    if (batch != null) {
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
    } else {
      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  void _upsertLocal({
    List<Salon>? salons,
    List<StaffMember>? staff,
    List<StaffRole>? staffRoles,
    List<Client>? clients,
    List<ServiceCategory>? serviceCategories,
    List<Service>? services,
    List<ServicePackage>? packages,
    List<Appointment>? appointments,
    List<Quote>? quotes,
    List<PaymentTicket>? paymentTickets,
    List<InventoryItem>? inventoryItems,
    List<Sale>? sales,
    List<CashFlowEntry>? cashFlowEntries,
    List<MessageTemplate>? messageTemplates,
    List<ReminderSettings>? reminderSettings,
    List<AppNotification>? clientNotifications,
    List<Shift>? shifts,
    List<StaffAbsence>? staffAbsences,
    List<StaffAbsence>? publicStaffAbsences,
    List<ClientPhoto>? clientPhotos,
    List<ClientQuestionnaireTemplate>? clientQuestionnaireTemplates,
    List<ClientQuestionnaire>? clientQuestionnaires,
    List<Promotion>? promotions,
    List<LastMinuteSlot>? lastMinuteSlots,
  }) {
    state = state.copyWith(
      salons:
          salons != null
              ? _merge(state.salons, salons, (e) => e.id)
              : state.salons,
      staff:
          staff != null ? _merge(state.staff, staff, (e) => e.id) : state.staff,
      staffRoles:
          staffRoles != null
              ? _merge(state.staffRoles, staffRoles, (e) => e.id)
              : state.staffRoles,
      clients:
          clients != null
              ? _merge(state.clients, clients, (e) => e.id)
              : state.clients,
      serviceCategories:
          serviceCategories != null
              ? _merge(
                state.serviceCategories,
                serviceCategories,
                (e) => e.id,
              ).sortedByDisplayOrder()
              : state.serviceCategories,
      services:
          services != null
              ? _merge(state.services, services, (e) => e.id)
              : state.services,
      packages:
          packages != null
              ? _merge(state.packages, packages, (e) => e.id)
              : state.packages,
      appointments:
          appointments != null
              ? _merge(state.appointments, appointments, (e) => e.id)
              : state.appointments,
      quotes:
          quotes != null
              ? _merge(state.quotes, quotes, (e) => e.id)
              : state.quotes,
      paymentTickets:
          paymentTickets != null
              ? _merge(state.paymentTickets, paymentTickets, (e) => e.id)
              : state.paymentTickets,
      inventoryItems:
          inventoryItems != null
              ? _merge(state.inventoryItems, inventoryItems, (e) => e.id)
              : state.inventoryItems,
      sales:
          sales != null ? _merge(state.sales, sales, (e) => e.id) : state.sales,
      cashFlowEntries:
          cashFlowEntries != null
              ? _merge(state.cashFlowEntries, cashFlowEntries, (e) => e.id)
              : state.cashFlowEntries,
      messageTemplates:
          messageTemplates != null
              ? _merge(state.messageTemplates, messageTemplates, (e) => e.id)
              : state.messageTemplates,
      reminderSettings:
          reminderSettings != null
              ? _merge(
                state.reminderSettings,
                reminderSettings,
                (e) => e.salonId,
              )
              : state.reminderSettings,
      clientNotifications:
          clientNotifications != null
              ? _merge(
                state.clientNotifications,
                clientNotifications,
                (e) => e.id,
              )
              : state.clientNotifications,
      shifts:
          shifts != null
              ? _merge(state.shifts, shifts, (e) => e.id)
              : state.shifts,
      staffAbsences:
          staffAbsences != null
              ? _merge(state.staffAbsences, staffAbsences, (e) => e.id)
              : state.staffAbsences,
      publicStaffAbsences:
          publicStaffAbsences != null
              ? _merge(
                state.publicStaffAbsences,
                publicStaffAbsences,
                (e) => e.id,
              )
              : state.publicStaffAbsences,
      clientPhotos:
          clientPhotos != null
              ? _merge(state.clientPhotos, clientPhotos, (e) => e.id)
              : state.clientPhotos,
      clientQuestionnaireTemplates:
          clientQuestionnaireTemplates != null
              ? _merge(
                state.clientQuestionnaireTemplates,
                clientQuestionnaireTemplates,
                (e) => e.id,
              )
              : state.clientQuestionnaireTemplates,
      clientQuestionnaires:
          clientQuestionnaires != null
              ? _merge(
                state.clientQuestionnaires,
                clientQuestionnaires,
                (e) => e.id,
              )
              : state.clientQuestionnaires,
      promotions:
          promotions != null
              ? _merge(state.promotions, promotions, (e) => e.id)
              : state.promotions,
      lastMinuteSlots:
          lastMinuteSlots != null
              ? _merge(state.lastMinuteSlots, lastMinuteSlots, (e) => e.id)
              : state.lastMinuteSlots,
    );
  }

  void _deleteStaffRoleLocal(String roleId, {required String fallbackRoleId}) {
    final updatedStaff =
        state.staff.map((member) {
          if (!member.roleIds.contains(roleId)) {
            return member;
          }
          final remainingRoles =
              member.roleIds.where((value) => value != roleId).toList();
          if (remainingRoles.isEmpty) {
            remainingRoles.add(fallbackRoleId);
          }
          return member.copyWith(roleIds: remainingRoles);
        }).toList();
    final updatedServices =
        state.services.map((service) {
          if (!service.staffRoles.contains(roleId)) {
            return service;
          }
          final filteredRoles = service.staffRoles
              .where((value) => value != roleId)
              .toList(growable: false);
          return service.copyWith(staffRoles: filteredRoles);
        }).toList();

    state = state.copyWith(
      staffRoles: List.unmodifiable(
        state.staffRoles.where((role) => role.id != roleId),
      ),
      staff: List.unmodifiable(updatedStaff),
      services: List.unmodifiable(updatedServices),
    );
  }

  void _deleteQuoteLocal(String quoteId) {
    state = state.copyWith(
      quotes: List.unmodifiable(
        state.quotes.where((quote) => quote.id != quoteId),
      ),
    );
  }

  String _resolveFallbackRoleId(String removedRoleId) {
    final candidates = state.staffRoles
        .where((role) => role.id != removedRoleId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return removedRoleId == _unknownStaffRoleId
          ? _defaultStaffRoleId
          : _unknownStaffRoleId;
    }
    final preferredDefault = candidates.firstWhereOrNull(
      (role) => role.id == _defaultStaffRoleId,
    );
    if (preferredDefault != null) {
      return preferredDefault.id;
    }
    final defaultRole = candidates.firstWhereOrNull(
      (role) => role.isDefault && role.id != _unknownStaffRoleId,
    );
    if (defaultRole != null) {
      return defaultRole.id;
    }
    final nonUnknown = candidates.firstWhereOrNull(
      (role) => role.id != _unknownStaffRoleId,
    );
    if (nonUnknown != null) {
      return nonUnknown.id;
    }
    return candidates.first.id;
  }

  Future<FirebaseAuth?> _getAdminAuth() {
    final cached = _adminAuthFuture;
    if (cached != null) {
      return cached;
    }

    final completer = Completer<FirebaseAuth?>();
    _adminAuthFuture = completer.future;

    Future<FirebaseAuth?> initialize() async {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      if (_adminAuth != null) {
        return _adminAuth;
      }
      FirebaseApp adminApp;
      try {
        adminApp = Firebase.app('civiapp-admin');
      } on FirebaseException {
        final defaultApp = Firebase.app();
        adminApp = await Firebase.initializeApp(
          name: 'civiapp-admin',
          options: defaultApp.options,
        );
      }
      final auth = FirebaseAuth.instanceFor(app: adminApp);
      try {
        await auth.setLanguageCode('it');
      } catch (_) {
        // Ignore failures to set the language.
      }
      _adminAuth = auth;
      return auth;
    }

    initialize().then(completer.complete).catchError((error, stackTrace) {
      _adminAuthFuture = null;
      completer.completeError(error, stackTrace);
    });

    return completer.future;
  }

  String _generateTemporaryPassword() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'Civi${timestamp}*';
  }

  void _deleteSalonLocal(String salonId) {
    state = state.copyWith(
      salons: List.unmodifiable(
        state.salons.where((element) => element.id != salonId),
      ),
      staff: List.unmodifiable(
        state.staff.where((element) => element.salonId != salonId),
      ),
      staffRoles: List.unmodifiable(
        state.staffRoles.where((element) {
          final roleSalonId = element.salonId?.trim();
          if (roleSalonId == null || roleSalonId.isEmpty) {
            return true;
          }
          return roleSalonId != salonId;
        }),
      ),
      clients: List.unmodifiable(
        state.clients.where((element) => element.salonId != salonId),
      ),
      serviceCategories: List.unmodifiable(
        state.serviceCategories.where((element) => element.salonId != salonId),
      ),
      services: List.unmodifiable(
        state.services.where((element) => element.salonId != salonId),
      ),
      packages: List.unmodifiable(
        state.packages.where((element) => element.salonId != salonId),
      ),
      appointments: List.unmodifiable(
        state.appointments.where((element) => element.salonId != salonId),
      ),
      quotes: List.unmodifiable(
        state.quotes.where((element) => element.salonId != salonId),
      ),
      inventoryItems: List.unmodifiable(
        state.inventoryItems.where((element) => element.salonId != salonId),
      ),
      sales: List.unmodifiable(
        state.sales.where((element) => element.salonId != salonId),
      ),
      cashFlowEntries: List.unmodifiable(
        state.cashFlowEntries.where((element) => element.salonId != salonId),
      ),
      messageTemplates: List.unmodifiable(
        state.messageTemplates.where((element) => element.salonId != salonId),
      ),
      shifts: List.unmodifiable(
        state.shifts.where((element) => element.salonId != salonId),
      ),
      staffAbsences: List.unmodifiable(
        state.staffAbsences.where((element) => element.salonId != salonId),
      ),
    );
  }

  void _deleteStaffLocal(String staffId) {
    state = state.copyWith(
      staff: List.unmodifiable(
        state.staff.where((element) => element.id != staffId),
      ),
      appointments: List.unmodifiable(
        state.appointments.map((appointment) {
          if (appointment.staffId == staffId) {
            return appointment.copyWith(staffId: '');
          }
          return appointment;
        }).toList(),
      ),
      shifts: List.unmodifiable(
        state.shifts.where((element) => element.staffId != staffId),
      ),
      staffAbsences: List.unmodifiable(
        state.staffAbsences.where((element) => element.staffId != staffId),
      ),
      cashFlowEntries: List.unmodifiable(
        state.cashFlowEntries.map((entry) {
          if (entry.staffId == staffId) {
            return CashFlowEntry(
              id: entry.id,
              salonId: entry.salonId,
              type: entry.type,
              amount: entry.amount,
              date: entry.date,
              createdAt: entry.createdAt,
              description: entry.description,
              category: entry.category,
              staffId: null,
            );
          }
          return entry;
        }).toList(),
      ),
    );
  }

  void _deleteClientLocal(String clientId) {
    state = state.copyWith(
      clients: List.unmodifiable(
        state.clients.where((element) => element.id != clientId),
      ),
      appointments: List.unmodifiable(
        state.appointments.where((element) => element.clientId != clientId),
      ),
      quotes: List.unmodifiable(
        state.quotes.where((element) => element.clientId != clientId),
      ),
      sales: List.unmodifiable(
        state.sales.where((element) => element.clientId != clientId),
      ),
      paymentTickets: List.unmodifiable(
        state.paymentTickets.where((element) => element.clientId != clientId),
      ),
      clientPhotos: List.unmodifiable(
        state.clientPhotos.where((element) => element.clientId != clientId),
      ),
    );
  }

  void _deleteClientPhotoLocal(String photoId) {
    state = state.copyWith(
      clientPhotos: List.unmodifiable(
        state.clientPhotos.where((element) => element.id != photoId),
      ),
    );
  }

  void _deleteServiceLocal(String serviceId) {
    state = state.copyWith(
      services: List.unmodifiable(
        state.services.where((element) => element.id != serviceId),
      ),
      appointments: List.unmodifiable(
        state.appointments.where((element) => element.serviceId != serviceId),
      ),
      paymentTickets: List.unmodifiable(
        state.paymentTickets.where((element) => element.serviceId != serviceId),
      ),
      packages: List.unmodifiable(
        state.packages.map((pkg) {
          final updatedSessions = Map<String, int>.from(
            pkg.serviceSessionCounts,
          )..remove(serviceId);
          return ServicePackage(
            id: pkg.id,
            salonId: pkg.salonId,
            name: pkg.name,
            price: pkg.price,
            fullPrice: pkg.fullPrice,
            discountPercentage: pkg.discountPercentage,
            description: pkg.description,
            serviceIds: pkg.serviceIds.where((id) => id != serviceId).toList(),
            sessionCount: pkg.sessionCount,
            validDays: pkg.validDays,
            serviceSessionCounts: updatedSessions,
          );
        }).toList(),
      ),
    );
  }

  void _deleteServiceCategoryLocal(String categoryId) {
    state = state.copyWith(
      serviceCategories: List.unmodifiable(
        state.serviceCategories.where((element) => element.id != categoryId),
      ),
    );
  }

  void _updateLocalServicesCategoryName({
    required String categoryId,
    required String categoryName,
    String? previousCategoryName,
    String? salonId,
  }) {
    final updated = <Service>[];
    var hasChanges = false;
    for (final service in state.services) {
      final matchesId = service.categoryId == categoryId;
      final matchesLegacyName =
          previousCategoryName != null &&
          service.categoryId == null &&
          (salonId == null || service.salonId == salonId) &&
          service.category.toLowerCase() == previousCategoryName.toLowerCase();
      if (matchesId || matchesLegacyName) {
        updated.add(
          service.copyWith(category: categoryName, categoryId: categoryId),
        );
        hasChanges = true;
      } else {
        updated.add(service);
      }
    }
    if (hasChanges) {
      state = state.copyWith(services: List.unmodifiable(updated));
    }
  }

  Future<void> _syncServiceCategoryNameRemote({
    required String categoryId,
    required String categoryName,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }
    try {
      final querySnapshot =
          await firestore
              .collection('services')
              .where('categoryId', isEqualTo: categoryId)
              .get();
      if (querySnapshot.docs.isEmpty) {
        return;
      }
      final docs = querySnapshot.docs;
      var index = 0;
      while (index < docs.length) {
        final batch = firestore.batch();
        final chunk = docs.skip(index).take(_firestoreChunkSize);
        for (final doc in chunk) {
          batch.update(doc.reference, {'category': categoryName});
        }
        await batch.commit();
        index += _firestoreChunkSize;
      }
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        debugPrint(
          'Permission denied updating service names for category $categoryId.',
        );
        throw error;
      }
      rethrow;
    }
  }

  void _deletePackageLocal(String packageId) {
    state = state.copyWith(
      packages: List.unmodifiable(
        state.packages.where((element) => element.id != packageId),
      ),
    );
  }

  void _deleteAppointmentLocal(String appointmentId) {
    state = state.copyWith(
      appointments: List.unmodifiable(
        state.appointments.where((element) => element.id != appointmentId),
      ),
    );
  }

  void _deleteInventoryItemLocal(String itemId) {
    state = state.copyWith(
      inventoryItems: List.unmodifiable(
        state.inventoryItems.where((element) => element.id != itemId),
      ),
    );
  }

  void _deletePaymentTicketLocal(String ticketId) {
    state = state.copyWith(
      paymentTickets: List.unmodifiable(
        state.paymentTickets.where((element) => element.id != ticketId),
      ),
    );
  }

  void _deleteSaleLocal(String saleId) {
    state = state.copyWith(
      sales: List.unmodifiable(
        state.sales.where((element) => element.id != saleId),
      ),
    );
  }

  void _deleteCashFlowEntryLocal(String entryId) {
    state = state.copyWith(
      cashFlowEntries: List.unmodifiable(
        state.cashFlowEntries.where((element) => element.id != entryId),
      ),
    );
  }

  void _deleteTemplateLocal(String templateId) {
    state = state.copyWith(
      messageTemplates: List.unmodifiable(
        state.messageTemplates.where((element) => element.id != templateId),
      ),
    );
  }

  void _deleteClientQuestionnaireTemplateLocal(String templateId) {
    state = state.copyWith(
      clientQuestionnaireTemplates: List.unmodifiable(
        state.clientQuestionnaireTemplates.where(
          (element) => element.id != templateId,
        ),
      ),
    );
  }

  void _deleteClientQuestionnaireLocal(String questionnaireId) {
    state = state.copyWith(
      clientQuestionnaires: List.unmodifiable(
        state.clientQuestionnaires.where(
          (element) => element.id != questionnaireId,
        ),
      ),
    );
  }

  void _deletePromotionLocal(String promotionId) {
    state = state.copyWith(
      promotions: List.unmodifiable(
        state.promotions.where((promotion) => promotion.id != promotionId),
      ),
    );
  }

  List<Appointment> _blockingLastMinuteAppointments({
    required String salonId,
    required String staffId,
    required DateTime reference,
    String? ignoreSlotId,
  }) {
    if (staffId.isEmpty) {
      return const <Appointment>[];
    }
    final placeholders = _cachedLastMinuteSlots
        .where((slot) {
          if (slot.salonId != salonId) {
            return false;
          }
          if (slot.operatorId != staffId) {
            return false;
          }
          if (!slot.isAvailable) {
            return false;
          }
          if (!slot.end.isAfter(reference)) {
            return false;
          }
          if (ignoreSlotId != null && slot.id == ignoreSlotId) {
            return false;
          }
          return true;
        })
        .map(_appointmentFromLastMinuteSlot);
    return List<Appointment>.unmodifiable(placeholders);
  }

  Appointment _appointmentFromLastMinuteSlot(LastMinuteSlot slot) {
    final serviceIds =
        slot.serviceId != null && slot.serviceId!.isNotEmpty
            ? <String>[slot.serviceId!]
            : const <String>[];
    return Appointment(
      id: 'last-minute-${slot.id}',
      salonId: slot.salonId,
      clientId: 'last-minute-${slot.id}',
      staffId: slot.operatorId ?? '',
      serviceIds: serviceIds,
      start: slot.start,
      end: slot.end,
      status: AppointmentStatus.scheduled,
      notes: slot.serviceName,
      roomId: slot.roomId,
      lastMinuteSlotId: slot.id,
    );
  }

  void _deleteLastMinuteSlotLocal(String slotId) {
    state = state.copyWith(
      lastMinuteSlots: List.unmodifiable(
        state.lastMinuteSlots.where((slot) => slot.id != slotId),
      ),
    );
  }

  Future<void> _markLastMinuteSlotBooking({
    String? slotId,
    required Appointment appointment,
  }) async {
    var resolvedSlotId = slotId;
    if (resolvedSlotId == null || resolvedSlotId.isEmpty) {
      resolvedSlotId = _extractLastMinuteSlotId(appointment);
    }

    LastMinuteSlot? target;
    if (resolvedSlotId != null && resolvedSlotId.isNotEmpty) {
      target = _cachedLastMinuteSlots.firstWhereOrNull(
        (slot) => slot.id == resolvedSlotId,
      );
    }

    target ??= _cachedLastMinuteSlots.firstWhereOrNull((slot) {
      if (!slot.isAvailable) {
        return false;
      }
      if (slot.salonId != appointment.salonId) {
        return false;
      }
      if (slot.operatorId != appointment.staffId) {
        return false;
      }
      if (!slot.start.isAtSameMomentAs(appointment.start)) {
        return false;
      }
      if (!slot.end.isAtSameMomentAs(appointment.end)) {
        return false;
      }
      return true;
    });

    target ??= _cachedLastMinuteSlots.firstWhereOrNull((slot) {
      if (!slot.isBooked) {
        return false;
      }
      if (slot.bookedClientId != appointment.clientId) {
        return false;
      }
      if (slot.salonId != appointment.salonId) {
        return false;
      }
      return slot.id == resolvedSlotId;
    });
    if (target == null) {
      return;
    }
    if (!target.isAvailable && target.bookedClientId == appointment.clientId) {
      return;
    }
    final client = state.clients.firstWhereOrNull(
      (item) => item.id == appointment.clientId,
    );
    final now = DateTime.now();
    final updatedSlot = target.copyWith(
      start: appointment.start,
      duration: appointment.duration,
      availableSeats: 0,
      updatedAt: now,
      bookedClientId: appointment.clientId,
      bookedClientName: client?.fullName,
    );

    final isAdmin = _currentUser?.role == UserRole.admin;
    if (isAdmin && _firestore != null) {
      try {
        await upsertLastMinuteSlot(updatedSlot);
        return;
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Failed to update last-minute slot ${target.id}: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        try {
          await deleteLastMinuteSlot(target.id);
          return;
        } catch (innerError, innerStack) {
          if (kDebugMode) {
            debugPrint(
              'Failed to remove last-minute slot ${target.id}: $innerError',
            );
            debugPrintStack(stackTrace: innerStack);
          }
        }
      }
    }

    _cachedLastMinuteSlots = _merge(_cachedLastMinuteSlots, <LastMinuteSlot>[
      updatedSlot,
    ], (slot) => slot.id);
    _upsertLocal(lastMinuteSlots: <LastMinuteSlot>[updatedSlot]);
  }

  String? _extractLastMinuteSlotId(Appointment appointment) {
    final notes = appointment.notes;
    if (notes == null || notes.isEmpty) {
      return null;
    }
    final regex = RegExp(r'Prenotazione last-minute ([a-zA-Z0-9\-]+)');
    final match = regex.firstMatch(notes);
    return match?.group(1);
  }

  Appointment _appointmentFromCallableMap(Map<String, dynamic> data) {
    final start = _parseIsoDate(data['start'] as String? ?? '');
    final end = _parseIsoDate(data['end'] as String? ?? '');
    final serviceIdsRaw = data['serviceIds'];
    final serviceIds =
        serviceIdsRaw is Iterable
            ? serviceIdsRaw.map((e) => e.toString()).toList()
            : <String>[];
    final serviceIdRaw = data['serviceId'];
    final serviceId =
        serviceIdRaw is String && serviceIdRaw.trim().isNotEmpty
            ? serviceIdRaw.trim()
            : null;

    return Appointment(
      id: data['id'] as String,
      salonId: data['salonId'] as String,
      clientId: data['clientId'] as String,
      staffId: data['staffId'] as String,
      serviceId: serviceId,
      serviceIds: serviceIds,
      start: start,
      end: end,
      status: _statusFromName(data['status'] as String? ?? 'scheduled'),
      notes:
          (data['notes'] as String?)?.trim().isNotEmpty == true
              ? data['notes'] as String
              : null,
      packageId:
          (data['packageId'] as String?)?.isNotEmpty == true
              ? data['packageId'] as String
              : null,
      roomId:
          (data['roomId'] as String?)?.isNotEmpty == true
              ? data['roomId'] as String
              : null,
      lastMinuteSlotId:
          (data['lastMinuteSlotId'] as String?)?.isNotEmpty == true
              ? data['lastMinuteSlotId'] as String
              : null,
    );
  }

  LastMinuteSlot _slotFromCallableMap(Map<String, dynamic> data) {
    final start = _parseIsoDate(data['start'] as String? ?? '');
    final durationMinutes = (data['durationMinutes'] as num?)?.toInt() ?? 0;
    final duration = Duration(
      minutes: durationMinutes > 0 ? durationMinutes : 15,
    );

    return LastMinuteSlot(
      id: data['id'] as String,
      salonId: (data['salonId'] as String?) ?? '',
      serviceId:
          (data['serviceId'] as String?)?.isNotEmpty == true
              ? data['serviceId'] as String
              : null,
      serviceName: (data['serviceName'] as String?) ?? 'Slot last-minute',
      start: start,
      duration: duration,
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0,
      discountPercentage: (data['discountPercentage'] as num?)?.toDouble() ?? 0,
      priceNow: (data['priceNow'] as num?)?.toDouble() ?? 0,
      roomId:
          (data['roomId'] as String?)?.isNotEmpty == true
              ? data['roomId'] as String
              : null,
      roomName: data['roomName'] as String?,
      operatorId:
          (data['operatorId'] as String?)?.isNotEmpty == true
              ? data['operatorId'] as String
              : null,
      operatorName: data['operatorName'] as String?,
      availableSeats: (data['availableSeats'] as num?)?.toInt() ?? 0,
      loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
      createdAt: null,
      updatedAt: DateTime.now(),
      windowStart: null,
      windowEnd: null,
      bookedClientId:
          (data['bookedClientId'] as String?)?.isNotEmpty == true
              ? data['bookedClientId'] as String
              : null,
      bookedClientName: data['bookedClientName'] as String?,
    );
  }

  AppointmentStatus _statusFromName(String value) {
    return AppointmentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AppointmentStatus.scheduled,
    );
  }

  DateTime _parseIsoDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw StateError('Data non valida: $value');
    }
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  void _deleteShiftLocal(String shiftId) {
    state = state.copyWith(
      shifts: List.unmodifiable(
        state.shifts.where((element) => element.id != shiftId),
      ),
    );
  }

  void _deleteStaffAbsenceLocal(String absenceId) {
    state = state.copyWith(
      staffAbsences: List.unmodifiable(
        state.staffAbsences.where((element) => element.id != absenceId),
      ),
      publicStaffAbsences: List.unmodifiable(
        state.publicStaffAbsences.where((element) => element.id != absenceId),
      ),
    );
  }

  List<T> _merge<T>(
    List<T> source,
    List<T> updates,
    String Function(T) keySelector,
  ) {
    final map = {for (final item in source) keySelector(item): item};
    for (final item in updates) {
      map[keySelector(item)] = item;
    }
    return List.unmodifiable(map.values);
  }
}

class _PackageConsumptionCandidate {
  const _PackageConsumptionCandidate({
    required this.sale,
    required this.item,
    required this.itemIndex,
    required this.totalSessions,
    required this.remainingSessions,
    required this.expirationDate,
    required this.servicePackage,
  });

  final Sale sale;
  final SaleItem item;
  final int itemIndex;
  final int totalSessions;
  final int remainingSessions;
  final DateTime? expirationDate;
  final ServicePackage? servicePackage;
}

class _LastMinuteBookingResult {
  const _LastMinuteBookingResult({required this.appointment, this.slot});

  final Appointment appointment;
  final LastMinuteSlot? slot;
}
