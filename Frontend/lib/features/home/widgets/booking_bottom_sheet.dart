import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'search_bar_widget.dart';
import 'service_selector.dart';
import 'promo_carousel.dart';
import 'book_ride_button.dart';

/// Draggable bottom sheet overlaying the lower portion of the map.
/// Contains search, service selector, promo carousel, and CTA button.
class BookingBottomSheet extends StatelessWidget {
  final String selectedServiceId;
  final ValueChanged<String> onServiceSelected;
  final VoidCallback onBook;

  const BookingBottomSheet({
    super.key,
    required this.selectedServiceId,
    required this.onServiceSelected,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.15,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.15, 0.42, 0.88],
      builder: (context, scrollController) {
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (_) {},
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowMedium,
                  blurRadius: 40,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Drag handle
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Search bar
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: const SliverToBoxAdapter(
                  child: SearchBarWidget(),
                ),
              ),

              // Spacing
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Service selector (Centred with symmetric 20px padding)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: ServiceSelector(
                    selectedServiceId: selectedServiceId,
                    onServiceSelected: onServiceSelected,
                    onBook: onBook,
                  ),
                ),
              ),

              // Spacing
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Promo carousel (Centred with symmetric 20px padding)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: const SliverToBoxAdapter(
                  child: PromoCarousel(),
                ),
              ),

              // Spacing
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // CTA Button
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: BookRideButton(
                    selectedServiceId: selectedServiceId,
                    onBook: onBook,
                  ),
                ),
              ),

              // Bottom safe area padding
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 20,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }
}
