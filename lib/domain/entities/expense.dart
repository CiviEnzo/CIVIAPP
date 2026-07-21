import 'package:you_book/domain/entities/sale.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.salonId,
    required this.name,
    this.description,
    this.color = 0xFF7C3AED,
    this.icon = 'receipt_long',
    this.reportGroup = ExpenseReportGroup.fixedCosts,
    this.monthlyBudget,
    this.defaultPaymentMethod,
    this.requiresAttachment = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String salonId;
  final String name;
  final String? description;
  final int color;
  final String icon;
  final ExpenseReportGroup reportGroup;
  final double? monthlyBudget;
  final PaymentMethod? defaultPaymentMethod;
  final bool requiresAttachment;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  ExpenseCategory copyWith({
    String? id,
    String? salonId,
    String? name,
    Object? description = _unset,
    int? color,
    String? icon,
    ExpenseReportGroup? reportGroup,
    Object? monthlyBudget = _unset,
    Object? defaultPaymentMethod = _unset,
    bool? requiresAttachment,
    bool? isActive,
    int? sortOrder,
    Object? createdAt = _unset,
    Object? createdBy = _unset,
    Object? updatedAt = _unset,
    Object? updatedBy = _unset,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      description:
          description == _unset ? this.description : description as String?,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      reportGroup: reportGroup ?? this.reportGroup,
      monthlyBudget:
          monthlyBudget == _unset
              ? this.monthlyBudget
              : monthlyBudget as double?,
      defaultPaymentMethod:
          defaultPaymentMethod == _unset
              ? this.defaultPaymentMethod
              : defaultPaymentMethod as PaymentMethod?,
      requiresAttachment: requiresAttachment ?? this.requiresAttachment,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
      createdBy: createdBy == _unset ? this.createdBy : createdBy as String?,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      updatedBy: updatedBy == _unset ? this.updatedBy : updatedBy as String?,
    );
  }
}

class Expense {
  Expense({
    required this.id,
    required this.salonId,
    required this.categoryId,
    required this.title,
    required this.totalAmount,
    required this.competenceDate,
    required this.dueDate,
    this.supplierName,
    this.amount,
    this.taxAmount = 0,
    this.currency = 'EUR',
    this.status = ExpenseStatus.toPay,
    List<ExpensePayment>? payments,
    this.notes,
    List<String>? tags,
    List<String>? attachmentUrls,
    this.isRecurring = false,
    this.recurrenceRuleId,
    this.occurrenceDate,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    this.deletedBy,
    this.deleteReason,
  }) : payments = List.unmodifiable(payments ?? const <ExpensePayment>[]),
       tags = List.unmodifiable(tags ?? const <String>[]),
       attachmentUrls = List.unmodifiable(attachmentUrls ?? const <String>[]);

  final String id;
  final String salonId;
  final String categoryId;
  final String title;
  final String? supplierName;
  final double? amount;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final DateTime competenceDate;
  final DateTime dueDate;
  final ExpenseStatus status;
  final List<ExpensePayment> payments;
  final String? notes;
  final List<String> tags;
  final List<String> attachmentUrls;
  final bool isRecurring;
  final String? recurrenceRuleId;
  final DateTime? occurrenceDate;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deleteReason;

  bool get isDeleted => deletedAt != null;
  bool get isCancelled => status == ExpenseStatus.cancelled;
  bool get isPayable => !isDeleted && !isCancelled;

  double get paidAmount {
    final sum = payments.fold<double>(0, (total, item) => total + item.amount);
    return _roundMoney(sum.clamp(0, totalAmount).toDouble());
  }

  double get outstandingAmount {
    final remaining = totalAmount - paidAmount;
    return remaining <= 0.01 ? 0 : _roundMoney(remaining);
  }

  DateTime? get lastPaymentDate {
    if (payments.isEmpty) {
      return null;
    }
    return payments
        .map((payment) => payment.date)
        .reduce((left, right) => left.isAfter(right) ? left : right);
  }

  ExpenseStatus get resolvedStatus {
    if (isCancelled) {
      return ExpenseStatus.cancelled;
    }
    if (paidAmount >= totalAmount && totalAmount > 0) {
      return ExpenseStatus.paid;
    }
    if (paidAmount > 0) {
      return ExpenseStatus.partial;
    }
    return ExpenseStatus.toPay;
  }

