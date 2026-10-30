import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key, required this.tripId});
  final String tripId;
  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  late final Future<Trip?> _trip = widget.tripId.isEmpty
      ? Future.value(null)
      : Db.tripStream(widget.tripId).first;
  int _stars = 5;
  int _tip = 0;
  bool _saving = false;
  final _comment = TextEditingController();
  final Set<String> _tags = {};
  static const _allTags = [
    'Safe driving',
    'Polite',
    'Clean vehicle',
    'On time',
    'Knew the route',
    'Good music',
  ];
  static const _tips = [0, 5, 10, 20];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _home() =>
      Navigator.of(context).pushNamedAndRemoveUntil(R.rider, (_) => false);

  Future<void> _submit(Trip t) async {
    final s = AppScope.read(context);
    setState(() => _saving = true);
    try {
      await Db.rateTrip(
        trip: t,
        stars: _stars,
        tags: _tags.toList(),
        comment: _comment.text.trim(),
        tip: _tip.toDouble(),
        uid: s.authUser!.uid,
      );
      if (!mounted) return;
      showToast(context, 'Thanks! Your feedback keeps TrustRide safe',
          icon: PhosphorIconsFill.heart);
      _home();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Trip?>(
          future: _trip,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Loading();
            final t = snap.data;
            if (t == null) {
              return Center(
                child: TRButton(label: 'Back to home', expand: false, onPressed: _home),
              );
            }
            final wallet = t.payment == 'wallet';
            final balance = s.profile?.wallet ?? 0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                Center(
                  child: Avatar(t.driverInitials, size: 96, ring: true)
                      .animate()
                      .scale(curve: Curves.easeOutBack, duration: 500.ms),
                ),
                const SizedBox(height: 16),
                Text('How was your ride with ${t.driverName.split(' ').first}?',
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
                    for (final tag in _allTags)
                      SelectTile(
                        selected: _tags.contains(tag),
                        radius: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        onTap: () => setState(() =>
                            _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag)),
                        child: Text(tag, style: TS.label.copyWith(fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _comment,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Tell us more (optional)'),
                ),
                const SizedBox(height: 20),
                Text(
                    wallet
                        ? 'Add a tip from your wallet'
                        : 'Did you give a cash tip? (for our records)',
                    style: TS.small.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < _tips.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                          child: Opacity(
                            opacity: wallet && _tips[i] > balance ? 0.4 : 1,
                            child: SelectTile(
                              selected: _tip == _tips[i],
                              onTap: () {
                                if (wallet && _tips[i] > balance) return;
                                setState(() => _tip = _tips[i]);
                              },
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              radius: 14,
                              child: Center(
                                child: Text(_tips[i] == 0 ? 'No tip' : 'Le ${_tips[i]}',
                                    style: TS.label.copyWith(fontSize: 14)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                TRButton(label: 'Submit', loading: _saving, onPressed: () => _submit(t)),
                const SizedBox(height: 6),
                TRButton(label: 'Skip', kind: BtnKind.ghost, height: 46, onPressed: _home),
              ],
            );
          },
        ),
      ),
    );
  }
}
