import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// First-time profile creation, and later "Personal info" editing.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String _lang = 'English';
  String? _photo; // new photo picked this session
  bool _picking = false;
  bool _saving = false;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final p = AppScope.read(context).profile;
    if (p != null) {
      _name.text = p.name;
      _email.text = p.email;
      _lang = p.language;
      _photo = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppScope.read(context);
    final user = s.authUser;
    if (user == null) return;
    if (_name.text.trim().length < 2) {
      showToast(context, 'Please enter your name', icon: PhosphorIconsFill.warning);
      return;
    }
    final exists = s.profile != null;
    final cPhone = _contactPhone.text.trim();
    setState(() => _saving = true);
    try {
      await Db.guard(Db.createOrUpdateProfile(
        uid: user.uid,
        phone: user.phoneNumber ?? '',
        name: _name.text.trim(),
        email: _email.text.trim(),
        language: _lang,
        exists: exists,
        photo: _photo,
        emergency: cPhone.isEmpty
            ? null
            : Contact(
                _contactName.text.trim().isEmpty
                    ? 'Emergency contact'
                    : _contactName.text.trim(),
                AuthService.normalise(cPhone)),
      ));
      if (!mounted) return;
      if (_photo != null && s.driver != null) {
        await Db.setPhoto(user.uid, _photo!, isDriver: true);
      }
      if (!mounted) return;
      if (exists) {
        showToast(context, 'Profile saved');
        Navigator.of(context).pop();
      } else {
        await s.waitForProfile();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(R.rider, (_) => false);
      }
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    setState(() => _picking = true);
    try {
      final p = await pickPhotoSheet(context);
      if (p != null && mounted) setState(() => _photo = p);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
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
          textCapitalization: type == null
              ? TextCapitalization.words
              : TextCapitalization.none,
          style: TS.label.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                icon == null ? null : Icon(icon, color: TR.muted, size: 20),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final editing = s.profile != null;
    final initials = _name.text.trim().isEmpty
        ? null
        : _name.text
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p[0])
            .join()
            .toUpperCase();

    final items = <Widget>[
      Row(children: [
        if (editing) const TRBack(),
        const Spacer(),
        const LogoMark(),
      ]),
      const SizedBox(height: 16),
      Text(editing ? 'Personal info' : 'Tell us about you', style: TS.h2),
      const SizedBox(height: 6),
      Text('Drivers see your first name when you book.', style: TS.body),
      const SizedBox(height: 24),
      Row(children: [
        Pressable(
          onTap: _picking ? null : _pickPhoto,
          semanticLabel: 'Change profile photo',
          child: Stack(clipBehavior: Clip.none, children: [
            Avatar(initials ?? '', photo: _photo ?? s.profile?.photo ?? '', size: 88,
                bg: TR.greenTint, fg: TR.green, ring: true),
            if (initials == null && (_photo ?? s.profile?.photo ?? '').isEmpty)
              const Positioned.fill(
                child: Center(child: Icon(PhosphorIconsFill.user, color: TR.green, size: 34)),
              ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: TR.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: _picking
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(PhosphorIconsFill.camera, color: Colors.white, size: 15),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((_photo ?? s.profile?.photo ?? '').isEmpty ? 'Add a profile photo' : 'Looking good',
                  style: TS.label),
              Text(s.authUser?.phoneNumber ?? '', style: TS.small),
              Text('Verified phone number', style: TS.small.copyWith(fontSize: 12, color: TR.green)),
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
      Text('App language', style: TS.small.copyWith(fontWeight: FontWeight.w600)),
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
      const SizedBox(height: 22),
      Text(editing ? 'Add a trusted contact' : 'Emergency contact (recommended)',
          style: TS.label),
      const SizedBox(height: 4),
      Text('We alert them if you press SOS during a ride.', style: TS.small),
      const SizedBox(height: 10),
      _field('Their name', _contactName, icon: PhosphorIconsRegular.user),
      const SizedBox(height: 12),
      _field('Their phone', _contactPhone,
          hint: '77 000 000',
          type: TextInputType.phone,
          icon: PhosphorIconsRegular.phone),
      const SizedBox(height: 28),
      TRButton(
          label: editing ? 'Save' : 'Finish setup',
          loading: _saving,
          onPressed: _save),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            for (var i = 0; i < items.length; i++)
              items[i]
                  .animate()
                  .fadeIn(delay: (30 * i).ms, duration: 300.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
