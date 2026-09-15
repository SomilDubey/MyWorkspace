import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_guard/theme.dart';

class ServicesTab extends ConsumerWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Premium Services', style: context.textStyles.headlineMedium?.semiBold),
              const SizedBox(height: 12),
              _buildServiceCard(
                context,
                'Personal Loan',
                'Get instant loans up to ₹10 Lakhs',
                Icons.credit_score,
                AppColors.credTeal,
              ),
              _buildServiceCard(
                context,
                'Emergency Fund',
                'Build your financial safety net',
                Icons.savings_outlined,
                Colors.orange,
              ),
              _buildServiceCard(
                context,
                'Insurance',
                'Life & health insurance plans',
                Icons.health_and_safety_outlined,
                Colors.blue,
              ),
              _buildServiceCard(
                context,
                'Fund Manager',
                'Professional portfolio management',
                Icons.account_balance_outlined,
                Colors.green,
              ),
              _buildServiceCard(
                context,
                'Financial Advisor',
                'Expert financial planning',
                Icons.psychology_outlined,
                Colors.purple,
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'chatbot',
            onPressed: () => _showChatbot(context),
            backgroundColor: AppColors.credTeal,
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String description, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title service coming soon!'), backgroundColor: AppColors.credTeal),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textStyles.titleLarge?.extraBold),
                    const SizedBox(height: 4),
                    Text(description, style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatbot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChatbotSheet(),
    );
  }
}

class ChatbotSheet extends StatelessWidget {
  const ChatbotSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.credTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.smart_toy_outlined, color: AppColors.credTeal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('Financial Assistant', style: context.textStyles.headlineMedium?.semiBold),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: AppSpacing.paddingMd,
              children: [
                _buildChatOption(context, Icons.calculate_outlined, 'Budget Planning', 'Get help with monthly budgeting'),
                _buildChatOption(context, Icons.credit_card_outlined, 'Loan Help', 'Loan eligibility and options'),
                _buildChatOption(context, Icons.emergency_outlined, 'Emergency Fund', 'Build your emergency corpus'),
                _buildChatOption(context, Icons.security_outlined, 'Insurance', 'Find the right insurance plan'),
                _buildChatOption(context, Icons.trending_up_outlined, 'Investment Help', 'Smart investment strategies'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatOption(BuildContext context, IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.credTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.credTeal, size: 24),
        ),
        title: Text(title, style: context.textStyles.titleMedium?.semiBold),
        subtitle: Text(subtitle, style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title feature coming soon!'), backgroundColor: AppColors.credTeal),
          );
        },
      ),
    );
  }
}
