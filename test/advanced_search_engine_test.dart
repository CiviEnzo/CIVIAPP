import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_engine.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_filters.dart';

void main() {
  const salonId = 'salon-001';
  final now = DateTime(2026, 6, 5, 12);

  test('filters clients by any completed service appointment', () {
    final targetClient = _client('client-target', 'Anna');
    final otherClient = _client('client-other', 'Bruno');
    final engine = AdvancedSearchEngine(
      state: AppDataState.initial().copyWith(
        clients: [targetClient, otherClient],
        services: [
          _service('srv-viso', 'Pulizia viso', 'cat-viso'),
          _service('srv-mani', 'Manicure', 'cat-mani'),
        ],
        appointments: [
          _appointment(
            id: 'appt-old-target',
            clientId: targetClient.id,
            serviceId: 'srv-viso',
            end: DateTime(2026, 4, 1, 11),
            status: AppointmentStatus.completed,
          ),
          _appointment(
            id: 'appt-new-target',
            clientId: targetClient.id,
            serviceId: 'srv-mani',
            end: DateTime(2026, 5, 1, 11),
            status: AppointmentStatus.completed,
          ),
          _appointment(
            id: 'appt-other',
            clientId: otherClient.id,
            serviceId: 'srv-mani',
            end: DateTime(2026, 5, 2, 11),
            status: AppointmentStatus.completed,
          ),
        ],
      ),
      now: now,
      defaultSalonId: salonId,
    );

    final results = engine.apply(
      const AdvancedSearchFilters(
        salonId: salonId,
        completedAppointmentServiceIds: {'srv-viso'},
      ),
    );

    expect(results.map((client) => client.id), [targetClient.id]);
  });

  test('ignores scheduled appointments for completed service filter', () {
    final client = _client('client-target', 'Anna');
    final engine = AdvancedSearchEngine(
      state: AppDataState.initial().copyWith(
        clients: [client],
        services: [_service('srv-viso', 'Pulizia viso', 'cat-viso')],
        appointments: [
          _appointment(
            id: 'appt-future',
            clientId: client.id,
            serviceId: 'srv-viso',
            end: DateTime(2026, 6, 10, 11),
            status: AppointmentStatus.scheduled,
          ),
        ],
      ),
      now: now,
      defaultSalonId: salonId,
    );

    final results = engine.apply(
      const AdvancedSearchFilters(
        salonId: salonId,
        completedAppointmentServiceIds: {'srv-viso'},
      ),
    );

    expect(results, isEmpty);
  });

  test('filters completed service appointments by past date range', () {
    final oldClient = _client('client-old', 'Anna');
    final recentClient = _client('client-recent', 'Bruno');
    final engine = AdvancedSearchEngine(
      state: AppDataState.initial().copyWith(
        clients: [oldClient, recentClient],
        services: [_service('srv-viso', 'Pulizia viso', 'cat-viso')],
        appointments: [
          _appointment(
            id: 'appt-old',
            clientId: oldClient.id,
            serviceId: 'srv-viso',
            end: DateTime(2026, 4, 30, 18),
            status: AppointmentStatus.completed,
          ),
          _appointment(
            id: 'appt-recent',
            clientId: recentClient.id,
            serviceId: 'srv-viso',
            end: DateTime(2026, 5, 31, 18),
            status: AppointmentStatus.completed,
          ),
        ],
      ),
      now: now,
      defaultSalonId: salonId,
    );

    final results = engine.apply(
      AdvancedSearchFilters(
        salonId: salonId,
        completedAppointmentServiceIds: const {'srv-viso'},
        completedAppointmentFrom: DateTime(2026, 5),
        completedAppointmentTo: DateTime(2026, 5, 31),
      ),
    );

    expect(results.map((client) => client.id), [recentClient.id]);
  });
}

Client _client(String id, String firstName) {
  return Client(
    id: id,
    salonId: 'salon-001',
    firstName: firstName,
    lastName: 'Cliente',
    phone: '3330000000',
  );
}

Service _service(String id, String name, String categoryId) {
  return Service(
    id: id,
    salonId: 'salon-001',
    name: name,
    category: categoryId,
    categoryId: categoryId,
    duration: const Duration(minutes: 30),
    price: 50,
  );
}

Appointment _appointment({
  required String id,
  required String clientId,
  required String serviceId,
  required DateTime end,
  required AppointmentStatus status,
}) {
  return Appointment(
    id: id,
    salonId: 'salon-001',
    clientId: clientId,
    staffId: 'staff-001',
    serviceId: serviceId,
    start: end.subtract(const Duration(minutes: 30)),
    end: end,
    status: status,
  );
}
