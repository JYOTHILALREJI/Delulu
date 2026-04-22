import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

enum NavTab { discovery, requests, chat, profile }

class BottomNavBar extends StatelessWidget {
  final NavTab selectedTab;
  final ValueChanged<NavTab> onTabChanged;

  const BottomNavBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: AppColors.whiteAlpha05),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'DISCOVERY',
                isActive: selectedTab == NavTab.discovery,
                onTap: () => onTabChanged(NavTab.discovery),
              ),
              _NavItem(
                icon: Icons.mail_outline,
                activeIcon: Icons.mail,
                label: 'REQUESTS',
                isActive: selectedTab == NavTab.requests,
                badge: 3,
                onTap: () => onTabChanged(NavTab.requests),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'CHAT',
                isActive: selectedTab == NavTab.chat,
                badge: 2,
                onTap: () => onTabChanged(NavTab.chat),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'PROFILE',
                isActive: selectedTab == NavTab.profile,
                onTap: () => onTabChanged(NavTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.purpleAccent : AppColors.textDim,
                size: 24,
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.pinkAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.5,
              color: isActive ? AppColors.purpleAccent : AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}