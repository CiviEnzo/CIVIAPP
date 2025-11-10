import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_service_allocation.dart';
import 'package:you_book/domain/entities/appointment_day_checklist.dart';
import 'package:you_book/domain/entities/cash_flow_entry.dart';
import 'package:you_book/domain/entities/app_notification.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_app_movement.dart';
import 'package:you_book/domain/entities/client_questionnaire.dart';
import 'package:you_book/domain/entities/client_photo.dart';
import 'package:you_book/domain/entities/client_photo_collage.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/loyalty_settings.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/quote.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/public_salon.dart';
import 'package:you_book/domain/entities/salon_setup_progress.dart';
import 'package:you_book/domain/entities/salon_access_request.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/domain/entities/reminder_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

Salon salonFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final roomsRaw = data['rooms'] as List<dynamic>? ?? const [];
  final scheduleRaw = data['schedule'] as List<dynamic>? ?? const [];
  final equipmentRaw = data['equipment'] as List<dynamic>? ?? const [];
  final closuresRaw = data['closures'] as List<dynamic>? ?? const [];
  final loyaltyRaw = data['loyaltySettings'] as Map<String, dynamic>?;
  final featureFlagsRaw = _mapFromDynamic(
    data['featureFlags'] ?? data['features'],
  );
  final dashboardSectionsRaw = _mapFromDynamic(data['dashboardSections']);
  final socialLinksRaw = _mapFromDynamic(data['socialLinks']);
  final setupChecklistRaw = _mapFromDynamic(data['setupChecklist']);
  final allowedChecklistKeys = SetupChecklistKeys.defaults.toSet();
  final setupChecklist = <String, SetupChecklistStatus>{};
  setupChecklistRaw.forEach((key, value) {
    final status = setupChecklistStatusFromName(value?.toString());
    final normalizedKey = key.toString();
    if (status != null && allowedChecklistKeys.contains(normalizedKey)) {
      setupChecklist[key.toString()] = status;
    }
  });
  final socialLinks = <String, String>{};
  socialLinksRaw.forEach((key, value) {
    final label = key.toString().trim();
    final linkRaw = value?.toString() ?? '';
    final link = linkRaw.trim();
    if (label.isEmpty || link.isEmpty) {
      return;
    }
    socialLinks[label] = link;
  });
  final clientRegistrationRaw = _mapFromDynamic(data['clientRegistration']);
  final stripeAccountRaw = _mapFromDynamic(data['stripeAccount']);
  final stripeRequirementsRaw = _mapFromDynamic(
    stripeAccountRaw['requirements'],
  );
  final currentlyDueRaw =
      (stripeRequirementsRaw['currentlyDue'] as List<dynamic>? ??
          stripeAccountRaw['currentlyDue'] as List<dynamic>? ??
          const <dynamic>[]);
  final pastDueRaw =
      (stripeRequirementsRaw['pastDue'] as List<dynamic>? ??
          stripeAccountRaw['pastDue'] as List<dynamic>? ??
          const <dynamic>[]);
  final eventuallyDueRaw =
      (stripeRequirementsRaw['eventuallyDue'] as List<dynamic>? ??
          stripeAccountRaw['eventuallyDue'] as List<dynamic>? ??
          const <dynamic>[]);
  final stripeAccount = StripeAccountSnapshot(
    chargesEnabled: _coerceToBool(stripeAccountRaw['chargesEnabled']),
    payoutsEnabled: _coerceToBool(stripeAccountRaw['payoutsEnabled']),
    detailsSubmitted: _coerceToBool(stripeAccountRaw['detailsSubmitted']),
    currentlyDue: currentlyDueRaw
        .map((value) => value.toString())
        .toList(growable: false),
    pastDue: pastDueRaw
        .map((value) => value.toString())
        .toList(growable: false),
    eventuallyDue: eventuallyDueRaw
        .map((value) => value.toString())
        .toList(growable: false),
    disabledReason:
        (stripeRequirementsRaw['disabledReason'] as String?) ??
        stripeAccountRaw['disabledReason'] as String?,
    createdAt: _timestampToDate(
      stripeAccountRaw['createdAt'] ?? stripeRequirementsRaw['createdAt'],
    ),
    updatedAt: _timestampToDate(
      stripeAccountRaw['updatedAt'] ?? stripeRequirementsRaw['updatedAt'],
    ),
  );
  return Salon(
    id: doc.id,
    name: data['name'] as String? ?? '',
    address: data['address'] as String? ?? '',
    city: data['city'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String? ?? '',
    postalCode: data['postalCode'] as String?,
    bookingLink: data['bookingLink'] as String?,
    googlePlaceId: data['googlePlaceId'] as String?,
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    socialLinks: socialLinks,
    description: data['description'] as String?,
    status: _stringToSalonStatus(data['status'] as String?),
    rooms:
        roomsRaw.map((roomRaw) {
          final room = roomRaw as Map<String, dynamic>;
          return SalonRoom(
            id: room['id'] as String? ?? '',
            name: room['name'] as String? ?? '',
            capacity: ((room['capacity'] as num?) ?? 0).toInt(),
            category: room['category'] as String?,
            services:
                (room['services'] as List<dynamic>? ?? const [])
                    .map((service) => service.toString())
                    .toList(),
          );
        }).toList(),
    equipment:
        equipmentRaw
            .map(_mapToSalonEquipment)
            .whereType<SalonEquipment>()
            .toList(),
    closures:
        closuresRaw.map(_mapToSalonClosure).whereType<SalonClosure>().toList(),
    schedule:
        scheduleRaw
            .map(
              (entryRaw) => SalonDailySchedule(
                weekday:
                    (entryRaw as Map<String, dynamic>)['weekday'] as int? ??
                    DateTime.monday,
                isOpen: entryRaw['isOpen'] as bool? ?? false,
                openMinuteOfDay: (entryRaw['openMinuteOfDay'] as num?)?.toInt(),
                closeMinuteOfDay:
                    (entryRaw['closeMinuteOfDay'] as num?)?.toInt(),
              ),
            )
            .toList(),
    loyaltySettings: _mapToLoyaltySettings(loyaltyRaw),
    featureFlags: SalonFeatureFlags.fromMap(featureFlagsRaw),
    isPublished: _coerceToBool(data['isPublished']),
    dashboardSections: SalonDashboardSections.fromMap(dashboardSectionsRaw),
    clientRegistration: _mapToClientRegistrationSettings(clientRegistrationRaw),
    stripeAccountId: data['stripeAccountId'] as String?,
    stripeAccount: stripeAccount,
    setupChecklist: Map<String, SetupChecklistStatus>.unmodifiable(
      setupChecklist,
    ),
  );
}

Map<String, dynamic> salonToMap(Salon salon) {
  final map = {
    'name': salon.name,
    'address': salon.address,
    'city': salon.city,
    'phone': salon.phone,
    'email': salon.email,
    'postalCode': salon.postalCode,
    'bookingLink': salon.bookingLink,
    'googlePlaceId': salon.googlePlaceId,
    'latitude': salon.latitude,
    'longitude': salon.longitude,
    'socialLinks': salon.socialLinks,
    'description': salon.description,
    'status': salon.status.name,
    'isPublished': salon.isPublished,
    'rooms':
        salon.rooms
            .map(
              (room) => {
                'id': room.id,
                'name': room.name,
                'capacity': room.capacity,
                'category': room.category,
                'services': room.services,
              },
            )
            .toList(),
    'equipment':
        salon.equipment
            .map(
              (item) => {
                'id': item.id,
                'name': item.name,
                'quantity': item.quantity,
                'status': item.status.name,
                'notes': item.notes,
              },
            )
            .toList(),
    'closures':
        salon.closures
            .map(
              (closure) => {
                'id': closure.id,
                'start': Timestamp.fromDate(closure.start),
                'end': Timestamp.fromDate(closure.end),
                'reason': closure.reason,
              },
            )
            .toList(),
    'schedule':
        salon.schedule
            .map(
              (entry) => {
                'weekday': entry.weekday,
                'isOpen': entry.isOpen,
                'openMinuteOfDay': entry.openMinuteOfDay,
                'closeMinuteOfDay': entry.closeMinuteOfDay,
              },
            )
            .toList(),
    'setupChecklist': salon.setupChecklist.map(
      (key, value) => MapEntry(key, setupChecklistStatusToName(value)),
    ),
  };

  final loyaltyMap = _loyaltySettingsToMap(salon.loyaltySettings);
  if (loyaltyMap != null) {
    map['loyaltySettings'] = loyaltyMap;
  }

  map['dashboardSections'] = salon.dashboardSections.toMap();

  map['featureFlags'] = salon.featureFlags.toMap();
  map['clientRegistration'] = _clientRegistrationToMap(
    salon.clientRegistration,
  );
  if (salon.stripeAccountId != null) {
    map['stripeAccountId'] = salon.stripeAccountId;
  }
  map['stripeAccount'] = {
    'chargesEnabled': salon.stripeAccount.chargesEnabled,
    'payoutsEnabled': salon.stripeAccount.payoutsEnabled,
    'detailsSubmitted': salon.stripeAccount.detailsSubmitted,
    'currentlyDue': salon.stripeAccount.currentlyDue,
    'pastDue': salon.stripeAccount.pastDue,
    'eventuallyDue': salon.stripeAccount.eventuallyDue,
    if (salon.stripeAccount.disabledReason != null)
      'disabledReason': salon.stripeAccount.disabledReason,
    if (salon.stripeAccount.createdAt != null)
      'createdAt': Timestamp.fromDate(salon.stripeAccount.createdAt!),
    if (salon.stripeAccount.updatedAt != null)
      'updatedAt': Timestamp.fromDate(salon.stripeAccount.updatedAt!),
  };

  return map;
}

PublicSalon publicSalonFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return PublicSalon.fromMap(doc.id, data);
}

AdminSetupProgress adminSetupProgressFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final itemsRaw = data['items'] as List<dynamic>? ?? const [];
  final items = <SetupChecklistItem>[];
  final allowedKeys = SetupChecklistKeys.defaults.toSet();
  for (final entry in itemsRaw) {
    if (entry is! Map<String, dynamic>) {
      continue;
    }
    final key = entry['key'] as String? ?? '';
    if (key.isEmpty || !allowedKeys.contains(key)) {
      continue;
    }
    final status =
        setupChecklistStatusFromName(entry['status']?.toString()) ??
        SetupChecklistStatus.notStarted;
    final metadata = _mapFromDynamic(entry['metadata']);
    final updatedAt = _coerceToDateTime(entry['updatedAt']);
    final updatedBy = entry['updatedBy'] as String?;
    items.add(
      SetupChecklistItem(
        key: key,
        status: status,
        metadata: Map<String, dynamic>.unmodifiable(metadata),
        updatedAt: updatedAt,
        updatedBy: updatedBy,
      ),
    );
  }

  return AdminSetupProgress(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    tenantId: data['tenantId'] as String?,
    createdBy: data['createdBy'] as String?,
    createdAt: _coerceToDateTime(data['createdAt']),
    updatedAt: _coerceToDateTime(data['updatedAt']),
    updatedBy: data['updatedBy'] as String?,
    pendingReminder:
        data.containsKey('pendingReminder')
            ? _coerceToBool(data['pendingReminder'])
            : true,
    requiredCompleted: _coerceToBool(data['requiredCompleted']),
    items: List.unmodifiable(items),
  );
}

Map<String, dynamic> adminSetupProgressToMap(AdminSetupProgress progress) {
  return <String, dynamic>{
    'salonId': progress.salonId,
    if (progress.tenantId != null) 'tenantId': progress.tenantId,
    if (progress.createdBy != null) 'createdBy': progress.createdBy,
    if (progress.updatedBy != null) 'updatedBy': progress.updatedBy,
    if (progress.createdAt != null)
      'createdAt': Timestamp.fromDate(progress.createdAt!),
    if (progress.updatedAt != null)
      'updatedAt': Timestamp.fromDate(progress.updatedAt!),
    'pendingReminder': progress.pendingReminder,
    'requiredCompleted': progress.requiredCompleted,
    'items':
        progress.items
            .map(
              (item) => <String, dynamic>{
                'key': item.key,
                'status': setupChecklistStatusToName(item.status),
                if (item.metadata.isNotEmpty) 'metadata': item.metadata,
                if (item.updatedBy != null) 'updatedBy': item.updatedBy,
                if (item.updatedAt != null)
                  'updatedAt': Timestamp.fromDate(item.updatedAt!),
              },
            )
            .toList(),
  };
}

