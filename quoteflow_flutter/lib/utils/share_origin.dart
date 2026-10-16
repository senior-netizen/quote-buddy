import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// UIKit requires a non-empty popover anchor when presenting a share sheet.
Rect shareOrigin(BuildContext context) {
  final render = context.findRenderObject();
  if (render is RenderBox && render.hasSize && !render.size.isEmpty) {
    return render.localToGlobal(Offset.zero) & render.size;
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}
