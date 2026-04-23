import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/animations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _messagePreviews = true;
  bool _incognito = false;
  bool _screenshotShield = true;
  bool _readReceipts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
                child: Row(
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_ios_new,
                      size: 18,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            StaggerReveal(
              staggerDelay: const Duration(milliseconds: 40),
              itemDuration: const Duration(milliseconds: 500),
              beginOffset: const Offset(0, 0.1),
              children: [
                // --- APPEARANCE ---
                _SectionTitle('APPEARANCE'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Mode',
                      subtitle: 'Always on',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purpleAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('NOIR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.purpleAccent, letterSpacing: 1)),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'App Theme',
                      subtitle: 'Purple Dusk',
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.purpleAccent, AppColors.pinkAccent]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.whiteAlpha20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- NOTIFICATIONS ---
                _SectionTitle('NOTIFICATIONS'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Push Notifications',
                      trailing: _ToggleSwitch(
                        value: _pushNotifications,
                        onChanged: (v) => setState(() => _pushNotifications = v),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'Message Previews',
                      trailing: _ToggleSwitch(
                        value: _messagePreviews,
                        onChanged: (v) => setState(() => _messagePreviews = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- PRIVACY & SECURITY ---
                _SectionTitle('PRIVACY & SECURITY'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.visibility_off_outlined,
                      title: 'Incognito Mode',
                      subtitle: _incognito ? 'ACTIVE' : 'OFF',
                      trailing: _ToggleSwitch(
                        value: _incognito,
                        onChanged: (v) => setState(() => _incognito = v),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.screenshot_monitor_outlined,
                      title: 'Screenshot Shield',
                      subtitle: 'Blurs app in recents',
                      trailing: _ToggleSwitch(
                        value: _screenshotShield,
                        onChanged: (v) => setState(() => _screenshotShield = v),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.done_all_outlined,
                      title: 'Read Receipts',
                      trailing: _ToggleSwitch(
                        value: _readReceipts,
                        onChanged: (v) => setState(() => _readReceipts = v),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.block_outlined,
                      title: 'Blocked Users',
                      trailing: const _Chevron(),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- DATA & STORAGE ---
                _SectionTitle('DATA & STORAGE'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.cleaning_services_outlined,
                      title: 'Clear Cache',
                      trailing: const _Chevron(),
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.download_outlined,
                      title: 'Download My Data',
                      trailing: const _Chevron(),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- SUPPORT & ABOUT ---
                _SectionTitle('SUPPORT & ABOUT'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      subtitle: '4.2.0 Noir Edition',
                      showDivider: true,
                    ),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      trailing: const _Chevron(),
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      trailing: const _Chevron(),
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.support_agent_outlined,
                      title: 'Concierge Support',
                      trailing: const _Chevron(),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- DANGER ZONE ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _DangerButton(
                        icon: Icons.logout,
                        label: 'Log Out',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 12),
                      _DangerButton(
                        icon: Icons.delete_forever_outlined,
                        label: 'Delete Account',
                        isDestructive: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Reusable Setting Components ---

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.textDim,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteAlpha05),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.whiteAlpha05, width: 1),
                ),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.whiteAlpha05,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.whiteAlpha60, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.whiteAlpha80,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                ],
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: value ? AppColors.buttonGradient : null,
          color: value ? null : AppColors.whiteAlpha10,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.white : AppColors.textDim,
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: AppColors.purpleAccent.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chevron_right, color: AppColors.textDim, size: 20);
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    this.size = 22,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.whiteAlpha05,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.whiteAlpha10),
        ),
        child: Icon(icon, color: AppColors.whiteAlpha60, size: size),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DangerButton({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.rejectRed : AppColors.whiteAlpha60;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDestructive 
              ? AppColors.rejectRed.withOpacity(0.1) 
              : AppColors.whiteAlpha05,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive 
                ? AppColors.rejectRed.withOpacity(0.2) 
                : AppColors.whiteAlpha10,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}