Promotion promotionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final startsAt = _coerceToDateTime(data['startsAt'] ?? data['startAt']);
  final endsAt = _coerceToDateTime(data['endsAt'] ?? data['endAt']);
  final discount =
      _coerceToDouble(
        data['discountPercentage'] ?? data['discountPct'] ?? data['discount'],
      ) ??
      0;
  final priority = (data['priority'] as num?)?.toInt() ?? 0;
  PromotionCta? cta;
  final ctaRaw = data['cta'];
  if (ctaRaw is Map<String, dynamic>) {
    cta = PromotionCta.fromMap(Map<String, dynamic>.from(ctaRaw));
  }
  final ctaUrl =
      (data['ctaUrl'] as String?) ??
      (cta != null && cta.url != null ? cta.url : null);
  final sectionsRaw = data['sections'] as List<dynamic>? ?? const <dynamic>[];
  final sections =
      sectionsRaw
          .map((item) => _mapFromDynamic(item))
          .where((sectionMap) => sectionMap.isNotEmpty)
          .map(PromotionSection.fromMap)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
  final analyticsRaw = _mapFromDynamic(data['analytics']);
  PromotionAnalytics? analytics;
  if (analyticsRaw.isNotEmpty) {
    analytics = PromotionAnalytics.fromMap(analyticsRaw);
  }
  final dynamic themeColorRaw = data['themeColor'];
  int? themeColor;
  if (themeColorRaw is int) {
    themeColor = themeColorRaw;
  } else if (themeColorRaw is String) {
    final sanitized = themeColorRaw.replaceAll('#', '').trim();
    if (sanitized.isNotEmpty) {
      final hex = sanitized.length == 6 ? 'FF$sanitized' : sanitized;
      themeColor = int.tryParse('0x$hex');
    }
  }
  final status =
      data.containsKey('status')
          ? promotionStatusFromName(data['status'] as String?)
          : (data['isActive'] == true
              ? PromotionStatus.published
              : PromotionStatus.draft);
  final bool? isActiveValue =
      data.containsKey('isActive') || data.containsKey('active')
          ? _coerceToBool(data['isActive'] ?? data['active'])
          : null;
  final bool isActive = isActiveValue ?? (status == PromotionStatus.published);
  return Promotion(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    title: data['title'] as String? ?? '',
    subtitle: data['subtitle'] as String?,
    tagline: data['tagline'] as String?,
    coverImageUrl:
        (data['coverImageUrl'] as String?) ?? (data['imageUrl'] as String?),
    coverImagePath:
        (data['coverImagePath'] as String?) ??
        (data['imageStoragePath'] as String?),
    themeColor: themeColor,
    ctaUrl: ctaUrl,
    cta: cta,
    sections: List.unmodifiable(sections),
    startsAt: startsAt,
    endsAt: endsAt,
    discountPercentage: discount,
    priority: priority,
    status: status,
    isActive: isActive,
    createdAt: _coerceToDateTime(data['createdAt']),
    updatedAt: _coerceToDateTime(data['updatedAt']),
    createdBy: data['createdBy'] as String?,
    updatedBy: data['updatedBy'] as String?,
    analytics: analytics,
  );
}

Map<String, dynamic> promotionToMap(Promotion promotion) {
  final sections =
      promotion.sections.isNotEmpty
          ? promotion.sections.map((section) => section.toMap()).toList()
          : null;
  final analyticsMap = promotion.analytics?.toMap();
  final map = <String, dynamic>{
    'salonId': promotion.salonId,
    'title': promotion.title,
    'subtitle': promotion.subtitle,
    'tagline': promotion.tagline,
    'coverImageUrl': promotion.coverImageUrl,
    'coverImagePath': promotion.coverImagePath,
    'imageUrl': promotion.coverImageUrl,
    'imageStoragePath': promotion.coverImagePath,
    'themeColor': promotion.themeColor,
    'ctaUrl': promotion.ctaUrl ?? promotion.cta?.url,
    if (promotion.cta != null) 'cta': promotion.cta!.toMap(),
    if (sections != null) 'sections': sections,
    'startsAt':
        promotion.startsAt != null
            ? Timestamp.fromDate(promotion.startsAt!)
            : null,
    'endsAt':
        promotion.endsAt != null ? Timestamp.fromDate(promotion.endsAt!) : null,
    'discountPercentage': promotion.discountPercentage,
    'priority': promotion.priority,
    'status': promotion.status.name,
    'isActive': promotion.isActive,
    'createdAt':
        promotion.createdAt != null
            ? Timestamp.fromDate(promotion.createdAt!)
            : null,
    'updatedAt':
        promotion.updatedAt != null
            ? Timestamp.fromDate(promotion.updatedAt!)
            : FieldValue.serverTimestamp(),
    'createdBy': promotion.createdBy,
    'updatedBy': promotion.updatedBy,
    if (analyticsMap != null) 'analytics': analyticsMap,
  }..removeWhere((_, value) {
    if (value == null) {
      return true;
    }
    if (value is List && value.isEmpty) {
      return true;
    }
    if (value is Map && value.isEmpty) {
      return true;
    }
    return false;
  });
  return map;
}

LastMinuteSlot lastMinuteSlotFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final serviceRaw = _mapFromDynamic(data['service']);
  final roomRaw = _mapFromDynamic(data['room']);
  final operatorRaw = _mapFromDynamic(data['operator']);
  final durationMinutes =
      (data['durationMinutes'] as num?)?.toInt() ??
      (data['duration'] as num?)?.toInt() ??
      30;
  final safeDurationMinutes = durationMinutes.clamp(5, 480).toInt();
  final serviceId =
      data['serviceId'] as String? ?? serviceRaw['id']?.toString();
  final serviceName =
      data['serviceName'] as String? ?? serviceRaw['name']?.toString();
  return LastMinuteSlot(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    serviceId: serviceId?.isNotEmpty == true ? serviceId : null,
    serviceName:
        (serviceName == null || serviceName.isEmpty)
            ? 'Slot last-minute'
            : serviceName,
    imageUrl: data['imageUrl'] as String?,
    imageStoragePath: data['imageStoragePath'] as String?,
    start: _coerceToDateTime(data['startAt']) ?? DateTime.now(),
    duration: Duration(minutes: safeDurationMinutes),
    basePrice: _coerceToDouble(data['basePrice']) ?? 0,
    discountPercentage:
        _coerceToDouble(data['discountPct'] ?? data['discount']) ?? 0,
    priceNow: _coerceToDouble(data['priceNow'] ?? data['price']) ?? 0,
    roomId: data['roomId'] as String? ?? roomRaw['id']?.toString(),
    roomName: data['roomName'] as String? ?? roomRaw['name']?.toString(),
    operatorId: data['operatorId'] as String? ?? operatorRaw['id']?.toString(),
    operatorName:
        data['operatorName'] as String? ?? operatorRaw['name']?.toString(),
    availableSeats:
        (data['availableSeats'] as num?)?.toInt() ??
        (data['seats'] as num?)?.toInt() ??
        1,
    loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
    createdAt: _coerceToDateTime(data['createdAt']),
    updatedAt: _coerceToDateTime(data['updatedAt']),
    windowStart: _coerceToDateTime(data['windowStart']),
    windowEnd: _coerceToDateTime(data['windowEnd']),
    bookedClientId: data['bookedClientId'] as String?,
    bookedClientName: data['bookedClientName'] as String?,
    paymentMode: lastMinutePaymentModeFromName(data['paymentMode'] as String?),
  );
}

Map<String, dynamic> lastMinuteSlotToMap(LastMinuteSlot slot) {
  final map = <String, dynamic>{
    'salonId': slot.salonId,
    'serviceId': slot.serviceId,
    'serviceName': slot.serviceName,
    'startAt': Timestamp.fromDate(slot.start),
    'durationMinutes': slot.duration.inMinutes,
    'basePrice': slot.basePrice,
    'discountPct': slot.discountPercentage,
    'priceNow': slot.priceNow,
    'roomId': slot.roomId,
    'roomName': slot.roomName,
    'operatorId': slot.operatorId,
    'operatorName': slot.operatorName,
    'availableSeats': slot.availableSeats,
    'loyaltyPoints': slot.loyaltyPoints,
    'paymentMode': slot.paymentMode.name,
    'createdAt':
        slot.createdAt != null ? Timestamp.fromDate(slot.createdAt!) : null,
    'updatedAt':
        slot.updatedAt != null ? Timestamp.fromDate(slot.updatedAt!) : null,
    'windowStart':
        slot.windowStart != null ? Timestamp.fromDate(slot.windowStart!) : null,
    'windowEnd':
        slot.windowEnd != null ? Timestamp.fromDate(slot.windowEnd!) : null,
    'bookedClientId': slot.bookedClientId,
    'bookedClientName': slot.bookedClientName,
  }..removeWhere((_, value) => value == null);
  if (slot.imageUrl != null && slot.imageUrl!.isNotEmpty) {
    map['imageUrl'] = slot.imageUrl;
  }
  if (slot.imageStoragePath != null && slot.imageStoragePath!.isNotEmpty) {
    map['imageStoragePath'] = slot.imageStoragePath;
  }
  return map;
}

PaymentTicket paymentTicketFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final createdAt = _coerceToDateTime(data['createdAt']) ?? DateTime.now();
  final appointmentStart =
      _coerceToDateTime(data['appointmentStart']) ?? createdAt;
  final appointmentEnd =
      _coerceToDateTime(data['appointmentEnd']) ?? appointmentStart;
  return PaymentTicket(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    appointmentId: data['appointmentId'] as String? ?? '',
    clientId: data['clientId'] as String? ?? '',
    serviceId: data['serviceId'] as String? ?? '',
    staffId: data['staffId'] as String?,
    appointmentStart: appointmentStart,
    appointmentEnd: appointmentEnd,
    createdAt: createdAt,
    status: _stringToTicketStatus(data['status'] as String?),
    closedAt: _coerceToDateTime(data['closedAt']),
    saleId: data['saleId'] as String?,
    expectedTotal: (data['expectedTotal'] as num?)?.toDouble(),
    serviceName: data['serviceName'] as String?,
    notes: data['notes'] as String?,
  );
}

Map<String, dynamic> paymentTicketToMap(PaymentTicket ticket) {
  final map = <String, dynamic>{
    'salonId': ticket.salonId,
    'appointmentId': ticket.appointmentId,
    'clientId': ticket.clientId,
    'serviceId': ticket.serviceId,
    'staffId': ticket.staffId,
    'appointmentStart': Timestamp.fromDate(ticket.appointmentStart),
    'appointmentEnd': Timestamp.fromDate(ticket.appointmentEnd),
    'createdAt': Timestamp.fromDate(ticket.createdAt),
    'status': ticket.status.name,
    'closedAt':
        ticket.closedAt != null ? Timestamp.fromDate(ticket.closedAt!) : null,
    'saleId': ticket.saleId,
    'expectedTotal': ticket.expectedTotal,
    'serviceName': ticket.serviceName,
    'notes': ticket.notes,
  };
  map.removeWhere((_, value) => value == null);
  return map;
}

