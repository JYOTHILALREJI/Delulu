import 'package:flutter/material.dart';
import '../utils/constants.dart';

class InterestChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDeletable;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  const InterestChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.isDeletable = false,
    this.onTap,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryContainer.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('#', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isDeletable) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDeleted,
                child: const Icon(Icons.close, size: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}