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

/// Driver application form and its review status.
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
  final _payout = TextEditingController();
  String _type = 'car';
  String _provider = 'Orange Money';
  bool _saving = false;
  bool _editing = false;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final s = AppScope.read(context);
    final d = s.driver;
    _name.text = d?.name ?? s.profile?.name ?? '';
    if (d != null) {
      _type = d.vehicleType;
      _vehicle.text = d.vehicle;
      _plate.text = d.plate;
      _nin.text = d.nin;
      _licence.text = d.licence;
      _insurance.text = d.insurance;
      _provider = d.payoutProvider;
      _payout.text = d.payoutNumber.replaceFirst('+232', '');
    } else {
      _payout.text = (s.profile?.phone ?? '').replaceFirst('+232', '');
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _vehicle, _plate, _nin, _licence, _insurance, _payout]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final s = AppScope.read(context);
    final uid = s.authUser?.uid;
    if (uid == null) return;
    final missing = <String>[
      if (_name.text.trim().length < 2) 'full name',
      if (_vehicle.text.trim().isEmpty) 'vehicle',
      if (_plate.text.trim().isEmpty) 'plate number',
      if (_nin.text.trim().isEmpty) 'NIN',
      if (_licence.text.trim().isEmpty) 'driver’s licence number',
      if (_payout.text.trim().isEmpty) 'payout number',
    ];
    if (missing.isNotEmpty) {
      showToast(context, 'Please add your ${missing.join(', ')}',
          icon: PhosphorIconsFill.warning);
      return;
    }
    setState(() => _saving = true);
    try {
      await Db.submitDriverApplication(
        uid: uid,
        exists: s.driver != null,
        fields: {
          'name': _name.text.trim(),
          'phone': s.profile?.phone ?? s.authUser?.phoneNumber ?? '',
          'vehicleType': _type,
          'vehicle': _vehicle.text.trim(),
          'plate': _plate.text.trim().toUpperCase(),
          'nin': _nin.text.trim().toUpperCase(),
          'licence': _licence.text.trim().toUpperCase(),
          'insurance': _insurance.text.trim(),
          'payoutProvider': _provider,
          'payoutNumber': AuthService.normalise(_payout.text),
        },
      );
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
        child: IconBubble(
          approved ? PhosphorIconsFill.sealCheck : PhosphorIconsFill.hourglassMedium,
          size: 96,
          color: approved ? TR.green : TR.amberInk,
          bg: approved ? TR.greenTint : TR.amberTint,
        ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
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
              ? 'Go online to start receiving ride requests near you.'
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
          _info('Payouts', '${d.payoutProvider} · ${d.payoutNumber}'),
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

  List<Widget> _form(AppState s, DriverProfile? d) {
    final types = s.config.enabledRides;
    return [
      Text(d == null ? 'Drive with TrustRide' : 'Update your application', style: TS.h2),
      const SizedBox(height: 6),
      Text('Fill in your details. Our team checks every document in person before approval.',
          style: TS.body),
      if (d?.status == 'rejected' && d!.rejectReason.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: TR.dangerTint, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(PhosphorIconsFill.warning, color: TR.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Needs changes: ${d.rejectReason}',
                    style: TS.small.copyWith(color: TR.ink))),
          ]),
        ),
      ],
      const SizedBox(height: 20),
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
      _field('Plate number', _plate, PhosphorIconsRegular.identificationCard,
          caps: true),
      _field('National ID number (NIN)', _nin, PhosphorIconsRegular.identificationCard,
          caps: true),
      _field('Driver’s licence number', _licence, PhosphorIconsRegular.identificationCard,
          caps: true),
      _field('Insurance policy number (optional)', _insurance, PhosphorIconsRegular.fileText),
      const SizedBox(height: 4),
      const Caps('Get paid with'),
      const SizedBox(height: 8),
      Row(children: [
        for (final p in ['Orange Money', 'Afrimoney'])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: p == 'Orange Money' ? 8 : 0),
              child: SelectTile(
                selected: _provider == p,
                onTap: () => setState(() => _provider = p),
                radius: 14,
                child: Center(child: Text(p, style: TS.label.copyWith(fontSize: 14))),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      _field('Mobile money number', _payout, PhosphorIconsRegular.deviceMobile,
          phone: true, hint: '76 000 000'),
      const SizedBox(height: 10),
      TRButton(label: 'Submit application', loading: _saving, onPressed: _submit),
    ];
  }

  Widget _field(String label, TextEditingController c, IconData icon,
      {String? hint, bool caps = false, bool phone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TS.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: phone ? TextInputType.phone : TextInputType.text,
            textCapitalization:
                caps ? TextCapitalization.characters : TextCapitalization.words,
            style: TS.label.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: TR.muted, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
