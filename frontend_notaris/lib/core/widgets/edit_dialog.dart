import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Route completion (not just its pop result) owns the editor's controllers.
Future<T?> showEditDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool Function() dirty,
  bool Function()? saving,
}) async {
  final route = DialogRoute<T>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _EditGuard(
      dirty: dirty,
      saving: saving ?? () => false,
      child: Builder(builder: builder),
    ),
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}

class _EditGuard extends StatefulWidget {
  const _EditGuard({
    required this.child,
    required this.dirty,
    required this.saving,
  });
  final Widget child;
  final bool Function() dirty, saving;
  @override
  State<_EditGuard> createState() => _EditGuardState();
}

class _EditGuardState extends State<_EditGuard> {
  bool closing = false;
  Future<void> cancel() async {
    if (closing ||
        widget.saving() ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    closing = true;
    try {
      if (widget.dirty()) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Buang perubahan?'),
            content: const Text(
              'Perubahan yang belum disimpan akan dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Lanjut edit'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Buang perubahan'),
              ),
            ],
          ),
        );
        if (discard != true) return;
      }
      if (mounted &&
          !widget.saving() &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } finally {
      closing = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) cancel();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): cancel},
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              cancel();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: widget.child),
      ),
    ),
  );
}

void cancelEditDialog(BuildContext context) =>
    context.findAncestorStateOfType<_EditGuardState>()?.cancel();
