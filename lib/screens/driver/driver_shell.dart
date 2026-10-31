import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/routes.dart';
import '../../widgets/nav_bar.dart';
import 'driver_earnings_tab.dart';
import 'driver_home_tab.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});
  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _index == 0 ? const DriverHomeTab() : const DriverEarningsTab(),
        ),
      ),
      bottomNavigationBar: TRNavBar(
        index: _index,
        onTap: (i) {
          if (i == 2) {
            Navigator.of(context).pushNamed(R.driverSignup);
            return;
          }
          setState(() => _index = i);
        },
        items: const [
          NavItem(PhosphorIconsRegular.steeringWheel,
              PhosphorIconsFill.steeringWheel, 'Drive'),
          NavItem(PhosphorIconsRegular.chartBar, PhosphorIconsFill.chartBar,
              'Earnings'),
          NavItem(PhosphorIconsRegular.identificationCard,
              PhosphorIconsFill.identificationCard, 'Profile'),
        ],
      ),
    );
  }
}
