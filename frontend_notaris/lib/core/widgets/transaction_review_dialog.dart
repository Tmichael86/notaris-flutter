import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A bounded dialog with a content-sized body and fixed controls.
class TransactionReviewDialog extends StatelessWidget {
  const TransactionReviewDialog({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.status,
    this.footer,
    this.bodyKey,
    this.width = 600,
  });

  final String title;
  final String? subtitle;
  final Widget? status, footer;
  final Widget body;
  final Key? bodyKey;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        key: const Key('transaction-review-surface'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 26,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (subtitle != null || status != null) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (subtitle != null)
                                  Text(
                                    subtitle!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ?status,
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: SingleChildScrollView(
                  key: bodyKey,
                  primary: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: body,
                ),
              ),
              if (footer != null) ...[
                const Divider(height: 1, color: AppColors.divider),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: footer!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionReviewMessage extends StatelessWidget {
  const TransactionReviewMessage(
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.loading = false,
  });

  final String message;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}

class TransactionReviewBadge extends StatelessWidget {
  const TransactionReviewBadge(this.label, {super.key, required this.color});

  factory TransactionReviewBadge.transaction(String status) =>
      TransactionReviewBadge(
        status.trim().isEmpty ? '—' : status,
        color: switch (status.trim().toLowerCase()) {
          'selesai' => Colors.green.shade800,
          'dalam proses' => Colors.orange.shade900,
          'dihapus' => AppColors.primaryDark,
          _ => AppColors.textSecondary,
        },
      );

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: .24)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          color: Color.lerp(color, AppColors.textPrimary, .28),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
