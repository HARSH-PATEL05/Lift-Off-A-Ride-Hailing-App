import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Community & Eco Impact Highlights Carousel
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  final List<Map<String, dynamic>> _banners = [
    {
      'title': '142 kg CO₂ Saved Together 🌿',
      'subtitle': 'Sharing rides on your daily route cuts city carbon by 65%',
      'tag': 'COMMUNITY IMPACT',
      'gradient': AppColors.ecoGradient,
      'icon': Icons.eco_rounded,
    },
    {
      'title': '120s Democratic Co-Passenger Polling ⚡',
      'subtitle': 'All onboard commuters vote to approve new co-travellers',
      'tag': 'SAFETY FIRST',
      'gradient': AppColors.navyGradient,
      'icon': Icons.how_to_vote_rounded,
    },
    {
      'title': '100% Aadhaar & DL Verified Hosts 🛡️',
      'subtitle': 'Travel with verified working professionals in your city',
      'tag': 'VERIFIED VAULT',
      'gradient': AppColors.tealGradient,
      'icon': Icons.security_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _currentPage = (_currentPage + 1) % _banners.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final b = _banners[index];
              return Container(
                padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: b['gradient'] as LinearGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowMedium,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          b['icon'] as IconData,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white.withAlpha(50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                b['tag'] as String,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b['title'] as String,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              b['subtitle'] as String,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.white.withAlpha(220),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: SmoothPageIndicator(
            controller: _pageController,
            count: _banners.length,
            effect: const ExpandingDotsEffect(
              dotHeight: 5,
              dotWidth: 5,
              activeDotColor: AppColors.primaryTeal,
              dotColor: AppColors.lightGray,
              expansionFactor: 3,
              spacing: 4,
            ),
          ),
        ),
      ],
    );
  }
}
