import 'package:flutter/material.dart';

import 'data.dart';

/// Single source of truth for the demo app. Swap the methods for real API
/// calls (auth, pricing, dispatch, payments) when wiring up a backend.
class AppState extends ChangeNotifier {
  // ---------- Rider ----------
  String riderName = 'Aminata Kamara';
  String phone = '76 123 456';
  String language = 'English';
  String pickup = 'Current location · Congo Cross';
  Place destination = Mock.places.first;
  String rideId = 'car';
  String paymentId = 'om';
  double wallet = 240;
  int tip = 10;
  final List<Trip> trips = Mock.seedTrips();
  final List<String> trustedContacts = ['Fatmata Kamara · +232 77 555 210'];
  bool requirePin = true;
  bool shareNightTrips = true;
  bool preferFemaleDrivers = false;

  String get firstName => riderName.split(' ').first;
  RideType get ride => Mock.rides.firstWhere((r) => r.id == rideId);
  PayMethod get payment =>
      Mock.payMethods.firstWhere((p) => p.id == paymentId);
  double get fare => ride.fareFor(destination.km);
  int get tripMinutes => (destination.km * 4.3).round().clamp(4, 90).toInt();

  void setProfile(String name, String lang) {
    if (name.trim().isNotEmpty) riderName = name.trim();
    language = lang;
    notifyListeners();
  }

  void setPhone(String value) {
    phone = value;
    notifyListeners();
  }

  void setDestination(Place p) {
    destination = p;
    notifyListeners();
  }

  void setRide(String id) {
    rideId = id;
    notifyListeners();
  }

  void setPayment(String id) {
    paymentId = id;
    notifyListeners();
  }

  void setTip(int value) {
    tip = value;
    notifyListeners();
  }

  void topUp(double amount) {
    wallet += amount;
    notifyListeners();
  }

  /// Returns false when the wallet cannot cover the fare.
  bool pay() {
    if (paymentId == 'wallet') {
      if (wallet < fare) return false;
      wallet -= fare;
    }
    notifyListeners();
    return true;
  }

  void finishTrip(int rating) {
    trips.insert(
      0,
      Trip(
        id: 'TR-${20940 + trips.length}',
        when: 'Today, ${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
        from: 'Congo Cross',
        to: destination.name,
        fare: fare + tip,
        rideName: ride.name,
        status: TripStatus.completed,
        rating: rating,
      ),
    );
    if (paymentId == 'wallet' && tip > 0 && wallet >= tip) wallet -= tip;
    notifyListeners();
  }

  void cancelTrip() {
    trips.insert(
      0,
      Trip(
        id: 'TR-${20940 + trips.length}',
        when: 'Today',
        from: 'Congo Cross',
        to: destination.name,
        fare: 0,
        rideName: ride.name,
        status: TripStatus.cancelled,
      ),
    );
    notifyListeners();
  }

  void addContact(String c) {
    trustedContacts.add(c);
    notifyListeners();
  }

  void toggleSetting(String key) {
    switch (key) {
      case 'pin':
        requirePin = !requirePin;
      case 'night':
        shareNightTrips = !shareNightTrips;
      case 'female':
        preferFemaleDrivers = !preferFemaleDrivers;
    }
    notifyListeners();
  }

  // ---------- Driver ----------
  bool driverOnline = false;
  double driverToday = 640;
  int driverTripsToday = 9;
  double driverAvailable = 1215.5;
  final List<double> driverWeek = [480, 260, 410, 455, 330, 360, 640];
  final Map<String, String> driverDocs = {
    'National ID card (NIN)': 'approved',
    'Driver’s licence (SLRSA)': 'approved',
    'Profile photo': 'approved',
    'Vehicle licence / registration': 'review',
    'Insurance certificate': 'upload',
    'Police clearance': 'upload',
  };
  String driverVehicle = 'Car';

  int get docsDone =>
      driverDocs.values.where((s) => s != 'upload').length;

  void uploadDoc(String name) {
    driverDocs[name] = 'review';
    notifyListeners();
  }

  void setDriverVehicle(String v) {
    driverVehicle = v;
    notifyListeners();
  }

  void toggleOnline() {
    driverOnline = !driverOnline;
    notifyListeners();
  }

  void acceptRide(double fare) {
    final net = fare * 0.85;
    driverToday += net;
    driverAvailable += net;
    driverTripsToday += 1;
    driverWeek[driverWeek.length - 1] = driverToday;
    notifyListeners();
  }

  void cashOut() {
    driverAvailable = 0;
    notifyListeners();
  }

  // ---------- Admin ----------
  final List<Applicant> applicants = Mock.seedApplicants();
  int sosAlerts = 1;

  int get pendingCount =>
      applicants.where((a) => a.status == 'pending').length;

  void review(Applicant a, String status) {
    a.status = status;
    notifyListeners();
  }

  void resolveSos() {
    sosAlerts = 0;
    notifyListeners();
  }
}

/// Makes [AppState] available to the whole widget tree without extra packages.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
