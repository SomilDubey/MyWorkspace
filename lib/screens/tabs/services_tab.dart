import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_guard/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ServicesTab extends ConsumerStatefulWidget {
  const ServicesTab({super.key});

  @override
  ConsumerState<ServicesTab> createState() => _ServicesTabState();
}

class _ProviderService {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String providerUrl;
  bool enabled = false;

  _ProviderService(this.title, this.description, this.icon, this.color, this.providerUrl);
}

class _ServicesTabState extends ConsumerState<ServicesTab> {
  final _services = <_ProviderService>[
    _ProviderService('Personal Loan', 'Compare lending partners and apply securely.', Icons.credit_score, AppColors.credTeal, 'https://www.bankbazaar.com/personal-loan.html'),
    _ProviderService('Emergency Fund', 'Build your financial safety net.', Icons.savings_outlined, Colors.orange, 'https://www.etmoney.com/'),
    _ProviderService('Insurance', 'Explore health and life insurance providers.', Icons.health_and_safety_outlined, Colors.blue, 'https://www.policybazaar.com/'),
    _ProviderService('Fund Manager', 'Connect with a professional investment partner.', Icons.account_balance_outlined, Colors.green, 'https://www.mfcentral.com/'),
    _ProviderService('Financial Advisor', 'Find a configurable advisory provider.', Icons.psychology_outlined, Colors.purple, 'https://www.sebi.gov.in/'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingMd,
      children: [
        Text('Premium Services', style: context.textStyles.headlineMedium?.semiBold),
        const SizedBox(height: 8),
        Text('Enable a provider before opening its service.', style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary)),
        const SizedBox(height: 12),
        ..._services.map((service) => _serviceCard(context, service)),
      ],
    );
  }

  Widget _serviceCard(BuildContext context, _ProviderService service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: service.color.withValues(alpha: .1), borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(service.icon, color: service.color, size: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(service.title, style: context.textStyles.titleMedium?.extraBold), const SizedBox(height: 4), Text(service.description, style: context.textStyles.bodySmall?.withColor(AppColors.textSecondary))])),
            Column(children: [Switch(value: service.enabled, onChanged: (value) => setState(() => service.enabled = value)), TextButton.icon(onPressed: service.enabled ? () => _openProvider(context, service) : null, icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Open'))]),
          ],
        ),
      ),
    );
  }

  Future<void> _openProvider(BuildContext context, _ProviderService service) async {
    final launched = await launchUrl(Uri.parse(service.providerUrl), mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open ${service.title} provider')));
    }
  }
}