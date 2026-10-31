import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/live_map.dart';

class ChooseRideScreen extends StatefulWidget {
  const ChooseRideScreen({super.key});
  @override
  State<ChooseRideScreen> createState() => _ChooseRideScreenState();
}

class _ChooseRideScreenState extends State<ChooseRideScreen> {
  bool _booking = false;
  bool _loadingRoute = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = AppScope.read(context);
    setState(() => _loadingRoute = true);
    if (s.pickup == null) await s.locate();
    await s.loadRoute();
    if (mounted) setState(() => _loadingRoute = false);
  }

  Future<void> _book() async {
    final s = AppScope.read(context);
    setState(() => _booking = true);
    try {
      await s.book();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(R.ride, ModalRoute.withName(R.rider));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _editPrice(AppState s) async {
    final ctrl = TextEditingController(text: s.fare.round().toString());
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Your price', style: TS.h3),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TS.h2,
            decoration: const InputDecoration(prefixText: 'Le '),
          ),
          const SizedBox(height: 8),
          Text('Recommended ${TR.le(s.suggested)} · minimum ${TR.le(s.minOffer)}',
              style: TS.small),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Cancel', style: TS.label.copyWith(color: TR.muted))),
          TextButton(
              onPressed: () => Navigator.pop(c, double.tryParse(ctrl.text)),
              child: Text('Set price', style: TS.label.copyWith(color: TR.green))),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null) return;
    if (v < s.minOffer) {
      if (mounted) {
        showToast(context, 'The lowest price for this trip is ${TR.le(s.minOffer)}',
            icon: PhosphorIconsFill.warning);
      }
      return;
    }
    s.setOffer(v);
  }

  Future<void> _details(AppState s) async {
    final note = TextEditingController(text: s.note);
    final name = TextEditingController(text: s.passengerName);
    final phone = TextEditingController(text: s.passengerPhone.replaceFirst('+232', ''));
    var other = s.passengerName.isNotEmpty;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: BottomPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                Text('Trip details', style: TS.h3),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  maxLength: 140,
                  decoration: const InputDecoration(
                    hintText: 'Note for the driver, e.g. blue gate opposite the mosque',
                    prefixIcon: Icon(PhosphorIconsRegular.chatText, size: 20),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: other,
                  activeTrackColor: TR.green,
                  onChanged: (v) => set(() => other = v),
                  title: Text('Booking for someone else', style: TS.label),
                  subtitle: Text('The driver will call them at pickup',
                      style: TS.small.copyWith(fontSize: 12)),
                ),
                if (other) ...[
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'Their name',
                        prefixIcon: Icon(PhosphorIconsRegular.user, size: 20)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        hintText: 'Their phone',
                        prefixText: '+232 ',
                        prefixIcon: Icon(PhosphorIconsRegular.phone, size: 20)),
                  ),
                ],
                const SizedBox(height: 16),
                TRButton(label: 'Save', onPressed: () => Navigator.pop(c, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      s.setTripDetails(
        note: note.text,
        passengerName: other ? name.text.trim() : '',
        passengerPhone:
            other && phone.text.trim().isNotEmpty ? AuthService.normalise(phone.text) : '',
      );
    }
    note.dispose();
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final h = MediaQuery.of(context).size.height;
    final route = s.route;
    final rides = s.config.enabledRides;
    final ready = !_loadingRoute && route != null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.40,
            child: LiveMap(
              pickup: s.pickup?.latLng,
              dropoff: s.dropoff?.latLng,
              route: route?.points ?? const [],
              fitAll: true,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                const TRBack(light: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: TR.shadow(),
                    ),
                    child: Row(children: [
                      const Icon(PhosphorIconsFill.flagCheckered, size: 18, color: TR.navy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.dropoff?.label ?? 'Destination',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.label.copyWith(fontSize: 14)),
                      ),
                      if (route != null)
                        Text('${route.distanceKm.toStringAsFixed(1)} km · ${route.durationMin.round()} min',
                            style: TS.small.copyWith(fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                const LogoMark(size: 46),
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: h * 0.35,
            child: BottomPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Text('Choose a ride', style: TS.h3)),
                    Text('Drivers send you their prices', style: TS.small.copyWith(fontSize: 12)),
                  ]),
                  const SizedBox(height: 10),
                  Expanded(
                    child: !ready
                        ? const Loading()
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: rides.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = rides[i];
                              final sel = r.id == s.rideId;
                              return SelectTile(
                                selected: sel,
                                onTap: () => s.setRide(r.id),
                                child: Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: 54,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: sel
                                          ? const LinearGradient(colors: [TR.greenBright, TR.green])
                                          : null,
                                      color: sel ? null : TR.field,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(rideIcon(r.id),
                                        color: sel ? Colors.white : TR.navy, size: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Flexible(
                                            child: Text(r.name,
                                                overflow: TextOverflow.ellipsis, style: TS.label),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(PhosphorIconsFill.user,
                                              size: 12, color: TR.subtle),
                                          Text(' ${r.seats}', style: TS.small.copyWith(fontSize: 12)),
                                        ]),
                                        Text(r.note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TS.small.copyWith(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('~${TR.le(s.fareFor(r))}',
                                        style: TS.label.copyWith(fontSize: 15)),
                                    Text('recommended', style: TS.small.copyWith(fontSize: 10.5)),
                                  ]),
                                ]),
                              )
                                  .animate()
                                  .fadeIn(delay: (50 * i).ms)
                                  .slideY(begin: 0.3, curve: Curves.easeOutCubic);
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (ready) _priceCard(s),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _payChip(s, 'cash', 'Cash', PhosphorIconsFill.money, TR.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _payChip(s, 'transfer', 'Transfer', PhosphorIconsFill.bank, TR.navy),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      onTap: () => _details(s),
                      semanticLabel: 'Trip details',
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: s.note.isNotEmpty || s.passengerName.isNotEmpty
                              ? TR.greenTint
                              : TR.field,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Icon(
                              s.passengerName.isNotEmpty
                                  ? PhosphorIconsFill.users
                                  : PhosphorIconsFill.notePencil,
                              color: TR.navy,
                              size: 20),
                          if (s.note.isNotEmpty || s.passengerName.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(PhosphorIconsFill.checkCircle, color: TR.green, size: 14),
                            ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TRButton(
                    label: !ready ? 'Calculating fare…' : 'Find drivers · ${TR.le(s.fare)}',
                    icon: ready ? PhosphorIconsBold.magnifyingGlass : null,
                    loading: _booking,
                    onPressed: !ready || s.dropoff == null ? null : _book,
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.25, duration: 450.ms, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }

  Widget _priceCard(AppState s) {
    final step = s.suggested >= 100 ? 10.0 : 5.0;
    final below = s.fare < s.suggested;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: TR.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(
          child: Pressable(
            onTap: () => _editPrice(s),
            semanticLabel: 'Edit your price',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Your price',
                      style: TS.small.copyWith(color: const Color(0xFFD6E2F0), fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(PhosphorIconsBold.pencilSimple, color: Color(0xFFD6E2F0), size: 12),
                ]),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text(TR.le(s.fare),
                      key: ValueKey(s.fare),
                      style: TS.h2.copyWith(color: Colors.white)),
                ),
                Text(
                    below
                        ? 'Below recommended — fewer drivers may accept'
                        : 'Recommended ${TR.le(s.suggested)}',
                    style: TS.small.copyWith(
                        color: below ? const Color(0xFFFFD58A) : const Color(0xFFD6E2F0),
                        fontSize: 11.5)),
              ],
            ),
          ),
        ),
        _stepBtn(PhosphorIconsBold.minus, 'Lower price', s.fare - step >= s.minOffer
            ? () => s.setOffer(s.fare - step)
            : null),
        const SizedBox(width: 8),
        _stepBtn(PhosphorIconsBold.plus, 'Raise price', () => s.setOffer(s.fare + step)),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, String label, VoidCallback? onTap) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: CircleIconButton(
          icon: icon,
          label: label,
          onTap: onTap ?? () {},
          background: Colors.white.fade(0.16),
          color: Colors.white,
          size: 44,
        ),
      );

  Widget _payChip(AppState s, String id, String label, IconData icon, Color c) {
    final sel = s.payment == id;
    return SelectTile(
      selected: sel,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      onTap: () => s.setPayment(id),
      child: Row(children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label.copyWith(fontSize: 13)),
        ),
      ]),
    );
  }
}
