import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_day_checklist.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_calendar_view.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_anomaly.dart';

final DateTime _kAnchorDate = DateTime(2026, 2, 17);
const _kAppointmentCardKey = ValueKey<String>('appointment-card-appt-1');
const _kSecondAppointmentCardKey = ValueKey<String>('appointment-card-appt-2');
const _kHoverPreviewCardKey = ValueKey<String>('appointment_hover_preview');
const _kVisibleWeekdays = <int>{DateTime.tuesday};
const _kFirstClientNumberText = 'N° 623';
const _kSecondClientNumberText = 'N° 999';
const _kHoverPreviewLabel = 'Codice cliente';

Appointment _buildAppointment({
  String id = 'appt-1',
  String clientId = 'client-1',
  String staffId = 'staff-1',
  List<String> serviceIds = const <String>['service-1'],
  DateTime? start,
  DateTime? end,
  AppointmentStatus status = AppointmentStatus.completed,
}) {
  final appointmentStart = start ?? DateTime(2026, 2, 17, 15, 15);
  final appointmentEnd =
      end ?? appointmentStart.add(const Duration(minutes: 15));
  return Appointment(
    id: id,
    salonId: 'salon-1',
    clientId: clientId,
    staffId: staffId,
    serviceIds: serviceIds,
    start: appointmentStart,
    end: appointmentEnd,
    status: status,
  );
}

StaffMember _buildStaff() {
  return _buildStaffWith();
}

StaffMember _buildStaffWith({
  String id = 'staff-1',
  String firstName = 'Federica',
  String lastName = 'Rossi',
}) {
  return StaffMember(
    id: id,
    salonId: 'salon-1',
    firstName: firstName,
    lastName: lastName,
    roleIds: const <String>['role-1'],
  );
}

Client _buildClient() {
  return _buildClientWith();
}

Client _buildClientWith({
  String id = 'client-1',
  String firstName = 'Mario',
  String lastName = 'Bianchi',
  String phone = '0000000000',
  String clientNumber = '623',
}) {
  return Client(
    id: id,
    salonId: 'salon-1',
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    clientNumber: clientNumber,
  );
}

Service _buildService() {
  return Service(
    id: 'service-1',
    salonId: 'salon-1',
    name: 'Reset 360',
    category: 'Viso',
    duration: const Duration(minutes: 60),
    price: 60,
  );
}

List<SalonDailySchedule> _buildOpenDaySchedule({
  int weekday = DateTime.tuesday,
  int openMinuteOfDay = 9 * 60,
  int closeMinuteOfDay = 18 * 60,
}) {
  return <SalonDailySchedule>[
    SalonDailySchedule(
      weekday: weekday,
      isOpen: true,
      openMinuteOfDay: openMinuteOfDay,
      closeMinuteOfDay: closeMinuteOfDay,
    ),
  ];
}

