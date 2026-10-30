import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/icons.dart';
import '../../core/launch.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _seconds = 60;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds == 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (_ctrl.text.length < 6 || _verifying) return;
    _focus.unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await AuthService.verifyCode(_ctrl.text);
      if (!mounted) return;
      await goHome(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AuthService.friendlyError(e);
        _ctrl.clear();
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await AuthService.sendCode(widget.phone);
      if (!mounted) return;
      if (AuthService.user != null) {
        await goHome(context);
        return;
      }
      setState(_startTimer);
      showToast(context, 'New code sent');
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
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
    final code = _ctrl.text;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: TRBack()),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: TR.greenTint,
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(PhosphorIconsFill.chatCircleDots,
                    color: TR.green, size: 32),
              ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
            ),
            const SizedBox(height: 20),
            Text('Enter the code', style: TS.h2),
            const SizedBox(height: 8),
            Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Sent by SMS to '),
                  TextSpan(
                      text: widget.phone,
                      style: TS.label.copyWith(fontSize: 15)),
                ]),
                style: TS.body),
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
                              color: _error != null
                                  ? TR.danger
                                  : active
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
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
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
                          setState(() => _error = null);
                          if (v.length == 6) _verify();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TS.small.copyWith(color: TR.danger)),
            ],
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: Text(
                    _seconds > 0
                        ? 'Resend code in 0:${_seconds.toString().padLeft(2, '0')}'
                        : "Didn't get it?",
                    style: TS.small),
              ),
              TextButton(
                onPressed: _seconds == 0 && !_resending ? _resend : null,
                child: Text(_resending ? 'Sending…' : 'Resend',
                    style: TS.label.copyWith(
                        color: _seconds == 0 ? TR.navy : TR.subtle,
                        fontSize: 14)),
              ),
            ]),
            const SizedBox(height: 32),
            TRButton(
              label: 'Verify',
              loading: _verifying,
              onPressed: code.length == 6 ? _verify : null,
            ),
          ],
        ),
      ),
    );
  }
}