  bool isOverdue(DateTime now) {
    if (!isPayable || resolvedStatus == ExpenseStatus.paid) {
      return false;
    }
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.isBefore(today);
  }

  Expense copyWith({
    String? id,
    String? salonId,
    String? categoryId,
    String? title,
    Object? supplierName = _unset,
    Object? amount = _unset,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    DateTime? competenceDate,
    DateTime? dueDate,
    ExpenseStatus? status,
    List<ExpensePayment>? payments,
    Object? notes = _unset,
    List<String>? tags,
    List<String>? attachmentUrls,
    bool? isRecurring,
    Object? recurrenceRuleId = _unset,
    Object? occurrenceDate = _unset,
    Object? createdAt = _unset,
    Object? createdBy = _unset,
    Object? updatedAt = _unset,
    Object? updatedBy = _unset,
    Object? deletedAt = _unset,
    Object? deletedBy = _unset,
    Object? deleteReason = _unset,
  }) {
    return Expense(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      supplierName:
          supplierName == _unset ? this.supplierName : supplierName as String?,
      amount: amount == _unset ? this.amount : amount as double?,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      competenceDate: competenceDate ?? this.competenceDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      payments: payments ?? this.payments,
      notes: notes == _unset ? this.notes : notes as String?,
      tags: tags ?? this.tags,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRuleId:
          recurrenceRuleId == _unset
              ? this.recurrenceRuleId
              : recurrenceRuleId as String?,
      occurrenceDate:
          occurrenceDate == _unset
              ? this.occurrenceDate
              : occurrenceDate as DateTime?,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
      createdBy: createdBy == _unset ? this.createdBy : createdBy as String?,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      updatedBy: updatedBy == _unset ? this.updatedBy : updatedBy as String?,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
      deletedBy: deletedBy == _unset ? this.deletedBy : deletedBy as String?,
      deleteReason:
          deleteReason == _unset ? this.deleteReason : deleteReason as String?,
    );
  }
}

class ExpensePayment {
  const ExpensePayment({
    required this.id,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.recordedBy,
    this.note,
  });

  final String id;
  final double amount;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? recordedBy;
  final String? note;

  ExpensePayment copyWith({
    String? id,
    double? amount,
    DateTime? date,
    PaymentMethod? paymentMethod,
    Object? recordedBy = _unset,
    Object? note = _unset,
  }) {
    return ExpensePayment(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      recordedBy:
          recordedBy == _unset ? this.recordedBy : recordedBy as String?,
      note: note == _unset ? this.note : note as String?,
    );
  }
}

class ExpenseRecurringRule {
  ExpenseRecurringRule({
    required this.id,
    required this.salonId,
    required this.categoryId,
    required this.title,
    required this.totalAmount,
    required this.frequency,
    required this.startDate,
    this.supplierName,
    this.amount,
    this.taxAmount = 0,
    this.currency = 'EUR',
    int interval = 1,
    this.endDate,
    this.dueDay,
    this.defaultPaymentMethod,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.cancelledAt,
    this.cancelledBy,
  }) : interval = interval <= 0 ? 1 : interval;

  final String id;
  final String salonId;
  final String categoryId;
  final String title;
  final String? supplierName;
  final double? amount;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final ExpenseRecurrenceFrequency frequency;
  final int interval;
  final DateTime startDate;
  final DateTime? endDate;
  final int? dueDay;
  final PaymentMethod? defaultPaymentMethod;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  bool get isCancelled => cancelledAt != null || !isActive;

  ExpenseRecurringRule copyWith({
    String? id,
    String? salonId,
    String? categoryId,
    String? title,
    Object? supplierName = _unset,
    Object? amount = _unset,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    ExpenseRecurrenceFrequency? frequency,
    int? interval,
    DateTime? startDate,
    Object? endDate = _unset,
    Object? dueDay = _unset,
    Object? defaultPaymentMethod = _unset,
    Object? notes = _unset,
    bool? isActive,
    Object? createdAt = _unset,
    Object? createdBy = _unset,
    Object? updatedAt = _unset,
    Object? updatedBy = _unset,
    Object? cancelledAt = _unset,
    Object? cancelledBy = _unset,
  }) {
    return ExpenseRecurringRule(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      supplierName:
          supplierName == _unset ? this.supplierName : supplierName as String?,
      amount: amount == _unset ? this.amount : amount as double?,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      dueDay: dueDay == _unset ? this.dueDay : dueDay as int?,
      defaultPaymentMethod:
          defaultPaymentMethod == _unset
              ? this.defaultPaymentMethod
              : defaultPaymentMethod as PaymentMethod?,
      notes: notes == _unset ? this.notes : notes as String?,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime?,
      createdBy: createdBy == _unset ? this.createdBy : createdBy as String?,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      updatedBy: updatedBy == _unset ? this.updatedBy : updatedBy as String?,
      cancelledAt:
          cancelledAt == _unset ? this.cancelledAt : cancelledAt as DateTime?,
      cancelledBy:
          cancelledBy == _unset ? this.cancelledBy : cancelledBy as String?,
    );
  }
}

