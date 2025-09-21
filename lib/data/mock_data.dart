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

class MockData {
  MockData._();

  static DateTime get _now => DateTime.now();

  static List<SalonDailySchedule> get _defaultWeeklySchedule {
    const openingMinute = 9 * 60;
    const closingMinute = 19 * 60;
    return List<SalonDailySchedule>.generate(7, (index) {
      final weekday = DateTime.monday + index;
      final isSunday = weekday == DateTime.sunday;
      return SalonDailySchedule(
        weekday: weekday,
        isOpen: !isSunday,
        openMinuteOfDay: isSunday ? null : openingMinute,
        closeMinuteOfDay: isSunday ? null : closingMinute,
      );
    });
  }

  static final salons = <Salon>[
    Salon(
      id: 'salon-001',
      name: 'Civi Beauty - Centro Milano',
      address: 'Via Dante 12',
      city: 'Milano',
      phone: '+39 02 1234 5678',
      email: 'milano@civibeauty.it',
      description: 'Flagship store con focus su trattamenti viso e benessere.',
      rooms: const [
        SalonRoom(
          id: 'room-1',
          name: 'Cabina Relax',
          capacity: 1,
          services: ['srv-massage'],
        ),
        SalonRoom(
          id: 'room-2',
          name: 'Sala Estetica',
          capacity: 2,
          services: ['srv-skincare', 'srv-manicure'],
        ),
      ],
      schedule: _defaultWeeklySchedule,
    ),
    Salon(
      id: 'salon-002',
      name: 'Civi Beauty - Centro Roma',
      address: 'Via del Corso 89',
      city: 'Roma',
      phone: '+39 06 9876 5432',
      email: 'roma@civibeauty.it',
      rooms: const [
        SalonRoom(
          id: 'room-3',
          name: 'Cabina Benessere',
          capacity: 1,
          services: ['srv-massage', 'srv-spa'],
        ),
      ],
      schedule: _defaultWeeklySchedule,
    ),
  ];

  static final staffMembers = <StaffMember>[
    StaffMember(
      id: 'staff-001',
      salonId: 'salon-001',
      fullName: 'Laura Conti',
      role: StaffRole.manager,
      phone: '+39 320 111 2233',
      email: 'laura.conti@civibeauty.it',
      skills: const ['Coordinamento', 'Analisi vendite'],
    ),
    StaffMember(
      id: 'staff-002',
      salonId: 'salon-001',
      fullName: 'Giulia Serra',
      role: StaffRole.estetista,
      phone: '+39 333 444 5566',
      skills: const ['Trattamenti viso', 'Massaggi decontratturanti'],
    ),
    StaffMember(
      id: 'staff-003',
      salonId: 'salon-002',
      fullName: 'Marco Bianchi',
      role: StaffRole.massaggiatore,
      phone: '+39 340 777 8899',
      skills: const ['Massaggi sportivi', 'Linfodrenaggio'],
    ),
  ];

  static final clients = <Client>[
    Client(
      id: 'client-001',
      salonId: 'salon-001',
      firstName: 'Sara',
      lastName: 'Verdi',
      phone: '+39 351 000 1122',
      clientNumber: '202309010900',
      dateOfBirth: DateTime(1990, 5, 17),
      address: 'Via Roma 10, Milano',
      profession: 'Impiegata',
      referralSource: 'Instagram',
      email: 'sara.verdi@example.com',
      loyaltyPoints: 120,
      marketedConsents: [
        ClientConsent(
          type: ConsentType.privacy,
          acceptedAt: _now.subtract(const Duration(days: 200)),
        ),
        ClientConsent(
          type: ConsentType.marketing,
          acceptedAt: _now.subtract(const Duration(days: 180)),
        ),
      ],
      onboardingStatus: ClientOnboardingStatus.onboardingCompleted,
      invitationSentAt: _now.subtract(const Duration(days: 210)),
      firstLoginAt: _now.subtract(const Duration(days: 205)),
      onboardingCompletedAt: _now.subtract(const Duration(days: 200)),
    ),
    Client(
      id: 'client-002',
      salonId: 'salon-001',
      firstName: 'Alessia',
      lastName: 'Russo',
      phone: '+39 328 123 7788',
      clientNumber: '202311150845',
      dateOfBirth: DateTime(1988, 11, 3),
      address: 'Piazza Garibaldi 5, Milano',
      profession: 'Graphic Designer',
      referralSource: 'Passaparola',
      loyaltyPoints: 45,
      marketedConsents: [
        ClientConsent(
          type: ConsentType.privacy,
          acceptedAt: _now.subtract(const Duration(days: 90)),
        ),
      ],
      onboardingStatus: ClientOnboardingStatus.invitationSent,
      invitationSentAt: _now.subtract(const Duration(days: 2)),
      firstLoginAt: null,
    ),
    Client(
      id: 'client-003',
      salonId: 'salon-002',
      firstName: 'Daniele',
      lastName: 'Moretti',
      phone: '+39 329 555 6677',
      clientNumber: '202402101130',
      dateOfBirth: DateTime(1995, 2, 10),
      address: 'Via Dante 22, Torino',
      profession: 'Personal Trainer',
      referralSource: 'Google Ads',
      email: 'daniele.moretti@example.com',
      loyaltyPoints: 10,
      marketedConsents: [
        ClientConsent(
          type: ConsentType.privacy,
          acceptedAt: _now.subtract(const Duration(days: 40)),
        ),
      ],
    ),
  ];

