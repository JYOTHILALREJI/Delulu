import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: Interested in you, 1: Your interests

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Text(
                  _selectedTab == 0 ? 'Who Likes You' : 'You Liked',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.pinkButtonGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedTab == 0 ? '5 New' : '3 New',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Animated Tab Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTabBar(),
          ),
          
          const SizedBox(height: 16),

          // Animated Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                // Smooth Fade + slight upward slide
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                );
              },
              child: _selectedTab == 0 
                  ? _buildInterestedList(key: const ValueKey(0))
                  : _buildYourInterestsList(key: const ValueKey(1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha05,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.whiteAlpha05),
      ),
      child: Stack(
        children: [
          // Animated Sliding Background Indicator
          AnimatedAlign(
            alignment: _selectedTab == 0 ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purpleAccent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab Text Buttons
          Row(
            children: [
              _buildTabButton(0, 'Interested in You'),
              _buildTabButton(1, 'Your Interests'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.5,
              color: isActive ? AppColors.white : AppColors.textMuted,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  // --- Lists ---

  Widget _buildInterestedList({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('TODAY'),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'S', name: 'Scarlet', age: 23, time: '2 min ago', tags: const ['#Art', '#Midnight Walks'], bio: '"Your profile gave me butterflies."', isNew: true),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'L', name: 'Luna', age: 26, time: '18 min ago', tags: const ['#Vinyl', '#Poetry'], bio: '"We match on every interest. Say hi?"', isNew: true),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'A', name: 'Aria', age: 22, time: '1 hr ago', tags: const ['#Film', '#Coffee'], bio: '"I love your vibe. Let\'s explore the city."', isNew: true),
          const SizedBox(height: 28),
          _buildSectionLabel('THIS WEEK'),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'M', name: 'Maya', age: 25, time: '3 days ago', tags: const ['#Jazz', '#Travel'], bio: '"Your taste in music is impeccable."', isNew: false),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'E', name: 'Elena', age: 24, time: '5 days ago', tags: const ['#Architecture', '#Photography'], bio: '"Someone who gets light and shadow. Rare."', isNew: false),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildYourInterestsList({required Key key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('RECENTLY LIKED'),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'N', name: 'Nova', age: 24, time: '1 hr ago', tags: const ['#Philosophy', '#Art'], bio: '"Seeking a connection that transcends the visual."', isNew: true, isReversed: true),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'I', name: 'Iris', age: 27, time: '5 hr ago', tags: const ['#Sourdough', '#Vinyl'], bio: '"Let\'s talk about the books that changed us."', isNew: true, isReversed: true),
          const SizedBox(height: 14),
          _buildLikeCard(initial: 'C', name: 'Celeste', age: 23, time: 'Yesterday', tags: const ['#Jazz', '#Midnight Walks'], bio: '"Your playlist is a masterpiece."', isNew: false, isReversed: true),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- Components ---

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: AppColors.textDim,
      ),
    );
  }

  Widget _buildLikeCard({
    required String initial,
    required String name,
    required int age,
    required String time,
    required List<String> tags,
    required String bio,
    required bool isNew,
    bool isReversed = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.whiteAlpha05),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isNew
                            ? (isReversed 
                                ? [AppColors.purpleAccent, AppColors.pinkAccent] 
                                : [AppColors.pinkAccent, AppColors.purpleAccent])
                            : [AppColors.surfaceLight, AppColors.whiteAlpha10],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: isNew ? AppColors.white : AppColors.whiteAlpha40,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.greenGlow,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$name, $age',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.verifiedBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: isNew ? AppColors.pinkAccent.withOpacity(0.8) : AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isReversed ? Icons.favorite_rounded : Icons.favorite,
                color: isNew ? AppColors.pinkAccent : AppColors.whiteAlpha10,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.whiteAlpha05,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.whiteAlpha10),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.whiteAlpha60,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            bio,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.whiteAlpha60,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purpleAccent.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'CONNECT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.whiteAlpha05,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.whiteAlpha10),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.textDim,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}