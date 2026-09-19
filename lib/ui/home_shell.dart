import 'package:flutter/material.dart';

import '../state/sprayer_view_model.dart';
import 'guidance_screen.dart';
import 'main_screen.dart';
import 'settings_screen.dart';
import 'simulation_screen.dart';

/// Top-level navigation shell (MAIN / GUIDE / SIM / SETTINGS tabs).
class HomeShell extends StatefulWidget {
  final SprayerViewModel vm;

  const HomeShell({super.key, required this.vm});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          MainScreen(vm: widget.vm),
          GuidanceScreen(vm: widget.vm),
          SimulationScreen(vm: widget.vm),
          SettingsScreen(vm: widget.vm),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.speed), label: 'MAIN'),
          NavigationDestination(icon: Icon(Icons.alt_route), label: 'GUIDE'),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            label: 'SIM',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'SETTINGS'),
        ],
      ),
    );
  }
}
