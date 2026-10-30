import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/db.dart';
import 'app_state.dart';
import 'routes.dart';

/// Sends the user to the right place after launch or sign-in:
/// onboarding → profile setup → admin console (web admins) → live trip →
/// rider home.
Future<void> goHome(BuildContext context) async {
  final s = AppScope.read(context);
  final nav = Navigator.of(context);
  if (s.authUser == null) {
    nav.pushNamedAndRemoveUntil(R.onboarding, (_) => false);
    return;
  }
  await s.waitForProfile();
  final p = s.profile;
  if (p == null) {
    nav.pushNamedAndRemoveUntil(R.profileSetup, (_) => false);
    return;
  }
  if (kIsWeb && p.isAdmin) {
    nav.pushNamedAndRemoveUntil(R.admin, (_) => false);
    return;
  }
  try {
    final active = await Db.activeRiderTrip(p.uid);
    if (active != null) {
      s.setCurrentTrip(active.id);
      nav.pushNamedAndRemoveUntil(R.rider, (_) => false);
      nav.pushNamed(R.ride);
      return;
    }
  } catch (_) {}
  nav.pushNamedAndRemoveUntil(R.rider, (_) => false);
}
