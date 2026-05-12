import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class DeluluNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int whisperUnreadCount;
  final int pingsUnreadCount;

  const DeluluNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.whisperUnreadCount = 0,
    this.pingsUnreadCount = 0,
  });

  @override
  State<DeluluNavBar> createState() => _DeluluNavBarState();
}

class _DeluluNavBarState extends State<DeluluNavBar> {
  late List<GlobalKey> _itemKeys;
  final GlobalKey _stackKey = GlobalKey();
  List<Rect> _itemRects = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // 5 tabs now
    _itemKeys = List.generate(5, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMeasurements();
      setState(() => _ready = true);
    });
  }

  void _updateMeasurements() {
    final stackContext = _stackKey.currentContext;
    if (stackContext == null) return;
    final stackBox = stackContext.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    _itemRects = _itemKeys.map((key) {
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return Rect.zero;
      final offset = renderBox.localToGlobal(Offset.zero);
      final stackOffset = stackBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        offset.dx - stackOffset.dx,
        offset.dy - stackOffset.dy,
        renderBox.size.width,
        renderBox.size.height,
      );
    }).toList();
  }

  @override
  void didUpdateWidget(DeluluNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateMeasurements());
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.auto_awesome, label: 'Vibes'),
      _NavItem(icon: Icons.favorite_outline, label: 'Signals'),
      _NavItem(icon: Icons.person_add_outlined, label: 'Pings'),   // new tab
      _NavItem(icon: Icons.mark_unread_chat_alt_outlined, label: 'Whispers'),
      _NavItem(icon: Icons.spoke_outlined, label: 'Aura'),
    ];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),   // slightly smaller margins
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 25,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),  // tighter horizontal padding
            child: Stack(
              key: _stackKey,
              clipBehavior: Clip.none,
              children: [
                // Smooth sliding pill
                if (_ready && _itemRects.isNotEmpty)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    left: _itemRects[widget.currentIndex].left,
                    top: _itemRects[widget.currentIndex].top,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      width: _itemRects[widget.currentIndex].width,
                      height: _itemRects[widget.currentIndex].height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.primaryContainer.withValues(alpha: 0.18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                // Row of tappable items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isActive = widget.currentIndex == index;

                    return GestureDetector(
                      key: _itemKeys[index],
                      onTap: () => widget.onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,   // slightly less than before (was 12)
                          vertical: 5,      // slightly less (was 6)
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 19,
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                if ((index == 3 && widget.whisperUnreadCount > 0) || (index == 2 && widget.pingsUnreadCount > 0))
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.purple, // Requested purple circle
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        '${(index == 3 ? widget.whisperUnreadCount : widget.pingsUnreadCount) > 9 ? '9+' : (index == 3 ? widget.whisperUnreadCount : widget.pingsUnreadCount)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              style: GoogleFonts.inter(
                                fontSize: 9,                 // unchanged
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}