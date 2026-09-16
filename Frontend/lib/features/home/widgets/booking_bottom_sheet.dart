import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';

import 'search_bar_widget.dart';
import 'service_selector.dart';
import 'promo_carousel.dart';
import 'book_ride_button.dart';

class BookingBottomSheet extends StatelessWidget {
  final String selectedServiceId;
  final ValueChanged<String> onServiceSelected;
  final VoidCallback onBook;
  final String? initialSource;
  final String? initialDestination;
  final List<SearchRouteStop> initialStops;
  final bool isSearchingRoute;
  final String? routeDistance;
  final String? routeDuration;
  final VoidCallback? onSelectSourceFromMap;
  final VoidCallback? onSelectDestinationFromMap;
  final ValueChanged<int>? onSelectStopFromMap;

  final void Function(
    LatLng source,
    LatLng destination,
    String sourceName,
    String destinationName,
    List<SearchRouteStop> stops,
  ) onRouteSearch;

  const BookingBottomSheet({
    super.key,
    required this.selectedServiceId,
    required this.onServiceSelected,
    required this.onBook,
    required this.onRouteSearch,
    this.initialSource,
    this.initialDestination,
    this.initialStops = const [],
    this.isSearchingRoute = false,
    this.routeDistance,
    this.routeDuration,
    this.onSelectSourceFromMap,
    this.onSelectDestinationFromMap,
    this.onSelectStopFromMap,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bottomPadding = mediaQuery.padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 24, offset: Offset(0, -4))],
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(isAndroid ? 16 : 20, 6, isAndroid ? 16 : 20, bottomPadding + 16),
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.lightGray, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 6),
          SearchBarWidget(
            key: const PageStorageKey('booking_search_bar_widget'),
            initialSource: initialSource,
            initialDestination: initialDestination,
            initialStops: initialStops,
            isSearchingRoute: isSearchingRoute,
            routeDistance: routeDistance,
            routeDuration: routeDuration,
            onSelectSourceFromMap: onSelectSourceFromMap,
            onSelectDestinationFromMap: onSelectDestinationFromMap,
            onSelectStopFromMap: onSelectStopFromMap,
            onRouteSearch: onRouteSearch,
          ),
          const SizedBox(height: 16),
          ServiceSelector(selectedServiceId: selectedServiceId, onServiceSelected: onServiceSelected, onBook: onBook),
          const SizedBox(height: 24),
          const PromoCarousel(),
          const SizedBox(height: 24),
          BookRideButton(selectedServiceId: selectedServiceId, onBook: onBook),
        ],
      ),
    );
  }
}