Quote quoteFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final itemsRaw = data['items'] as List<dynamic>? ?? const [];
  final items = itemsRaw
      .map((rawItem) {
        if (rawItem is! Map<String, dynamic>) {
          return null;
        }
        final quantity = (rawItem['quantity'] as num?)?.toDouble() ?? 1;
        final unitPrice = (rawItem['unitPrice'] as num?)?.toDouble() ?? 0;
        final id = rawItem['id'] as String? ?? const Uuid().v4();
        final serviceId = rawItem['serviceId'] as String?;
        final packageId = rawItem['packageId'] as String?;
        final inventoryItemId = rawItem['inventoryItemId'] as String?;
        final referenceTypeRaw = rawItem['referenceType'] as String?;
        QuoteItemReferenceType referenceType = quoteItemReferenceTypeFromString(
          referenceTypeRaw,
        );
        if (referenceTypeRaw == null ||
            referenceType == QuoteItemReferenceType.manual) {
          if (packageId != null && packageId.isNotEmpty) {
            referenceType = QuoteItemReferenceType.package;
          } else if (serviceId != null && serviceId.isNotEmpty) {
            referenceType = QuoteItemReferenceType.service;
          } else if (inventoryItemId != null && inventoryItemId.isNotEmpty) {
            referenceType = QuoteItemReferenceType.product;
          }
        }
        return QuoteItem(
          id: id,
          description: rawItem['description'] as String? ?? '',
          quantity: quantity,
          unitPrice: unitPrice,
          referenceType: referenceType,
          serviceId: serviceId,
          packageId: packageId,
          inventoryItemId: inventoryItemId,
        );
      })
      .whereType<QuoteItem>()
      .toList(growable: false);

  return Quote(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    clientId: data['clientId'] as String? ?? '',
    items: items,
    number: data['number'] as String?,
    title: data['title'] as String?,
    notes: data['notes'] as String?,
    status: _stringToQuoteStatus(data['status'] as String?),
    createdAt: _coerceToDateTime(data['createdAt']) ?? DateTime.now(),
    updatedAt: _coerceToDateTime(data['updatedAt']),
    validUntil: _coerceToDateTime(data['validUntil']),
    sentAt: _coerceToDateTime(data['sentAt']),
    acceptedAt: _coerceToDateTime(data['acceptedAt']),
    declinedAt: _coerceToDateTime(data['declinedAt']),
    ticketId: data['ticketId'] as String?,
    sentChannels: _mapToMessageChannels(data['sentChannels'] as List<dynamic>?),
    pdfStoragePath: data['pdfStoragePath'] as String?,
    saleId: data['saleId'] as String?,
    stripePaymentIntentId: data['stripePaymentIntentId'] as String?,
  );
}

Map<String, dynamic> quoteToMap(Quote quote) {
  final map = <String, dynamic>{
    'salonId': quote.salonId,
    'clientId': quote.clientId,
    'number': quote.number,
    'title': quote.title,
    'notes': quote.notes,
    'status': quote.status.name,
    'createdAt': Timestamp.fromDate(quote.createdAt),
    'updatedAt':
        quote.updatedAt != null ? Timestamp.fromDate(quote.updatedAt!) : null,
    'validUntil':
        quote.validUntil != null ? Timestamp.fromDate(quote.validUntil!) : null,
    'sentAt': quote.sentAt != null ? Timestamp.fromDate(quote.sentAt!) : null,
    'acceptedAt':
        quote.acceptedAt != null ? Timestamp.fromDate(quote.acceptedAt!) : null,
    'declinedAt':
        quote.declinedAt != null ? Timestamp.fromDate(quote.declinedAt!) : null,
    'ticketId': quote.ticketId,
    'sentChannels': quote.sentChannels.map((channel) => channel.name).toList(),
    'pdfStoragePath': quote.pdfStoragePath,
    'saleId': quote.saleId,
    'stripePaymentIntentId': quote.stripePaymentIntentId,
    'total': quote.total,
    'items':
        quote.items
            .map(
              (item) => {
                'id': item.id,
                'description': item.description,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'referenceType': item.referenceType.name,
                'serviceId': item.serviceId,
                'packageId': item.packageId,
                'inventoryItemId': item.inventoryItemId,
              },
            )
            .toList(),
  };

  map.removeWhere((_, value) => value == null);
  return map;
}

SalonStatus _stringToSalonStatus(String? value) {
  if (value == null) {
    return SalonStatus.active;
  }
  final normalized = value.toLowerCase();
  return SalonStatus.values.firstWhere(
    (status) => status.name.toLowerCase() == normalized,
    orElse: () => SalonStatus.active,
  );
}

PaymentTicketStatus _stringToTicketStatus(String? value) {
  if (value == null) {
    return PaymentTicketStatus.open;
  }
  final normalized = value.toLowerCase();
  return PaymentTicketStatus.values.firstWhere(
    (status) => status.name.toLowerCase() == normalized,
    orElse: () => PaymentTicketStatus.open,
  );
}

SalonEquipmentStatus _stringToEquipmentStatus(String? value) {
  if (value == null) {
    return SalonEquipmentStatus.operational;
  }
  final normalized = value.toLowerCase();
  return SalonEquipmentStatus.values.firstWhere(
    (status) => status.name.toLowerCase() == normalized,
    orElse: () => SalonEquipmentStatus.operational,
  );
}

SalonEquipment? _mapToSalonEquipment(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  return SalonEquipment(
    id: raw['id'] as String? ?? const Uuid().v4(),
    name: raw['name'] as String? ?? '',
    quantity: ((raw['quantity'] as num?) ?? 0).toInt(),
    status: _stringToEquipmentStatus(raw['status'] as String?),
    notes: raw['notes'] as String?,
  );
}

SalonClosure? _mapToSalonClosure(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  final start = _coerceToDateTime(raw['start']);
  final end = _coerceToDateTime(raw['end']) ?? start;
  if (start == null || end == null) {
    return null;
  }
  final id = raw['id'] as String? ?? const Uuid().v4();
  final reason = raw['reason'] as String?;
  try {
    return SalonClosure(id: id, start: start, end: end, reason: reason);
  } catch (_) {
    return null;
  }
}

DateTime? _coerceToDateTime(dynamic raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  if (raw is num) {
    final value = raw.toInt();
    if (value > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (raw is String) {
    return DateTime.tryParse(raw);
  }
  return null;
}

StaffMember staffFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final firstNameRaw = (data['firstName'] as String?)?.trim();
  final lastNameRaw = (data['lastName'] as String?)?.trim();
  final fullNameRaw = (data['fullName'] as String?)?.trim();

  String resolveFirstName() {
    if (firstNameRaw != null && firstNameRaw.isNotEmpty) {
      return firstNameRaw;
    }
    if (fullNameRaw != null && fullNameRaw.isNotEmpty) {
      final parts = fullNameRaw.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return parts.sublist(0, parts.length - 1).join(' ');
      }
      return fullNameRaw;
    }
    return '';
  }

  String resolveLastName() {
    if (lastNameRaw != null && lastNameRaw.isNotEmpty) {
      return lastNameRaw;
    }
    if (fullNameRaw != null && fullNameRaw.isNotEmpty) {
      final parts = fullNameRaw.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        return parts.last;
      }
    }
    return '';
  }

  final roleIdRaw = (data['roleId'] as String?)?.trim();
  final legacyRole = (data['role'] as String?)?.trim();
  final roleId =
      roleIdRaw != null && roleIdRaw.isNotEmpty
          ? roleIdRaw
          : (legacyRole != null && legacyRole.isNotEmpty)
          ? legacyRole
          : StaffMember.unknownRoleId;

  final roleIdsRaw = data['roleIds'];
  final roleIds =
      roleIdsRaw is Iterable
          ? roleIdsRaw
              .map((dynamic value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList()
          : <String>[];
  if (!roleIds.contains(roleId)) {
    roleIds.insert(0, roleId);
  }
  final normalizedRoleIds =
      roleIds.isEmpty ? const <String>[StaffMember.unknownRoleId] : roleIds;

  final dateOfBirthRaw = data['dateOfBirth'];
  final dateOfBirth =
      dateOfBirthRaw is Timestamp
          ? dateOfBirthRaw.toDate()
          : dateOfBirthRaw is DateTime
          ? dateOfBirthRaw
          : null;

  final vacationAllowance =
      (data['vacationAllowance'] as num?)?.toInt() ??
      StaffMember.defaultVacationAllowance;
  final permissionAllowance =
      (data['permissionAllowance'] as num?)?.toInt() ??
      StaffMember.defaultPermissionAllowance;
  final sortOrder = (data['sortOrder'] as num?)?.toInt() ?? 0;
  final avatarUrlRaw = (data['avatarUrl'] as String?)?.trim();
  final avatarStoragePathRaw = (data['avatarStoragePath'] as String?)?.trim();

  return StaffMember(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    firstName: resolveFirstName(),
    lastName: resolveLastName(),
    roleIds: normalizedRoleIds,
    phone: (data['phone'] as String?)?.trim(),
    email: (data['email'] as String?)?.trim(),
    dateOfBirth: dateOfBirth,
    isActive: data['isActive'] as bool? ?? true,
    isEquipment: data['isEquipment'] as bool? ?? false,
    vacationAllowance: vacationAllowance,
    permissionAllowance: permissionAllowance,
    sortOrder: sortOrder,
    avatarUrl:
        avatarUrlRaw != null && avatarUrlRaw.isNotEmpty ? avatarUrlRaw : null,
    avatarStoragePath:
        avatarStoragePathRaw != null && avatarStoragePathRaw.isNotEmpty
            ? avatarStoragePathRaw
            : null,
  );
}

Map<String, dynamic> staffToMap(StaffMember staff) {
  return {
    'salonId': staff.salonId,
    'firstName': staff.firstName,
    'lastName': staff.lastName,
    'fullName': staff.fullName,
    'roleId': staff.primaryRoleId,
    'role': staff.primaryRoleId,
    'roleIds': staff.roleIds,
    'phone': staff.phone,
    'email': staff.email,
    if (staff.dateOfBirth != null)
      'dateOfBirth': Timestamp.fromDate(staff.dateOfBirth!),
    'isActive': staff.isActive,
    'isEquipment': staff.isEquipment,
    'vacationAllowance': staff.vacationAllowance,
    'permissionAllowance': staff.permissionAllowance,
    'sortOrder': staff.sortOrder,
    if (staff.avatarUrl != null && staff.avatarUrl!.isNotEmpty)
      'avatarUrl': staff.avatarUrl,
    if (staff.avatarStoragePath != null && staff.avatarStoragePath!.isNotEmpty)
      'avatarStoragePath': staff.avatarStoragePath,
  };
}

StaffRole staffRoleFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return StaffRole(
    id: doc.id,
    name: (data['name'] as String? ?? '').trim(),
    salonId: (data['salonId'] as String?)?.trim(),
    description: (data['description'] as String?)?.trim(),
    color: (data['color'] as num?)?.toInt(),
    isDefault: data['isDefault'] as bool? ?? false,
    sortPriority: (data['sortPriority'] as num?)?.toInt() ?? 0,
  );
}

Map<String, dynamic> staffRoleToMap(StaffRole role) {
  return {
    'name': role.name,
    'salonId': role.salonId,
    'description': role.description,
    'color': role.color,
    'isDefault': role.isDefault,
    'sortPriority': role.sortPriority,
  };
}

Client clientFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final consentsRaw = data['consents'] as List<dynamic>? ?? const [];
  final invitationStatusRaw = data['invitationStatus'] as String?;
  final invitationSentAtRaw = data['invitationSentAt'];
  final firstLoginAtRaw = data['firstLoginAt'] ?? data['invitationAcceptedAt'];
  final onboardingCompletedAtRaw = data['onboardingCompletedAt'];
  final dateOfBirthRaw = data['dateOfBirth'];
  final channelPreferencesRaw =
      data['channelPreferences'] as Map<String, dynamic>?;
  final fcmTokensRaw = data['fcmTokens'] as List<dynamic>?;
  final rawCity = data['city'];
  final normalizedCity = rawCity is String ? rawCity.trim() : '';
  final rawAddress = data['address'];
  final normalizedAddress = rawAddress is String ? rawAddress.trim() : '';

  return Client(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    firstName: data['firstName'] as String? ?? '',
    lastName: data['lastName'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    gender: (data['gender'] as String?)?.trim(),
    clientNumber: data['clientNumber'] as String?,
    dateOfBirth:
        (dateOfBirthRaw is Timestamp)
            ? dateOfBirthRaw.toDate()
            : (dateOfBirthRaw is DateTime ? dateOfBirthRaw : null),
    address: normalizedAddress.isNotEmpty ? normalizedAddress : null,
    city:
        normalizedCity.isNotEmpty
            ? normalizedCity
            : (normalizedAddress.isNotEmpty ? normalizedAddress : null),
    profession: data['profession'] as String?,
    referralSource: data['referralSource'] as String?,
    email: data['email'] as String?,
    notes: data['notes'] as String?,
    stripeCustomerId: data['stripeCustomerId'] as String?,
    loyaltyInitialPoints: (data['loyaltyInitialPoints'] as num?)?.toInt() ?? 0,
    loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
    loyaltyUpdatedAt: _timestampToDate(data['loyaltyUpdatedAt']),
    loyaltyTotalEarned: (data['loyaltyTotalEarned'] as num?)?.toInt(),
    loyaltyTotalRedeemed: (data['loyaltyTotalRedeemed'] as num?)?.toInt(),
    marketedConsents:
        consentsRaw
            .map(
              (entry) => ClientConsent(
                type: _stringToConsentType(
                  (entry as Map<String, dynamic>)['type'] as String?,
                ),
                acceptedAt:
                    ((entry['acceptedAt'] as Timestamp?) ?? Timestamp.now())
                        .toDate(),
              ),
            )
            .toList(),
    fcmTokens:
        fcmTokensRaw
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[],
    channelPreferences: ChannelPreferences(
      push: channelPreferencesRaw?['push'] as bool? ?? true,
      email: channelPreferencesRaw?['email'] as bool? ?? true,
      whatsapp: channelPreferencesRaw?['whatsapp'] as bool? ?? false,
      sms: channelPreferencesRaw?['sms'] as bool? ?? false,
      updatedAt: (channelPreferencesRaw?['updatedAt'] as Timestamp?)?.toDate(),
    ),
    onboardingStatus: _onboardingStatusFromString(invitationStatusRaw),
    invitationSentAt:
        (invitationSentAtRaw is Timestamp)
            ? invitationSentAtRaw.toDate()
            : (invitationSentAtRaw is DateTime ? invitationSentAtRaw : null),
    firstLoginAt:
        (firstLoginAtRaw is Timestamp)
            ? firstLoginAtRaw.toDate()
            : (firstLoginAtRaw is DateTime ? firstLoginAtRaw : null),
    onboardingCompletedAt:
        (onboardingCompletedAtRaw is Timestamp)
            ? onboardingCompletedAtRaw.toDate()
            : (onboardingCompletedAtRaw is DateTime
                ? onboardingCompletedAtRaw
                : null),
    createdAt: _timestampToDate(data['createdAt']),
  );
}

