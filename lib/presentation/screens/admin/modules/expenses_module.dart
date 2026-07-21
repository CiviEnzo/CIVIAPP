import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/expense.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/modules/expenses/expense_agenda_preferences.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';

enum _ExpensesTab { dashboard, list, recurring, calendar, settings }

extension _ExpensesTabX on _ExpensesTab {
  String get label {
    switch (this) {
      case _ExpensesTab.dashboard:
        return 'Dashboard';
      case _ExpensesTab.list:
        return 'Uscite';
      case _ExpensesTab.recurring:
        return 'Ricorrenti';
      case _ExpensesTab.calendar:
        return 'Calendario';
      case _ExpensesTab.settings:
        return 'Config';
    }
  }

  IconData get icon {
    switch (this) {
      case _ExpensesTab.dashboard:
        return Icons.space_dashboard_outlined;
      case _ExpensesTab.list:
        return Icons.receipt_long_outlined;
      case _ExpensesTab.recurring:
        return Icons.repeat_rounded;
      case _ExpensesTab.calendar:
        return Icons.calendar_month_outlined;
      case _ExpensesTab.settings:
        return Icons.tune_rounded;
    }
  }
}

class ExpensesModule extends ConsumerStatefulWidget {
  const ExpensesModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<ExpensesModule> createState() => _ExpensesModuleState();
}

