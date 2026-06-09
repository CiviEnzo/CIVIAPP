import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_service_allocation.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';

void main() {
  test('service sale credit is resolved as a usable client session', () {
    const service = Service(
      id: 'srv-credit',
      salonId: 'salon-001',
      name: 'Trattamento test',
      category: 'Viso',
      duration: Duration(minutes: 45),
      price: 80,
    );
    final sale = Sale(
      id: 'sale-service-credit',
      salonId: service.salonId,
      clientId: 'client-001',
      items: [
        SaleItem(
          referenceId: service.id,
          referenceType: SaleReferenceType.service,
          description: service.name,
          quantity: 1,
          unitPrice: service.price,
          totalSessions: 1,
          remainingSessions: 1,
          remainingPackageServiceSessions: const {'srv-credit': 1},
        ),
      ],
      total: service.price,
      createdAt: DateTime(2026, 1),
    );

    final purchases = resolveClientPackagePurchases(
      sales: [sale],
      packages: const [],
      appointments: const [],
      services: const [service],
      clientId: sale.clientId,
      salonId: sale.salonId,
    );

    expect(purchases, hasLength(1));
    expect(purchases.single.displayName, service.name);
    expect(purchases.single.supportsService(service.id), isTrue);
    expect(purchases.single.remainingSessionsForService(service.id), 1);
    expect(purchases.single.effectiveRemainingSessions, 1);
    expect(purchases.single.outstandingAmount, 0);
    expect(purchases.single.paymentStatus, PackagePaymentStatus.paid);
  });

  test('completed appointment consumes a service sale credit', () async {
    final store = AppDataStore(currentUser: null);
    final service = store.state.services.firstWhere(
      (item) => item.salonId == 'salon-001',
    );
    final staff = store.state.staff.firstWhere(
      (item) => item.salonId == service.salonId && !item.isEquipment,
    );
    const clientId = 'client-001';
    final sale = Sale(
      id: 'sale-service-credit-consume',
      salonId: service.salonId,
      clientId: clientId,
      items: [
        SaleItem(
          referenceId: service.id,
          referenceType: SaleReferenceType.service,
          description: service.name,
          quantity: 1,
          unitPrice: service.price,
          totalSessions: 1,
          remainingSessions: 1,
          remainingPackageServiceSessions: {service.id: 1},
        ),
      ],
      total: service.price,
      createdAt: DateTime(2026, 1),
    );
    await store.upsertSale(sale);

    final appointment = Appointment(
      id: 'appointment-service-credit-consume',
      salonId: service.salonId,
      clientId: clientId,
      staffId: staff.id,
      serviceAllocations: [
        AppointmentServiceAllocation(
          serviceId: service.id,
          quantity: 1,
          packageConsumptions: [
            AppointmentPackageConsumption(
              packageReferenceId: service.id,
              quantity: 1,
            ),
          ],
        ),
      ],
      start: DateTime(2026, 1, 2, 10),
      end: DateTime(2026, 1, 2, 11),
      status: AppointmentStatus.completed,
    );
    await store.upsertAppointment(appointment);

    final updatedSale = store.state.sales.firstWhere(
      (item) => item.id == sale.id,
    );
    final updatedItem = updatedSale.items.single;
    expect(updatedItem.remainingSessions, 0);
    expect(updatedItem.remainingPackageServiceSessions[service.id], 0);
    expect(updatedItem.packageStatus, PackagePurchaseStatus.completed);
  });

  test(
    'copied appointment with stale session allocation creates ticket',
    () async {
      final store = AppDataStore(currentUser: null);
      final service = store.state.services.firstWhere(
        (item) => item.salonId == 'salon-001',
      );
      final staff = store.state.staff.firstWhere(
        (item) => item.salonId == service.salonId && !item.isEquipment,
      );
      const clientId = 'client-copy-session-test';
      final sale = Sale(
        id: 'sale-service-credit-copy',
        salonId: service.salonId,
        clientId: clientId,
        items: [
          SaleItem(
            referenceId: service.id,
            referenceType: SaleReferenceType.service,
            description: service.name,
            quantity: 1,
            unitPrice: service.price,
            totalSessions: 1,
            remainingSessions: 1,
            remainingPackageServiceSessions: {service.id: 1},
          ),
        ],
        total: service.price,
        createdAt: DateTime(2026, 1),
      );
      await store.upsertSale(sale);

      Appointment buildAppointment(String id, DateTime start) {
        return Appointment(
          id: id,
          salonId: service.salonId,
          clientId: clientId,
          staffId: staff.id,
          serviceAllocations: [
            AppointmentServiceAllocation(
              serviceId: service.id,
              quantity: 1,
              packageConsumptions: [
                AppointmentPackageConsumption(
                  packageReferenceId: service.id,
                  quantity: 1,
                ),
              ],
            ),
          ],
          start: start,
          end: start.add(service.duration),
          status: AppointmentStatus.completed,
        );
      }

      await store.upsertAppointment(
        buildAppointment(
          'appointment-original-session',
          DateTime(2026, 1, 3, 9),
        ),
      );
      final consumedSale = store.state.sales.firstWhere(
        (item) => item.id == sale.id,
      );
      expect(consumedSale.items.single.remainingSessions, 0);

      final copied = buildAppointment(
        'appointment-copied-stale-session',
        DateTime(2026, 1, 4, 9),
      ).copyWith(status: AppointmentStatus.scheduled);
      await store.upsertAppointment(copied);
      await store.upsertAppointment(
        copied.copyWith(status: AppointmentStatus.completed),
      );

      final tickets =
          store.state.paymentTickets
              .where((ticket) => ticket.id == copied.id)
              .toList();
      expect(tickets, hasLength(1));
      expect(tickets.single.expectedTotal, service.price);

      final persistedAppointment = store.state.appointments.firstWhere(
        (appointment) => appointment.id == copied.id,
      );
      expect(
        persistedAppointment.serviceAllocations.single.packageConsumptions,
        isEmpty,
      );
    },
  );
}
