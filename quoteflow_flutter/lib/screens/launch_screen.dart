import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import '../widgets/reference_design.dart';

class QuoteFlowLaunchScreen extends StatelessWidget {
  final VoidCallback? retry;
  const QuoteFlowLaunchScreen({super.key, this.retry});
  @override
  Widget build(BuildContext context) => ReferenceBackdrop(
    fullWaves: true,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .07),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const AppLogo(size: 128),
                ),
                const SizedBox(height: 24),
                const Text(
                  'QuoteFlow',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Offline-first quotations & invoicing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 70),
                if (retry == null)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else ...[
                  const Text(
                    'Your workspace could not be opened. Your saved data has not been reset.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: retry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
