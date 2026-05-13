import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.beVietnamPro(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(),
            const SizedBox(height: 24),
            _buildSection(
              '1. Eligibility',
              'By using Delulu, you confirm that:\n\n'
              '• You are at least 18 years of age.\n'
              '• You will not provide false information or impersonate others.\n'
              '• You are not a convicted sex offender or prohibited from using the platform under applicable law.',
            ),
            _buildSection(
              '2. User Conduct',
              'To keep Delulu safe and fun, the following behavior is strictly prohibited:\n\n'
              '• Harassment, bullying, or hate speech.\n'
              '• Sending sexually explicit or illegal content.\n'
              '• Scams, spamming, or commercial solicitation.\n'
              '• Sharing others\' private information without consent.\n'
              '• Creating multiple accounts for deceptive purposes.',
            ),
            _buildSection(
              '3. Messaging & Interactive Features',
              'Delulu provides realtime messaging, voice notes, and games. You are solely responsible for your interactions. While we provide safety tools (reporting/blocking), offline meetings are at your own risk. Use caution and follow our safety guidelines.',
            ),
            _buildSection(
              '4. Premium Subscriptions (Rizz+)',
              'Premium features are billed on a subscription basis. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Billing is handled through your respective App Store or Google Play account.',
            ),
            _buildSection(
              '5. Games & Entertainment',
              'Our in-app games (like Truth or Dare) are for entertainment purposes only. No real money gambling or rewards are involved. Play respectfully.',
            ),
            _buildSection(
              '6. Content Ownership & License',
              'You retain ownership of the content you post. However, by posting, you grant Delulu a worldwide, royalty-free license to host, store, and display your content to other users as part of the app service.',
            ),
            _buildSection(
              '7. Account Termination',
              'We reserve the right to suspend or terminate accounts that violate these terms, engage in fraudulent activity, or harm the community experience. Terminated accounts may lose access to premium features without refund.',
            ),
            _buildSection(
              '8. Limitation of Liability',
              'Delulu is provided "as is". We are not liable for user-generated content or interactions. You use the platform at your own discretion and risk.',
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'By using the app, you agree to these terms.',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: AppColors.outline.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Last Updated: May 13, 2026',
        style: GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.beVietnamPro(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            body,
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
