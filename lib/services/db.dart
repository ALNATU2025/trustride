import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/models.dart';

/// All Firestore reads and writes. Collections:
///   users/{uid}        rider profile, wallet balance, role
///   drivers/{uid}      driver application, status, online + location
///   trips/{id}         every ride from request to completion
///   walletTx/{id}      wallet ledger (top-ups, wallet trip payments, tips)
///   payouts/{id}       driver cash-out requests
///   sos/{id}           emergency alerts
///   config/app         prices and business settings (admin-editable)
class Db {
  static final _fs = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users =>
      _fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get drivers =>
      _fs.collection('drivers');
  static CollectionReference<Map<String, dynamic>> get trips =>
      _fs.collection('trips');
  static CollectionReference<Map<String, dynamic>> get walletTx =>
      _fs.collection('walletTx');
  static CollectionReference<Map<String, dynamic>> get payouts =>
      _fs.collection('payouts');
  static CollectionReference<Map<String, dynamic>> get sos =>
      _fs.collection('sos');
  static DocumentReference<Map<String, dynamic>> get configDoc =>
      _fs.collection('config').doc('app');

  static FieldValue get now => FieldValue.serverTimestamp();

  // ---------------- config ----------------
  static Stream<AppConfig> configStream() => configDoc
      .snapshots()
      .map((d) => AppConfig.fromMap(d.data()))
      .handleError((_) {});

  static Future<void> saveConfig(AppConfig c) =>
      configDoc.set({...c.toMap(), 'updatedAt': now});

  // ---------------- users ----------------
  static Stream<AppUser?> userStream(String uid) => users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  static Future<void> createOrUpdateProfile({
    required String uid,
    required String phone,
    required String name,
    required String email,
    required String language,
    required bool exists,
    Contact? emergency,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'language': language,
      'updatedAt': now,
    };
    if (!exists) {
      data['role'] = 'rider';
      data['wallet'] = 0;
      data['createdAt'] = now;
      data['contacts'] =
          emergency == null ? <Map<String, dynamic>>[] : [emergency.toMap()];
      await users.doc(uid).set(data);
    } else {
      if (emergency != null) {
        data['contacts'] = FieldValue.arrayUnion([emergency.toMap()]);
      }
      await users.doc(uid).update(data);
    }
  }

  static Future<void> setLanguage(String uid, String lang) =>
      users.doc(uid).update({'language': lang});

  static Future<void> savePlace(String uid, String slot, Place p) =>
      users.doc(uid).update({'savedPlaces.$slot': p.toMap()});

  static Future<void> addContact(String uid, Contact c) =>
      users.doc(uid).update({'contacts': FieldValue.arrayUnion([c.toMap()])});

  static Future<void> removeContact(String uid, Contact c) =>
      users.doc(uid).update({'contacts': FieldValue.arrayRemove([c.toMap()])});

  static Future<void> setSetting(String uid, String key, bool value) =>
      users.doc(uid).update({'settings.$key': value});

  static Future<AppUser?> findUserByPhone(String phone) async {
    final q = await users.where('phone', isEqualTo: phone).limit(1).get();
    return q.docs.isEmpty ? null : AppUser.fromDoc(q.docs.first);
  }

