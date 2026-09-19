import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yard_sprayer/state/sprayer_view_model.dart';
import 'package:yard_sprayer/ui/main_screen.dart';
import 'package:yard_sprayer/ui/theme.dart';

void main() {
  testWidgets('main screen renders the operator readouts', (tester) async {
    // Not started: no tick timer, so this is a pure render smoke test.
    final SprayerViewModel vm = SprayerViewModel();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: MainScreen(vm: vm)),
      ),
    );

    expect(find.text('SPRAYER'), findsOneWidget);
    expect(find.text('TARGET RATE'), findsOneWidget);
    expect(find.text('ACTUAL RATE'), findsOneWidget);
    expect(find.text('REQUIRED FLOW'), findsOneWidget);
    expect(find.text('ACTUAL FLOW'), findsOneWidget);
    expect(find.text('PRESSURE'), findsOneWidget);
    expect(find.text('SPEED'), findsOneWidget);
    expect(find.text('SPRAY'), findsOneWidget);
  });
}
