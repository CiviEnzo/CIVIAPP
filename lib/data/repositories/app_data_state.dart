import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/client_questionnaire.dart';
import 'package:civiapp/domain/entities/client_photo.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/app_notification.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/quote.dart';
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

class AppDataState {
  const AppDataState({
    required this.salons,
    required this.staff,
    required this.staffRoles,
    required this.clients,
    required this.serviceCategories,
    required this.services,
    required this.packages,
    required this.appointments,
    required this.quotes,
    required this.paymentTickets,
    required this.inventoryItems,
    required this.sales,
    required this.cashFlowEntries,
    required this.messageTemplates,
    required this.reminderSettings,
    required this.clientNotifications,
    required this.shifts,
    required this.staffAbsences,
    required this.publicStaffAbsences,
    required this.users,
    required this.clientPhotos,
    required this.clientQuestionnaireTemplates,
    required this.clientQuestionnaires,
  });

  factory AppDataState.initial() {
    return const AppDataState(
      salons: [],
      staff: [],
      staffRoles: [],
      clients: [],
      serviceCategories: [],
      services: [],
      packages: [],
      appointments: [],
      quotes: [],
      paymentTickets: [],
      inventoryItems: [],
      sales: [],
      cashFlowEntries: [],
      messageTemplates: [],
      reminderSettings: [],
      clientNotifications: [],
      shifts: [],
      staffAbsences: [],
      publicStaffAbsences: [],
      users: [],
      clientPhotos: [],
      clientQuestionnaireTemplates: [],
      clientQuestionnaires: [],
    );
  }

  final List<Salon> salons;
  final List<StaffMember> staff;
  final List<StaffRole> staffRoles;
  final List<Client> clients;
  final List<ServiceCategory> serviceCategories;
  final List<Service> services;
  final List<ServicePackage> packages;
  final List<Appointment> appointments;
  final List<Quote> quotes;
  final List<PaymentTicket> paymentTickets;
  final List<InventoryItem> inventoryItems;
  final List<Sale> sales;
  final List<CashFlowEntry> cashFlowEntries;
  final List<MessageTemplate> messageTemplates;
  final List<ReminderSettings> reminderSettings;
  final List<AppNotification> clientNotifications;
  final List<Shift> shifts;
  final List<StaffAbsence> staffAbsences;
  final List<StaffAbsence> publicStaffAbsences;
  final List<AppUser> users;
  final List<ClientPhoto> clientPhotos;
  final List<ClientQuestionnaireTemplate> clientQuestionnaireTemplates;
  final List<ClientQuestionnaire> clientQuestionnaires;

  AppDataState copyWith({
    List<Salon>? salons,
    List<StaffMember>? staff,
    List<StaffRole>? staffRoles,
    List<Client>? clients,
    List<ServiceCategory>? serviceCategories,
    List<Service>? services,
    List<ServicePackage>? packages,
    List<Appointment>? appointments,
    List<Quote>? quotes,
    List<PaymentTicket>? paymentTickets,
    List<InventoryItem>? inventoryItems,
    List<Sale>? sales,
    List<CashFlowEntry>? cashFlowEntries,
    List<MessageTemplate>? messageTemplates,
    List<ReminderSettings>? reminderSettings,
    List<AppNotification>? clientNotifications,
    List<Shift>? shifts,
    List<StaffAbsence>? staffAbsences,
    List<StaffAbsence>? publicStaffAbsences,
    List<AppUser>? users,
    List<ClientPhoto>? clientPhotos,
    List<ClientQuestionnaireTemplate>? clientQuestionnaireTemplates,
    List<ClientQuestionnaire>? clientQuestionnaires,
  }) {
    return AppDataState(
      salons: salons ?? this.salons,
      staff: staff ?? this.staff,
      staffRoles: staffRoles ?? this.staffRoles,
      clients: clients ?? this.clients,
      serviceCategories: serviceCategories ?? this.serviceCategories,
      services: services ?? this.services,
      packages: packages ?? this.packages,
      appointments: appointments ?? this.appointments,
      quotes: quotes ?? this.quotes,
      paymentTickets: paymentTickets ?? this.paymentTickets,
      inventoryItems: inventoryItems ?? this.inventoryItems,
      sales: sales ?? this.sales,
      cashFlowEntries: cashFlowEntries ?? this.cashFlowEntries,
      messageTemplates: messageTemplates ?? this.messageTemplates,
      reminderSettings: reminderSettings ?? this.reminderSettings,
      clientNotifications: clientNotifications ?? this.clientNotifications,
      shifts: shifts ?? this.shifts,
      staffAbsences: staffAbsences ?? this.staffAbsences,
      publicStaffAbsences: publicStaffAbsences ?? this.publicStaffAbsences,
      users: users ?? this.users,
      clientPhotos: clientPhotos ?? this.clientPhotos,
      clientQuestionnaireTemplates:
          clientQuestionnaireTemplates ?? this.clientQuestionnaireTemplates,
      clientQuestionnaires: clientQuestionnaires ?? this.clientQuestionnaires,
    );
  }
}
