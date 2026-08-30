import 'package:flutter/material.dart';

import 'state/sprayer_view_model.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

/// Root application widget. Owns the single [SprayerViewModel] instance.
class YardSprayerApp extends StatefulWidget {
  const YardSprayerApp({super.key});

  @override
  State<YardSprayerApp> createState() => _YardSprayerAppState();
}

class _YardSprayerAppState extends State<YardSprayerApp> {
  final SprayerViewModel _vm = SprayerViewModel();

  @override
  void initState() {
    super.initState();
    _vm.start(); // begin the 100 ms control loop in simulation mode
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yard Sprayer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: HomeShell(vm: _vm),
    );
  }
}