  // ---------------- wallet ----------------
  static Stream<List<WalletTx>> walletStream(String uid) => walletTx
      .where('uid', isEqualTo: uid)
      .limit(100)
      .snapshots()
      .map((q) {
        final list = q.docs.map(WalletTx.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2100))
            .compareTo(a.createdAt ?? DateTime(2100)));
        return list;
      });

  /// Admin only: credit a rider's wallet (e.g. after cash or mobile money
  /// received at an agent).
  static Future<void> adminTopUp(
      {required String uid,
      required double amount,
      required String note,
      required String adminId}) {
    return _fs.runTransaction((tx) async {
      final ref = users.doc(uid);
      final snap = await tx.get(ref);
      final bal = toD(snap.data()?['wallet']);
      tx.update(ref, {'wallet': bal + amount});
      tx.set(walletTx.doc(), {
        'uid': uid,
        'amount': amount,
        'type': amount >= 0 ? 'topup' : 'adjust',
        'note': note,
        'by': adminId,
        'createdAt': now,
      });
    });
  }

  // ---------------- trips: rider ----------------
  static String _pin() => (1000 + Random.secure().nextInt(9000)).toString();

  static Future<String> requestTrip({
    required AppUser rider,
    required RideType ride,
    required Place pickup,
    required Place dropoff,
    required RouteInfo route,
    required double fare,
    required String payment,
  }) async {
    final ref = trips.doc();
    await ref.set({
      'riderId': rider.uid,
      'riderName': rider.name,
      'riderPhone': rider.phone,
      'driverId': '',
      'rideType': ride.id,
      'rideName': ride.name,
      'pickup': pickup.toMap(),
      'dropoff': dropoff.toMap(),
      'distanceKm': double.parse(route.distanceKm.toStringAsFixed(2)),
      'durationMin': route.durationMin.roundToDouble(),
      'fare': fare,
      'payment': payment,
      'status': TripStatus.requested,
      'pin': _pin(),
      'requirePin': rider.requirePin,
      'paid': false,
      'tip': 0,
      'sos': false,
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  static Stream<Trip?> tripStream(String id) => trips
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Trip.fromDoc(d) : null);

  static Stream<List<Trip>> riderTrips(String uid) => trips
          .where('riderId', isEqualTo: uid)
          .limit(100)
          .snapshots()
          .map((q) {
        final list = q.docs.map(Trip.fromDoc).toList();
        _sortTrips(list);
        return list;
      });

  static Future<Trip?> activeRiderTrip(String uid) async {
    final q = await trips.where('riderId', isEqualTo: uid).limit(30).get();
    final list = q.docs.map(Trip.fromDoc).where((t) => t.isActive).toList();
    _sortTrips(list);
    return list.isEmpty ? null : list.first;
  }

  static Future<void> cancelTrip(String id, String by) => trips.doc(id).update({
        'status': TripStatus.cancelled,
        'cancelledBy': by,
        'cancelledAt': now,
        'updatedAt': now,
      });

  /// Rider pays a finished trip from their wallet. Fails if balance is low.
  static Future<void> payWithWallet(Trip t, String uid) {
    return _fs.runTransaction((tx) async {
      final uRef = users.doc(uid);
      final tRef = trips.doc(t.id);
      final u = await tx.get(uRef);
      final trip = await tx.get(tRef);
      if (toB(trip.data()?['paid'])) return;
      final bal = toD(u.data()?['wallet']);
      if (bal < t.fare) throw Exception('Wallet balance is too low');
      tx.update(uRef, {'wallet': bal - t.fare});
      tx.update(tRef, {'paid': true, 'updatedAt': now});
      tx.set(walletTx.doc(), {
        'uid': uid,
        'amount': -t.fare,
        'type': 'trip',
        'note': 'Trip to ${t.dropoff.label}',
        'tripId': t.id,
        'createdAt': now,
      });
    });
  }

  static Future<void> markCashPaid(String tripId) =>
      trips.doc(tripId).update({'paid': true, 'updatedAt': now});

  static Future<void> rateTrip({
    required Trip trip,
    required int stars,
    required List<String> tags,
    required String comment,
    required double tip,
    required String uid,
  }) async {
    await trips.doc(trip.id).update({
      'rating': stars,
      'tags': tags,
      'comment': comment,
      'tip': tip,
      'updatedAt': now,
    });
    if (trip.driverId.isNotEmpty) {
      await drivers.doc(trip.driverId).update({
        'ratingSum': FieldValue.increment(stars),
        'ratingCount': FieldValue.increment(1),
      });
    }
    if (tip > 0 && trip.payment == 'wallet') {
      await _fs.runTransaction((tx) async {
        final uRef = users.doc(uid);
        final u = await tx.get(uRef);
        final bal = toD(u.data()?['wallet']);
        if (bal < tip) return;
        tx.update(uRef, {'wallet': bal - tip});
        tx.set(walletTx.doc(), {
          'uid': uid,
          'amount': -tip,
          'type': 'tip',
          'note': 'Tip for ${trip.driverName}',
          'tripId': trip.id,
          'createdAt': now,
        });
      });
    }
  }

  // ---------------- trips: driver ----------------
  static Stream<List<Trip>> openRequests() => trips
      .where('status', isEqualTo: TripStatus.requested)
      .limit(50)
      .snapshots()
      .map((q) => q.docs.map(Trip.fromDoc).toList());

  static Stream<List<Trip>> driverTrips(String uid) => trips
          .where('driverId', isEqualTo: uid)
          .limit(500)
          .snapshots()
          .map((q) {
        final list = q.docs.map(Trip.fromDoc).toList();
        _sortTrips(list);
        return list;
      });

  /// First driver to accept wins; others get an error.
  static Future<void> acceptTrip(String tripId, DriverProfile d) {
    return _fs.runTransaction((tx) async {
      final ref = trips.doc(tripId);
      final snap = await tx.get(ref);
      if (toS(snap.data()?['status']) != TripStatus.requested) {
        throw Exception('This ride was taken by another driver');
      }
      tx.update(ref, {
        'status': TripStatus.accepted,
        'driverId': d.uid,
        'driverName': d.name,
        'driverPhone': d.phone,
        'driverPlate': d.plate,
        'driverVehicle': d.vehicle,
        'driverRating': double.parse(d.rating.toStringAsFixed(2)),
        'acceptedAt': now,
        'updatedAt': now,
      });
    });
  }

  static Future<void> setTripStatus(String id, String status) {
    final stamp = switch (status) {
      TripStatus.arrived => 'arrivedAt',
      TripStatus.inProgress => 'startedAt',
      TripStatus.completed => 'completedAt',
      _ => 'updatedAt',
    };
    return trips.doc(id).update({'status': status, stamp: now, 'updatedAt': now});
  }

  /// Driver finishes the ride. For cash trips the driver confirms the cash
  /// was collected, which also marks the trip paid.
  static Future<void> completeTrip(String id, {required bool cashCollected}) =>
      trips.doc(id).update({
        'status': TripStatus.completed,
        'completedAt': now,
        'updatedAt': now,
        if (cashCollected) 'paid': true,
      });

  // ---------------- drivers ----------------
  static Stream<DriverProfile?> driverStream(String uid) => drivers
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? DriverProfile.fromDoc(d) : null);

  static Stream<List<DriverProfile>> onlineDrivers() => drivers
      .where('online', isEqualTo: true)
      .limit(200)
      .snapshots()
      .map((q) => q.docs
          .map(DriverProfile.fromDoc)
          .where((d) => d.approved && d.location != null)
          .toList());

  static Stream<List<DriverProfile>> driversByStatus(String status) => drivers
      .where('status', isEqualTo: status)
      .limit(200)
      .snapshots()
      .map((q) => q.docs.map(DriverProfile.fromDoc).toList());

  static Future<void> submitDriverApplication({
    required String uid,
    required bool exists,
    required Map<String, dynamic> fields,
  }) async {
    if (!exists) {
      await drivers.doc(uid).set({
        ...fields,
        'status': 'pending',
        'rejectReason': '',
        'online': false,
        'ratingSum': 0,
        'ratingCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      await drivers.doc(uid).update({
        ...fields,
        'status': 'pending',
        'rejectReason': '',
        'updatedAt': now,
      });
    }
  }

  static Future<void> setOnline(String uid, bool online, [LatLng? at]) =>
      drivers.doc(uid).update({
        'online': online,
        if (at != null) 'location': GeoPoint(at.latitude, at.longitude),
        'locationAt': now,
      });

  static Future<void> updateLocation(String uid, LatLng at) =>
      drivers.doc(uid).update({
        'location': GeoPoint(at.latitude, at.longitude),
        'locationAt': now,
      });

  static Future<void> reviewDriver(String uid, String status,
          {String reason = ''}) =>
      drivers.doc(uid).update({
        'status': status,
        'rejectReason': reason,
        if (status != 'approved') 'online': false,
        'reviewedAt': now,
      });

  // ---------------- payouts ----------------
  static Stream<List<Payout>> driverPayouts(String uid) => payouts
          .where('driverId', isEqualTo: uid)
          .limit(100)
          .snapshots()
          .map((q) {
        final list = q.docs.map(Payout.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2100))
            .compareTo(a.createdAt ?? DateTime(2100)));
        return list;
      });

  static Stream<List<Payout>> allPayouts() =>
      payouts.orderBy('createdAt', descending: true).limit(200).snapshots().map(
          (q) => q.docs.map(Payout.fromDoc).toList());

  static Future<void> requestPayout(DriverProfile d, double amount) =>
      payouts.add({
        'driverId': d.uid,
        'driverName': d.name,
        'amount': double.parse(amount.toStringAsFixed(2)),
        'provider': d.payoutProvider,
        'number': d.payoutNumber,
        'status': 'requested',
        'createdAt': now,
      });

  static Future<void> setPayoutStatus(String id, String status) =>
      payouts.doc(id).update({'status': status, 'processedAt': now});

  // ---------------- SOS ----------------
  static Future<void> raiseSos({
    required AppUser user,
    required String tripId,
    LatLng? at,
  }) async {
    await sos.add({
      'uid': user.uid,
      'name': user.name,
      'phone': user.phone,
      'tripId': tripId,
      if (at != null) 'location': GeoPoint(at.latitude, at.longitude),
      'resolved': false,
      'createdAt': now,
    });
    if (tripId.isNotEmpty) {
      await trips.doc(tripId).update({'sos': true, 'updatedAt': now});
    }
  }

  static Stream<List<SosAlert>> openSos() => sos
      .where('resolved', isEqualTo: false)
      .limit(50)
      .snapshots()
      .map((q) => q.docs.map(SosAlert.fromDoc).toList());

  static Future<void> resolveSos(String id) =>
      sos.doc(id).update({'resolved': true, 'resolvedAt': now});

  // ---------------- admin ----------------
  static Stream<List<Trip>> recentTrips({int limit = 300}) => trips
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(Trip.fromDoc).toList());

  static void _sortTrips(List<Trip> list) => list.sort((a, b) =>
      (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));
}
