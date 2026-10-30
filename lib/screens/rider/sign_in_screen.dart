import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _ctrl = TextEditingController(text: '76 123 456');
  bool _loading = false;

  bool get _valid => _ctrl.text.replaceAll(' ', '').length == 8;

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    AppScope.read(context).setPhone(_ctrl.text);
    setState(() => _loading = false);
    Navigator.of(context).pushNamed(R.otp);
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
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 36),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          autofocus: false,
                          onChanged: (_) => setState(() {}),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: TS.label.copyWith(
                              fontSize: 18, letterSpacing: 1.2),
                          decoration: InputDecoration(
                            hintText: '76 123 456',
                            suffixIcon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _valid
                                  ? const Icon(PhosphorIconsFill.checkCircle,
                                      key: ValueKey(1), color: TR.green)
                                  : const SizedBox(key: ValueKey(0)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(PhosphorIconsRegular.simCard,
                          size: 15, color: TR.muted),
                      const SizedBox(width: 6),
                      Text('Works with Orange, Africell and Qcell lines',
                          style: TS.small),
                    ]),
                    const Spacer(),
                    const SizedBox(height: 24),
                    TRButton(
                      label: 'Send code',
                      loading: _loading,
                      onPressed: _valid ? _send : null,
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Expanded(child: Divider(color: TR.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TS.small),
                      ),
                      const Expanded(child: Divider(color: TR.line)),
                    ]),
                    const SizedBox(height: 16),
                    TRButton(
                      label: 'Continue with email',
                      kind: BtnKind.outline,
                      onPressed: () => showToast(
                          context, 'Email sign-in is coming soon',
                          icon: PhosphorIconsFill.envelope),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        "By continuing you agree to TrustRide's Terms and Privacy Policy.",
                        textAlign: TextAlign.center,
                        style: TS.small.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