  static final services = <Service>[
    Service(
      id: 'srv-skincare',
      salonId: 'salon-001',
      name: 'Trattamento Viso Rigenerante',
      category: 'Skincare',
      duration: const Duration(minutes: 60),
      price: 75,
      description:
          'Pulizia profonda, maschera e massaggio viso personalizzato.',
      staffRoles: const ['estetista'],
    ),
    Service(
      id: 'srv-massage',
      salonId: 'salon-001',
      name: 'Massaggio Decontratturante',
      category: 'Massaggi',
      duration: const Duration(minutes: 50),
      price: 65,
      description:
          'Massaggio mirato per alleviare tensioni muscolari e stress.',
      staffRoles: const ['massaggiatore', 'estetista'],
    ),
    Service(
      id: 'srv-manicure',
      salonId: 'salon-001',
      name: 'Manicure Deluxe',
      category: 'Unghie',
      duration: const Duration(minutes: 45),
      price: 40,
      description:
          'Trattamento completo con maschera idratante e smalto semipermanente.',
      staffRoles: const ['nailArtist'],
    ),
    Service(
      id: 'srv-spa',
      salonId: 'salon-002',
      name: 'Percorso Spa Relax',
      category: 'Benessere',
      duration: const Duration(minutes: 90),
      price: 95,
      description:
          'Percorso spa completo con sauna, bagno turco e massaggio aromatico.',
      staffRoles: const ['massaggiatore'],
    ),
  ];

  static final packages = <ServicePackage>[
    ServicePackage(
      id: 'pkg-beauty-01',
      salonId: 'salon-001',
      name: 'Pacchetto Bellezza Completa',
      price: 190,
      fullPrice: 190,
      discountPercentage: null,
      description: '3 sessioni viso + 2 massaggi + manicure deluxe',
      serviceIds: const ['srv-skincare', 'srv-massage', 'srv-manicure'],
      sessionCount: 5,
      validDays: 180,
      serviceSessionCounts: const {'srv-skincare': 3, 'srv-massage': 2},
    ),
    ServicePackage(
      id: 'pkg-relax-01',
      salonId: 'salon-002',
      name: 'Percorso Relax Trimestrale',
      price: 240,
      fullPrice: 240,
      discountPercentage: null,
      description: '4 massaggi e 2 percorsi spa in tre mesi',
      serviceIds: const ['srv-massage', 'srv-spa'],
      sessionCount: 6,
      validDays: 120,
      serviceSessionCounts: const {'srv-massage': 4, 'srv-spa': 2},
    ),
  ];

  static final appointments = <Appointment>[
    Appointment(
      id: 'app-001',
      salonId: 'salon-001',
      clientId: 'client-001',
      staffId: 'staff-002',
      serviceId: 'srv-skincare',
      start: _now.add(const Duration(hours: 4)),
      end: _now.add(const Duration(hours: 5)),
      notes: 'Preferisce prodotti alla vitamina C',
      roomId: 'room-2',
    ),
    Appointment(
      id: 'app-002',
      salonId: 'salon-001',
      clientId: 'client-002',
      staffId: 'staff-002',
      serviceId: 'srv-massage',
      start: _now.add(const Duration(days: 1, hours: 2)),
      end: _now.add(const Duration(days: 1, hours: 3)),
      status: AppointmentStatus.confirmed,
      roomId: 'room-1',
    ),
    Appointment(
      id: 'app-003',
      salonId: 'salon-002',
      clientId: 'client-003',
      staffId: 'staff-003',
      serviceId: 'srv-spa',
      start: _now.add(const Duration(days: 2, hours: 3)),
      end: _now.add(const Duration(days: 2, hours: 4, minutes: 30)),
      status: AppointmentStatus.scheduled,
      roomId: 'room-3',
    ),
  ];

  static final inventoryItems = <InventoryItem>[
    InventoryItem(
      id: 'inv-001',
      salonId: 'salon-001',
      name: 'Crema Idratante Premium',
      category: 'Skincare',
      quantity: 24,
      unit: 'pz',
      threshold: 10,
      cost: 18,
      sellingPrice: 39,
      updatedAt: _now.subtract(const Duration(days: 2)),
    ),
    InventoryItem(
      id: 'inv-002',
      salonId: 'salon-001',
      name: 'Olio Massaggio Relax',
      category: 'Massaggi',
      quantity: 8,
      unit: 'bottiglie',
      threshold: 5,
      cost: 12,
      sellingPrice: 29,
      updatedAt: _now.subtract(const Duration(days: 3)),
    ),
    InventoryItem(
      id: 'inv-003',
      salonId: 'salon-002',
      name: 'Kit Spa Aromaterapia',
      category: 'Spa',
      quantity: 6,
      unit: 'kit',
      threshold: 3,
      cost: 25,
      sellingPrice: 55,
      updatedAt: _now.subtract(const Duration(days: 1)),
    ),
  ];

