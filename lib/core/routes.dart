import 'package:flutter/material.dart';

import '../screens/admin/admin_shell.dart';
import '../screens/chat_screen.dart';
import '../screens/driver/driver_shell.dart';
import '../screens/driver/driver_signup_screen.dart';
import '../screens/rider/app_lock_screen.dart';
import '../screens/rider/choose_ride_screen.dart';
import '../screens/rider/onboarding_screen.dart';
import '../screens/rider/otp_screen.dart';
import '../screens/rider/profile_setup_screen.dart';
import '../screens/rider/rate_screen.dart';
import '../screens/rider/ride_screen.dart';
import '../screens/rider/rider_shell.dart';
import '../screens/rider/safety_screen.dart';
import '../screens/rider/search_screen.dart';
import '../screens/rider/sign_in_screen.dart';
import '../screens/rider/splash_screen.dart';

class R {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const otp = '/otp';
  static const profileSetup = '/profile-setup';
  static const rider = '/rider';
  static const search = '/search'; // argument: 'pickup' | 'dropoff' | 'home' | 'work'
  static const chooseRide = '/choose-ride';
  static const ride = '/ride'; // live trip: finding → arriving → on trip → pay
  static const rate = '/rate'; // argument: Trip
  static const safety = '/safety';
  static const driverSignup = '/driver-signup';
  static const driver = '/driver';
  static const admin = '/admin';
  static const chat = '/chat'; // argument: ChatArgs
  static const appLock = '/app-lock';

  static Route<dynamic> generate(RouteSettings settings) {
    final args = settings.arguments;
    final Widget page = switch (settings.name) {
      splash => const SplashScreen(),
      onboarding => const OnboardingScreen(),
      signIn => const SignInScreen(),
      otp => OtpScreen(phone: args is String ? args : ''),
      profileSetup => const ProfileSetupScreen(),
      rider => RiderShell(initialTab: args is int ? args : 0),
      search => SearchScreen(mode: args is String ? args : 'dropoff'),
      chooseRide => const ChooseRideScreen(),
      ride => const RideScreen(),
      rate => RateScreen(tripId: args is String ? args : ''),
      safety => const SafetyScreen(),
      driverSignup => const DriverSignupScreen(),
      driver => const DriverShell(),
      admin => const AdminShell(),
      chat when args is ChatArgs => ChatScreen(args: args),
      appLock => const AppLockScreen(),
      _ => const SplashScreen(),
    };
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, secondary, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        final out = CurvedAnimation(parent: secondary, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
                .animate(curved),
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 0.96).animate(out),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
