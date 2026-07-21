import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/expense.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_aggregator.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_export_service.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_models.dart';

void main() {
  group('ReportsAggregator', () {
    test('aggregates KPI, occupancy, inventory alerts and promotion CTR', () {
      final state = _buildState(
        shifts: [
          Shift(
            id: 'shift-1',
            salonId: 'salon-1',
            staffId: 'staff-1',
            start: DateTime(2026, 3, 4, 9),
            end: DateTime(2026, 3, 4, 12, 30),
            breakStart: DateTime(2026, 3, 4, 11, 30),
            breakEnd: DateTime(2026, 3, 4, 12),
          ),
        ],
      );

      final snapshot = ReportsAggregator.build(
        data: state,
        filters: _filters(),
      );

      expect(snapshot.current.totalRevenue, 100);
      expect(snapshot.current.salesCount, 1);
      expect(snapshot.current.averageTicket, 100);
      expect(snapshot.current.newClients, 1);
      expect(snapshot.current.completedAppointments, 1);
      expect(snapshot.current.cancelledAppointments, 1);
      expect(snapshot.current.noShowAppointments, 1);
      expect(snapshot.current.activeClients, 2);
      expect(snapshot.current.returningClients, 1);
      expect(snapshot.current.averageRevenuePerClient, 50);
      expect(snapshot.current.occupancy.ratio, closeTo(0.5, 0.001));
      expect(snapshot.current.occupancy.estimated, isFalse);
      expect(snapshot.inventoryAlerts.length, 1);
      expect(snapshot.promotionCtr, closeTo(0.1, 0.0001));
      expect(snapshot.topServices.first.name, 'Trattamento viso');
    });

    test('uses competence for profit and payment date for cash flow', () {
      final state = _buildState(
        shifts: const [],
        expenseCategories: const [
          ExpenseCategory(
            id: 'expense-cat-1',
            salonId: 'salon-1',
            name: 'Affitto',
          ),
        ],
        expenses: [
          Expense(
            id: 'expense-current-competence',
            salonId: 'salon-1',
            categoryId: 'expense-cat-1',
            title: 'Canone marzo',
            totalAmount: 40,
            competenceDate: DateTime(2026, 3, 2),
            dueDate: DateTime(2026, 3, 5),
            createdAt: DateTime(2026, 3, 1),
            payments: [
              ExpensePayment(
                id: 'payment-outside-period',
                amount: 40,
                date: DateTime(2026, 4, 1),
                paymentMethod: PaymentMethod.transfer,
              ),
            ],
          ),
          Expense(
            id: 'expense-paid-in-period',
            salonId: 'salon-1',
            categoryId: 'expense-cat-1',
            title: 'Saldo febbraio',
            totalAmount: 30,
            competenceDate: DateTime(2026, 2, 20),
            dueDate: DateTime(2026, 2, 28),
            createdAt: DateTime(2026, 2, 20),
            payments: [
              ExpensePayment(
                id: 'payment-inside-period',
                amount: 30,
                date: DateTime(2026, 3, 3),
                paymentMethod: PaymentMethod.transfer,
              ),
            ],
          ),
        ],
      );

      final snapshot = ReportsAggregator.build(
        data: state,
        filters: _filters(),
      );

      expect(snapshot.current.totalRevenue, 100);
      expect(snapshot.current.totalExpenses, 40);
      expect(snapshot.current.netProfit, 60);
      expect(snapshot.current.cashOut, 30);
      expect(snapshot.current.netCashFlow, 70);
      expect(snapshot.filteredExpenses.map((item) => item.id), [
        'expense-current-competence',
      ]);
    });

    test('falls back to salon schedule when shifts are missing', () {
      final state = _buildState(shifts: const []);

      final snapshot = ReportsAggregator.build(
        data: state,
        filters: _filters(),
      );

      expect(snapshot.current.occupancy.estimated, isTrue);
      expect(snapshot.current.occupancy.ratio, closeTo(0.1875, 0.0001));
    });

    test(
      'marks occupancy as unavailable when no shifts and no schedule exist',
      () {
        final state = _buildState(
          shifts: const [],
          schedule: const <SalonDailySchedule>[],
        );

        final snapshot = ReportsAggregator.build(
          data: state,
          filters: _filters(),
        );

        expect(snapshot.current.occupancy.ratio, isNull);
        expect(snapshot.occupancyTrend, isEmpty);
      },
    );
  });

  group('ReportExportService', () {
    test('builds non-empty pdf and csv exports', () async {
      final service = const ReportExportService();
      final snapshot = ReportsAggregator.build(
        data: _buildState(
          shifts: [
            Shift(
              id: 'shift-1',
              salonId: 'salon-1',
              staffId: 'staff-1',
              start: DateTime(2026, 3, 4, 9),
              end: DateTime(2026, 3, 4, 12, 30),
              breakStart: DateTime(2026, 3, 4, 11, 30),
              breakEnd: DateTime(2026, 3, 4, 12),
            ),
          ],
        ),
        filters: _filters(),
      );

      final pdf = await service.buildExecutivePdf(snapshot: snapshot);
      final salesCsv = service.buildCsvDataset(
        snapshot: snapshot,
        dataset: ReportExportDataset.sales,
      );

      expect(pdf.fileName, endsWith('.pdf'));
      expect(pdf.bytes.length, greaterThan(500));
      expect(salesCsv.fileName, contains('vendite_youbook_'));
      expect(utf8.decode(salesCsv.bytes), contains('Totale report'));
      expect(utf8.decode(salesCsv.bytes), contains('Cliente storico Uno'));
    });
  });
}

