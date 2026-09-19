import 'package:flutter/material.dart';

import '../theme.dart';

/// Compact ON/OFF button for small screens.
class SmallToggle extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool on;
  final VoidCallback onTap;

  const SmallToggle({
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: on ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sublabel.isNotEmpty) ...[
              const SizedBox(height: 0),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: on
                      ? Colors.black.withValues(alpha: 0.6)
                      : AppTheme.textDim,
                  fontSize: 8,
                ),
              ),
            ],
            const SizedBox(height: 1),
            Text(
              on ? 'ON' : 'OFF',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