class ExpenseSettings {
  const ExpenseSettings({
    required this.salonId,
    this.showExpensesInAgenda = false,
    this.agendaIndicatorMode = 'icon_with_count',
    this.upcomingWarningDays = 7,
    this.updatedAt,
    this.updatedBy,
  });

  final String salonId;
  final bool showExpensesInAgenda;
  final String agendaIndicatorMode;
  final int upcomingWarningDays;
  final DateTime? updatedAt;
  final String? updatedBy;

  ExpenseSettings copyWith({
    String? salonId,
    bool? showExpensesInAgenda,
    String? agendaIndicatorMode,
    int? upcomingWarningDays,
    Object? updatedAt = _unset,
    Object? updatedBy = _unset,
  }) {
    return ExpenseSettings(
      salonId: salonId ?? this.salonId,
      showExpensesInAgenda: showExpensesInAgenda ?? this.showExpensesInAgenda,
      agendaIndicatorMode: agendaIndicatorMode ?? this.agendaIndicatorMode,
      upcomingWarningDays: upcomingWarningDays ?? this.upcomingWarningDays,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      updatedBy: updatedBy == _unset ? this.updatedBy : updatedBy as String?,
    );
  }
}

enum ExpenseStatus { toPay, partial, paid, cancelled }

extension ExpenseStatusX on ExpenseStatus {
  String get label {
    switch (this) {
      case ExpenseStatus.toPay:
        return 'Da pagare';
      case ExpenseStatus.partial:
        return 'Parziale';
      case ExpenseStatus.paid:
        return 'Pagata';
      case ExpenseStatus.cancelled:
        return 'Annullata';
    }
  }
}

enum ExpenseReportGroup {
  fixedCosts,
  variableCosts,
  staff,
  tax,
  marketing,
  inventory,
  maintenance,
  other,
}

extension ExpenseReportGroupX on ExpenseReportGroup {
  String get label {
    switch (this) {
      case ExpenseReportGroup.fixedCosts:
        return 'Costi fissi';
      case ExpenseReportGroup.variableCosts:
        return 'Costi variabili';
      case ExpenseReportGroup.staff:
        return 'Personale';
      case ExpenseReportGroup.tax:
        return 'Fiscale';
      case ExpenseReportGroup.marketing:
        return 'Marketing';
      case ExpenseReportGroup.inventory:
        return 'Magazzino';
      case ExpenseReportGroup.maintenance:
        return 'Manutenzione';
      case ExpenseReportGroup.other:
        return 'Altro';
    }
  }
}

enum ExpenseRecurrenceFrequency {
  weekly,
  monthly,
  quarterly,
  semiannual,
  yearly,
}

extension ExpenseRecurrenceFrequencyX on ExpenseRecurrenceFrequency {
  String get label {
    switch (this) {
      case ExpenseRecurrenceFrequency.weekly:
        return 'Settimanale';
      case ExpenseRecurrenceFrequency.monthly:
        return 'Mensile';
      case ExpenseRecurrenceFrequency.quarterly:
        return 'Trimestrale';
      case ExpenseRecurrenceFrequency.semiannual:
        return 'Semestrale';
      case ExpenseRecurrenceFrequency.yearly:
        return 'Annuale';
    }
  }

  int get monthStep {
    switch (this) {
      case ExpenseRecurrenceFrequency.weekly:
        return 0;
      case ExpenseRecurrenceFrequency.monthly:
        return 1;
      case ExpenseRecurrenceFrequency.quarterly:
        return 3;
      case ExpenseRecurrenceFrequency.semiannual:
        return 6;
      case ExpenseRecurrenceFrequency.yearly:
        return 12;
    }
  }
}

double _roundMoney(double value) => double.parse(value.toStringAsFixed(2));

const Object _unset = Object();
