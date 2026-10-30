import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

// ---------- small parsing helpers ----------
double toD(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;
int toI(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
String toS(dynamic v, [String fallback = '']) => v is String ? v : fallback;
bool toB(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;
DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;
Map<String, dynamic> toMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Freetown city centre — used when location is unavailable.
final freetown = LatLng(8.4844, -13.2344);

class Place {
  const Place({
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String label;
  final String address;
  final double lat;
  final double lng;

  LatLng get latLng => LatLng(lat, lng);

  Map<String, dynamic> toMap() =>
      {'label': label, 'address': address, 'lat': lat, 'lng': lng};

  static Place? fromMap(dynamic raw) {
    final m = toMap(raw);
    if (m['lat'] is! num || m['lng'] is! num) return null;
    return Place(
      label: toS(m['label'], 'Pinned location'),
      address: toS(m['address']),
      lat: toD(m['lat']),
      lng: toD(m['lng']),
    );
  }
}

class RideType {
  const RideType({
    required this.id,
    required this.name,
    required this.seats,
    required this.base,
    required this.perKm,
    required this.perMin,
    required this.minFare,
    required this.note,
    this.enabled = true,
  });

  final String id;
  final String name;
  final int seats;
  final double base;
  final double perKm;
  final double perMin;
  final double minFare;
  final String note;
  final bool enabled;

  double fareFor(double km, double minutes) {
    final raw = base + perKm * km + perMin * minutes;
    return (raw < minFare ? minFare : raw).roundToDouble();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'seats': seats,
        'base': base,
        'perKm': perKm,
        'perMin': perMin,
        'minFare': minFare,
        'note': note,
        'enabled': enabled,
      };

  factory RideType.fromMap(Map<String, dynamic> m) => RideType(
        id: toS(m['id']),
        name: toS(m['name']),
        seats: toI(m['seats'], 4),
        base: toD(m['base']),
        perKm: toD(m['perKm']),
        perMin: toD(m['perMin']),
        minFare: toD(m['minFare']),
        note: toS(m['note']),
        enabled: toB(m['enabled'], true),
      );

  RideType copyWith({
    double? base,
    double? perKm,
    double? perMin,
    double? minFare,
    bool? enabled,
  }) =>
      RideType(
        id: id,
        name: name,
        seats: seats,
        base: base ?? this.base,
        perKm: perKm ?? this.perKm,
        perMin: perMin ?? this.perMin,
        minFare: minFare ?? this.minFare,
        note: note,
        enabled: enabled ?? this.enabled,
      );
}

/// Business settings, stored in Firestore at config/app and editable from
/// the admin console. These defaults are used until an admin saves them.
class AppConfig {
  const AppConfig({
    required this.rideTypes,
    required this.commission,
    required this.supportPhone,
    required this.policeNumber,
    required this.ambulanceNumber,
  });

  final List<RideType> rideTypes;
  final double commission;
  final String supportPhone;
  final String policeNumber;
  final String ambulanceNumber;

  static const defaults = AppConfig(
    commission: 0.15,
    supportPhone: '',
    policeNumber: '999',
    ambulanceNumber: '117',
    rideTypes: [
      RideType(id: 'okada', name: 'Okada', seats: 1, base: 10, perKm: 3.5, perMin: 0.3, minFare: 15, note: 'Motorbike · helmet provided'),
      RideType(id: 'keke', name: 'Keke', seats: 3, base: 14, perKm: 5, perMin: 0.4, minFare: 20, note: 'Tricycle'),
      RideType(id: 'car', name: 'TrustRide Car', seats: 4, base: 20, perKm: 12, perMin: 0.8, minFare: 40, note: 'Everyday rides'),
      RideType(id: 'ac', name: 'Comfort AC', seats: 4, base: 30, perKm: 17, perMin: 1, minFare: 60, note: 'Air-conditioned'),
      RideType(id: 'xl', name: 'TrustRide XL', seats: 6, base: 40, perKm: 21, perMin: 1.2, minFare: 80, note: 'Groups and luggage'),
    ],
  );

  List<RideType> get enabledRides => rideTypes.where((r) => r.enabled).toList();

  RideType ride(String id) =>
      rideTypes.firstWhere((r) => r.id == id, orElse: () => rideTypes.first);

  Map<String, dynamic> toMap() => {
        'rideTypes': rideTypes.map((r) => r.toMap()).toList(),
        'commission': commission,
        'supportPhone': supportPhone,
        'policeNumber': policeNumber,
        'ambulanceNumber': ambulanceNumber,
      };

  factory AppConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    final rides = (m['rideTypes'] is List)
        ? (m['rideTypes'] as List)
            .map((e) => RideType.fromMap(toMap(e)))
            .where((r) => r.id.isNotEmpty)
            .toList()
        : defaults.rideTypes;
    return AppConfig(
      rideTypes: rides.isEmpty ? defaults.rideTypes : rides,
      commission: toD(m['commission'], defaults.commission),
      supportPhone: toS(m['supportPhone']),
      policeNumber: toS(m['policeNumber'], defaults.policeNumber),
      ambulanceNumber: toS(m['ambulanceNumber'], defaults.ambulanceNumber),
    );
  }

  AppConfig copyWith({
    List<RideType>? rideTypes,
    double? commission,
    String? supportPhone,
    String? policeNumber,
    String? ambulanceNumber,
  }) =>
      AppConfig(
        rideTypes: rideTypes ?? this.rideTypes,
        commission: commission ?? this.commission,
        supportPhone: supportPhone ?? this.supportPhone,
        policeNumber: policeNumber ?? this.policeNumber,
        ambulanceNumber: ambulanceNumber ?? this.ambulanceNumber,
      );
}

class Contact {
  const Contact(this.name, this.phone);
  final String name;
  final String phone;
  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
  static Contact fromMap(dynamic raw) {
    final m = toMap(raw);
    return Contact(toS(m['name']), toS(m['phone']));
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.language,
    required this.wallet,
    required this.contacts,
    required this.home,
    required this.work,
    required this.requirePin,
    required this.shareNight,
    required this.preferFemale,
  });

  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role; // rider | admin
  final String language;
  final double wallet;
  final List<Contact> contacts;
  final Place? home;
  final Place? work;
  final bool requirePin;
  final bool shareNight;
  final bool preferFemale;

  bool get isAdmin => role == 'admin';
  String get firstName => name.trim().split(' ').first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final s = parts.take(2).map((p) => p[0]).join();
    return s.isEmpty ? '?' : s.toUpperCase();
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final settings = toMap(m['settings']);
    final places = toMap(m['savedPlaces']);
    return AppUser(
      uid: d.id,
      name: toS(m['name']),
      phone: toS(m['phone']),
      email: toS(m['email']),
      role: toS(m['role'], 'rider'),
      language: toS(m['language'], 'English'),
      wallet: toD(m['wallet']),
      contacts: (m['contacts'] is List)
          ? (m['contacts'] as List).map(Contact.fromMap).toList()
          : const [],
      home: Place.fromMap(places['home']),
      work: Place.fromMap(places['work']),
      requirePin: toB(settings['requirePin'], true),
      shareNight: toB(settings['shareNight'], false),
      preferFemale: toB(settings['preferFemale'], false),
    );
  }
}

class DriverProfile {
  const DriverProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.vehicle,
    required this.plate,
    required this.nin,
    required this.licence,
    required this.insurance,
    required this.payoutProvider,
    required this.payoutNumber,
    required this.status,
    required this.rejectReason,
    required this.online,
    required this.location,
    required this.ratingSum,
    required this.ratingCount,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String phone;
  final String vehicleType;
  final String vehicle;
  final String plate;
  final String nin;
  final String licence;
  final String insurance;
  final String payoutProvider;
  final String payoutNumber;
  final String status; // pending | approved | rejected | suspended
  final String rejectReason;
  final bool online;
  final LatLng? location;
  final double ratingSum;
  final int ratingCount;
  final DateTime? createdAt;

  bool get approved => status == 'approved';
  double get rating => ratingCount == 0 ? 5.0 : ratingSum / ratingCount;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final s = parts.take(2).map((p) => p[0]).join();
    return s.isEmpty ? '?' : s.toUpperCase();
  }

  factory DriverProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final loc = m['location'];
    return DriverProfile(
      uid: d.id,
      name: toS(m['name']),
      phone: toS(m['phone']),
      vehicleType: toS(m['vehicleType'], 'car'),
      vehicle: toS(m['vehicle']),
      plate: toS(m['plate']),
      nin: toS(m['nin']),
      licence: toS(m['licence']),
      insurance: toS(m['insurance']),
      payoutProvider: toS(m['payoutProvider'], 'Orange Money'),
      payoutNumber: toS(m['payoutNumber']),
      status: toS(m['status'], 'pending'),
      rejectReason: toS(m['rejectReason']),
      online: toB(m['online']),
      location: loc is GeoPoint ? LatLng(loc.latitude, loc.longitude) : null,
      ratingSum: toD(m['ratingSum']),
      ratingCount: toI(m['ratingCount']),
      createdAt: toDate(m['createdAt']),
    );
  }
}

