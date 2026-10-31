import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../services/db.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'admin_drivers.dart';
import 'admin_overview.dart';
import 'admin_trips.dart';
import 'admin_settings.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final _scaffold = GlobalKey<ScaffoldState>();
  late final Stream<List<DriverProfile>> _pending = Db.driversByStatus('pending');
  late final Stream<List<SosAlert>> _sos = Db.openSos();

  void _go(int i) {
    setState(() => _index = i);
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.profile;
    if (p == null || !p.isAdmin) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const EmptyState(
                icon: PhosphorIconsFill.lockSimple,
                title: 'Admins only',
                body: 'Ask a TrustRide owner to give your account the admin role.',
              ),
              TRButton(
                label: s.authUser == null ? 'Sign in' : 'Back',
                expand: false,
                onPressed: () => s.authUser == null
                    ? Navigator.of(context).pushNamedAndRemoveUntil(R.signIn, (_) => false)
                    : Navigator.of(context).maybePop(),
              ),
            ]),
          ),
        ),
      );
    }
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
          2 => const AdminTrips(),
          _ => const AdminSettings(),
        },
      ),
    );

    final sidebar = StreamBuilder<List<DriverProfile>>(
      stream: _pending,
      builder: (context, pend) => StreamBuilder<List<SosAlert>>(
        stream: _sos,
        builder: (context, sos) => _Sidebar(
          index: _index,
          onTap: _go,
          pending: pend.data?.length ?? 0,
          sos: sos.data?.length ?? 0,
        ),
      ),
    );

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
  const _Sidebar({
    required this.index,
    required this.onTap,
    required this.pending,
    required this.sos,
  });
  final int index;
  final ValueChanged<int> onTap;
  final int pending;
  final int sos;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.read(context);
    final items = [
      (PhosphorIconsFill.squaresFour, 'Overview', 0, sos, true),
      (PhosphorIconsFill.identificationCard, 'Driver verification', 1, pending, false),
      (PhosphorIconsFill.receipt, 'Trips', 2, 0, false),
      (PhosphorIconsFill.gear, 'Prices & settings', 3, 0, false),
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
                  child: Image.asset('assets/images/logo_mark.png'),
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
                    badge: it.$4, danger: it.$5),
              const Spacer(),
              if (!kIsWeb)
                _tile(PhosphorIconsFill.userSwitch, 'Back to app', false,
                    () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(R.rider, (r) => false)),
              _tile(PhosphorIconsFill.signOut, 'Log out', false, () async {
                await s.signOut();
                if (context.mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(R.signIn, (r) => false);
                }
              }),
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
