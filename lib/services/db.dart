import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../core/models.dart';

/// All Firestore reads and writes. Collections:
///   users/{uid}                    rider profile, photo, role
///   drivers/{uid}                  driver application, payment account,
///                                  online + location, commission paid
///   trips/{id}                     every ride from request to completion
///   trips/{id}/offers/{driverId}   drivers' prices for an open request
///   trips/{id}/messages/{id}       rider ↔ driver chat
///   sos/{id}                       emergency alerts
///   config/app                     prices and business settings
class Db {
  static final _fs = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users =>
      _fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get drivers =>
      _fs.collection('drivers');
  static CollectionReference<Map<String, dynamic>> get trips =>
      _fs.collection('trips');
  static CollectionReference<Map<String, dynamic>> get sos =>
      _fs.collection('sos');
  static DocumentReference<Map<String, dynamic>> get configDoc =>
      _fs.collection('config').doc('app');
  static CollectionReference<Map<String, dynamic>> offers(String tripId) =>
      trips.doc(tripId).collection('offers');
  static CollectionReference<Map<String, dynamic>> messages(String tripId) =>
      trips.doc(tripId).collection('messages');

  static FieldValue get now => FieldValue.serverTimestamp();

  /// Fails with a clear message instead of waiting forever when the
  /// database can't be reached (offline, or Firestore not created yet).
  static Future<T> guard<T>(Future<T> f) => f.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception(
            'Can’t reach the TrustRide database. Check your internet '
            'connection, and that Firestore Database is created in Firebase.'),
      );

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
    String? photo,
    Contact? emergency,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'language': language,
      if (photo != null) 'photo': photo,
      'updatedAt': now,
    };
    if (!exists) {
      data['role'] = 'rider';
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

  /// Saves a profile photo on the user and, if they drive, on their driver
  /// record too (so riders see it).
  static Future<void> setPhoto(String uid, String photo,
      {bool isDriver = false}) async {
    await users.doc(uid).update({'photo': photo});
    if (isDriver) await drivers.doc(uid).update({'photo': photo});
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

  // ---------------- trips: rider ----------------
  static String _pin() => (1000 + Random.secure().nextInt(9000)).toString();

  static Future<String> requestTrip({
    required AppUser rider,
    required RideType ride,
    required Place pickup,
    required Place dropoff,
    required RouteInfo route,
    required double suggestedFare,
    required double offer,
    required String payment,
    required String note,
    required String passengerName,
    required String passengerPhone,
  }) async {
    final ref = trips.doc();
    await ref.set({
      'riderId': rider.uid,
      'riderName': rider.name,
      'riderPhone': rider.phone,
      'riderPhoto': rider.photo,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'note': note,
      'driverId': '',
      'rideType': ride.id,
      'rideName': ride.name,
      'pickup': pickup.toMap(),
      'dropoff': dropoff.toMap(),
      'distanceKm': double.parse(route.distanceKm.toStringAsFixed(2)),
      'durationMin': route.durationMin.roundToDouble(),
      'suggestedFare': suggestedFare,
      'fare': offer,
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

  /// Rider raises (or lowers) their offer while still searching.
  static Future<void> updateRiderOffer(String tripId, double fare) =>
      trips.doc(tripId).update({'fare': fare, 'updatedAt': now});

  static Stream<List<Offer>> offersStream(String tripId) =>
      offers(tripId).snapshots().map((q) {
        final list = q.docs.map(Offer.fromDoc).toList()
          ..sort((a, b) => a.price.compareTo(b.price));
        return list;
      });

  /// Rider picks a driver's offer: the trip takes that driver and price.
  static Future<void> acceptOffer(String tripId, Offer o) {
    return _fs.runTransaction((tx) async {
      final ref = trips.doc(tripId);
      final snap = await tx.get(ref);
      if (toS(snap.data()?['status']) != TripStatus.requested) {
        throw Exception('This request is no longer open');
      }
      final offerSnap = await tx.get(offers(tripId).doc(o.driverId));
      if (!offerSnap.exists) {
        throw Exception('That driver withdrew their offer');
      }
      final price = toD(offerSnap.data()?['price']);
      tx.update(ref, {
        'status': TripStatus.accepted,
        'driverId': o.driverId,
        'driverName': o.driverName,
        'driverPhone': o.driverPhone,
        'driverPhoto': o.driverPhoto,
        'driverPlate': o.plate,
        'driverVehicle': o.vehicle,
        'driverRating': double.parse(o.rating.toStringAsFixed(2)),
        'driverAccount': o.account.toMap(),
        'fare': price,
        'acceptedAt': now,
        'updatedAt': now,
      });
    });
  }

  static Future<void> cancelTrip(String id, String by) => trips.doc(id).update({
        'status': TripStatus.cancelled,
        'cancelledBy': by,
        'cancelledAt': now,
        'updatedAt': now,
      });

  /// Rider confirms they paid (cash handed over, or transfer sent).
  static Future<void> markPaid(String tripId) =>
      trips.doc(tripId).update({'paid': true, 'updatedAt': now});

  static Future<void> rateTrip({
    required Trip trip,
    required int stars,
    required List<String> tags,
    required String comment,
    required double tip,
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
  }

  // ---------------- chat ----------------
  static Stream<List<ChatMessage>> chatStream(String tripId) => messages(tripId)
      .orderBy('createdAt')
      .limitToLast(200)
      .snapshots()
      .map((q) => q.docs.map(ChatMessage.fromDoc).toList());

  static Future<void> sendMessage(String tripId, String from, String text) =>
      messages(tripId).add({'from': from, 'text': text, 'createdAt': now});

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

  /// Driver sends (or updates) their price for an open request.
  static Future<void> sendOffer({
    required String tripId,
    required DriverProfile d,
    required double price,
    required int etaMin,
  }) =>
      offers(tripId).doc(d.uid).set({
        'driverId': d.uid,
        'driverName': d.name,
        'driverPhone': d.phone,
        'driverPhoto': d.photo,
        'vehicle': d.vehicle,
        'plate': d.plate,
        'rating': double.parse(d.rating.toStringAsFixed(2)),
        'ratingCount': d.ratingCount,
        'account': d.account.toMap(),
        'price': price,
        'etaMin': etaMin,
        'createdAt': now,
      });

  static Future<void> withdrawOffer(String tripId, String driverId) =>
      offers(tripId).doc(driverId).delete();

  static Future<void> setTripStatus(String id, String status) {
    final stamp = switch (status) {
      TripStatus.arrived => 'arrivedAt',
      TripStatus.inProgress => 'startedAt',
      TripStatus.completed => 'completedAt',
      _ => 'updatedAt',
    };
    return trips.doc(id).update({'status': status, stamp: now, 'updatedAt': now});
  }

  /// Driver finishes the ride and confirms whether payment was received.
  static Future<void> completeTrip(String id, {required bool paymentReceived}) =>
      trips.doc(id).update({
        'status': TripStatus.completed,
        'completedAt': now,
        'updatedAt': now,
        if (paymentReceived) 'paid': true,
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
        'commissionPaid': 0,
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

  /// Approved drivers can update their payment account without re-review.
  static Future<void> updateDriverAccount(String uid, PayAccount a) =>
      drivers.doc(uid).update({'account': a.toMap(), 'updatedAt': now});

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

  /// Admin records commission the driver paid to TrustRide.
  static Future<void> recordCommissionPayment(String uid, double amount) =>
      drivers.doc(uid).update({
        'commissionPaid': FieldValue.increment(amount),
        'commissionPaidAt': now,
      });

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
