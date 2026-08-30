import 'package:flutter/material.dart';

import '../theme.dart';

/// Large ON/OFF button sized for use while sitting on a mower.
class BigToggle extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool on;
  final VoidCallback onTap;

  const BigToggle({
    super.key,
    required this.label,
    this.sublabel = '',
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = on ? AppTheme.accent : AppTheme.border;
    final Color textColor = on ? Colors.black : AppTheme.textDim;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: on ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sublabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  color: on ? Colors.black.withValues(alpha: 0.7) : AppTheme.textDim,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              on ? 'ON' : 'OFF',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
