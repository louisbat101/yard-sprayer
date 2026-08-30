import 'package:flutter/material.dart';

import '../core/sprayer_engine.dart';
import '../state/sprayer_view_model.dart';
import 'theme.dart';
import 'widgets/big_toggle.dart';
import 'widgets/labeled_slider.dart';

/// Simulation mode: drive speed/flow/pressure/valve/position by hand and
/// deliberately introduce flow errors to verify the closed-loop controller.
class SimulationScreen extends StatelessWidget {
  final SprayerViewModel vm;

  const SimulationScreen({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final e = vm.engine;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'SIMULATION',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    _chip(
                      label: 'SIM MODE',
                      color: AppTheme.amber,
                      onTap: () => vm.setMode(SprayerMode.live),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _readoutStrip(e),
                        const SizedBox(height: 16),
                        _section('DRIVE & APPLICATION', [
                          LabeledSlider(
                            label: 'Speed',
                            value: e.simSpeedMph,
                            min: 0,
                            max: 15,
                            divisions: 150,
                            format: (v) => '${v.toStringAsFixed(1)} MPH',
                            onChanged: (v) => _set(() => e.simSpeedMph = v),
                          ),
                          LabeledSlider(
                            label: 'Target GPA',
                            value: e.config.targetGpa,
                            min: 2,
                            max: 20,
                            divisions: 90,
                            format: (v) => '${v.toStringAsFixed(1)} GPA',
                            onChanged: (v) =>
                                _set(() => e.applyConfig(e.config.copyWith(targetGpa: v))),
                          ),
                          LabeledSlider(
                            label: 'Heading',
                            value: e.simHeadingDeg,
                            min: 0,
                            max: 359,
                            divisions: 36,
                            format: (v) => '${v.round()}°',
                            onChanged: (v) => _set(() => e.simHeadingDeg = v),
                          ),
                        ]),
                        _section('FLOW DISTURBANCE & VALVE', [
                          LabeledSlider(
                            label: 'Flow error',
                            value: e.flowErrorGpm,
                            min: -1,
                            max: 1,
                            divisions: 40,
                            format: (v) => '${v.toStringAsFixed(2)} GPM',
                            onChanged: (v) => _set(() => e.flowErrorGpm = v),
                          ),
                          LabeledSlider(
                            label: 'Pressure bias',
                            value: e.pressureBiasPsi,
                            min: -10,
                            max: 20,
                            divisions: 60,
                            format: (v) => '${v.toStringAsFixed(0)} PSI',
                            onChanged: (v) => _set(() => e.pressureBiasPsi = v),
                          ),
                          LabeledSlider(
                            label: 'Valve max flow',
                            value: e.config.valveMaxFlowGpm,
                            min: 2,
                            max: 10,
                            divisions: 16,
                            format: (v) => '${v.toStringAsFixed(1)} GPM',
                            onChanged: (v) =>
                                _set(() => e.applyConfig(e.config.copyWith(valveMaxFlowGpm: v))),
                          ),
                          SwitchListTile(
                            value: e.manualValveOverride,
                            activeThumbColor: AppTheme.amber,
                            title: const Text('Manual valve override (open-loop)',
                                style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Off = closed-loop rate control',
                                style: TextStyle(color: AppTheme.textDim)),
                            onChanged: (v) => _set(() {
                              e.manualValveOverride = v;
                              if (v) e.rateController.reset(valvePct: e.manualValvePct);
                            }),
                          ),
                          if (e.manualValveOverride)
                            LabeledSlider(
                              label: 'Manual valve position',
                              value: e.manualValvePct,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              format: (v) => '${v.toStringAsFixed(0)}%',
                              onChanged: (v) => _set(() => e.manualValvePct = v),
                            ),
                        ]),
                        _section('SECTIONS', [
                          Row(
                            children: [
                              Expanded(
                                child: BigToggle(
                                  label: 'LEFT',
                                  sublabel: '${e.config.sectionWidthsFt[0].toStringAsFixed(0)} FT',
                                  on: e.sections.isOn(0),
                                  onTap: () => _set(() => e.sections.setOn(0, !e.sections.isOn(0))),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: BigToggle(
                                  label: 'RIGHT',
                                  sublabel: e.config.sectionCount > 1
                                      ? '${e.config.sectionWidthsFt[1].toStringAsFixed(0)} FT'
                                      : '',
                                  on: e.config.sectionCount > 1 && e.sections.isOn(1),
                                  onTap: () => _set(() {
                                    if (e.config.sectionCount > 1) {
                                      e.sections.setOn(1, !e.sections.isOn(1));
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                label: e.sprayOn ? 'STOP' : 'START SIMULATION',
                                color: e.sprayOn ? AppTheme.danger : AppTheme.accent,
                                onTap: () => _set(() => e.setSprayOn(!e.sprayOn)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                label: 'RESET CTL',
                                color: AppTheme.amber,
                                onTap: () => _set(() => e.rateController.reset(valvePct: 0)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'GPS: ${e.simLat.toStringAsFixed(5)}, ${e.simLon.toStringAsFixed(5)}',
                          style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                        ),
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

  Widget _readoutStrip(SprayerEngine e) {
    return Row(
      children: [
        _mini('SPEED', e.speedMph.toStringAsFixed(1), 'MPH'),
        _mini('FLOW', e.actualGpm.toStringAsFixed(2), 'GPM'),
        _mini('PRESSURE', e.pressurePsi.toStringAsFixed(0), 'PSI'),
        _mini('VALVE', e.valveCommandPct.toStringAsFixed(0), '%'),
      ],
    );
  }

  Widget _mini(String label, String value, String unit) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(unit, style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
          ],
        ),
      ),
    );
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

  Widget _actionButton({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _chip({required String label, required Color color, VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