Map<String, dynamic> clientToMap(Client client) {
  final map = <String, dynamic>{
    'salonId': client.salonId,
    'firstName': client.firstName,
    'lastName': client.lastName,
    'phone': client.phone,
    'gender': client.gender,
    'clientNumber': client.clientNumber,
    'dateOfBirth':
        client.dateOfBirth == null
            ? null
            : Timestamp.fromDate(client.dateOfBirth!),
    'address': client.address,
    'city': client.city,
    'profession': client.profession,
    'referralSource': client.referralSource,
    'email': client.email,
    'notes': client.notes,
    'loyaltyInitialPoints': client.loyaltyInitialPoints,
    'loyaltyPoints': client.loyaltyPoints,
    if (client.loyaltyUpdatedAt != null)
      'loyaltyUpdatedAt': Timestamp.fromDate(client.loyaltyUpdatedAt!),
    if (client.loyaltyTotalEarned != null)
      'loyaltyTotalEarned': client.loyaltyTotalEarned,
    if (client.loyaltyTotalRedeemed != null)
      'loyaltyTotalRedeemed': client.loyaltyTotalRedeemed,
    'fcmTokens': client.fcmTokens,
    'consents':
        client.marketedConsents
            .map(
              (consent) => {
                'type': consent.type.name,
                'acceptedAt': Timestamp.fromDate(consent.acceptedAt),
              },
            )
            .toList(),
    'channelPreferences': {
      'push': client.channelPreferences.push,
      'email': client.channelPreferences.email,
      'whatsapp': client.channelPreferences.whatsapp,
      'sms': client.channelPreferences.sms,
      if (client.channelPreferences.updatedAt != null)
        'updatedAt': Timestamp.fromDate(client.channelPreferences.updatedAt!),
    },
    'invitationStatus': client.onboardingStatus.name,
  };

  if (client.stripeCustomerId != null) {
    map['stripeCustomerId'] = client.stripeCustomerId;
  }

  if (client.invitationSentAt != null) {
    map['invitationSentAt'] = Timestamp.fromDate(client.invitationSentAt!);
  }
  if (client.firstLoginAt != null) {
    map['firstLoginAt'] = Timestamp.fromDate(client.firstLoginAt!);
  }
  if (client.onboardingCompletedAt != null) {
    map['onboardingCompletedAt'] = Timestamp.fromDate(
      client.onboardingCompletedAt!,
    );
  }
  if (client.createdAt != null) {
    map['createdAt'] = Timestamp.fromDate(client.createdAt!);
  } else {
    map['createdAt'] = FieldValue.serverTimestamp();
  }

  return map;
}

SalonAccessRequest salonAccessRequestFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? const <String, dynamic>{};
  final extraRaw = data['extraData'] as Map<String, dynamic>? ?? const {};
  return SalonAccessRequest(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    userId: data['userId'] as String? ?? '',
    clientId: data['clientId'] as String?,
    firstName: data['firstName'] as String? ?? '',
    lastName: data['lastName'] as String? ?? '',
    email: data['email'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    dateOfBirth: _timestampToDate(data['dateOfBirth']),
    extraData: Map<String, dynamic>.from(extraRaw),
    status: _stringToAccessRequestStatus(data['status'] as String?),
    createdAt: _timestampToDate(data['createdAt']),
    updatedAt: _timestampToDate(data['updatedAt']),
  );
}

Map<String, dynamic> salonAccessRequestToMap(SalonAccessRequest request) {
  final map = <String, dynamic>{
    'salonId': request.salonId,
    'userId': request.userId,
    'clientId': request.clientId,
    'firstName': request.firstName,
    'lastName': request.lastName,
    'email': request.email,
    'phone': request.phone,
    'status': _accessRequestStatusToString(request.status),
    'extraData': request.extraData,
  };
  if (request.dateOfBirth != null) {
    map['dateOfBirth'] = Timestamp.fromDate(request.dateOfBirth!);
  }
  if (request.createdAt != null) {
    map['createdAt'] = Timestamp.fromDate(request.createdAt!);
  }
  if (request.updatedAt != null) {
    map['updatedAt'] = Timestamp.fromDate(request.updatedAt!);
  }
  return map;
}

ClientQuestionnaireTemplate clientQuestionnaireTemplateFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final groupsRaw = data['groups'] as List<dynamic>? ?? const [];
  final groups =
      groupsRaw.map((raw) {
        final groupMap =
            (raw as Map<String, dynamic>?) ?? const <String, dynamic>{};
        final questionsRaw =
            groupMap['questions'] as List<dynamic>? ?? const [];
        final questions =
            questionsRaw.map((questionRaw) {
              final questionMap =
                  (questionRaw as Map<String, dynamic>?) ??
                  const <String, dynamic>{};
              final optionsRaw =
                  questionMap['options'] as List<dynamic>? ?? const [];
              final options =
                  optionsRaw.map((optionRaw) {
                    final optionMap =
                        (optionRaw as Map<String, dynamic>?) ??
                        const <String, dynamic>{};
                    return ClientQuestionOption(
                      id: optionMap['id'] as String? ?? const Uuid().v4(),
                      label: optionMap['label'] as String? ?? '',
                      description: optionMap['description'] as String?,
                    );
                  }).toList();
              return ClientQuestionDefinition(
                id: questionMap['id'] as String? ?? const Uuid().v4(),
                label: questionMap['label'] as String? ?? '',
                type:
                    _questionTypeFromString(questionMap['type'] as String?) ??
                    ClientQuestionType.text,
                helperText: questionMap['helperText'] as String?,
                isRequired: questionMap['isRequired'] as bool? ?? false,
                options: options,
              );
            }).toList();
        return ClientQuestionGroup(
          id: groupMap['id'] as String? ?? const Uuid().v4(),
          title: groupMap['title'] as String? ?? '',
          description: groupMap['description'] as String?,
          sortOrder: (groupMap['sortOrder'] as num?)?.toInt() ?? 0,
          questions: questions,
        );
      }).toList();

  return ClientQuestionnaireTemplate(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    description: data['description'] as String?,
    createdAt: _timestampToDate(data['createdAt']),
    updatedAt: _timestampToDate(data['updatedAt']),
    isDefault: data['isDefault'] as bool? ?? false,
    groups: groups,
  );
}

Map<String, dynamic> clientQuestionnaireTemplateToMap(
  ClientQuestionnaireTemplate template,
) {
  final map = <String, dynamic>{
    'salonId': template.salonId,
    'name': template.name,
    'isDefault': template.isDefault,
    'groups':
        template.groups
            .map(
              (group) => {
                'id': group.id,
                'title': group.title,
                'sortOrder': group.sortOrder,
                if (group.description != null) 'description': group.description,
                'questions':
                    group.questions
                        .map(
                          (question) => {
                            'id': question.id,
                            'label': question.label,
                            'type': question.type.name,
                            'isRequired': question.isRequired,
                            if (question.helperText != null)
                              'helperText': question.helperText,
                            if (question.options.isNotEmpty)
                              'options':
                                  question.options
                                      .map(
                                        (option) => {
                                          'id': option.id,
                                          'label': option.label,
                                          if (option.description != null)
                                            'description': option.description,
                                        },
                                      )
                                      .toList(),
                          },
                        )
                        .toList(),
              },
            )
            .toList(),
  };

  if (template.description != null) {
    map['description'] = template.description;
  }
  if (template.createdAt != null) {
    map['createdAt'] = Timestamp.fromDate(template.createdAt!);
  }
  if (template.updatedAt != null) {
    map['updatedAt'] = Timestamp.fromDate(template.updatedAt!);
  }

  return map;
}

ClientQuestionnaire clientQuestionnaireFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final answersRaw = data['answers'] as Map<String, dynamic>? ?? const {};
  final answers = <ClientQuestionAnswer>[];
  for (final entry in answersRaw.entries) {
    final answerMap =
        (entry.value as Map<String, dynamic>?) ?? const <String, dynamic>{};
    answers.add(
      ClientQuestionAnswer(
        questionId: entry.key,
        boolValue: answerMap['boolValue'] as bool?,
        textValue: answerMap['textValue'] as String?,
        optionIds: (answerMap['optionIds'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        numberValue: answerMap['numberValue'] as num?,
        dateValue: _timestampToDate(answerMap['dateValue']),
      ),
    );
  }

  return ClientQuestionnaire(
    id: doc.id,
    clientId: data['clientId'] as String? ?? '',
    salonId: data['salonId'] as String? ?? '',
    templateId: data['templateId'] as String? ?? '',
    answers: answers,
    createdAt: _timestampToDate(data['createdAt']) ?? DateTime.now(),
    updatedAt: _timestampToDate(data['updatedAt']) ?? DateTime.now(),
  );
}

Map<String, dynamic> clientQuestionnaireToMap(
  ClientQuestionnaire questionnaire,
) {
  final answers = <String, Map<String, dynamic>>{};
  for (final answer in questionnaire.answers) {
    final payload = <String, dynamic>{};
    if (answer.boolValue != null) {
      payload['boolValue'] = answer.boolValue;
    }
    if (answer.textValue != null) {
      payload['textValue'] = answer.textValue;
    }
    if (answer.optionIds.isNotEmpty) {
      payload['optionIds'] = answer.optionIds;
    }
    if (answer.numberValue != null) {
      payload['numberValue'] = answer.numberValue;
    }
    if (answer.dateValue != null) {
      payload['dateValue'] = Timestamp.fromDate(answer.dateValue!);
    }
    answers[answer.questionId] = payload;
  }

  return {
    'clientId': questionnaire.clientId,
    'salonId': questionnaire.salonId,
    'templateId': questionnaire.templateId,
    'answers': answers,
    'createdAt': Timestamp.fromDate(questionnaire.createdAt),
    'updatedAt': Timestamp.fromDate(questionnaire.updatedAt),
  };
}

ClientPhoto clientPhotoFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final rawSetType = data['setType'] as String?;
  ClientPhotoSetType? setType;
  if (rawSetType != null && rawSetType.isNotEmpty) {
    for (final candidate in ClientPhotoSetType.values) {
      if (candidate.name == rawSetType) {
        setType = candidate;
        break;
      }
    }
  }
  return ClientPhoto(
    id: doc.id,
    clientId: data['clientId'] as String? ?? '',
    salonId: data['salonId'] as String? ?? '',
    storagePath: data['storagePath'] as String? ?? '',
    downloadUrl: data['downloadUrl'] as String? ?? '',
    uploadedAt: _timestampToDate(data['uploadedAt']) ?? DateTime.now(),
    uploadedBy: data['uploadedBy'] as String? ?? '',
    fileName: data['fileName'] as String?,
    contentType: data['contentType'] as String?,
    sizeBytes: (data['sizeBytes'] as num?)?.toInt(),
    notes: data['notes'] as String?,
    setType: setType,
    setVersionIndex: (data['setVersionIndex'] as num?)?.toInt(),
    isSetActiveVersion: data['isSetActiveVersion'] as bool? ?? true,
    archivedAt: _timestampToDate(data['archivedAt']),
  );
}