class TripStatus {
  static const requested = 'requested';
  static const accepted = 'accepted';
  static const arrived = 'arrived';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const active = [requested, accepted, arrived, inProgress];
}

class Trip {
  const Trip({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.driverPlate,
    required this.driverVehicle,
    required this.driverRating,
    required this.rideType,
    required this.rideName,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.payment,
    required this.status,
    required this.pin,
    required this.requirePin,
    required this.createdAt,
    required this.completedAt,
    required this.rating,
    required this.tip,
    required this.paid,
    required this.sos,
    required this.cancelledBy,
  });

  final String id;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String driverPlate;
  final String driverVehicle;
  final double driverRating;
  final String rideType;
  final String rideName;
  final Place pickup;
  final Place dropoff;
  final double distanceKm;
  final double durationMin;
  final double fare;
  final String payment; // cash | wallet
  final String status;
  final String pin;
  final bool requirePin;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final int? rating;
  final double tip;
  final bool paid;
  final bool sos;
  final String cancelledBy;

  bool get isActive => TripStatus.active.contains(status);
  bool get hasDriver => driverId.isNotEmpty;
  String get driverInitials {
    final parts =
        driverName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final s = parts.take(2).map((p) => p[0]).join();
    return s.isEmpty ? '?' : s.toUpperCase();
  }

