import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _seconds = 45;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (_ctrl.text.length < 6) return;
    _focus.unfocus();
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(R.profileSetup, (route) => false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = AppScope.of(context).phone;
    final code = _ctrl.text;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TRBack(),
              const SizedBox(height: 28),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: TR.greenTint,
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(PhosphorIconsFill.chatCircleDots,
                    color: TR.green, size: 32),
              ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
              const SizedBox(height: 20),
              Text('Enter the code', style: TS.h2),
              const SizedBox(height: 8),
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Sent by SMS to '),
                TextSpan(
                    text: '+232 $phone',
                    style: TS.label.copyWith(fontSize: 15)),
              ]), style: TS.body),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => _focus.requestFocus(),
                child: Stack(
                  children: [
                    Row(
                      children: List.generate(6, (i) {
                        final filled = i < code.length;
                        final active = i == code.length && _focus.hasFocus;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 62,
                            margin: EdgeInsets.only(right: i < 5 ? 10 : 0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: filled ? TR.greenTint : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: active
                                    ? TR.navy
                                    : filled
                                        ? TR.green
                                        : TR.border,
                                width: active || filled ? 2 : 1,
                              ),
                            ),
                            child: filled
                                ? Text(code[i],
                                        style: TS.h2.copyWith(fontSize: 24))
                                    .animate()
                                    .scale(
                                        begin: const Offset(0.5, 0.5),
                                        curve: Curves.easeOutBack,
                                        duration: 220.ms)
                                : null,
                          ),
                        );
                      }),
                    ),
                    Opacity(
                      opacity: 0,
                      child: SizedBox(
                        height: 62,
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (v) {
                            setState(() {});
                            if (v.length == 6) _verify();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Text(
                    _seconds > 0
                        ? 'Resend code in 0:${_seconds.toString().padLeft(2, '0')}'
                        : "Didn't get it?",
                    style: TS.small),
                const Spacer(),
                TextButton(
                  onPressed: _seconds == 0
                      ? () {
                          setState(_startTimer);
                          showToast(context, 'New code sent');
                        }
                      : null,
                  child: Text('Resend',
                      style: TS.label.copyWith(
                          color: _seconds == 0 ? TR.navy : TR.subtle,
                          fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Demo: type any 6 digits.',
                  style: TS.small.copyWith(fontSize: 12)),
              const Spacer(),
              TRButton(
                label: 'Verify',
                loading: _verifying,
                onPressed: code.length == 6 ? _verify : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
