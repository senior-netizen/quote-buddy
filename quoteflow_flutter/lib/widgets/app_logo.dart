import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.08),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    child: Image.asset(
      'assets/branding/quoteflow-logo.png',
      semanticLabel: 'QuoteFlow logo',
      fit: BoxFit.contain,
    ),
  );
}
