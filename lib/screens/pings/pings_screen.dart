import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../profileRequest/profile_request_view_screen.dart';
import '../aura/public_aura_screen.dart';
import '../../components/delulu_wavy_loader.dart';

class PingsScreen extends StatefulWidget {
  const PingsScreen({super.key});

  @override
  State<PingsScreen> createState() => PingsScreenState();
}

class PingsScreenState extends State<PingsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  int _selectedCategory = 0; // 0: Slide-ins, 1: The Squad

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = _selectedCategory == 0 
          ? await ApiService.getPendingRequests()
          : await ApiService.getHistoryRequests();
      
      final body = jsonDecode(res.body);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(body['requests'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleCategory(int index) {
    if (_selectedCategory == index) return;
    setState(() {
      _selectedCategory = index;
    });
    fetchRequests();
  }

  // Group by date (same logic as SignalsScreen)
  List<Map<String, dynamic>> _groupByDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final req in _requests) {
      try {
        final createdAt = DateTime.parse(req['created_at']);
        final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        grouped.putIfAbsent(dateKey, () => []).add(req);
      } catch (_) {
        grouped.putIfAbsent('unknown', () => []).add(req);
      }
    }

    final List<Map<String, dynamic>> sortedGroups = grouped.entries.map((entry) {
      DateTime? date;
      if (entry.key != 'unknown') {
        final parts = entry.key.split('-');
        date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return {'date': date, 'requests': entry.value};
    }).toList();

    sortedGroups.sort((a, b) {
      final aDate = a['date'] as DateTime?;
      final bDate = b['date'] as DateTime?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sortedGroups;
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  Future<void> _accept(int requestId) async {
    await ApiService.acceptRequest(requestId);
    fetchRequests(); // refresh list
  }

  Future<void> _reject(int requestId) async {
    await ApiService.rejectRequest(requestId);
    fetchRequests();
  }

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(child: _buildToggleButton('Slide-ins', 0)),
          Expanded(child: _buildToggleButton('The Squad', 1)),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int index) {
    final isSelected = _selectedCategory == index;
    return GestureDetector(
      onTap: () => _toggleCategory(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected ? const LinearGradient(
            colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
          ) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_outlined, size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 0 ? 'No new pings yet' : 'No history yet',
            style: GoogleFonts.beVietnamPro(
              fontSize: 16, color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == 0 
                ? 'When someone connects, you\'ll see them here.'
                : 'Your connection history will appear here.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: AppColors.outline.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.person_add_outlined, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Pings',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 24, fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          _buildToggle(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isLoading
                ? const Center(
                    key: ValueKey('loading'),
                    child: DeluluWavyLoader(),
                  )
                : (_requests.isEmpty
                    ? SizedBox(
                        key: const ValueKey('empty'),
                        child: _buildEmptyState(),
                      )
                    : RefreshIndicator(
                        key: ValueKey('list_$_selectedCategory'),
                        onRefresh: fetchRequests,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final group = grouped[index];
                            final date = group['date'] as DateTime?;
                            final reqs = group['requests'] as List<Map<String, dynamic>>;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
                                  child: Text(
                                    _dateLabel(date),
                                    style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2, color: AppColors.primaryContainer,
                                    ),
                                  ),
                                ),
                                ...reqs.map((req) => RequestCard(
                                  request: req,
                                  isHistory: _selectedCategory == 1,
                                  onAccept: () => _accept(req['request_id'] as int),
                                  onReject: () => _reject(req['request_id'] as int),
                                )),
                                const SizedBox(height: 4),
                              ],
                            );
                          },
                        ),
                      )),
            ),
          ),
        ],
      ),
    );
  }
}

class RequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isHistory;

  const RequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
    this.isHistory = false,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _isBioExpanded = false;

  @override
  Widget build(BuildContext context) {
    final sender = widget.request['sender'] as Map<String, dynamic>;
    final photos = List<Map<String, dynamic>>.from(sender['photos'] ?? []);
    final primaryPhoto = photos.isNotEmpty 
        ? photos.firstWhere((p) => p['is_primary'] == true, orElse: () => photos[0])
        : null;
    final imageUrl = primaryPhoto?['url'];
    final interests = List<String>.from(sender['interests'] ?? []);
    final requestId = widget.request['request_id'] as int;
    final bio = sender['bio'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Photo - Clicking opens profile
              GestureDetector(
                onTap: () {
                  if (widget.isHistory) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicAuraScreen(userId: sender['id']),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileRequestViewScreen(
                          requestId: requestId,
                          profile: sender,
                          onAccept: widget.onAccept,
                          onReject: widget.onReject,
                        ),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 70, height: 70,
                    color: AppColors.surfaceContainerHigh,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? (imageUrl.startsWith('data:image')
                            ? Image.memory(base64Decode(imageUrl.split(',').last), fit: BoxFit.cover)
                            : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover))
                        : _defaultAvatar(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name - Clicking opens profile
                    GestureDetector(
                      onTap: () {
                        if (widget.isHistory) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicAuraScreen(userId: sender['id']),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileRequestViewScreen(
                                requestId: requestId,
                                profile: sender,
                                onAccept: widget.onAccept,
                                onReject: widget.onReject,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        '${sender['display_name']}, ${sender['age']}',
                        style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (interests.isNotEmpty)
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: interests.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: AppColors.primary.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text('#$tag', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        )).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  bio,
                  maxLines: _isBioExpanded ? null : 1,
                  overflow: _isBioExpanded ? null : TextOverflow.ellipsis,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Action Buttons Row
          // Action Buttons or Status Badge
          if (widget.isHistory)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: widget.request['status'] == 'accepted' 
                    ? Colors.greenAccent.withValues(alpha: 0.1)
                    : Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (widget.request['status'] == 'accepted' 
                      ? Colors.greenAccent 
                      : Colors.redAccent).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.request['status'] == 'accepted' ? Icons.check_circle : Icons.cancel,
                    size: 18,
                    color: widget.request['status'] == 'accepted' ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.request['status'] == 'accepted' ? 'Matched' : 'Passed',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: widget.request['status'] == 'accepted' ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onAccept,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Text('Accept', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cancel_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: AppColors.outlineVariant, size: 32),
    );
  }
}