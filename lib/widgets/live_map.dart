import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/icons.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Real OpenStreetMap map with TrustRide markers.
///
/// Tiles come from tile.openstreetmap.org, which is fine for launch but has
/// a fair-use policy. For heavy traffic switch [tileUrl] to a provider such
/// as MapTiler, Stadia or Thunderforest (they offer free tiers with a key).
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    this.center,
    this.me,
    this.pickup,
    this.dropoff,
    this.driver,
    this.nearby = const [],
    this.route = const [],
    this.zoom = 15,
    this.fitAll = false,
    this.bottomPadding = 0,
    this.onTap,
  });

  final LatLng? center;
  final LatLng? me;
  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final List<LatLng> nearby;
  final List<LatLng> route;
  final double zoom;

  /// Zoom out to show pickup, drop-off, driver and route together.
  final bool fitAll;

  /// Height of any panel covering the bottom of the map, so fitted content
  /// stays visible above it.
  final double bottomPadding;
  final void Function(LatLng)? onTap;

  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final _controller = MapController();
  bool _ready = false;

  List<LatLng> get _fitPoints => [
        ...widget.route,
        if (widget.pickup != null) widget.pickup!,
        if (widget.dropoff != null) widget.dropoff!,
        if (widget.driver != null) widget.driver!,
      ];

  LatLng get _center =>
      widget.center ?? widget.me ?? widget.pickup ?? freetown;

  void _reframe() {
    if (!_ready) return;
    final pts = _fitPoints;
    if (widget.fitAll && pts.length >= 2) {
      _controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: EdgeInsets.fromLTRB(48, 120, 48, 48 + widget.bottomPadding),
        maxZoom: 17,
      ));
    } else {
      _controller.move(_center, widget.zoom);
    }
  }

  @override
  void didUpdateWidget(covariant LiveMap old) {
    super.didUpdateWidget(old);
    final moved = old.center != widget.center ||
        old.pickup != widget.pickup ||
        old.dropoff != widget.dropoff ||
        old.route.length != widget.route.length ||
        old.fitAll != widget.fitAll ||
        (widget.center == null && old.me == null && widget.me != null);
    if (moved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reframe());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: widget.zoom,
        minZoom: 6,
        maxZoom: 19,
        onMapReady: () {
          _ready = true;
          _reframe();
        },
        onTap: widget.onTap == null ? null : (_, p) => widget.onTap!(p),
      ),
      children: [
        TileLayer(
          urlTemplate: LiveMap.tileUrl,
          userAgentPackageName: 'sl.trustride.app',
          maxZoom: 19,
        ),
        if (widget.route.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: widget.route,
              strokeWidth: 6,
              color: TR.navy,
              borderStrokeWidth: 3,
              borderColor: Colors.white,
            ),
          ]),
        MarkerLayer(markers: [
          for (final n in widget.nearby)
            Marker(
              point: n,
              width: 34,
              height: 34,
              child: const _VehicleDot(color: TR.navy, size: 30),
            ),
          if (widget.me != null)
            Marker(point: widget.me!, width: 60, height: 60, child: const _MeDot()),
          if (widget.pickup != null)
            Marker(
              point: widget.pickup!,
              width: 30,
              height: 30,
              child: const _PickupDot(),
            ),
          if (widget.dropoff != null)
            Marker(
              point: widget.dropoff!,
              width: 40,
              height: 48,
              alignment: Alignment.topCenter,
              child: const Icon(PhosphorIconsFill.mapPin,
                  color: TR.navy, size: 44),
            ),
          if (widget.driver != null)
            Marker(
              point: widget.driver!,
              width: 48,
              height: 48,
              child: const _VehicleDot(color: TR.green, size: 44, pulse: true),
            ),
        ]),
        const Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Text('© OpenStreetMap',
                style: TextStyle(fontSize: 9, color: Color(0xFF6B7A8E))),
          ),
        ),
      ],
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();
  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: TR.navy.fade(0.15)),
          )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(begin: 0.4, end: 1, duration: 1600.ms)
              .fadeOut(duration: 1600.ms),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TR.navy,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: TR.shadow(),
            ),
          ),
        ],
      );
}

class _PickupDot extends StatelessWidget {
  const _PickupDot();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TR.green,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: TR.shadow(),
        ),
      );
}

class _VehicleDot extends StatelessWidget {
  const _VehicleDot({required this.color, required this.size, this.pulse = false});
  final Color color;
  final double size;
  final bool pulse;
  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: TR.shadow(),
      ),
      child: Icon(PhosphorIconsFill.carProfile,
          color: Colors.white, size: size * 0.55),
    );
    if (!pulse) return dot;
    return dot
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.08, duration: 900.ms);
  }
}
