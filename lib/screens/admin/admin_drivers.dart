import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

class AdminDrivers extends StatefulWidget {
  const AdminDrivers({super.key});
  @override
  State<AdminDrivers> createState() => _AdminDriversState();
}

class _AdminDriversState extends State<AdminDrivers> {
  String _tab = 'pending';
  int _sel = 0;

  static const _docs = [
    ('National ID', 'Matches', PillKind.success),
    ('Driver licence', 'Valid', PillKind.success),
    ('Profile photo', 'Matches ID', PillKind.success),
    ('Vehicle licence', 'Check plate', PillKind.warning),
    ('Insurance', 'Valid', PillKind.success),
    ('Police clearance', 'Blurry', PillKind.danger),
  ];

  void _decide(AppState s, Applicant a, String status) {
    s.review(a, status);
    showToast(
        context,
        status == 'approved'
            ? '${a.name} approved — they can go online now'
            : '${a.name} rejected and notified by SMS',
        icon: status == 'approved'
            ? PhosphorIconsFill.sealCheck
            : PhosphorIconsFill.xCircle);
    setState(() => _sel = 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.applicants.where((a) => a.status == _tab).toList();
    if (_sel >= list.length) _sel = 0;
    final a = list.isEmpty ? null : list[_sel];

    final tabs = [
      ('pending', 'Pending (${s.pendingCount})'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
    ];

    final queue = AdminCard(
      padding: 8,
      child: list.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(30),
              child: Column(children: [
                const Icon(PhosphorIconsFill.confetti,
                    color: TR.green, size: 40),
                const SizedBox(height: 8),
                Text('Nothing here', style: TS.label),
                Text('The queue is clear', style: TS.small),
              ]),
            )
          : Column(children: [
              for (var i = 0; i < list.length; i++)
                Pressable(
                  scale: 0.98,
                  onTap: () => setState(() => _sel = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: i == _sel ? TR.greenTint : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Avatar(list[i].initials, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(list[i].name, style: TS.label.copyWith(fontSize: 14)),
                            Text('${list[i].kind} · ${list[i].city}',
                                style: TS.small.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(list[i].age, style: TS.small.copyWith(fontSize: 11)),
                    ]),
                  ),
                ).animate().fadeIn(delay: (40 * i).ms).slideX(begin: -0.05),
            ]),
    );

    final detail = a == null
        ? const SizedBox.shrink()
        : AdminCard(
            key: ValueKey(a.name),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Avatar(a.initials, size: 64, ring: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: TS.h2.copyWith(fontSize: 22)),
                        Text('${a.kind} · ${a.city} · ${a.phone}', style: TS.small),
                      ],
                    ),
                  ),
                  Pill(
                    a.status == 'pending'
                        ? 'Awaiting review'
                        : a.status == 'approved'
                            ? 'Approved'
                            : 'Rejected',
                    kind: a.status == 'pending'
                        ? PillKind.warning
                        : a.status == 'approved'
                            ? PillKind.success
                            : PillKind.danger,
                  ),
                ]),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 600 ? 3 : 2;
                  final w = (c.maxWidth - (cols - 1) * 12) / cols - 0.5;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final d in _docs)
                      SizedBox(
                        width: w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pressable(
                              onTap: () => showToast(context, 'Opening ${d.$1} image…',
                                  icon: PhosphorIconsFill.image),
                              child: Container(
                                height: 96,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF1F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFD5DDE7)),
                                ),
                                child: const Center(
                                  child: Icon(PhosphorIconsRegular.image,
                                      color: TR.subtle, size: 30),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(
                                  child: Text(d.$1,
                                      style: TS.label.copyWith(fontSize: 13))),
                              Pill(d.$2, kind: d.$3),
                            ]),
                          ],
                        ),
                      ),
                  ]);
                }),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _info('Vehicle', a.vehicle),
                  _info('Plate', a.plate),
                  _info('Payout wallet', a.wallet),
                ]),
                const SizedBox(height: 14),
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                      hintText: 'Reviewer notes (visible to the review team only)'),
                ),
                const SizedBox(height: 16),
                if (a.status == 'pending')
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    children: [
                      TRButton(
                          label: 'Reject',
                          kind: BtnKind.outline,
                          expand: false,
                          height: 48,
                          onPressed: () => _decide(s, a, 'rejected')),
                      TRButton(
                          label: 'Request re-upload',
                          kind: BtnKind.outline,
                          expand: false,
                          height: 48,
                          onPressed: () => showToast(context,
                              'SMS sent to ${a.name} asking for a clearer police clearance photo')),
                      TRButton(
                          label: 'Approve driver',
                          icon: PhosphorIconsBold.check,
                          expand: false,
                          height: 48,
                          onPressed: () => _decide(s, a, 'approved')),
                    ],
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminHeader(
          title: 'Driver verification',
          subtitle: '${s.pendingCount} applications waiting · target 48 hours',
          actions: [
            for (final t in tabs)
              Pressable(
                onTap: () => setState(() {
                  _tab = t.$1;
                  _sel = 0;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == t.$1 ? TR.navy : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _tab == t.$1 ? TR.navy : TR.border),
                  ),
                  child: Text(t.$2,
                      style: TS.label.copyWith(
                          fontSize: 13,
                          color: _tab == t.$1 ? Colors.white : TR.ink)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
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
        }),
      ],
    );
  }

  Widget _info(String label, String value) => Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: TR.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TS.small.copyWith(fontSize: 12)),
            Text(value, style: TS.label.copyWith(fontSize: 14)),
          ],
        ),
      );
}
