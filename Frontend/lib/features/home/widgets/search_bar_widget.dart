import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/google_places_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum ActiveSearchField { source, destination, stop }

/// A stop used by the Home route search.
///
/// The Home page keeps this model lightweight so it can pass the same
/// locations to the detailed routing logic and to MapView.
class SearchRouteStop {
  final String name;
  final LatLng position;

  const SearchRouteStop({
    required this.name,
    required this.position,
  });
}

class _StopEditor {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  PlaceSuggestion? selectedPlace;
  LatLng? position;

  _StopEditor({String initialText = '', this.position})
      : controller = TextEditingController(text: initialText),
        focusNode = FocusNode(),
        layerLink = LayerLink();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// Route Corridor Search Widget.
///
/// Preserves the existing Home search UI and autocomplete behavior while
/// adding dynamic intermediate stops.
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String>? onFilterChanged;
  final String? initialSource;
  final String? initialDestination;
  final List<SearchRouteStop> initialStops;
  final bool isSearchingRoute;

  final ValueChanged<PlaceSuggestion>? onSourceSelected;
  final ValueChanged<PlaceSuggestion>? onDestinationSelected;
  final ValueChanged<LatLng>? onSourceLocationSelected;
  final ValueChanged<LatLng>? onDestinationLocationSelected;

  /// Search callback now carries all intermediate stops.
  final void Function(
    LatLng source,
    LatLng destination,
    String sourceName,
    String destinationName,
    List<SearchRouteStop> stops,
  )? onRouteSearch;

  final VoidCallback? onSelectSourceFromMap;
  final VoidCallback? onSelectDestinationFromMap;
  final ValueChanged<int>? onSelectStopFromMap;

  final String? routeDistance;
  final String? routeDuration;