ReportFilters _filters() {
  return ReportFilters(
    range: DateTimeRange(
      start: DateTime(2026, 3, 1),
      end: DateTime(2026, 3, 7, 23, 59, 59),
    ),
    salonId: 'salon-1',
  );
}

AppDataState _buildState({
  required List<Shift> shifts,
  List<SalonDailySchedule> schedule = const <SalonDailySchedule>[
    SalonDailySchedule(
      weekday: DateTime.wednesday,
      isOpen: true,
      openMinuteOfDay: 9 * 60,
      closeMinuteOfDay: 17 * 60,
    ),
  ],
  List<ExpenseCategory> expenseCategories = const <ExpenseCategory>[],
  List<Expense> expenses = const <Expense>[],
}) {
  return AppDataState.initial().copyWith(
    salons: [
      Salon(
        id: 'salon-1',
        name: 'Salon Test',
        address: 'Via Roma 1',
        city: 'Roma',
        phone: '000',
        email: 'test@example.com',
        schedule: schedule,
      ),
    ],
    staff: [
      StaffMember(
        id: 'staff-1',
        salonId: 'salon-1',
        firstName: 'Giulia',
        lastName: 'Rossi',
      ),
    ],
    serviceCategories: const [
      ServiceCategory(id: 'cat-1', salonId: 'salon-1', name: 'Viso'),
    ],
    services: const [
      Service(
        id: 'service-1',
        salonId: 'salon-1',
        name: 'Trattamento viso',
        category: 'Viso',
        categoryId: 'cat-1',
        duration: Duration(minutes: 60),
        price: 100,
      ),
    ],
    clients: [
      Client(
        id: 'client-1',
        salonId: 'salon-1',
        firstName: 'Cliente storico',
        lastName: 'Uno',
        phone: '111',
        createdAt: DateTime(2026, 2, 1),
      ),
      Client(
        id: 'client-2',
        salonId: 'salon-1',
        firstName: 'Nuovo',
        lastName: 'Cliente',
        phone: '222',
        referralSource: 'Instagram',
        createdAt: DateTime(2026, 3, 3),
      ),
    ],
    appointments: [
      Appointment(
        id: 'appt-1',
        salonId: 'salon-1',
        clientId: 'client-1',
        staffId: 'staff-1',
        serviceIds: const ['service-1'],
        start: DateTime(2026, 3, 4, 10),
        end: DateTime(2026, 3, 4, 11),
        status: AppointmentStatus.completed,
        bookingChannel: 'app',
      ),
      Appointment(
        id: 'appt-2',
        salonId: 'salon-1',
        clientId: 'client-2',
        staffId: 'staff-1',
        serviceIds: const ['service-1'],
        start: DateTime(2026, 3, 4, 11),
        end: DateTime(2026, 3, 4, 11, 30),
        status: AppointmentStatus.cancelled,
        bookingChannel: 'app',
      ),
      Appointment(
        id: 'appt-3',
        salonId: 'salon-1',
        clientId: 'client-2',
        staffId: 'staff-1',
        serviceIds: const ['service-1'],
        start: DateTime(2026, 3, 4, 12),
        end: DateTime(2026, 3, 4, 12, 30),
        status: AppointmentStatus.noShow,
        bookingChannel: 'instagram',
      ),
    ],
    sales: [
      Sale(
        id: 'sale-current',
        salonId: 'salon-1',
        clientId: 'client-1',
        staffId: 'staff-1',
        createdAt: DateTime(2026, 3, 4, 12, 5),
        total: 100,
        items: [
          SaleItem(
            referenceId: 'service-1',
            referenceType: SaleReferenceType.service,
            description: 'Trattamento viso',
            quantity: 1,
            unitPrice: 100,
          ),
        ],
        metadata: const {'source': 'app'},
      ),
      Sale(
        id: 'sale-previous',
        salonId: 'salon-1',
        clientId: 'client-1',
        staffId: 'staff-1',
        createdAt: DateTime(2026, 2, 20, 12, 5),
        total: 80,
        items: [
          SaleItem(
            referenceId: 'service-1',
            referenceType: SaleReferenceType.service,
            description: 'Trattamento viso',
            quantity: 1,
            unitPrice: 80,
          ),
        ],
      ),
    ],
    inventoryItems: const [
      InventoryItem(
        id: 'item-1',
        salonId: 'salon-1',
        name: 'Siero viso',
        category: 'Cosmetici',
        quantity: 2,
        unit: 'pz',
        threshold: 5,
        cost: 10,
        sellingPrice: 20,
      ),
    ],
    expenseCategories: expenseCategories,
    expenses: expenses,
    promotions: [
      Promotion(
        id: 'promo-1',
        salonId: 'salon-1',
        title: 'Promo primavera',
        startsAt: DateTime(2026, 3, 1),
        endsAt: DateTime(2026, 3, 31),
        status: PromotionStatus.published,
        analytics: const PromotionAnalytics(viewCount: 100, ctaClickCount: 10),
      ),
    ],
    shifts: shifts,
  );
}
