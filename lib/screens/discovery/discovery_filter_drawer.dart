import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import 'dart:convert';
import '../premium/subscription_screen.dart';

class DiscoveryFilterDrawer extends StatefulWidget {
  final double currentMinAge;
  final double currentMaxAge;
  final double currentDistance;
  final bool isPremium;
  final Function(double min, double max, double dist) onApply;

  const DiscoveryFilterDrawer({
    super.key,
    required this.currentMinAge,
    required this.currentMaxAge,
    required this.currentDistance,
    required this.isPremium,
    required this.onApply,
  });

  @override
  State<DiscoveryFilterDrawer> createState() => _DiscoveryFilterDrawerState();
}

class _DiscoveryFilterDrawerState extends State<DiscoveryFilterDrawer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  late RangeValues _ageRange;
  late double _distance;
  
  double _dbMinAge = 18;
  double _dbMaxAge = 100;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _ageRange = RangeValues(widget.currentMinAge, widget.currentMaxAge);
    _distance = widget.isPremium ? widget.currentDistance : widget.currentDistance.clamp(1.0, 20.0);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await ApiService.getDiscoveryStats();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _dbMinAge = (data['min_age'] ?? 18).toDouble();
          _dbMaxAge = (data['max_age'] ?? 100).toDouble();
          if (_ageRange.start < _dbMinAge) _ageRange = RangeValues(_dbMinAge, _ageRange.end);
          if (_ageRange.end > _dbMaxAge) _ageRange = RangeValues(_ageRange.start, _dbMaxAge);
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    if (mounted) Navigator.pop(context);
  }

  void _showPremiumPrompt() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _close,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  height: MediaQuery.of(context).size.height * 0.85,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 50,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.7),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AURA',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                        color: AppColors.primary.withOpacity(0.7),
                                      ),
                                    ),
                                    Text(
                                      'Filters',
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: _close,
                                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 48),
                            
                            _buildSectionHeader(
                              'AGE RANGE', 
                              '${_ageRange.start.round()} - ${_ageRange.end.round()}',
                              Icons.cake_outlined,
                            ),
                            const SizedBox(height: 16),
                            if (_isLoadingStats)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: LinearProgressIndicator(backgroundColor: Colors.white10),
                              )
                            else
                              SliderTheme(
                                data: _modernSliderTheme(),
                                child: RangeSlider(
                                  values: _ageRange,
                                  min: _dbMinAge,
                                  max: _dbMaxAge,
                                  divisions: (_dbMaxAge - _dbMinAge).toInt().clamp(1, 100),
                                  onChanged: (val) => setState(() => _ageRange = val),
                                ),
                              ),
                            
                            const SizedBox(height: 48),
                            
                            Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      'DISTANCE', 
                                      _distance >= 500 ? 'Global' : '${_distance.round()} miles',
                                      Icons.location_on_outlined,
                                      isPremium: true,
                                    ),
                                    const SizedBox(height: 16),
                                    IgnorePointer(
                                      ignoring: !widget.isPremium,
                                      child: Opacity(
                                        opacity: widget.isPremium ? 1.0 : 0.4,
                                        child: SliderTheme(
                                          data: _modernSliderTheme(),
                                          child: Slider(
                                            value: _distance,
                                            min: 1,
                                            max: 500,
                                            divisions: 50,
                                            onChanged: (val) {
                                              if (!widget.isPremium && val > 20) {
                                                _showPremiumPrompt();
                                                return;
                                              }
                                              setState(() => _distance = val);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      widget.isPremium 
                                        ? 'Find real Delulus within ${_distance >= 500 ? 'the world' : '${_distance.round()} miles'}.'
                                        : 'Discovery distance is locked to 20 miles. Upgrade to Rizz+ to search globally!',
                                      style: GoogleFonts.inter(
                                        fontSize: 12, 
                                        color: Colors.white.withOpacity(0.3),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!widget.isPremium)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: _showPremiumPrompt,
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.bolt, color: Colors.amber, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'UNLOCK WITH RIZZ+',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.amber,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            const Spacer(),
                            
                            Container(
                              width: double.infinity,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  colors: [AppColors.tertiaryContainer, AppColors.primaryContainer],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  widget.onApply(_ageRange.start, _ageRange.end, _distance);
                                  _close();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                child: Text(
                                  'APPLY FILTERS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800, 
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  widget.onApply(_dbMinAge, _dbMaxAge, widget.isPremium ? 500 : 20);
                                  _close();
                                },
                                child: Text(
                                  'CLEAR ALL FILTERS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12, 
                                    color: Colors.white.withOpacity(0.4), 
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            )

                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliderThemeData _modernSliderTheme() {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: Colors.white.withOpacity(0.05),
      trackHeight: 6,
      thumbColor: Colors.white,
      overlayColor: AppColors.primary.withOpacity(0.2),
      rangeThumbShape: const RoundRangeSliderThumbShape(
        enabledThumbRadius: 10,
        elevation: 4,
      ),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 10,
        elevation: 4,
      ),
      trackShape: const RoundedRectSliderTrackShape(),
    );
  }

  Widget _buildSectionHeader(String title, String value, IconData icon, {bool isPremium = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary.withOpacity(0.7)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            if (isPremium) ...[
              const SizedBox(width: 6),
              const Icon(Icons.bolt, size: 14, color: Colors.amber),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.beVietnamPro(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