  factory Trip.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    const nowhere =
        Place(label: 'Unknown', address: '', lat: 8.4844, lng: -13.2344);
    return Trip(
      id: d.id,
      riderId: toS(m['riderId']),
      riderName: toS(m['riderName']),
      riderPhone: toS(m['riderPhone']),
      driverId: toS(m['driverId']),
      driverName: toS(m['driverName']),
      driverPhone: toS(m['driverPhone']),
      driverPlate: toS(m['driverPlate']),
      driverVehicle: toS(m['driverVehicle']),
      driverRating: toD(m['driverRating'], 5),
      rideType: toS(m['rideType'], 'car'),
      rideName: toS(m['rideName'], 'TrustRide'),
      pickup: Place.fromMap(m['pickup']) ?? nowhere,
      dropoff: Place.fromMap(m['dropoff']) ?? nowhere,
      distanceKm: toD(m['distanceKm']),
      durationMin: toD(m['durationMin']),
      fare: toD(m['fare']),
      payment: toS(m['payment'], 'cash'),
      status: toS(m['status'], TripStatus.requested),
      pin: toS(m['pin']),
      requirePin: toB(m['requirePin'], true),
      createdAt: toDate(m['createdAt']),
      completedAt: toDate(m['completedAt']),
      rating: m['rating'] is num ? (m['rating'] as num).toInt() : null,
      tip: toD(m['tip']),
      paid: toB(m['paid']),
      sos: toB(m['sos']),
      cancelledBy: toS(m['cancelledBy']),
    );
  }
}

class WalletTx {
  const WalletTx(this.id, this.amount, this.type, this.note, this.createdAt);
  final String id;
  final double amount;
  final String type; // topup | trip | tip | adjust
  final String note;
  final DateTime? createdAt;

  factory WalletTx.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return WalletTx(d.id, toD(m['amount']), toS(m['type']), toS(m['note']),
        toDate(m['createdAt']));
  }
}

class Payout {
  const Payout({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.amount,
    required this.provider,
    required this.number,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String driverId;
  final String driverName;
  final double amount;
  final String provider;
  final String number;
  final String status; // requested | paid | rejected
  final DateTime? createdAt;

  factory Payout.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Payout(
      id: d.id,
      driverId: toS(m['driverId']),
      driverName: toS(m['driverName']),
      amount: toD(m['amount']),
      provider: toS(m['provider']),
      number: toS(m['number']),
      status: toS(m['status'], 'requested'),
      createdAt: toDate(m['createdAt']),
    );
  }
}

class SosAlert {
  const SosAlert({
    required this.id,
    required this.tripId,
    required this.uid,
    required this.name,
    required this.phone,
    required this.location,
    required this.createdAt,
    required this.resolved,
  });
  final String id;
  final String tripId;
  final String uid;
  final String name;
  final String phone;
  final LatLng? location;
  final DateTime? createdAt;
  final bool resolved;

  factory SosAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final loc = m['location'];
    return SosAlert(
      id: d.id,
      tripId: toS(m['tripId']),
      uid: toS(m['uid']),
      name: toS(m['name']),
      phone: toS(m['phone']),
      location: loc is GeoPoint ? LatLng(loc.latitude, loc.longitude) : null,
      createdAt: toDate(m['createdAt']),
      resolved: toB(m['resolved']),
    );
  }
}

/// Result of a route lookup.
class RouteInfo {
  const RouteInfo(this.points, this.distanceKm, this.durationMin);
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;
}
