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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('mouse click on appointment card triggers onEdit callback', (
    WidgetTester tester,
  ) async {
    final appointment = Appointment(
      id: 'appt-1',
      salonId: 'salon-1',
      clientId: 'client-1',
      staffId: 'staff-1',
      serviceIds: const <String>['service-1'],
      start: DateTime(2026, 2, 17, 15, 0),
      end: DateTime(2026, 2, 17, 16, 0),
      status: AppointmentStatus.scheduled,
    );

    final staff = StaffMember(
      id: 'staff-1',
      salonId: 'salon-1',
      firstName: 'Federica',
      lastName: 'Rossi',
      roleIds: const <String>['role-1'],
    );

    final client = Client(
      id: 'client-1',
      salonId: 'salon-1',
      firstName: 'Mario',
      lastName: 'Bianchi',
      phone: '0000000000',
      clientNumber: '623',
    );

    final service = Service(
      id: 'service-1',
      salonId: 'salon-1',
      name: 'Reset 360',
      category: 'Viso',
      duration: const Duration(minutes: 60),
      price: 60,
    );

    Appointment? edited;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1100,
            height: 900,
            child: AppointmentCalendarView(
              anchorDate: DateTime(2026, 2, 17),
              scope: AppointmentCalendarScope.day,
              appointments: <Appointment>[appointment],
              allAppointments: <Appointment>[appointment],
              lastMinutePlaceholders: const <Appointment>[],
              lastMinuteSlots: const [],
              staff: <StaffMember>[staff],
              clients: <Client>[client],
              clientsWithOutstandingPayments: const <String>{},
              services: <Service>[service],
              serviceCategories: const <ServiceCategory>[],
              shifts: const <Shift>[],
              absences: const <StaffAbsence>[],
              roles: const <StaffRole>[],
              schedule: null,
              visibleWeekdays: const <int>{
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday,
                DateTime.saturday,
                DateTime.sunday,
              },
              roomsById: const <String, String>{},
              salonsById: const <String, Salon>{},
              selectedSalonId: null,
              lockedAppointmentReasons: const <String, String>{},
              dayChecklists: const <DateTime, AppointmentDayChecklist>{},
              anomalies: const <String, Set<AppointmentAnomalyType>>{},
              statusColor: (_) => Colors.green,
              onReschedule: (_) async {},
              onEdit: (value) {
                edited = value;
              },
              onCreate: (_) {},
              onTapLastMinuteSlot: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appointmentText = find.textContaining('Reset 360');
    expect(appointmentText, findsWidgets);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final center = tester.getCenter(appointmentText.first);
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
}
