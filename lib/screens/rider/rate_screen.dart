import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});
  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  int _stars = 5;
  final Set<String> _tags = {'Safe driving', 'Polite'};
  static const _allTags = [
    'Safe driving',
    'Polite',
    'Clean car',
    'On time',
    'Knew the route',
    'Good music',
  ];
  static const _tips = [0, 5, 10, 20];

  void _done() {
    final s = AppScope.read(context);
    s.finishTrip(_stars);
    showToast(context, 'Thanks! Your feedback keeps TrustRide safe',
        icon: PhosphorIconsFill.heart);
    Navigator.of(context).pushNamedAndRemoveUntil(R.rider, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    const d = Mock.driver;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(
              child: Avatar(d.initials, size: 96, ring: true)
                  .animate()
                  .scale(curve: Curves.easeOutBack, duration: 500.ms),
            ),
            const SizedBox(height: 16),
            Text('How was your ride with Mohamed?',
                textAlign: TextAlign.center, style: TS.h2),
            const SizedBox(height: 6),
            Text('Your rating helps keep TrustRide safe',
                textAlign: TextAlign.center, style: TS.small),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final on = i < _stars;
                return Pressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _stars = i + 1);
                  },
                  semanticLabel: '${i + 1} stars',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedScale(
                      scale: on ? 1 : 0.85,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        on ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                        size: 46,
                        color: on ? TR.gold : TR.border,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  ['Terrible', 'Poor', 'Okay', 'Good', 'Excellent'][_stars - 1],
                  key: ValueKey(_stars),
                  style: TS.label.copyWith(color: TR.green),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _allTags)
                  SelectTile(
                    selected: _tags.contains(t),
                    radius: 22,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    onTap: () => setState(() =>
                        _tags.contains(t) ? _tags.remove(t) : _tags.add(t)),
                    child: Text(t, style: TS.label.copyWith(fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Tell us more (optional)'),
            ),
            const SizedBox(height: 20),
            Text('Add a tip for Mohamed',
                style: TS.small.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _tips.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                      child: SelectTile(
                        selected: s.tip == _tips[i],
                        onTap: () => s.setTip(_tips[i]),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        radius: 14,
                        child: Center(
                          child: Text(
                              _tips[i] == 0 ? 'No tip' : 'Le ${_tips[i]}',
                              style: TS.label.copyWith(fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            TRButton(label: 'Submit', onPressed: _done),
            const SizedBox(height: 6),
            TRButton(
                label: 'Skip',
                kind: BtnKind.ghost,
                height: 46,
                onPressed: () {
                  AppScope.read(context).finishTrip(5);
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(R.rider, (r) => false);
                }),
          ],
        ),
      ),
    );
  }
}
