import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/app_notification.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/package.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

Salon salonFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final roomsRaw = data['rooms'] as List<dynamic>? ?? const [];
  final scheduleRaw = data['schedule'] as List<dynamic>? ?? const [];
  final equipmentRaw = data['equipment'] as List<dynamic>? ?? const [];
  final closuresRaw = data['closures'] as List<dynamic>? ?? const [];
  return Salon(
    id: doc.id,
    name: data['name'] as String? ?? '',
    address: data['address'] as String? ?? '',
    city: data['city'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String? ?? '',
    postalCode: data['postalCode'] as String?,
    bookingLink: data['bookingLink'] as String?,
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
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
  );
}

Map<String, dynamic> salonToMap(Salon salon) {
  return {
    'name': salon.name,
    'address': salon.address,
    'city': salon.city,
    'phone': salon.phone,
    'email': salon.email,
    'postalCode': salon.postalCode,
    'bookingLink': salon.bookingLink,
    'latitude': salon.latitude,
    'longitude': salon.longitude,
    'description': salon.description,
    'status': salon.status.name,
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
  };
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
    vacationAllowance: vacationAllowance,
    permissionAllowance: permissionAllowance,
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
    'vacationAllowance': staff.vacationAllowance,
    'permissionAllowance': staff.permissionAllowance,
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

  return Client(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    firstName: data['firstName'] as String? ?? '',
    lastName: data['lastName'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    clientNumber: data['clientNumber'] as String?,
    dateOfBirth:
        (dateOfBirthRaw is Timestamp)
            ? dateOfBirthRaw.toDate()
            : (dateOfBirthRaw is DateTime ? dateOfBirthRaw : null),
    address: data['address'] as String?,
    profession: data['profession'] as String?,
    referralSource: data['referralSource'] as String?,
    email: data['email'] as String?,
    notes: data['notes'] as String?,
    loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
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
  );
}

Map<String, dynamic> clientToMap(Client client) {
  final map = <String, dynamic>{
    'salonId': client.salonId,
    'firstName': client.firstName,
    'lastName': client.lastName,
    'phone': client.phone,
    'clientNumber': client.clientNumber,
    'dateOfBirth':
        client.dateOfBirth == null
            ? null
            : Timestamp.fromDate(client.dateOfBirth!),
    'address': client.address,
    'profession': client.profession,
    'referralSource': client.referralSource,
    'email': client.email,
    'notes': client.notes,
    'loyaltyPoints': client.loyaltyPoints,
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
  return ServiceCategory(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    name: data['name'] as String? ?? '',
    description: data['description'] as String?,
    sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
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
  return Appointment(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    clientId: data['clientId'] as String? ?? '',
    staffId: data['staffId'] as String? ?? '',
    serviceId: data['serviceId'] as String? ?? '',
    serviceIds:
        (data['serviceIds'] as List<dynamic>?)
            ?.whereType<String>()
            .toList(),
    start: ((data['start'] as Timestamp?) ?? Timestamp.now()).toDate(),
    end: ((data['end'] as Timestamp?) ?? Timestamp.now()).toDate(),
    status: _stringToAppointmentStatus(data['status'] as String?),
    notes: data['notes'] as String?,
    packageId: data['packageId'] as String?,
    roomId: data['roomId'] as String?,
  );
}

Map<String, dynamic> appointmentToMap(Appointment appointment) {
  return {
    'salonId': appointment.salonId,
    'clientId': appointment.clientId,
    'staffId': appointment.staffId,
    'serviceId': appointment.serviceId,
    'serviceIds': appointment.serviceIds,
    'start': Timestamp.fromDate(appointment.start),
    'end': Timestamp.fromDate(appointment.end),
    'status': appointment.status.name,
    'notes': appointment.notes,
    'packageId': appointment.packageId,
    'roomId': appointment.roomId,
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
  final paidAmount =
      paidAmountRaw ?? (paymentStatus == SalePaymentStatus.deposit ? 0 : total);
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
  );
}

Map<String, dynamic> saleToMap(Sale sale) {
  return {
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
}

Map<String, int> _mapToIntMap(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) {
    return const {};
  }
  return raw.map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0))
    ..removeWhere((key, value) => value <= 0);
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

ReminderSettings reminderSettingsFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? <String, dynamic>{};
  return ReminderSettings(
    salonId: data['salonId'] as String? ?? doc.id,
    dayBeforeEnabled: data['dayBeforeEnabled'] as bool? ?? true,
    threeHoursEnabled: data['threeHoursEnabled'] as bool? ?? true,
    oneHourEnabled: data['oneHourEnabled'] as bool? ?? true,
    birthdayEnabled: data['birthdayEnabled'] as bool? ?? true,
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    updatedBy: data['updatedBy'] as String?,
  );
}

Map<String, dynamic> reminderSettingsToMap(ReminderSettings settings) {
  return {
    'salonId': settings.salonId,
    'dayBeforeEnabled': settings.dayBeforeEnabled,
    'threeHoursEnabled': settings.threeHoursEnabled,
    'oneHourEnabled': settings.oneHourEnabled,
    'birthdayEnabled': settings.birthdayEnabled,
    if (settings.updatedAt != null)
      'updatedAt': Timestamp.fromDate(settings.updatedAt!),
    'updatedBy': settings.updatedBy,
  };
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
  );
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

  return Shift(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    staffId: data['staffId'] as String? ?? '',
    start: ((data['start'] as Timestamp?) ?? Timestamp.now()).toDate(),
    end: ((data['end'] as Timestamp?) ?? Timestamp.now()).toDate(),
    roomId: data['roomId'] as String? ?? '',
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

MessageChannel _stringToMessageChannel(String? value) {
  return MessageChannel.values.firstWhere(
    (channel) => channel.name == value,
    orElse: () => MessageChannel.whatsapp,
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
