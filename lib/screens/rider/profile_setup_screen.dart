import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController(text: 'Aminata Kamara');
  final _email = TextEditingController();
  final _contact = TextEditingController();
  String _lang = 'English';
  bool _photo = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _finish() {
    final s = AppScope.read(context);
    s.setProfile(_name.text, _lang);
    if (_contact.text.trim().isNotEmpty) {
      s.addContact('Emergency contact · +232 ${_contact.text.trim()}');
    }
    Navigator.of(context).pushNamedAndRemoveUntil(R.rider, (r) => false);
  }

  Widget _field(String label, TextEditingController c,
      {String? hint, TextInputType? type, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TS.small.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          keyboardType: type,
          style: TS.label.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, color: TR.muted, size: 20),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Text('Tell us about you', style: TS.h2),
      const SizedBox(height: 6),
      Text('Drivers see your first name and photo when you book.',
          style: TS.body),
      const SizedBox(height: 24),
      Row(children: [
        Pressable(
          onTap: () => setState(() => _photo = !_photo),
          semanticLabel: 'Add photo',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _photo ? TR.brandGradient : null,
              color: _photo ? null : TR.greenTint,
            ),
            child: Center(
              child: _photo
                  ? Text('AK',
                      style: TS.h2.copyWith(color: Colors.white))
                  : const Icon(PhosphorIconsFill.camera,
                      color: TR.green, size: 34),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_photo ? 'Looking good' : 'Add a profile photo',
                  style: TS.label),
              Text('Helps drivers find you at pickup', style: TS.small),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 22),
      _field('Full name', _name, icon: PhosphorIconsRegular.user),
      const SizedBox(height: 16),
      _field('Email (optional, for receipts)', _email,
          hint: 'you@example.com',
          type: TextInputType.emailAddress,
          icon: PhosphorIconsRegular.envelope),
      const SizedBox(height: 16),
      Text('App language',
          style: TS.small.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(
        children: ['English', 'Krio'].map((l) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: l == 'English' ? 10 : 0),
              child: SelectTile(
                selected: _lang == l,
                onTap: () => setState(() => _lang = l),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsRegular.translate,
                        size: 18, color: _lang == l ? TR.green : TR.muted),
                    const SizedBox(width: 8),
                    Text(l, style: TS.label),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      _field('Emergency contact', _contact,
          hint: '77 000 000',
          type: TextInputType.phone,
          icon: PhosphorIconsRegular.firstAid),
      const SizedBox(height: 28),
      TRButton(label: 'Finish setup', onPressed: _finish),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            for (var i = 0; i < items.length; i++)
              items[i]
                  .animate()
                  .fadeIn(delay: (40 * i).ms, duration: 350.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
