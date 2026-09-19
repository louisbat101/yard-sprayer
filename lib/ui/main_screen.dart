import 'package:flutter/material.dart';

import '../core/sprayer_engine.dart';
import '../state/sprayer_view_model.dart';
import 'theme.dart';
import 'widgets/readout_tile.dart';
import 'widgets/small_toggle.dart';

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
        final String gpsUnit = !live
            ? 'SIMULATED'
            : '±${f(e.gpsAccuracyM, 0)} m';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                _header(context, e),
                const SizedBox(height: 3),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _alarmBanner(e),
                        if (e.safety.anyAlarm) const SizedBox(height: 6),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: 1.2,
                          children: [
                            ReadoutTile(
                              label: 'TARGET RATE',
                              value: f(e.targetGpa, 1),
                              unit: 'GPA',
                            ),
                            ReadoutTile(
                              label: 'ACTUAL RATE',
                              value: f(e.actualGpa, 1),
                              unit: 'GPA',
                              valueColor: _rateColor(e.actualGpa, e.targetGpa),
                            ),
                            ReadoutTile(
                              label: 'SPEED',
                              value: f(e.speedMph, 1),
                              unit: 'MPH',
                            ),
                            ReadoutTile(
                              label: 'REQUIRED FLOW',
                              value: f(e.requiredGpm, 2),
                              unit: 'GPM',
                            ),
                            ReadoutTile(
                              label: 'ACTUAL FLOW',
                              value: f(e.actualGpm, 2),
                              unit: 'GPM',
                              valueColor: e.safety.lossOfFlowAlarm
                                  ? AppTheme.danger
                                  : null,
                            ),
                            ReadoutTile(
                              label: 'PRESSURE',
                              value: f(e.pressurePsi, 0),
                              unit: 'PSI',
                              valueColor:
                                  (e.safety.highPressureAlarm ||
                                      e.safety.lowPressureAlarm)
                                  ? AppTheme.danger
                                  : null,
                            ),
                            ReadoutTile(
                              label: 'VALVE',
                              value: f(e.valveCommandPct, 0),
                              unit: '%',
                            ),
                            ReadoutTile(
                              label: 'GPS',
                              value: gpsValue,
                              unit: gpsUnit,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        _valveBar(e),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: SmallToggle(
                                label: 'L',
                                sublabel:
                                    '${f(e.config.sectionWidthsFt[0], 0)}F',
                                on: e.sections.isOn(0),
                                onTap: () =>
                                    e.sections.setOn(0, !e.sections.isOn(0)),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: SmallToggle(
                                label: 'R',
                                sublabel: e.config.sectionCount > 1
                                    ? '${f(e.config.sectionWidthsFt[1], 0)}F'
                                    : '',
                                on:
                                    e.config.sectionCount > 1 &&
                                    e.sections.isOn(1),
                                onTap: () {
                                  if (e.config.sectionCount > 1) {
                                    e.sections.setOn(1, !e.sections.isOn(1));
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: SmallToggle(
                                label: 'SPRAY',
                                sublabel: '',
                                on: e.sprayOn,
                                onTap: () => e.setSprayOn(!e.sprayOn),
                              ),
                            ),
                          ],
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        _chip(
          label: live ? 'LIVE GPS' : 'SIM MODE',
          color: live ? AppTheme.accent : AppTheme.amber,
          onTap: () =>
              vm.setMode(live ? SprayerMode.simulation : SprayerMode.live),
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

  Widget _chip({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }

  Widget _valveBar(SprayerEngine e) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'VALVE',
                style: TextStyle(
                  color: AppTheme.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${f(e.valveCommandPct, 0)}%',
                style: const TextStyle(
                  color: AppTheme.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (e.valvePositionPct / 100).clamp(0, 1),
              minHeight: 10,
              backgroundColor: AppTheme.surfaceLight,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CLOSED',
                style: TextStyle(color: AppTheme.textDim, fontSize: 9),
              ),
              Text(
                e.manualValveOverride ? 'MANUAL' : 'AUTO',
                style: const TextStyle(color: AppTheme.textDim, fontSize: 8),
              ),
              const Text(
                'OPEN',
                style: TextStyle(color: AppTheme.textDim, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alarmBanner(SprayerEngine e) {
    if (!e.safety.anyAlarm) return const SizedBox.shrink();
    final List<String> alarms = [];
    if (e.safety.highPressureAlarm) alarms.add('HP');
    if (e.safety.lowPressureAlarm) alarms.add('LP');
    if (e.safety.lossOfFlowAlarm) alarms.add('LF');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.danger, width: 0.5),
      ),
      child: Text(
        '⚠ ${alarms.join('/')}',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.danger,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }

  Color? _rateColor(double actual, double target) {
    final double err = (actual - target).abs();
    if (err > target * 0.15) return AppTheme.amber;
    return null;
  }
}
