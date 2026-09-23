import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color barrierColor;
  final double barrierOpacity;
  final bool preventInteraction;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.barrierColor = Colors.black,
    this.barrierOpacity = 0.35,
    this.preventInteraction = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Jangan gunakan StackFit.expand.
      // Content berada di dalam SingleChildScrollView,
      // sehingga height bisa bersifat unbounded.
      fit: StackFit.loose,
      children: [
        AbsorbPointer(
          absorbing: isLoading && preventInteraction,
          child: child,
        ),

        if (isLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: barrierColor.withValues(
                  alpha: barrierOpacity,
                ),
              ),
            ),
          ),

        if (isLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 150,
                      maxWidth: 280,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 12,
                          offset: Offset(0, 4),
                          color: Color(0x33000000),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),

                        if (message != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}