import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Privacy Policy',
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
              '1. Data We Collect',
              'To provide the best dating and messaging experience, we collect information you provide directly to us:\n\n'
              '• Account Info: Name, email, date of birth, gender, and interests.\n'
              '• Profile Media: Photos and videos you upload to your Aura.\n'
              '• Location Data: We process your location to show you nearby connections (with your permission).\n'
              '• Communication: Voice notes, messages, and game interactions are processed to enable realtime features.',
            ),
            _buildSection(
              '2. How We Use Your Data',
              'We use your information to:\n\n'
              '• Facilitate matches and discovery.\n'
              '• Enable realtime messaging and voice interactions.\n'
              '• Process premium subscriptions and Rizz+ features.\n'
              '• Improve our multiplayer game experiences.\n'
              '• Ensure platform safety through moderation and fraud prevention.',
            ),
            _buildSection(
              '3. Encryption & Security',
              'Security is at our core. We use industry-standard encryption for data transmission and storage. Your messages and voice notes are protected using secure protocols to ensure your private conversations stay private.',
            ),
            _buildSection(
              '4. Location & Permissions',
              'Our app requires certain permissions to function effectively:\n\n'
              '• Location: For discovery and distance-based matching.\n'
              '• Camera/Gallery: For profile verification and sharing media.\n'
              '• Microphone: For sending voice whispers.',
            ),
            _buildSection(
              '5. Data Retention & Deletion',
              'You have the right to access, correct, or delete your data at any time. When you delete your account, we remove your personal information from our active databases, subject to legal requirements.',
            ),
            _buildSection(
              '6. Third-Party Services',
              'We may use trusted third-party providers for payment processing (subscriptions), analytics, and cloud hosting. These partners are required to maintain strict data protection standards.',
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Questions? Contact us at support@delulu.app',
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