Map<String, dynamic> clientPhotoToMap(ClientPhoto photo) {
  final map = <String, dynamic>{
    'clientId': photo.clientId,
    'salonId': photo.salonId,
    'storagePath': photo.storagePath,
    'downloadUrl': photo.downloadUrl,
    'uploadedAt': Timestamp.fromDate(photo.uploadedAt),
    'uploadedBy': photo.uploadedBy,
  };

  if (photo.fileName != null && photo.fileName!.isNotEmpty) {
    map['fileName'] = photo.fileName;
  }
  if (photo.contentType != null && photo.contentType!.isNotEmpty) {
    map['contentType'] = photo.contentType;
  }
  if (photo.sizeBytes != null && photo.sizeBytes! > 0) {
    map['sizeBytes'] = photo.sizeBytes;
  }
  if (photo.notes != null && photo.notes!.isNotEmpty) {
    map['notes'] = photo.notes;
  }
  if (photo.setType != null) {
    map['setType'] = photo.setType!.name;
  }
  if (photo.setVersionIndex != null) {
    map['setVersionIndex'] = photo.setVersionIndex;
  }
  map['isSetActiveVersion'] = photo.isSetActiveVersion;
  if (photo.archivedAt != null) {
    map['archivedAt'] = Timestamp.fromDate(photo.archivedAt!);
  }

  return map;
}

ClientPhotoCollage clientPhotoCollageFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final orientationRaw =
      data['orientation'] as String? ??
      ClientPhotoCollageOrientation.vertical.name;
  var orientation = ClientPhotoCollageOrientation.vertical;
  for (final candidate in ClientPhotoCollageOrientation.values) {
    if (candidate.name == orientationRaw) {
      orientation = candidate;
      break;
    }
  }
  final primaryDataRaw = data['primaryPlacement'];
  final secondaryDataRaw = data['secondaryPlacement'];
  final primaryData =
      primaryDataRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(primaryDataRaw)
          : <String, dynamic>{};
  final secondaryData =
      secondaryDataRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(secondaryDataRaw)
          : <String, dynamic>{};

  return ClientPhotoCollage(
    id: doc.id,
    clientId: data['clientId'] as String? ?? '',
    salonId: data['salonId'] as String? ?? '',
    createdAt: _timestampToDate(data['createdAt']) ?? DateTime.now(),
    createdBy: data['createdBy'] as String? ?? '',
    updatedAt: _timestampToDate(data['updatedAt']),
    orientation: orientation,
    primaryPlacement: ClientPhotoCollagePlacement.fromJson(primaryData),
    secondaryPlacement: ClientPhotoCollagePlacement.fromJson(secondaryData),
    storagePath: data['storagePath'] as String?,
    downloadUrl: data['downloadUrl'] as String?,
    thumbnailUrl: data['thumbnailUrl'] as String?,
    notes: data['notes'] as String?,
  );
}

Map<String, dynamic> clientPhotoCollageToMap(ClientPhotoCollage collage) {
  final map = <String, dynamic>{
    'clientId': collage.clientId,
    'salonId': collage.salonId,
    'createdAt': Timestamp.fromDate(collage.createdAt),
    'createdBy': collage.createdBy,
    'orientation': collage.orientation.name,
    'primaryPlacement': collage.primaryPlacement.toJson(),
    'secondaryPlacement': collage.secondaryPlacement.toJson(),
  };

  if (collage.updatedAt != null) {
    map['updatedAt'] = Timestamp.fromDate(collage.updatedAt!);
  }
  if (collage.storagePath != null && collage.storagePath!.isNotEmpty) {
    map['storagePath'] = collage.storagePath;
  }
  if (collage.downloadUrl != null && collage.downloadUrl!.isNotEmpty) {
    map['downloadUrl'] = collage.downloadUrl;
  }
  if (collage.thumbnailUrl != null && collage.thumbnailUrl!.isNotEmpty) {
    map['thumbnailUrl'] = collage.thumbnailUrl;
  }
  if (collage.notes != null && collage.notes!.isNotEmpty) {
    map['notes'] = collage.notes;
  }

  return map;
}

