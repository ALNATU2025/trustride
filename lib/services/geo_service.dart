import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/models.dart';

/// Place search, reverse geocoding and routing on OpenStreetMap services.
///
/// The public Nominatim and OSRM servers are fine for launch and testing but
/// have fair-use limits. At scale, point [nominatimHost] / [osrmHost] at a
/// paid provider or your own server — nothing else needs to change.
class GeoService {
  static const nominatimHost = 'nominatim.openstreetmap.org';
  static const osrmHost = 'router.project-osrm.org';

  static Map<String, String> get _headers => kIsWeb
      ? const {}
      : const {'User-Agent': 'TrustRide/1.0 (ride-hailing app, Sierra Leone)'};

  static final _distance = Distance();

  static double km(LatLng a, LatLng b) =>
      _distance.as(LengthUnit.Meter, a, b) / 1000;

  /// Search places inside Sierra Leone, biased towards [near].
  static Future<List<Place>> search(String query, {LatLng? near}) async {
    if (query.trim().length < 2) return [];
    final c = near ?? freetown;
    final uri = Uri.https(nominatimHost, '/search', {
      'q': query,
      'format': 'jsonv2',
      'countrycodes': 'sl',
      'limit': '10',
      'addressdetails': '1',
      'viewbox':
          '${c.longitude - 0.4},${c.latitude + 0.4},${c.longitude + 0.4},${c.latitude - 0.4}',
      'bounded': '0',
    });
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Search failed (${res.statusCode})');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data.map<Place>((e) {
      final m = asMap(e);
      final display = toS(m['display_name']);
      final name = toS(m['name']);
      return Place(
        label: name.isNotEmpty ? name : display.split(',').first,
        address: _shorten(display),
        lat: double.tryParse(toS(m['lat'])) ?? 0,
        lng: double.tryParse(toS(m['lon'])) ?? 0,
      );
    }).toList();
  }

  /// Turn coordinates into a readable place.
  static Future<Place> reverse(LatLng p) async {
    try {
      final uri = Uri.https(nominatimHost, '/reverse', {
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
        'format': 'jsonv2',
        'zoom': '17',
        'addressdetails': '1',
      });
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final m = asMap(jsonDecode(res.body));
        final a = asMap(m['address']);
        final road = toS(a['road']);
        final area = toS(a['suburb'],
            toS(a['neighbourhood'], toS(a['city_district'], toS(a['town']))));
        final name = toS(m['name']);
        final label = name.isNotEmpty
            ? name
            : road.isNotEmpty
                ? road
                : (area.isNotEmpty ? area : 'Pinned location');
        return Place(
          label: label,
          address: _shorten(toS(m['display_name'])),
          lat: p.latitude,
          lng: p.longitude,
        );
      }
    } catch (_) {}
    return Place(
      label: 'Pinned location',
      address:
          '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
      lat: p.latitude,
      lng: p.longitude,
    );
  }

  /// Driving route between two points. Falls back to a straight line
  /// estimate if the routing server is unreachable.
  static Future<RouteInfo> route(LatLng a, LatLng b) async {
    try {
      final uri = Uri.https(osrmHost,
          '/route/v1/driving/${a.longitude},${a.latitude};${b.longitude},${b.latitude}',
          {'overview': 'full', 'geometries': 'geojson'});
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final m = asMap(jsonDecode(res.body));
        final routes = m['routes'];
        if (routes is List && routes.isNotEmpty) {
          final r = asMap(routes.first);
          final coords = asMap(r['geometry'])['coordinates'];
          final pts = <LatLng>[];
          if (coords is List) {
            for (final c in coords) {
              if (c is List && c.length >= 2) {
                pts.add(LatLng(toD(c[1]), toD(c[0])));
              }
            }
          }
          return RouteInfo(
            pts.isEmpty ? [a, b] : pts,
            toD(r['distance']) / 1000,
            toD(r['duration']) / 60,
          );
        }
      }
    } catch (_) {}
    final straight = km(a, b);
    // City driving: ~1.3x straight-line distance at ~20 km/h.
    return RouteInfo([a, b], straight * 1.3, straight * 1.3 / 20 * 60);
  }

  static String _shorten(String display) {
    final parts = display.split(', ');
    final kept = parts.where((p) => p != 'Sierra Leone').take(3);
    return kept.join(', ');
  }
}
