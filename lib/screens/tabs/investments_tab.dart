import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_guard/theme.dart';
import 'package:pocket_guard/utils/currency_formatter.dart';

class InvestmentsTab extends ConsumerWidget {
  const InvestmentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dummy data for V1
    final totalInvested = 125000.0;
    final currentValue = 142500.0;
    final profitLoss = currentValue - totalInvested;
    final plPercent = (profitLoss / totalInvested) * 100;

    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortfolioSummaryCard(
            totalInvested: totalInvested,
            currentValue: currentValue,
            profitLoss: profitLoss,
            plPercent: plPercent,
          ),
          const SizedBox(height: 24),
          Text('Holdings', style: context.textStyles.headlineMedium?.semiBold),
          const SizedBox(height: 12),
          _buildHoldingCard(context, 'RELIANCE', 10, 2450.0, 2580.0),
          _buildHoldingCard(context, 'TCS', 5, 3200.0, 3450.0),
          _buildHoldingCard(context, 'INFY', 15, 1450.0, 1520.0),
          const SizedBox(height: 24),
          Text('Watchlist', style: context.textStyles.headlineMedium?.semiBold),
          const SizedBox(height: 12),
          _buildWatchlistCard(context, 'HDFC BANK', 1645.50, 2.3),
          _buildWatchlistCard(context, 'ICICI BANK', 1089.75, -1.2),
          const SizedBox(height: 24),
          Text('SIP Investments', style: context.textStyles.headlineMedium?.semiBold),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Monthly SIP', style: context.textStyles.titleLarge?.semiBold),
                      const Icon(Icons.edit_outlined, color: AppColors.credTeal, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount', style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary)),
                      Text('₹5,000', style: context.textStyles.titleMedium?.semiBold),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date', style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary)),
                      Text('5th of every month', style: context.textStyles.titleMedium?.semiBold),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: AppSpacing.paddingSm,
                    decoration: BoxDecoration(
                      color: AppColors.credTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outlined, color: AppColors.credTeal, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Amount will be auto-deducted from remaining salary',
                            style: context.textStyles.bodySmall?.withColor(AppColors.credTeal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHoldingCard(BuildContext context, String symbol, int qty, double avgPrice, double ltp) {
    final invested = qty * avgPrice;
    final current = qty * ltp;
    final pl = current - invested;
    final plPercent = (pl / invested) * 100;
    final isProfit = pl >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(symbol, style: context.textStyles.titleLarge?.extraBold),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isProfit ? AppColors.profitGreen : AppColors.lossRed).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${isProfit ? '+' : ''}${plPercent.toStringAsFixed(2)}%',
                    style: context.textStyles.bodySmall?.semiBold.withColor(isProfit ? AppColors.profitGreen : AppColors.lossRed),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qty: $qty', style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)),
                    Text('Avg: ₹${avgPrice.toStringAsFixed(2)}', style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LTP: ₹${ltp.toStringAsFixed(2)}', style: context.textStyles.bodyMedium?.semiBold),
                    Text(
                      'P&L: ₹${pl.toStringAsFixed(2)}',
                      style: context.textStyles.bodyMedium?.semiBold.withColor(isProfit ? AppColors.profitGreen : AppColors.lossRed),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistCard(BuildContext context, String symbol, double price, double change) {
    final isPositive = change >= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.credTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.visibility_outlined, color: AppColors.credTeal, size: 24),
        ),
        title: Text(symbol, style: context.textStyles.titleMedium?.semiBold),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹${price.toStringAsFixed(2)}', style: context.textStyles.titleMedium?.semiBold),
            Text(
              '${isPositive ? '+' : ''}$change%',
              style: context.textStyles.bodySmall?.withColor(isPositive ? AppColors.profitGreen : AppColors.lossRed),
            ),
          ],
        ),
      ),
    );
  }
}

class PortfolioSummaryCard extends StatelessWidget {
  final double totalInvested;
  final double currentValue;
  final double profitLoss;
  final double plPercent;

  const PortfolioSummaryCard({
    super.key,
    required this.totalInvested,
    required this.currentValue,
    required this.profitLoss,
    required this.plPercent,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = profitLoss >= 0;

    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio Summary', style: context.textStyles.headlineSmall?.semiBold),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invested', style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.formatCompact(totalInvested), style: context.textStyles.headlineMedium?.semiBold),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Current', style: context.textStyles.bodyMedium?.withColor(AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.formatCompact(currentValue), style: context.textStyles.headlineMedium?.semiBold),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Overall P&L', style: context.textStyles.titleLarge?.semiBold),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatCompact(profitLoss),
                      style: context.textStyles.displayLarge?.withSize(32).withColor(isProfit ? AppColors.profitGreen : AppColors.lossRed),
                    ),
                    Text(
                      '${isProfit ? '+' : ''}${plPercent.toStringAsFixed(2)}%',
                      style: context.textStyles.titleMedium?.withColor(isProfit ? AppColors.profitGreen : AppColors.lossRed),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
