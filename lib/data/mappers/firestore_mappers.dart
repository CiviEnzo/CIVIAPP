import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

Salon salonFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  final roomsRaw = data['rooms'] as List<dynamic>? ?? const [];
  final scheduleRaw = data['schedule'] as List<dynamic>? ?? const [];
  return Salon(
    id: doc.id,
    name: data['name'] as String? ?? '',
    address: data['address'] as String? ?? '',
    city: data['city'] as String? ?? '',
    phone: data['phone'] as String? ?? '',
    email: data['email'] as String? ?? '',
    description: data['description'] as String?,
    rooms:
        roomsRaw
            .map(
              (room) => SalonRoom(
                id: (room as Map<String, dynamic>)['id'] as String? ?? '',
                name: room['name'] as String? ?? '',
                capacity: ((room['capacity'] as num?) ?? 0).toInt(),
                services:
                    (room['services'] as List<dynamic>? ?? const [])
                        .map((service) => service.toString())
                        .toList(),
              ),
            )
            .toList(),
    schedule:
        scheduleRaw
            .map(
              (entry) => SalonDailySchedule(
                weekday:
                    (entry as Map<String, dynamic>)['weekday'] as int? ??
                    DateTime.monday,
                isOpen: entry['isOpen'] as bool? ?? false,
                openMinuteOfDay: (entry['openMinuteOfDay'] as num?)?.toInt(),
                closeMinuteOfDay: (entry['closeMinuteOfDay'] as num?)?.toInt(),
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
    'description': salon.description,
    'rooms':
        salon.rooms
            .map(
              (room) => {
                'id': room.id,
                'name': room.name,
                'capacity': room.capacity,
                'services': room.services,
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

StaffMember staffFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? <String, dynamic>{};
  return StaffMember(
    id: doc.id,
    salonId: data['salonId'] as String? ?? '',
    fullName: data['fullName'] as String? ?? '',
    role: _stringToStaffRole(data['role'] as String?),
    phone: data['phone'] as String?,
    email: data['email'] as String?,
    skills:
        (data['skills'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
    isActive: data['isActive'] as bool? ?? true,
  );
}

Map<String, dynamic> staffToMap(StaffMember staff) {
  return {
    'salonId': staff.salonId,
    'fullName': staff.fullName,
    'role': staff.role.name,
    'phone': staff.phone,
    'email': staff.email,
    'skills': staff.skills,
    'isActive': staff.isActive,
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
    'consents':
        client.marketedConsents
            .map(
              (consent) => {
                'type': consent.type.name,
                'acceptedAt': Timestamp.fromDate(consent.acceptedAt),
              },
            )
            .toList(),
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
    duration: Duration(
      minutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
    ),
    price: (data['price'] as num?)?.toDouble() ?? 0,
    description: data['description'] as String?,
    staffRoles:
        (data['staffRoles'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
  );
}

Map<String, dynamic> serviceToMap(Service service) {
  return {
    'salonId': service.salonId,
    'name': service.name,
    'category': service.category,
    'durationMinutes': service.duration.inMinutes,
    'price': service.price,
    'description': service.description,
    'staffRoles': service.staffRoles,
  };
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
  final salePaymentMethod =
      _stringToPaymentMethod(data['paymentMethod'] as String?);
  final itemsRaw = data['items'] as List<dynamic>? ?? const [];
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
                final method = methodValue == null
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
    total: (data['total'] as num?)?.toDouble() ?? 0,
    createdAt: createdAt,
    paymentMethod: salePaymentMethod,
    invoiceNumber: data['invoiceNumber'] as String?,
    notes: data['notes'] as String?,
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
    'invoiceNumber': sale.invoiceNumber,
    'notes': sale.notes,
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

StaffRole _stringToStaffRole(String? value) {
  return StaffRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => StaffRole.estetista,
  );
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