Future<void> _pumpCalendarView(
  WidgetTester tester, {
  required Size size,
  required AppointmentCalendarScope scope,
  AppointmentWeekLayoutMode weekLayout = AppointmentWeekLayoutMode.detailed,
  required int slotMinutes,
  AppointmentTapCallback? onEdit,
  AppointmentRescheduleCallback? onReschedule,
  List<Appointment>? appointments,
  List<Appointment>? allAppointments,
  List<Client>? clients,
  List<Service>? services,
  List<StaffMember>? staffMembers,
  List<Shift> shifts = const <Shift>[],
  List<StaffAbsence> absences = const <StaffAbsence>[],
  List<SalonDailySchedule>? schedule,
  Map<String, Salon> salonsById = const <String, Salon>{},
  String? selectedSalonId,
  Set<int> visibleWeekdays = _kVisibleWeekdays,
  Set<String> clientsWithOutstandingPayments = const <String>{'client-1'},
  Map<String, Set<AppointmentAnomalyType>> anomalies =
      const <String, Set<AppointmentAnomalyType>>{},
}) async {
  final resolvedAppointments =
      appointments ?? <Appointment>[_buildAppointment()];
  final resolvedStaff = staffMembers ?? <StaffMember>[_buildStaff()];
  final resolvedClients = clients ?? <Client>[_buildClient()];
  final resolvedServices = services ?? <Service>[_buildService()];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: AppointmentCalendarView(
            anchorDate: _kAnchorDate,
            scope: scope,
            weekLayout: weekLayout,
            appointments: resolvedAppointments,
            allAppointments: allAppointments ?? resolvedAppointments,
            lastMinutePlaceholders: const <Appointment>[],
            lastMinuteSlots: const [],
            staff: resolvedStaff,
            clients: resolvedClients,
            clientsWithOutstandingPayments: clientsWithOutstandingPayments,
            services: resolvedServices,
            serviceCategories: const <ServiceCategory>[],
            shifts: shifts,
            absences: absences,
            roles: const <StaffRole>[],
            schedule: schedule,
            visibleWeekdays: visibleWeekdays,
            roomsById: const <String, String>{},
            salonsById: salonsById,
            selectedSalonId: selectedSalonId,
            lockedAppointmentReasons: const <String, String>{},
            dayChecklists: const <DateTime, AppointmentDayChecklist>{},
            anomalies: anomalies,
            statusColor: (_) => Colors.green,
            slotMinutes: slotMinutes,
            interactionSlotMinutes: slotMinutes,
            onReschedule: onReschedule ?? (_) async {},
            onEdit: onEdit ?? (_) {},
            onCreate: (_) {},
            onTapLastMinuteSlot: null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _createMouseGesture(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await tester.pump();
  return gesture;
}

Future<void> _hoverAt(
  WidgetTester tester,
  TestGesture gesture,
  Offset location,
) async {
  await gesture.moveTo(location);
  await tester.pump(const Duration(milliseconds: 220));
}

Future<void> _hoverFinder(
  WidgetTester tester,
  TestGesture gesture,
  Finder finder,
) async {
  await _hoverAt(tester, gesture, tester.getCenter(finder));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('day view keeps 15 minute card readable on mobile', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(390, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(_kAppointmentCardKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(_kAppointmentCardKey)).height,
      moreOrLessEquals(76.0, epsilon: 0.5),
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.text('15:15'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(_kAppointmentCardKey),
              matching: find.byIcon(Icons.check_circle_rounded),
            ),
          )
          .size,
      13,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.payments_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(_kAppointmentCardKey),
              matching: find.byIcon(Icons.payments_rounded),
            ),
          )
          .size,
      14,
    );
  });

  testWidgets('week detailed view keeps 15 minute card readable on tablet', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(1000, 900),
      scope: AppointmentCalendarScope.week,
      weekLayout: AppointmentWeekLayoutMode.detailed,
      slotMinutes: 30,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(_kAppointmentCardKey)).height,
      moreOrLessEquals(68.0, epsilon: 0.5),
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.text('15:15'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(_kAppointmentCardKey),
              matching: find.byIcon(Icons.check_circle_rounded),
            ),
          )
          .size,
      13,
    );
  });

  testWidgets('15 minute card stays readable with all alert icons', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(390, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
      appointments: <Appointment>[
        _buildAppointment().copyWith(packageId: 'pkg-1'),
      ],
      anomalies: const <String, Set<AppointmentAnomalyType>>{
        'appt-1': <AppointmentAnomalyType>{AppointmentAnomalyType.noShift},
      },
    );

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.payments_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.inventory_2_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('calendar shows no shift overlay marker on uncovered slots', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(900, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
      schedule: _buildOpenDaySchedule(),
      selectedSalonId: 'salon-1',
    );

    expect(find.byKey(const ValueKey<String>('no-shift-marker')), findsWidgets);
    expect(find.text('Nessun turno'), findsNothing);
  });

  testWidgets('narrow warning cards stay icon only without overflow', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(360, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
      appointments: <Appointment>[
        _buildAppointment().copyWith(packageId: 'pkg-1'),
      ],
      staffMembers: <StaffMember>[
        _buildStaffWith(
          id: 'staff-1',
          firstName: 'Federica',
          lastName: 'Rossi',
        ),
        _buildStaffWith(id: 'staff-2', firstName: 'Ada', lastName: 'Neri'),
        _buildStaffWith(id: 'staff-3', firstName: 'Luca', lastName: 'Bianchi'),
        _buildStaffWith(id: 'staff-4', firstName: 'Sara', lastName: 'Verdi'),
      ],
      anomalies: const <String, Set<AppointmentAnomalyType>>{
        'appt-1': <AppointmentAnomalyType>{AppointmentAnomalyType.noShift},
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(_kAppointmentCardKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.text('Fuori turno'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsWidgets,
    );
  });

  testWidgets('week compact view keeps short cards icon only', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(1000, 900),
      scope: AppointmentCalendarScope.week,
      weekLayout: AppointmentWeekLayoutMode.compact,
      slotMinutes: 60,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(_kAppointmentCardKey)).height,
      moreOrLessEquals(44.0, epsilon: 0.5),
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.text('15:15'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_kAppointmentCardKey),
        matching: find.byIcon(Icons.payments_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mouse click on appointment card triggers onEdit callback', (
    WidgetTester tester,
  ) async {
    Appointment? edited;

    await _pumpCalendarView(
      tester,
      size: const Size(1100, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
      onEdit: (value) {
        edited = value;
      },
    );

    final appointmentCard = find.byKey(_kAppointmentCardKey);
    expect(appointmentCard, findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final center = tester.getCenter(appointmentCard);
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.down(center);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.id, equals('appt-1'));
  });

  testWidgets('hover preview opens and closes when moving to an empty slot', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(1100, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
    );

    final gesture = await _createMouseGesture(tester);
    await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));

    expect(find.text(_kHoverPreviewLabel), findsOneWidget);
    expect(find.text(_kFirstClientNumberText), findsOneWidget);
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);

    final cardCenter = tester.getCenter(find.byKey(_kAppointmentCardKey));
    await _hoverAt(tester, gesture, Offset(cardCenter.dx, cardCenter.dy - 180));

    expect(find.text(_kHoverPreviewLabel), findsNothing);
    expect(find.text(_kFirstClientNumberText), findsNothing);
    expect(find.byKey(_kHoverPreviewCardKey), findsNothing);
  });

  testWidgets('hovering a second appointment always replaces the old preview', (
    WidgetTester tester,
  ) async {
    final firstAppointment = _buildAppointment();
    final secondAppointment = _buildAppointment(
      id: 'appt-2',
      clientId: 'client-2',
      start: DateTime(2026, 2, 17, 16, 15),
      end: DateTime(2026, 2, 17, 16, 45),
    );
    final secondClient = _buildClientWith(
      id: 'client-2',
      firstName: 'Anna',
      lastName: 'Verdi',
      phone: '1111111111',
      clientNumber: '999',
    );

    await _pumpCalendarView(
      tester,
      size: const Size(1100, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
      appointments: <Appointment>[firstAppointment, secondAppointment],
      clients: <Client>[_buildClient(), secondClient],
    );

    final gesture = await _createMouseGesture(tester);
    await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));
    expect(find.text(_kHoverPreviewLabel), findsOneWidget);
    expect(find.text(_kFirstClientNumberText), findsOneWidget);
    expect(find.text(_kSecondClientNumberText), findsNothing);
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);

    await _hoverFinder(tester, gesture, find.byKey(_kSecondAppointmentCardKey));

    expect(find.text(_kHoverPreviewLabel), findsOneWidget);
    expect(find.text(_kFirstClientNumberText), findsNothing);
    expect(find.text(_kSecondClientNumberText), findsOneWidget);
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);
  });

  testWidgets(
    'hovering across day staff columns keeps a single shared preview',
    (WidgetTester tester) async {
      final secondStaff = _buildStaffWith(
        id: 'staff-2',
        firstName: 'Anna',
        lastName: 'Neri',
      );
      final secondAppointment = _buildAppointment(
        id: 'appt-2',
        clientId: 'client-2',
        staffId: 'staff-2',
        start: DateTime(2026, 2, 17, 15, 45),
        end: DateTime(2026, 2, 17, 16, 15),
      );
      final secondClient = _buildClientWith(
        id: 'client-2',
        firstName: 'Anna',
        lastName: 'Verdi',
        phone: '1111111111',
        clientNumber: '999',
      );

      await _pumpCalendarView(
        tester,
        size: const Size(1400, 900),
        scope: AppointmentCalendarScope.day,
        slotMinutes: 30,
        appointments: <Appointment>[_buildAppointment(), secondAppointment],
        clients: <Client>[_buildClient(), secondClient],
        staffMembers: <StaffMember>[_buildStaff(), secondStaff],
      );

      final gesture = await _createMouseGesture(tester);
      await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));
      expect(find.text(_kFirstClientNumberText), findsOneWidget);
      expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);

      await _hoverFinder(
        tester,
        gesture,
        find.byKey(_kSecondAppointmentCardKey),
      );

      expect(find.text(_kFirstClientNumberText), findsNothing);
      expect(find.text(_kSecondClientNumberText), findsOneWidget);
      expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);
    },
  );

  testWidgets('week view uses one preview across different day columns', (
    WidgetTester tester,
  ) async {
    final secondAppointment = _buildAppointment(
      id: 'appt-2',
      clientId: 'client-2',
      start: DateTime(2026, 2, 18, 10, 0),
      end: DateTime(2026, 2, 18, 10, 30),
    );
    final secondClient = _buildClientWith(
      id: 'client-2',
      firstName: 'Anna',
      lastName: 'Verdi',
      phone: '1111111111',
      clientNumber: '999',
    );

    await _pumpCalendarView(
      tester,
      size: const Size(1400, 900),
      scope: AppointmentCalendarScope.week,
      weekLayout: AppointmentWeekLayoutMode.detailed,
      slotMinutes: 30,
      appointments: <Appointment>[_buildAppointment(), secondAppointment],
      clients: <Client>[_buildClient(), secondClient],
      visibleWeekdays: const <int>{DateTime.tuesday, DateTime.wednesday},
    );

    await tester.ensureVisible(find.byKey(_kAppointmentCardKey));
    await tester.pumpAndSettle();

    final gesture = await _createMouseGesture(tester);
    await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);
    expect(find.text(_kHoverPreviewLabel), findsOneWidget);

    await tester.ensureVisible(find.byKey(_kSecondAppointmentCardKey));
    await tester.pumpAndSettle();
    await _hoverFinder(tester, gesture, find.byKey(_kSecondAppointmentCardKey));

    expect(find.text(_kFirstClientNumberText), findsNothing);
    expect(find.text(_kSecondClientNumberText), findsOneWidget);
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);
  });

  testWidgets('removing the hovered appointment clears the preview overlay', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(1100, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
    );

    final gesture = await _createMouseGesture(tester);
    await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));
    expect(find.text(_kHoverPreviewLabel), findsOneWidget);
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);

    await _pumpCalendarView(
      tester,
      size: const Size(1100, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
      appointments: const <Appointment>[],
      allAppointments: const <Appointment>[],
    );

    expect(find.byKey(_kAppointmentCardKey), findsNothing);
    expect(find.text(_kHoverPreviewLabel), findsNothing);
    expect(find.text(_kFirstClientNumberText), findsNothing);
    expect(find.byKey(_kHoverPreviewCardKey), findsNothing);
  });

  testWidgets('unmounting the calendar clears any active hover preview', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(1100, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
    );

    final gesture = await _createMouseGesture(tester);
    await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));
    expect(find.text(_kHoverPreviewLabel), findsOneWidget);
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(find.text(_kHoverPreviewLabel), findsNothing);
    expect(find.text(_kFirstClientNumberText), findsNothing);
    expect(find.byKey(_kHoverPreviewCardKey), findsNothing);
  });

  testWidgets('pressing an appointment clears the hover preview', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(1100, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
    );

    final gesture = await _createMouseGesture(tester);
    await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);

    final cardCenter = tester.getCenter(find.byKey(_kAppointmentCardKey));
    await gesture.down(cardCenter);
    await tester.pump();

    expect(find.byKey(_kHoverPreviewCardKey), findsNothing);
    expect(find.text(_kHoverPreviewLabel), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('scrolling the agenda closes the hover preview', (
    WidgetTester tester,
  ) async {
    await _pumpCalendarView(
      tester,
      size: const Size(620, 900),
      scope: AppointmentCalendarScope.day,
      slotMinutes: 30,
      staffMembers: <StaffMember>[
        _buildStaff(),
        _buildStaffWith(id: 'staff-2', firstName: 'Luca', lastName: 'Bianchi'),
        _buildStaffWith(id: 'staff-3', firstName: 'Sara', lastName: 'Verdi'),
      ],
    );

    final gesture = await _createMouseGesture(tester);
    await _hoverFinder(tester, gesture, find.byKey(_kAppointmentCardKey));
    expect(find.text(_kHoverPreviewLabel), findsOneWidget);
    expect(find.byKey(_kHoverPreviewCardKey), findsOneWidget);

    final horizontalScrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .where(
          (state) =>
              state.widget.axisDirection == AxisDirection.left ||
              state.widget.axisDirection == AxisDirection.right,
        )
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    final position = horizontalScrollable.position;
    expect(position.maxScrollExtent, greaterThan(0));

    position.jumpTo(
      (position.pixels + 160).clamp(0.0, position.maxScrollExtent),
    );
    await tester.pumpAndSettle();

    expect(find.text(_kHoverPreviewLabel), findsNothing);
    expect(find.text(_kFirstClientNumberText), findsNothing);
    expect(find.byKey(_kHoverPreviewCardKey), findsNothing);
  });
}
