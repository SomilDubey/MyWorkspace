import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocket_guard/models/expense_account_filter.dart';
import 'package:pocket_guard/models/user_model.dart';
import 'package:pocket_guard/screens/components/voice_expense_agent_sheet.dart';
import 'package:pocket_guard/services/user_service.dart';
import 'package:pocket_guard/theme.dart';
import 'package:pocket_guard/utils/currency_formatter.dart';

final userStreamProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  return UserService().userStream(user.uid);
});

typedef SalaryCycle = ({
  DateTime start,
  DateTime endExclusive,
  int daysLeftInclusive
});

enum _ExpenseDatePreset {
  all,
  today,
  yesterday,
  thisWeek,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  custom,
}

class _ExpenseDateFilter {
  final _ExpenseDatePreset preset;
  final DateTime? from;
  final DateTime? to;

  const _ExpenseDateFilter(
      {this.preset = _ExpenseDatePreset.all, this.from, this.to});

  String get label => switch (preset) {
        _ExpenseDatePreset.all => 'All dates',
        _ExpenseDatePreset.today => 'Today',
        _ExpenseDatePreset.yesterday => 'Yesterday',
        _ExpenseDatePreset.thisWeek => 'This Week',
        _ExpenseDatePreset.last7Days => 'Last 7 Days',
        _ExpenseDatePreset.last30Days => 'Last 30 Days',
        _ExpenseDatePreset.thisMonth => 'This Month',
        _ExpenseDatePreset.lastMonth => 'Last Month',
        _ExpenseDatePreset.last3Months => 'Last 3 Months',
        _ExpenseDatePreset.thisYear => 'This Year',
        _ExpenseDatePreset.custom => 'Custom Date Range',
      };
}

class ExpenseEntry {
  final String id;
  final double amount;
  final String category;
  final String accountType;
  final String source;
  final String? note;
  final DateTime date;

  ExpenseEntry(
      {required this.id,
      required this.amount,
      required this.category,
      required this.accountType,
      required this.source,
      required this.date,
      this.note});

  factory ExpenseEntry.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final amount = ((data['amount'] ?? 0) as num).toDouble();
    final category = (data['category'] ?? '').toString();
    final accountType = (data['accountType'] ?? 'personal').toString();
    final source = (data['source'] ?? 'manual').toString();
    final note = (data['note'] as String?)?.trim();
    final ts = data['date'];
    final date = (ts is Timestamp) ? ts.toDate() : DateTime.now();
    return ExpenseEntry(
        id: doc.id,
        amount: amount,
        category: category,
        accountType: accountType,
        source: source,
        note: note?.isEmpty == true ? null : note,
        date: date);
  }
}

final expensesStreamProvider = StreamProvider.family
    .autoDispose<List<ExpenseEntry>, ExpenseAccountFilter>((ref, filter) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  final q = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('expenses');

  // Account types were not always stored consistently. Filter the ordered stream
  // client-side so entries without an account type retain their Personal default.
  // Do not limit this query: a selected account or date range must include every
  // matching expense, not only the most recent page of expenses.
  return q.orderBy('date', descending: true).snapshots().map((snapshot) {
    final items = snapshot.docs.map(ExpenseEntry.fromDoc).toList();
    return switch (filter) {
      ExpenseAccountFilter.personal => items
          .where((entry) => entry.accountType.toLowerCase() != 'business')
          .toList(),
      ExpenseAccountFilter.business => items
          .where((entry) => entry.accountType.toLowerCase() == 'business')
          .toList(),
      ExpenseAccountFilter.all => items,
    };
  });
});

class ExpensesTab extends ConsumerStatefulWidget {
  const ExpensesTab({super.key});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  ExpenseAccountFilter _filter = ExpenseAccountFilter.all;
  _ExpenseDateFilter _dateFilter = const _ExpenseDateFilter();

  // UI-only privacy states (never persisted / never sent to Firestore)
  bool _personalHidden = false;
  bool _businessHidden = false;
  bool _totalPortfolioHidden = false;

  Future<void> _deleteExpenseDirect(BuildContext context, ExpenseEntry entry,
      {ScaffoldMessengerState? messenger}) async {
    final snack = messenger ?? ScaffoldMessenger.of(context);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      snack.showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    try {
      debugPrint('Deleting expense: uid=$uid expenseId=${entry.id}');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(entry.id)
          .delete();
      snack.showSnackBar(const SnackBar(content: Text('Expense deleted')));
    } catch (e, st) {
      debugPrint('Delete expense failed: $e');
      debugPrint('$st');
      snack.showSnackBar(const SnackBar(
          content: Text('Failed to delete expense. Please try again.')));
      rethrow;
    }
  }

