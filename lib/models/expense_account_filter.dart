enum ExpenseAccountFilter { all, personal, business }

extension ExpenseAccountFilterX on ExpenseAccountFilter {
  String? get fixedAccountType {
    switch (this) {
      case ExpenseAccountFilter.personal:
        return 'personal';
      case ExpenseAccountFilter.business:
        return 'business';
      case ExpenseAccountFilter.all:
        return null;
    }
  }
}
