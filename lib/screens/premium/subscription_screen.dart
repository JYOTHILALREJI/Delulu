import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../theme/app_colors.dart';
import '../../services/api_service.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  
  int _selectedPlan = 1; // Default to middle plan
  bool _isLoading = true;
  bool _isAvailable = false;
  String? _currentUserId;

  List<Map<String, dynamic>> _plans = [];

  final List<Map<String, dynamic>> _features = [
    {'icon': Icons.bolt, 'text': 'Unlimited Rizz Room plays'},
    {'icon': Icons.timer, 'text': '10 mins Attention Seeker cool time for more usage'},
    {'icon': Icons.visibility, 'text': 'See who liked you in The Vault'},
    {'icon': Icons.verified, 'text': 'Exclusive Premium Badge'},
    {'icon': Icons.favorite, 'text': 'Priority discovery placement'},
    {'icon': Icons.star, 'text': 'Access to premium profile themes'},
  ];

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // Handle error
    });
    _initStore();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initStore() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      setState(() {
        _isAvailable = false;
        _isLoading = false;
      });
      return;
    }

    _isAvailable = true;
    await _loadUserData();
    await _loadPlansAndProducts();
  }

  Future<void> _loadUserData() async {
    try {
      final res = await ApiService.getMe();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _currentUserId = body['user']['id'];
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadPlansAndProducts() async {
    try {
      // 1. Load plans from backend to get IDs and display info
      final res = await ApiService.getSubscriptionPlans();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List<dynamic> data = body['plans'];
        
        // 2. Fetch corresponding products from store
        final Set<String> kIds = data.map((p) => p['id'].toString()).toSet();
        final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(kIds);

        if (response.notFoundIDs.isNotEmpty) {
          debugPrint('Products not found: ${response.notFoundIDs}');
        }

        if (mounted) {
          setState(() {
            _products = response.productDetails;
            _plans = data.map((p) {
              // Match backend plan with store product if available
              final storeProduct = _products.firstWhere(
                (prod) => prod.id == p['id'],
                orElse: () => _products.isNotEmpty ? _products.first : null as dynamic, 
              );

              return {
                'id': p['id'],
                'title': p['name'],
                'price': storeProduct != null ? storeProduct.price : p['price_text'],
                'period': p['period_text'],
                'tag': p['tag'],
                'savings': p['savings_text'],
              };
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading indicator if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          bool deliver = await _verifyPurchase(purchaseDetails);
          if (deliver) {
            _showPaymentSuccess();
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    });
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    if (_currentUserId == null) return false;

    try {
      final res = await ApiService.verifyPurchase(
        userId: _currentUserId!,
        planId: _plans[_selectedPlan]['id'],
        store: Platform.isAndroid ? 'google_play' : 'apple_store',
        transactionId: purchaseDetails.transactionDate,
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
      );
      
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Verification error: $e');
      return false;
    }
  }

  void _handleError(IAPError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purchase failed: ${error.message}'), backgroundColor: Colors.red),
    );
  }

  void _subscribe() async {
    if (_plans.isEmpty || _selectedPlan >= _plans.length) return;
    
    final planId = _plans[_selectedPlan]['id'];
    final product = _products.firstWhere((p) => p.id == planId);
    
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    if (product.id.contains('subscription')) {
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // In our case they are likely all non-consumable subscriptions
      _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianEdge,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : !_isAvailable 
          ? _buildNotAvailable()
          : Stack(
              children: [
          // Background Gradients
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),
                        _buildFeaturesGrid(),
                        const SizedBox(height: 40),
                        _buildPricingSection(),
                        const SizedBox(height: 40),
                        _buildSubscribeButton(),
                        const SizedBox(height: 24),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            'DELULU',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              try {
                await _inAppPurchase.restorePurchases();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restoring purchases...')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Restore',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ).createShader(bounds),
          child: Text(
            'Rizz+',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Elevate your connection game',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: _features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(f['icon'] as IconData, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  f['text'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )).toList()..last,
      ),
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'CHOOSE A PLAN',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.primary,
            ),
          ),
        ),
        ...List.generate(_plans.length, (index) {
          final plan = _plans[index];
          final isSelected = _selectedPlan == index;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedPlan = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                plan['title'],
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                            if (plan['tag'] != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  plan['tag'],
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (plan['savings'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              plan['savings'],
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        plan['price'],
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        plan['period'],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubscribeButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFFA500)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _subscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Text(
          'START RIZZ+',
          style: GoogleFonts.beVietnamPro(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  void _showPaymentSuccess() {
    if (mounted) {
      showDialog(
        context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.verified, color: AppColors.primary, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Rizz+',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your premium features are now active. Go dominate!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context, true); // Return to previous screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('LET\'S GO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Recurring billing, cancel anytime.',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: const Text('Terms of Use', style: TextStyle(color: Colors.white30, fontSize: 11)),
            ),
            const Text('•', style: TextStyle(color: Colors.white30)),
            TextButton(
              onPressed: () {},
              child: const Text('Privacy Policy', style: TextStyle(color: Colors.white30, fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotAvailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 64),
            const SizedBox(height: 24),
            Text(
              'Store Unavailable',
              style: GoogleFonts.beVietnamPro(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We are unable to connect to the store right now. Please try again later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('GO BACK'),
            ),
          ],
        ),
      ),
    );
  }
}
