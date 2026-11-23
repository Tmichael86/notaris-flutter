import 'package:flutter/material.dart';

/// Optional preview marker for unfinished screens; no authorization is granted.
class PromotionalPreview extends InheritedWidget {
  const PromotionalPreview({super.key, required super.child});
  static Widget prototype(BuildContext context, Widget child) {
    if (context.dependOnInheritedWidgetOfExactType<PromotionalPreview>() ==
        null) {
      return child;
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xfffff4df),
          padding: const EdgeInsets.all(12),
          child: const Text(
            'PRATINJAU PROTOTIPE · Data contoh tampilan. Operasi pengelolaan belum diaktifkan.',
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              child: SizedBox(
                height: constraints.maxHeight < 760
                    ? 760
                    : constraints.maxHeight,
                child: ExcludeFocus(child: IgnorePointer(child: child)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool updateShouldNotify(PromotionalPreview oldWidget) => false;
}
