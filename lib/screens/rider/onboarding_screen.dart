import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/map_view.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _titles = [
    'Rides across Freetown in a few taps',
    'Pay the way you already pay',
    'Your journey, our trust',
  ];
  static const _bodies = [
    'From Lumley to Kissy, pick a car, keke or okada and see the fare before you book. No haggling.',
    'Orange Money, Afrimoney, TrustRide Wallet or cash. Fares are shown upfront in Leones.',
    'Every driver is verified before their first trip, and every ride is tracked from pickup to drop-off.',
  ];

  void _next() {
    if (_page < 2) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic);
    } else {
      Navigator.of(context).pushReplacementNamed(R.signIn);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const BrandWord(size: 18),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _page < 2 ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: _page < 2
                            ? () => Navigator.of(context)
                                .pushReplacementNamed(R.signIn)
                            : null,
                        child: Text('Skip',
                            style: TS.label.copyWith(color: TR.muted)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: 3,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _OnboardPage(
                    index: i,
                    title: _titles[i],
                    body: _bodies[i],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Row(
                    children: List.generate(3, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? TR.navy : const Color(0xFFC9D6E3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: TRButton(
                      key: ValueKey(_page == 2),
                      label: _page == 2 ? 'Get started' : 'Next',
                      icon: PhosphorIconsBold.arrowRight,
                      expand: false,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _page == 2
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(R.driverSignup),
                          icon: const Icon(PhosphorIconsBold.steeringWheel,
                              size: 18, color: TR.navy),
                          label: Text('I want to drive with TrustRide',
                              style: TS.label.copyWith(color: TR.navy)),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage(
      {required this.index, required this.title, required this.body});
  final int index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final art = switch (index) {
      0 => const _ArtRide(),
      1 => const _ArtPay(),
      _ => const _ArtSafety(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Expanded(child: art.animate().fadeIn(duration: 500.ms).scale(
            begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack)),
        const SizedBox(height: 32),
        Text(title, style: TS.h1)
            .animate()
            .fadeIn(delay: 150.ms)
            .slideY(begin: 0.25, curve: Curves.easeOutCubic),
        const SizedBox(height: 12),
        Text(body, style: TS.body.copyWith(fontSize: 16))
            .animate()
            .fadeIn(delay: 260.ms)
            .slideY(begin: 0.25, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _ArtRide extends StatelessWidget {
  const _ArtRide();
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const TRMap(mode: MapMode.route),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: TRCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const IconBubble(PhosphorIconsFill.carProfile,
                      color: Colors.white, bg: TR.navy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lumley Beach', style: TS.label),
                        Text('4.2 km · 18 min', style: TS.small),
                      ],
                    ),
                  ),
                  Text('Le 85', style: TS.h3.copyWith(color: TR.navy)),
                ]),
              ).animate().slideY(begin: 1, delay: 500.ms, curve: Curves.easeOutBack),
            ),
          ],
        ),
      );
}

class _ArtPay extends StatelessWidget {
  const _ArtPay();
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Orange Money', TR.orangeMoney, true),
      ('Afrimoney', TR.afrimoney, false),
      ('Cash to driver', TR.green, false),
    ];
    return Container(
      decoration: BoxDecoration(
        color: TR.greenTint,
        borderRadius: BorderRadius.circular(30),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
        width: 260,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: TR.shadow(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Caps('Trip fare'),
            const SizedBox(height: 4),
            Text('Le 85.00', style: TS.h1.copyWith(color: TR.navy)),
            const SizedBox(height: 12),
            for (var i = 0; i < rows.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: rows[i].$3 ? TR.green : TR.border,
                      width: rows[i].$3 ? 2 : 1),
                ),
                child: Row(children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: rows[i].$2, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(rows[i].$1, style: TS.label.copyWith(fontSize: 14))),
                  if (rows[i].$3)
                    const Icon(PhosphorIconsFill.checkCircle,
                        color: TR.green, size: 18),
                ]),
              )
                  .animate()
                  .fadeIn(delay: (250 + i * 120).ms)
                  .slideX(begin: 0.2, curve: Curves.easeOutCubic),
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -4, end: 4, duration: 2200.ms, curve: Curves.easeInOut),
      ),
    );
  }
}

class _ArtSafety extends StatelessWidget {
  const _ArtSafety();
  @override
  Widget build(BuildContext context) {
    const items = [
      'ID & licence-checked drivers',
      'Share your trip live with family',
      'One-tap SOS to police & our team',
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [TR.navy, TR.navyDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(24),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
        width: 300,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: TR.green,
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                    color: TR.greenBright.fade(0.4),
                    blurRadius: 40,
                    spreadRadius: 2)
              ],
            ),
            child: const Icon(PhosphorIconsFill.shieldCheck,
                color: Colors.white, size: 58),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.06, duration: 1400.ms, curve: Curves.easeInOut),
          const SizedBox(height: 24),
          for (var i = 0; i < items.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.fade(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.fade(0.08)),
              ),
              child: Row(children: [
                const Icon(PhosphorIconsFill.sealCheck,
                    color: TR.greenBright, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(items[i],
                      style: TS.label.copyWith(color: Colors.white, fontSize: 14)),
                ),
              ]),
            )
                .animate()
                .fadeIn(delay: (300 + i * 140).ms)
                .slideX(begin: -0.15, curve: Curves.easeOutCubic),
        ],
      ),
        ),
      ),
    );
  }
}
