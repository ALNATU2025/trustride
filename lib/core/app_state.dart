import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';
import '../services/db.dart';
import '../services/geo_service.dart';
import '../services/location_service.dart';
import 'models.dart';

/// Live app state: who is signed in, their profile and driver record, the
/// admin-managed config, and the ride being booked.
class AppState extends ChangeNotifier {
  AppConfig config = AppConfig.defaults;
  User? authUser;
  AppUser? profile;
  DriverProfile? driver;
  bool profileLoaded = false;

  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<DriverProfile?>? _driverSub;
  StreamSubscription<AppConfig>? _configSub;

  void start() {
    _configSub = Db.configStream().listen((c) {
      config = c;
      if (!config.enabledRides.any((r) => r.id == rideId) &&
          config.enabledRides.isNotEmpty) {
        rideId = config.enabledRides.first.id;
      }
      notifyListeners();
    });
    _authSub = AuthService.changes().listen(_onAuth, onError: (_) {
      _completeReady();
    });
  }

  void _completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void _onAuth(User? u) {
    final changed = u?.uid != authUser?.uid;
    authUser = u;
    if (!changed && u != null) return;
    _userSub?.cancel();
    _driverSub?.cancel();
    profile = null;
    driver = null;
    profileLoaded = false;
    currentTripId = null;
    if (u == null) {
      _completeReady();
      notifyListeners();
      return;
    }
    _userSub = Db.userStream(u.uid).listen((p) {
      profile = p;
      profileLoaded = true;
      _completeReady();
      notifyListeners();
    }, onError: (_) {
      profileLoaded = true;
      _completeReady();
      notifyListeners();
    });
    _driverSub = Db.driverStream(u.uid).listen((d) {
      driver = d;
      notifyListeners();
    }, onError: (_) {});
  }

  /// Waits until the signed-in user's profile has been read (or 15 s).
  Future<void> waitForProfile() async {
    if (authUser != null && profileLoaded) return;
    final c = Completer<void>();
    void check() {
      if (authUser != null && profileLoaded && !c.isCompleted) c.complete();
    }

    addListener(check);
    try {
      await c.future.timeout(const Duration(seconds: 15));
    } catch (_) {
    } finally {
      removeListener(check);
    }
  }

  Future<void> signOut() async {
    final d = driver;
    if (d != null && d.online) {
      try {
        await Db.setOnline(d.uid, false);
      } catch (_) {}
    }
    await AuthService.signOut();
  }

  // ---------------- booking ----------------
  LatLng? myLocation;
  String? locationError;
  Place? pickup;
  Place? dropoff;
  RouteInfo? route;
  String rideId = 'car';
  String payment = 'cash';
  String? currentTripId;

  RideType get ride => config.ride(rideId);
  double fareFor(RideType r) =>
      route == null ? 0 : r.fareFor(route!.distanceKm, route!.durationMin);
  double get fare => fareFor(ride);

  Future<void> locate({bool resetPickup = false}) async {
    locationError = await LocationService.ensurePermission();
    final p = await LocationService.current();
    if (p != null) myLocation = p;
    notifyListeners();
    if (p != null && (pickup == null || resetPickup)) {
      final place = await GeoService.reverse(p);
      pickup = Place(
          label: 'Current location · ${place.label}',
          address: place.address,
          lat: place.lat,
          lng: place.lng);
      notifyListeners();
    }
  }

  void setPickup(Place p) {
    pickup = p;
    route = null;
    notifyListeners();
  }

  void setDropoff(Place p) {
    dropoff = p;
    route = null;
    notifyListeners();
  }

  void setRide(String id) {
    rideId = id;
    notifyListeners();
  }

  void setPayment(String p) {
    payment = p;
    notifyListeners();
  }

  Future<void> loadRoute() async {
    final a = pickup, b = dropoff;
    if (a == null || b == null) return;
    route = await GeoService.route(a.latLng, b.latLng);
    notifyListeners();
  }

  Future<String> book() async {
    final p = profile, a = pickup, b = dropoff, r = route;
    if (p == null || a == null || b == null || r == null) {
      throw 'Choose a pickup and destination first.';
    }
    if (payment == 'wallet' && p.wallet < fare) {
      throw 'Your wallet balance is too low for this ride.';
    }
    final id = await Db.requestTrip(
      rider: p,
      ride: ride,
      pickup: a,
      dropoff: b,
      route: r,
      fare: fare,
      payment: payment,
    );
    currentTripId = id;
    notifyListeners();
    return id;
  }

  void setCurrentTrip(String? id) {
    currentTripId = id;
    notifyListeners();
  }

  void finishBooking() {
    currentTripId = null;
    dropoff = null;
    route = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _driverSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }
}

/// Makes [AppState] available to the whole widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
