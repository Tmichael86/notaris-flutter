import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class TransactionDialogSection extends StatelessWidget {
  const TransactionDialogSection({
    super.key,
    required this.child,
    this.highlight = false,
  });

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: highlight ? AppColors.selectedMenuBg : AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
