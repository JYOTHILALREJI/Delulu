import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'New Requests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.whiteAlpha05),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            AppColors.surfaceLight,
                            AppColors.purpleAccent.withOpacity(0.15),
                          ]),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.whiteAlpha20,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.background.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mysterious stranger...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: const [
                      _ReqTag(label: 'Architecture'),
                      _ReqTag(label: 'Midnight Jazz'),
                      _ReqTag(label: 'Sourdough'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '"Seeking a connection that transcends the visual. Let\'s talk about the books that changed us before we see who we are."',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.whiteAlpha60,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.whiteAlpha05,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppColors.rejectRed.withOpacity(0.3)),
                            ),
                            child: Center(
                              child: Text(
                                'REJECT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: AppColors.rejectRed,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: AppColors.buttonGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purpleAccent
                                      .withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'ACCEPT',
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
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                    child: Divider(color: AppColors.whiteAlpha05)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'WAITING IN SHADOWS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(color: AppColors.whiteAlpha05)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '3 More',
              style: TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _BlurredMiniCard(),
                SizedBox(width: 12),
                _BlurredMiniCard(),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ReqTag extends StatelessWidget {
  final String label;
  const _ReqTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.whiteAlpha10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.whiteAlpha60,
        ),
      ),
    );
  }
}

class _BlurredMiniCard extends StatelessWidget {
  const _BlurredMiniCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.whiteAlpha05),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.person, size: 32, color: AppColors.whiteAlpha05),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.background.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}