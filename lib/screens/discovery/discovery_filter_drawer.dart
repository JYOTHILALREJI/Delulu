import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import 'dart:convert';

class DiscoveryFilterDrawer extends StatefulWidget {
  final double currentMinAge;
  final double currentMaxAge;
  final double currentDistance;
  final Function(double min, double max, double dist) onApply;

  const DiscoveryFilterDrawer({
    super.key,
    required this.currentMinAge,
    required this.currentMaxAge,
    required this.currentDistance,
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
  double _dbMaxAge = 60;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _ageRange = RangeValues(widget.currentMinAge, widget.currentMaxAge);
    _distance = widget.currentDistance;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
          // Ensure current range is within bounds
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dismissible background
          GestureDetector(
            onTap: _close,
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.7,
                  margin: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.12),
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
                                Text(
                                  'FILTERS',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _close,
                                  icon: const Icon(Icons.close, color: Colors.white54),
                                )
                              ],
                            ),
                            const SizedBox(height: 40),
                            
                            _buildSectionHeader('AGE RANGE', '${_ageRange.start.round()} - ${_ageRange.end.round()}'),
                            const SizedBox(height: 16),
                            if (_isLoadingStats)
                              const Center(child: LinearProgressIndicator())
                            else
                              RangeSlider(
                                values: _ageRange,
                                min: _dbMinAge,
                                max: _dbMaxAge,
                                divisions: (_dbMaxAge - _dbMinAge).toInt(),
                                activeColor: AppColors.primary,
                                inactiveColor: Colors.white10,
                                onChanged: (val) => setState(() => _ageRange = val),
                              ),
                            
                            const SizedBox(height: 40),
                            
                            _buildSectionHeader('DISTANCE', '${_distance.round()} miles'),
                            const SizedBox(height: 16),
                            Slider(
                              value: _distance,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              activeColor: AppColors.primary,
                              inactiveColor: Colors.white10,
                              onChanged: (val) => setState(() => _distance = val),
                            ),
                            Text(
                              'Show people within a 20 mile range for better matches.',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                            ),
                            
                            const Spacer(),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  widget.onApply(_ageRange.start, _ageRange.end, _distance);
                                  _close();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'APPLY FILTERS',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _ageRange = RangeValues(_dbMinAge, _dbMaxAge);
                                    _distance = 100;
                                  });
                                },
                                child: Text(
                                  'RESET TO DEFAULT',
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold),
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

  Widget _buildSectionHeader(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: AppColors.primary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.beVietnamPro(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
