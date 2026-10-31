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

/// Driver application form, payment account, and review status.
class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});
  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final _name = TextEditingController();
  final _vehicle = TextEditingController();
  final _plate = TextEditingController();
  final _nin = TextEditingController();
  final _licence = TextEditingController();
  final _insurance = TextEditingController();
  final _accName = TextEditingController();
  final _accNumber = TextEditingController();
  final _bank = TextEditingController();
  String _type = 'car';
  String _provider = 'Orange Money';
  String _photo = '';
  bool _saving = false;
  bool _editing = false;
  bool _editingAccount = false;
  bool _filled = false;

  static const _providers = ['Orange Money', 'Afrimoney', 'Bank'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final s = AppScope.read(context);
    final d = s.driver;
    _name.text = d?.name ?? s.profile?.name ?? '';
    _photo = d?.photo.isNotEmpty == true ? d!.photo : (s.profile?.photo ?? '');
    _accName.text = d?.account.accountName ?? s.profile?.name ?? '';
    if (d != null) {
      _type = d.vehicleType;
      _vehicle.text = d.vehicle;
      _plate.text = d.plate;
      _nin.text = d.nin;
      _licence.text = d.licence;
      _insurance.text = d.insurance;
      _provider = _providers.contains(d.account.provider) ? d.account.provider : 'Orange Money';
      _accNumber.text = d.account.accountNumber.replaceFirst('+232', '');
      _bank.text = d.account.bankName;
    } else {
      _accNumber.text = (s.profile?.phone ?? '').replaceFirst('+232', '');
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _vehicle, _plate, _nin, _licence, _insurance, _accName, _accNumber, _bank]) {
      c.dispose();
    }
    super.dispose();
  }

  PayAccount get _account => PayAccount(
        provider: _provider,
        accountName: _accName.text.trim(),
        accountNumber: _provider == 'Bank'
            ? _accNumber.text.trim()
            : AuthService.normalise(_accNumber.text),
        bankName: _provider == 'Bank' ? _bank.text.trim() : '',
      );

  String? _accountProblem() {
    if (_accName.text.trim().length < 2) return 'account name';
    if (_accNumber.text.trim().isEmpty) {
      return _provider == 'Bank' ? 'account number' : 'mobile money number';
    }
    if (_provider == 'Bank' && _bank.text.trim().isEmpty) return 'bank name';
    return null;
  }

  Future<void> _pickPhoto() async {
    try {
      final p = await pickPhotoSheet(context);
      if (p != null && mounted) setState(() => _photo = p);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    }
  }

  Future<void> _submit() async {
    final s = AppScope.read(context);
    final uid = s.authUser?.uid;
    if (uid == null) return;
    final acc = _accountProblem();
    final missing = <String>[
      if (_photo.isEmpty) 'profile photo',
      if (_name.text.trim().length < 2) 'full name',
      if (_vehicle.text.trim().isEmpty) 'vehicle',
      if (_plate.text.trim().isEmpty) 'plate number',
      if (_nin.text.trim().isEmpty) 'NIN',
      if (_licence.text.trim().isEmpty) 'driver’s licence number',
      if (acc != null) acc,
    ];
    if (missing.isNotEmpty) {
      showToast(context, 'Please add your ${missing.join(', ')}', icon: PhosphorIconsFill.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await Db.guard(Db.submitDriverApplication(
        uid: uid,
        exists: s.driver != null,
        fields: {
          'name': _name.text.trim(),
          'phone': s.profile?.phone ?? s.authUser?.phoneNumber ?? '',
          'photo': _photo,
          'vehicleType': _type,
          'vehicle': _vehicle.text.trim(),
          'plate': _plate.text.trim().toUpperCase(),
          'nin': _nin.text.trim().toUpperCase(),
          'licence': _licence.text.trim().toUpperCase(),
          'insurance': _insurance.text.trim(),
          'account': _account.toMap(),
        },
      ));
      if (s.profile != null && s.profile!.photo != _photo) {
        await Db.setPhoto(uid, _photo);
      }
      if (!mounted) return;
      setState(() => _editing = false);
      showToast(context, 'Application sent — we’ll review it shortly',
          icon: PhosphorIconsFill.sealCheck);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAccount(String uid) async {
    final problem = _accountProblem();
    if (problem != null) {
      showToast(context, 'Please add your $problem', icon: PhosphorIconsFill.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await Db.guard(Db.updateDriverAccount(uid, _account));
      if (!mounted) return;
      setState(() => _editingAccount = false);
      showToast(context, 'Payment account updated');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.driver;
    final showForm = d == null || _editing || d.status == 'rejected';

    return Scaffold(
      backgroundColor: TR.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(children: [
              const TRBack(light: true),
              const SizedBox(width: 12),
              const Pill('TrustRide Driver', icon: PhosphorIconsFill.steeringWheel),
              const Spacer(),
              const LogoMark(),
            ]),
            const SizedBox(height: 18),
            if (d != null && !showForm) ..._status(d) else ..._form(s, d),
          ],
        ),
      ),
    );
  }

  List<Widget> _status(DriverProfile d) {
    final approved = d.approved;
    return [
      Center(
        child: Stack(clipBehavior: Clip.none, children: [
          Avatar(d.initials, photo: d.photo, size: 96, ring: true),
          Positioned(
            right: -4,
            bottom: -4,
            child: IconBubble(
              approved ? PhosphorIconsFill.sealCheck : PhosphorIconsFill.hourglassMedium,
              size: 36,
              color: Colors.white,
              bg: approved ? TR.green : TR.gold,
            ),
          ),
        ]).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
      ),
      const SizedBox(height: 18),
      Text(
          approved
              ? 'You’re approved to drive'
              : d.status == 'suspended'
                  ? 'Your driver account is suspended'
                  : 'Application under review',
          textAlign: TextAlign.center,
          style: TS.h2),
      const SizedBox(height: 8),
      Text(
          approved
              ? 'Go online to see ride requests and send riders your price.'
              : d.status == 'suspended'
                  ? 'Please contact TrustRide support.'
                  : 'Bring your NIN card, licence and vehicle papers to the TrustRide office for verification. We’ll notify you here once approved.',
          textAlign: TextAlign.center,
          style: TS.body),
      const SizedBox(height: 20),
      TRCard(
        child: Column(children: [
          _info('Vehicle', '${d.vehicle} · ${d.plate}'),
          _info('Type', AppScope.read(context).config.ride(d.vehicleType).name),
          _info('NIN', d.nin),
          _info('Licence', d.licence),
        ]),
      ),
      const SizedBox(height: 14),
      TRCard(
        child: _editingAccount
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ..._accountFields(),
                Row(children: [
                  Expanded(
                    child: TRButton(
                        label: 'Cancel',
                        kind: BtnKind.outline,
                        height: 48,
                        onPressed: () => setState(() => _editingAccount = false)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TRButton(
                        label: 'Save',
                        height: 48,
                        loading: _saving,
                        onPressed: () => _saveAccount(d.uid)),
                  ),
                ]),
              ])
            : Row(children: [
                IconBubble(
                    d.account.provider == 'Bank' ? PhosphorIconsFill.bank : PhosphorIconsFill.deviceMobile,
                    color: TR.green,
                    bg: TR.greenTint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Riders pay you at', style: TS.small.copyWith(fontSize: 12)),
                      Text(d.account.isEmpty ? 'Not set' : '${d.account.title} · ${d.account.accountNumber}',
                          style: TS.label),
                      if (d.account.accountName.isNotEmpty)
                        Text(d.account.accountName, style: TS.small.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _editingAccount = true),
                  child: Text('Edit', style: TS.label.copyWith(color: TR.navy)),
                ),
              ]),
      ),
      const SizedBox(height: 20),
      if (approved)
        TRButton(
          label: 'Open driver app',
          icon: PhosphorIconsBold.arrowRight,
          onPressed: () => Navigator.of(context).pushReplacementNamed(R.driver),
        )
      else if (d.status == 'pending')
        TRButton(
          label: 'Edit application',
          kind: BtnKind.outline,
          onPressed: () => setState(() => _editing = true),
        ),
    ];
  }

  Widget _info(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 90, child: Text(a, style: TS.small)),
          Expanded(child: Text(b, style: TS.label.copyWith(fontSize: 14))),
        ]),
      );

  List<Widget> _accountFields() => [
        Text('How riders pay you by transfer', style: TS.label),
        const SizedBox(height: 4),
        Text('Riders who choose “Transfer” see these details at the end of the trip.',
            style: TS.small.copyWith(fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _providers)
            SelectTile(
              selected: _provider == p,
              onTap: () => setState(() => _provider = p),
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(p == 'Bank' ? PhosphorIconsFill.bank : PhosphorIconsFill.deviceMobile,
                    size: 18, color: _provider == p ? TR.green : TR.navy),
                const SizedBox(width: 6),
                Text(p, style: TS.label.copyWith(fontSize: 13)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        _field('Account name', _accName, PhosphorIconsRegular.user),
        if (_provider == 'Bank')
          _field('Bank name', _bank, PhosphorIconsRegular.bank, hint: 'e.g. Rokel Commercial Bank'),
        _field(_provider == 'Bank' ? 'Account number' : 'Mobile money number', _accNumber,
            _provider == 'Bank' ? PhosphorIconsRegular.hash : PhosphorIconsRegular.deviceMobile,
            phone: _provider != 'Bank', number: _provider == 'Bank',
            hint: _provider == 'Bank' ? '' : '76 000 000'),
      ];

  List<Widget> _form(AppState s, DriverProfile? d) {
    final types = s.config.enabledRides;
    return [
      Text(d == null ? 'Drive with TrustRide' : 'Update your application', style: TS.h2),
      const SizedBox(height: 6),
      Text('Set your own prices on every request. Our team checks your documents in person before approval.',
          style: TS.body),
      if (d?.status == 'rejected' && d!.rejectReason.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: TR.dangerTint, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(PhosphorIconsFill.warning, color: TR.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Needs changes: ${d.rejectReason}', style: TS.small.copyWith(color: TR.ink))),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      Center(
        child: Pressable(
          onTap: _pickPhoto,
          semanticLabel: 'Add profile photo',
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Avatar(initialsOf(_name.text), photo: _photo, size: 96, ring: true),
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
                  child: const Icon(PhosphorIconsFill.camera, color: Colors.white, size: 15),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(_photo.isEmpty ? 'Add a clear photo of your face (required)' : 'Change photo',
                style: TS.small.copyWith(color: _photo.isEmpty ? TR.navy : TR.muted)),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      const Caps('Vehicle type'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in types)
          SelectTile(
            selected: _type == r.id,
            onTap: () => setState(() => _type = r.id),
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(rideIcon(r.id), size: 20, color: _type == r.id ? TR.green : TR.navy),
              const SizedBox(width: 6),
              Text(r.name, style: TS.label.copyWith(fontSize: 13)),
            ]),
          ),
      ]),
      const SizedBox(height: 18),
      _field('Full name (as on your ID)', _name, PhosphorIconsRegular.user),
      _field('Vehicle make, model and colour', _vehicle, PhosphorIconsRegular.carProfile,
          hint: 'e.g. Toyota Corolla, silver'),
      _field('Plate number', _plate, PhosphorIconsRegular.identificationCard, caps: true),
      _field('National ID number (NIN)', _nin, PhosphorIconsRegular.identificationCard, caps: true),
      _field('Driver’s licence number', _licence, PhosphorIconsRegular.identificationCard, caps: true),
      _field('Insurance policy number (optional)', _insurance, PhosphorIconsRegular.fileText),
      const SizedBox(height: 4),
      TRCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _accountFields())),
      const SizedBox(height: 18),
      TRButton(label: 'Submit application', loading: _saving, onPressed: _submit),
    ];
  }

  Widget _field(String label, TextEditingController c, IconData icon,
      {String? hint, bool caps = false, bool phone = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TS.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            onChanged: c == _name ? (_) => setState(() {}) : null,
            keyboardType: phone
                ? TextInputType.phone
                : number
                    ? TextInputType.number
                    : TextInputType.text,
            textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.words,
            style: TS.label.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint == null || hint.isEmpty ? null : hint,
              prefixText: phone ? '+232 ' : null,
              prefixIcon: Icon(icon, color: TR.muted, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
