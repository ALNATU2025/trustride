import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'theme.dart';

class RideType {
  const RideType({
    required this.id,
    required this.name,
    required this.seats,
    required this.etaMin,
    required this.base,
    required this.perKm,
    required this.icon,
    required this.note,
  });

  final String id;
  final String name;
  final int seats;
  final int etaMin;
  final double base;
  final double perKm;
  final IconData icon;
  final String note;

  double fareFor(double km) => (base + perKm * km).roundToDouble();
}

class Place {
  const Place(this.name, this.area, this.km);
  final String name;
  final String area;
  final double km;
}

class PayMethod {
  const PayMethod(this.id, this.name, this.detail, this.color, this.icon);
  final String id;
  final String name;
  final String detail;
  final Color color;
  final IconData icon;
}

enum TripStatus { completed, cancelled }

class Trip {
  Trip({
    required this.id,
    required this.when,
    required this.from,
    required this.to,
    required this.fare,
    required this.rideName,
    required this.status,
    this.rating,
  });

  final String id;
  final String when;
  final String from;
  final String to;
  final double fare;
  final String rideName;
  final TripStatus status;
  final int? rating;
}

class Driver {
  const Driver({
    required this.initials,
    required this.name,
    required this.rating,
    required this.trips,
    required this.car,
    required this.plate,
  });
  final String initials;
  final String name;
  final double rating;
  final int trips;
  final String car;
  final String plate;
}

class Applicant {
  Applicant({
    required this.initials,
    required this.name,
    required this.kind,
    required this.city,
    required this.age,
    required this.phone,
    required this.vehicle,
    required this.plate,
    required this.wallet,
  });
  final String initials;
  final String name;
  final String kind;
  final String city;
  final String age;
  final String phone;
  final String vehicle;
  final String plate;
  final String wallet;
  String status = 'pending'; // pending | approved | rejected
}

class AdminTrip {
  const AdminTrip(this.id, this.date, this.rider, this.driver, this.route,
      this.type, this.pay, this.fare, this.status);
  final String id;
  final String date;
  final String rider;
  final String driver;
  final String route;
  final String type;
  final String pay;
  final double fare;
  final String status;
}

class Mock {
  static final rides = <RideType>[
    RideType(
        id: 'okada',
        name: 'Okada',
        seats: 1,
        etaMin: 3,
        base: 10,
        perKm: 3.5,
        icon: PhosphorIconsFill.motorcycle,
        note: 'Helmet provided'),
    RideType(
        id: 'keke',
        name: 'Keke',
        seats: 3,
        etaMin: 5,
        base: 14,
        perKm: 5,
        icon: PhosphorIconsFill.scooter,
        note: 'Open-air tricycle'),
    RideType(
        id: 'car',
        name: 'TrustRide Car',
        seats: 4,
        etaMin: 4,
        base: 20,
        perKm: 15.5,
        icon: PhosphorIconsFill.carProfile,
        note: 'Everyday rides'),
    RideType(
        id: 'ac',
        name: 'Comfort AC',
        seats: 4,
        etaMin: 7,
        base: 30,
        perKm: 21,
        icon: PhosphorIconsFill.snowflake,
        note: 'Air-conditioned, newer cars'),
    RideType(
        id: 'xl',
        name: 'TrustRide XL',
        seats: 6,
        etaMin: 10,
        base: 40,
        perKm: 26,
        icon: PhosphorIconsFill.van,
        note: 'Groups and luggage'),
  ];

  static const places = <Place>[
    Place('Lumley Beach Road', 'Lumley, Western Area Urban', 4.2),
    Place('Aberdeen Beach', 'Aberdeen, Freetown', 5.6),
    Place('Youyi Building', 'Brookfields, Freetown', 3.1),
    Place('Connaught Hospital', 'Wallace Johnson St, Central', 6.0),
    Place('Kissy Ferry Terminal', 'Kissy, ferry to Lungi Airport', 9.8),
    Place('Fourah Bay College', 'Mount Aureol, Freetown', 7.4),
    Place('Siaka Stevens Street', 'Central Freetown', 5.2),
    Place('Hill Station', 'Hill Station, Freetown', 3.8),
    Place('Wilberforce', 'Wilberforce, Freetown', 2.9),
    Place('Tower Hill', 'Tower Hill, Freetown', 4.6),
    Place('Waterloo', 'Western Area Rural', 24.0),
  ];

  static final payMethods = <PayMethod>[
    PayMethod('om', 'Orange Money', '·· 456', TR.orangeMoney,
        PhosphorIconsFill.deviceMobile),
    PayMethod('af', 'Afrimoney', '·· 902', TR.afrimoney,
        PhosphorIconsFill.deviceMobile),
    PayMethod('wallet', 'TrustRide Wallet', 'Balance', TR.navy,
        PhosphorIconsFill.wallet),
    PayMethod('cash', 'Cash to driver', 'Pay at drop-off', TR.green,
        PhosphorIconsFill.money),
  ];

  static const driver = Driver(
    initials: 'MS',
    name: 'Mohamed Sesay',
    rating: 4.9,
    trips: 1240,
    car: 'Silver Toyota Corolla',
    plate: 'AKJ 482',
  );

