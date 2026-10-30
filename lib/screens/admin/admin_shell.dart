import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'admin_drivers.dart';
import 'admin_overview.dart';
import 'admin_trips.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final _scaffold = GlobalKey<ScaffoldState>();

  void _go(int i) {
    setState(() => _index = i);
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 920;
    final page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.02, 0), end: Offset.zero)
              .animate(a),
          child: c,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_index),
        child: switch (_index) {
          0 => AdminOverview(onOpen: _go),
          1 => const AdminDrivers(),
          _ => const AdminTrips(),
        },
      ),
    );

    final sidebar = _Sidebar(index: _index, onTap: _go);

    return Scaffold(
      key: _scaffold,
      backgroundColor: const Color(0xFFF3F5F8),
      drawer: wide ? null : Drawer(width: 270, child: sidebar),
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: TR.navy,
              foregroundColor: Colors.white,
              title: const BrandWord(light: true, size: 18),
              actions: [
                IconButton(
                  tooltip: 'Exit admin',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(PhosphorIconsBold.signOut),
                ),
              ],
            ),
      body: wide
          ? Row(children: [
              SizedBox(width: 250, child: sidebar),
              Expanded(child: page),
            ])
          : page,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final items = [
      (PhosphorIconsFill.squaresFour, 'Overview', 0, 0),
      (PhosphorIconsFill.identificationCard, 'Driver verification', 1,
          s.pendingCount),
      (PhosphorIconsFill.receipt, 'Trips & payouts', 2, 0),
    ];
    final soon = [
      (PhosphorIconsFill.users, 'Riders'),
      (PhosphorIconsFill.siren, 'Safety & SOS'),
      (PhosphorIconsFill.mapTrifold, 'Pricing & zones'),
      (PhosphorIconsFill.ticket, 'Promotions'),
      (PhosphorIconsFill.gear, 'Settings'),
    ];
    return Container(
      color: TR.navy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandWord(light: true, size: 17),
                    Text('Admin console',
                        style: TS.small.copyWith(
                            color: const Color(0xFF9FB7D4), fontSize: 11)),
                  ],
                ),
              ]),
              const SizedBox(height: 26),
              for (final it in items)
                _tile(it.$1, it.$2, it.$3 == index, () => onTap(it.$3),
                    badge: it.$4),
              const SizedBox(height: 10),
              for (final it in soon)
                _tile(it.$1, it.$2, false,
                    () => showToast(context, '${it.$2} is coming soon'),
                    badge: it.$2.startsWith('Safety') ? s.sosAlerts : 0,
                    danger: true),
              const Spacer(),
              _tile(PhosphorIconsFill.signOut, 'Exit to app', false,
                  () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(R.rider, (r) => false)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, bool active, VoidCallback onTap,
      {int badge = 0, bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Pressable(
        scale: 0.98,
        onTap: onTap,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.white.fade(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon,
                size: 20,
                color: active ? TR.greenBright : const Color(0xFF9FB7D4)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TS.label.copyWith(
                      fontSize: 14,
                      color: active ? Colors.white : const Color(0xFFC9D6E3))),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: danger ? const Color(0xFFE5484D) : TR.greenBright,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$badge',
                    style: TS.small.copyWith(
                        color: danger ? Colors.white : TR.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Shared admin card + header pieces.
class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = 20, this.color = Colors.white});
  final Widget child;
  final double padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: TR.navy.fade(0.05),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

class AdminHeader extends StatelessWidget {
  const AdminHeader(
      {super.key, required this.title, required this.subtitle, this.actions = const []});
  final String title;
  final String subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TS.h2),
              Text(subtitle, style: TS.small),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
}
