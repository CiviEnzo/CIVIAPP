import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_day_checklist.dart';
import 'package:you_book/domain/entities/cash_flow_entry.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_questionnaire.dart';
import 'package:you_book/domain/entities/client_photo.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/quote.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/domain/entities/reminder_settings.dart';

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
      postalCode: '20121',
      bookingLink: 'https://civibeauty.it/milano',
      latitude: 45.4674,
      longitude: 9.1895,
      description: 'Flagship store con focus su trattamenti viso e benessere.',
      status: SalonStatus.active,
      rooms: const [
        SalonRoom(
          id: 'room-1',
          name: 'Cabina Relax',
          capacity: 1,
          category: 'Massaggi',
          services: ['srv-massage'],
        ),
        SalonRoom(
          id: 'room-2',
          name: 'Sala Estetica',
          capacity: 2,
          category: 'Estetica',
          services: ['srv-skincare', 'srv-manicure'],
        ),
      ],
      equipment: const [
        SalonEquipment(
          id: 'eq-pressoterapia',
          name: 'Pressoterapia',
          quantity: 2,
          status: SalonEquipmentStatus.operational,
        ),
        SalonEquipment(
          id: 'eq-laser',
          name: 'Laser diodo 808',
          quantity: 1,
          status: SalonEquipmentStatus.maintenance,
          notes: 'Manutenzione programmata il prossimo lunedì.',
        ),
        SalonEquipment(
          id: 'eq-manipolo',
          name: 'Manipolo radiofrequenza',
          quantity: 3,
        ),
      ],
      closures: [
        SalonClosure(
          id: 'closure-milano-01',
          start: DateTime(_now.year, _now.month, _now.day + 20),
          end: DateTime(_now.year, _now.month, _now.day + 21),
          reason: 'Formazione staff su nuovi macchinari',
        ),
      ],
      schedule: _defaultWeeklySchedule,
      featureFlags: const SalonFeatureFlags(
        clientPromotions: true,
        clientLastMinute: true,
      ),
      stripeAccountId: 'acct_mock_salon001',
      stripeAccount: const StripeAccountSnapshot(
        chargesEnabled: true,
        payoutsEnabled: true,
        detailsSubmitted: true,
      ),
    ),
    Salon(
      id: 'salon-002',
      name: 'Civi Beauty - Centro Roma',
      address: 'Via del Corso 89',
      city: 'Roma',
      phone: '+39 06 9876 5432',
      email: 'roma@civibeauty.it',
      postalCode: '00186',
      bookingLink: 'https://civibeauty.it/roma',
      latitude: 41.9009,
      longitude: 12.4795,
      status: SalonStatus.active,
      rooms: const [
        SalonRoom(
          id: 'room-3',
          name: 'Cabina Benessere',
          capacity: 1,
          category: 'SPA',
          services: ['srv-massage', 'srv-spa'],
        ),
      ],
      equipment: const [
        SalonEquipment(id: 'eq-sauna', name: 'Sauna Finlandese', quantity: 1),
        SalonEquipment(
          id: 'eq-vasca-idro',
          name: 'Vasca idromassaggio',
          quantity: 1,
        ),
        SalonEquipment(
          id: 'eq-laser-compact',
          name: 'Laser compatto per epilazione',
          quantity: 1,
          status: SalonEquipmentStatus.outOfOrder,
          notes: 'In attesa di pezzo di ricambio.',
        ),
      ],
      closures: const [],
      schedule: _defaultWeeklySchedule,
      featureFlags: const SalonFeatureFlags(
        clientPromotions: false,
        clientLastMinute: true,
      ),
      stripeAccountId: 'acct_mock_salon002',
      stripeAccount: const StripeAccountSnapshot(
        chargesEnabled: true,
        payoutsEnabled: true,
        detailsSubmitted: true,
      ),
    ),
  ];

  static final appointmentDayChecklists = <AppointmentDayChecklist>[
    AppointmentDayChecklist(
      id: 'chk-1',
      salonId: 'salon-001',
      date: DateTime(_now.year, _now.month, _now.day),
      createdAt: _now.subtract(const Duration(days: 1)),
      updatedAt: _now.subtract(const Duration(hours: 6)),
      items: const [
        AppointmentChecklistItem(
          id: 'chk-1-itm-1',
          label: 'Prepara cabina relax',
          position: 0,
          isCompleted: true,
        ),
        AppointmentChecklistItem(
          id: 'chk-1-itm-2',
          label: 'Verifica disponibilità prodotti viso',
          position: 1,
        ),
        AppointmentChecklistItem(
          id: 'chk-1-itm-3',
          label: 'Aggiorna promo express in vetrina',
          position: 2,
        ),
      ],
    ),
    AppointmentDayChecklist(
      id: 'chk-2',
      salonId: 'salon-001',
      date: DateTime(_now.year, _now.month, _now.day + 1),
      createdAt: _now,
      updatedAt: _now,
      items: const [
        AppointmentChecklistItem(
          id: 'chk-2-itm-1',
          label: 'Controlla macchinari pressoterapia',
          position: 0,
        ),
      ],
    ),
  ];

  static final promotions = <Promotion>[
    Promotion(
      id: 'promo-welcome-spring',
      salonId: 'salon-001',
      title: 'Spring Glow Facial',
      subtitle: 'Illumina la tua pelle in 30 minuti',
      tagline: 'Risparmia il 25% se prenoti entro oggi',
      discountPercentage: 25,
      imageUrl: 'https://example.com/assets/promotions/spring-glow.jpg',
      ctaUrl: 'https://civibeauty.it/milano/offerte',
      cta: const PromotionCta(
        type: PromotionCtaType.link,
        label: 'Scopri l\'offerta',
        url: 'https://civibeauty.it/milano/offerte',
      ),
      startsAt: DateTime(_now.year, _now.month, _now.day - 3),
      endsAt: DateTime(_now.year, _now.month, _now.day + 7),
      priority: 10,
    ),
    Promotion(
      id: 'promo-wallet-boost',
      salonId: 'salon-002',
      title: 'Wallet Boost',
      subtitle: 'Ricarica 100€, ricevi 20€ in omaggio',
      discountPercentage: 20,
      imageUrl: 'https://example.com/assets/promotions/wallet-boost.jpg',
      ctaUrl: 'https://civibeauty.it/roma/wallet',
      cta: const PromotionCta(
        type: PromotionCtaType.link,
        label: 'Scopri l\'offerta',
        url: 'https://civibeauty.it/roma/wallet',
      ),
      startsAt: DateTime(_now.year, _now.month, _now.day - 1),
      endsAt: DateTime(_now.year, _now.month, _now.day + 14),
      priority: 5,
    ),
  ];

  static final lastMinuteSlots = <LastMinuteSlot>[
    LastMinuteSlot(
      id: 'lm-slot-001',
      salonId: 'salon-001',
      serviceId: 'srv-manicure',
      serviceName: 'Manicure express',
      start: _now.add(const Duration(minutes: 45)),
      duration: const Duration(minutes: 30),
      basePrice: 39,
      discountPercentage: 25,
      priceNow: 29.25,
      roomId: 'room-2',
      roomName: 'Sala Estetica',
      operatorId: 'staff-giulia',
      operatorName: 'Giulia',
      availableSeats: 1,
      loyaltyPoints: 15,
      windowStart: _now,
      windowEnd: _now.add(const Duration(minutes: 60)),
    ),
    LastMinuteSlot(
      id: 'lm-slot-002',
      salonId: 'salon-001',
      serviceId: 'srv-vacufit',
      serviceName: "VacuFIT 45'",
      start: _now.add(const Duration(minutes: 90)),
      duration: const Duration(minutes: 45),
      basePrice: 49,
      discountPercentage: 20,
      priceNow: 39.2,
      roomId: 'room-1',
      roomName: 'Cabina Relax',
      operatorId: 'staff-luca',
      operatorName: 'Luca',
      availableSeats: 1,
      loyaltyPoints: 25,
      windowStart: _now.add(const Duration(minutes: 30)),
      windowEnd: _now.add(const Duration(minutes: 120)),
    ),
  ];

  static List<ClientQuestionGroup> _anamnesisQuestionGroups() {
    return <ClientQuestionGroup>[
      ClientQuestionGroup(
        id: 'grp-cardiovascular',
        title: 'Condizioni cardiovascolari',
        sortOrder: 10,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-cardiac-disease',
            label: 'Patologie cardiache (infarto, aritmie, insufficienza)?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-blood-pressure',
            label: 'Pressione alta o bassa?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-pacemaker',
            label: 'Portatore di pacemaker o defibrillatore?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-heart-meds',
            label:
                'Assunzione di farmaci cardiaci (anticoagulanti, beta-bloccanti)?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-pregnancy',
        title: 'Gravidanza e allattamento',
        sortOrder: 20,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-pregnant',
            label: 'Attualmente incinta?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-breastfeeding',
            label: 'Sta allattando?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-general-pathologies',
        title: 'Patologie generali',
        sortOrder: 30,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-diabetes',
            label: 'Diabete diagnosticato?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-diabetes-meds',
            label: 'Assunzione di farmaci per il diabete?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-insulin-resistance',
            label: 'Insulino-resistenza confermata?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-kidney-liver',
            label: 'Problemi renali o epatici?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-autoimmune',
            label: 'Patologie autoimmuni o croniche?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-general-notes',
            label: 'Dettagli o note aggiuntive',
            type: ClientQuestionType.textarea,
            helperText: 'Specificare eventuali terapie in corso.',
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-hormonal',
        title: 'Storia ormonale',
        sortOrder: 40,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-menstrual-irregularities',
            label: 'Irregolarita mestruali?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-menopause',
            label: 'Menopausa in corso?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-pcos',
            label: 'Problemi di ovaio policistico o simili?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-thyroid',
            label: 'Patologie tiroidee o endocrine?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-weight-history',
            label:
                'Storia di sovrappeso, obesita o difficolta nel controllo del peso?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-allergies',
        title: 'Allergie e reazioni',
        sortOrder: 50,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-allergies',
            label: 'Allergie note a farmaci, cosmetici o lattice?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-adverse-reactions',
            label: 'Reazioni avverse a trattamenti estetici o farmaci?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-skin',
        title: 'Disturbi della pelle',
        sortOrder: 60,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-skin-disorders',
            label: 'Dermatiti, eczema, psoriasi o ferite aperte?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-topical-therapies',
            label: 'Terapie topiche o sistemiche in corso?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-surgery',
        title: 'Chirurgia e trattamenti recenti',
        sortOrder: 70,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-surgery-last12',
            label: 'Interventi chirurgici negli ultimi 12 mesi?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-recent-aesthetic',
            label:
                'Trattamenti estetici recenti (laser, filler, peeling, botox)?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-activity',
        title: 'Attivita fisica',
        sortOrder: 80,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-activity-regular',
            label: 'Pratica attivita fisica regolare?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-activity-type',
            label: 'Tipo di attivita praticata',
            type: ClientQuestionType.text,
          ),
          ClientQuestionDefinition(
            id: 'q-activity-frequency',
            label: 'Frequenza settimanale e durata',
            type: ClientQuestionType.text,
          ),
          ClientQuestionDefinition(
            id: 'q-sedentary',
            label: 'Stile di vita sedentario?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-nutrition',
        title: 'Alimentazione',
        sortOrder: 90,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-special-diet',
            label: 'Segue una dieta particolare o nutrizionista?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-dietary-restrictions',
            label: 'Restrizioni o intolleranze alimentari?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-fruit-veg-portions',
            label: 'Porzioni di frutta o verdura al giorno',
            type: ClientQuestionType.number,
            helperText: 'Inserire un valore medio giornaliero.',
          ),
          ClientQuestionDefinition(
            id: 'q-sugar-fat',
            label: 'Consumo frequente di zuccheri o grassi?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-hydration',
        title: 'Idratazione',
        sortOrder: 100,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-water-intake',
            label: 'Quanta acqua beve mediamente al giorno?',
            type: ClientQuestionType.singleChoice,
            options: <ClientQuestionOption>[
              ClientQuestionOption(id: 'lt_less_1', label: 'Meno di 1 litro'),
              ClientQuestionOption(id: 'lt_1_2', label: 'Tra 1 e 2 litri'),
              ClientQuestionOption(id: 'lt_over_2', label: 'Oltre 2 litri'),
            ],
          ),
          ClientQuestionDefinition(
            id: 'q-sugary-drinks',
            label: 'Consumo di bevande zuccherate o alcoliche?',
            type: ClientQuestionType.boolean,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-sleep-stress',
        title: 'Sonno e stress',
        sortOrder: 110,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-sleep-hours',
            label: 'Ore di sonno medie per notte',
            type: ClientQuestionType.number,
          ),
          ClientQuestionDefinition(
            id: 'q-insomnia',
            label: 'Problemi di insonnia?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-stress-level',
            label: 'Livello di stress percepito',
            type: ClientQuestionType.singleChoice,
            options: <ClientQuestionOption>[
              ClientQuestionOption(id: 'low', label: 'Basso'),
              ClientQuestionOption(id: 'medium', label: 'Medio'),
              ClientQuestionOption(id: 'high', label: 'Alto'),
            ],
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-skin-care',
        title: 'Cura della pelle',
        sortOrder: 120,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-uses-cosmetics',
            label: 'Utilizza creme o cosmetici?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-cosmetic-source',
            label: 'Dove acquista abitualmente i prodotti?',
            type: ClientQuestionType.singleChoice,
            options: <ClientQuestionOption>[
              ClientQuestionOption(id: 'pharmacy', label: 'Farmacia'),
              ClientQuestionOption(id: 'supermarket', label: 'Supermercato'),
              ClientQuestionOption(
                id: 'beauty_center',
                label: 'Centro estetico',
              ),
              ClientQuestionOption(id: 'other', label: 'Altro'),
            ],
          ),
          ClientQuestionDefinition(
            id: 'q-products-used',
            label: 'Prodotti utilizzati regolarmente',
            type: ClientQuestionType.textarea,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-hair-removal',
        title: 'Depilazione',
        sortOrder: 130,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-hair-removal-method',
            label: 'Metodo di depilazione utilizzato',
            type: ClientQuestionType.singleChoice,
            options: <ClientQuestionOption>[
              ClientQuestionOption(id: 'wax', label: 'Ceretta'),
              ClientQuestionOption(id: 'razor', label: 'Rasoio'),
              ClientQuestionOption(id: 'epilator', label: 'Epilatore'),
              ClientQuestionOption(id: 'laser', label: 'Laser'),
              ClientQuestionOption(id: 'other', label: 'Altro'),
            ],
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-previous-treatments',
        title: 'Trattamenti estetici precedenti',
        sortOrder: 140,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-previous-treatments',
            label: 'Ha effettuato trattamenti viso o corpo precedenti?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-previous-treatments-notes',
            label: 'Specificare trattamenti precedenti',
            type: ClientQuestionType.textarea,
            helperText: 'Inserire trattamenti, date e risultati.',
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-goals',
        title: 'Obiettivi personali',
        sortOrder: 150,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-treatment-goals',
            label: 'Obiettivi personali del trattamento',
            type: ClientQuestionType.textarea,
          ),
        ],
      ),
      ClientQuestionGroup(
        id: 'grp-consent',
        title: 'Consenso informato',
        sortOrder: 160,
        questions: <ClientQuestionDefinition>[
          ClientQuestionDefinition(
            id: 'q-consent-informed',
            label:
                'Il cliente dichiara di aver ricevuto tutte le informazioni sul trattamento?',
            type: ClientQuestionType.boolean,
          ),
          ClientQuestionDefinition(
            id: 'q-client-signature',
            label: 'Firma cliente',
            type: ClientQuestionType.text,
          ),
          ClientQuestionDefinition(
            id: 'q-consent-date',
            label: 'Data compilazione',
            type: ClientQuestionType.date,
          ),
        ],
      ),
    ];
  }

  static final staffRoles = <StaffRole>[
    const StaffRole(
      id: 'manager',
      name: 'Manager',
      isDefault: true,
      sortPriority: 10,
    ),
    const StaffRole(
      id: 'receptionist',
      name: 'Receptionist',
      isDefault: true,
      sortPriority: 20,
    ),
    const StaffRole(
      id: 'estetista',
      name: 'Estetista',
      isDefault: true,
      sortPriority: 30,
    ),
    const StaffRole(
      id: 'massaggiatore',
      name: 'Massaggiatore',
      isDefault: true,
      sortPriority: 40,
    ),
    const StaffRole(
      id: 'nail_artist',
      name: 'Nail Artist',
      isDefault: true,
      sortPriority: 50,
    ),
    const StaffRole(
      id: 'staff-role-unknown',
      name: 'Ruolo non assegnato',
      isDefault: true,
      sortPriority: 1000,
    ),
  ];

  static final staffMembers = <StaffMember>[
    StaffMember(
      id: 'staff-001',
      salonId: 'salon-001',
      firstName: 'Laura',
      lastName: 'Conti',
      roleIds: const ['manager'],
      phone: '+39 320 111 2233',
      email: 'laura.conti@civibeauty.it',
      dateOfBirth: DateTime(1990, 3, 14),
      vacationAllowance: 28,
      permissionAllowance: 15,
      sortOrder: 10,
      avatarUrl:
          'https://images.unsplash.com/photo-1589578527966-74ee9689173f?auto=format&fit=facearea&w=160&h=160&q=80',
    ),
    StaffMember(
      id: 'staff-002',
      salonId: 'salon-001',
      firstName: 'Giulia',
      lastName: 'Serra',
      roleIds: const ['estetista'],
      phone: '+39 333 444 5566',
      dateOfBirth: DateTime(1994, 8, 23),
      sortOrder: 20,
    ),
    StaffMember(
      id: 'staff-003',
      salonId: 'salon-002',
      firstName: 'Marco',
      lastName: 'Bianchi',
      roleIds: const ['massaggiatore'],
      phone: '+39 340 777 8899',
      dateOfBirth: DateTime(1988, 12, 2),
      sortOrder: 10,
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
      stripeCustomerId: 'cus_mock_001',
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
      channelPreferences: const ChannelPreferences(
        push: true,
        email: true,
        whatsapp: true,
        sms: false,
      ),
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
      stripeCustomerId: 'cus_mock_002',
      loyaltyPoints: 45,
      marketedConsents: [
        ClientConsent(
          type: ConsentType.privacy,
          acceptedAt: _now.subtract(const Duration(days: 90)),
        ),
      ],
      channelPreferences: const ChannelPreferences(
        push: true,
        email: true,
        whatsapp: false,
        sms: false,
      ),
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
      stripeCustomerId: 'cus_mock_003',
      loyaltyPoints: 10,
      marketedConsents: [
        ClientConsent(
          type: ConsentType.privacy,
          acceptedAt: _now.subtract(const Duration(days: 40)),
        ),
      ],
      channelPreferences: const ChannelPreferences(
        push: true,
        email: false,
        whatsapp: false,
        sms: true,
      ),
    ),
  ];

  static final clientPhotos = <ClientPhoto>[
    ClientPhoto(
      id: 'photo-sara-1',
      salonId: 'salon-001',
      clientId: 'client-001',
      storagePath:
          'salon_media/salon-001/clients/client-001/photos/photo-sara-1.jpg',
      downloadUrl:
          'https://storage.googleapis.com/civiapp-mock/photo-sara-1.jpg',
      uploadedAt: _now.subtract(const Duration(days: 30)),
      uploadedBy: 'staff-001',
      fileName: 'trattamento-viso-1.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 1800000,
      notes: 'Risultato dopo il terzo trattamento viso rigenerante.',
    ),
    ClientPhoto(
      id: 'photo-sara-2',
      salonId: 'salon-001',
      clientId: 'client-001',
      storagePath:
          'salon_media/salon-001/clients/client-001/photos/photo-sara-2.jpg',
      downloadUrl:
          'https://storage.googleapis.com/civiapp-mock/photo-sara-2.jpg',
      uploadedAt: _now.subtract(const Duration(days: 7)),
      uploadedBy: 'staff-002',
      fileName: 'prima-dopo-manicure.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 950000,
      notes: 'Prima e dopo il trattamento manicure deluxe.',
    ),
    ClientPhoto(
      id: 'photo-daniele-1',
      salonId: 'salon-002',
      clientId: 'client-003',
      storagePath:
          'salon_media/salon-002/clients/client-003/photos/photo-daniele-1.jpg',
      downloadUrl:
          'https://storage.googleapis.com/civiapp-mock/photo-daniele-1.jpg',
      uploadedAt: _now.subtract(const Duration(days: 12)),
      uploadedBy: 'staff-003',
      fileName: 'pressoterapia-sessione1.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 1320000,
      notes: 'Foto della prima sessione di pressoterapia.',
    ),
  ];

  static final clientQuestionnaireTemplates = <ClientQuestionnaireTemplate>[
    ClientQuestionnaireTemplate(
      id: 'tmpl-anamnesi-salon-001',
      salonId: 'salon-001',
      name: 'Anamnesi estetica base',
      description:
          'Questionario anamnestico standard per i clienti del centro di Milano.',
      createdAt: _now.subtract(const Duration(days: 120)),
      updatedAt: _now.subtract(const Duration(days: 7)),
      isDefault: true,
      groups: _anamnesisQuestionGroups(),
    ),
    ClientQuestionnaireTemplate(
      id: 'tmpl-anamnesi-salon-002',
      salonId: 'salon-002',
      name: 'Anamnesi estetica base',
      description:
          'Template condiviso per il centro di Roma, modificabile dallo staff.',
      createdAt: _now.subtract(const Duration(days: 90)),
      updatedAt: _now.subtract(const Duration(days: 14)),
      isDefault: true,
      groups: _anamnesisQuestionGroups(),
    ),
  ];

  static final clientQuestionnaires = <ClientQuestionnaire>[
    ClientQuestionnaire(
      id: 'cq-client-001',
      clientId: 'client-001',
      salonId: 'salon-001',
      templateId: 'tmpl-anamnesi-salon-001',
      createdAt: _now.subtract(const Duration(days: 60)),
      updatedAt: _now.subtract(const Duration(days: 12)),
      answers: [
        ClientQuestionAnswer(questionId: 'q-cardiac-disease', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-blood-pressure', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-pacemaker', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-heart-meds', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-pregnant', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-breastfeeding', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-diabetes', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-diabetes-meds', boolValue: false),
        ClientQuestionAnswer(
          questionId: 'q-insulin-resistance',
          boolValue: false,
        ),
        ClientQuestionAnswer(questionId: 'q-kidney-liver', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-autoimmune', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-general-notes', textValue: ''),
        ClientQuestionAnswer(
          questionId: 'q-menstrual-irregularities',
          boolValue: false,
        ),
        ClientQuestionAnswer(questionId: 'q-menopause', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-pcos', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-thyroid', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-weight-history', boolValue: true),
        ClientQuestionAnswer(questionId: 'q-allergies', boolValue: false),
        ClientQuestionAnswer(
          questionId: 'q-adverse-reactions',
          boolValue: false,
        ),
        ClientQuestionAnswer(questionId: 'q-skin-disorders', boolValue: false),
        ClientQuestionAnswer(
          questionId: 'q-topical-therapies',
          boolValue: false,
        ),
        ClientQuestionAnswer(questionId: 'q-surgery-last12', boolValue: false),
        ClientQuestionAnswer(
          questionId: 'q-recent-aesthetic',
          boolValue: false,
        ),
        ClientQuestionAnswer(questionId: 'q-activity-regular', boolValue: true),
        ClientQuestionAnswer(
          questionId: 'q-activity-type',
          textValue: 'Yoga e pilates',
        ),
        ClientQuestionAnswer(
          questionId: 'q-activity-frequency',
          textValue: '3 volte a settimana, 60 minuti',
        ),
        ClientQuestionAnswer(questionId: 'q-sedentary', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-special-diet', boolValue: false),
        ClientQuestionAnswer(
          questionId: 'q-dietary-restrictions',
          boolValue: false,
        ),
        ClientQuestionAnswer(
          questionId: 'q-fruit-veg-portions',
          numberValue: 4,
        ),
        ClientQuestionAnswer(questionId: 'q-sugar-fat', boolValue: false),
        ClientQuestionAnswer(
          questionId: 'q-water-intake',
          optionIds: ['lt_1_2'],
        ),
        ClientQuestionAnswer(questionId: 'q-sugary-drinks', boolValue: false),
        ClientQuestionAnswer(questionId: 'q-sleep-hours', numberValue: 7),
        ClientQuestionAnswer(questionId: 'q-insomnia', boolValue: false),
        ClientQuestionAnswer(
          questionId: 'q-stress-level',
          optionIds: ['medium'],
        ),
        ClientQuestionAnswer(questionId: 'q-uses-cosmetics', boolValue: true),
        ClientQuestionAnswer(
          questionId: 'q-cosmetic-source',
          optionIds: ['beauty_center'],
        ),
        ClientQuestionAnswer(
          questionId: 'q-products-used',
          textValue: 'Detergente specifico e crema idratante SPF 30.',
        ),
        ClientQuestionAnswer(
          questionId: 'q-hair-removal-method',
          optionIds: ['laser'],
        ),
        ClientQuestionAnswer(
          questionId: 'q-previous-treatments',
          boolValue: true,
        ),
        ClientQuestionAnswer(
          questionId: 'q-previous-treatments-notes',
          textValue: 'Peeling chimico leggero tre mesi fa.',
        ),
        ClientQuestionAnswer(
          questionId: 'q-treatment-goals',
          textValue:
              'Migliorare il tono del viso e mantenere risultati a lungo termine.',
        ),
        ClientQuestionAnswer(questionId: 'q-consent-informed', boolValue: true),
        ClientQuestionAnswer(
          questionId: 'q-client-signature',
          textValue: 'Sara Verdi',
        ),
        ClientQuestionAnswer(
          questionId: 'q-consent-date',
          dateValue: _now.subtract(const Duration(days: 45)),
        ),
      ],
    ),
  ];

  static final serviceCategories = <ServiceCategory>[
    ServiceCategory(
      id: 'cat-skincare',
      salonId: 'salon-001',
      name: 'Skincare',
      sortOrder: 10,
      color: 0xFF8F6BFF,
    ),
    ServiceCategory(
      id: 'cat-massaggi',
      salonId: 'salon-001',
      name: 'Massaggi',
      sortOrder: 20,
      color: 0xFF30A28A,
    ),
    ServiceCategory(
      id: 'cat-unghie',
      salonId: 'salon-001',
      name: 'Unghie',
      sortOrder: 30,
      color: 0xFFFF7B89,
    ),
    ServiceCategory(
      id: 'cat-benessere',
      salonId: 'salon-002',
      name: 'Benessere',
      sortOrder: 10,
      color: 0xFF4C9EE3,
    ),
  ];

  static final services = <Service>[
    Service(
      id: 'srv-skincare',
      salonId: 'salon-001',
      name: 'Trattamento Viso Rigenerante',
      category: 'Skincare',
      categoryId: 'cat-skincare',
      duration: const Duration(minutes: 60),
      extraDuration: const Duration(minutes: 10),
      price: 75,
      description:
          'Pulizia profonda, maschera e massaggio viso personalizzato.',
      staffRoles: const ['estetista'],
      requiredEquipmentIds: const ['eq-manipolo'],
    ),
    Service(
      id: 'srv-massage',
      salonId: 'salon-001',
      name: 'Massaggio Decontratturante',
      category: 'Massaggi',
      categoryId: 'cat-massaggi',
      duration: const Duration(minutes: 50),
      extraDuration: const Duration(minutes: 15),
      price: 65,
      description:
          'Massaggio mirato per alleviare tensioni muscolari e stress.',
      staffRoles: const ['massaggiatore', 'estetista'],
      requiredEquipmentIds: const ['eq-pressoterapia'],
    ),
    Service(
      id: 'srv-manicure',
      salonId: 'salon-001',
      name: 'Manicure Deluxe',
      category: 'Unghie',
      categoryId: 'cat-unghie',
      duration: const Duration(minutes: 45),
      extraDuration: const Duration(minutes: 5),
      price: 40,
      description:
          'Trattamento completo con maschera idratante e smalto semipermanente.',
      staffRoles: const ['nail_artist'],
      requiredEquipmentIds: const [],
    ),
    Service(
      id: 'srv-spa',
      salonId: 'salon-002',
      name: 'Percorso Spa Relax',
      category: 'Benessere',
      categoryId: 'cat-benessere',
      duration: const Duration(minutes: 90),
      extraDuration: const Duration(minutes: 20),
      price: 95,
      description:
          'Percorso spa completo con sauna, bagno turco e massaggio aromatico.',
      staffRoles: const ['massaggiatore'],
      requiredEquipmentIds: const ['eq-sauna', 'eq-vasca-idro'],
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
      status: AppointmentStatus.scheduled,
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
    Appointment(
      id: 'app-004',
      salonId: 'salon-001',
      clientId: 'client-001',
      staffId: 'staff-002',
      serviceId: 'srv-skincare',
      start: _now.subtract(const Duration(hours: 3)),
      end: _now.subtract(const Duration(hours: 2)),
      status: AppointmentStatus.completed,
      notes: 'Pagamento da registrare',
      roomId: 'room-2',
    ),
  ];

  static List<Appointment> get publicAppointments => appointments
      .map(
        (appointment) =>
            appointment.copyWith(clientId: '', notes: null, packageId: null),
      )
      .toList(growable: false);

  static final quotes = <Quote>[
    Quote(
      id: 'quote-001',
      salonId: 'salon-001',
      clientId: 'client-001',
      number: 'PR-${_now.year}-001',
      title: 'Pacchetto rimodellante 5 sessioni',
      notes: 'Offerta valida 30 giorni, pagamento anticipato del 30%.',
      status: QuoteStatus.sent,
      createdAt: _now.subtract(const Duration(days: 2)),
      updatedAt: _now.subtract(const Duration(days: 2)),
      sentAt: _now.subtract(const Duration(days: 2)),
      validUntil: _now.add(const Duration(days: 28)),
      sentChannels: const [MessageChannel.email],
      items: const [
        QuoteItem(
          id: 'quote-001-item-1',
          description: 'Pacchetto pressoterapia 5 sessioni',
          quantity: 1,
          unitPrice: 320,
          referenceType: QuoteItemReferenceType.service,
          serviceId: 'srv-massage',
        ),
        QuoteItem(
          id: 'quote-001-item-2',
          description: 'Crema corpo drenante home-care',
          quantity: 1,
          unitPrice: 39,
        ),
      ],
    ),
    Quote(
      id: 'quote-002',
      salonId: 'salon-002',
      clientId: 'client-003',
      number: 'PR-${_now.year}-002',
      title: 'Percorso relax completo',
      notes: 'Comprende massaggi e day spa.',
      status: QuoteStatus.accepted,
      createdAt: _now.subtract(const Duration(days: 7)),
      sentAt: _now.subtract(const Duration(days: 7)),
      acceptedAt: _now.subtract(const Duration(days: 5)),
      updatedAt: _now.subtract(const Duration(days: 5)),
      ticketId: 'quote-002-ticket',
      sentChannels: const [MessageChannel.email, MessageChannel.whatsapp],
      saleId: 'sale-002',
      stripePaymentIntentId: 'pi_mock_002',
      items: const [
        QuoteItem(
          id: 'quote-002-item-1',
          description: 'Percorso spa giornaliero',
          quantity: 2,
          unitPrice: 85,
          referenceType: QuoteItemReferenceType.manual,
        ),
        QuoteItem(
          id: 'quote-002-item-2',
          description: 'Massaggio decontratturante',
          quantity: 1,
          unitPrice: 40,
          referenceType: QuoteItemReferenceType.service,
          serviceId: 'srv-massage',
        ),
      ],
    ),
  ];

  static final paymentTickets = <PaymentTicket>[
    PaymentTicket(
      id: 'app-004',
      salonId: 'salon-001',
      appointmentId: 'app-004',
      clientId: 'client-001',
      serviceId: 'srv-skincare',
      staffId: 'staff-002',
      appointmentStart: _now.subtract(const Duration(hours: 3)),
      appointmentEnd: _now.subtract(const Duration(hours: 2)),
      createdAt: _now.subtract(const Duration(hours: 1, minutes: 45)),
      status: PaymentTicketStatus.open,
      expectedTotal: 75,
      serviceName: 'Trattamento Viso Rigenerante',
      notes: 'Pagamento da registrare',
    ),
    PaymentTicket(
      id: 'quote-002-ticket',
      salonId: 'salon-002',
      appointmentId: 'quote-002-ticket',
      clientId: 'client-003',
      serviceId: 'quote-002-ticket',
      appointmentStart: _now.subtract(const Duration(days: 5)),
      appointmentEnd: _now
          .subtract(const Duration(days: 5))
          .add(const Duration(hours: 1)),
      createdAt: _now.subtract(const Duration(days: 5)),
      status: PaymentTicketStatus.open,
      expectedTotal: 210,
      serviceName: 'Preventivo percorso relax',
      notes: 'Originato da preventivo accettato',
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
      paymentHistory: [
        SalePaymentMovement(
          id: 'sale-001-move-001',
          amount: 114,
          type: SalePaymentType.settlement,
          date: _now.subtract(const Duration(days: 1, hours: 3)),
          paymentMethod: PaymentMethod.pos,
          recordedBy: 'staff-001',
        ),
      ],
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
      paymentHistory: [
        SalePaymentMovement(
          id: 'sale-002-move-001',
          amount: 240,
          type: SalePaymentType.settlement,
          date: _now.subtract(const Duration(days: 4)),
          paymentMethod: PaymentMethod.transfer,
          recordedBy: 'staff-003',
        ),
      ],
    ),
  ];

  static final cashFlowEntries = <CashFlowEntry>[
    CashFlowEntry(
      id: 'cash-001',
      salonId: 'salon-001',
      type: CashFlowType.income,
      amount: 250,
      date: _now.subtract(const Duration(days: 1)),
      createdAt: _now.subtract(const Duration(days: 1, hours: 3)),
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
      createdAt: _now.subtract(const Duration(days: 2, hours: 6)),
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

  static final reminderSettings = <ReminderSettings>[
    ReminderSettings(
      salonId: 'salon-001',
      offsets: const [
        ReminderOffsetConfig(id: 'M1440', minutesBefore: 1440),
        ReminderOffsetConfig(id: 'M180', minutesBefore: 180),
        ReminderOffsetConfig(id: 'M30', minutesBefore: 30),
      ],
      birthdayEnabled: true,
      lastMinuteNotificationAudience: LastMinuteNotificationAudience.everyone,
    ),
    ReminderSettings(
      salonId: 'salon-002',
      offsets: const [
        ReminderOffsetConfig(id: 'M1440', minutesBefore: 1440),
        ReminderOffsetConfig(id: 'M60', minutesBefore: 60),
      ],
      birthdayEnabled: true,
      lastMinuteNotificationAudience: LastMinuteNotificationAudience.none,
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

  static List<StaffAbsence> get publicStaffAbsences =>
      staffAbsences
          .map(
            (absence) => StaffAbsence(
              id: absence.id,
              salonId: absence.salonId,
              staffId: absence.staffId,
              type: absence.type,
              start: absence.start,
              end: absence.end,
            ),
          )
          .toList();
}
