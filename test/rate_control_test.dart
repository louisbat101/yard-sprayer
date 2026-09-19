import 'package:flutter_test/flutter_test.dart';

import 'package:yard_sprayer/core/rate_controller.dart';
import 'package:yard_sprayer/core/section_controller.dart';
import 'package:yard_sprayer/core/sprayer_config.dart';
import 'package:yard_sprayer/core/sprayer_engine.dart';
import 'package:yard_sprayer/core/units.dart';

/// Rate-control verification from spec section 19.
void main() {
  group('Required flow formula', () {
    test('Test 1: 10 GPA, 10 ft boom, 5 MPH => ~1.01 GPM', () {
      expect(
        SprayMath.requiredGpm(targetGpa: 10, speedMph: 5, activeWidthFt: 10),
        closeTo(1.01, 0.01),
      );
    });

    test('Test 2: 10 GPA, 10 ft boom, 3 MPH => ~0.61 GPM', () {
      expect(
        SprayMath.requiredGpm(targetGpa: 10, speedMph: 3, activeWidthFt: 10),
        closeTo(0.61, 0.01),
      );
    });

    test('Test 3: 10 GPA, 5 ft active boom, 5 MPH => ~0.505 GPM', () {
      expect(
        SprayMath.requiredGpm(targetGpa: 10, speedMph: 5, activeWidthFt: 5),
        closeTo(0.505, 0.01),
      );
    });

    test('Actual GPA is the inverse of required flow', () {
      final gpa = SprayMath.actualGpa(
        flowGpm: 1.01,
        speedMph: 5,
        activeWidthFt: 10,
      );
      expect(gpa, closeTo(10, 0.1));
    });
  });

  group('Section control', () {
    test('Test 5: turning one section off halves the active width', () {
      final SectionController s = SectionController(2);
      expect(s.activeWidthFt(const [5, 5]), 10);

      s.setOn(1, false);
      expect(s.activeWidthFt(const [5, 5]), 5);

      s.setOn(0, false);
      expect(s.activeWidthFt(const [5, 5]), 0);
    });
  });

  group('Closed-loop rate control (engine)', () {
    SprayerEngine makeEngine({double flowError = 0}) {
      final e = SprayerEngine();
      e.mode = SprayerMode.simulation;
      e.simSpeedMph = 5;
      e.flowErrorGpm = flowError;
      e.setSprayOn(true);
      return e;
    }

    void run(SprayerEngine e, int ticks) {
      for (var i = 0; i < ticks; i++) {
        e.tick(0.1);
      }
    }

    test('Test 4: required flow follows speed changes', () {
      final e = makeEngine();
      run(e, 50); // settle at 5 MPH
      expect(e.requiredGpm, closeTo(1.01, 0.05));

      e.simSpeedMph = 3;
      run(e, 50);
      expect(e.requiredGpm, closeTo(0.61, 0.05));
    });

    test(
      'Test 6: injected low flow makes the valve open until flow recovers',
      () {
        final e = makeEngine(flowError: -0.16); // e.g. a clogged nozzle
        run(e, 200); // 20 s of control
        expect(e.actualGpm, closeTo(e.requiredGpm, 0.08));
        // Feed-forward alone would sit at ~16.8%; the controller must open wider.
        expect(e.valvePositionPct, greaterThan(17));
      },
    );

    test(
      'Test 7: injected high flow makes the valve close until flow recovers',
      () {
        final e = makeEngine(flowError: 0.16);
        run(e, 200);
        expect(e.actualGpm, closeTo(e.requiredGpm, 0.08));
        expect(e.valvePositionPct, lessThan(30)); // valve had to throttle down
      },
    );

    test('Test 8: both sections off => zero flow and safe state', () {
      final e = makeEngine();
      run(e, 50);
      expect(e.requiredGpm, greaterThan(0));

      e.sections.setAll(false);
      run(e, 100);
      expect(e.requiredGpm, 0);
      expect(e.valveCommandPct, 0);
      expect(e.pumpRunning, isFalse);
      expect(e.actualGpm, closeTo(0, 0.01));
    });

    test('master spray off drives the valve closed', () {
      final e = makeEngine();
      run(e, 100);
      expect(e.valvePositionPct, greaterThan(0));

      e.setSprayOn(false);
      run(e, 100);
      expect(e.requiredGpm, 0);
      expect(e.valveCommandPct, 0);
      expect(e.actualGpm, closeTo(0, 0.01));
    });
  });

  group('RateController unit', () {
    test('output is clamped and slew-limited', () {
      const cfg = SprayerConfig(
        valveMinPct: 0,
        maxCorrectionPctPerSec: 25,
        kp: 3,
        ki: 2,
      );
      final c = RateController();

      // Huge error: output must not exceed the per-step slew limit.
      final step = c.update(
        requiredGpm: 5,
        actualGpm: 0,
        ffPct: 0,
        dt: 0.1,
        cfg: cfg,
      );
      expect(step, lessThanOrEqualTo(cfg.maxCorrectionPctPerSec * 0.1));
      expect(step, greaterThan(0));
    });
  });
}