  static List<Trip> seedTrips() => [
        Trip(
            id: 'TR-20850',
            when: 'Yesterday, 8:02 AM',
            from: 'Congo Cross',
            to: 'Siaka Stevens Street',
            fare: 35,
            rideName: 'Keke',
            status: TripStatus.completed,
            rating: 5),
        Trip(
            id: 'TR-20811',
            when: 'Mon, 27 Oct',
            from: 'Aberdeen',
            to: 'Hill Station',
            fare: 0,
            rideName: 'TrustRide Car',
            status: TripStatus.cancelled),
        Trip(
            id: 'TR-20790',
            when: 'Sat, 25 Oct',
            from: 'Brookfields',
            to: 'Kissy Ferry Terminal',
            fare: 120,
            rideName: 'Comfort AC',
            status: TripStatus.completed,
            rating: 4),
        Trip(
            id: 'TR-20755',
            when: 'Thu, 23 Oct',
            from: 'Wilberforce',
            to: 'Tower Hill',
            fare: 25,
            rideName: 'Okada',
            status: TripStatus.completed,
            rating: 5),
      ];

  static List<Applicant> seedApplicants() => [
        Applicant(initials: 'AJ', name: 'Alhassan Jalloh', kind: 'Car', city: 'Freetown', age: '2h', phone: '+232 76 410 220', vehicle: 'Toyota Corolla 2012 · white', plate: 'AKN 117', wallet: 'Orange Money ·· 220'),
        Applicant(initials: 'MK', name: 'Mariama Koroma', kind: 'Car', city: 'Freetown', age: '5h', phone: '+232 77 902 314', vehicle: 'Honda Fit 2014 · blue', plate: 'AJX 905', wallet: 'Afrimoney ·· 314'),
        Applicant(initials: 'SB', name: 'Sahr Bockarie', kind: 'Keke', city: 'Waterloo', age: '9h', phone: '+232 79 118 640', vehicle: 'Bajaj RE tricycle · yellow', plate: 'TR 4471', wallet: 'Orange Money ·· 640'),
        Applicant(initials: 'IK', name: 'Ibrahim Kamara', kind: 'Okada', city: 'Wellington', age: '1d', phone: '+232 76 773 051', vehicle: 'Haojue 125 · red', plate: 'MC 2280', wallet: 'Orange Money ·· 051'),
        Applicant(initials: 'FT', name: 'Fatu Turay', kind: 'Car', city: 'Freetown', age: '1d', phone: '+232 30 225 778', vehicle: 'Toyota Vitz 2011 · silver', plate: 'AKB 639', wallet: 'Afrimoney ·· 778'),
        Applicant(initials: 'DC', name: 'David Cole', kind: 'Comfort AC', city: 'Freetown', age: '2d', phone: '+232 78 640 019', vehicle: 'Toyota RAV4 2015 · black', plate: 'AKP 402', wallet: 'Orange Money ·· 019'),
      ];

  static const adminTrips = <AdminTrip>[
    AdminTrip('TR-20931', '30 Oct, 15:52', 'Isatu B.', 'Abu Conteh', 'Kissy → Eastern Police', 'Keke', 'Cash', 30, 'SOS'),
    AdminTrip('TR-20928', '30 Oct, 15:50', 'Aminata K.', 'Mohamed Sesay', 'Congo Cross → Lumley Beach', 'Car', 'Orange Money', 85, 'En route'),
    AdminTrip('TR-20927', '30 Oct, 15:49', 'Joseph M.', 'Foday Kanu', 'Aberdeen → Hill Station', 'Comfort AC', 'Afrimoney', 140, 'Pickup'),
    AdminTrip('TR-20921', '30 Oct, 15:48', 'Samuel K.', 'Alhaji Jalloh', 'Brookfields → Kissy Ferry', 'Car', 'Orange Money', 110, 'Completed'),
    AdminTrip('TR-20917', '30 Oct, 15:30', 'Kadiatu S.', 'Foday Kanu', 'Lumley → Aberdeen', 'Comfort AC', 'Afrimoney', 135, 'Completed'),
    AdminTrip('TR-20902', '30 Oct, 14:02', 'Ishmael B.', 'Sahr Fomba', 'Kissy → Clock Tower', 'Keke', 'Cash', 30, 'Disputed'),
    AdminTrip('TR-20889', '30 Oct, 12:41', 'Hawa T.', 'Ibrahim Bangura', 'Wilberforce → Tower Hill', 'Okada', 'Wallet', 25, 'Completed'),
    AdminTrip('TR-20871', '30 Oct, 11:15', 'Mohamed J.', 'Abu Conteh', 'Calaba Town → Kissy', 'Keke', 'Orange Money', 0, 'Cancelled'),
    AdminTrip('TR-20844', '29 Oct, 20:12', 'Abdul R.', 'Mariama Koroma', 'Congo Cross → Murray Town', 'Car', 'Cash', 80, 'Completed'),
    AdminTrip('TR-20830', '29 Oct, 18:40', 'Grace M.', 'David Cole', 'Hill Station → Lumley', 'TrustRide XL', 'Afrimoney', 160, 'Completed'),
  ];
}
