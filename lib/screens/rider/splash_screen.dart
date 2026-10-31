import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/launch.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final s = AppScope.read(context);
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1600)),
      s.ready.timeout(const Duration(seconds: 12), onTimeout: () {}),
    ]);
    _go();
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    goHome(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // soft brand glow
            Positioned(
              top: -120,
              right: -120,
              child: _Glow(color: TR.greenBright.fade(0.16), size: 320),
            ),
            Positioned(
              bottom: -140,
              left: -120,
              child: _Glow(color: TR.navy.fade(0.10), size: 360),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Image.asset('assets/images/logo.png',
                        width: 320, semanticLabel: 'TrustRide'),
                  )
                      .animate()
                      .scale(
                          begin: const Offset(0.7, 0.7),
                          duration: 900.ms,
                          curve: Curves.elasticOut)
                      .fadeIn(duration: 500.ms),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 1 ? TR.green : TR.navy,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(
                              begin: 0.6,
                              end: 1.1,
                              delay: (i * 160).ms,
                              duration: 520.ms,
                              curve: Curves.easeInOut);
                    }),
                  ).animate().fadeIn(delay: 600.ms),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _Flag(),
                      const SizedBox(width: 8),
                      Text('Made in Salone · Freetown', style: TS.small),
                    ],
                  ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.4),
                  const SizedBox(height: 14),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: TR.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TR.line),
                    ),
                    child: Column(children: [
                      Text('POWERED BY',
                          style: TS.caps.copyWith(fontSize: 10, letterSpacing: 1.6)),
                      const SizedBox(height: 2),
                      Text('Easy Trust Corporation LTD',
                          textAlign: TextAlign.center,
                          style: TS.label.copyWith(color: TR.navy, fontSize: 14)),
                    ]),
                  ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.4),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.fade(0)]),
        ),
      );
}

class _Flag extends StatelessWidget {
  const _Flag();
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: 24,
          height: 16,
          decoration: BoxDecoration(border: Border.all(color: TR.border)),
          child: const Column(children: [
            Expanded(child: ColoredBox(color: Color(0xFF1EB53A))),
            Expanded(child: ColoredBox(color: Colors.white)),
            Expanded(child: ColoredBox(color: Color(0xFF0072C6))),
          ]),
        ),
      );
}
