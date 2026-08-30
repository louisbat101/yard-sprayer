import 'package:flutter/material.dart';

import '../theme.dart';

/// Label + value + slider, reused by the Simulation and Settings screens.
class LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              format(value),
              style: const TextStyle(color: AppTheme.amber, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: format(value),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
