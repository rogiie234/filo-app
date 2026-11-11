import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'filo_motion_widgets.dart';

/// Branded feedback while the verified account's local data opens.
class FiloStartupScreen extends StatelessWidget {
  const FiloStartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FiloSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 144,
                    height: 144,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? Theme.of(context).colorScheme.primaryContainer
                          : FiloColors.mint,
                    ),
                    child: Image.asset(
                      dark
                          ? 'assets/brand/logo-mark-dark.png'
                          : 'assets/brand/logo-mark-light.png',
                      fit: BoxFit.contain,
                      isAntiAlias: true,
                    ),
                  ),
                ),
                const SizedBox(height: FiloSpacing.screen),
                Text('filo', style: FiloTypography.wordmark(context)),
                const SizedBox(height: FiloSpacing.screen),
                const FiloCircularProgressIndicator(
                  semanticsLabel: 'Starting Filo',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
