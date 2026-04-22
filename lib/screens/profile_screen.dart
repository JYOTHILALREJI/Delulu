import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _liveLocation = true;
  bool _incognito = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    const Text(
                      'Delulu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.notifications_outlined,
                        color: AppColors.whiteAlpha40, size: 22),
                    const SizedBox(width: 16),
                    const Icon(Icons.settings_outlined,
                        color: AppColors.whiteAlpha40, size: 22),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.whiteAlpha05),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.purpleAccent,
                                AppColors.pinkAccent
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alexander, 28',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'CURATING MOMENTS IN SILENCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: AppColors.pinkButtonGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.pinkAccent.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Unlock Delulu Noir',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONNECTION SETTINGS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Live Location',
                    trailing: _ToggleSwitch(
                      value: _liveLocation,
                      onChanged: (v) => setState(() => _liveLocation = v),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Controls',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textDim, size: 20),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.visibility_off_outlined,
                    title: 'Incognito Discovery',
                    subtitle: 'OFF',
                    trailing: _ToggleSwitch(
                      value: _incognito,
                      onChanged: (v) => setState(() => _incognito = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACCOUNT & SAFETY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.fingerprint,
                    title: 'Biometric Unlock',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textDim, size: 20),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.support_agent_outlined,
                    title: 'Concierge Support',
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textDim, size: 20),
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    titleColor: AppColors.rejectRed,
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textDim, size: 20),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'DELULU \u2014 VERSION 4.2.0 NOIR EDITION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  color: AppColors.textDim,
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.whiteAlpha05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.whiteAlpha40, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? AppColors.whiteAlpha60,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDim,
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value ? AppColors.purpleAccent : AppColors.whiteAlpha10,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.white : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}