Service serviceFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return Service(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    category: data['category'] as String? ?? '',
    categoryId: data['categoryId'] as String?,
    duration: Duration(
      minutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
    ),
    price: (data['price'] as num?)?.toDouble() ?? 0,
    description: data['description'] as String?,
    staffRoles:
        (data['staffRoles'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
    requiredEquipmentIds:
        (data['requiredEquipmentIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
    extraDuration: Duration(
      minutes: (data['extraDurationMinutes'] as num?)?.toInt() ?? 0,
    ),
    isActive: data['isActive'] as bool? ?? true,
  );
}

Map<String, dynamic> serviceToMap(Service service) {
  final map = <String, dynamic>{
    'salonId': service.salonId,
    'name': service.name,
    'category': service.category,
    'durationMinutes': service.duration.inMinutes,
    'price': service.price,
    'description': service.description,
    'staffRoles': service.staffRoles,
    'requiredEquipmentIds': service.requiredEquipmentIds,
    'extraDurationMinutes': service.extraDuration.inMinutes,
    'isActive': service.isActive,
  };
  if (service.categoryId != null) {
    map['categoryId'] = service.categoryId;
  }
  return map;
}

ServiceCategory serviceCategoryFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final rawZoneServices =
      (data['bodyZoneServiceIds'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  final zoneServiceIds = <String, String>{};
  rawZoneServices.forEach((key, value) {
    final zoneKey = key?.toString() ?? '';
    final zoneValue = value?.toString() ?? '';
    if (zoneKey.isEmpty || zoneValue.isEmpty) {
      return;
    }
    zoneServiceIds[zoneKey] = zoneValue;
  });
  return ServiceCategory(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    description: data['description'] as String?,
    sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    color: (data['color'] as num?)?.toInt(),
    zoneServiceIds: zoneServiceIds,
  );
}

Map<String, dynamic> serviceCategoryToMap(ServiceCategory category) {
  final map = <String, dynamic>{
    'salonId': category.salonId,
    'name': category.name,
    'sortOrder': category.sortOrder,
  };
  if (category.description != null) {
    map['description'] = category.description;
  }
  if (category.color != null) {
    map['color'] = category.color;
  }
  if (category.zoneServiceIds.isNotEmpty) {
    map['bodyZoneServiceIds'] = category.zoneServiceIds;
  } else {
    map['bodyZoneServiceIds'] = <String, String>{};
  }
  return map;
}

ServicePackage packageFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return ServicePackage(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    price: (data['price'] as num?)?.toDouble() ?? 0,
    fullPrice:
        (data['fullPrice'] as num?)?.toDouble() ??
        (data['price'] as num?)?.toDouble() ??
        0,
    discountPercentage: (data['discountPercentage'] as num?)?.toDouble(),
    description: data['description'] as String?,
    serviceIds:
        (data['serviceIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
    sessionCount: (data['sessionCount'] as num?)?.toInt(),
    validDays: (data['validDays'] as num?)?.toInt(),
    serviceSessionCounts: _mapToIntMap(
      data['serviceSessionCounts'] as Map<String, dynamic>?,
    ),
    showOnClientDashboard:
        data.containsKey('showOnClientDashboard')
            ? _coerceToBool(data['showOnClientDashboard'])
            : true,
    isGeneratedFromServiceBuilder: _coerceToBool(
      data['isGeneratedFromServiceBuilder'],
    ),
  );
}

Map<String, dynamic> packageToMap(ServicePackage pkg) {
  final map = {
    'salonId': pkg.salonId,
    'name': pkg.name,
    'price': pkg.price,
    'fullPrice': pkg.fullPrice,
    'description': pkg.description,
    'serviceIds': pkg.serviceIds,
    'sessionCount': pkg.sessionCount,
    'validDays': pkg.validDays,
    'showOnClientDashboard': pkg.showOnClientDashboard,
    'isGeneratedFromServiceBuilder': pkg.isGeneratedFromServiceBuilder,
  };
  if (pkg.discountPercentage != null) {
    map['discountPercentage'] = pkg.discountPercentage;
  }
  if (pkg.serviceSessionCounts.isNotEmpty) {
    map['serviceSessionCounts'] = pkg.serviceSessionCounts;
  }
  return map;
}

Appointment appointmentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final allocationsRaw =
      data['serviceAllocations'] as List<dynamic>? ?? const [];
  final allocations = allocationsRaw
      .whereType<Map<String, dynamic>>()
      .map(AppointmentServiceAllocation.fromMap)
      .toList(growable: false);
  return Appointment(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    clientId: data['clientId'] as String? ?? '',
    staffId: data['staffId'] as String? ?? '',
    serviceId: data['serviceId'] as String? ?? '',
    serviceIds:
        (data['serviceIds'] as List<dynamic>?)?.whereType<String>().toList(),
    serviceAllocations: allocations,
    start: ((data['start'] as Timestamp?) ?? Timestamp.now()).toDate(),
    end: ((data['end'] as Timestamp?) ?? Timestamp.now()).toDate(),
    status: _stringToAppointmentStatus(data['status'] as String?),
    notes: data['notes'] as String?,
    packageId: data['packageId'] as String?,
    roomId: data['roomId'] as String?,
    lastMinuteSlotId: data['lastMinuteSlotId'] as String?,
    createdAt: _timestampToDate(data['createdAt']),
    bookingChannel: (data['bookingChannel'] as String?)?.trim(),
  );
}

Map<String, dynamic> appointmentToMap(Appointment appointment) {
  final allocations = appointment.serviceAllocations;
  return {
    'salonId': appointment.salonId,
    'clientId': appointment.clientId,
    'staffId': appointment.staffId,
    'serviceId': appointment.serviceId,
    'serviceIds': appointment.serviceIds,
    if (allocations.isNotEmpty)
      'serviceAllocations':
          allocations.map((allocation) => allocation.toMap()).toList(),
    'start': Timestamp.fromDate(appointment.start),
    'end': Timestamp.fromDate(appointment.end),
    'status': appointment.status.name,
    'notes': appointment.notes,
    'packageId': appointment.packageId,
    'roomId': appointment.roomId,
    'lastMinuteSlotId': appointment.lastMinuteSlotId,
    if (appointment.bookingChannel != null)
      'bookingChannel': appointment.bookingChannel,
    'createdAt':
        appointment.createdAt != null
            ? Timestamp.fromDate(appointment.createdAt!)
            : FieldValue.serverTimestamp(),
  };
}

AppointmentDayChecklist appointmentDayChecklistFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final itemsRaw = data['items'] as List<dynamic>? ?? const <dynamic>[];
  final items = itemsRaw
      .map(_appointmentChecklistItemFromMap)
      .whereType<AppointmentChecklistItem>()
      .toList(growable: false);
  return AppointmentDayChecklist(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    date: _timestampToDate(data['date']) ?? DateTime.now(),
    items: items,
    createdAt: _timestampToDate(data['createdAt']),
    updatedAt: _timestampToDate(data['updatedAt']),
  );
}

Map<String, dynamic> appointmentDayChecklistToMap(
  AppointmentDayChecklist checklist,
) {
  final now = DateTime.now();
  return <String, dynamic>{
    'salonId': checklist.salonId,
    'date': Timestamp.fromDate(checklist.date),
    'items': checklist.items
        .map((item) {
          final createdAt = item.createdAt;
          final updatedAt = item.updatedAt;
          return <String, dynamic>{
            'id': item.id,
            'label': item.label,
            'position': item.position,
            'isCompleted': item.isCompleted,
            if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt),
            if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt),
          };
        })
        .toList(growable: false),
    'createdAt': Timestamp.fromDate(checklist.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(checklist.updatedAt ?? now),
  };
}

Map<String, dynamic> publicAppointmentToMap(Appointment appointment) {
  return {
    'salonId': appointment.salonId,
    'staffId': appointment.staffId,
    'serviceId': appointment.serviceId,
    'serviceIds': appointment.serviceIds,
    'start': Timestamp.fromDate(appointment.start),
    'end': Timestamp.fromDate(appointment.end),
    'status': appointment.status.name,
    'roomId': appointment.roomId,
    'lastMinuteSlotId': appointment.lastMinuteSlotId,
    if (appointment.bookingChannel != null)
      'bookingChannel': appointment.bookingChannel,
    'createdAt':
        appointment.createdAt != null
            ? Timestamp.fromDate(appointment.createdAt!)
            : FieldValue.serverTimestamp(),
  };
}

InventoryItem inventoryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return InventoryItem(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    category: data['category'] as String? ?? '',
    quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
    unit: data['unit'] as String? ?? 'pz',
    threshold: (data['threshold'] as num?)?.toDouble() ?? 0,
    cost: (data['cost'] as num?)?.toDouble() ?? 0,
    sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
  );
}

Map<String, dynamic> inventoryToMap(InventoryItem item) {
  return {
    'salonId': item.salonId,
    'name': item.name,
    'category': item.category,
    'quantity': item.quantity,
    'unit': item.unit,
    'threshold': item.threshold,
    'cost': item.cost,
    'sellingPrice': item.sellingPrice,
    'updatedAt':
        item.updatedAt != null ? Timestamp.fromDate(item.updatedAt!) : null,
  };
}

Sale saleFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final createdAt =
      ((data['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate();
  final salePaymentMethod = _stringToPaymentMethod(
    data['paymentMethod'] as String?,
  );
  final itemsRaw = data['items'] as List<dynamic>? ?? const [];
  final total = (data['total'] as num?)?.toDouble() ?? 0;
  final paidAmountRaw = (data['paidAmount'] as num?)?.toDouble();
  final storedStatus = _salePaymentStatusFromString(
    data['paymentStatus'] as String?,
  );
  final paymentStatus =
      storedStatus ??
      (paidAmountRaw != null && (total - paidAmountRaw).abs() > 0.01
          ? SalePaymentStatus.deposit
          : SalePaymentStatus.paid);
  final paidAmount = paidAmountRaw ??
      (paymentStatus == SalePaymentStatus.deposit ||
              paymentStatus == SalePaymentStatus.posticipated
          ? 0
          : total);
  final paymentHistoryRaw =
      data['paymentHistory'] as List<dynamic>? ?? const [];
  final paymentHistory =
      paymentHistoryRaw
          .map((entry) => entry as Map<String, dynamic>?)
          .where((entry) => entry != null)
          .map((entry) {
            final map = entry!;
            final movementType = _salePaymentTypeFromString(
              map['type'] as String?,
            );
            if (movementType == null) {
              return null;
            }
            final method = _stringToPaymentMethod(
              map['paymentMethod'] as String?,
            );
            final timestamp = map['date'];
            final date = _timestampToDate(timestamp) ?? createdAt;
            final amountRaw = (map['amount'] as num?)?.toDouble();
            if (amountRaw == null) {
              return null;
            }
            return SalePaymentMovement(
              id: map['id'] as String? ?? const Uuid().v4(),
              amount: amountRaw,
              type: movementType,
              date: date,
              paymentMethod: method,
              recordedBy: map['recordedBy'] as String?,
              note: map['note'] as String?,
            );
          })
          .whereType<SalePaymentMovement>()
          .toList();
  final loyaltyRaw = data['loyalty'] as Map<String, dynamic>?;
  final metadataRaw = data['metadata'];
  final metadata =
      metadataRaw is Map
          ? Map<String, dynamic>.from(
            metadataRaw.map((key, value) => MapEntry(key.toString(), value)),
          )
          : const <String, dynamic>{};

  return Sale(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    clientId: data['clientId'] as String? ?? '',
    items:
        itemsRaw.map((item) {
          final map = item as Map<String, dynamic>;
          final depositsRaw = map['deposits'] as List<dynamic>? ?? const [];
          final deposits =
              depositsRaw.map((entry) {
                final depositMap = entry as Map<String, dynamic>;
                final methodValue = depositMap['paymentMethod'] as String?;
                final method =
                    methodValue == null
                        ? salePaymentMethod
                        : _stringToPaymentMethod(methodValue);
                return PackageDeposit(
                  id: depositMap['id'] as String? ?? const Uuid().v4(),
                  amount: (depositMap['amount'] as num?)?.toDouble() ?? 0,
                  date: _timestampToDate(depositMap['date']) ?? createdAt,
                  note: depositMap['note'] as String?,
                  paymentMethod: method,
                );
              }).toList();

          // Backward compatibility with legacy depositAmount field.
          final legacyDeposit = (map['depositAmount'] as num?)?.toDouble();
          if (deposits.isEmpty && legacyDeposit != null && legacyDeposit > 0) {
            deposits.add(
              PackageDeposit(
                id: const Uuid().v4(),
                amount: legacyDeposit,
                date: createdAt,
                note: 'Acconto registrato',
                paymentMethod: salePaymentMethod,
              ),
            );
          }

          return SaleItem(
            referenceId: map['referenceId'] as String? ?? '',
            referenceType: _stringToSaleReferenceType(
              map['referenceType'] as String?,
            ),
            description: map['description'] as String? ?? '',
            quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
            unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
            expirationDate: _timestampToDate(map['expirationDate']),
            totalSessions: (map['totalSessions'] as num?)?.toInt(),
            remainingSessions: (map['remainingSessions'] as num?)?.toInt(),
            packageStatus: _packageStatusFromString(
              map['packageStatus'] as String?,
            ),
            packagePaymentStatus: _packagePaymentStatusFromString(
              map['packagePaymentStatus'] as String?,
            ),
            deposits: deposits,
            packageServiceSessions: _mapToIntMap(
              map['packageServiceSessions'] as Map<String, dynamic>?,
            ),
            remainingPackageServiceSessions: _mapToIntMap(
              map['remainingPackageServiceSessions'] as Map<String, dynamic>?,
            ),
          );
        }).toList(),
    total: total,
    createdAt: createdAt,
    paymentMethod: salePaymentMethod,
    paymentStatus: paymentStatus,
    paidAmount: paidAmount,
    invoiceNumber: data['invoiceNumber'] as String?,
    notes: data['notes'] as String?,
    discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0,
    staffId: data['staffId'] as String?,
    paymentHistory: paymentHistory,
    loyalty: _mapToSaleLoyaltySummary(loyaltyRaw),
    metadata: metadata,
  );
}

Map<String, dynamic> saleToMap(Sale sale) {
  final map = {
    'salonId': sale.salonId,
    'clientId': sale.clientId,
    'items':
        sale.items.map((item) {
          final map = <String, dynamic>{
            'referenceId': item.referenceId,
            'referenceType': item.referenceType.name,
            'description': item.description,
            'quantity': item.quantity,
            'unitPrice': item.unitPrice,
          };
          if (item.expirationDate != null) {
            map['expirationDate'] = Timestamp.fromDate(item.expirationDate!);
          }
          if (item.totalSessions != null) {
            map['totalSessions'] = item.totalSessions;
          }
          if (item.remainingSessions != null) {
            map['remainingSessions'] = item.remainingSessions;
          }
          if (item.packageStatus != null) {
            map['packageStatus'] = item.packageStatus!.name;
          }
          if (item.packagePaymentStatus != null) {
            map['packagePaymentStatus'] = item.packagePaymentStatus!.name;
          }
          if (item.depositAmount != 0) {
            map['depositAmount'] = item.depositAmount;
          }
          if (item.deposits.isNotEmpty) {
            map['deposits'] =
                item.deposits
                    .map(
                      (deposit) => {
                        'id': deposit.id,
                        'amount': deposit.amount,
                        'date': Timestamp.fromDate(deposit.date),
                        'note': deposit.note,
                        'paymentMethod': deposit.paymentMethod.name,
                      },
                    )
                    .toList();
          }
          if (item.packageServiceSessions.isNotEmpty) {
            map['packageServiceSessions'] = item.packageServiceSessions;
          }
          if (item.remainingPackageServiceSessions.isNotEmpty) {
            map['remainingPackageServiceSessions'] =
                item.remainingPackageServiceSessions;
          }
          return map;
        }).toList(),
    'total': sale.total,
    'createdAt': Timestamp.fromDate(sale.createdAt),
    'paymentMethod': sale.paymentMethod.name,
    'paymentStatus': sale.paymentStatus.name,
    if (sale.paymentStatus == SalePaymentStatus.deposit ||
        (sale.paidAmount - sale.total).abs() > 0.01)
      'paidAmount': sale.paidAmount,
    'invoiceNumber': sale.invoiceNumber,
    'notes': sale.notes,
    if (sale.discountAmount != 0) 'discountAmount': sale.discountAmount,
    if (sale.staffId != null) 'staffId': sale.staffId,
    'paymentHistory':
        sale.paymentHistory
            .map(
              (movement) => {
                'id': movement.id,
                'amount': movement.amount,
                'type': movement.type.name,
                'date': Timestamp.fromDate(movement.date),
                'paymentMethod': movement.paymentMethod.name,
                if (movement.recordedBy != null)
                  'recordedBy': movement.recordedBy,
                if (movement.note != null && movement.note!.isNotEmpty)
                  'note': movement.note,
              },
            )
            .toList(),
  };

  final loyaltyMap = _saleLoyaltySummaryToMap(sale.loyalty);
  if (loyaltyMap != null) {
    map['loyalty'] = loyaltyMap;
  }
  if (sale.metadata.isNotEmpty) {
    map['metadata'] = sale.metadata;
  }

  return map;
}

Map<String, int> _mapToIntMap(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) {
    return const {};
  }
  return raw.map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0))
    ..removeWhere((key, value) => value <= 0);
}

LoyaltySettings _mapToLoyaltySettings(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) {
    return const LoyaltySettings();
  }
  final earningRaw = raw['earning'] as Map<String, dynamic>?;
  final redemptionRaw = raw['redemption'] as Map<String, dynamic>?;
  final expirationRaw = raw['expiration'] as Map<String, dynamic>?;
  return LoyaltySettings(
    enabled: raw['enabled'] as bool? ?? false,
    earning: LoyaltyEarningRules(
      euroPerPoint: (earningRaw?['euroPerPoint'] as num?)?.toDouble() ?? 10,
      rounding: _loyaltyRoundingFromString(earningRaw?['rounding'] as String?),
    ),
    redemption: LoyaltyRedemptionRules(
      pointValueEuro:
          (redemptionRaw?['pointValueEuro'] as num?)?.toDouble() ?? 1,
      maxPercent: (redemptionRaw?['maxPercent'] as num?)?.toDouble() ?? 0.3,
      autoSuggest: redemptionRaw?['autoSuggest'] as bool? ?? true,
    ),
    expiration: LoyaltyExpirationRules(
      resetMonth: (expirationRaw?['resetMonth'] as num?)?.toInt() ?? 1,
      resetDay: (expirationRaw?['resetDay'] as num?)?.toInt() ?? 1,
      timezone: expirationRaw?['timezone'] as String? ?? 'Europe/Rome',
    ),
    initialBalance: (raw['initialBalance'] as num?)?.toInt() ?? 0,
    updatedAt: _timestampToDate(raw['updatedAt']),
  );
}

Map<String, dynamic>? _loyaltySettingsToMap(LoyaltySettings settings) {
  if (!settings.enabled &&
      settings.initialBalance == 0 &&
      settings.updatedAt == null &&
      settings.earning.euroPerPoint == 10 &&
      settings.earning.rounding == LoyaltyRoundingMode.floor &&
      settings.redemption.pointValueEuro == 1 &&
      settings.redemption.maxPercent == 0.3 &&
      settings.redemption.autoSuggest &&
      settings.expiration.resetMonth == 1 &&
      settings.expiration.resetDay == 1 &&
      settings.expiration.timezone == 'Europe/Rome') {
    return null;
  }
  final map = <String, dynamic>{
    'enabled': settings.enabled,
    'earning': {
      'euroPerPoint': settings.earning.euroPerPoint,
      'rounding': settings.earning.rounding.name,
    },
    'redemption': {
      'pointValueEuro': settings.redemption.pointValueEuro,
      'maxPercent': settings.redemption.maxPercent,
      'autoSuggest': settings.redemption.autoSuggest,
    },
    'expiration': {
      'resetMonth': settings.expiration.resetMonth,
      'resetDay': settings.expiration.resetDay,
      'timezone': settings.expiration.timezone,
    },
    'initialBalance': settings.initialBalance,
  };
  if (settings.updatedAt != null) {
    map['updatedAt'] = Timestamp.fromDate(settings.updatedAt!);
  }
  return map;
}

