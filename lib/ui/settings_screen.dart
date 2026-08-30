import 'package:flutter/material.dart';

import '../core/sprayer_config.dart';
import '../state/sprayer_view_model.dart';
import 'theme.dart';
import 'widgets/labeled_slider.dart';

/// All user-adjustable configuration: boom geometry, target rate, valve and
/// controller tunables, and safety thresholds.
class SettingsScreen extends StatelessWidget {
  final SprayerViewModel vm;

  const SettingsScreen({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final e = vm.engine;
        final cfg = e.config;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _section('BOOM & TARGET', [
                          LabeledSlider(
                            label: 'Boom width',
                            value: cfg.boomWidthFt,
                            min: 5,
                            max: 40,
                            divisions: 35,
                            format: (v) => '${v.toStringAsFixed(0)} FT',
                            onChanged: (v) => _set(() {
                              final widths = SprayerConfig.equalSections(v, cfg.sectionCount);
                              e.applyConfig(cfg.copyWith(boomWidthFt: v, sectionWidthsFt: widths));
                            }),
                          ),
                          _stepper(
                            label: 'Sections',
                            value: cfg.sectionCount,
                            min: 1,
                            max: 4,
                            onChanged: (v) => _set(() {
                              e.applyConfig(cfg.copyWith(
                                sectionCount: v,
                                sectionWidthsFt: SprayerConfig.equalSections(cfg.boomWidthFt, v),
                              ));
                            }),
                          ),
                          LabeledSlider(
                            label: 'Target rate',
                            value: cfg.targetGpa,
                            min: 2,
                            max: 30,
                            divisions: 56,
                            format: (v) => '${v.toStringAsFixed(1)} GPA',
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(targetGpa: v))),
                          ),
                          LabeledSlider(
                            label: 'Design speed',
                            value: cfg.designSpeedMph,
                            min: 1,
                            max: 12,
                            divisions: 44,
                            format: (v) => '${v.toStringAsFixed(1)} MPH',
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(designSpeedMph: v))),
                          ),
                        ]),
                        _section('VALVE & FLOW', [
                          LabeledSlider(
                            label: 'Valve max flow (100%)',
                            value: cfg.valveMaxFlowGpm,
                            min: 2,
                            max: 12,
                            divisions: 20,
                            format: (v) => '${v.toStringAsFixed(1)} GPM',
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(valveMaxFlowGpm: v))),
                          ),
                          LabeledSlider(
                            label: 'Valve min command',
                            value: cfg.valveMinPct,
                            min: 0,
                            max: 20,
                            divisions: 20,
                            format: (v) => '${v.toStringAsFixed(0)}%',
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(valveMinPct: v))),
                          ),
                          LabeledSlider(
                            label: 'Valve max command',
                            value: cfg.valveMaxPct,
                            min: 60,
                            max: 100,
                            divisions: 40,
                            format: (v) => '${v.toStringAsFixed(0)}%',
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(valveMaxPct: v))),
                          ),
                        ]),
                        _section('CONTROLLER', [
                          LabeledSlider(
                            label: 'Proportional gain (Kp)',
                            value: cfg.kp,
                            min: 0,
                            max: 10,
                            divisions: 40,
                            format: (v) => v.toStringAsFixed(2),
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(kp: v))),
                          ),
                          LabeledSlider(
                            label: 'Integral gain (Ki)',
                            value: cfg.ki,
                            min: 0,
                            max: 10,
                            divisions: 40,
                            format: (v) => v.toStringAsFixed(2),
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(ki: v))),
                          ),
                          LabeledSlider(
                            label: 'Deadband',
                            value: cfg.deadbandGpm,
                            min: 0,
                            max: 0.2,
                            divisions: 40,
                            format: (v) => '${v.toStringAsFixed(3)} GPM',
                            onChanged: (v) => _set(() => e.applyConfig(cfg.copyWith(deadbandGpm: v))),
                          ),
                          LabeledSlider(
                            label: 'Max correction rate',
                            value: cfg.maxCorrectionPctPerSec,
                            min: 5,
                            max: 100,
                            divisions: 95,
                            format: (v) => '${v.toStringAsFixed(0)}%/s',
                            onChanged: (v) =>
                                _set(() => e.applyConfig(cfg.copyWith(maxCorrectionPctPerSec: v))),
                          ),
                        ]),
                        _section('SAFETY', [
                          LabeledSlider(
                            label: 'High pressure alarm',
                            value: cfg.pressureAlarmHighPsi,
                            min: 40,
                            max: 150,
                            divisions: 110,
                            format: (v) => '${v.toStringAsFixed(0)} PSI',
                            onChanged: (v) =>
                                _set(() => e.applyConfig(cfg.copyWith(pressureAlarmHighPsi: v))),
                          ),
                          LabeledSlider(
                            label: 'Low pressure alarm',
                            value: cfg.pressureAlarmLowPsi,
                            min: 0,
                            max: 40,
                            divisions: 40,
                            format: (v) => '${v.toStringAsFixed(0)} PSI',
                            onChanged: (v) =>
                                _set(() => e.applyConfig(cfg.copyWith(pressureAlarmLowPsi: v))),
                          ),
                          LabeledSlider(
                            label: 'Loss-of-flow valve threshold',
                            value: cfg.lossOfFlowValvePct,
                            min: 50,
                            max: 100,
                            divisions: 50,
                            format: (v) => '${v.toStringAsFixed(0)}%',
                            onChanged: (v) =>
                                _set(() => e.applyConfig(cfg.copyWith(lossOfFlowValvePct: v))),
                          ),
                          LabeledSlider(
                            label: 'Loss-of-flow time',
                            value: cfg.lossOfFlowSeconds,
                            min: 0.5,
                            max: 10,
                            divisions: 19,
                            format: (v) => '${v.toStringAsFixed(1)} s',
                            onChanged: (v) =>
                                _set(() => e.applyConfig(cfg.copyWith(lossOfFlowSeconds: v))),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _set(() => e.applyConfig(const SprayerConfig())),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'RESET TO DEFAULTS',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _set(VoidCallback apply) {
    apply();
    vm.refresh();
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _stepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w600)),
        Row(
          children: [
            _stepButton('-', () => onChanged((value - 1).clamp(min, max))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('$value',
                  style: const TextStyle(color: AppTheme.amber, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            _stepButton('+', () => onChanged((value + 1).clamp(min, max))),
          ],
        ),
      ],
    );
  }

  Widget _stepButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(label, style: const TextStyle(color: AppTheme.text, fontSize: 20, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
