import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class TransactionAlertDialog extends StatelessWidget {
  const TransactionAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.scrollable = false,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: AppColors.primaryDark),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.border),
          ),
        ),
      ),
      child: AlertDialog(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actionsOverflowButtonSpacing: 8,
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
      ),
    );
  }
}
