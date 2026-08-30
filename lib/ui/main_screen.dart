import 'package:flutter/material.dart';

import '../core/sprayer_engine.dart';
import '../state/sprayer_view_model.dart';
import 'theme.dart';
import 'widgets/big_toggle.dart';
import 'widgets/readout_tile.dart';

/// Main operator screen: rate readouts, section switches and the spray master.
class MainScreen extends StatelessWidget {
  final SprayerViewModel vm;

  const MainScreen({super.key, required this.vm});

  static String f(double v, int d) => v.toStringAsFixed(d);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final e = vm.engine;
        final bool live = e.mode == SprayerMode.live;
        final String gpsValue = !live
            ? 'SIM'
            : (e.gpsFixOk ? 'FIXED' : 'SEARCH');
        final String gpsUnit = !live ? 'SIMULATED' : '±${f(e.gpsAccuracyM, 0)} m';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _header(context, e),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _alarmBanner(e),
                        if (e.safety.anyAlarm) const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.45,
                          children: [
                            ReadoutTile(label: 'TARGET RATE', value: f(e.targetGpa, 1), unit: 'GPA'),
                            ReadoutTile(
                              label: 'ACTUAL RATE',
                              value: f(e.actualGpa, 1),
                              unit: 'GPA',
                              valueColor: _rateColor(e.actualGpa, e.targetGpa),
                            ),
                            ReadoutTile(label: 'SPEED', value: f(e.speedMph, 1), unit: 'MPH'),
                            ReadoutTile(label: 'REQUIRED FLOW', value: f(e.requiredGpm, 2), unit: 'GPM'),
                            ReadoutTile(
                              label: 'ACTUAL FLOW',
                              value: f(e.actualGpm, 2),
                              unit: 'GPM',
                              valueColor: e.safety.lossOfFlowAlarm ? AppTheme.danger : null,
                            ),
                            ReadoutTile(
                              label: 'PRESSURE',
                              value: f(e.pressurePsi, 0),
                              unit: 'PSI',
                              valueColor:
                                  (e.safety.highPressureAlarm || e.safety.lowPressureAlarm)
                                      ? AppTheme.danger
                                      : null,
                            ),
                            ReadoutTile(label: 'VALVE', value: f(e.valveCommandPct, 0), unit: '%'),
                            ReadoutTile(label: 'GPS', value: gpsValue, unit: gpsUnit),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _valveBar(e),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: BigToggle(
                                label: 'LEFT',
                                sublabel: '${f(e.config.sectionWidthsFt[0], 0)} FT',
                                on: e.sections.isOn(0),
                                onTap: () => e.sections.setOn(0, !e.sections.isOn(0)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BigToggle(
                                label: 'RIGHT',
                                sublabel: e.config.sectionCount > 1
                                    ? '${f(e.config.sectionWidthsFt[1], 0)} FT'
                                    : '',
                                on: e.config.sectionCount > 1 && e.sections.isOn(1),
                                onTap: () {
                                  if (e.config.sectionCount > 1) {
                                    e.sections.setOn(1, !e.sections.isOn(1));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        BigToggle(
                          label: 'SPRAY',
                          sublabel: 'MASTER',
                          on: e.sprayOn,
                          onTap: () => e.setSprayOn(!e.sprayOn),
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

  Widget _header(BuildContext context, SprayerEngine e) {
    final bool live = e.mode == SprayerMode.live;
    return Row(
      children: [
        const Text(
          'SPRAYER',
          style: TextStyle(
            color: AppTheme.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        _chip(
          label: live ? 'LIVE GPS' : 'SIM MODE',
          color: live ? AppTheme.accent : AppTheme.amber,
          onTap: () => vm.setMode(live ? SprayerMode.simulation : SprayerMode.live),
        ),
        const SizedBox(width: 8),
        _chip(
          label: vm.gpsMessage,
          color: vm.gpsDenied ? AppTheme.danger : AppTheme.textDim,
          onTap: null,
        ),
      ],
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
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }

  Widget _valveBar(SprayerEngine e) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VALVE COMMAND',
                style: TextStyle(color: AppTheme.textDim, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.1),
              ),
              Text(
                '${f(e.valveCommandPct, 0)}%',
                style: const TextStyle(color: AppTheme.amber, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (e.valvePositionPct / 100).clamp(0, 1),
              minHeight: 18,
              backgroundColor: AppTheme.surfaceLight,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CLOSED', style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
              Text(
                e.manualValveOverride ? 'MANUAL OVERRIDE' : 'AUTO (CLOSED-LOOP)',
                style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
              ),
              const Text('OPEN', style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alarmBanner(SprayerEngine e) {
    if (!e.safety.anyAlarm) return const SizedBox.shrink();
    final List<String> alarms = [];
    if (e.safety.highPressureAlarm) alarms.add('HIGH PRESSURE');
    if (e.safety.lowPressureAlarm) alarms.add('LOW PRESSURE');
    if (e.safety.lossOfFlowAlarm) alarms.add('LOSS OF FLOW');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger),
      ),
      child: Text(
        'ALARM: ${alarms.join(' · ')}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }

  Color? _rateColor(double actual, double target) {
    final double err = (actual - target).abs();
    if (err > target * 0.15) return AppTheme.amber;
    return null;
  }
}
