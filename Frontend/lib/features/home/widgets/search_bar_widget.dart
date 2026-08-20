import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Route Corridor Search Widget with Quick Filters (Women Only, Verified Hosts, Date, Seats)
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String>? onFilterChanged;

  const SearchBarWidget({super.key, this.onFilterChanged});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Today (Evening)',
    'Verified Hosts Only 🛡️',
    'Women-Only 👩',
    'Strict Consent 🗳️',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two connected inputs: Pickup Node & Destination
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderGray, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Pickup Node Input
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting Node (Pickup)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mediumGray,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          'Rajiv Chowk Metro Gate 2',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '150m walk',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryTealDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 5),
                    Container(
                      width: 2,
                      height: 18,
                      color: AppColors.borderGray,
                    ),
                    const SizedBox(width: 19),
                    const Expanded(child: Divider(height: 1)),
                  ],
                ),
              ),

              // Destination Input
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.midnightBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where are you heading?',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mediumGray,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          'DLF Cyber City, Gurgaon',
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.midnightBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.primaryTealDark,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick Filter Chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            separatorBuilder: (_, a) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = filter == _selectedFilter;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = filter);
                  widget.onFilterChanged?.call(filter);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.midnightBlue
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.midnightBlue
                          : AppColors.borderGray,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected ? AppColors.white : AppColors.deepSlate,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
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