  void _ensureValidFilter(
      {required bool personalEnabled, required bool businessEnabled}) {
    if (_filter == ExpenseAccountFilter.personal && !personalEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _filter = businessEnabled
            ? ExpenseAccountFilter.business
            : ExpenseAccountFilter.all);
      });
      return;
    }

    if (_filter == ExpenseAccountFilter.business && !businessEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _filter = personalEnabled
            ? ExpenseAccountFilter.personal
            : ExpenseAccountFilter.all);
      });
    }
  }

  Future<void> _setAccountEnabled(
      {required UserModel user,
      bool? personalEnabled,
      bool? businessEnabled}) async {
    final messenger = ScaffoldMessenger.of(context);

    final nextPersonal = personalEnabled ?? user.personalAccountEnabled;
    final nextBusiness = businessEnabled ?? user.businessAccountEnabled;
    if (!nextPersonal && !nextBusiness) {
      messenger.showSnackBar(const SnackBar(
          content: Text('At least one account must stay enabled.')));
      return;
    }

    try {
      await UserService().updateUser(user.copyWith(
          personalAccountEnabled: nextPersonal,
          businessAccountEnabled: nextBusiness));
    } catch (e, st) {
      debugPrint('Failed to update account settings: $e');
      debugPrint('$st');
      messenger.showSnackBar(const SnackBar(
          content:
              Text('Failed to update account settings. Please try again.')));
    }
  }

  void _showAccountSettingsSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountSettingsSheet(
        user: user,
        onSetPersonalEnabled: (v) =>
            _setAccountEnabled(user: user, personalEnabled: v),
        onSetBusinessEnabled: (v) =>
            _setAccountEnabled(user: user, businessEnabled: v),
      ),
    );
  }

  bool _matchesDateFilter(DateTime date, _ExpenseDateFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    DateTime? endExclusive;

    switch (filter.preset) {
      case _ExpenseDatePreset.all:
        return true;
      case _ExpenseDatePreset.today:
        from = today;
        endExclusive = today.add(const Duration(days: 1));
      case _ExpenseDatePreset.yesterday:
        from = today.subtract(const Duration(days: 1));
        endExclusive = today;
      case _ExpenseDatePreset.thisWeek:
        from = today.subtract(Duration(days: today.weekday - DateTime.monday));
        endExclusive = today.add(const Duration(days: 1));
      case _ExpenseDatePreset.last7Days:
        from = today.subtract(const Duration(days: 6));
        endExclusive = today.add(const Duration(days: 1));
      case _ExpenseDatePreset.last30Days:
        from = today.subtract(const Duration(days: 29));
        endExclusive = today.add(const Duration(days: 1));
      case _ExpenseDatePreset.thisMonth:
        from = DateTime(today.year, today.month);
        endExclusive = DateTime(today.year, today.month + 1);
      case _ExpenseDatePreset.lastMonth:
        from = DateTime(today.year, today.month - 1);
        endExclusive = DateTime(today.year, today.month);
      case _ExpenseDatePreset.last3Months:
        from = DateTime(today.year, today.month - 2);
        endExclusive = DateTime(today.year, today.month + 1);
      case _ExpenseDatePreset.thisYear:
        from = DateTime(today.year);
        endExclusive = DateTime(today.year + 1);
      case _ExpenseDatePreset.custom:
        from = filter.from == null
            ? null
            : DateTime(filter.from!.year, filter.from!.month, filter.from!.day);
        endExclusive = filter.to == null
            ? null
            : DateTime(filter.to!.year, filter.to!.month, filter.to!.day + 1);
    }

    if (from == null || endExclusive == null) return true;
    return !date.isBefore(from) && date.isBefore(endExclusive);
  }

  Future<void> _showDateFilterSheet(
    BuildContext context, {
    required bool personalEnabled,
    required bool businessEnabled,
    required bool showAccountTypeFilter,
  }) async {
    final selection = await showModalBottomSheet<
        ({ExpenseAccountFilter accountFilter, _ExpenseDateFilter dateFilter})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var preset = _dateFilter.preset;
        DateTime? from = _dateFilter.from;
        DateTime? to = _dateFilter.to;
        var accountFilter = _filter;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            const presets = [
              (_ExpenseDatePreset.today, 'Today'),
              (_ExpenseDatePreset.yesterday, 'Yesterday'),
              (_ExpenseDatePreset.thisWeek, 'This Week'),
              (_ExpenseDatePreset.last7Days, 'Last 7 Days'),
              (_ExpenseDatePreset.last30Days, 'Last 30 Days'),
              (_ExpenseDatePreset.thisMonth, 'This Month'),
              (_ExpenseDatePreset.lastMonth, 'Last Month'),
              (_ExpenseDatePreset.last3Months, 'Last 3 Months'),
              (_ExpenseDatePreset.thisYear, 'This Year'),
              (_ExpenseDatePreset.custom, 'Custom Date Range'),
            ];

            Future<void> chooseDate({required bool isFrom}) async {
              final selected = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                initialDate:
                    isFrom ? (from ?? DateTime.now()) : (to ?? DateTime.now()),
              );
              if (selected == null) return;
              setSheetState(() {
                if (isFrom) {
                  from = selected;
                  preset = _ExpenseDatePreset.custom;
                } else {
                  to = selected;
                  preset = _ExpenseDatePreset.custom;
                }
              });
            }

            return SafeArea(
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Filter Expenses',
                              style:
                                  context.textStyles.headlineSmall?.semiBold)),
                      TextButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          (
                            accountFilter: _filter,
                            dateFilter: const _ExpenseDateFilter(),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ]),
                    if (showAccountTypeFilter) ...[
                      const SizedBox(height: 8),
                      Text('Account Type',
                          style: context.textStyles.bodySmall?.semiBold
                              .withColor(AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: accountFilter == ExpenseAccountFilter.all,
                            selectedColor:
                                AppColors.credTeal.withValues(alpha: .25),
                            onSelected: (_) => setSheetState(
                                () => accountFilter = ExpenseAccountFilter.all),
                          ),
                          if (personalEnabled)
                            FilterChip(
                              label: const Text('Personal'),
                              selected: accountFilter ==
                                  ExpenseAccountFilter.personal,
                              selectedColor:
                                  AppColors.credTeal.withValues(alpha: .25),
                              onSelected: (_) => setSheetState(() =>
                                  accountFilter =
                                      ExpenseAccountFilter.personal),
                            ),
                          if (businessEnabled)
                            FilterChip(
                              label: const Text('Business'),
                              selected: accountFilter ==
                                  ExpenseAccountFilter.business,
                              selectedColor:
                                  AppColors.credTeal.withValues(alpha: .25),
                              onSelected: (_) => setSheetState(() =>
                                  accountFilter =
                                      ExpenseAccountFilter.business),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 8),
                    Text('Date Range',
                        style: context.textStyles.bodySmall?.semiBold
                            .withColor(AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All dates'),
                          selected: preset == _ExpenseDatePreset.all,
                          onSelected: (_) => setSheetState(() {
                            preset = _ExpenseDatePreset.all;
                            from = null;
                            to = null;
                          }),
                        ),
                        ...presets.map((item) => FilterChip(
                              label: Text(item.$2),
                              selected: preset == item.$1,
                              selectedColor:
                                  AppColors.credTeal.withValues(alpha: .25),
                              onSelected: (_) =>
                                  setSheetState(() => preset = item.$1),
                            )),
                      ],
                    ),
                    if (preset == _ExpenseDatePreset.custom) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton.icon(
                                onPressed: () => chooseDate(isFrom: true),
                                icon:
                                    const Icon(Icons.calendar_today, size: 16),
                                label: Text(from == null
                                    ? 'From date'
                                    : DateFormat('d MMM yyyy').format(from!)))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton.icon(
                                onPressed: () => chooseDate(isFrom: false),
                                icon:
                                    const Icon(Icons.calendar_today, size: 16),
                                label: Text(to == null
                                    ? 'To date'
                                    : DateFormat('d MMM yyyy').format(to!)))),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (preset == _ExpenseDatePreset.custom &&
                              (from == null || to == null)) return;
                          if (preset == _ExpenseDatePreset.custom &&
                              from!.isAfter(to!)) return;
                          Navigator.pop(
                            sheetContext,
                            (
                              accountFilter: accountFilter,
                              dateFilter: _ExpenseDateFilter(
                                  preset: preset, from: from, to: to),
                            ),
                          );
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selection != null && mounted) {
      setState(() {
        _filter = selection.accountFilter;
        _dateFilter = selection.dateFilter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider(_filter));

    return userAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.credTeal)),
      error: (error, stack) => Center(
          child: Text('Error: $error', style: context.textStyles.bodyMedium)),
      data: (user) {
        if (user == null) return const Center(child: Text('User not found'));

        return expensesAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.credTeal)),
          error: (error, stack) => Center(
              child:
                  Text('Error: $error', style: context.textStyles.bodyMedium)),
          data: (expenses) {
            final personalEnabled = user.personalAccountEnabled;
            final businessEnabled = user.businessAccountEnabled;

            _ensureValidFilter(
                personalEnabled: personalEnabled,
                businessEnabled: businessEnabled);

            bool isEntryEnabled(ExpenseEntry e) {
              final isBusiness = e.accountType.toLowerCase() == 'business';
              return isBusiness ? businessEnabled : personalEnabled;
            }

            final List<ExpenseEntry> expensesForView;
            if (_filter == ExpenseAccountFilter.personal) {
              expensesForView = personalEnabled
                  ? expenses
                      .where((e) => e.accountType.toLowerCase() != 'business')
                      .toList()
                  : const [];
            } else if (_filter == ExpenseAccountFilter.business) {
              expensesForView = businessEnabled
                  ? expenses
                      .where((e) => e.accountType.toLowerCase() == 'business')
                      .toList()
                  : const [];
            } else {
              expensesForView = expenses.where(isEntryEnabled).toList();
            }

            final filteredExpenses = expensesForView
                .where((entry) => _matchesDateFilter(entry.date, _dateFilter))
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            final cycle = _currentSalaryCycle(user.salaryDate);
            final cycleExpenses = expensesForView
                .where((e) =>
                    !e.date.isBefore(cycle.start) &&
                    e.date.isBefore(cycle.endExclusive))
                .toList();

            final personalSpent = personalEnabled
                ? cycleExpenses
                    .where((e) => e.accountType.toLowerCase() != 'business')
                    .fold<double>(0, (s, e) => s + e.amount)
                : 0.0;
            final businessSpent = businessEnabled
                ? cycleExpenses
                    .where((e) => e.accountType.toLowerCase() == 'business')
                    .fold<double>(0, (s, e) => s + e.amount)
                : 0.0;

            final totalSpent =
                cycleExpenses.fold<double>(0, (total, e) => total + e.amount);

            final personalSalary = personalEnabled ? user.personalSalary : 0.0;
            final businessIncome = businessEnabled ? user.businessIncome : 0.0;
            final personalAvailable =
                personalEnabled ? (personalSalary - user.fixedDeductions) : 0.0;

            final availableForAll = personalAvailable + businessIncome;
            final remainingSalary = availableForAll - totalSpent;

            final personalRemaining = personalAvailable - personalSpent;
            final businessRemaining = businessIncome - businessSpent;
            final remainingForView = switch (_filter) {
              ExpenseAccountFilter.personal => personalRemaining,
              ExpenseAccountFilter.business => businessRemaining,
              _ => remainingSalary,
            };

            final dailyLimitBase = remainingForView;
            final dailyLimit = cycle.daysLeftInclusive > 0
                ? (dailyLimitBase / cycle.daysLeftInclusive.toDouble())
                : 0.0;

            final recent = filteredExpenses;

            return Scaffold(
              body: SafeArea(
                bottom: false,
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 140),
                    children: [
                      _ExpensesTopBar(
                        filter: _filter,
                        personalHidden: _personalHidden,
                        businessHidden: _businessHidden,
                        personalEnabled: personalEnabled,
                        businessEnabled: businessEnabled,
                        onOpenUserAccount: () => _showUserAccountSheet(user),
                        onOpenAccountSettings: () =>
                            _showAccountSettingsSheet(user),
                        onFilterChanged: (v) => setState(() => _filter = v),
                        onTogglePersonalHidden: () =>
                            setState(() => _personalHidden = !_personalHidden),
                        onToggleBusinessHidden: () =>
                            setState(() => _businessHidden = !_businessHidden),
                      ),
                      const SizedBox(height: 12),
                      PortfolioHeaderSection(
                        filter: _filter,
                        personalEnabled: personalEnabled,
                        businessEnabled: businessEnabled,
                        personalSalary: user.personalSalary,
                        businessIncome: user.businessIncome,
                        deductions: user.fixedDeductions,
                        daysLeftInclusive: cycle.daysLeftInclusive,
                        personalSpent: personalSpent,
                        businessSpent: businessSpent,
                        totalSpent: totalSpent,
                        remaining: remainingForView,
                        dailyLimit: dailyLimit,
                        personalHidden: _personalHidden,
                        businessHidden: _businessHidden,
                        totalPortfolioHidden: _totalPortfolioHidden,
                        onTogglePersonalHidden: () =>
                            setState(() => _personalHidden = !_personalHidden),
                        onToggleBusinessHidden: () =>
                            setState(() => _businessHidden = !_businessHidden),
                        onToggleTotalPortfolioHidden: () => setState(() =>
                            _totalPortfolioHidden = !_totalPortfolioHidden),
                        onEditIncome: () => _showEditIncomeSheet(context, user),
                      ),
                      const SizedBox(height: 18),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent Expenses (${recent.length})',
                              style:
                                  context.textStyles.headlineMedium?.semiBold),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_filter == ExpenseAccountFilter.all)
                                ActionChip(
                                  label: const Text('All accounts'),
                                  avatar: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 16),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  side: const BorderSide(
                                      color: Colors.transparent),
                                  onPressed: () => _showDateFilterSheet(
                                    context,
                                    personalEnabled: personalEnabled,
                                    businessEnabled: businessEnabled,
                                    showAccountTypeFilter: true,
                                  ),
                                ),
                              ActionChip(
                                label: Text(_dateFilter.label),
                                avatar: const Icon(Icons.date_range_rounded,
                                    size: 16),
                                backgroundColor: _dateFilter.preset ==
                                        _ExpenseDatePreset.all
                                    ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                    : AppColors.credTeal.withValues(alpha: .18),
                                side: BorderSide(
                                  color: _dateFilter.preset ==
                                          _ExpenseDatePreset.all
                                      ? Colors.transparent
                                      : AppColors.credTeal,
                                ),
                                onPressed: () => _showDateFilterSheet(
                                  context,
                                  personalEnabled: personalEnabled,
                                  businessEnabled: businessEnabled,
                                  showAccountTypeFilter:
                                      _filter == ExpenseAccountFilter.all,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_dateFilter.preset != _ExpenseDatePreset.all) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_dateFilter.preset != _ExpenseDatePreset.all)
                              Chip(
                                label: Text(_dateFilter.label),
                                avatar: const Icon(Icons.date_range_rounded,
                                    size: 16),
                                backgroundColor:
                                    AppColors.credTeal.withValues(alpha: .18),
                                side: BorderSide(
                                    color: AppColors.credTeal
                                        .withValues(alpha: .5)),
                              ),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _dateFilter = const _ExpenseDateFilter();
                              }),
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              label: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (recent.isEmpty)
                        const EmptyTransactionsState()
                      else
                        SizedBox(
                          height: 360,
                          child: ListView.builder(
                            itemCount: recent.length,
                            itemBuilder: (context, index) {
                              final entry = recent[index];
                              final isBusiness =
                                  entry.accountType.toLowerCase() == 'business';
                              final hide = isBusiness
                                  ? _businessHidden
                                  : _personalHidden;
                              return ExpenseTile(
                                entry: entry,
                                hideAmounts: hide,
                                canDelete: true,
                                onEdit: () => _showEditTransactionDialog(
                                    context, user, entry),
                                onDelete: () =>
                                    _deleteExpenseDirect(context, entry),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              floatingActionButton: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: FloatingActionButton(
                      heroTag: 'voice_expense_fab',
                      onPressed: () => _showVoiceAgentSheet(context, user.uid),
                      backgroundColor:
                          AppColors.credTeal.withValues(alpha: 0.82),
                      elevation: 2,
                      child: const Icon(Icons.mic_rounded,
                          size: 18, color: AppColors.darkBackground),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.extended(
                    heroTag: 'add_expense_fab',
                    onPressed: () => _showAddTransactionDialog(context, user),
                    backgroundColor: AppColors.credTeal.withValues(alpha: 0.82),
                    elevation: 2,
                    extendedPadding: const EdgeInsets.symmetric(horizontal: 10),
                    extendedIconLabelSpacing: 4,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Expense',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddTransactionDialog(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddTransactionSheet(
          user: user, rootContext: context, accountContext: _filter),
    );
  }

  void _showVoiceAgentSheet(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => VoiceExpenseAgentSheet(
        userId: userId,
        rootContext: context,
        personalHidden: _personalHidden,
        businessHidden: _businessHidden,
        accountContext: _filter,
      ),
    );
  }

  void _showUserAccountSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserAccountSheet(user: user),
    );
  }

  void _showEditTransactionDialog(
      BuildContext context, UserModel user, ExpenseEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
          user: user,
          rootContext: context,
          accountContext: _filter,
          entry: entry),
    );
  }

  void _showEditIncomeSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          EditIncomeSheet(user: user, rootContext: context),
    );
  }
}

