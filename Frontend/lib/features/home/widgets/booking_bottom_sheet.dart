import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';

import 'search_bar_widget.dart';
import 'service_selector.dart';
import 'promo_carousel.dart';
import 'book_ride_button.dart';

/// Booking area displayed below the map.
///
/// The sheet slightly overlaps the map from HomeScreen
/// to create a seamless transition between the map
/// and the search section.
class BookingBottomSheet extends StatelessWidget {
  final String selectedServiceId;

  final ValueChanged<String> onServiceSelected;

  final VoidCallback onBook;

  final String? initialSource;

  final String? initialDestination;

  final bool isSearchingRoute;

  final String? routeDistance;

  final String? routeDuration;

  final VoidCallback? onSelectSourceFromMap;

  final VoidCallback? onSelectDestinationFromMap;

  final void Function(
    LatLng source,
    LatLng destination,
    String sourceName,
    String destinationName,
  ) onRouteSearch;

  const BookingBottomSheet({
    super.key,
    required this.selectedServiceId,
    required this.onServiceSelected,
    required this.onBook,
    required this.onRouteSearch,
    this.initialSource,
    this.initialDestination,
    this.isSearchingRoute = false,
    this.routeDistance,
    this.routeDuration,
    this.onSelectSourceFromMap,
    this.onSelectDestinationFromMap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration:
          const BoxDecoration(
        color: AppColors.white,

        borderRadius:
            BorderRadius.only(
          topLeft:
              Radius.circular(24),

          topRight:
              Radius.circular(24),
        ),

        boxShadow: [
          BoxShadow(
            color:
                AppColors.shadowMedium,

            blurRadius:
                24,

            offset:
                Offset(0, -4),
          ),
        ],
      ),

      child: ListView(
        physics:
            const BouncingScrollPhysics(),

        padding:
            EdgeInsets.fromLTRB(
          20,

          // Reduced from 8.
          // Keeps the content closer to the map.
          6,

          20,

          bottomPadding + 16,
        ),

        children: [
          // ==========================================================
          // DRAG HANDLE
          // ==========================================================

          Center(
            child: Container(
              width: 40,
              height: 4,

              decoration:
                  BoxDecoration(
                color:
                    AppColors.lightGray,

                borderRadius:
                    BorderRadius.circular(
                  2,
                ),
              ),
            ),
          ),

          // Reduced spacing between handle and search section.
          const SizedBox(
            height: 6,
          ),

          // ==========================================================
          // SOURCE / DESTINATION SEARCH
          // ==========================================================

          SearchBarWidget(
            key:
                const PageStorageKey(
              'booking_search_bar_widget',
            ),

            initialSource:
                initialSource,

            initialDestination:
                initialDestination,

            isSearchingRoute:
                isSearchingRoute,

            routeDistance:
                routeDistance,

            routeDuration:
                routeDuration,

            onSelectSourceFromMap:
                onSelectSourceFromMap,

            onSelectDestinationFromMap:
                onSelectDestinationFromMap,

            onRouteSearch:
                onRouteSearch,
          ),

          const SizedBox(
            height: 16,
          ),

          // ==========================================================
          // SERVICES
          // ==========================================================

          ServiceSelector(
            selectedServiceId:
                selectedServiceId,

            onServiceSelected:
                onServiceSelected,

            onBook:
                onBook,
          ),

          const SizedBox(
            height: 24,
          ),

          // ==========================================================
          // PROMOTIONS
          // ==========================================================

          const PromoCarousel(),

          const SizedBox(
            height: 24,
          ),

          // ==========================================================
          // BOOK RIDE
          // ==========================================================

          BookRideButton(
            selectedServiceId:
                selectedServiceId,

            onBook:
                onBook,
          ),
        ],
      ),
    );
  }
}