import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});
  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  String? _uploading;
  bool _submitting = false;

  Future<void> _upload(AppState s, String doc) async {
    setState(() => _uploading = doc);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    s.uploadDoc(doc);
    setState(() => _uploading = null);
    showToast(context, '$doc uploaded — in review');
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _submitting = false);
    showToast(context, 'Submitted! Preview the driver app while we review.',
        icon: PhosphorIconsFill.sealCheck);
    Navigator.of(context).pushReplacementNamed(R.driver);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final total = s.driverDocs.length;
    final done = s.docsDone;
    final docs = s.driverDocs.entries.toList();
    const vehicles = [
      ('Car', PhosphorIconsFill.carProfile),
      ('Keke', PhosphorIconsFill.scooter),
      ('Okada', PhosphorIconsFill.motorcycle),
    ];

    return Scaffold(
      backgroundColor: TR.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(children: [
              const TRBack(light: true),
              const SizedBox(width: 12),
              const Pill('TrustRide Driver',
                  icon: PhosphorIconsFill.steeringWheel),
            ]),
            const SizedBox(height: 18),
            Text('Get verified to drive', style: TS.h2),
            const SizedBox(height: 6),
            Text('Upload clear photos. Our Freetown team reviews within 48 hours.',
                style: TS.body),
            const SizedBox(height: 18),
            Row(children: [
              Text('$done of $total complete', style: TS.label.copyWith(fontSize: 13)),
              const Spacer(),
              Text('${(done / total * 100).round()}%',
                  style: TS.label.copyWith(color: TR.green, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: done / total),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: TR.line,
                  color: TR.green,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Caps('Vehicle type'),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 0; i < vehicles.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    child: SelectTile(
                      selected: s.driverVehicle == vehicles[i].$1,
                      onTap: () => s.setDriverVehicle(vehicles[i].$1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(children: [
                        Icon(vehicles[i].$2,
                            size: 26,
                            color: s.driverVehicle == vehicles[i].$1
                                ? TR.green
                                : TR.navy),
                        const SizedBox(height: 4),
                        Text(vehicles[i].$1,
                            style: TS.label.copyWith(fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 20),
            const Caps('Documents'),
            const SizedBox(height: 8),
            TRCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (var i = 0; i < docs.length; i++)
                  _DocRow(
                    name: docs[i].key,
                    status: docs[i].value,
                    busy: _uploading == docs[i].key,
                    onUpload: () => _upload(s, docs[i].key),
                  ).animate().fadeIn(delay: (40 * i).ms).slideX(begin: 0.05),
              ]),
            ),
            const SizedBox(height: 22),
            TRButton(
              label: done == total ? 'Submit for review' : 'Submit what I have',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.name,
    required this.status,
    required this.busy,
    required this.onUpload,
  });
  final String name;
  final String status;
  final bool busy;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (status) {
      'approved' => (PhosphorIconsFill.checkCircle, TR.green, TR.greenTint),
      'review' => (PhosphorIconsFill.hourglassMedium, TR.amberInk, TR.amberTint),
      _ => (PhosphorIconsFill.cloudArrowUp, TR.navy, TR.field),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        IconBubble(icon, color: color, bg: bg, size: 40),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: TS.label.copyWith(fontSize: 14))),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: busy
              ? const SizedBox(
                  key: ValueKey('b'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4))
              : status == 'upload'
                  ? TRButton(
                      key: const ValueKey('u'),
                      label: 'Upload',
                      kind: BtnKind.dark,
                      expand: false,
                      height: 38,
                      onPressed: onUpload,
                    )
                  : Pill(
                      status == 'approved' ? 'Approved' : 'In review',
                      key: ValueKey(status),
                      kind: status == 'approved'
                          ? PillKind.success
                          : PillKind.warning,
                    ),
        ),
      ]),
    );
  }
}
