import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_guard/models/user_model.dart';
import 'package:pocket_guard/services/user_service.dart';
import 'package:pocket_guard/theme.dart';
import 'package:pocket_guard/utils/currency_formatter.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _salaryFormKey = GlobalKey<FormState>();
  final _salaryController = TextEditingController();
  final _pageController = PageController();

  int _pageIndex = 0;
  int _selectedDate = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _salaryController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_pageIndex == 0) {
      if (!_salaryFormKey.currentState!.validate()) return;
    }

    if (_pageIndex >= 2) return;

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goBack() async {
    if (_pageIndex <= 0) return;

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  double? _salaryValue() {
    final raw = _salaryController.text.trim().replaceAll(',', '');
    return double.tryParse(raw);
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;

    debugPrint('Onboarding: _completeOnboarding tapped. pageIndex=$_pageIndex selectedDate=$_selectedDate salaryRaw=${_salaryController.text}');

    // Don’t depend on the FormState here because the salary Form lives on another
    // PageView page and may not be mounted/active when the user taps Finish.
    final salary = _salaryValue();
    if (salary == null || salary <= 0) {
      debugPrint('Onboarding: salary invalid on finish; salary=$salary');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid salary.')),
        );
        await _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Onboarding: currentUser is null; cannot complete onboarding.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user signed in. Please log in again.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      debugPrint('Onboarding: building UserModel...');
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        phoneNumber: user.phoneNumber,
        monthlySalary: salary,
        personalSalary: salary,
        businessIncome: 0.0,
        salaryDate: _selectedDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('Onboarding: upserting user uid=${user.uid} salary=$salary salaryDate=$_selectedDate');
      await UserService().upsertUser(userModel);
      debugPrint('Onboarding: upsert complete; navigating to /home');
      if (!mounted) return;

      context.go('/home');
    } catch (e) {
      debugPrint('Onboarding: failed to complete onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save data: ${e.toString()}'), backgroundColor: AppColors.lossRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  AnimatedOpacity(
                    opacity: _pageIndex == 0 ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: IconButton(
                      onPressed: _pageIndex == 0 ? null : _goBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  Flexible(
                      child: OnboardingProgressDots(activeIndex: _pageIndex)),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  children: [
                    SalaryStep(
                      formKey: _salaryFormKey,
                      controller: _salaryController,
                      onNext: _goNext,
                    ),
                    SalaryDateStep(
                      selectedDay: _selectedDate,
                      onDaySelected: (day) =>
                          setState(() => _selectedDate = day),
                      onNext: _goNext,
                    ),
                    WelcomeStep(
                      salaryText: _salaryValue() == null
                          ? null
                          : CurrencyFormatter.formatCompact(_salaryValue()!),
                      dayOfMonth: _selectedDate,
                      isSaving: _isSaving,
                      onFinish: _isSaving ? null : _completeOnboarding,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingProgressDots extends StatelessWidget {
  final int activeIndex;
  const OnboardingProgressDots({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          height: 8,
          width: isActive ? 28 : 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.credTeal
                : AppColors.textSecondary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class OnboardingCardShell extends StatelessWidget {
  final Widget child;
  const OnboardingCardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: child,
      ),
    );
  }
}

class SalaryStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VoidCallback onNext;

  const SalaryStep(
      {super.key,
      required this.formKey,
      required this.controller,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Monthly salary',
                style: context.textStyles.displaySmall?.extraBold),
            const SizedBox(height: 10),
            Text(
              'Add your monthly take-home salary in INR. We’ll help you protect it with smarter budgeting.',
              style: context.textStyles.bodyMedium
                  ?.withColor(AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OnboardingCardShell(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Amount',
                        style: context.textStyles.titleLarge?.semiBold),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Enter salary',
                        prefixText: '₹ ',
                        prefixIcon: Icon(Icons.currency_rupee_outlined,
                            color: AppColors.credTeal),
                      ),
                      validator: (value) {
                        final v = value?.trim();
                        if (v == null || v.isEmpty) return 'Salary required';
                        final parsed = double.tryParse(v.replaceAll(',', ''));
                        if (parsed == null) return 'Invalid amount';
                        if (parsed <= 0) return 'Salary must be greater than 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: onNext,
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tip: You can change this later from Services.',
              style: context.textStyles.bodySmall
                  ?.withColor(AppColors.textSecondary.withValues(alpha: 0.9)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SalaryDateStep extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  final VoidCallback onNext;

  const SalaryDateStep(
      {super.key,
      required this.selectedDay,
      required this.onDaySelected,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Salary date',
                style: context.textStyles.displaySmall?.extraBold),
            const SizedBox(height: 10),
            Text(
              'Pick the day of the month your salary usually hits your account.',
              style: context.textStyles.bodyMedium
                  ?.withColor(AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OnboardingCardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: AppColors.credTeal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Selected: Day $selectedDay',
                          style: context.textStyles.titleLarge?.semiBold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(31, (index) {
                      final day = index + 1;
                      final isSelected = selectedDay == day;
                      return _OnboardingDayChip(
                        day: day,
                        isSelected: isSelected,
                        onTap: () => onDaySelected(day),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onNext,
                    child: const Text('Continue'),
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

class _OnboardingDayChip extends StatelessWidget {
  final int day;
  final bool isSelected;
  final VoidCallback onTap;

  const _OnboardingDayChip(
      {required this.day, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.credTeal : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? AppColors.credTeal
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Center(
          child: Text(
            '$day',
            style: context.textStyles.bodyMedium?.semiBold.withColor(
              isSelected ? AppColors.darkBackground : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeStep extends StatelessWidget {
  final String? salaryText;
  final int dayOfMonth;
  final bool isSaving;
  final VoidCallback? onFinish;

  const WelcomeStep(
      {super.key,
      required this.salaryText,
      required this.dayOfMonth,
      required this.isSaving,
      required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('All set', style: context.textStyles.displaySmall?.extraBold),
            const SizedBox(height: 10),
            Text(
              'Let’s lock in your salary plan and jump into your dashboard.',
              style: context.textStyles.bodyMedium
                  ?.withColor(AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OnboardingCardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.credTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: AppColors.credTeal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Let\'s Protect Your Salary',
                                style:
                                    context.textStyles.titleLarge?.extraBold),
                            const SizedBox(height: 4),
                            Text(
                              salaryText == null
                                  ? 'Salary + date saved in the next step.'
                                  : '$salaryText • Day $dayOfMonth every month',
                              style: context.textStyles.bodyMedium
                                  ?.withColor(AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: onFinish,
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Go to Dashboard'),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'You can edit salary & payday later in Services.',
              style: context.textStyles.bodySmall
                  ?.withColor(AppColors.textSecondary.withValues(alpha: 0.9)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
