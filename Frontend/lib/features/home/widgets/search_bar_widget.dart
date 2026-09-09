import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/google_places_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Identifies which location field is currently active.
enum ActiveSearchField {
  source,
  destination,
}

/// Route Corridor Search Widget.
///
/// Handles:
/// - Source autocomplete
/// - Destination autocomplete
/// - Google Places live suggestions
/// - Fully touchable suggestion tiles
/// - Source/Destination selection
/// - Route search activation
/// - Select location from map callbacks
/// - Quick filters
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String>? onFilterChanged;

  /// Initial source text passed from parent.
  final String? initialSource;

  /// Initial destination text passed from parent.
  final String? initialDestination;

  /// Whether route coordinates/directions are currently being searched.
  final bool isSearchingRoute;

  /// Called when the user selects a source suggestion.
  final ValueChanged<PlaceSuggestion>? onSourceSelected;

  /// Called when the user selects a destination suggestion.
  final ValueChanged<PlaceSuggestion>? onDestinationSelected;

  /// Called when the source location is selected.
  final ValueChanged<LatLng>? onSourceLocationSelected;

  /// Called when the destination location is selected.
  final ValueChanged<LatLng>? onDestinationLocationSelected;

  /// Called when both source and destination are selected
  /// and the user presses "Search Route".
  final void Function(
    LatLng source,
    LatLng destination,
    String sourceName,
    String destinationName,
  )? onRouteSearch;

  /// Called when user wants to select source directly from map.
  final VoidCallback? onSelectSourceFromMap;

  /// Called when user wants to select destination directly from map.
  final VoidCallback? onSelectDestinationFromMap;

  /// Route distance and duration.
  final String? routeDistance;
  final String? routeDuration;

  const SearchBarWidget({
    super.key,
    this.onFilterChanged,
    this.initialSource,
    this.initialDestination,
    this.isSearchingRoute = false,
    this.routeDistance,
    this.routeDuration,
    this.onSourceSelected,
    this.onDestinationSelected,
    this.onSourceLocationSelected,
    this.onDestinationLocationSelected,
    this.onRouteSearch,
    this.onSelectSourceFromMap,
    this.onSelectDestinationFromMap,
  });

  @override
  State<SearchBarWidget> createState() =>
      _SearchBarWidgetState();
}