  const SearchBarWidget({
    super.key,
    this.onFilterChanged,
    this.initialSource,
    this.initialDestination,
    this.initialStops = const [],
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
    this.onSelectStopFromMap,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _sourceFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  final LayerLink _sourceLayerLink = LayerLink();
  final LayerLink _destinationLayerLink = LayerLink();

  final List<_StopEditor> _stops = [];
  final Map<String, Timer> _debounces = {};

  OverlayEntry? _suggestionOverlay;
  Timer? _hideOverlayTimer;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _activeKey;
  int _searchRequestId = 0;
  bool _isApplyingSelection = false;
  PlaceSuggestion? _selectedSource;
  PlaceSuggestion? _selectedDestination;

  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Today (Evening)',
    'Verified Hosts Only 🛡️',
    'Women-Only 👩',
    'Strict Consent 🗳️',
  ];

  bool _localSearching = false;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  _StopEditor _stopAt(int index) => _stops[index];

  bool get _canSearchRoute {
    final source = _sourceController.text.trim();
    final destination = _destinationController.text.trim();
    if ((_selectedSource == null && source.isEmpty) ||
        (_selectedDestination == null && destination.isEmpty)) {
      return false;
    }
    for (final stop in _stops) {
      if (stop.controller.text.trim().isEmpty && stop.selectedPlace == null) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _sourceController.text = widget.initialSource ?? '';
    _destinationController.text = widget.initialDestination ?? '';

    for (final stop in widget.initialStops) {
      _addStopInternal(initialText: stop.name, selectedPosition: stop.position);
    }

    _sourceFocusNode.addListener(() => _handleFocus('source'));
    _destinationFocusNode.addListener(() => _handleFocus('destination'));
    _sourceController.addListener(_onSourceChanged);
    _destinationController.addListener(_onDestinationChanged);
  }

  void _addStopInternal({String initialText = '', LatLng? selectedPosition}) {
    final editor = _StopEditor(initialText: initialText, position: selectedPosition);
    editor.focusNode.addListener(() {
      final index = _stops.indexOf(editor);
      if (index >= 0) _handleFocus('stop:$index');
    });
    editor.controller.addListener(() {
      final index = _stops.indexOf(editor);
      if (index >= 0) _onStopChanged(index);
    });
    _stops.add(editor);
  }

  @override
  void didUpdateWidget(covariant SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSource != null &&
        widget.initialSource != _sourceController.text &&
        widget.initialSource != oldWidget.initialSource) {
      _isApplyingSelection = true;
      _sourceController.text = widget.initialSource!;
      _isApplyingSelection = false;
    }

    if (widget.initialDestination != null &&
        widget.initialDestination != _destinationController.text &&
        widget.initialDestination != oldWidget.initialDestination) {
      _isApplyingSelection = true;
      _destinationController.text = widget.initialDestination!;
      _isApplyingSelection = false;
    }

    // Keep the internal stop editors synchronized with HomeScreen. This is
    // important for map selection: HomeScreen receives the exact LatLng,
    // then rebuilds this widget with the selected stop.
    if (widget.initialStops.length != _stops.length) {
      setState(() {
        while (_stops.length < widget.initialStops.length) {
          final incoming = widget.initialStops[_stops.length];
          _addStopInternal(
            initialText: incoming.name,
            selectedPosition: incoming.position,
          );
        }
        while (_stops.length > widget.initialStops.length) {
          _stops.removeLast().dispose();
        }
      });
    }

    var stopStateChanged = false;
    for (var i = 0; i < widget.initialStops.length && i < _stops.length; i++) {
      final incoming = widget.initialStops[i];
      final current = _stops[i];
      final nameChanged = current.controller.text != incoming.name;
      final positionChanged =
          current.position?.latitude != incoming.position.latitude ||
          current.position?.longitude != incoming.position.longitude;

      if (nameChanged || positionChanged) {
        _isApplyingSelection = true;
        current.controller.text = incoming.name;
        current.position = incoming.position;
        current.selectedPlace = null;
        _isApplyingSelection = false;
        stopStateChanged = true;
      }
    }

    if (stopStateChanged && mounted) {
      setState(() {});
    }
  }

  void _handleFocus(String key) {
    final focused = key == 'source'
        ? _sourceFocusNode.hasFocus
        : key == 'destination'
            ? _destinationFocusNode.hasFocus
            : _stops[int.parse(key.split(':').last)].focusNode.hasFocus;

    if (focused) {
      _hideOverlayTimer?.cancel();
      setState(() => _activeKey = key);
      final controller = _controllerFor(key);
      final text = controller.text.trim();
      if (text.length >= 2) {
        _searchPlaces(text, key);
      }
    } else {
      _scheduleOverlayHide();
    }
  }

  TextEditingController _controllerFor(String key) {
    if (key == 'source') return _sourceController;
    if (key == 'destination') return _destinationController;
    return _stopAt(int.parse(key.split(':').last)).controller;
  }

  FocusNode _focusNodeFor(String key) {
    if (key == 'source') return _sourceFocusNode;
    if (key == 'destination') return _destinationFocusNode;
    return _stopAt(int.parse(key.split(':').last)).focusNode;
  }

  LayerLink _layerLinkFor(String key) {
    if (key == 'source') return _sourceLayerLink;
    if (key == 'destination') return _destinationLayerLink;
    return _stopAt(int.parse(key.split(':').last)).layerLink;
  }

  void _scheduleOverlayHide() {
    _hideOverlayTimer?.cancel();
    _hideOverlayTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final anyFocused = _sourceFocusNode.hasFocus ||
          _destinationFocusNode.hasFocus ||
          _stops.any((s) => s.focusNode.hasFocus);
      if (!anyFocused) _removeSuggestionOverlay();
    });
  }

  void _onSourceChanged() {
    if (_isApplyingSelection) return;
    if (_selectedSource != null) setState(() => _selectedSource = null);
    _debounceSearch('source', _sourceController.text.trim());
  }

  void _onDestinationChanged() {
    if (_isApplyingSelection) return;
    if (_selectedDestination != null) setState(() => _selectedDestination = null);
    _debounceSearch('destination', _destinationController.text.trim());
  }

  void _onStopChanged(int index) {
    if (_isApplyingSelection || index >= _stops.length) return;
    _stops[index].selectedPlace = null;
    _stops[index].position = null;
    _debounceSearch('stop:$index', _stops[index].controller.text.trim());
    if (mounted) setState(() {});
  }

  void _debounceSearch(String key, String input) {
    _debounces[key]?.cancel();
    if (input.length < 2) {
      if (_activeKey == key) _clearSuggestions();
      return;
    }
    _debounces[key] = Timer(const Duration(milliseconds: 350), () {
      if (_activeKey == key) _searchPlaces(input, key);
    });
  }

  Future<void> _searchPlaces(String input, String key) async {
    final clean = input.trim();
    if (clean.length < 2) return;
    final requestId = ++_searchRequestId;
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await GooglePlacesService.instance.autocomplete(clean);
      if (!mounted || requestId != _searchRequestId || _activeKey != key) return;
      setState(() => _suggestions = results);
      if (results.isNotEmpty) {
        _showSuggestionOverlay(key, results);
      } else {
        _removeSuggestionOverlay();
      }
    } catch (e) {
      debugPrint('Google Places autocomplete error: $e');
      if (mounted && requestId == _searchRequestId) _clearSuggestions();
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuggestionOverlay(String key, List<PlaceSuggestion> results) {
    if (!mounted || results.isEmpty) return;
    final link = _layerLinkFor(key);
    _removeSuggestionOverlayOnly();
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? MediaQuery.of(context).size.width - (_isAndroid ? 32 : 40);
    final copy = List<PlaceSuggestion>.from(results);
    _suggestionOverlay = OverlayEntry(
      builder: (_) => CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 8),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(width: width, child: _buildSuggestionBox(key, copy)),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_suggestionOverlay!);
  }

  void _removeSuggestionOverlayOnly() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
  }

  void _removeSuggestionOverlay() {
    _removeSuggestionOverlayOnly();
    if (mounted) setState(() => _suggestions = []);
  }

  void _clearSuggestions() {
    _removeSuggestionOverlayOnly();
    if (mounted) setState(() => _suggestions = []);
  }

  Widget _buildSuggestionBox(String key, List<PlaceSuggestion> suggestions) {
    return Material(
      elevation: 14,
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 310),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          physics: const ClampingScrollPhysics(),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(height: 1, color: AppColors.borderGray),
          ),
          itemBuilder: (_, index) => _buildSuggestionItem(suggestions[index], key),
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(PlaceSuggestion suggestion, String key) {
    final parts = suggestion.description.split(',');
    final primary = parts.isNotEmpty ? parts.first.trim() : suggestion.description;
    final secondary = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    final isSource = key == 'source';
    final isDestination = key == 'destination';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectSuggestion(suggestion, key),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _isAndroid ? 12 : 16, vertical: _isAndroid ? 13 : 15),
          child: Row(
            children: [
              Container(
                width: _isAndroid ? 40 : 42,
                height: _isAndroid ? 40 : 42,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTealSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSource ? Icons.trip_origin_rounded : isDestination ? Icons.location_on_outlined : Icons.stop_circle_outlined,
                  color: isSource ? AppColors.primaryTealDark : isDestination ? AppColors.midnightBlue : AppColors.primaryTealDark,
                  size: _isAndroid ? 20 : 21,
                ),
              ),
              SizedBox(width: _isAndroid ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(fontSize: _isAndroid ? 13 : 14, fontWeight: FontWeight.w700)),
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(secondary, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(fontSize: _isAndroid ? 10 : 11, color: AppColors.mediumGray)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.north_west_rounded, size: 18, color: AppColors.mediumGray),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion, String key) async {
    HapticFeedback.selectionClick();
    _hideOverlayTimer?.cancel();
    _removeSuggestionOverlayOnly();
    _isApplyingSelection = true;
    try {
      if (key == 'source') {
        setState(() {
          _selectedSource = suggestion;
          _sourceController.text = suggestion.description;
          _suggestions = [];
        });
        widget.onSourceSelected?.call(suggestion);
        _isApplyingSelection = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _destinationFocusNode.requestFocus();
        });
        return;
      }

      if (key == 'destination') {
        setState(() {
          _selectedDestination = suggestion;
          _destinationController.text = suggestion.description;
          _suggestions = [];
        });
        widget.onDestinationSelected?.call(suggestion);
        _destinationFocusNode.unfocus();
        _isApplyingSelection = false;
        return;
      }

      final index = int.parse(key.split(':').last);
      if (index < _stops.length) {
        setState(() {
          _stops[index].selectedPlace = suggestion;
          _stops[index].position = null;
          _stops[index].controller.text = suggestion.description;
          _suggestions = [];
        });
        _isApplyingSelection = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (index + 1 < _stops.length) {
            _stops[index + 1].focusNode.requestFocus();
          } else {
            _destinationFocusNode.requestFocus();
          }
        });
      }
    } finally {
      _isApplyingSelection = false;
    }
  }

  void _clearSource() {
    _isApplyingSelection = true;
    _sourceController.clear();
    _isApplyingSelection = false;
    _removeSuggestionOverlayOnly();
    setState(() {
      _selectedSource = null;
      _suggestions = [];
      _activeKey = 'source';
    });
    _sourceFocusNode.requestFocus();
  }

  void _clearDestination() {
    _isApplyingSelection = true;
    _destinationController.clear();
    _isApplyingSelection = false;
    _removeSuggestionOverlayOnly();
    setState(() {
      _selectedDestination = null;
      _suggestions = [];
      _activeKey = 'destination';
    });
    _destinationFocusNode.requestFocus();
  }

  void _clearStop(int index) {
    if (index >= _stops.length) return;
    _isApplyingSelection = true;
    _stops[index].controller.clear();
    _isApplyingSelection = false;
    _stops[index].selectedPlace = null;
    _removeSuggestionOverlayOnly();
    setState(() {
      _suggestions = [];
      _activeKey = 'stop:$index';
    });
    _stops[index].focusNode.requestFocus();
  }

  void _removeStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    _debounces.remove('stop:$index')?.cancel();
    _stops.removeAt(index).dispose();
    setState(() {});
    _removeSuggestionOverlayOnly();
  }

  void _addStop() {
    if (_stops.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 4 stops.')),
      );
      return;
    }
    setState(() => _addStopInternal());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _stops.last.focusNode.requestFocus();
    });
  }

  void _selectFromMap(String key) {
    HapticFeedback.selectionClick();
    _hideOverlayTimer?.cancel();
    _removeSuggestionOverlay();

    // Stop the text field from retaining focus, but invoke the parent
    // callback immediately. The old post-frame callback could be lost
    // when the platform Google Map rebuilt on Web.
    FocusManager.instance.primaryFocus?.unfocus();
    _sourceFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    for (final stop in _stops) {
      stop.focusNode.unfocus();
    }

    if (key == 'source') {
      widget.onSelectSourceFromMap?.call();
    } else if (key == 'destination') {
      widget.onSelectDestinationFromMap?.call();
    } else if (key.startsWith('stop:')) {
      final index = int.tryParse(key.substring(5));
      if (index != null) {
        widget.onSelectStopFromMap?.call(index);
      }
    }
  }

  Future<LatLng?> _resolvePlace(String key, PlaceSuggestion? selected) async {
    if (selected != null) {
      return GooglePlacesService.instance.getPlaceLocation(selected.placeId);
    }
    final text = _controllerFor(key).text.trim();
    if (text.isEmpty) return null;
    final suggestions = await GooglePlacesService.instance.autocomplete(text);
    if (suggestions.isEmpty) return null;
    return GooglePlacesService.instance.getPlaceLocation(suggestions.first.placeId);
  }

  Future<void> _searchRoute() async {
    if (!_canSearchRoute || _localSearching || widget.isSearchingRoute) return;
    HapticFeedback.mediumImpact();
    _removeSuggestionOverlay();
    _sourceFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    for (final stop in _stops) stop.focusNode.unfocus();
    setState(() => _localSearching = true);

    try {
      final source = await _resolvePlace('source', _selectedSource);
      final destination = await _resolvePlace('destination', _selectedDestination);
      if (source == null || destination == null) return;

      final stops = <SearchRouteStop>[];
      for (var i = 0; i < _stops.length; i++) {
        final position = _stops[i].position ??
            await _resolvePlace('stop:$i', _stops[i].selectedPlace);
        if (position == null) {
          throw Exception('Unable to resolve stop ${i + 1}');
        }
        stops.add(SearchRouteStop(name: _stops[i].controller.text.trim(), position: position));
      }

      widget.onRouteSearch?.call(
        source,
        destination,
        _sourceController.text.trim(),
        _destinationController.text.trim(),
        stops,
      );
    } catch (e) {
      debugPrint('Error fetching route locations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to resolve one or more route locations.')),
        );
      }
    } finally {
      if (mounted) setState(() => _localSearching = false);
    }
  }

  Widget _buildLocationInput({
    required String key,
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
    bool alwaysShowMapIcon = false,
    VoidCallback? onSubmitted,
    Widget? trailing,
  }) {
    final isFocused = focusNode.hasFocus;
    final hasText = controller.text.isNotEmpty;
    final isSource = key == 'source';

    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: _isAndroid ? 3 : 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isFocused ? AppColors.primaryTealSurface.withAlpha(45) : Colors.transparent,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _isAndroid ? 13 : 14,
              height: _isAndroid ? 13 : 14,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: isFocused
                    ? const [BoxShadow(color: AppColors.tealGlow, blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
            ),
            SizedBox(width: _isAndroid ? 11 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.caption.copyWith(
                    color: isFocused ? labelColor : AppColors.mediumGray,
                    fontSize: _isAndroid ? 9 : 10,
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 2),
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: textInputAction,
                    onSubmitted: (_) => onSubmitted?.call(),
                    style: AppTextStyles.label.copyWith(
                      fontSize: _isAndroid ? 14 : 15,
                      fontWeight: isSource ? FontWeight.w600 : FontWeight.w700,
                      color: isSource ? AppColors.deepSlate : AppColors.midnightBlue,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: AppTextStyles.label.copyWith(
                        fontSize: _isAndroid ? 13 : 14,
                        color: AppColors.mediumGray,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: _isAndroid ? 4 : 5),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading && _activeKey == key)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primaryTeal),
                ),
              )
            else ...[
              if (hasText)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 19),
                  color: AppColors.mediumGray,
                  splashRadius: 20,
                  onPressed: onClear,
                ),
              if (!hasText || alwaysShowMapIcon)
                IconButton(
                  icon: Icon(
                    mapIcon,
                    size: _isAndroid ? 20 : 21,
                    color: isSource
                        ? AppColors.primaryTealDark
                        : AppColors.midnightBlue,
                  ),
                  splashRadius: 20,
                  tooltip: 'Select from map',
                  onPressed: onSelectFromMap,
                ),
            ],
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildConnector({bool dashed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Container(
            width: 2,
            height: 22,
            decoration: BoxDecoration(color: AppColors.borderGray, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 20),
          Expanded(child: Divider(height: 1, color: AppColors.borderGray)),
        ],
      ),
    );
  }

  Widget _buildStopInput(int index) {
    final stop = _stops[index];
    return _buildLocationInput(
      key: 'stop:$index',
      controller: stop.controller,
      focusNode: stop.focusNode,
      layerLink: stop.layerLink,
      label: 'Stop ${index + 1}',
      hint: 'Add an intermediate stop',
      dotColor: AppColors.primaryTeal,
      labelColor: AppColors.primaryTealDark,
      mapIcon: Icons.map_outlined,
      onSelectFromMap: () => _selectFromMap('stop:$index'),
      onClear: () => _clearStop(index),
      alwaysShowMapIcon: true,
      textInputAction: index + 1 < _stops.length ? TextInputAction.next : TextInputAction.next,
      onSubmitted: () {
        if (index + 1 < _stops.length) {
          _stops[index + 1].focusNode.requestFocus();
        } else {
          _destinationFocusNode.requestFocus();
        }
      },
      trailing: IconButton(
        tooltip: 'Remove stop',
        splashRadius: 20,
        onPressed: () => _removeStop(index),
        icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
        color: AppColors.mediumGray,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sourceFocused = _sourceFocusNode.hasFocus;
    final destinationFocused = _destinationFocusNode.hasFocus;
    final anyStopFocused = _stops.any((s) => s.focusNode.hasFocus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(_isAndroid ? 12 : 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: sourceFocused || destinationFocused || anyStopFocused
                  ? AppColors.primaryTeal
                  : AppColors.borderGray,
              width: sourceFocused || destinationFocused || anyStopFocused ? 1.8 : 1.3,
            ),
            boxShadow: const [BoxShadow(color: AppColors.shadowLight, blurRadius: 18, offset: Offset(0, 5))],
          ),
          child: Column(
            children: [
              _buildLocationInput(
                key: 'source',
                controller: _sourceController,
                focusNode: _sourceFocusNode,
                layerLink: _sourceLayerLink,
                label: 'Starting Location',
                hint: 'Enter pickup location',
                dotColor: AppColors.primaryTeal,
                labelColor: AppColors.primaryTealDark,
                mapIcon: Icons.map_outlined,
                onSelectFromMap: () => _selectFromMap('source'),
                onClear: _clearSource,
                textInputAction: TextInputAction.next,
                onSubmitted: () {
                  if (_stops.isNotEmpty) {
                    _stops.first.focusNode.requestFocus();
                  } else {
                    _destinationFocusNode.requestFocus();
                  }
                },
              ),
              if (_stops.isNotEmpty) _buildConnector(),
              for (var i = 0; i < _stops.length; i++) ...[
                _buildStopInput(i),
                _buildConnector(),
              ],
              _buildLocationInput(
                key: 'destination',
                controller: _destinationController,
                focusNode: _destinationFocusNode,
                layerLink: _destinationLayerLink,
                label: 'Where are you heading?',
                hint: 'Enter destination',
                dotColor: AppColors.midnightBlue,
                labelColor: AppColors.midnightBlue,
                mapIcon: Icons.map_outlined,
                onSelectFromMap: () => _selectFromMap('destination'),
                onClear: _clearDestination,
                textInputAction: TextInputAction.search,
                onSubmitted: _searchRoute,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addStop,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Stop'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTealDark,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: _isAndroid ? 48 : 50,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _canSearchRoute ? 1 : 0.55,
            child: ElevatedButton(
              onPressed: (_canSearchRoute && !_localSearching && !widget.isSearchingRoute) ? _searchRoute : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnightBlue,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.borderGray,
                disabledForegroundColor: AppColors.mediumGray,
                elevation: _canSearchRoute ? 3 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: (_localSearching || widget.isSearchingRoute)
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.white)),
                      SizedBox(width: 12),
                      Text('Finding Route...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.alt_route_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Search Route', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
            ),
          ),
        ),
        if (widget.routeDistance != null && widget.routeDistance!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryTealSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.directions_car_rounded, color: AppColors.primaryTealDark, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Trip Distance: ${widget.routeDistance} • ${widget.routeDuration}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryTealDark, fontSize: 13.5))),
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryTealDark, size: 16),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final filter = _filters[index];
              final selected = filter == _selectedFilter;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = filter);
                  widget.onFilterChanged?.call(filter);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: _isAndroid ? 12 : 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.midnightBlue : AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: selected ? AppColors.midnightBlue : AppColors.borderGray, width: 1.5),
                  ),
                  child: Center(child: Text(filter, style: AppTextStyles.caption.copyWith(
                    color: selected ? AppColors.white : AppColors.deepSlate,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: _isAndroid ? 11 : 12,
                  ))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final timer in _debounces.values) timer.cancel();
    _hideOverlayTimer?.cancel();
    _removeSuggestionOverlayOnly();
    _sourceController.dispose();
    _destinationController.dispose();
    _sourceFocusNode.dispose();
    _destinationFocusNode.dispose();
    for (final stop in _stops) stop.dispose();
    super.dispose();
  }
}