LoyaltyRoundingMode _loyaltyRoundingFromString(String? value) {
  switch (value) {
    case 'round':
      return LoyaltyRoundingMode.round;
    case 'ceil':
      return LoyaltyRoundingMode.ceil;
    case 'floor':
    default:
      return LoyaltyRoundingMode.floor;
  }
}

ClientRegistrationSettings _mapToClientRegistrationSettings(
  Map<String, dynamic>? data,
) {
  if (data == null) {
    return const ClientRegistrationSettings();
  }
  final mode = _stringToClientRegistrationAccessMode(
    data['accessMode'] as String?,
  );
  final extraRaw = data['extraFields'] as List<dynamic>? ?? const [];
  final extra = extraRaw
      .map((value) => _stringToClientRegistrationExtraField(value?.toString()))
      .whereType<ClientRegistrationExtraField>()
      .toList(growable: false);
  return ClientRegistrationSettings(accessMode: mode, extraFields: extra);
}

Map<String, dynamic> _clientRegistrationToMap(
  ClientRegistrationSettings settings,
) {
  return {
    'accessMode': _clientRegistrationAccessModeToString(settings.accessMode),
    'extraFields': settings.extraFields
        .map(_clientRegistrationExtraFieldToString)
        .toList(growable: false),
  };
}

ClientRegistrationAccessMode _stringToClientRegistrationAccessMode(
  String? value,
) {
  switch (value) {
    case 'approval':
      return ClientRegistrationAccessMode.approval;
    case 'open':
    default:
      return ClientRegistrationAccessMode.open;
  }
}

String _clientRegistrationAccessModeToString(
  ClientRegistrationAccessMode mode,
) {
  switch (mode) {
    case ClientRegistrationAccessMode.open:
      return 'open';
    case ClientRegistrationAccessMode.approval:
      return 'approval';
  }
}

ClientRegistrationExtraField? _stringToClientRegistrationExtraField(
  String? value,
) {
  switch (value) {
    case 'address':
      return ClientRegistrationExtraField.address;
    case 'profession':
      return ClientRegistrationExtraField.profession;
    case 'referralSource':
      return ClientRegistrationExtraField.referralSource;
    case 'notes':
      return ClientRegistrationExtraField.notes;
    case 'gender':
      return ClientRegistrationExtraField.gender;
    default:
      return null;
  }
}

String _clientRegistrationExtraFieldToString(
  ClientRegistrationExtraField field,
) {
  switch (field) {
    case ClientRegistrationExtraField.address:
      return 'address';
    case ClientRegistrationExtraField.profession:
      return 'profession';
    case ClientRegistrationExtraField.referralSource:
      return 'referralSource';
    case ClientRegistrationExtraField.notes:
      return 'notes';
    case ClientRegistrationExtraField.gender:
      return 'gender';
  }
}

SalonAccessRequestStatus _stringToAccessRequestStatus(String? value) {
  switch (value) {
    case 'approved':
      return SalonAccessRequestStatus.approved;
    case 'rejected':
      return SalonAccessRequestStatus.rejected;
    case 'pending':
    default:
      return SalonAccessRequestStatus.pending;
  }
}

String _accessRequestStatusToString(SalonAccessRequestStatus status) {
  switch (status) {
    case SalonAccessRequestStatus.pending:
      return 'pending';
    case SalonAccessRequestStatus.approved:
      return 'approved';
    case SalonAccessRequestStatus.rejected:
      return 'rejected';
  }
}

SaleLoyaltySummary _mapToSaleLoyaltySummary(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) {
    return SaleLoyaltySummary();
  }
  return SaleLoyaltySummary(
    redeemedPoints: (raw['redeemedPoints'] as num?)?.toInt() ?? 0,
    redeemedValue: (raw['redeemedValue'] as num?)?.toDouble() ?? 0,
    eligibleAmount: (raw['eligibleAmount'] as num?)?.toDouble() ?? 0,
    requestedEarnPoints: (raw['requestedEarnPoints'] as num?)?.toInt() ?? 0,
    requestedEarnValue: (raw['requestedEarnValue'] as num?)?.toDouble() ?? 0,
    processedMovementIds:
        (raw['processedMovementIds'] as List<dynamic>? ?? const [])
            .map((entry) => entry.toString())
            .where((entry) => entry.isNotEmpty)
            .toList(),
    earnedPoints: (raw['earnedPoints'] as num?)?.toInt() ?? 0,
    earnedValue: (raw['earnedValue'] as num?)?.toDouble() ?? 0,
    netPoints: (raw['netPoints'] as num?)?.toInt() ?? 0,
    computedAt: _timestampToDate(raw['computedAt']),
    version: (raw['version'] as num?)?.toInt() ?? 1,
  );
}

Map<String, dynamic>? _saleLoyaltySummaryToMap(SaleLoyaltySummary summary) {
  if (_isSaleLoyaltySummaryEmpty(summary)) {
    return null;
  }
  final map = <String, dynamic>{
    'redeemedPoints': summary.redeemedPoints,
    'redeemedValue': summary.redeemedValue,
    'eligibleAmount': summary.eligibleAmount,
    'requestedEarnPoints': summary.requestedEarnPoints,
    'requestedEarnValue': summary.requestedEarnValue,
    if (summary.processedMovementIds.isNotEmpty)
      'processedMovementIds': summary.processedMovementIds,
    'earnedPoints': summary.earnedPoints,
    'earnedValue': summary.earnedValue,
    'netPoints': summary.netPoints,
    'version': summary.version,
  };
  if (summary.computedAt != null) {
    map['computedAt'] = Timestamp.fromDate(summary.computedAt!);
  }
  return map;
}

bool _isSaleLoyaltySummaryEmpty(SaleLoyaltySummary summary) {
  return summary.redeemedPoints == 0 &&
      summary.redeemedValue == 0 &&
      summary.eligibleAmount == 0 &&
      summary.requestedEarnPoints == 0 &&
      summary.requestedEarnValue == 0 &&
      summary.earnedPoints == 0 &&
      summary.earnedValue == 0 &&
      summary.netPoints == 0 &&
      summary.processedMovementIds.isEmpty &&
      summary.computedAt == null;
}

AppointmentChecklistItem? _appointmentChecklistItemFromMap(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  final id = (raw['id'] as String?)?.trim();
  if (id == null || id.isEmpty) {
    return null;
  }
  final label = (raw['label'] as String?)?.trim() ?? '';
  return AppointmentChecklistItem(
    id: id,
    label: label,
    position: (raw['position'] as num?)?.toInt() ?? 0,
    isCompleted: raw['isCompleted'] == true,
    createdAt: _timestampToDate(raw['createdAt']),
    updatedAt: _timestampToDate(raw['updatedAt']),
  );
}

DateTime? _timestampToDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

ClientQuestionType? _questionTypeFromString(String? raw) {
  switch (raw) {
    case 'boolean':
      return ClientQuestionType.boolean;
    case 'text':
      return ClientQuestionType.text;
    case 'textarea':
      return ClientQuestionType.textarea;
    case 'singleChoice':
      return ClientQuestionType.singleChoice;
    case 'multiChoice':
      return ClientQuestionType.multiChoice;
    case 'number':
      return ClientQuestionType.number;
    case 'date':
      return ClientQuestionType.date;
    default:
      return null;
  }
}

PackagePurchaseStatus? _packageStatusFromString(String? value) {
  switch (value) {
    case 'active':
      return PackagePurchaseStatus.active;
    case 'completed':
      return PackagePurchaseStatus.completed;
    case 'cancelled':
      return PackagePurchaseStatus.cancelled;
    default:
      return null;
  }
}

PackagePaymentStatus? _packagePaymentStatusFromString(String? value) {
  switch (value) {
    case 'deposit':
      return PackagePaymentStatus.deposit;
    case 'paid':
      return PackagePaymentStatus.paid;
    default:
      return null;
  }
}

SalePaymentStatus? _salePaymentStatusFromString(String? value) {
  switch (value) {
    case 'deposit':
      return SalePaymentStatus.deposit;
    case 'paid':
      return SalePaymentStatus.paid;
    case 'posticipated':
      return SalePaymentStatus.posticipated;
    default:
      return null;
  }
}

SalePaymentType? _salePaymentTypeFromString(String? value) {
  switch (value) {
    case 'deposit':
      return SalePaymentType.deposit;
    case 'settlement':
      return SalePaymentType.settlement;
    default:
      return null;
  }
}

CashFlowEntry cashFlowFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return CashFlowEntry(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    type: _stringToCashFlowType(data['type'] as String?),
    amount: (data['amount'] as num?)?.toDouble() ?? 0,
    date: ((data['date'] as Timestamp?) ?? Timestamp.now()).toDate(),
    createdAt: _coerceToDateTime(data['createdAt']),
    description: data['description'] as String?,
    category: data['category'] as String?,
    staffId: data['staffId'] as String?,
  );
}

Map<String, dynamic> cashFlowToMap(CashFlowEntry entry) {
  return {
    'salonId': entry.salonId,
    'type': entry.type.name,
    'amount': entry.amount,
    'date': Timestamp.fromDate(entry.date),
    'createdAt': Timestamp.fromDate(entry.createdAt),
    'description': entry.description,
    'category': entry.category,
    'staffId': entry.staffId,
  };
}

MessageTemplate messageTemplateFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  return MessageTemplate(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    title: data['title'] as String? ?? '',
    body: data['body'] as String? ?? '',
    channel: _stringToMessageChannel(data['channel'] as String?),
    usage: _stringToTemplateUsage(data['usage'] as String?),
    isActive: data['isActive'] as bool? ?? true,
  );
}

Map<String, dynamic> messageTemplateToMap(MessageTemplate template) {
  return {
    'salonId': template.salonId,
    'title': template.title,
    'body': template.body,
    'channel': template.channel.name,
    'usage': template.usage.name,
    'isActive': template.isActive,
  };
}

LastMinuteNotificationAudience _lastMinuteAudienceFromString(String? value) {
  switch (value) {
    case 'everyone':
      return LastMinuteNotificationAudience.everyone;
    case 'ownerSelection':
      return LastMinuteNotificationAudience.ownerSelection;
    case 'none':
    case null:
    default:
      return LastMinuteNotificationAudience.none;
  }
}

String _lastMinuteAudienceToString(LastMinuteNotificationAudience audience) {
  switch (audience) {
    case LastMinuteNotificationAudience.none:
      return 'none';
    case LastMinuteNotificationAudience.everyone:
      return 'everyone';
    case LastMinuteNotificationAudience.ownerSelection:
      return 'ownerSelection';
  }
}

ReminderSettings reminderSettingsFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final parentSalonId = doc.reference.parent.parent?.id;
  final salonIdRaw = data['salonId'] as String?;
  final resolvedSalonId =
      (salonIdRaw != null && salonIdRaw.trim().isNotEmpty)
          ? salonIdRaw
          : (parentSalonId ?? doc.id);

  List<ReminderOffsetConfig> offsets = const <ReminderOffsetConfig>[];
  final offsetsRaw = data['offsets'];
  if (offsetsRaw is Iterable) {
    offsets =
        offsetsRaw
            .map((entry) {
              if (entry is! Map<String, dynamic>) {
                return null;
              }
              final id = entry['id'] as String? ?? '';
              final minutesBefore =
                  (entry['minutesBefore'] as num?)?.toInt() ??
                  (entry['minutes'] as num?)?.toInt() ??
                  0;
              final active = entry['active'] as bool? ?? true;
              final title = entry['title'] as String?;
              final bodyTemplate = entry['bodyTemplate'] as String?;
              return ReminderOffsetConfig(
                id: id,
                minutesBefore: minutesBefore,
                active: active,
                title: title,
                bodyTemplate: bodyTemplate,
              );
            })
            .whereType<ReminderOffsetConfig>()
            .toList();
  }

  if (offsets.isEmpty) {
    final explicitOffsets = _parseReminderOffsets(
      data['appointmentOffsetsMinutes'],
    );
    if (explicitOffsets.isNotEmpty) {
      offsets =
          explicitOffsets
              .map(
                (minutes) => ReminderOffsetConfig(
                  id: 'M$minutes',
                  minutesBefore: minutes,
                ),
              )
              .toList();
    } else {
      final legacyOffsets = <int>[
        if (data['dayBeforeEnabled'] == true) 1440,
        if (data['threeHoursEnabled'] == true) 180,
        if (data['oneHourEnabled'] == true) 60,
      ];
      if (legacyOffsets.isNotEmpty) {
        offsets =
            legacyOffsets
                .map(
                  (minutes) => ReminderOffsetConfig(
                    id: 'M$minutes',
                    minutesBefore: minutes,
                  ),
                )
                .toList();
      }
    }
  }

  final audience = _lastMinuteAudienceFromString(
    data['lastMinuteNotificationAudience'] as String?,
  );

  return ReminderSettings(
    salonId: resolvedSalonId,
    offsets: offsets,
    birthdayEnabled: data['birthdayEnabled'] as bool? ?? true,
    lastMinuteNotificationAudience: audience,
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    updatedBy: data['updatedBy'] as String?,
  );
}

