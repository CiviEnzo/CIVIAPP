import 'package:civiapp/data/models/app_user.dart';
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

class AppDataState {
  const AppDataState({
    required this.salons,
    required this.staff,
    required this.clients,
    required this.services,
    required this.packages,
    required this.appointments,
    required this.inventoryItems,
    required this.sales,
    required this.cashFlowEntries,
    required this.messageTemplates,
    required this.shifts,
    required this.staffAbsences,
    required this.users,
  });

  factory AppDataState.initial() {
    return const AppDataState(
      salons: [],
      staff: [],
      clients: [],
      services: [],
      packages: [],
      appointments: [],
      inventoryItems: [],
      sales: [],
      cashFlowEntries: [],
      messageTemplates: [],
      shifts: [],
      staffAbsences: [],
      users: [],
    );
  }

  final List<Salon> salons;
  final List<StaffMember> staff;
  final List<Client> clients;
  final List<Service> services;
  final List<ServicePackage> packages;
  final List<Appointment> appointments;
  final List<InventoryItem> inventoryItems;
  final List<Sale> sales;
  final List<CashFlowEntry> cashFlowEntries;
  final List<MessageTemplate> messageTemplates;
  final List<Shift> shifts;
  final List<StaffAbsence> staffAbsences;
  final List<AppUser> users;

  AppDataState copyWith({
    List<Salon>? salons,
    List<StaffMember>? staff,
    List<Client>? clients,
    List<Service>? services,
    List<ServicePackage>? packages,
    List<Appointment>? appointments,
    List<InventoryItem>? inventoryItems,
    List<Sale>? sales,
    List<CashFlowEntry>? cashFlowEntries,
    List<MessageTemplate>? messageTemplates,
    List<Shift>? shifts,
    List<StaffAbsence>? staffAbsences,
    List<AppUser>? users,
  }) {
    return AppDataState(
      salons: salons ?? this.salons,
      staff: staff ?? this.staff,
      clients: clients ?? this.clients,
      services: services ?? this.services,
      packages: packages ?? this.packages,
      appointments: appointments ?? this.appointments,
      inventoryItems: inventoryItems ?? this.inventoryItems,
      sales: sales ?? this.sales,
      cashFlowEntries: cashFlowEntries ?? this.cashFlowEntries,
      messageTemplates: messageTemplates ?? this.messageTemplates,
      shifts: shifts ?? this.shifts,
      staffAbsences: staffAbsences ?? this.staffAbsences,
      users: users ?? this.users,
    );
  }
}
