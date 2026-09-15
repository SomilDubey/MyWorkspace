import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:pocket_guard/theme.dart';

class ChartsTab extends ConsumerStatefulWidget {
  const ChartsTab({super.key});

  @override
  ConsumerState<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends ConsumerState<ChartsTab> {
  String _selectedTimeframe = '1D';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NIFTY 50', style: context.textStyles.headlineMedium?.extraBold),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.profitGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text('+2.34%', style: context.textStyles.titleMedium?.semiBold.withColor(AppColors.profitGreen)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('₹21,450.75', style: context.textStyles.displayLarge?.withSize(36)),
          const SizedBox(height: 16),
          Row(
            children: ['1D', '1W', '1M', '1Y'].map((timeframe) {
              final isSelected = _selectedTimeframe == timeframe;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(timeframe),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedTimeframe = timeframe),
                  selectedColor: AppColors.credTeal,
                  labelStyle: context.textStyles.bodySmall?.semiBold.withColor(isSelected ? AppColors.darkBackground : AppColors.textPrimary),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Card(
            child: SizedBox(
              height: 400,
              child: Candlesticks(
                candles: _generateDummyCandles(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('AI Signals', style: context.textStyles.headlineMedium?.semiBold),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSignalChip(context, 'Breakout', AppColors.profitGreen),
              _buildSignalChip(context, 'Support Zone', AppColors.credTeal),
              _buildSignalChip(context, 'Averaging Zone', Colors.amber),
            ],
          ),
          const SizedBox(height: 24),
          Text('Market News', style: context.textStyles.headlineMedium?.semiBold),
          const SizedBox(height: 12),
          _buildNewsCard(context, 'Markets rally on strong Q4 earnings', '2 hours ago'),
          _buildNewsCard(context, 'RBI maintains repo rate at 6.5%', '5 hours ago'),
          _buildNewsCard(context, 'IT sector sees surge in global demand', '1 day ago'),
        ],
      ),
    );
  }

  List<Candle> _generateDummyCandles() {
    final now = DateTime.now();
    return List.generate(50, (index) {
      final date = now.subtract(Duration(days: 50 - index));
      final open = 21000 + (index * 10).toDouble();
      final close = open + (index % 2 == 0 ? 50 : -50);
      final high = open > close ? open + 30 : close + 30;
      final low = open < close ? open - 30 : close - 30;
      
      return Candle(
        date: date,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 1000000 + (index * 10000).toDouble(),
      );
    });
  }

  Widget _buildSignalChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: context.textStyles.bodyMedium?.semiBold.withColor(color)),
        ],
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, String title, String time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.credTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.article_outlined, color: AppColors.credTeal, size: 24),
        ),
        title: Text(title, style: context.textStyles.titleMedium),
        subtitle: Text(time, style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}