Map<String, dynamic> reminderSettingsToMap(ReminderSettings settings) {
  final offsets =
      settings.offsets.map((offset) {
        return {
          'id': offset.id,
          'minutesBefore': offset.minutesBefore,
          'active': offset.active,
          if (offset.title != null) 'title': offset.title,
          if (offset.bodyTemplate != null) 'bodyTemplate': offset.bodyTemplate,
        };
      }).toList();

  return {
    'salonId': settings.salonId,
    'offsets': offsets,
    'appointmentOffsetsMinutes': settings.activeOffsetsMinutes,
    'birthdayEnabled': settings.birthdayEnabled,
    'lastMinuteNotificationAudience': _lastMinuteAudienceToString(
      settings.lastMinuteNotificationAudience,
    ),
    if (settings.updatedAt != null)
      'updatedAt': Timestamp.fromDate(settings.updatedAt!),
    'updatedBy': settings.updatedBy,
  };
}

List<int> _parseReminderOffsets(dynamic value) {
  if (value is Iterable) {
    final offsets = <int>[];
    for (final item in value) {
      if (item is int) {
        offsets.add(item);
      } else if (item is num) {
        offsets.add(item.toInt());
      }
    }
    return offsets;
  }
  return const <int>[];
}

AppNotification appNotificationFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final payloadRaw = data['payload'];
  final payload =
      payloadRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(payloadRaw)
          : <String, dynamic>{};

  final createdAtRaw = data['createdAt'];
  final scheduledAtRaw = data['scheduledAt'];
  final sentAtRaw = data['sentAt'];
  final readAtRaw = data['readAt'];

  return AppNotification(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    clientId: data['clientId'] as String? ?? '',
    channel: _stringToMessageChannel(data['channel'] as String?),
    status: data['status'] as String? ?? 'pending',
    title: data['title'] as String? ?? payload['title'] as String?,
    body: data['body'] as String? ?? payload['body'] as String?,
    payload: payload,
    createdAt:
        (createdAtRaw is Timestamp)
            ? createdAtRaw.toDate()
            : (createdAtRaw is DateTime ? createdAtRaw : DateTime.now()),
    scheduledAt:
        (scheduledAtRaw is Timestamp)
            ? scheduledAtRaw.toDate()
            : (scheduledAtRaw is DateTime ? scheduledAtRaw : null),
    sentAt:
        (sentAtRaw is Timestamp)
            ? sentAtRaw.toDate()
            : (sentAtRaw is DateTime ? sentAtRaw : null),
    type: data['type'] as String? ?? payload['type'] as String?,
    offsetMinutes: (payload['offsetMinutes'] as num?)?.toInt(),
    readAt:
        (readAtRaw is Timestamp)
            ? readAtRaw.toDate()
            : (readAtRaw is DateTime ? readAtRaw : null),
  );
}

ClientAppMovement clientAppMovementFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  final type =
      clientAppMovementTypeFromName(data['type'] as String?) ??
      ClientAppMovementType.registration;
  return ClientAppMovement(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    clientId: data['clientId'] as String? ?? '',
    type: type,
    timestamp: _timestampToDate(data['timestamp']) ?? DateTime.now(),
    source: data['source'] as String?,
    channel: data['channel'] as String?,
    label: data['label'] as String?,
    description: data['description'] as String?,
    appointmentId: data['appointmentId'] as String?,
    saleId: data['saleId'] as String?,
    lastMinuteSlotId: data['lastMinuteSlotId'] as String?,
    createdBy: data['createdBy'] as String?,
    metadata: _mapFromDynamic(data['metadata']),
  );
}

Map<String, dynamic> clientAppMovementToMap(ClientAppMovement movement) {
  final map = <String, dynamic>{
    'salonId': movement.salonId,
    'clientId': movement.clientId,
    'type': movement.type.name,
    'timestamp': Timestamp.fromDate(movement.timestamp),
    if (movement.source != null) 'source': movement.source,
    if (movement.channel != null) 'channel': movement.channel,
    if (movement.label != null) 'label': movement.label,
    if (movement.description != null) 'description': movement.description,
    if (movement.appointmentId != null) 'appointmentId': movement.appointmentId,
    if (movement.saleId != null) 'saleId': movement.saleId,
    if (movement.lastMinuteSlotId != null)
      'lastMinuteSlotId': movement.lastMinuteSlotId,
    if (movement.createdBy != null) 'createdBy': movement.createdBy,
    if (movement.metadata.isNotEmpty) 'metadata': movement.metadata,
  };
  return map;
}

Shift shiftFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final breakStartTimestamp = data['breakStart'] as Timestamp?;
  final breakEndTimestamp = data['breakEnd'] as Timestamp?;
  final recurrenceData = data['recurrence'] as Map<String, dynamic>?;

  ShiftRecurrence? recurrence;
  if (recurrenceData != null) {
    final frequencyName = recurrenceData['frequency'] as String?;
    final interval = recurrenceData['interval'] as int? ?? 1;
    final untilTimestamp = recurrenceData['until'] as Timestamp?;
    final until = (untilTimestamp ?? Timestamp.now()).toDate();
    final recurrenceWeekdaysRaw = (recurrenceData['weekdays'] as List<dynamic>?)
        ?.map((value) => value is int ? value : null)
        .whereType<int>()
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toList(growable: false);
    final recurrenceWeekdays =
        recurrenceWeekdaysRaw != null && recurrenceWeekdaysRaw.isNotEmpty
            ? List<int>.unmodifiable(recurrenceWeekdaysRaw)
            : null;
    recurrence = ShiftRecurrence(
      frequency: ShiftRecurrenceFrequency.values.firstWhere(
        (value) => value.name == frequencyName,
        orElse: () => ShiftRecurrenceFrequency.weekly,
      ),
      interval: interval,
      until: until,
      weekdays: recurrenceWeekdays,
      activeWeeks: (recurrenceData['activeWeeks'] as num?)?.toInt(),
      inactiveWeeks: (recurrenceData['inactiveWeeks'] as num?)?.toInt(),
    );
  }

  final rawRoomId = data['roomId'];
  final normalizedRoomId =
      rawRoomId is String && rawRoomId.trim().isNotEmpty
          ? rawRoomId.trim()
          : null;

  return Shift(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    staffId: data['staffId'] as String? ?? '',
    start: ((data['start'] as Timestamp?) ?? Timestamp.now()).toDate(),
    end: ((data['end'] as Timestamp?) ?? Timestamp.now()).toDate(),
    roomId: normalizedRoomId,
    notes: data['notes'] as String?,
    breakStart: breakStartTimestamp?.toDate(),
    breakEnd: breakEndTimestamp?.toDate(),
    seriesId: data['seriesId'] as String?,
    recurrence: recurrence,
  );
}

Map<String, dynamic> shiftToMap(Shift shift) {
  return {
    'salonId': shift.salonId,
    'staffId': shift.staffId,
    'start': Timestamp.fromDate(shift.start),
    'end': Timestamp.fromDate(shift.end),
    'roomId': shift.roomId,
    'notes': shift.notes,
    if (shift.breakStart != null)
      'breakStart': Timestamp.fromDate(shift.breakStart!),
    if (shift.breakEnd != null) 'breakEnd': Timestamp.fromDate(shift.breakEnd!),
    if (shift.seriesId != null) 'seriesId': shift.seriesId,
    if (shift.recurrence != null)
      'recurrence': {
        'frequency': shift.recurrence!.frequency.name,
        'interval': shift.recurrence!.interval,
        'until': Timestamp.fromDate(shift.recurrence!.until),
        if (shift.recurrence!.weekdays != null &&
            shift.recurrence!.weekdays!.isNotEmpty)
          'weekdays': shift.recurrence!.weekdays,
        if (shift.recurrence!.activeWeeks != null)
          'activeWeeks': shift.recurrence!.activeWeeks,
        if (shift.recurrence!.inactiveWeeks != null)
          'inactiveWeeks': shift.recurrence!.inactiveWeeks,
      },
  };
}

StaffAbsence staffAbsenceFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return StaffAbsence(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    staffId: data['staffId'] as String? ?? '',
    type: _stringToStaffAbsenceType(data['type'] as String?),
    start: ((data['start'] as Timestamp?) ?? Timestamp.now()).toDate(),
    end: ((data['end'] as Timestamp?) ?? Timestamp.now()).toDate(),
    notes: data['notes'] as String?,
  );
}

Map<String, dynamic> staffAbsenceToMap(StaffAbsence absence) {
  return {
    'salonId': absence.salonId,
    'staffId': absence.staffId,
    'type': absence.type.name,
    'start': Timestamp.fromDate(absence.start),
    'end': Timestamp.fromDate(absence.end),
    'notes': absence.notes,
  };
}

StaffAbsenceType _stringToStaffAbsenceType(String? value) {
  return StaffAbsenceType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => StaffAbsenceType.vacation,
  );
}

ConsentType _stringToConsentType(String? value) {
  return ConsentType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => ConsentType.privacy,
  );
}

AppointmentStatus _stringToAppointmentStatus(String? value) {
  return AppointmentStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => AppointmentStatus.scheduled,
  );
}

SaleReferenceType _stringToSaleReferenceType(String? value) {
  return SaleReferenceType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => SaleReferenceType.service,
  );
}

PaymentMethod _stringToPaymentMethod(String? value) {
  return PaymentMethod.values.firstWhere(
    (method) => method.name == value,
    orElse: () => PaymentMethod.pos,
  );
}

CashFlowType _stringToCashFlowType(String? value) {
  return CashFlowType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => CashFlowType.income,
  );
}

List<MessageChannel> _mapToMessageChannels(List<dynamic>? raw) {
  if (raw == null || raw.isEmpty) {
    return const <MessageChannel>[];
  }
  final channels = <MessageChannel>[];
  for (final entry in raw) {
    if (entry is! String) {
      continue;
    }
    final channel = _stringToMessageChannel(entry);
    if (!channels.contains(channel)) {
      channels.add(channel);
    }
  }
  return List.unmodifiable(channels);
}

MessageChannel _stringToMessageChannel(String? value) {
  return MessageChannel.values.firstWhere(
    (channel) => channel.name == value,
    orElse: () => MessageChannel.whatsapp,
  );
}

QuoteStatus _stringToQuoteStatus(String? value) {
  if (value == null || value.isEmpty) {
    return QuoteStatus.draft;
  }
  return QuoteStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => QuoteStatus.draft,
  );
}

ClientOnboardingStatus _onboardingStatusFromString(String? value) {
  if (value == null) {
    return ClientOnboardingStatus.notSent;
  }
  final normalized = value.toLowerCase();
  switch (normalized) {
    case 'invitationsent':
    case 'linksent':
    case 'sent':
      return ClientOnboardingStatus.invitationSent;
    case 'invitationaccepted':
    case 'accepted':
    case 'firstlogin':
    case 'firstaccess':
    case 'loggedin':
      return ClientOnboardingStatus.firstLogin;
    case 'onboardingcompleted':
    case 'completed':
      return ClientOnboardingStatus.onboardingCompleted;
    case 'notsent':
    default:
      return ClientOnboardingStatus.notSent;
  }
}

TemplateUsage _stringToTemplateUsage(String? value) {
  return TemplateUsage.values.firstWhere(
    (usage) => usage.name == value,
    orElse: () => TemplateUsage.reminder,
  );
}

Map<String, dynamic> _mapFromDynamic(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

double? _coerceToDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
  return null;
}

bool _coerceToBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on';
  }
  return false;
}