class _SearchBarWidgetState
    extends State<SearchBarWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // =============================================================
  // CONTROLLERS
  // =============================================================

  final TextEditingController _sourceController =
      TextEditingController();

  final TextEditingController _destinationController =
      TextEditingController();

  // =============================================================
  // FOCUS
  // =============================================================

  final FocusNode _sourceFocusNode =
      FocusNode();

  final FocusNode _destinationFocusNode =
      FocusNode();

  // =============================================================
  // OVERLAY ANCHORS
  // =============================================================

  final LayerLink _sourceLayerLink =
      LayerLink();

  final LayerLink _destinationLayerLink =
      LayerLink();

  OverlayEntry? _suggestionOverlay;

  // =============================================================
  // TIMERS
  // =============================================================

  Timer? _sourceDebounce;

  Timer? _destinationDebounce;

  Timer? _hideOverlayTimer;

  // =============================================================
  // AUTOCOMPLETE STATE
  // =============================================================

  List<PlaceSuggestion> _suggestions = [];

  List<PlaceSuggestion> get suggestions =>
      _suggestions;

  bool _isLoading = false;

  ActiveSearchField? _activeField;

  /// Prevents old API responses from replacing newer results.
  int _searchRequestId = 0;

  /// Prevents controller listeners from clearing selected places
  /// while fields are updated programmatically.
  bool _isApplyingSelection = false;

  // =============================================================
  // SELECTED PLACES
  // =============================================================

  PlaceSuggestion? _selectedSource;

  PlaceSuggestion? _selectedDestination;

  // =============================================================
  // FILTERS
  // =============================================================

  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Today (Evening)',
    'Verified Hosts Only 🛡️',
    'Women-Only 👩',
    'Strict Consent 🗳️',
  ];

  bool _localSearching = false;

  // =============================================================
  // PLATFORM
  // =============================================================

  bool get _isAndroid =>
      defaultTargetPlatform ==
      TargetPlatform.android;

  // =============================================================
  // GETTERS
  // =============================================================

  bool get _canSearchRoute {
    final hasSource =
        _selectedSource != null ||
            _sourceController.text
                .trim()
                .isNotEmpty;

    final hasDestination =
        _selectedDestination != null ||
            _destinationController.text
                .trim()
                .isNotEmpty;

    return hasSource &&
        hasDestination;
  }

  // =============================================================
  // INITIALIZATION
  // =============================================================

  @override
  void initState() {
    super.initState();

    if (widget.initialSource != null &&
        widget.initialSource!.isNotEmpty) {
      _sourceController.text =
          widget.initialSource!;
    }

    if (widget.initialDestination != null &&
        widget.initialDestination!.isNotEmpty) {
      _destinationController.text =
          widget.initialDestination!;
    }

    _sourceFocusNode.addListener(
      _handleSourceFocus,
    );

    _destinationFocusNode.addListener(
      _handleDestinationFocus,
    );

    _sourceController.addListener(
      _onSourceChanged,
    );

    _destinationController.addListener(
      _onDestinationChanged,
    );
  }

  @override
  void didUpdateWidget(
    covariant SearchBarWidget oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSource != null &&
        widget.initialSource !=
            _sourceController.text &&
        widget.initialSource !=
            oldWidget.initialSource) {
      _isApplyingSelection = true;

      _sourceController.text =
          widget.initialSource!;

      _isApplyingSelection = false;
    }

    if (widget.initialDestination != null &&
        widget.initialDestination !=
            _destinationController.text &&
        widget.initialDestination !=
            oldWidget.initialDestination) {
      _isApplyingSelection = true;

      _destinationController.text =
          widget.initialDestination!;

      _isApplyingSelection = false;
    }
  }

  // =============================================================
  // SOURCE FOCUS
  // =============================================================

  void _handleSourceFocus() {
    if (_sourceFocusNode.hasFocus) {
      _hideOverlayTimer?.cancel();

      if (mounted) {
        setState(() {
          _activeField =
              ActiveSearchField.source;
        });
      }

      final text =
          _sourceController.text.trim();

      if (text.length >= 2) {
        _searchPlaces(
          text,
          ActiveSearchField.source,
        );
      }

      return;
    }

    _scheduleOverlayHide();
  }

  // =============================================================
  // DESTINATION FOCUS
  // =============================================================

  void _handleDestinationFocus() {
    if (_destinationFocusNode.hasFocus) {
      _hideOverlayTimer?.cancel();

      if (mounted) {
        setState(() {
          _activeField =
              ActiveSearchField.destination;
        });
      }

      final text =
          _destinationController.text.trim();

      if (text.length >= 2) {
        _searchPlaces(
          text,
          ActiveSearchField.destination,
        );
      }

      return;
    }

    _scheduleOverlayHide();
  }

  // =============================================================
  // OVERLAY HIDE
  // =============================================================

  void _scheduleOverlayHide() {
    _hideOverlayTimer?.cancel();

    _hideOverlayTimer = Timer(
      const Duration(
        milliseconds: 250,
      ),
      () {
        if (!mounted) {
          return;
        }

        if (!_sourceFocusNode.hasFocus &&
            !_destinationFocusNode.hasFocus) {
          _removeSuggestionOverlay();
        }
      },
    );
  }

  // =============================================================
  // SOURCE INPUT CHANGE
  // =============================================================

  void _onSourceChanged() {
    if (_isApplyingSelection) {
      return;
    }

    if (_selectedSource != null) {
      setState(() {
        _selectedSource = null;
      });
    }

    _sourceDebounce?.cancel();

    final input =
        _sourceController.text.trim();

    if (input.length < 2) {
      _clearSuggestions();
      return;
    }

    _sourceDebounce = Timer(
      const Duration(
        milliseconds: 350,
      ),
      () {
        if (_activeField ==
            ActiveSearchField.source) {
          _searchPlaces(
            input,
            ActiveSearchField.source,
          );
        }
      },
    );
  }

  // =============================================================
  // DESTINATION INPUT CHANGE
  // =============================================================

  void _onDestinationChanged() {
    if (_isApplyingSelection) {
      return;
    }

    if (_selectedDestination != null) {
      setState(() {
        _selectedDestination = null;
      });
    }

    _destinationDebounce?.cancel();

    final input =
        _destinationController.text.trim();

    if (input.length < 2) {
      _clearSuggestions();
      return;
    }

    _destinationDebounce = Timer(
      const Duration(
        milliseconds: 350,
      ),
      () {
        if (_activeField ==
            ActiveSearchField.destination) {
          _searchPlaces(
            input,
            ActiveSearchField.destination,
          );
        }
      },
    );
  }

  // =============================================================
  // GOOGLE PLACES AUTOCOMPLETE
  // =============================================================

  Future<void> _searchPlaces(
    String input,
    ActiveSearchField field,
  ) async {
    final cleanInput =
        input.trim();

    if (cleanInput.length < 2) {
      return;
    }

    final requestId =
        ++_searchRequestId;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results =
          await GooglePlacesService.instance
              .autocomplete(
        cleanInput,
      );

      // Ignore stale responses.
      if (!mounted ||
          requestId !=
              _searchRequestId ||
          _activeField != field) {
        return;
      }

      setState(() {
        _suggestions = results;
      });

      if (results.isNotEmpty) {
        _showSuggestionOverlay(
          field,
          results,
        );
      } else {
        _removeSuggestionOverlay();
      }
    } catch (e) {
      debugPrint(
        'Google Places autocomplete error: $e',
      );

      if (!mounted ||
          requestId !=
              _searchRequestId) {
        return;
      }

      _clearSuggestions();
    } finally {
      if (mounted &&
          requestId ==
              _searchRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =============================================================
  // SHOW SUGGESTION OVERLAY
  // =============================================================

  void _showSuggestionOverlay(
    ActiveSearchField field,
    List<PlaceSuggestion> results,
  ) {
    if (!mounted ||
        results.isEmpty) {
      return;
    }

    final LayerLink layerLink =
        field ==
                ActiveSearchField.source
            ? _sourceLayerLink
            : _destinationLayerLink;

    _removeSuggestionOverlayOnly();

    final RenderBox? renderBox =
        context.findRenderObject()
            as RenderBox?;

    final double width =
        renderBox?.size.width ??
            MediaQuery.of(context)
                    .size
                    .width -
                (_isAndroid ? 32 : 40);

    final List<PlaceSuggestion>
        overlaySuggestions =
        List<PlaceSuggestion>.from(
      results,
    );

    _suggestionOverlay =
        OverlayEntry(
      builder: (overlayContext) {
        return CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor:
              Alignment.bottomLeft,
          followerAnchor:
              Alignment.topLeft,
          offset:
              const Offset(
            0,
            8,
          ),
          child: Material(
            color:
                Colors.transparent,
            child: SizedBox(
              width:
                  width,
              child:
                  _buildSuggestionBox(
                field,
                overlaySuggestions,
              ),
            ),
          ),
        );
      },
    );

    final overlay =
        Overlay.of(
      context,
      rootOverlay: true,
    );

    overlay.insert(
      _suggestionOverlay!,
    );
  }

  // =============================================================
  // REMOVE OVERLAY ONLY
  // =============================================================

  void _removeSuggestionOverlayOnly() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  // =============================================================
  // REMOVE OVERLAY + CLEAR DATA
  // =============================================================

  void _removeSuggestionOverlay() {
    _removeSuggestionOverlayOnly();

    if (!mounted) {
      return;
    }

    setState(() {
      _suggestions = [];
    });
  }

  // =============================================================
  // CLEAR SUGGESTIONS
  // =============================================================

  void _clearSuggestions() {
    _removeSuggestionOverlayOnly();

    if (!mounted) {
      return;
    }

    setState(() {
      _suggestions = [];
    });
  }

  // =============================================================
  // SUGGESTION BOX
  // =============================================================

  Widget _buildSuggestionBox(
    ActiveSearchField field,
    List<PlaceSuggestion> suggestions,
  ) {
    return Material(
      elevation: 14,
      color:
          AppColors.white,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child: Container(
        constraints:
            const BoxConstraints(
          maxHeight: 310,
        ),
        decoration:
            BoxDecoration(
          color:
              AppColors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border:
              Border.all(
            color:
                AppColors.borderGray,
          ),
        ),
        child:
            ListView.separated(
          shrinkWrap:
              true,
          padding:
              const EdgeInsets.symmetric(
            vertical: 6,
          ),
          physics:
              const ClampingScrollPhysics(),
          itemCount:
              suggestions.length,
          separatorBuilder:
              (_, __) =>
                  Padding(
            padding:
                const EdgeInsets.only(
              left: 68,
            ),
            child:
                Divider(
              height: 1,
              color:
                  AppColors.borderGray,
            ),
          ),
          itemBuilder:
              (context, index) {
            return _buildSuggestionItem(
              suggestions[index],
              field,
            );
          },
        ),
      ),
    );
  }

  // =============================================================
  // SUGGESTION ITEM
  // =============================================================

  Widget _buildSuggestionItem(
    PlaceSuggestion suggestion,
    ActiveSearchField field,
  ) {
    final parts =
        suggestion.description
            .split(',');

    final primaryText =
        parts.isNotEmpty
            ? parts.first.trim()
            : suggestion.description;

    final secondaryText =
        parts.length > 1
            ? parts
                .sublist(1)
                .join(',')
                .trim()
            : '';

    final isSource =
        field ==
            ActiveSearchField.source;

    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        onTap:
            () {
          _selectSuggestion(
            suggestion,
            field,
          );
        },
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        child:
            SizedBox(
          width:
              double.infinity,
          child:
              Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal:
                  _isAndroid ? 12 : 16,
              vertical:
                  _isAndroid ? 13 : 15,
            ),
            child:
                Row(
              children: [
                Container(
                  width:
                      _isAndroid ? 40 : 42,
                  height:
                      _isAndroid ? 40 : 42,
                  decoration:
                      const BoxDecoration(
                    color:
                        AppColors
                            .primaryTealSurface,
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      Icon(
                    isSource
                        ? Icons
                            .trip_origin_rounded
                        : Icons
                            .location_on_outlined,
                    color:
                        isSource
                            ? AppColors
                                .primaryTealDark
                            : AppColors
                                .midnightBlue,
                    size:
                        _isAndroid
                            ? 20
                            : 21,
                  ),
                ),

                SizedBox(
                  width:
                      _isAndroid
                          ? 12
                          : 14,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        primaryText,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            AppTextStyles
                                .label
                                .copyWith(
                          fontSize:
                              _isAndroid
                                  ? 13
                                  : 14,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),

                      if (secondaryText
                          .isNotEmpty) ...[
                        const SizedBox(
                          height:
                              4,
                        ),
                        Text(
                          secondaryText,
                          maxLines:
                              2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              AppTextStyles
                                  .caption
                                  .copyWith(
                            fontSize:
                                _isAndroid
                                    ? 10
                                    : 11,
                            color:
                                AppColors
                                    .mediumGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(
                  width:
                      8,
                ),

                const Icon(
                  Icons
                      .north_west_rounded,
                  size:
                      18,
                  color:
                      AppColors
                          .mediumGray,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // SELECT SUGGESTION
  // =============================================================

  void _selectSuggestion(
    PlaceSuggestion suggestion,
    ActiveSearchField field,
  ) {
    debugPrint(
      'Selected suggestion: '
      '${suggestion.description}',
    );

    HapticFeedback.selectionClick();

    _hideOverlayTimer?.cancel();

    // Remove the overlay immediately.
    _removeSuggestionOverlayOnly();

    _isApplyingSelection = true;

    if (field ==
        ActiveSearchField.source) {
      setState(() {
        _selectedSource =
            suggestion;

        _sourceController.text =
            suggestion.description;

        _suggestions = [];
      });

      widget.onSourceSelected?.call(
        suggestion,
      );

      _isApplyingSelection = false;

      // ==========================================================
      // IMPORTANT ANDROID KEYBOARD FIX
      // ==========================================================
      //
      // Do NOT:
      //
      //   unfocus source
      //   wait 250ms
      //   request destination focus
      //
      // That sequence causes the keyboard to disappear and
      // reopen, which makes the white search panel jump.
      //
      // Instead, transfer focus directly to destination.
      // The keyboard therefore stays open.
      // ==========================================================

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (!mounted) {
            return;
          }

          _destinationFocusNode
              .requestFocus();
        },
      );

      return;
    }

    if (field ==
        ActiveSearchField.destination) {
      setState(() {
        _selectedDestination =
            suggestion;

        _destinationController.text =
            suggestion.description;

        _suggestions = [];
      });

      widget.onDestinationSelected?.call(
        suggestion,
      );

      // Destination selection is the end of the
      // autocomplete flow, so keyboard can close.
      _destinationFocusNode.unfocus();

      _isApplyingSelection = false;
    }
  }

  // =============================================================
  // CLEAR SOURCE
  // =============================================================

  void _clearSource() {
    _sourceDebounce?.cancel();

    _isApplyingSelection = true;

    _sourceController.clear();

    _isApplyingSelection = false;

    _removeSuggestionOverlayOnly();

    setState(() {
      _selectedSource = null;
      _suggestions = [];
      _activeField =
          ActiveSearchField.source;
    });

    _sourceFocusNode.requestFocus();
  }

  // =============================================================
  // CLEAR DESTINATION
  // =============================================================

  void _clearDestination() {
    _destinationDebounce?.cancel();

    _isApplyingSelection = true;

    _destinationController.clear();

    _isApplyingSelection = false;

    _removeSuggestionOverlayOnly();

    setState(() {
      _selectedDestination = null;
      _suggestions = [];
      _activeField =
          ActiveSearchField.destination;
    });

    _destinationFocusNode
        .requestFocus();
  }

  // =============================================================
  // SELECT SOURCE FROM MAP
  // =============================================================

  void _selectSourceFromMap() {
    HapticFeedback.selectionClick();

    _hideOverlayTimer?.cancel();

    _removeSuggestionOverlay();

    // Map selection intentionally closes the keyboard.
    _sourceFocusNode.unfocus();
    _destinationFocusNode.unfocus();

    // Give Flutter one frame to process the focus change before
    // changing the parent map selection mode.
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        widget.onSelectSourceFromMap
            ?.call();
      },
    );
  }

  // =============================================================
  // SELECT DESTINATION FROM MAP
  // =============================================================

  void _selectDestinationFromMap() {
    HapticFeedback.selectionClick();

    _hideOverlayTimer?.cancel();

    _removeSuggestionOverlay();

    // Map selection intentionally closes the keyboard.
    _sourceFocusNode.unfocus();
    _destinationFocusNode.unfocus();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        widget.onSelectDestinationFromMap
            ?.call();
      },
    );
  }

  // =============================================================
  // SEARCH ROUTE
  // =============================================================

  Future<void> _searchRoute() async {
    if (!_canSearchRoute ||
        _localSearching ||
        widget.isSearchingRoute) {
      return;
    }

    HapticFeedback.mediumImpact();

    _removeSuggestionOverlay();

    _sourceFocusNode.unfocus();
    _destinationFocusNode.unfocus();

    setState(() {
      _localSearching = true;
    });

    try {
      // ==========================================================
      // SOURCE
      // ==========================================================

      LatLng? sourceLatLng;

      if (_selectedSource != null) {
        sourceLatLng =
            await GooglePlacesService
                .instance
                .getPlaceLocation(
          _selectedSource!.placeId,
        );
      } else if (_sourceController.text
          .trim()
          .isNotEmpty) {
        final suggestions =
            await GooglePlacesService
                .instance
                .autocomplete(
          _sourceController.text.trim(),
        );

        if (suggestions.isNotEmpty) {
          sourceLatLng =
              await GooglePlacesService
                  .instance
                  .getPlaceLocation(
            suggestions.first.placeId,
          );
        }
      }

      // ==========================================================
      // DESTINATION
      // ==========================================================

      LatLng? destinationLatLng;

      if (_selectedDestination != null) {
        destinationLatLng =
            await GooglePlacesService
                .instance
                .getPlaceLocation(
          _selectedDestination!
              .placeId,
        );
      } else if (_destinationController
          .text
          .trim()
          .isNotEmpty) {
        final suggestions =
            await GooglePlacesService
                .instance
                .autocomplete(
          _destinationController
              .text
              .trim(),
        );

        if (suggestions.isNotEmpty) {
          destinationLatLng =
              await GooglePlacesService
                  .instance
                  .getPlaceLocation(
            suggestions.first.placeId,
          );
        }
      }

      // ==========================================================
      // ROUTE CALLBACK
      // ==========================================================

      if (sourceLatLng != null &&
          destinationLatLng != null) {
        widget.onRouteSearch?.call(
          sourceLatLng,
          destinationLatLng,
          _sourceController.text.trim(),
          _destinationController
              .text
              .trim(),
        );
      }
    } catch (e) {
      debugPrint(
        'Error fetching place locations: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _localSearching = false;
        });
      }
    }
  }

  // =============================================================
  // DISPOSE
  // =============================================================

  @override
  void dispose() {
    _sourceDebounce?.cancel();
    _destinationDebounce?.cancel();
    _hideOverlayTimer?.cancel();

    _removeSuggestionOverlayOnly();

    _sourceController.dispose();
    _destinationController.dispose();

    _sourceFocusNode.dispose();
    _destinationFocusNode.dispose();

    super.dispose();
  }

  // =============================================================
  // LOCATION INPUT
  // =============================================================

  Widget _buildLocationInput({
    required ActiveSearchField field,
    required TextEditingController controller,
    required FocusNode focusNode,
    required LayerLink layerLink,
    required String label,
    required String hint,
    required Color dotColor,
    required Color labelColor,
    required IconData mapIcon,
    required VoidCallback onSelectFromMap,
    required VoidCallback onClear,
    required TextInputAction textInputAction,
    VoidCallback? onSubmitted,
  }) {
    final isFocused =
        focusNode.hasFocus;

    final hasText =
        controller.text.isNotEmpty;

    final isSource =
        field ==
            ActiveSearchField.source;

    return CompositedTransformTarget(
      link:
          layerLink,
      child:
          Container(
        padding:
            EdgeInsets.symmetric(
          horizontal:
              2,
          vertical:
              _isAndroid ? 3 : 4,
        ),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          color:
              isFocused
                  ? AppColors
                      .primaryTealSurface
                      .withAlpha(
                    45,
                  )
                  : Colors.transparent,
        ),
        child:
            Row(
          children: [
            // ======================================================
            // LOCATION DOT
            // ======================================================

            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds:
                    180,
              ),
              width:
                  _isAndroid ? 13 : 14,
              height:
                  _isAndroid ? 13 : 14,
              decoration:
                  BoxDecoration(
                color:
                    dotColor,
                shape:
                    BoxShape.circle,
                boxShadow:
                    isFocused
                        ? const [
                            BoxShadow(
                              color:
                                  AppColors
                                      .tealGlow,
                              blurRadius:
                                  8,
                              spreadRadius:
                                  1,
                            ),
                          ]
                        : null,
              ),
            ),

            SizedBox(
              width:
                  _isAndroid ? 11 : 14,
            ),

            // ======================================================
            // TEXT
            // ======================================================

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    label,
                    style:
                        AppTextStyles
                            .caption
                            .copyWith(
                      color:
                          isFocused
                              ? labelColor
                              : AppColors
                                  .mediumGray,
                      fontSize:
                          _isAndroid
                              ? 9
                              : 10,
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),

                  const SizedBox(
                    height:
                        2,
                  ),

                  TextField(
                    controller:
                        controller,
                    focusNode:
                        focusNode,
                    textInputAction:
                        textInputAction,
                    onSubmitted:
                        (_) {
                      onSubmitted
                          ?.call();
                    },
                    style:
                        AppTextStyles
                            .label
                            .copyWith(
                      fontSize:
                          _isAndroid
                              ? 14
                              : 15,
                      fontWeight:
                          isSource
                              ? FontWeight
                                  .w600
                              : FontWeight
                                  .w700,
                      color:
                          isSource
                              ? AppColors
                                  .deepSlate
                              : AppColors
                                  .midnightBlue,
                    ),
                    decoration:
                        InputDecoration(
                      hintText:
                          hint,
                      hintStyle:
                          AppTextStyles
                              .label
                              .copyWith(
                        fontSize:
                            _isAndroid
                                ? 13
                                : 14,
                        color:
                            AppColors
                                .mediumGray,
                        fontWeight:
                            FontWeight
                                .w400,
                      ),
                      border:
                          InputBorder.none,
                      enabledBorder:
                          InputBorder.none,
                      focusedBorder:
                          InputBorder.none,
                      isDense:
                          true,
                      contentPadding:
                          EdgeInsets.symmetric(
                        vertical:
                            _isAndroid
                                ? 4
                                : 5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ======================================================
            // LOADING / CLEAR / MAP
            // ======================================================

            if (_isLoading &&
                _activeField ==
                    field)
              Padding(
                padding:
                    const EdgeInsets.all(
                  8,
                ),
                child:
                    SizedBox(
                  width:
                      20,
                  height:
                      20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth:
                        2.2,
                    color:
                        AppColors
                            .primaryTeal,
                  ),
                ),
              )
            else if (hasText)
              IconButton(
                icon:
                    const Icon(
                  Icons
                      .close_rounded,
                  size:
                      19,
                ),
                color:
                    AppColors
                        .mediumGray,
                splashRadius:
                    20,
                onPressed:
                    onClear,
              )
            else
              IconButton(
                icon:
                    Icon(
                  mapIcon,
                  size:
                      _isAndroid
                          ? 20
                          : 21,
                  color:
                      isSource
                          ? AppColors
                              .primaryTealDark
                          : AppColors
                              .midnightBlue,
                ),
                splashRadius:
                    20,
                tooltip:
                    'Select from map',
                onPressed:
                    onSelectFromMap,
              ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    super.build(context);

    final isSourceFocused =
        _sourceFocusNode.hasFocus;

    final isDestinationFocused =
        _destinationFocusNode.hasFocus;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ==========================================================
        // SEARCH CONTAINER
        // ==========================================================

        AnimatedContainer(
          duration:
              const Duration(
            milliseconds:
                180,
          ),
          padding:
              EdgeInsets.all(
            _isAndroid ? 12 : 14,
          ),
          decoration:
              BoxDecoration(
            color:
                AppColors.white,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border:
                Border.all(
              color:
                  isSourceFocused ||
                          isDestinationFocused
                      ? AppColors
                          .primaryTeal
                      : AppColors
                          .borderGray,
              width:
                  isSourceFocused ||
                          isDestinationFocused
                      ? 1.8
                      : 1.3,
            ),
            boxShadow:
                const [
              BoxShadow(
                color:
                    AppColors
                        .shadowLight,
                blurRadius:
                    18,
                offset:
                    Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),
          child:
              Column(
            children: [
              // ====================================================
              // SOURCE
              // ====================================================

              _buildLocationInput(
                field:
                    ActiveSearchField
                        .source,
                controller:
                    _sourceController,
                focusNode:
                    _sourceFocusNode,
                layerLink:
                    _sourceLayerLink,
                label:
                    'Starting Location',
                hint:
                    'Enter pickup location',
                dotColor:
                    AppColors
                        .primaryTeal,
                labelColor:
                    AppColors
                        .primaryTealDark,
                mapIcon:
                    Icons.map_outlined,
                onSelectFromMap:
                    _selectSourceFromMap,
                onClear:
                    _clearSource,
                textInputAction:
                    TextInputAction.next,
                onSubmitted:
                    () {
                  _destinationFocusNode
                      .requestFocus();
                },
              ),

              // ====================================================
              // CONNECTOR
              // ====================================================

              Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical:
                      8,
                ),
                child:
                    Row(
                  children: [
                    const SizedBox(
                      width:
                          6,
                    ),

                    Container(
                      width:
                          2,
                      height:
                          22,
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors
                                .borderGray,
                        borderRadius:
                            BorderRadius
                                .circular(
                          2,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                          20,
                    ),

                    Expanded(
                      child:
                          Divider(
                        height:
                            1,
                        color:
                            AppColors
                                .borderGray,
                      ),
                    ),
                  ],
                ),
              ),

              // ====================================================
              // DESTINATION
              // ====================================================

              _buildLocationInput(
                field:
                    ActiveSearchField
                        .destination,
                controller:
                    _destinationController,
                focusNode:
                    _destinationFocusNode,
                layerLink:
                    _destinationLayerLink,
                label:
                    'Where are you heading?',
                hint:
                    'Enter destination',
                dotColor:
                    AppColors
                        .midnightBlue,
                labelColor:
                    AppColors
                        .midnightBlue,
                mapIcon:
                    Icons.map_outlined,
                onSelectFromMap:
                    _selectDestinationFromMap,
                onClear:
                    _clearDestination,
                textInputAction:
                    TextInputAction.search,
                onSubmitted:
                    _searchRoute,
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              14,
        ),

        // ==========================================================
        // SEARCH ROUTE BUTTON
        // ==========================================================

        SizedBox(
          width:
              double.infinity,
          height:
              _isAndroid ? 48 : 50,
          child:
              AnimatedOpacity(
            duration:
                const Duration(
              milliseconds:
                  180,
            ),
            opacity:
                _canSearchRoute
                    ? 1
                    : 0.55,
            child:
                ElevatedButton(
              onPressed:
                  (_canSearchRoute &&
                          !_localSearching &&
                          !widget
                              .isSearchingRoute)
                      ? _searchRoute
                      : null,
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    AppColors
                        .midnightBlue,
                foregroundColor:
                    AppColors.white,
                disabledBackgroundColor:
                    AppColors
                        .borderGray,
                disabledForegroundColor:
                    AppColors
                        .mediumGray,
                elevation:
                    _canSearchRoute
                        ? 3
                        : 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
              ),
              child:
                  (_localSearching ||
                          widget
                              .isSearchingRoute)
                      ? const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            SizedBox(
                              width:
                                  18,
                              height:
                                  18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2.2,
                                color:
                                    AppColors
                                        .white,
                              ),
                            ),
                            SizedBox(
                              width:
                                  12,
                            ),
                            Text(
                              'Finding Route...',
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              Icons
                                  .alt_route_rounded,
                              size:
                                  20,
                            ),
                            SizedBox(
                              width:
                                  8,
                            ),
                            Text(
                              'Search Route',
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),

        // ==========================================================
        // ROUTE INFORMATION
        // ==========================================================

        if (widget.routeDistance !=
                null &&
            widget.routeDistance!
                .isNotEmpty) ...[
          const SizedBox(
            height:
                12,
          ),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal:
                  14,
              vertical:
                  10,
            ),
            decoration:
                BoxDecoration(
              color:
                  AppColors
                      .primaryTealSurface,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border:
                  Border.all(
                color:
                    AppColors
                        .primaryTeal
                        .withValues(
                  alpha:
                      0.3,
                ),
              ),
            ),
            child:
                Row(
              children: [
                const Icon(
                  Icons
                      .directions_car_rounded,
                  color:
                      AppColors
                          .primaryTealDark,
                  size:
                      20,
                ),

                const SizedBox(
                  width:
                      8,
                ),

                Expanded(
                  child:
                      Text(
                    'Trip Distance: '
                    '${widget.routeDistance} • '
                    '${widget.routeDuration}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w700,
                      color:
                          AppColors
                              .primaryTealDark,
                      fontSize:
                          13.5,
                    ),
                  ),
                ),

                const Icon(
                  Icons
                      .check_circle_rounded,
                  color:
                      AppColors
                          .primaryTealDark,
                  size:
                      16,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(
          height:
              12,
        ),

        // ==========================================================
        // FILTERS
        // ==========================================================

        SizedBox(
          height:
              36,
          child:
              ListView.separated(
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            itemCount:
                _filters.length,
            separatorBuilder:
                (_, __) =>
                    const SizedBox(
              width:
                  8,
            ),
            itemBuilder:
                (context, index) {
              final filter =
                  _filters[index];

              final isSelected =
                  filter ==
                      _selectedFilter;

              return GestureDetector(
                behavior:
                    HitTestBehavior
                        .opaque,
                onTap:
                    () {
                  HapticFeedback
                      .selectionClick();

                  setState(() {
                    _selectedFilter =
                        filter;
                  });

                  widget
                      .onFilterChanged
                      ?.call(
                    filter,
                  );
                },
                child:
                    AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds:
                        200,
                  ),
                  padding:
                      EdgeInsets.symmetric(
                    horizontal:
                        _isAndroid
                            ? 12
                            : 14,
                    vertical:
                        8,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        isSelected
                            ? AppColors
                                .midnightBlue
                            : AppColors
                                .white,
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                    border:
                        Border.all(
                      color:
                          isSelected
                              ? AppColors
                                  .midnightBlue
                              : AppColors
                                  .borderGray,
                      width:
                          1.5,
                    ),
                  ),
                  child:
                      Center(
                    child:
                        Text(
                      filter,
                      style:
                          AppTextStyles
                              .caption
                              .copyWith(
                        color:
                            isSelected
                                ? AppColors
                                    .white
                                : AppColors
                                    .deepSlate,
                        fontWeight:
                            isSelected
                                ? FontWeight
                                    .w700
                                : FontWeight
                                    .w500,
                        fontSize:
                            _isAndroid
                                ? 11
                                : 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}