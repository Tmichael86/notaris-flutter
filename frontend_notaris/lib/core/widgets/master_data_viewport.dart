import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Uses the content constraint, including when the unchanged desktop shell
/// wraps a page in a SingleChildScrollView. No screen/chrome height constants.
class MasterDataViewport extends StatelessWidget {
  const MasterDataViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context); // rebuild on height-only resize
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = context
            .findAncestorRenderObjectOfType<RenderAbstractViewport>();
        final RenderBox? box = viewport is RenderBox
            ? viewport as RenderBox
            : null;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : box != null && box.constraints.hasBoundedHeight
            ? box.constraints.maxHeight
            : screen.height;
        return SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 700 ? 16 : 28,
              20,
              constraints.maxWidth < 700 ? 16 : 28,
              30,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// The scrollbars occupy reserved rails, outside the table and pagination.
/// Both axes scroll one DataTable, keeping column/header widths aligned.
class MasterDataTableViewport extends StatelessWidget {
  const MasterDataTableViewport({
    super.key,
    required this.horizontalController,
    required this.verticalController,
    required this.child,
  });
  final ScrollController horizontalController, verticalController;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      return Scrollbar(
        controller: verticalController,
        thumbVisibility: true,
        notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
        child: Scrollbar(
          controller: horizontalController,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: (c.maxWidth - 12).clamp(0, double.infinity),
                ),
                child: SingleChildScrollView(
                  controller: verticalController,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