class _ExpensesTopBar extends StatelessWidget {
  final ExpenseAccountFilter filter;
  final bool personalHidden;
  final bool businessHidden;
  final bool personalEnabled;
  final bool businessEnabled;
  final VoidCallback onOpenUserAccount;
  final VoidCallback onOpenAccountSettings;
  final ValueChanged<ExpenseAccountFilter> onFilterChanged;
  final VoidCallback onTogglePersonalHidden;
  final VoidCallback onToggleBusinessHidden;

  const _ExpensesTopBar({
    required this.filter,
    required this.personalHidden,
    required this.businessHidden,
    required this.personalEnabled,
    required this.businessEnabled,
    required this.onOpenUserAccount,
    required this.onOpenAccountSettings,
    required this.onFilterChanged,
    required this.onTogglePersonalHidden,
    required this.onToggleBusinessHidden,
  });

  @override
  Widget build(BuildContext context) {
    final segments = <ButtonSegment<ExpenseAccountFilter>>[
      const ButtonSegment(value: ExpenseAccountFilter.all, label: Text('All')),
      if (personalEnabled)
        const ButtonSegment(
            value: ExpenseAccountFilter.personal, label: Text('Personal')),
      if (businessEnabled)
        const ButtonSegment(
            value: ExpenseAccountFilter.business, label: Text('Business')),
    ];

    Widget hideControl;

    if (filter == ExpenseAccountFilter.all) {
      hideControl = PopupMenuButton<_HideTarget>(
        tooltip: 'Hide amounts',
        position: PopupMenuPosition.under,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        itemBuilder: (context) => [
          if (personalEnabled)
            CheckedPopupMenuItem<_HideTarget>(
              value: _HideTarget.personal,
              checked: personalHidden,
              child: const Text('Hide Personal'),
            ),
          if (businessEnabled)
            CheckedPopupMenuItem<_HideTarget>(
              value: _HideTarget.business,
              checked: businessHidden,
              child: const Text('Hide Business'),
            ),
        ],
        onSelected: (v) {
          switch (v) {
            case _HideTarget.personal:
              onTogglePersonalHidden();
            case _HideTarget.business:
              onToggleBusinessHidden();
          }
        },
        child: IconButton(
          onPressed: null,
          icon: Icon(
              (personalHidden || businessHidden)
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppColors.textSecondary),
        ),
      );
    } else if (filter == ExpenseAccountFilter.personal) {
      hideControl = IconButton(
        onPressed: onTogglePersonalHidden,
        tooltip:
            personalHidden ? 'Show personal amounts' : 'Hide personal amounts',
        icon: Icon(
            personalHidden
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: AppColors.textSecondary),
      );
    } else {
      hideControl = IconButton(
        onPressed: onToggleBusinessHidden,
        tooltip:
            businessHidden ? 'Show business amounts' : 'Hide business amounts',
        icon: Icon(
            businessHidden
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: AppColors.textSecondary),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SegmentedButton<ExpenseAccountFilter>(
            segments: segments,
            selected: {filter},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              onFilterChanged(s.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.credTeal;
                }
                return Theme.of(context).colorScheme.surfaceContainerHighest;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.darkBackground;
                }
                return Theme.of(context).colorScheme.onSurfaceVariant;
              }),
              side: WidgetStateProperty.all(
                  BorderSide(color: Colors.white.withValues(alpha: 0.10))),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999))),
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              textStyle: WidgetStateProperty.all(
                  context.textStyles.bodySmall?.semiBold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        hideControl,
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'My account',
          onPressed: onOpenUserAccount,
          icon: const Icon(Icons.person_outline_rounded,
              color: AppColors.textSecondary),
        ),
        IconButton(
          tooltip: 'Account settings',
          onPressed: onOpenAccountSettings,
          icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

enum _HideTarget { personal, business }

SalaryCycle _currentSalaryCycle(int salaryDayOfMonth) {
  final now = DateTime.now();
  final safeSalaryDay = salaryDayOfMonth.clamp(1, 31);

  DateTime salaryThisMonth = _safeDate(now.year, now.month, safeSalaryDay);
  DateTime cycleStart;
  DateTime cycleEndExclusive;

  if (now.isBefore(salaryThisMonth)) {
    cycleEndExclusive = salaryThisMonth;
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    cycleStart = _safeDate(prevMonth.year, prevMonth.month, safeSalaryDay);
  } else {
    cycleStart = salaryThisMonth;
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    cycleEndExclusive =
        _safeDate(nextMonth.year, nextMonth.month, safeSalaryDay);
  }

  final endDateInclusive = cycleEndExclusive.subtract(const Duration(days: 1));
  final daysLeftInclusive = endDateInclusive
          .difference(DateTime(now.year, now.month, now.day))
          .inDays +
      1;
  return (
    start: DateTime(cycleStart.year, cycleStart.month, cycleStart.day),
    endExclusive: DateTime(
        cycleEndExclusive.year, cycleEndExclusive.month, cycleEndExclusive.day),
    daysLeftInclusive: daysLeftInclusive
  );
}

DateTime _safeDate(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final safeDay = day.clamp(1, lastDay);
  return DateTime(year, month, safeDay);
}

String _maskCurrency() => '₹••••';

String _maybeMask({required bool hide, required String value}) =>
    hide ? _maskCurrency() : value;

class PortfolioHeaderSection extends StatelessWidget {
  final ExpenseAccountFilter filter;
  final bool personalEnabled;
  final bool businessEnabled;
  final double personalSalary;
  final double businessIncome;
  final double deductions;
  final int daysLeftInclusive;
  final double personalSpent;
  final double businessSpent;
  final double totalSpent;
  final double remaining;
  final double dailyLimit;

  final bool personalHidden;
  final bool businessHidden;
  final bool totalPortfolioHidden;
  final VoidCallback onTogglePersonalHidden;
  final VoidCallback onToggleBusinessHidden;
  final VoidCallback onToggleTotalPortfolioHidden;
  final VoidCallback onEditIncome;

  const PortfolioHeaderSection({
    super.key,
    required this.filter,
    required this.personalEnabled,
    required this.businessEnabled,
    required this.personalSalary,
    required this.businessIncome,
    required this.deductions,
    required this.daysLeftInclusive,
    required this.personalSpent,
    required this.businessSpent,
    required this.totalSpent,
    required this.remaining,
    required this.dailyLimit,
    required this.personalHidden,
    required this.businessHidden,
    required this.totalPortfolioHidden,
    required this.onTogglePersonalHidden,
    required this.onToggleBusinessHidden,
    required this.onToggleTotalPortfolioHidden,
    required this.onEditIncome,
  });

  @override
  Widget build(BuildContext context) {
    final personalAvailable =
        personalEnabled ? (personalSalary - deductions) : 0.0;
    final personalBalance =
        personalAvailable - (personalEnabled ? personalSpent : 0.0);
    final businessBalance = (businessEnabled ? businessIncome : 0.0) -
        (businessEnabled ? businessSpent : 0.0);

    final totalPortfolio = (personalEnabled ? personalBalance : 0.0) +
        (businessEnabled ? businessBalance : 0.0);

    if (filter == ExpenseAccountFilter.all) {
      final subtitle = switch ((personalEnabled, businessEnabled)) {
        (true, true) => 'Personal Balance + Business Balance',
        (true, false) => 'Personal Balance',
        (false, true) => 'Business Balance',
        _ => 'Portfolio',
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TotalPortfolioHeroCard(
            totalPortfolio: totalPortfolio,
            subtitle: subtitle,
            hidden: totalPortfolioHidden,
            onToggleHidden: onToggleTotalPortfolioHidden,
          ),
          const SizedBox(height: 12),
          if (personalEnabled && businessEnabled)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AccountPortfolioCard(
                      title: 'Personal',
                      icon: Icons.person_rounded,
                      balanceText: _maybeMask(
                          hide: personalHidden,
                          value:
                              CurrencyFormatter.formatCompact(personalBalance)),
                      totalExpensesText: _maybeMask(
                          hide: personalHidden,
                          value:
                              CurrencyFormatter.formatCompact(personalSpent)),
                      eyeHidden: personalHidden,
                      onToggleEye: onTogglePersonalHidden,
                      showBalance: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AccountPortfolioCard(
                      title: 'Business',
                      icon: Icons.business_center_rounded,
                      balanceText: _maybeMask(
                          hide: businessHidden,
                          value:
                              CurrencyFormatter.formatCompact(businessBalance)),
                      totalExpensesText: _maybeMask(
                          hide: businessHidden,
                          value:
                              CurrencyFormatter.formatCompact(businessSpent)),
                      eyeHidden: businessHidden,
                      onToggleEye: onToggleBusinessHidden,
                      showBalance: true,
                    ),
                  ),
                ],
              ),
            )
          else if (personalEnabled)
            AccountPortfolioCard(
              title: 'Personal',
              icon: Icons.person_rounded,
              balanceText: _maybeMask(
                  hide: personalHidden,
                  value: CurrencyFormatter.formatCompact(personalBalance)),
              totalExpensesText: _maybeMask(
                  hide: personalHidden,
                  value: CurrencyFormatter.formatCompact(personalSpent)),
              eyeHidden: personalHidden,
              onToggleEye: onTogglePersonalHidden,
              showBalance: true,
            )
          else if (businessEnabled)
            AccountPortfolioCard(
              title: 'Business',
              icon: Icons.business_center_rounded,
              balanceText: _maybeMask(
                  hide: businessHidden,
                  value: CurrencyFormatter.formatCompact(businessBalance)),
              totalExpensesText: _maybeMask(
                  hide: businessHidden,
                  value: CurrencyFormatter.formatCompact(businessSpent)),
              eyeHidden: businessHidden,
              onToggleEye: onToggleBusinessHidden,
              showBalance: true,
            ),
          const SizedBox(height: 12),
          SalaryOverviewCard(
            personalSalary: personalSalary,
            businessIncome: businessIncome,
            deductions: deductions,
            remaining: remaining,
            totalExpenses: totalSpent,
            hideAmounts: false,
            onEdit: onEditIncome,
            showTotalExpenses: false,
            showPersonalSalary: personalEnabled,
            showBusinessIncome: businessEnabled,
          ),
          const SizedBox(height: 12),
          DailySpendCard(
              dailyLimit: dailyLimit,
              daysLeft: daysLeftInclusive.toDouble(),
              hideAmounts: false),
        ],
      );
    }

    final isPersonal = filter == ExpenseAccountFilter.personal;
    final acctTitle = isPersonal ? 'Personal' : 'Business';
    final icon =
        isPersonal ? Icons.person_rounded : Icons.business_center_rounded;
    final acctSpent = isPersonal ? personalSpent : businessSpent;
    final acctBalance = isPersonal ? personalBalance : businessBalance;
    final acctHidden = isPersonal ? personalHidden : businessHidden;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleAccountHeroCard(
          title: acctTitle,
          icon: icon,
          balanceText: _maybeMask(
              hide: acctHidden,
              value: CurrencyFormatter.formatCompact(acctBalance)),
          totalExpensesText: _maybeMask(
              hide: acctHidden,
              value: CurrencyFormatter.formatCompact(acctSpent)),
        ),
        const SizedBox(height: 12),
        SalaryOverviewCard(
          personalSalary: personalSalary,
          businessIncome: businessIncome,
          deductions: deductions,
          remaining: remaining,
          totalExpenses: totalSpent,
          hideAmounts: false,
          onEdit: onEditIncome,
          showPersonalSalary: isPersonal,
          showBusinessIncome: !isPersonal,
        ),
        const SizedBox(height: 12),
        DailySpendCard(
            dailyLimit: dailyLimit,
            daysLeft: daysLeftInclusive.toDouble(),
            hideAmounts: false),
      ],
    );
  }
}

