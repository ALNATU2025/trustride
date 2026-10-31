import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

class AdminDrivers extends StatefulWidget {
  const AdminDrivers({super.key});
  @override
  State<AdminDrivers> createState() => _AdminDriversState();
}

class _AdminDriversState extends State<AdminDrivers> {
  String _tab = 'pending';
  late Stream<List<DriverProfile>> _list = Db.driversByStatus(_tab);
  String? _selId;

  static const _tabs = [
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
    ('suspended', 'Suspended'),
  ];

  void _setTab(String t) => setState(() {
        _tab = t;
        _list = Db.driversByStatus(t);
        _selId = null;
      });

  Future<void> _decide(DriverProfile d, String status) async {
    var reason = '';
    if (status == 'rejected' || status == 'suspended') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(status == 'rejected' ? 'Reject application' : 'Suspend driver',
              style: TS.h3),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Reason (shown to the driver), e.g. licence photo unreadable'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text('Cancel', style: TS.label.copyWith(color: TR.muted))),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text('Confirm', style: TS.label.copyWith(color: TR.danger))),
          ],
        ),
      );
      reason = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true) return;
    }
    try {
      await Db.reviewDriver(d.uid, status, reason: reason);
      if (!mounted) return;
      showToast(
          context,
          switch (status) {
            'approved' => '${d.name} approved — they can go online now',
            'rejected' => '${d.name} rejected',
            'suspended' => '${d.name} suspended',
            _ => 'Updated',
          },
          icon: status == 'approved' ? PhosphorIconsFill.sealCheck : PhosphorIconsFill.info);
      setState(() => _selId = null);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminHeader(
          title: 'Driver verification',
          subtitle: 'Check documents in person before approving',
          actions: [
            for (final t in _tabs)
              Pressable(
                onTap: () => _setTab(t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == t.$1 ? TR.navy : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tab == t.$1 ? TR.navy : TR.border),
                  ),
                  child: Text(t.$2,
                      style: TS.label.copyWith(
                          fontSize: 13, color: _tab == t.$1 ? Colors.white : TR.ink)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<DriverProfile>>(
          stream: _list,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(
                  icon: PhosphorIconsFill.warning,
                  title: 'Couldn’t load drivers',
                  body: errorText(snap.error!));
            }
            if (!snap.hasData) return const Loading();
            final list = snap.data!
              ..sort((a, b) => (a.createdAt ?? DateTime(2100))
                  .compareTo(b.createdAt ?? DateTime(2100)));
            if (list.isEmpty) {
              return const AdminCard(
                child: EmptyState(
                    icon: PhosphorIconsFill.confetti,
                    title: 'Nothing here',
                    body: 'No drivers in this list.'),
              );
            }
            final sel = list.firstWhere((d) => d.uid == _selId, orElse: () => list.first);

            final queue = AdminCard(
              padding: 8,
              child: Column(children: [
                for (var i = 0; i < list.length; i++)
                  Pressable(
                    scale: 0.98,
                    onTap: () => setState(() => _selId = list[i].uid),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: list[i].uid == sel.uid ? TR.greenTint : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Avatar(list[i].initials, photo: list[i].photo, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(list[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TS.label.copyWith(fontSize: 14)),
                              Text(
                                  '${AppScope.read(context).config.ride(list[i].vehicleType).name} · ${list[i].plate}',
                                  style: TS.small.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(timeAgo(list[i].createdAt), style: TS.small.copyWith(fontSize: 11)),
                      ]),
                    ),
                  ).animate().fadeIn(delay: (30 * i.clamp(0, 15)).ms),
              ]),
            );

            final detail = _detail(sel);

            return LayoutBuilder(builder: (context, c) {
              if (c.maxWidth > 860) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 320, child: queue),
                    const SizedBox(width: 16),
                    Expanded(child: detail),
                  ],
                );
              }
              return Column(children: [queue, const SizedBox(height: 16), detail]);
            });
          },
        ),
      ],
    );
  }

  Widget _detail(DriverProfile d) {
    final s = AppScope.read(context);
    final fields = [
      ('Phone', d.phone),
      ('Vehicle type', s.config.ride(d.vehicleType).name),
      ('Vehicle', d.vehicle),
      ('Plate', d.plate),
      ('NIN', d.nin),
      ('Licence no.', d.licence),
      ('Insurance', d.insurance.isEmpty ? '—' : d.insurance),
      ('Paid by riders at', d.account.isEmpty ? '—' : '${d.account.title} · ${d.account.accountNumber} · ${d.account.accountName}'),
      ('Rating', d.ratingCount == 0 ? 'No ratings yet' : '${d.rating.toStringAsFixed(2)} (${d.ratingCount})'),
      ('Applied', dateLabel(d.createdAt)),
      if (d.rejectReason.isNotEmpty) ('Reason given', d.rejectReason),
    ];
    return AdminCard(
      key: ValueKey(d.uid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Avatar(d.initials, photo: d.photo, size: 72, ring: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: TS.h2.copyWith(fontSize: 22)),
                  Text(d.online ? 'Online now' : 'Offline',
                      style: TS.small.copyWith(color: d.online ? TR.green : TR.muted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Call driver',
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: d.phone)),
              icon: const Icon(PhosphorIconsFill.phone, color: TR.navy),
            ),
          ]),
          const SizedBox(height: 18),
          for (final f in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 120, child: Text(f.$1, style: TS.small)),
                Expanded(child: SelectableText(f.$2, style: TS.label.copyWith(fontSize: 14))),
              ]),
            ),
          const SizedBox(height: 14),
          if (d.status == 'approved' || d.status == 'suspended') ...[
            _CommissionBox(driver: d),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: TR.amberTint, borderRadius: BorderRadius.circular(12)),
            child: Text(
                'Verify the original NIN card, licence and vehicle papers in person and check the numbers match before approving.',
                style: TS.small.copyWith(color: TR.ink)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              if (d.status == 'pending') ...[
                TRButton(
                    label: 'Reject',
                    kind: BtnKind.outline,
                    expand: false,
                    height: 48,
                    onPressed: () => _decide(d, 'rejected')),
                TRButton(
                    label: 'Approve driver',
                    icon: PhosphorIconsBold.check,
                    expand: false,
                    height: 48,
                    onPressed: () => _decide(d, 'approved')),
              ],
              if (d.status == 'approved')
                TRButton(
                    label: 'Suspend',
                    kind: BtnKind.danger,
                    expand: false,
                    height: 48,
                    onPressed: () => _decide(d, 'suspended')),
              if (d.status == 'suspended' || d.status == 'rejected')
                TRButton(
                    label: 'Approve',
                    expand: false,
                    height: 48,
                    onPressed: () => _decide(d, 'approved')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

/// Commission owed by a driver (from their completed trips) and a button to
/// record payments they make to TrustRide.
class _CommissionBox extends StatefulWidget {
  const _CommissionBox({required this.driver});
  final DriverProfile driver;
  @override
  State<_CommissionBox> createState() => _CommissionBoxState();
}

class _CommissionBoxState extends State<_CommissionBox> {
  late Stream<List<Trip>> _trips = Db.driverTrips(widget.driver.uid);

  @override
  void didUpdateWidget(covariant _CommissionBox old) {
    super.didUpdateWidget(old);
    if (old.driver.uid != widget.driver.uid) _trips = Db.driverTrips(widget.driver.uid);
  }

  Future<void> _record(double owed) async {
    final ctrl = TextEditingController(text: owed > 0 ? owed.round().toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Record commission payment', style: TS.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'Le ', hintText: 'Amount received'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel', style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Record', style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    final amt = double.tryParse(ctrl.text.trim());
    ctrl.dispose();
    if (ok != true || amt == null || amt <= 0) return;
    try {
      await Db.recordCommissionPayment(widget.driver.uid, amt);
      if (mounted) showToast(context, 'Recorded ${TR.le(amt)} from ${widget.driver.name}');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).config.commission;
    return StreamBuilder<List<Trip>>(
      stream: _trips,
      builder: (context, snap) {
        final done = (snap.data ?? const <Trip>[]).where((t) => t.status == TripStatus.completed);
        final gross = done.fold<double>(0, (a, t) => a + t.fare);
        final owed = gross * c - widget.driver.commissionPaid;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: owed > 0.5 ? TR.amberTint : TR.greenTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${done.length} trips · ${TR.le(gross)} fares', style: TS.small),
                Text(owed > 0.5 ? 'Commission owed: ${TR.le(owed)}' : 'Commission paid up',
                    style: TS.label.copyWith(color: owed > 0.5 ? TR.amberInk : const Color(0xFF1F6B2E))),
                Text('Paid so far: ${TR.le(widget.driver.commissionPaid)}', style: TS.small.copyWith(fontSize: 12)),
              ]),
              TRButton(
                label: 'Record payment',
                icon: PhosphorIconsBold.plus,
                expand: false,
                height: 42,
                onPressed: () => _record(owed),
              ),
            ],
          ),
        );
      },
    );
  }
}
