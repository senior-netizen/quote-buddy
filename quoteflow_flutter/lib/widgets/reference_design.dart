import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Shared presentation for the supplied QuoteFlow mobile references.
class ReferenceBackdrop extends StatelessWidget {
  final Widget child;
  final bool fullWaves;
  const ReferenceBackdrop({
    super.key,
    required this.child,
    this.fullWaves = false,
  });
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF101421)
        : const Color(0xFFF6F8FE),
    child: CustomPaint(
      painter: _WavePainter(
        Theme.of(context).brightness == Brightness.dark,
        fullWaves,
      ),
      child: child,
    ),
  );
}

class _WavePainter extends CustomPainter {
  final bool dark, full;
  const _WavePainter(this.dark, this.full);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = full ? size.height : 280.0;
    final bounds = Rect.fromLTWH(0, 0, w, h);
    final wave = Path()
      ..moveTo(w * .22, h * .72)
      ..cubicTo(w * .5, h * .95, w * .54, h * .22, w * .79, h * .38)
      ..cubicTo(w * .96, h * .5, w * 1.12, h * .93, w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w * .3, h * .3),
          Offset(w, h),
          [
            const Color(0xFFB8D7FF).withValues(alpha: dark ? .13 : .6),
            const Color(0xFFDFD7FB).withValues(alpha: dark ? .08 : .5),
            Colors.transparent,
          ],
          [0, .5, 1],
        ),
    );
    final upper = Path()
      ..moveTo(w * .47, h * .73)
      ..cubicTo(w * .73, h * .2, w * .82, h * .22, w * 1.08, h * .56)
      ..lineTo(w, h * .86)
      ..cubicTo(w * .78, h * .73, w * .68, h * .7, w * .47, h * .73)
      ..close();
    canvas.drawPath(
      upper,
      Paint()
        ..shader =
            ui.Gradient.linear(Offset(w * .6, h * .25), Offset(w * .9, h), [
              const Color(0xFF95C3FF).withValues(alpha: dark ? .14 : .45),
              Colors.transparent,
            ]),
    );
    if (full) {
      canvas.save();
      canvas.translate(w, size.height);
      canvas.rotate(3.141592653589793);
      canvas.drawPath(
        wave,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(w, h),
            [
              const Color(0xFF9CC8FF).withValues(alpha: dark ? .1 : .46),
              const Color(0xFFD7D1FA).withValues(alpha: dark ? .08 : .3),
              Colors.transparent,
            ],
            [0, .5, 1],
          ),
      );
      canvas.restore();
    }
    // A soft wash keeps text readable over the decorative waves.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
          Colors.transparent,
          (dark ? const Color(0xFF101421) : const Color(0xFFF6F8FE)).withValues(
            alpha: .35,
          ),
        ]),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.dark != dark || old.full != full;
}

class ReferenceHeading extends StatelessWidget {
  final String eyebrow, title;
  final String? subtitle;
  final Widget? action;
  const ReferenceHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow.isNotEmpty) ...[
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 7),
      ],
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(
          subtitle!,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}

class ReferenceIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const ReferenceIcon(this.icon, {super.key, this.color, this.size = 42});
  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(icon, color: ink, size: size * .52),
    );
  }
}

class ReferenceNotice extends StatelessWidget {
  final String text;
  const ReferenceNotice(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .065),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReferenceIcon(Icons.info_outline, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class ReferenceDocumentPreview extends StatelessWidget {
  final String style;
  final Color accent;
  const ReferenceDocumentPreview({
    super.key,
    required this.style,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) {
    final darkHeader = style == 'modern' || style == 'bold';
    return Container(
      width: 53,
      height: 88,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (darkHeader)
            Container(
              height: 13,
              color: style == 'modern' ? const Color(0xFF172239) : accent,
            )
          else
            Container(width: 17, height: 4, color: accent),
          const SizedBox(height: 5),
          const Text(
            'INVOICE',
            style: TextStyle(
              fontSize: 5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF253041),
            ),
          ),
          const SizedBox(height: 5),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Container(
                width: i == 1 ? 25 : 39,
                height: 1,
                color: const Color(0xFFDCE0E8),
              ),
            ),
          const SizedBox(height: 3),
          Container(height: 4, color: accent.withValues(alpha: .18)),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(height: 1, color: const Color(0xFFE1E4EA)),
            ),
          const Spacer(),
          Container(
            height: 3,
            color: style == 'minimal' ? const Color(0xFFE1E4EA) : accent,
          ),
        ],
      ),
    );
  }
}

class ReferenceSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const ReferenceSparkline({
    super.key,
    required this.values,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 52,
      height: 25,
      child: CustomPaint(painter: _Sparkline(values, color)),
    ),
  );
}

class _Sparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  const _Sparkline(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minimum = values.reduce((a, b) => a < b ? a : b),
        maximum = values.reduce((a, b) => a > b ? a : b);
    final range = maximum - minimum;
    Offset point(int index) => Offset(
      index * size.width / (values.length - 1),
      range == 0
          ? size.height * .7
          : size.height -
                3 -
                (values[index] - minimum) / range * (size.height - 6),
    );
    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var index = 1; index < values.length; index++) {
      final before = point(index - 1), after = point(index);
      final middle = (before.dx + after.dx) / 2;
      line.cubicTo(middle, before.dy, middle, after.dy, after.dx, after.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          color.withValues(alpha: .22),
          color.withValues(alpha: .01),
        ]),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) =>
      old.color != color || old.values != values;
}

AppBar referenceAppBar(
  BuildContext context,
  String title, {
  String? subtitle,
  List<Widget>? actions,
}) => AppBar(
  toolbarHeight: 76,
  leadingWidth: 70,
  leading: Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
    child: IconButton.filledTonal(
      tooltip: 'Back',
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back_rounded),
    ),
  ),
  titleSpacing: 4,
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      if (subtitle != null)
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
    ],
  ),
  actions: actions,
);