class TotalPortfolioHeroCard extends StatelessWidget {
  final double totalPortfolio;
  final String subtitle;
  final bool hidden;
  final VoidCallback onToggleHidden;

  const TotalPortfolioHeroCard(
      {super.key,
      required this.totalPortfolio,
      this.subtitle = 'Personal Balance + Business Balance',
      required this.hidden,
      required this.onToggleHidden});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.credTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.credTeal, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Total Portfolio',
                        style: context.textStyles.titleLarge?.semiBold)),
                IconButton(
                  onPressed: onToggleHidden,
                  tooltip:
                      hidden ? 'Show total portfolio' : 'Hide total portfolio',
                  icon: Icon(
                      hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _maybeMask(
                    hide: hidden,
                    value: CurrencyFormatter.formatCompact(totalPortfolio)),
                style: (context.textStyles.displayMedium ??
                        const TextStyle(fontSize: 36))
                    .copyWith(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle,
                style: context.textStyles.bodySmall
                    ?.withColor(AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class AccountPortfolioCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? balanceText;
  final String totalExpensesText;
  final bool eyeHidden;
  final VoidCallback onToggleEye;
  final bool showBalance;

  const AccountPortfolioCard({
    super.key,
    required this.title,
    required this.icon,
    required this.balanceText,
    required this.totalExpensesText,
    required this.eyeHidden,
    required this.onToggleEye,
    required this.showBalance,
  });

  @override
  Widget build(BuildContext context) {
    final totalLabel = title.toLowerCase() == 'business'
        ? 'Total business expenses'
        : 'Total expenses';

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10))),
                  child: Icon(icon, color: AppColors.credTeal, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(title,
                        style: context.textStyles.titleMedium?.semiBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                  onPressed: onToggleEye,
                  tooltip:
                      eyeHidden ? 'Show $title amounts' : 'Hide $title amounts',
                  icon: Icon(
                      eyeHidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showBalance && (balanceText != null)) ...[
              Text('Current balance',
                  style: context.textStyles.bodySmall
                      ?.withColor(AppColors.textSecondary)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  balanceText!,
                  style: (context.textStyles.headlineSmall?.semiBold ??
                          const TextStyle(fontWeight: FontWeight.w700))
                      .copyWith(color: Theme.of(context).colorScheme.onSurface),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(totalLabel,
                style: context.textStyles.bodySmall
                    ?.withColor(AppColors.textSecondary)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(totalExpensesText,
                  style: (context.textStyles.titleMedium?.semiBold ??
                          const TextStyle(fontWeight: FontWeight.w600))
                      .withColor(AppColors.lossRed),
                  maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class SingleAccountHeroCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String balanceText;
  final String totalExpensesText;

  const SingleAccountHeroCard({
    super.key,
    required this.title,
    required this.icon,
    required this.balanceText,
    required this.totalExpensesText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.credTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(icon, color: AppColors.credTeal, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(title,
                        style: context.textStyles.titleLarge?.semiBold)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Current balance',
                style: context.textStyles.bodySmall
                    ?.withColor(AppColors.textSecondary)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(balanceText,
                  style: (context.textStyles.displaySmall ??
                          const TextStyle(fontSize: 28))
                      .copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                  maxLines: 1),
            ),
            const SizedBox(height: 12),
            Text('Total expenses (cycle)',
                style: context.textStyles.bodySmall
                    ?.withColor(AppColors.textSecondary)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(totalExpensesText,
                  style: (context.textStyles.headlineSmall?.semiBold ??
                          const TextStyle(fontWeight: FontWeight.w600))
                      .withColor(AppColors.lossRed),
                  maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountSummarySection extends StatelessWidget {
  final ExpenseAccountFilter filter;
  final double personalSpent;
  final double businessSpent;
  final bool personalHidden;
  final bool businessHidden;
  final VoidCallback onTogglePersonalHidden;
  final VoidCallback onToggleBusinessHidden;

  const AccountSummarySection({
    super.key,
    required this.filter,
    required this.personalSpent,
    required this.businessSpent,
    required this.personalHidden,
    required this.businessHidden,
    required this.onTogglePersonalHidden,
    required this.onToggleBusinessHidden,
  });

  @override
  Widget build(BuildContext context) {
    final totalPortfolio = personalSpent + businessSpent;

    if (filter == ExpenseAccountFilter.all) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AccountAmountCard(
                  title: 'Personal',
                  icon: Icons.person_rounded,
                  amountText: _maybeMask(
                      hide: personalHidden,
                      value: CurrencyFormatter.formatCompact(personalSpent)),
                  amountColor: AppColors.lossRed,
                  eyeHidden: personalHidden,
                  onToggleEye: onTogglePersonalHidden,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AccountAmountCard(
                  title: 'Business',
                  icon: Icons.business_center_rounded,
                  amountText: _maybeMask(
                      hide: businessHidden,
                      value: CurrencyFormatter.formatCompact(businessSpent)),
                  amountColor: AppColors.lossRed,
                  eyeHidden: businessHidden,
                  onToggleEye: onToggleBusinessHidden,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  const Icon(Icons.pie_chart_rounded,
                      color: AppColors.credTeal, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Total Portfolio',
                          style: context.textStyles.bodyMedium
                              ?.withColor(AppColors.textSecondary))),
                  Text(CurrencyFormatter.formatCompact(totalPortfolio),
                      style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final isPersonal = filter == ExpenseAccountFilter.personal;
    final title = isPersonal ? 'Personal' : 'Business';
    final icon =
        isPersonal ? Icons.person_rounded : Icons.business_center_rounded;
    final eyeHidden = isPersonal ? personalHidden : businessHidden;
    final amount = isPersonal ? personalSpent : businessSpent;
    final onToggle =
        isPersonal ? onTogglePersonalHidden : onToggleBusinessHidden;

    return AccountAmountCard(
      title: title,
      icon: icon,
      amountText: _maybeMask(
          hide: eyeHidden, value: CurrencyFormatter.formatCompact(amount)),
      amountColor: AppColors.lossRed,
      eyeHidden: eyeHidden,
      onToggleEye: onToggle,
      showEye: false, // top bar already controls hide for single-account views
    );
  }
}

class AccountAmountCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String amountText;
  final Color amountColor;
  final bool eyeHidden;
  final VoidCallback onToggleEye;
  final bool showEye;

  const AccountAmountCard({
    super.key,
    required this.title,
    required this.icon,
    required this.amountText,
    required this.amountColor,
    required this.eyeHidden,
    required this.onToggleEye,
    this.showEye = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.credTeal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Icon(icon, color: AppColors.credTeal, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(title,
                        style: context.textStyles.titleMedium?.semiBold)),
                if (showEye)
                  IconButton(
                    onPressed: onToggleEye,
                    tooltip: eyeHidden
                        ? 'Show $title amounts'
                        : 'Hide $title amounts',
                    icon: Icon(
                        eyeHidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Expenses (cycle)',
                style: context.textStyles.bodySmall
                    ?.withColor(AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text(amountText,
                style: (context.textStyles.headlineMedium?.extraBold ??
                        const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 22))
                    .withColor(amountColor)),
          ],
        ),
      ),
    );
  }
}

class SalaryOverviewCard extends StatelessWidget {
  final double personalSalary;
  final double businessIncome;
  final double deductions;
  final double remaining;
  final double totalExpenses;
  final bool hideAmounts;
  final VoidCallback onEdit;
  final bool showTotalExpenses;
  final bool showPersonalSalary;
  final bool showBusinessIncome;

  const SalaryOverviewCard({
    super.key,
    required this.personalSalary,
    required this.businessIncome,
    required this.deductions,
    required this.remaining,
    required this.totalExpenses,
    required this.hideAmounts,
    required this.onEdit,
    this.showTotalExpenses = true,
    this.showPersonalSalary = true,
    this.showBusinessIncome = true,
  });

  @override
  Widget build(BuildContext context) {
    final available =
        (showPersonalSalary ? (personalSalary - deductions) : 0.0) +
            (showBusinessIncome ? businessIncome : 0.0);
    final ratio = available > 0 ? (remaining / available) : null;

    final bool showAlert;
    final Color alertColor;
    final IconData alertIcon;
    final String? alertText;

    if (available <= 0) {
      showAlert = false;
      alertColor = AppColors.textSecondary;
      alertIcon = Icons.info_outline_rounded;
      alertText = null;
    } else if (remaining < 0) {
      showAlert = true;
      alertColor = AppColors.lossRed;
      alertIcon = Icons.error_outline_rounded;
      alertText =
          'Budget exceeded by ${CurrencyFormatter.formatCompact(-remaining)}';
    } else if (ratio != null && ratio <= 0.10) {
      showAlert = true;
      alertColor = AppColors.lossRed;
      alertIcon = Icons.warning_amber_rounded;
      final pct = (ratio * 100).clamp(0, 100).toStringAsFixed(0);
      alertText = 'Critical: $pct% remaining';
    } else if (ratio != null && ratio <= 0.20) {
      showAlert = true;
      alertColor = Colors.amber;
      alertIcon = Icons.warning_amber_rounded;
      final pct = (ratio * 100).clamp(0, 100).toStringAsFixed(0);
      alertText = 'Warning: $pct% remaining';
    } else {
      showAlert = false;
      alertColor = AppColors.textSecondary;
      alertIcon = Icons.info_outline_rounded;
      alertText = null;
    }

    final remainingColor = remaining < 0
        ? AppColors.lossRed
        : (showAlert ? alertColor : AppColors.profitGreen);

    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Salary / Income',
                        style: context.textStyles.titleMedium?.semiBold)),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit salary & income',
                  icon: const Icon(Icons.edit_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (showPersonalSalary) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Personal Salary',
                      style: context.textStyles.bodyMedium
                          ?.withColor(AppColors.textSecondary)),
                  Text(
                      _maybeMask(
                          hide: hideAmounts,
                          value: CurrencyFormatter.format(personalSalary)),
                      style: context.textStyles.titleLarge?.semiBold),
                ],
              ),
            ],
            if (showPersonalSalary && showBusinessIncome)
              const SizedBox(height: 10),
            if (showBusinessIncome) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Business Income',
                      style: context.textStyles.bodyMedium
                          ?.withColor(AppColors.textSecondary)),
                  Text(
                      _maybeMask(
                          hide: hideAmounts,
                          value: CurrencyFormatter.format(businessIncome)),
                      style: context.textStyles.titleLarge?.semiBold),
                ],
              ),
            ],
            if (showTotalExpenses) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Expenses (cycle)',
                      style: context.textStyles.bodyMedium
                          ?.withColor(AppColors.textSecondary)),
                  Text(
                      hideAmounts
                          ? _maskCurrency()
                          : '- ${CurrencyFormatter.format(totalExpenses)}',
                      style: context.textStyles.titleMedium
                          ?.withColor(AppColors.lossRed)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fixed Deductions',
                    style: context.textStyles.bodyMedium
                        ?.withColor(AppColors.textSecondary)),
                Text(
                    hideAmounts
                        ? _maskCurrency()
                        : deductions > 0
                            ? '- ${CurrencyFormatter.format(deductions)}'
                            : 'No fixed deductions added',
                    style: context.textStyles.titleMedium?.withColor(
                        deductions > 0
                            ? AppColors.lossRed
                            : AppColors.textSecondary)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                    child: Text('Remaining',
                        style: context.textStyles.headlineSmall?.semiBold)),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _maybeMask(
                          hide: hideAmounts,
                          value: CurrencyFormatter.formatCompact(remaining)),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: context.textStyles.displayLarge
                          ?.withColor(remainingColor),
                    ),
                  ),
                ),
              ],
            ),
            if (showAlert && alertText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: AppSpacing.paddingSm,
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: alertColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(alertIcon, color: alertColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(alertText,
                            style: context.textStyles.bodySmall
                                ?.withColor(alertColor))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EditIncomeSheet extends StatefulWidget {
  final UserModel user;
  final BuildContext rootContext;

  const EditIncomeSheet(
      {super.key, required this.user, required this.rootContext});

  @override
  State<EditIncomeSheet> createState() => _EditIncomeSheetState();
}

class _EditIncomeSheetState extends State<EditIncomeSheet> {
  late final TextEditingController _personalController;
  late final TextEditingController _businessController;
  late final TextEditingController _deductionsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _personalController = TextEditingController(
        text: widget.user.personalSalary.toStringAsFixed(0));
    _businessController = TextEditingController(
        text: widget.user.businessIncome.toStringAsFixed(0));
    _deductionsController = TextEditingController(
        text: widget.user.fixedDeductions.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _personalController.dispose();
    _businessController.dispose();
    _deductionsController.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final messenger = ScaffoldMessenger.of(widget.rootContext);

    final personal = _parseAmount(_personalController.text) ?? 0.0;
    if (personal < 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Personal Salary cannot be negative.')));
      return;
    }

    final business = _parseAmount(_businessController.text) ?? 0.0;
    if (business < 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Business Income cannot be negative.')));
      return;
    }

    final deductions = _parseAmount(_deductionsController.text) ?? 0.0;
    if (deductions < 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Fixed deductions cannot be negative.')));
      return;
    }

    if (personal == 0 && business == 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Enter a Personal Salary or Business Income greater than 0.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Update existing users/{uid} document (docId = uid). No duplicates.
      final updated = widget.user.copyWith(
        monthlySalary: personal, // keep legacy field in sync
        personalSalary: personal,
        businessIncome: business,
        fixedDeductions: deductions,
      );
      await UserService().updateUser(updated);

      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Income updated')));
    } catch (e, st) {
      debugPrint('Edit income save failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Failed to update. Please try again.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                      child: Text('Edit Salary / Income',
                          style: context.textStyles.headlineSmall?.semiBold)),
                  IconButton(
                    onPressed: _isSaving ? null : () => context.pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _personalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Personal Salary',
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixIcon:
                        Icon(Icons.person_rounded, color: AppColors.credTeal)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _businessController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Business Income',
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.business_center_rounded,
                        color: AppColors.credTeal)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _deductionsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Fixed Deductions (EMI, rent, insurance, SIP)',
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.receipt_long_outlined,
                        color: AppColors.credTeal)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.darkBackground))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAccountSheet extends StatelessWidget {
  final UserModel user;

  const _UserAccountSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final phone = user.phoneNumber?.trim();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.credTeal,
                    child: Icon(Icons.person_rounded,
                        color: AppColors.darkBackground),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        user.displayName?.trim().isNotEmpty == true
                            ? user.displayName!.trim()
                            : 'My account',
                        style: context.textStyles.headlineSmall?.semiBold),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _AccountInfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email),
              const SizedBox(height: 12),
              _AccountInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: phone?.isNotEmpty == true ? phone! : 'Not added'),
              const SizedBox(height: 12),
              _AccountInfoRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'User ID',
                  value: user.uid),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AccountInfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.credTeal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.textStyles.bodySmall
                        ?.withColor(AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodyMedium?.semiBold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSettingsSheet extends StatefulWidget {
  final UserModel user;
  final ValueChanged<bool> onSetPersonalEnabled;
  final ValueChanged<bool> onSetBusinessEnabled;

  const _AccountSettingsSheet(
      {required this.user,
      required this.onSetPersonalEnabled,
      required this.onSetBusinessEnabled});

  @override
  State<_AccountSettingsSheet> createState() => _AccountSettingsSheetState();
}

class _AccountSettingsSheetState extends State<_AccountSettingsSheet> {
  late bool _personalEnabled;
  late bool _businessEnabled;

  @override
  void initState() {
    super.initState();
    _personalEnabled = widget.user.personalAccountEnabled;
    _businessEnabled = widget.user.businessAccountEnabled;
  }

  Future<void> _togglePersonal(bool v) async {
    if (!v && !_businessEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('At least one account must stay enabled.')));
      return;
    }
    setState(() => _personalEnabled = v);
    widget.onSetPersonalEnabled(v);
  }

  Future<void> _toggleBusiness(bool v) async {
    if (!v && !_personalEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('At least one account must stay enabled.')));
      return;
    }
    setState(() => _businessEnabled = v);
    widget.onSetBusinessEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                      child: Text('Account settings',
                          style: context.textStyles.headlineSmall?.semiBold)),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Disable an account to hide it from the ALL view and exclude it from totals & calculations.',
                style: context.textStyles.bodyMedium
                    ?.withColor(AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _personalEnabled,
                        onChanged: _togglePersonal,
                        title: Text('Personal',
                            style: context.textStyles.titleMedium?.semiBold),
                        subtitle: Text(
                            'Show Personal card and include Personal expenses in ALL totals.',
                            style: context.textStyles.bodySmall
                                ?.withColor(AppColors.textSecondary)),
                        secondary: const Icon(Icons.person_rounded,
                            color: AppColors.credTeal),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 18),
                      SwitchListTile(
                        value: _businessEnabled,
                        onChanged: _toggleBusiness,
                        title: Text('Business',
                            style: context.textStyles.titleMedium?.semiBold),
                        subtitle: Text(
                            'Show Business card and include Business expenses in ALL totals.',
                            style: context.textStyles.bodySmall
                                ?.withColor(AppColors.textSecondary)),
                        secondary: const Icon(Icons.business_center_rounded,
                            color: AppColors.credTeal),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  if (!_personalEnabled && !_businessEnabled) return;
                  context.pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailySpendCard extends StatelessWidget {
  final double dailyLimit;
  final double daysLeft;
  final bool hideAmounts;

  const DailySpendCard(
      {super.key,
      required this.dailyLimit,
      required this.daysLeft,
      required this.hideAmounts});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.credTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.credTeal, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Spend Limit',
                      style: context.textStyles.bodyMedium
                          ?.withColor(AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _maybeMask(
                        hide: hideAmounts,
                        value: CurrencyFormatter.formatCompact(dailyLimit)),
                    style: (context.textStyles.headlineMedium?.extraBold ??
                            const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 22))
                        .withColor(AppColors.credTeal),
                  ),
                ],
              ),
            ),
            Text('${daysLeft.toInt()} days left',
                style: context.textStyles.bodySmall
                    ?.withColor(AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final ExpenseEntry entry;
  final bool hideAmounts;
  final bool canDelete;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;

  const ExpenseTile(
      {super.key,
      required this.entry,
      required this.hideAmounts,
      this.canDelete = false,
      this.onEdit,
      this.onDelete});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _categoryStyle(entry.category);
    final typeBadge =
        entry.accountType.toLowerCase() == 'business' ? 'Business' : 'Personal';

    final tile = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        dense: true,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(entry.category.toUpperCase(),
                    style: context.textStyles.titleMedium,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(typeBadge,
                  style: (context.textStyles.labelSmall?.semiBold ??
                          const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12))
                      .withColor(AppColors.textSecondary)),
            ),
          ],
        ),
        subtitle: Text(
            entry.note ?? (entry.source == 'ai' ? 'AI expense' : 'Expense'),
            style: context.textStyles.bodySmall
                ?.withColor(AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    hideAmounts
                        ? _maskCurrency()
                        : '₹${entry.amount.toStringAsFixed(0)}',
                    style: (context.textStyles.titleLarge?.semiBold ??
                            const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 18))
                        .withColor(AppColors.lossRed)),
                Text(DateFormat('MMM dd').format(entry.date),
                    style: context.textStyles.bodySmall
                        ?.withColor(AppColors.textSecondary)),
              ],
            ),
            if (canDelete && onDelete != null) ...[
              const SizedBox(width: 4),
              if (onEdit != null)
                IconButton(
                  constraints:
                      const BoxConstraints.tightFor(width: 34, height: 34),
                  padding: EdgeInsets.zero,
                  tooltip: 'Edit expense',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded,
                      color: AppColors.textSecondary),
                ),
              IconButton(
                constraints:
                    const BoxConstraints.tightFor(width: 34, height: 34),
                padding: EdgeInsets.zero,
                tooltip: 'Delete expense',
                onPressed: () async {
                  final shouldDelete = await showModalBottomSheet<bool>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (sheetContext) =>
                        _DeleteExpenseConfirmSheet(entry: entry),
                  );
                  if (shouldDelete == true) await onDelete!.call();
                },
                icon: Icon(Icons.delete_rounded,
                    color: AppColors.lossRed.withValues(alpha: 0.90)),
              ),
            ],
          ],
        ),
      ),
    );

    if (!canDelete || onDelete == null) return tile;

    return Dismissible(
      key: ValueKey('expense_${entry.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final shouldDelete = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => _DeleteExpenseConfirmSheet(entry: entry),
        );
        if (shouldDelete != true) return false;
        await onDelete!.call();
        return true;
      },
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.lossRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.lossRed.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_rounded,
                color: AppColors.lossRed.withValues(alpha: 0.95)),
            const SizedBox(width: 8),
            Text('Delete',
                style: (context.textStyles.titleSmall?.semiBold ??
                        const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14))
                    .withColor(AppColors.lossRed)),
          ],
        ),
      ),
      child: tile,
    );
  }

  (IconData, Color) _categoryStyle(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return (Icons.restaurant_rounded, Colors.amber);
      case 'snacks':
        return (Icons.local_cafe_rounded, Colors.amber);
      case 'travel':
        return (Icons.directions_car_rounded, Colors.green);
      case 'bills':
        return (Icons.receipt_long_rounded, Colors.blue);
      case 'shopping':
        return (Icons.shopping_bag_rounded, Colors.purple);
      case 'fun':
        return (Icons.celebration_rounded, Colors.orange);
      case 'health':
        return (Icons.favorite_rounded, Colors.red);
      default:
        return (Icons.more_horiz_rounded, AppColors.textSecondary);
    }
  }
}