class _ExpensesModuleState extends ConsumerState<ExpensesModule> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currency = NumberFormat.simpleCurrency(locale: 'it_IT');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'it_IT');
  final DateFormat _monthFormat = DateFormat('MMMM yyyy', 'it_IT');
  _ExpensesTab _activeTab = _ExpensesTab.dashboard;
  ExpenseStatus? _statusFilter;
  String? _categoryFilterId;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _searchQuery = '';
  bool _personalAgendaPreference = true;
  bool _personalPreferenceReady = false;

  @override
  void initState() {
    super.initState();
    _restorePersonalAgendaPreference();
  }

  @override
  void didUpdateWidget(covariant ExpensesModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salonId != widget.salonId) {
      _personalPreferenceReady = false;
      _restorePersonalAgendaPreference();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restorePersonalAgendaPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(
        expenseAgendaUserPreferenceKey(widget.salonId),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _personalAgendaPreference = value ?? true;
        _personalPreferenceReady = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _personalPreferenceReady = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final effectiveSalonId =
        widget.salonId ?? (salons.length == 1 ? salons.first.id : null);
    final categories =
        data.expenseCategories
            .where(
              (category) =>
                  effectiveSalonId == null ||
                  category.salonId == effectiveSalonId,
            )
            .toList();
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final expenses =
        data.expenses
            .where(
              (expense) =>
                  effectiveSalonId == null ||
                  expense.salonId == effectiveSalonId,
            )
            .where((expense) => !expense.isDeleted)
            .toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final visibleExpenses = _filterExpenses(expenses);
    final recurringRules =
        data.expenseRecurringRules
            .where(
              (rule) =>
                  effectiveSalonId == null || rule.salonId == effectiveSalonId,
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final settings = _settingsForSalon(effectiveSalonId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(
          context,
          salons: salons,
          categories: categories,
          effectiveSalonId: effectiveSalonId,
        ),
        const SizedBox(height: 12),
        _buildTabs(context),
        const SizedBox(height: 14),
        switch (_activeTab) {
          _ExpensesTab.dashboard => _buildDashboard(
            context,
            expenses: expenses,
            recurringRules: recurringRules,
            categoryById: categoryById,
          ),
          _ExpensesTab.list => _buildListTab(
            context,
            salons: salons,
            categories: categories,
            expenses: visibleExpenses,
            categoryById: categoryById,
            effectiveSalonId: effectiveSalonId,
          ),
          _ExpensesTab.recurring => _buildRecurringTab(
            context,
            salons: salons,
            categories: categories,
            rules: recurringRules,
            categoryById: categoryById,
            effectiveSalonId: effectiveSalonId,
          ),
          _ExpensesTab.calendar => _buildCalendarTab(
            context,
            expenses: expenses,
            categoryById: categoryById,
          ),
          _ExpensesTab.settings => _buildSettingsTab(
            context,
            salons: salons,
            categories: categories,
            settings: settings,
            effectiveSalonId: effectiveSalonId,
          ),
        },
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required List<Salon> salons,
    required List<ExpenseCategory> categories,
    required String? effectiveSalonId,
  }) {
    final newExpenseAction = FilledButton.icon(
      onPressed:
          categories.where((category) => category.isActive).isEmpty
              ? null
              : () => _openExpenseForm(
                context,
                salons: salons,
                categories: categories,
                defaultSalonId: effectiveSalonId,
              ),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nuova uscita'),
    );
    final newRecurringAction = OutlinedButton.icon(
      onPressed:
          categories.where((category) => category.isActive).isEmpty
              ? null
              : () => _openRecurringForm(
                context,
                salons: salons,
                categories: categories,
                defaultSalonId: effectiveSalonId,
              ),
      icon: const Icon(Icons.repeat_rounded),
      label: const Text('Nuova ricorrente'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < kAdminPhoneBreakpoint;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              newExpenseAction,
              const SizedBox(height: 8),
              newRecurringAction,
            ],
          );
        }
        return Row(
          children: [
            const Spacer(),
            newRecurringAction,
            const SizedBox(width: 8),
            newExpenseAction,
          ],
        );
      },
    );
  }

  Widget _buildTabs(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_ExpensesTab>(
        selected: {_activeTab},
        onSelectionChanged:
            (selection) => setState(() => _activeTab = selection.first),
        segments:
            _ExpensesTab.values
                .map(
                  (tab) => ButtonSegment<_ExpensesTab>(
                    value: tab,
                    icon: Icon(tab.icon),
                    label: Text(tab.label),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context, {
    required List<Expense> expenses,
    required List<ExpenseRecurringRule> recurringRules,
    required Map<String, ExpenseCategory> categoryById,
  }) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final monthExpenses =
        expenses
            .where((expense) => expense.isPayable)
            .where(
              (expense) =>
                  !expense.competenceDate.isBefore(monthStart) &&
                  !expense.competenceDate.isAfter(monthEnd),
            )
            .toList();
    final total = monthExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.totalAmount,
    );
    final paid = monthExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.paidAmount,
    );
    final unpaid = monthExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.outstandingAmount,
    );
    final overdue =
        expenses.where((expense) => expense.isOverdue(now)).toList();
    final activeRecurring =
        recurringRules.where((rule) => !rule.isCancelled).length;
    final upcoming =
        expenses
            .where((expense) => expense.isPayable)
            .where((expense) => expense.resolvedStatus != ExpenseStatus.paid)
            .where(
              (expense) => expense.dueDate.isAfter(
                now.subtract(const Duration(days: 1)),
              ),
            )
            .take(5)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 1100
                    ? 4
                    : constraints.maxWidth >= kAdminTwoColumnBreakpoint
                    ? 2
                    : 1;
            final width =
                columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - (10 * (columns - 1))) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(width, 'Uscite mese', _currency.format(total)),
                _metric(width, 'Pagato', _currency.format(paid)),
                _metric(width, 'Da pagare', _currency.format(unpaid)),
                _metric(
                  width,
                  'Scadute',
                  '${overdue.length}',
                  valueColor: overdue.isEmpty ? null : const Color(0xFFB3261E),
                  subtitle: _currency.format(
                    overdue.fold<double>(
                      0,
                      (sum, expense) => sum + expense.outstandingAmount,
                    ),
                  ),
                ),
                _metric(width, 'Ricorrenti attive', '$activeRecurring'),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Prossime scadenze',
          child:
              upcoming.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nessuna uscita in scadenza.'),
                  )
                  : Column(
                    children: [
                      for (final expense in upcoming)
                        _ExpenseMiniTile(
                          expense: expense,
                          category: categoryById[expense.categoryId],
                          currency: _currency,
                          dateFormat: _dateFormat,
                          onTap:
                              () => _showExpenseDetails(expense, categoryById),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildListTab(
    BuildContext context, {
    required List<Salon> salons,
    required List<ExpenseCategory> categories,
    required List<Expense> expenses,
    required Map<String, ExpenseCategory> categoryById,
    required String? effectiveSalonId,
  }) {
    return Column(
      children: [
        AdminResponsiveToolbar(
          primary: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Cerca titolo, fornitore o note...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          secondary: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<ExpenseStatus?>(
                value: _statusFilter,
                hint: const Text('Stato'),
                items: [
                  const DropdownMenuItem<ExpenseStatus?>(
                    value: null,
                    child: Text('Tutti gli stati'),
                  ),
                  ...ExpenseStatus.values.map(
                    (status) => DropdownMenuItem<ExpenseStatus?>(
                      value: status,
                      child: Text(status.label),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _statusFilter = value),
              ),
              DropdownButton<String?>(
                value: _categoryFilterId,
                hint: const Text('Voce'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tutte le voci'),
                  ),
                  ...categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _categoryFilterId = value),
              ),
            ],
          ),
          secondaryFullWidthOnStack: true,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Uscite registrate',
          trailing: Text('${expenses.length} risultati'),
          child:
              expenses.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Nessuna uscita trovata.'),
                  )
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 780) {
                        return Column(
                          children: [
                            for (final expense in expenses)
                              _ExpenseMobileCard(
                                expense: expense,
                                category: categoryById[expense.categoryId],
                                currency: _currency,
                                dateFormat: _dateFormat,
                                onPay: () => _openPaymentDialog(expense),
                                onEdit:
                                    () => _openExpenseForm(
                                      context,
                                      salons: salons,
                                      categories: categories,
                                      defaultSalonId: effectiveSalonId,
                                      existing: expense,
                                    ),
                                onDelete: () => _confirmDeleteExpense(expense),
                              ),
                          ],
                        );
                      }
                      return _ExpenseDesktopTable(
                        expenses: expenses,
                        categoryById: categoryById,
                        currency: _currency,
                        dateFormat: _dateFormat,
                        onPay: _openPaymentDialog,
                        onEdit:
                            (expense) => _openExpenseForm(
                              context,
                              salons: salons,
                              categories: categories,
                              defaultSalonId: effectiveSalonId,
                              existing: expense,
                            ),
                        onDelete: _confirmDeleteExpense,
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildRecurringTab(
    BuildContext context, {
    required List<Salon> salons,
    required List<ExpenseCategory> categories,
    required List<ExpenseRecurringRule> rules,
    required Map<String, ExpenseCategory> categoryById,
    required String? effectiveSalonId,
  }) {
    return _SectionCard(
      title: 'Uscite ricorrenti',
      trailing: OutlinedButton.icon(
        onPressed:
            categories.where((category) => category.isActive).isEmpty
                ? null
                : () => _openRecurringForm(
                  context,
                  salons: salons,
                  categories: categories,
                  defaultSalonId: effectiveSalonId,
                ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ricorrente'),
      ),
      child:
          rules.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Nessuna ricorrenza configurata.'),
              )
              : Column(
                children: [
                  for (final rule in rules)
                    ListTile(
                      leading: Icon(
                        rule.isCancelled
                            ? Icons.pause_circle_outline
                            : Icons.repeat_rounded,
                      ),
                      title: Text(rule.title),
                      subtitle: Text(
                        '${categoryById[rule.categoryId]?.name ?? 'Senza voce'} - ${rule.frequency.label} - dal ${_dateFormat.format(rule.startDate)}',
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(_currency.format(rule.totalAmount)),
                          IconButton(
                            tooltip: 'Modifica',
                            onPressed:
                                () => _openRecurringForm(
                                  context,
                                  salons: salons,
                                  categories: categories,
                                  defaultSalonId: effectiveSalonId,
                                  existing: rule,
                                ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Annulla ricorrenza',
                            onPressed:
                                rule.isCancelled
                                    ? null
                                    : () => _confirmCancelRecurring(rule),
                            icon: const Icon(Icons.cancel_outlined),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  Widget _buildCalendarTab(
    BuildContext context, {
    required List<Expense> expenses,
    required Map<String, ExpenseCategory> categoryById,
  }) {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month);
    final firstGridDay = firstDay.subtract(
      Duration(days: firstDay.weekday - 1),
    );
    final days = List<DateTime>.generate(
      42,
      (index) => firstGridDay.add(Duration(days: index)),
    );
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in expenses.where((expense) => expense.isPayable)) {
      final day = DateUtils.dateOnly(expense.dueDate);
      grouped.putIfAbsent(day, () => <Expense>[]).add(expense);
    }

    return _SectionCard(
      title: _capitalize(_monthFormat.format(_calendarMonth)),
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: 'Mese precedente',
            onPressed:
                () => setState(
                  () =>
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month - 1,
                      ),
                ),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Mese successivo',
            onPressed:
                () => setState(
                  () =>
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month + 1,
                      ),
                ),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;
          return Wrap(
            children: [
              for (final label in const [
                'Lun',
                'Mar',
                'Mer',
                'Gio',
                'Ven',
                'Sab',
                'Dom',
              ])
                SizedBox(
                  width: cellWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              for (final day in days)
                SizedBox(
                  width: cellWidth,
                  height: 132,
                  child: _ExpenseCalendarDay(
                    day: day,
                    currentMonth: _calendarMonth.month,
                    expenses: grouped[DateUtils.dateOnly(day)] ?? const [],
                    categoryById: categoryById,
                    currency: _currency,
                    onAdd: () => _openExpenseFormForDate(day),
                    onOpen:
                        (expense) => _showExpenseDetails(expense, categoryById),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsTab(
    BuildContext context, {
    required List<Salon> salons,
    required List<ExpenseCategory> categories,
    required ExpenseSettings? settings,
    required String? effectiveSalonId,
  }) {
    return Column(
      children: [
        _SectionCard(
          title: 'Agenda',
          child: Column(
            children: [
              SwitchListTile(
                value: settings?.showExpensesInAgenda ?? false,
                onChanged:
                    effectiveSalonId == null
                        ? null
                        : (value) => _setSalonAgendaSetting(
                          effectiveSalonId,
                          value,
                          settings,
                        ),
                title: const Text('Mostra uscite in agenda per il salone'),
                subtitle: const Text(
                  'Abilita il conteggio giornaliero delle uscite nel calendario admin.',
                ),
              ),
              SwitchListTile(
                value: _personalAgendaPreference,
                onChanged:
                    !_personalPreferenceReady
                        ? null
                        : (value) => _setPersonalAgendaPreference(value),
                title: const Text('La mia preferenza agenda'),
                subtitle: const Text(
                  'Mostra l\'icona delle uscite nella mia agenda admin.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Voci di uscita',
          trailing: OutlinedButton.icon(
            onPressed:
                effectiveSalonId == null
                    ? null
                    : () => _openCategoryForm(
                      context,
                      salons: salons,
                      defaultSalonId: effectiveSalonId,
                    ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Voce'),
          ),
          child:
              categories.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Crea una voce di uscita per iniziare.'),
                  )
                  : Column(
                    children: [
                      for (final category in categories)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(category.color),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          title: Text(category.name),
                          subtitle: Text(category.reportGroup.label),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!category.isActive)
                                const Chip(label: Text('Disattivata')),
                              IconButton(
                                tooltip: 'Modifica voce',
                                onPressed:
                                    () => _openCategoryForm(
                                      context,
                                      salons: salons,
                                      defaultSalonId: effectiveSalonId,
                                      existing: category,
                                    ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    final query = _searchQuery.trim().toLowerCase();
    return expenses
        .where((expense) {
          if (_statusFilter != null &&
              expense.resolvedStatus != _statusFilter) {
            return false;
          }
          if (_categoryFilterId != null &&
              expense.categoryId != _categoryFilterId) {
            return false;
          }
          if (query.isNotEmpty) {
            final haystack =
                [
                  expense.title,
                  expense.supplierName ?? '',
                  expense.notes ?? '',
                  ...expense.tags,
                ].join(' ').toLowerCase();
            if (!haystack.contains(query)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  ExpenseSettings? _settingsForSalon(String? salonId) {
    if (salonId == null) {
      return null;
    }
    return ref
        .watch(appDataProvider)
        .expenseSettings
        .firstWhereOrNull((item) => item.salonId == salonId);
  }

  Widget _metric(
    double width,
    String label,
    String value, {
    Color? valueColor,
    String? subtitle,
  }) {
    return SizedBox(
      width: width,
      child: _MetricCard(
        label: label,
        value: value,
        valueColor: valueColor,
        subtitle: subtitle,
      ),
    );
  }

  Future<void> _openExpenseFormForDate(DateTime day) async {
    final data = ref.read(appDataProvider);
    await _openExpenseForm(
      context,
      salons: data.salons,
      categories: data.expenseCategories,
      defaultSalonId: widget.salonId,
      initialDate: day,
    );
  }

  Future<void> _openExpenseForm(
    BuildContext context, {
    required List<Salon> salons,
    required List<ExpenseCategory> categories,
    required String? defaultSalonId,
    Expense? existing,
    DateTime? initialDate,
  }) async {
    final result = await showAppModalSheet<Expense>(
      context: context,
      barrierDismissible: true,
      includeCloseButton: false,
      builder:
          (_) => _ExpenseFormSheet(
            salons: salons,
            categories: categories,
            defaultSalonId: defaultSalonId,
            existing: existing,
            initialDate: initialDate,
            currentUserId: ref.read(appDataProvider.notifier).currentUser?.uid,
          ),
    );
    if (result == null) {
      return;
    }
    await ref.read(appDataProvider.notifier).upsertExpense(result);
  }

  Future<void> _openCategoryForm(
    BuildContext context, {
    required List<Salon> salons,
    required String? defaultSalonId,
    ExpenseCategory? existing,
  }) async {
    final result = await showAppModalSheet<ExpenseCategory>(
      context: context,
      barrierDismissible: true,
      includeCloseButton: false,
      builder:
          (_) => _ExpenseCategoryFormSheet(
            salons: salons,
            defaultSalonId: defaultSalonId,
            existing: existing,
            currentUserId: ref.read(appDataProvider.notifier).currentUser?.uid,
          ),
    );
    if (result == null) {
      return;
    }
    await ref.read(appDataProvider.notifier).upsertExpenseCategory(result);
  }

  Future<void> _openRecurringForm(
    BuildContext context, {
    required List<Salon> salons,
    required List<ExpenseCategory> categories,
    required String? defaultSalonId,
    ExpenseRecurringRule? existing,
  }) async {
    final result = await showAppModalSheet<ExpenseRecurringRule>(
      context: context,
      barrierDismissible: true,
      includeCloseButton: false,
      builder:
          (_) => _ExpenseRecurringFormSheet(
            salons: salons,
            categories: categories,
            defaultSalonId: defaultSalonId,
            existing: existing,
            currentUserId: ref.read(appDataProvider.notifier).currentUser?.uid,
          ),
    );
    if (result == null) {
      return;
    }
    await ref
        .read(appDataProvider.notifier)
        .upsertExpenseRecurringRule(result, generateOccurrences: true);
  }

  Future<void> _openPaymentDialog(Expense expense) async {
    final data = ref.read(appDataProvider);
    final category = data.expenseCategories.firstWhereOrNull(
      (item) => item.id == expense.categoryId,
    );
    final recurringRule = data.expenseRecurringRules.firstWhereOrNull(
      (item) => item.id == expense.recurrenceRuleId,
    );
    final payment = await showAppModalSheet<ExpensePayment>(
      context: context,
      barrierDismissible: true,
      includeCloseButton: false,
      preset: AppModalSheetPreset.compact,
      builder:
          (_) => _ExpensePaymentSheet(
            expense: expense,
            initialMethod:
                category?.defaultPaymentMethod ??
                recurringRule?.defaultPaymentMethod,
            currentUserId: ref.read(appDataProvider.notifier).currentUser?.uid,
          ),
    );
    if (payment == null) {
      return;
    }
    final updated = expense.copyWith(
      payments: [...expense.payments, payment],
      updatedAt: DateTime.now(),
      updatedBy: ref.read(appDataProvider.notifier).currentUser?.uid,
    );
    await ref.read(appDataProvider.notifier).upsertExpense(updated);
  }

  Future<void> _confirmDeleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Cancellare uscita?'),
            content: Text(
              'L\'uscita "${expense.title}" verra esclusa da calendario, agenda e report.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cancella'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(appDataProvider.notifier)
        .softDeleteExpense(expense.id, reason: 'Cancellata da admin');
  }

  Future<void> _confirmCancelRecurring(ExpenseRecurringRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Annullare ricorrenza?'),
            content: Text(
              'La ricorrenza "${rule.title}" non generera nuove uscite. Le uscite future non pagate verranno annullate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Indietro'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Annulla ricorrenza'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(appDataProvider.notifier)
        .cancelExpenseRecurringRule(rule.id, deleteFutureOccurrences: true);
  }

  Future<void> _setSalonAgendaSetting(
    String salonId,
    bool value,
    ExpenseSettings? current,
  ) async {
    final now = DateTime.now();
    final updated = (current ?? ExpenseSettings(salonId: salonId)).copyWith(
      showExpensesInAgenda: value,
      updatedAt: now,
      updatedBy: ref.read(appDataProvider.notifier).currentUser?.uid,
    );
    await ref.read(appDataProvider.notifier).upsertExpenseSettings(updated);
  }

  Future<void> _setPersonalAgendaPreference(bool value) async {
    setState(() => _personalAgendaPreference = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(expenseAgendaUserPreferenceKey(widget.salonId), value);
  }

  void _showExpenseDetails(
    Expense expense,
    Map<String, ExpenseCategory> categoryById,
  ) {
    final data = ref.read(appDataProvider);
    final canRegisterPayment =
        expense.isPayable && expense.outstandingAmount > 0;
    final canEditOccurrence = !expense.isDeleted && !expense.isCancelled;

    Future<void> closeAndRun(
      BuildContext sheetContext,
      Future<void> Function() action,
    ) async {
      Navigator.of(sheetContext).pop();
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      await action();
    }

    showAppModalSheet<void>(
      context: context,
      barrierDismissible: true,
      includeCloseButton: false,
      preset: AppModalSheetPreset.compact,
      builder:
          (sheetContext) => SizedBox(
            width: isAppSheetPhoneLayout(context) ? double.infinity : 560,
            child: DialogActionLayout(
              title: 'Dettaglio uscita',
              subtitle: expense.title,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PaymentSummaryPanel(expense: expense, currency: _currency),
                  const SizedBox(height: 14),
                  _SheetSection(
                    title: 'Informazioni',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        _detailRow(
                          'Voce',
                          categoryById[expense.categoryId]?.name ??
                              'Senza voce',
                        ),
                        _detailRow(
                          'Scadenza',
                          _dateFormat.format(expense.dueDate),
                        ),
                        if (expense.supplierName != null)
                          _detailRow('Fornitore', expense.supplierName!),
                      ],
                    ),
                  ),
                  if (expense.payments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SheetSection(
                      title: 'Pagamenti',
                      icon: Icons.payments_outlined,
                      child: Column(
                        children: [
                          for (final payment in expense.payments)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_currency.format(payment.amount)),
                              subtitle: Text(
                                '${_dateFormat.format(payment.date)} - ${payment.paymentMethod.label}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (canRegisterPayment)
                  OutlinedButton.icon(
                    onPressed:
                        () => closeAndRun(
                          sheetContext,
                          () => _openPaymentDialog(expense),
                        ),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Registra pagamento'),
                  ),
                if (canEditOccurrence)
                  FilledButton.icon(
                    onPressed:
                        () => closeAndRun(
                          sheetContext,
                          () => _openExpenseForm(
                            context,
                            salons: data.salons,
                            categories: data.expenseCategories,
                            defaultSalonId: expense.salonId,
                            existing: expense,
                          ),
                        ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifica'),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.subtitle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ExpenseDesktopTable extends StatelessWidget {
  const _ExpenseDesktopTable({
    required this.expenses,
    required this.categoryById,
    required this.currency,
    required this.dateFormat,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Expense> expenses;
  final Map<String, ExpenseCategory> categoryById;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final ValueChanged<Expense> onPay;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.42,
          ),
          child: _ExpenseDesktopColumns(
            title: Text('Uscita', style: theme.textTheme.labelLarge),
            category: Text('Voce', style: theme.textTheme.labelLarge),
            dueDate: Text('Scadenza', style: theme.textTheme.labelLarge),
            amount: Text('Importo', style: theme.textTheme.labelLarge),
            payment: Text('Pagamento', style: theme.textTheme.labelLarge),
            status: Text('Stato', style: theme.textTheme.labelLarge),
            actions: Align(
              alignment: Alignment.centerRight,
              child: Text('Azioni', style: theme.textTheme.labelLarge),
            ),
          ),
        ),
        for (final expense in expenses)
          _ExpenseDesktopRow(
            expense: expense,
            category: categoryById[expense.categoryId],
            currency: currency,
            dateFormat: dateFormat,
            onPay: () => onPay(expense),
            onEdit: () => onEdit(expense),
            onDelete: () => onDelete(expense),
          ),
      ],
    );
  }
}

class _ExpenseDesktopRow extends StatelessWidget {
  const _ExpenseDesktopRow({
    required this.expense,
    required this.category,
    required this.currency,
    required this.dateFormat,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final ExpenseCategory? category;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _expenseStatusTone(expense);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.035),
        border: Border(
          top: BorderSide(color: theme.dividerColor),
          left: BorderSide(color: tone.color, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _ExpenseDesktopColumns(
          title: _ExpenseTitleCell(expense: expense),
          category: _CategoryPill(category: category),
          dueDate: Text(dateFormat.format(expense.dueDate)),
          amount: Text(
            currency.format(expense.totalAmount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          payment: _ExpensePaymentProgress(
            expense: expense,
            currency: currency,
          ),
          status: Align(
            alignment: Alignment.centerLeft,
            child: _ExpenseStatusChip(expense: expense),
          ),
          actions: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RowActionButton(
                  tooltip: 'Registra pagamento',
                  icon: Icons.payments_outlined,
                  onPressed: expense.outstandingAmount <= 0 ? null : onPay,
                ),
                _RowActionButton(
                  tooltip: 'Modifica',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
                _RowActionButton(
                  tooltip: 'Cancella',
                  icon: Icons.delete_outline,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseDesktopColumns extends StatelessWidget {
  const _ExpenseDesktopColumns({
    required this.title,
    required this.category,
    required this.dueDate,
    required this.amount,
    required this.payment,
    required this.status,
    required this.actions,
  });

  final Widget title;
  final Widget category;
  final Widget dueDate;
  final Widget amount;
  final Widget payment;
  final Widget status;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 22, child: title),
        const SizedBox(width: 12),
        Expanded(flex: 14, child: category),
        const SizedBox(width: 12),
        Expanded(flex: 11, child: dueDate),
        const SizedBox(width: 12),
        Expanded(flex: 10, child: amount),
        const SizedBox(width: 12),
        Expanded(flex: 18, child: payment),
        const SizedBox(width: 12),
        Expanded(flex: 11, child: status),
        const SizedBox(width: 12),
        SizedBox(width: 132, child: actions),
      ],
    );
  }
}

class _ExpenseTitleCell extends StatelessWidget {
  const _ExpenseTitleCell({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (expense.supplierName != null)
          Text(
            expense.supplierName!,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final ExpenseCategory? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(category?.color ?? 0xFF475569);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          category?.name ?? 'Senza voce',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ExpensePaymentProgress extends StatelessWidget {
  const _ExpensePaymentProgress({
    required this.expense,
    required this.currency,
  });

  final Expense expense;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _expenseStatusTone(expense);
    final ratio =
        expense.totalAmount <= 0
            ? 0.0
            : (expense.paidAmount / expense.totalAmount).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${currency.format(expense.paidAmount)} / ${currency.format(expense.totalAmount)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: ratio,
            valueColor: AlwaysStoppedAnimation<Color>(tone.color),
            backgroundColor: tone.background,
          ),
        ),
      ],
    );
  }
}

class _RowActionButton extends StatelessWidget {
  const _RowActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FormFieldGrid extends StatelessWidget {
  const _FormFieldGrid({required this.children, this.minFieldWidth = 240});

  final List<Widget> children;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= minFieldWidth * 2 + 12 ? 2 : 1;
        final width =
            columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _PaymentSummaryPanel extends StatelessWidget {
  const _PaymentSummaryPanel({required this.expense, required this.currency});

  final Expense expense;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            expense.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _FormFieldGrid(
            minFieldWidth: 150,
            children: [
              _SummaryAmount(
                label: 'Totale',
                value: currency.format(expense.totalAmount),
              ),
              _SummaryAmount(
                label: 'Pagato',
                value: currency.format(expense.paidAmount),
              ),
              _SummaryAmount(
                label: 'Residuo',
                value: currency.format(expense.outstandingAmount),
                emphasized: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasized ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _ExpenseStatusTone {
  const _ExpenseStatusTone({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  Color get background => color.withValues(alpha: 0.10);
  Color get strongBackground => color.withValues(alpha: 0.16);
  Color get border => color.withValues(alpha: 0.32);
}

_ExpenseStatusTone _expenseStatusTone(Expense expense) {
  if (expense.isOverdue(DateTime.now())) {
    return const _ExpenseStatusTone(
      label: 'Scaduta',
      color: Color(0xFFB3261E),
      icon: Icons.error_outline_rounded,
    );
  }
  switch (expense.resolvedStatus) {
    case ExpenseStatus.paid:
      return const _ExpenseStatusTone(
        label: 'Pagata',
        color: Color(0xFF0F766E),
        icon: Icons.check_circle_outline_rounded,
      );
    case ExpenseStatus.partial:
      return const _ExpenseStatusTone(
        label: 'Parziale',
        color: Color(0xFF2563EB),
        icon: Icons.pending_actions_outlined,
      );
    case ExpenseStatus.cancelled:
      return const _ExpenseStatusTone(
        label: 'Annullata',
        color: Color(0xFF64748B),
        icon: Icons.block_outlined,
      );
    case ExpenseStatus.toPay:
      return const _ExpenseStatusTone(
        label: 'Da pagare',
        color: Color(0xFFB45309),
        icon: Icons.schedule_outlined,
      );
  }
}

class _ExpenseStatusChip extends StatelessWidget {
  const _ExpenseStatusChip({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final tone = _expenseStatusTone(expense);
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(tone.icon, size: 16, color: tone.color),
      label: Text(tone.label),
      labelStyle: TextStyle(color: tone.color, fontWeight: FontWeight.w800),
      backgroundColor: tone.background,
      side: BorderSide(color: tone.border),
    );
  }
}

class _ExpenseMiniTile extends StatelessWidget {
  const _ExpenseMiniTile({
    required this.expense,
    required this.category,
    required this.currency,
    required this.dateFormat,
    required this.onTap,
  });

  final Expense expense;
  final ExpenseCategory? category;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _expenseStatusTone(expense);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: tone.color,
        child: Icon(tone.icon, color: Colors.white, size: 18),
      ),
      title: Text(expense.title),
      subtitle: Text(
        '${category?.name ?? 'Senza voce'} - ${dateFormat.format(expense.dueDate)}',
      ),
      trailing: Text(currency.format(expense.outstandingAmount)),
    );
  }
}

class _ExpenseMobileCard extends StatelessWidget {
  const _ExpenseMobileCard({
    required this.expense,
    required this.category,
    required this.currency,
    required this.dateFormat,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final ExpenseCategory? category;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tone = _expenseStatusTone(expense);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tone.color.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tone.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _ExpenseStatusChip(expense: expense),
              ],
            ),
            const SizedBox(height: 6),
            Text(category?.name ?? 'Senza voce'),
            const SizedBox(height: 6),
            Text('Scadenza ${dateFormat.format(expense.dueDate)}'),
            const SizedBox(height: 6),
            Text(
              '${currency.format(expense.paidAmount)} pagati su ${currency.format(expense.totalAmount)}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: expense.outstandingAmount <= 0 ? null : onPay,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Paga'),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifica'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Cancella'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCalendarDay extends StatelessWidget {
  const _ExpenseCalendarDay({
    required this.day,
    required this.currentMonth,
    required this.expenses,
    required this.categoryById,
    required this.currency,
    required this.onAdd,
    required this.onOpen,
  });

  final DateTime day;
  final int currentMonth;
  final List<Expense> expenses;
  final Map<String, ExpenseCategory> categoryById;
  final NumberFormat currency;
  final VoidCallback onAdd;
  final ValueChanged<Expense> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = day.month != currentMonth;
    return InkWell(
      onTap: onAdd,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              muted
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.30,
                  )
                  : theme.colorScheme.surface,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: muted ? theme.disabledColor : null,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final expense in expenses.take(3))
                    Builder(
                      builder: (context) {
                        final tone = _expenseStatusTone(expense);
                        final categoryColor = Color(
                          categoryById[expense.categoryId]?.color ?? 0xFF475569,
                        );
                        return InkWell(
                          onTap: () => onOpen(expense),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: categoryColor.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(tone.icon, size: 16, color: tone.color),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    '${expense.title} ${currency.format(expense.outstandingAmount)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (expenses.length > 3)
                    Text(
                      '+${expenses.length - 3}',
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.salons,
    required this.categories,
    required this.defaultSalonId,
    this.existing,
    this.initialDate,
    this.currentUserId,
  });

  final List<Salon> salons;
  final List<ExpenseCategory> categories;
  final String? defaultSalonId;
  final Expense? existing;
  final DateTime? initialDate;
  final String? currentUserId;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _supplier;
  late final TextEditingController _amount;
  late final TextEditingController _tax;
  late final TextEditingController _notes;
  String? _salonId;
  String? _categoryId;
  late DateTime _competenceDate;
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _salonId =
        existing?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _categoryId =
        existing?.categoryId ??
        widget.categories
            .where(
              (category) => category.salonId == _salonId && category.isActive,
            )
            .firstOrNull
            ?.id;
    _competenceDate =
        existing?.competenceDate ?? widget.initialDate ?? DateTime.now();
    _dueDate = existing?.dueDate ?? widget.initialDate ?? DateTime.now();
    _title = TextEditingController(text: existing?.title ?? '');
    _supplier = TextEditingController(text: existing?.supplierName ?? '');
    _amount = TextEditingController(
      text: (existing?.totalAmount ?? 0).toStringAsFixed(2),
    );
    _tax = TextEditingController(
      text: (existing?.taxAmount ?? 0).toStringAsFixed(2),
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _supplier.dispose();
    _amount.dispose();
    _tax.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.categories
            .where(
              (category) => category.salonId == _salonId && category.isActive,
            )
            .toList();
    if (_categoryId != null &&
        categories.every((item) => item.id != _categoryId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _categoryId = categories.firstOrNull?.id);
        }
      });
    }
    final title = widget.existing == null ? 'Nuova uscita' : 'Modifica uscita';
    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetSection(
            title: 'Dettagli',
            icon: Icons.receipt_long_outlined,
            child: _FormFieldGrid(
              children: [
                if (widget.salons.length > 1)
                  DropdownButtonFormField<String>(
                    value: _salonId,
                    decoration: const InputDecoration(labelText: 'Salone'),
                    items:
                        widget.salons
                            .map(
                              (salon) => DropdownMenuItem(
                                value: salon.id,
                                child: Text(salon.name),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          _salonId = value;
                          _categoryId =
                              widget.categories
                                  .where(
                                    (category) =>
                                        category.salonId == value &&
                                        category.isActive,
                                  )
                                  .firstOrNull
                                  ?.id;
                        }),
                    validator:
                        (value) => value == null ? 'Seleziona un salone' : null,
                  ),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Voce di uscita',
                  ),
                  items:
                      categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator:
                      (value) => value == null ? 'Seleziona una voce' : null,
                ),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titolo'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Inserisci un titolo'
                              : null,
                ),
                TextFormField(
                  controller: _supplier,
                  decoration: const InputDecoration(labelText: 'Fornitore'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Importi',
            icon: Icons.euro_rounded,
            child: _FormFieldGrid(
              children: [
                TextFormField(
                  controller: _amount,
                  decoration: const InputDecoration(
                    labelText: 'Importo totale',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator:
                      (value) =>
                          (_parseMoney(value) <= 0)
                              ? 'Importo non valido'
                              : null,
                ),
                TextFormField(
                  controller: _tax,
                  decoration: const InputDecoration(
                    labelText: 'IVA inclusa/opzionale',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Date',
            icon: Icons.event_outlined,
            child: _FormFieldGrid(
              children: [
                _DateTile(
                  label: 'Data competenza',
                  date: _competenceDate,
                  onTap: () async {
                    final picked = await _pickDate(_competenceDate);
                    if (picked != null) {
                      setState(() => _competenceDate = picked);
                    }
                  },
                ),
                _DateTile(
                  label: 'Data scadenza',
                  date: _dueDate,
                  onTap: () async {
                    final picked = await _pickDate(_dueDate);
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Note',
            icon: Icons.notes_outlined,
            child: TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Note interne'),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: isAppSheetPhoneLayout(context) ? double.infinity : 760,
      child: DialogActionLayout(
        title: title,
        subtitle: 'Registra importi, scadenze e competenza economica.',
        body: body,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Annulla'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('it', 'IT'),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    final existing = widget.existing;
    final total = _parseMoney(_amount.text);
    final expense = Expense(
      id: existing?.id ?? const Uuid().v4(),
      salonId: _salonId!,
      categoryId: _categoryId!,
      title: _title.text.trim(),
      supplierName: _emptyToNull(_supplier.text),
      amount: total,
      taxAmount: _parseMoney(_tax.text),
      totalAmount: total,
      competenceDate: _competenceDate,
      dueDate: _dueDate,
      status: existing?.status ?? ExpenseStatus.toPay,
      payments: existing?.payments,
      notes: _emptyToNull(_notes.text),
      isRecurring: existing?.isRecurring ?? false,
      recurrenceRuleId: existing?.recurrenceRuleId,
      occurrenceDate: existing?.occurrenceDate,
      createdAt: existing?.createdAt ?? now,
      createdBy: existing?.createdBy ?? widget.currentUserId,
      updatedAt: now,
      updatedBy: widget.currentUserId,
      deletedAt: existing?.deletedAt,
      deletedBy: existing?.deletedBy,
      deleteReason: existing?.deleteReason,
    );
    Navigator.of(context).pop(expense);
  }
}

class _ExpenseCategoryFormSheet extends StatefulWidget {
  const _ExpenseCategoryFormSheet({
    required this.salons,
    required this.defaultSalonId,
    this.existing,
    this.currentUserId,
  });

  final List<Salon> salons;
  final String? defaultSalonId;
  final ExpenseCategory? existing;
  final String? currentUserId;

  @override
  State<_ExpenseCategoryFormSheet> createState() =>
      _ExpenseCategoryFormSheetState();
}

class _ExpenseCategoryFormSheetState extends State<_ExpenseCategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _budget;
  String? _salonId;
  ExpenseReportGroup _group = ExpenseReportGroup.fixedCosts;
  PaymentMethod? _defaultMethod;
  bool _isActive = true;
  bool _requiresAttachment = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _salonId =
        existing?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _group = existing?.reportGroup ?? ExpenseReportGroup.fixedCosts;
    _defaultMethod = existing?.defaultPaymentMethod;
    _isActive = existing?.isActive ?? true;
    _requiresAttachment = existing?.requiresAttachment ?? false;
    _name = TextEditingController(text: existing?.name ?? '');
    _budget = TextEditingController(
      text: existing?.monthlyBudget?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null ? 'Nuova voce' : 'Modifica voce';
    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetSection(
            title: 'Identita',
            icon: Icons.label_outline_rounded,
            child: _FormFieldGrid(
              children: [
                if (widget.salons.length > 1)
                  DropdownButtonFormField<String>(
                    value: _salonId,
                    decoration: const InputDecoration(labelText: 'Salone'),
                    items:
                        widget.salons
                            .map(
                              (salon) => DropdownMenuItem(
                                value: salon.id,
                                child: Text(salon.name),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _salonId = value),
                    validator:
                        (value) => value == null ? 'Seleziona un salone' : null,
                  ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome voce'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Inserisci un nome'
                              : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Report e pagamenti',
            icon: Icons.analytics_outlined,
            child: _FormFieldGrid(
              children: [
                DropdownButtonFormField<ExpenseReportGroup>(
                  value: _group,
                  decoration: const InputDecoration(labelText: 'Gruppo report'),
                  items:
                      ExpenseReportGroup.values
                          .map(
                            (group) => DropdownMenuItem(
                              value: group,
                              child: Text(group.label),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(
                        () => _group = value ?? ExpenseReportGroup.other,
                      ),
                ),
                DropdownButtonFormField<PaymentMethod?>(
                  value: _defaultMethod,
                  decoration: const InputDecoration(
                    labelText: 'Metodo predefinito',
                  ),
                  items: [
                    const DropdownMenuItem<PaymentMethod?>(
                      value: null,
                      child: Text('Nessuno'),
                    ),
                    ...PaymentMethod.values
                        .where((method) => method.isManualSelectable)
                        .map(
                          (method) => DropdownMenuItem<PaymentMethod?>(
                            value: method,
                            child: Text(method.label),
                          ),
                        ),
                  ],
                  onChanged: (value) => setState(() => _defaultMethod = value),
                ),
                TextFormField(
                  controller: _budget,
                  decoration: const InputDecoration(
                    labelText: 'Budget mensile',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Opzioni',
            icon: Icons.tune_rounded,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _requiresAttachment,
                  onChanged:
                      (value) => setState(() => _requiresAttachment = value),
                  title: const Text('Richiede allegato'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Voce attiva'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: isAppSheetPhoneLayout(context) ? double.infinity : 680,
      child: DialogActionLayout(
        title: title,
        subtitle:
            'Definisci classificazione, budget e comportamento della voce.',
        body: body,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Annulla'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    final existing = widget.existing;
    final category = ExpenseCategory(
      id: existing?.id ?? const Uuid().v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      reportGroup: _group,
      color: existing?.color ?? _colorForGroup(_group),
      defaultPaymentMethod: _defaultMethod,
      monthlyBudget:
          _budget.text.trim().isEmpty ? null : _parseMoney(_budget.text),
      requiresAttachment: _requiresAttachment,
      isActive: _isActive,
      sortOrder: existing?.sortOrder ?? 0,
      createdAt: existing?.createdAt ?? now,
      createdBy: existing?.createdBy ?? widget.currentUserId,
      updatedAt: now,
      updatedBy: widget.currentUserId,
    );
    Navigator.of(context).pop(category);
  }

  int _colorForGroup(ExpenseReportGroup group) {
    switch (group) {
      case ExpenseReportGroup.fixedCosts:
        return 0xFF7C3AED;
      case ExpenseReportGroup.variableCosts:
        return 0xFF2563EB;
      case ExpenseReportGroup.staff:
        return 0xFF0F766E;
      case ExpenseReportGroup.tax:
        return 0xFFB45309;
      case ExpenseReportGroup.marketing:
        return 0xFFE11D48;
      case ExpenseReportGroup.inventory:
        return 0xFF047857;
      case ExpenseReportGroup.maintenance:
        return 0xFF6D28D9;
      case ExpenseReportGroup.other:
        return 0xFF475569;
    }
  }
}

class _ExpenseRecurringFormSheet extends StatefulWidget {
  const _ExpenseRecurringFormSheet({
    required this.salons,
    required this.categories,
    required this.defaultSalonId,
    this.existing,
    this.currentUserId,
  });

  final List<Salon> salons;
  final List<ExpenseCategory> categories;
  final String? defaultSalonId;
  final ExpenseRecurringRule? existing;
  final String? currentUserId;

  @override
  State<_ExpenseRecurringFormSheet> createState() =>
      _ExpenseRecurringFormSheetState();
}

class _ExpenseRecurringFormSheetState
    extends State<_ExpenseRecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _supplier;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  String? _salonId;
  String? _categoryId;
  ExpenseRecurrenceFrequency _frequency = ExpenseRecurrenceFrequency.monthly;
  PaymentMethod? _defaultMethod;
  late DateTime _startDate;
  DateTime? _endDate;
  int _dueDay = 5;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _salonId =
        existing?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _categoryId =
        existing?.categoryId ??
        widget.categories
            .where(
              (category) => category.salonId == _salonId && category.isActive,
            )
            .firstOrNull
            ?.id;
    _frequency = existing?.frequency ?? ExpenseRecurrenceFrequency.monthly;
    _defaultMethod = existing?.defaultPaymentMethod;
    _startDate = existing?.startDate ?? DateTime.now();
    _endDate = existing?.endDate;
    _dueDay = existing?.dueDay ?? _startDate.day;
    _title = TextEditingController(text: existing?.title ?? '');
    _supplier = TextEditingController(text: existing?.supplierName ?? '');
    _amount = TextEditingController(
      text: (existing?.totalAmount ?? 0).toStringAsFixed(2),
    );
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _supplier.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.categories
            .where(
              (category) => category.salonId == _salonId && category.isActive,
            )
            .toList();
    final preview = _previewOccurrences();
    final title =
        widget.existing == null ? 'Nuova ricorrente' : 'Modifica ricorrente';
    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetSection(
            title: 'Dettagli',
            icon: Icons.repeat_rounded,
            child: _FormFieldGrid(
              children: [
                if (widget.salons.length > 1)
                  DropdownButtonFormField<String>(
                    value: _salonId,
                    decoration: const InputDecoration(labelText: 'Salone'),
                    items:
                        widget.salons
                            .map(
                              (salon) => DropdownMenuItem(
                                value: salon.id,
                                child: Text(salon.name),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          _salonId = value;
                          _categoryId =
                              widget.categories
                                  .where(
                                    (category) =>
                                        category.salonId == value &&
                                        category.isActive,
                                  )
                                  .firstOrNull
                                  ?.id;
                        }),
                  ),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Voce'),
                  items:
                      categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator:
                      (value) => value == null ? 'Seleziona una voce' : null,
                ),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titolo'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Inserisci un titolo'
                              : null,
                ),
                TextFormField(
                  controller: _supplier,
                  decoration: const InputDecoration(labelText: 'Fornitore'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Importo e ricorrenza',
            icon: Icons.schedule_outlined,
            child: _FormFieldGrid(
              children: [
                TextFormField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'Importo'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator:
                      (value) =>
                          _parseMoney(value) <= 0 ? 'Importo non valido' : null,
                ),
                DropdownButtonFormField<ExpenseRecurrenceFrequency>(
                  value: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequenza'),
                  items:
                      ExpenseRecurrenceFrequency.values
                          .map(
                            (frequency) => DropdownMenuItem(
                              value: frequency,
                              child: Text(frequency.label),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(
                        () =>
                            _frequency =
                                value ?? ExpenseRecurrenceFrequency.monthly,
                      ),
                ),
                DropdownButtonFormField<int>(
                  value: _dueDay.clamp(1, 31).toInt(),
                  decoration: const InputDecoration(
                    labelText: 'Giorno scadenza',
                  ),
                  items:
                      List<int>.generate(31, (index) => index + 1)
                          .map(
                            (day) => DropdownMenuItem(
                              value: day,
                              child: Text('$day'),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _dueDay = value ?? 1),
                ),
                DropdownButtonFormField<PaymentMethod?>(
                  value: _defaultMethod,
                  decoration: const InputDecoration(
                    labelText: 'Metodo predefinito',
                  ),
                  items: [
                    const DropdownMenuItem<PaymentMethod?>(
                      value: null,
                      child: Text('Nessuno'),
                    ),
                    ...PaymentMethod.values
                        .where((method) => method.isManualSelectable)
                        .map(
                          (method) => DropdownMenuItem<PaymentMethod?>(
                            value: method,
                            child: Text(method.label),
                          ),
                        ),
                  ],
                  onChanged: (value) => setState(() => _defaultMethod = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Periodo',
            icon: Icons.date_range_outlined,
            child: _FormFieldGrid(
              children: [
                _DateTile(
                  label: 'Data inizio',
                  date: _startDate,
                  onTap: () async {
                    final picked = await _pickDate(_startDate);
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                ),
                _DateTile(
                  label: 'Data fine',
                  date: _endDate,
                  emptyLabel: 'Nessuna fine',
                  onTap: () async {
                    final picked = await _pickDate(_endDate ?? _startDate);
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                  trailing:
                      _endDate == null
                          ? null
                          : IconButton(
                            tooltip: 'Rimuovi fine',
                            onPressed: () => setState(() => _endDate = null),
                            icon: const Icon(Icons.clear_rounded),
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Anteprima',
            icon: Icons.calendar_month_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  preview
                      .map(
                        (date) => Chip(
                          label: Text(DateFormat('dd/MM/yyyy').format(date)),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Note',
            icon: Icons.notes_outlined,
            child: TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Note interne'),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: isAppSheetPhoneLayout(context) ? double.infinity : 760,
      child: DialogActionLayout(
        title: title,
        subtitle: 'Genera automaticamente le prossime uscite pianificate.',
        body: body,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Annulla'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: const Locale('it', 'IT'),
    );
  }

  List<DateTime> _previewOccurrences() {
    final dates = <DateTime>[];
    var current = _startDate;
    for (var i = 0; i < 6; i++) {
      if (_endDate != null && current.isAfter(_endDate!)) {
        break;
      }
      final lastDay = DateTime(current.year, current.month + 1, 0).day;
      dates.add(
        DateTime(
          current.year,
          current.month,
          _dueDay.clamp(1, lastDay).toInt(),
        ),
      );
      current = _next(current);
    }
    return dates;
  }

  DateTime _next(DateTime current) {
    if (_frequency == ExpenseRecurrenceFrequency.weekly) {
      return current.add(const Duration(days: 7));
    }
    final monthStep = _frequency.monthStep;
    final lastDay =
        DateTime(current.year, current.month + monthStep + 1, 0).day;
    return DateTime(
      current.year,
      current.month + monthStep,
      current.day.clamp(1, lastDay).toInt(),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    final existing = widget.existing;
    final total = _parseMoney(_amount.text);
    final rule = ExpenseRecurringRule(
      id: existing?.id ?? const Uuid().v4(),
      salonId: _salonId!,
      categoryId: _categoryId!,
      title: _title.text.trim(),
      supplierName: _emptyToNull(_supplier.text),
      amount: total,
      totalAmount: total,
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
      dueDay: _dueDay,
      defaultPaymentMethod: _defaultMethod,
      notes: _emptyToNull(_notes.text),
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt ?? now,
      createdBy: existing?.createdBy ?? widget.currentUserId,
      updatedAt: now,
      updatedBy: widget.currentUserId,
      cancelledAt: existing?.cancelledAt,
      cancelledBy: existing?.cancelledBy,
    );
    Navigator.of(context).pop(rule);
  }
}

class _ExpensePaymentSheet extends StatefulWidget {
  const _ExpensePaymentSheet({
    required this.expense,
    this.initialMethod,
    this.currentUserId,
  });

  final Expense expense;
  final PaymentMethod? initialMethod;
  final String? currentUserId;

  @override
  State<_ExpensePaymentSheet> createState() => _ExpensePaymentSheetState();
}

class _ExpensePaymentSheetState extends State<_ExpensePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late PaymentMethod _method;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod ?? PaymentMethod.transfer;
    _amount = TextEditingController(
      text: widget.expense.outstandingAmount.toStringAsFixed(2),
    );
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final body = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaymentSummaryPanel(expense: widget.expense, currency: currency),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Pagamento',
            icon: Icons.payments_outlined,
            child: _FormFieldGrid(
              children: [
                TextFormField(
                  controller: _amount,
                  decoration: InputDecoration(
                    labelText: 'Importo',
                    helperText:
                        'Residuo ${currency.format(widget.expense.outstandingAmount)}',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = _parseMoney(value);
                    if (amount <= 0) {
                      return 'Importo non valido';
                    }
                    if (amount > widget.expense.outstandingAmount + 0.01) {
                      return 'Importo superiore al residuo';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<PaymentMethod>(
                  value: _method,
                  decoration: const InputDecoration(
                    labelText: 'Metodo pagamento',
                  ),
                  items:
                      PaymentMethod.values
                          .where((method) => method.isManualSelectable)
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method.label),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(
                        () => _method = value ?? PaymentMethod.transfer,
                      ),
                ),
                _DateTile(
                  label: 'Data pagamento',
                  date: _date,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365 * 3),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('it', 'IT'),
                    );
                    if (picked != null) {
                      setState(() => _date = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetSection(
            title: 'Nota',
            icon: Icons.notes_outlined,
            child: TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Nota pagamento'),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: isAppSheetPhoneLayout(context) ? double.infinity : 560,
      child: DialogActionLayout(
        title: 'Registra pagamento',
        subtitle: widget.expense.title,
        body: body,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Annulla'),
          ),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      ExpensePayment(
        id: const Uuid().v4(),
        amount: _parseMoney(_amount.text),
        date: _date,
        paymentMethod: _method,
        recordedBy: widget.currentUserId,
        note: _emptyToNull(_note.text),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    this.emptyLabel,
    this.trailing,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final String? emptyLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy', 'it_IT');
    final theme = Theme.of(context);
    final value = date == null ? (emptyLabel ?? '') : formatter.format(date!);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: trailing ?? const Icon(Icons.calendar_today_outlined),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: date == null ? theme.colorScheme.onSurfaceVariant : null,
              fontWeight: date == null ? null : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

double _parseMoney(String? value) {
  final raw = (value ?? '').trim();
  final normalized =
      raw.contains(',') ? raw.replaceAll('.', '').replaceAll(',', '.') : raw;
  return double.tryParse(normalized) ?? 0;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
