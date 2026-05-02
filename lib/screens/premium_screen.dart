import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/constants.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.stars, size: 80, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Premium Benefits',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildBenefit('Unlimited likes', 'Swipe without restrictions'),
            _buildBenefit('No ads', 'Ad-free experience'),
            _buildBenefit('Video & Audio Calls', 'Connect face-to-face'),
            _buildBenefit('End-to-End Encryption', 'Your privacy matters'),
            _buildBenefit('500MB file sharing', 'Share high-quality media'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement in-app purchase
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('In-app purchase coming soon')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Subscribe - \$9.99/month'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/profile-settings'),
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}