class _DeleteExpenseConfirmSheet extends StatelessWidget {
  final ExpenseEntry entry;

  const _DeleteExpenseConfirmSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                      child: Text('Delete expense?',
                          style: context.textStyles.headlineSmall?.semiBold)),
                  IconButton(
                    onPressed: () => context.pop(false),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently remove this expense.',
                style: context.textStyles.bodyMedium
                    ?.withColor(AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.category.toUpperCase(),
                              style: context.textStyles.titleSmall?.semiBold),
                          const SizedBox(height: 2),
                          Text(
                              '₹${entry.amount.toStringAsFixed(0)} • ${DateFormat('MMM dd').format(entry.date)}',
                              style: context.textStyles.bodySmall
                                  ?.withColor(AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.pop(true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lossRed,
                          foregroundColor: AppColors.textPrimary),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyTransactionsState extends StatelessWidget {
  const EmptyTransactionsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('No expenses yet',
                style: context.textStyles.headlineSmall
                    ?.withColor(AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Add your first expense to get started',
                style: context.textStyles.bodyMedium
                    ?.withColor(AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class AddTransactionSheet extends StatefulWidget {
  final UserModel user;
  final BuildContext rootContext;
  final ExpenseAccountFilter accountContext;
  final ExpenseEntry? entry;

  const AddTransactionSheet(
      {super.key,
      required this.user,
      required this.rootContext,
      required this.accountContext,
      this.entry});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  final List<String> _categories = const [
    'Food',
    'Snacks',
    'Travel',
    'Bills',
    'Shopping',
    'Fun',
    'Health'
  ];
  String _selectedCategory = 'Food';
  String _accountType = '';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;
    if (entry != null) {
      _amountController.text =
          entry.amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
      _noteController.text = entry.note ?? '';
      _selectedCategory = entry.category;
      _accountType = entry.accountType.toLowerCase();
      _selectedDate = entry.date;
    }

    final personalEnabled = widget.user.personalAccountEnabled;
    final businessEnabled = widget.user.businessAccountEnabled;

    final fixed = widget.accountContext.fixedAccountType;
    if (fixed != null) {
      if (fixed == 'personal' && !personalEnabled) {
        _accountType = businessEnabled ? 'business' : '';
      } else if (fixed == 'business' && !businessEnabled) {
        _accountType = personalEnabled ? 'personal' : '';
      } else {
        _accountType = fixed;
      }
      return;
    }

    if (entry != null) return;

    if (widget.accountContext == ExpenseAccountFilter.all) {
      if (personalEnabled && !businessEnabled) {
        _accountType = 'personal';
      } else if (!personalEnabled && businessEnabled) {
        _accountType = 'business';
      } else {
        _accountType = 'personal';
      }
    }
  }

  Future<void> _saveExpense() async {
    if (_isSaving) return;

    final messenger = ScaffoldMessenger.of(widget.rootContext);

    final rawAmount = _amountController.text.trim();
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Please enter an amount greater than 0.')));
      return;
    }

    if (_selectedCategory.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please select a category.')));
      return;
    }

    if (_accountType.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please select Personal or Business.')));
      return;
    }

    if (_accountType == 'personal' && !widget.user.personalAccountEnabled) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Personal account is disabled. Enable it from Account settings.')));
      return;
    }

    if (_accountType == 'business' && !widget.user.businessAccountEnabled) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Business account is disabled. Enable it from Account settings.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = widget.user.uid;
      final note = _noteController.text.trim();
      final dateOnly =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      final expenseData = <String, dynamic>{
        'amount': amount,
        'category': _selectedCategory,
        'accountType': _accountType,
        'source': 'manual',
        'date': Timestamp.fromDate(dateOnly),
      };
      if (note.isNotEmpty) expenseData['note'] = note;

      final expenses = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('expenses');
      if (widget.entry == null) {
        expenseData['createdAt'] = FieldValue.serverTimestamp();
        await expenses.add(expenseData);
      } else {
        await expenses.doc(widget.entry!.id).update(expenseData);
      }

      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(widget.entry == null
              ? 'Expense added successfully'
              : 'Expense updated')));
    } catch (e, st) {
      debugPrint('Save expense failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
          content: Text('Failed to save expense. Please try again.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context)
                  .colorScheme
                  .copyWith(primary: AppColors.credTeal)),
          child: child ?? const SizedBox.shrink()),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateText = DateFormat('EEE, d MMM').format(_selectedDate);

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                      child: Text(
                          widget.entry == null ? 'Add Expense' : 'Edit Expense',
                          style: context.textStyles.headlineSmall?.semiBold)),
                  IconButton(
                    onPressed: () {
                      if (!context.mounted) return;
                      context.pop();
                    },
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.accountContext == ExpenseAccountFilter.all) ...[
                Text('Account Type',
                    style: context.textStyles.titleMedium?.semiBold),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: [
                    if (widget.user.personalAccountEnabled)
                      const ButtonSegment(
                          value: 'personal', label: Text('Personal')),
                    if (widget.user.businessAccountEnabled)
                      const ButtonSegment(
                          value: 'business', label: Text('Business')),
                  ],
                  selected: <String>{
                    _accountType.isEmpty
                        ? (widget.user.personalAccountEnabled
                            ? 'personal'
                            : 'business')
                        : _accountType,
                  },
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() => _accountType = s.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.credTeal;
                      }
                      return Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.darkBackground;
                      }
                      return AppColors.textPrimary;
                    }),
                    side: WidgetStateProperty.all(BorderSide(
                        color: Colors.white.withValues(alpha: 0.10))),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999))),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.currency_rupee_rounded,
                        color: AppColors.credTeal)),
              ),
              const SizedBox(height: 18),
              Text('Category', style: context.textStyles.titleMedium?.semiBold),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._categories,
                  if (!_categories.contains(_selectedCategory))
                    _selectedCategory
                ].map((c) {
                  final isSelected = _selectedCategory == c;
                  return ChoiceChip(
                    label: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(c)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = c),
                    selectedColor: AppColors.credTeal,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    showCheckmark: false,
                    labelStyle: (context.textStyles.bodyMedium?.semiBold ??
                            const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14))
                        .withColor(isSelected
                            ? AppColors.darkBackground
                            : AppColors.textPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color: Colors.white
                              .withValues(alpha: isSelected ? 0 : 0.10)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _noteController,
                textInputAction: TextInputAction.done,
                maxLength: 60,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Add a quick note…',
                    prefixIcon:
                        Icon(Icons.notes_rounded, color: AppColors.credTeal),
                    counterText: ''),
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
              ),
              const SizedBox(height: 18),
              Text('Date', style: context.textStyles.titleMedium?.semiBold),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: AppColors.credTeal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(dateText,
                              style: context.textStyles.bodyMedium?.semiBold)),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveExpense,
                      child: Text(widget.entry == null
                          ? 'Save Expense'
                          : 'Update Expense'))),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
