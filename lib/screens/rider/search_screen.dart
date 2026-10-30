import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/app_state.dart';
import '../../core/icons.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/db.dart';
import '../../services/geo_service.dart';
import '../../widgets/common.dart';

/// Place search. [mode] is 'pickup', 'dropoff', 'home' or 'work'.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.mode = 'dropoff'});
  final String mode;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();
  Timer? _debounce;
  List<Place> _results = [];
  bool _searching = false;
  String? _error;
  late String _field; // which box is being typed in: pickup | dropoff
  Stream<List<Trip>>? _recent;

  bool get _saving => widget.mode == 'home' || widget.mode == 'work';

  @override
  void initState() {
    super.initState();
    _field = widget.mode == 'pickup' ? 'pickup' : 'dropoff';
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) _switchTo('pickup');
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus) _switchTo('dropoff');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.read(context);
      final uid = s.authUser?.uid;
      if (uid != null) setState(() => _recent = Db.riderTrips(uid));
      if (s.pickup == null) s.locate();
      (_field == 'pickup' ? _pickupFocus : _destFocus).requestFocus();
    });
  }

  void _switchTo(String f) {
    if (_field == f) return;
    setState(() {
      _field = f;
      _results = [];
      _error = null;
    });
  }

  void _onType(String q) {
    _debounce?.cancel();
    setState(() => _error = null);
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final s = AppScope.read(context);
      final r = await GeoService.search(q, near: s.myLocation);
      if (!mounted) return;
      setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Search is unavailable. Check your connection.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(Place p) async {
    final s = AppScope.read(context);
    if (_saving) {
      final uid = s.authUser?.uid;
      if (uid == null) return;
      try {
        await Db.savePlace(uid, widget.mode, p);
        if (!mounted) return;
        showToast(context, '${widget.mode == 'home' ? 'Home' : 'Work'} saved');
        Navigator.of(context).pop();
      } catch (e) {
        if (mounted) showToast(context, errorText(e), icon: PhosphorIconsFill.warning);
      }
      return;
    }
    if (_field == 'pickup') {
      s.setPickup(p);
      _pickupCtrl.clear();
      _destFocus.requestFocus();
      _switchTo('dropoff');
      return;
    }
    s.setDropoff(p);
    _destCtrl.clear();
    Navigator.of(context).pushNamed(R.chooseRide);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final typing =
        (_field == 'pickup' ? _pickupCtrl : _destCtrl).text.trim().length >= 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                const TRBack(),
                const SizedBox(width: 12),
                Text(
                    _saving
                        ? 'Set ${widget.mode == 'home' ? 'Home' : 'Work'} address'
                        : 'Plan your ride',
                    style: TS.h3.copyWith(fontSize: 20)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TR.field,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  if (!_saving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: RouteRail(height: 40),
                    ),
                  if (!_saving) const SizedBox(width: 8),
                  Expanded(
                    child: Column(children: [
                      if (!_saving) ...[
                        _box(
                          label: 'Pickup',
                          focused: _field == 'pickup',
                          controller: _pickupCtrl,
                          focus: _pickupFocus,
                          hint: s.pickup?.label ?? 'Finding your location…',
                        ),
                        const SizedBox(height: 8),
                      ],
                      _box(
                        label: _saving ? 'Address' : 'Drop-off',
                        focused: _field == 'dropoff',
                        controller: _destCtrl,
                        focus: _destFocus,
                        hint: s.dropoff?.label ?? 'Search Sierra Leone places',
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_searching) const LinearProgressIndicator(color: TR.green, minHeight: 2),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_error!, style: TS.small.copyWith(color: TR.danger)),
                    ),
                  if (!typing) ..._suggestions(s),
                  if (typing && !_searching && _results.isEmpty && _error == null)
                    const EmptyState(
                      icon: PhosphorIconsFill.mapPin,
                      title: 'No places found',
                      body: 'Try a street, landmark or neighbourhood name.',
                    ),
                  if (typing)
                    for (var i = 0; i < _results.length; i++)
                      _row(PhosphorIconsFill.mapPin, _results[i])
                          .animate()
                          .fadeIn(delay: (30 * i).ms)
                          .slideX(begin: 0.06),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _suggestions(AppState s) {
    final out = <Widget>[];
    if (_field == 'pickup' || _saving) {
      out.add(Pressable(
        onTap: () async {
          await s.locate(resetPickup: true);
          if (!mounted) return;
          final me = s.myLocation;
          if (me == null) {
            showToast(context, s.locationError ?? 'Location unavailable',
                icon: PhosphorIconsFill.warning);
            return;
          }
          if (_saving) {
            await _pick(await GeoService.reverse(me));
          } else {
            _destFocus.requestFocus();
            _switchTo('dropoff');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            const IconBubble(PhosphorIconsFill.navigationArrow,
                size: 42, color: TR.green, bg: TR.greenTint),
            const SizedBox(width: 14),
            Expanded(child: Text('Use my current location', style: TS.label)),
          ]),
        ),
      ));
    }
    final p = s.profile;
    if (!_saving && p != null) {
      if (p.home != null) out.add(_row(PhosphorIconsFill.house, p.home!, title: 'Home'));
      if (p.work != null) out.add(_row(PhosphorIconsFill.briefcase, p.work!, title: 'Work'));
    }
    if (_recent != null && !_saving) {
      out.add(StreamBuilder<List<Trip>>(
        stream: _recent,
        builder: (context, snap) {
          final seen = <String>{};
          final places = <Place>[];
          for (final t in snap.data ?? const <Trip>[]) {
            final key = '${t.dropoff.lat.toStringAsFixed(4)},${t.dropoff.lng.toStringAsFixed(4)}';
            if (seen.add(key)) places.add(t.dropoff);
            if (places.length >= 6) break;
          }
          if (places.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text('Type at least 2 letters to search places.',
                  textAlign: TextAlign.center, style: TS.small),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 14, bottom: 4),
                child: Caps('Recent'),
              ),
              for (final pl in places)
                _row(PhosphorIconsFill.clockCounterClockwise, pl),
            ],
          );
        },
      ));
    }
    return out;
  }

  Widget _row(IconData icon, Place p, {String? title}) => Pressable(
        scale: 0.98,
        onTap: () => _pick(p),
        semanticLabel: title ?? p.label,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: TR.line))),
          child: Row(children: [
            IconBubble(icon, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title ?? p.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.label),
                  Text(title != null ? p.label : p.address,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TS.small),
                ],
              ),
            ),
            if (AppScope.read(context).myLocation != null)
              Text(
                  '${GeoService.km(AppScope.read(context).myLocation!, p.latLng).toStringAsFixed(1)} km',
                  style: TS.small),
          ]),
        ),
      );

  Widget _box({
    required String label,
    required bool focused,
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: focused ? TR.navy : Colors.white, width: focused ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TS.small.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            focusNode: focus,
            onChanged: _onType,
            style: TS.label.copyWith(fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: hint,
              hintStyle: TS.label.copyWith(fontSize: 15, color: TR.subtle),
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
