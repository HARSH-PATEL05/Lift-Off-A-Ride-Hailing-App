import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/verification_service.dart';

/// Reusable Vehicle RC Verification Module.
///
/// Used by:
/// 1. Trust Vault → Verify Vehicle RC
/// 2. Module 3 → Add Vehicle
///
/// The page collects the vehicle information required by the backend
/// and performs RC verification.
class VehicleRcVerificationScreen extends StatefulWidget {
  const VehicleRcVerificationScreen({
    super.key,
  });

  @override
  State<VehicleRcVerificationScreen> createState() =>
      _VehicleRcVerificationScreenState();
}

class _VehicleRcVerificationScreenState
    extends State<VehicleRcVerificationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _rcController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _specifiedTypeController = TextEditingController();

  String? _selectedCategory;
  String? _selectedSubtype;
  int? _seatingCapacity;

  bool _isSubmitting = false;

  // ─────────────────────────────────────────────
  // VEHICLE CLASSIFICATION
  // ─────────────────────────────────────────────

  static const Map<String, List<String>> _vehicleTypes = {
    '2 Wheeler': [
      'Bike',
      'Scooty',
    ],
    '3 Wheeler': [
      'Auto',
      'E-Rickshaw',
      'Toto',
    ],
    '4 Wheeler': [
      '5 Seater',
      '7 Seater',
    ],
    'Commercial Vehicle': [
      'Truck or Trailer',
      'Pickup',
      'Tampo',
      'Van',
      'Other',
    ],
    'Others': [
      'Other',
    ],
  };

  List<String> get _availableSubtypes {
    if (_selectedCategory == null) {
      return const [];
    }

    return _vehicleTypes[_selectedCategory] ?? const [];
  }

  bool get _requiresCustomVehicleType {
    return _selectedCategory == 'Others' ||
        _selectedSubtype == 'Other';
  }

  @override
  void dispose() {
    _rcController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _specifiedTypeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // CATEGORY / TYPE HANDLERS
  // ─────────────────────────────────────────────

  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value;
      _selectedSubtype = null;
      _specifiedTypeController.clear();
    });
  }

  void _onSubtypeChanged(String? value) {
    setState(() {
      _selectedSubtype = value;

      if (!_requiresCustomVehicleType) {
        _specifiedTypeController.clear();
      }
    });
  }

  // ─────────────────────────────────────────────
  // VERIFY VEHICLE
  // ─────────────────────────────────────────────

  Future<void> _verifyVehicle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      _showError('Please select a vehicle category.');
      return;
    }

    if (_selectedSubtype == null) {
      _showError('Please select a vehicle type.');
      return;
    }

    if (_requiresCustomVehicleType &&
        _specifiedTypeController.text.trim().isEmpty) {
      _showError('Please specify the vehicle type.');
      return;
    }

    if (_seatingCapacity == null || _seatingCapacity! < 2) {
      _showError('Please select the seating capacity.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final profile =
          await VerificationService.instance.verifyVehicleRc(
        rcNumber: _rcController.text,
        vehicleModel: _modelController.text,
        vehicleColor: _colorController.text,
        vehicleCategory: _selectedCategory!,
        vehicleSubtype: _selectedSubtype!,
        vehicleTypeSpecified: _requiresCustomVehicleType
            ? _specifiedTypeController.text
            : null,
        seatingCapacity: _seatingCapacity!,
      );

      if (!mounted) return;

      // Return the updated profile to the screen that opened this module.
      Navigator.pop(context, profile);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.midnightBlue,
          ),
          onPressed: _isSubmitting
              ? null
              : () => Navigator.pop(context),
        ),
        title: Text(
          'Vehicle RC Verification',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.midnightBlue,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────────────────────────────
                // HEADER
                // ─────────────────────────────────

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: AppColors.navyGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryTeal.withAlpha(35),
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.primaryTeal,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verify Your Vehicle',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your vehicle registration details to verify and add this vehicle to your LiftOff account.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color:
                              AppColors.white.withAlpha(210),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Vehicle Details',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.midnightBlue,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Fields marked with * are required.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),

                const SizedBox(height: 18),

                // ─────────────────────────────────
                // RC NUMBER
                // ─────────────────────────────────

                _buildLabel(
                  'Registration / RC Number',
                  required: true,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _rcController,
                  textCapitalization:
                      TextCapitalization.characters,
                  enabled: !_isSubmitting,
                  decoration: _inputDecoration(
                    hintText: 'e.g. DL01AB1234',
                    prefixIcon:
                        Icons.confirmation_number_outlined,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Please enter the RC number.';
                    }

                    if (text.length < 5 || text.length > 20) {
                      return 'Enter a valid RC number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ─────────────────────────────────
                // VEHICLE MODEL
                // ─────────────────────────────────

                _buildLabel(
                  'Vehicle Make & Model',
                  required: true,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _modelController,
                  enabled: !_isSubmitting,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: _inputDecoration(
                    hintText: 'e.g. Hyundai Creta',
                    prefixIcon:
                        Icons.directions_car_outlined,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Please enter the vehicle model.';
                    }

                    if (text.length < 2) {
                      return 'Vehicle model is too short.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ─────────────────────────────────
                // VEHICLE COLOR
                // ─────────────────────────────────

                _buildLabel(
                  'Vehicle Color',
                  required: false,
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: _colorController,
                  enabled: !_isSubmitting,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: _inputDecoration(
                    hintText: 'e.g. White',
                    prefixIcon: Icons.palette_outlined,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.length > 50) {
                      return 'Vehicle color is too long.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ─────────────────────────────────
                // VEHICLE CATEGORY
                // ─────────────────────────────────

                _buildLabel(
                  'Vehicle Category',
                  required: true,
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    hintText: 'Select vehicle category',
                    prefixIcon:
                        Icons.category_outlined,
                  ),
                  items:
                      _vehicleTypes.keys.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : _onCategoryChanged,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a vehicle category.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // ─────────────────────────────────
                // VEHICLE TYPE
                // ─────────────────────────────────

                _buildLabel(
                  'Vehicle Type',
                  required: true,
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _selectedSubtype,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    hintText: _selectedCategory == null
                        ? 'Select category first'
                        : 'Select vehicle type',
                    prefixIcon:
                        Icons.directions_car_outlined,
                  ),
                  items: _availableSubtypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged:
                      _isSubmitting ||
                              _selectedCategory == null
                          ? null
                          : _onSubtypeChanged,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a vehicle type.';
                    }

                    return null;
                  },
                ),

                // ─────────────────────────────────
                // SPECIFY OTHER VEHICLE TYPE
                // ─────────────────────────────────

                if (_requiresCustomVehicleType) ...[
                  const SizedBox(height: 18),

                  _buildLabel(
                    'Specify Vehicle Type',
                    required: true,
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller:
                        _specifiedTypeController,
                    enabled: !_isSubmitting,
                    textCapitalization:
                        TextCapitalization.words,
                    decoration: _inputDecoration(
                      hintText: 'e.g. Mini Bus',
                      prefixIcon:
                          Icons.edit_outlined,
                    ),
                    validator: (value) {
                      if (!_requiresCustomVehicleType) {
                        return null;
                      }

                      final text =
                          value?.trim() ?? '';

                      if (text.isEmpty) {
                        return 'Please specify the vehicle type.';
                      }

                      if (text.length > 100) {
                        return 'Vehicle type is too long.';
                      }

                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 18),

                // ─────────────────────────────────
                // SEATING CAPACITY
                // ─────────────────────────────────

                _buildLabel(
                  'Total Seating Capacity',
                  required: true,
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<int>(
                  value: _seatingCapacity,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    hintText:
                        'Select seating capacity',
                    prefixIcon:
                        Icons.event_seat_outlined,
                  ),
                  items:
                      List.generate(7, (index) {
                    final capacity = index + 2;

                    return DropdownMenuItem<int>(
                      value: capacity,
                      child:
                          Text('$capacity seats'),
                    );
                  }),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _seatingCapacity =
                                value;
                          });
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select seating capacity.';
                    }

                    if (value < 2 || value > 8) {
                      return 'Capacity must be between 2 and 8.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 8),

                Text(
                  'LiftOff available seats will be calculated from the vehicle seating capacity.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),

                const SizedBox(height: 30),

                // ─────────────────────────────────
                // SANDBOX INFO
                // ─────────────────────────────────

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryTeal
                          .withAlpha(80),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color:
                            AppColors.primaryTealDark,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sandbox Verification Environment\n'
                          'Your RC number is verified through the configured verification service.',
                          style:
                              AppTextStyles.caption
                                  .copyWith(
                            color:
                                AppColors.mediumGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ─────────────────────────────────
                // VERIFY BUTTON
                // ─────────────────────────────────

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : _verifyVehicle,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.primaryTeal,
                      foregroundColor:
                          AppColors.midnightBlue,
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  AppColors.midnightBlue,
                            ),
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 21,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Verify Now',
                                style: AppTextStyles
                                    .buttonPrimary
                                    .copyWith(
                                  color: AppColors
                                      .midnightBlue,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                Center(
                  child: Text(
                    'Vehicle information will be securely linked to your account.',
                    textAlign: TextAlign.center,
                    style:
                        AppTextStyles.caption.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LABEL
  // ─────────────────────────────────────────────

  Widget _buildLabel(
    String text, {
    required bool required,
  }) {
    return Row(
      children: [
        Text(
          text,
          style: AppTextStyles.label.copyWith(
            color: AppColors.midnightBlue,
            fontSize: 14,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: AppTextStyles.label.copyWith(
              color: AppColors.errorRed,
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // INPUT DECORATION
  // ─────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: AppColors.white,
      prefixIcon: Icon(
        prefixIcon,
        color: AppColors.mediumGray,
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primaryTeal,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.errorRed,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.errorRed,
          width: 1.5,
        ),
      ),
    );
  }
}