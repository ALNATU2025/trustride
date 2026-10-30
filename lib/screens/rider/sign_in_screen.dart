import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/icons.dart';
import '../../core/launch.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _valid {
    final d = _ctrl.text.replaceAll(RegExp(r'\D'), '');
    final local = d.startsWith('0') ? d.substring(1) : d;
    return local.length == 8;
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final phone = AuthService.normalise(_ctrl.text);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.sendCode(phone);
      if (!mounted) return;
      if (AuthService.user != null) {
        // Android verified the number automatically.
        await goHome(context);
        return;
      }
      Navigator.of(context).pushNamed(R.otp, arguments: phone);
    } catch (e) {
      setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Image.asset('assets/images/logo.png',
                    width: 96, height: 96, semanticLabel: 'TrustRide')
                .animate()
                .fadeIn()
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 20),
            Text('Enter your phone number', style: TS.h2),
            const SizedBox(height: 8),
            Text("We'll text you a 6-digit code to confirm it's you.",
                style: TS.body),
            const SizedBox(height: 28),
            Text('Mobile number',
                style: TS.small.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TR.border),
                ),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const SizedBox(
                      width: 24,
                      height: 16,
                      child: Column(children: [
                        Expanded(child: ColoredBox(color: Color(0xFF1EB53A))),
                        Expanded(child: ColoredBox(color: Color(0xFFF2F2F2))),
                        Expanded(child: ColoredBox(color: Color(0xFF0072C6))),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('+232', style: TS.label.copyWith(fontSize: 16)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _valid && !_loading ? _send() : null,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: TS.label.copyWith(fontSize: 18, letterSpacing: 1.2),
                  decoration: InputDecoration(
                    hintText: '76 000 000',
                    suffixIcon: _valid
                        ? const Icon(PhosphorIconsFill.checkCircle,
                            color: TR.green)
                        : null,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(PhosphorIconsRegular.simCard, size: 15, color: TR.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Any Sierra Leone mobile number',
                    style: TS.small),
              ),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: TR.dangerTint,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(PhosphorIconsFill.warning,
                            color: TR.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: TS.small.copyWith(color: TR.ink))),
                      ]),
                    ),
            ),
            const SizedBox(height: 32),
            TRButton(
              label: 'Send code',
              loading: _loading,
              onPressed: _valid ? _send : null,
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                "By continuing you agree to TrustRide's Terms and Privacy Policy. Standard SMS rates may apply.",
                textAlign: TextAlign.center,
                style: TS.small.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
