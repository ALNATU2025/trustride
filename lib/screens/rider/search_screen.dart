import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/icons.dart';

import '../../core/app_state.dart';
import '../../core/data.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _dest = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _dest.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(Place p) {
    AppScope.read(context).setDestination(p);
    Navigator.of(context).pushNamed(R.chooseRide);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = _dest.text.trim().toLowerCase();
    final results = Mock.places
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.area.toLowerCase().contains(q))
        .toList();

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
                Text('Plan your ride', style: TS.h3.copyWith(fontSize: 20)),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: RouteRail(height: 40),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(children: [
                      _box(
                        label: 'Pickup',
                        child: Text(s.pickup,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.label.copyWith(fontSize: 15)),
                      ),
                      const SizedBox(height: 8),
                      _box(
                        label: 'Drop-off',
                        focused: true,
                        child: TextField(
                          controller: _dest,
                          focusNode: _focus,
                          onChanged: (_) => setState(() {}),
                          style: TS.label.copyWith(fontSize: 15),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: false,
                            hintText: 'Search Freetown places',
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _chip(PhosphorIconsBold.plus, 'Add stop'),
                  _chip(PhosphorIconsBold.mapTrifold, 'Choose on map'),
                  _chip(PhosphorIconsBold.calendarBlank, 'Schedule'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Caps(q.isEmpty ? 'Suggestions' : 'Results'),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.mapPinArea,
                              size: 48, color: TR.subtle),
                          const SizedBox(height: 8),
                          Text('No places found', style: TS.label),
                          Text('Try a neighbourhood like Lumley or Kissy',
                              style: TS.small),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: TR.line),
                      itemBuilder: (context, i) {
                        final p = results[i];
                        return Pressable(
                          scale: 0.98,
                          onTap: () => _pick(p),
                          semanticLabel: p.name,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(children: [
                              const IconBubble(PhosphorIconsFill.mapPin,
                                  size: 42),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: TS.label),
                                    Text(p.area, style: TS.small),
                                  ],
                                ),
                              ),
                              Text('${p.km} km', style: TS.small),
                            ]),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: (30 * i).ms)
                            .slideX(begin: 0.06);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(
      {required String label, required Widget child, bool focused = false}) {
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
          child,
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Pressable(
          onTap: () => showToast(context, '$label is coming soon',
              icon: PhosphorIconsFill.sparkle),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: TR.border),
            ),
            child: Row(children: [
              Icon(icon, size: 16, color: TR.navy),
              const SizedBox(width: 6),
              Text(label, style: TS.label.copyWith(fontSize: 13)),
            ]),
          ),
        ),
      );
}