  static final sales = <Sale>[
    Sale(
      id: 'sale-001',
      salonId: 'salon-001',
      clientId: 'client-001',
      items: [
        SaleItem(
          referenceId: 'srv-skincare',
          referenceType: SaleReferenceType.service,
          description: 'Trattamento Viso Rigenerante',
          quantity: 1,
          unitPrice: 75,
        ),
        SaleItem(
          referenceId: 'inv-001',
          referenceType: SaleReferenceType.product,
          description: 'Crema Idratante Premium',
          quantity: 1,
          unitPrice: 39,
        ),
      ],
      total: 114,
      createdAt: _now.subtract(const Duration(days: 1, hours: 3)),
      paymentMethod: PaymentMethod.pos,
      invoiceNumber: '2024-000145',
    ),
    Sale(
      id: 'sale-002',
      salonId: 'salon-002',
      clientId: 'client-003',
      items: [
        SaleItem(
          referenceId: 'pkg-relax-01',
          referenceType: SaleReferenceType.package,
          description: 'Percorso Relax Trimestrale',
          quantity: 1,
          unitPrice: 240,
        ),
      ],
      total: 240,
      createdAt: _now.subtract(const Duration(days: 4)),
      paymentMethod: PaymentMethod.transfer,
      invoiceNumber: '2024-000122',
    ),
  ];

  static final cashFlowEntries = <CashFlowEntry>[
    CashFlowEntry(
      id: 'cash-001',
      salonId: 'salon-001',
      type: CashFlowType.income,
      amount: 250,
      date: _now.subtract(const Duration(days: 1)),
      description: 'Vendita pacchetto promo primavera',
      category: 'Vendite',
      staffId: 'staff-001',
    ),
    CashFlowEntry(
      id: 'cash-002',
      salonId: 'salon-001',
      type: CashFlowType.expense,
      amount: 85,
      date: _now.subtract(const Duration(days: 2)),
      description: 'Rifornimento oli massaggi',
      category: 'Magazzino',
      staffId: 'staff-001',
    ),
  ];

  static final messageTemplates = <MessageTemplate>[
    MessageTemplate(
      id: 'msg-001',
      salonId: 'salon-001',
      title: 'Promemoria Appuntamento',
      body:
          'Ciao {{cliente}}, ti ricordiamo l\'appuntamento il {{data}} alle {{ora}} presso {{salone}}. A presto!',
      channel: MessageChannel.whatsapp,
      usage: TemplateUsage.reminder,
    ),
    MessageTemplate(
      id: 'msg-002',
      salonId: 'salon-001',
      title: 'Promo Weekend',
      body:
          'Solo questo weekend trattamenti viso al 20% di sconto! Prenota ora via app o WhatsApp.',
      channel: MessageChannel.whatsapp,
      usage: TemplateUsage.promotion,
    ),
  ];

  static final shifts = <Shift>[
    Shift(
      id: 'shift-001',
      salonId: 'salon-001',
      staffId: 'staff-002',
      start: _now.add(const Duration(hours: 1)),
      end: _now.add(const Duration(hours: 9)),
      roomId: 'room-2',
      notes: 'Disponibile per trattamenti viso',
      breakStart: _now.add(const Duration(hours: 5)),
      breakEnd: _now.add(const Duration(hours: 6)),
    ),
    Shift(
      id: 'shift-002',
      salonId: 'salon-002',
      staffId: 'staff-003',
      start: _now.add(const Duration(days: 1, hours: 2)),
      end: _now.add(const Duration(days: 1, hours: 10)),
      roomId: 'room-3',
      recurrence: ShiftRecurrence(
        frequency: ShiftRecurrenceFrequency.weekly,
        interval: 2,
        until: _now.add(const Duration(days: 30)),
        weekdays: const [DateTime.tuesday, DateTime.thursday],
        activeWeeks: 1,
        inactiveWeeks: 1,
      ),
      seriesId: 'series-morning-roma',
    ),
  ];

  static final staffAbsences = <StaffAbsence>[
    StaffAbsence(
      id: 'absence-001',
      salonId: 'salon-001',
      staffId: 'staff-002',
      type: StaffAbsenceType.vacation,
      start: DateTime(_now.year, _now.month, _now.day + 10),
      end: DateTime(_now.year, _now.month, _now.day + 12, 23, 59),
      notes: 'Week-end lungo',
    ),
    StaffAbsence(
      id: 'absence-002',
      salonId: 'salon-002',
      staffId: 'staff-003',
      type: StaffAbsenceType.sickLeave,
      start: DateTime(_now.year, _now.month, _now.day + 3, 10, 0),
      end: DateTime(_now.year, _now.month, _now.day + 3, 14, 0),
      notes: 'Influenza stagionale',
    ),
  ];
}
