import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../widgets/nav_bar.dart';
import 'account_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';

class RiderShell extends StatefulWidget {
  const RiderShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends State<RiderShell> {
  late int _index = widget.initialTab;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: switch (_index) {
            0 => HomeTab(onOpenTab: _go),
            1 => const HistoryTab(),
            2 => const WalletTab(),
            _ => const AccountTab(),
          },
        ),
      ),
      bottomNavigationBar: TRNavBar(
        index: _index,
        onTap: _go,
        items: const [
          NavItem(PhosphorIconsRegular.house, PhosphorIconsFill.house, 'Home'),
          NavItem(PhosphorIconsRegular.clockCounterClockwise,
              PhosphorIconsFill.clockCounterClockwise, 'Trips'),
          NavItem(PhosphorIconsRegular.wallet, PhosphorIconsFill.wallet, 'Wallet'),
          NavItem(PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle,
              'Account'),
        ],
      ),
    );
  }
}
