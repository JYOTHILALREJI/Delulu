import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/animations.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Custom Header for Profile Page
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.notifications_outlined,
                    color: AppColors.whiteAlpha40, size: 22),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.settings_outlined,
                      color: AppColors.whiteAlpha40, size: 22),
                ),
              ],
            ),
          ),
          
          // Scrollable Profile Content
          const Expanded(child: _ProfileContent()),
        ],
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          
          // --- Avatar Section ---
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.purpleAccent, AppColors.pinkAccent],
                  ),
                  border:
                      Border.all(color: AppColors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purpleAccent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.purpleAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // --- Name & Details ---
          const Text(
            'Alexander, 28',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'CURATING MOMENTS IN SILENCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.location_on_outlined,
                  color: AppColors.whiteAlpha40, size: 14),
              SizedBox(width: 4),
              Text(
                'New York, NY',
                style: TextStyle(
                    fontSize: 13, color: AppColors.whiteAlpha60),
              ),
              SizedBox(width: 16),
              Icon(Icons.verified, color: AppColors.verifiedBlue, size: 16),
              SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(
                    fontSize: 13, color: AppColors.verifiedBlue, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // --- Stats Section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('120', 'Liked'),
              _buildStat('45', 'Connects'),
              _buildStat('89%', 'Match'),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // --- About Me & Interests Card ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.whiteAlpha05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ABOUT ME',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Seeking someone who appreciates the silence between jazz notes as much as the music itself. I curate moments, not just photos.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.whiteAlpha60,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'INTERESTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textDim,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _InterestTag(label: '#Philosophy'),
                    _InterestTag(label: '#Art'),
                    _InterestTag(label: '#Jazz'),
                    _InterestTag(label: '#Vinyl'),
                    _InterestTag(label: '#Coffee'),
                    _InterestTag(label: '#Architecture'),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // --- Edit Profile Button ---
          Pressable(
            onTap: () {},
            child: GlowPulse(
              glowColor: AppColors.purpleAccent,
              maxRadius: 140,
              maxOpacity: 0.12,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purpleAccent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'EDIT PROFILE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _InterestTag extends StatelessWidget {
  final String label;
  const _InterestTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.whiteAlpha10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.whiteAlpha60,
        ),
      ),
    );
  }
}