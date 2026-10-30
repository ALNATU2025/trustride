import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

/// Edit fares, commission and contact numbers (saved to config/app).
class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});
  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  AppConfig? _draft;
  final Map<String, TextEditingController> _c = {};
  bool _saving = false;

  TextEditingController _ctrl(String key, String value) =>
      _c.putIfAbsent(key, () => TextEditingController(text: value));

  String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(String key, double fallback) =>
      double.tryParse(_c[key]?.text.trim() ?? '') ?? fallback;

  Future<void> _save() async {
    final d = _draft;
    if (d == null) return;
    final rides = [
      for (final r in d.rideTypes)
        r.copyWith(
          base: _num('${r.id}.base', r.base),
          perKm: _num('${r.id}.perKm', r.perKm),
          perMin: _num('${r.id}.perMin', r.perMin),
          minFare: _num('${r.id}.minFare', r.minFare),
        ),
    ];
    if (!rides.any((r) => r.enabled)) {
      showToast(context, 'Keep at least one ride type enabled', icon: PhosphorIconsFill.warning);
      return;
    }
    final pct = _num('commission', d.commission * 100);
    final next = d.copyWith(
      rideTypes: rides,
      commission: (pct.clamp(0, 50) / 100).toDouble(),
      supportPhone: _c['support']?.text.trim() ?? d.supportPhone,
      policeNumber: _c['police']?.text.trim() ?? d.policeNumber,
      ambulanceNumber: _c['ambulance']?.text.trim() ?? d.ambulanceNumber,
    );
    setState(() => _saving = true);
    try {
      await Db.saveConfig(next);
      if (mounted) showToast(context, 'Settings saved — the apps update live');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    _draft ??= s.config;
    final d = _draft!;
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    Widget numField(String key, String label, double v, {String prefix = ''}) => SizedBox(
          width: 120,
          child: TextField(
            controller: _ctrl(key, _n(v)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: money,
            decoration: InputDecoration(labelText: label, prefixText: prefix, isDense: true),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminHeader(
          title: 'Prices & settings',
          subtitle: 'Changes reach every rider and driver app instantly',
          actions: [
            TRButton(
                label: 'Save changes',
                icon: PhosphorIconsBold.check,
                expand: false,
                height: 44,
                loading: _saving,
                onPressed: _save),
          ],
        ),
        const SizedBox(height: 20),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fares (Leones)', style: TS.h3),
              const SizedBox(height: 4),
              Text('Fare = base + per km × distance + per minute × time, never below the minimum.',
                  style: TS.small),
              const SizedBox(height: 14),
              for (var i = 0; i < d.rideTypes.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFEEF1F5)))),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: Row(children: [
                          Icon(rideIcon(d.rideTypes[i].id), color: TR.navy),
                          const SizedBox(width: 8),
                          Expanded(child: Text(d.rideTypes[i].name, style: TS.label)),
                          Switch(
                            value: d.rideTypes[i].enabled,
                            activeTrackColor: TR.green,
                            onChanged: (v) => setState(() {
                              final list = [...d.rideTypes];
                              list[i] = list[i].copyWith(enabled: v);
                              _draft = d.copyWith(rideTypes: list);
                            }),
                          ),
                        ]),
                      ),
                      numField('${d.rideTypes[i].id}.base', 'Base', d.rideTypes[i].base),
                      numField('${d.rideTypes[i].id}.perKm', 'Per km', d.rideTypes[i].perKm),
                      numField('${d.rideTypes[i].id}.perMin', 'Per min', d.rideTypes[i].perMin),
                      numField('${d.rideTypes[i].id}.minFare', 'Minimum', d.rideTypes[i].minFare),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business', style: TS.h3),
              const SizedBox(height: 14),
              Wrap(spacing: 14, runSpacing: 14, children: [
                numField('commission', 'Commission %', d.commission * 100),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _ctrl('support', d.supportPhone),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Support phone', hintText: '+232…', isDense: true),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _ctrl('police', d.policeNumber),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Police number', isDense: true),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _ctrl('ambulance', d.ambulanceNumber),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Ambulance number', isDense: true),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text('Confirm the emergency numbers with the authorities before launch.',
                  style: TS.small.copyWith(color: TR.amberInk)),
            ],
          ),
        ),
      ],
    );
  }
}
