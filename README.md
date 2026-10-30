# TrustRide — Flutter app

*Your journey, our trust.* Ride-hailing for Sierra Leone: rider app, driver app and admin console in one Flutter project, built from the TrustRide screen designs.

## Run it

You need Flutter 3.22 or newer (`flutter --version`).

```bash
cd trustride
flutter create . --project-name trustride --org sl.trustride   # adds android/, ios/, web/ folders — keeps the lib/ code
flutter pub get
flutter run            # phone or emulator
flutter run -d chrome  # quickest way to see the admin console on a wide screen
flutter test
```

Android release builds: `google_fonts` downloads the Plus Jakarta Sans font at runtime, so make sure `android/app/src/main/AndroidManifest.xml` has
`<uses-permission android:name="android.permission.INTERNET"/>` (debug builds already do).

## What works

**Rider** — splash → 3-page onboarding → phone sign-in (+232) → 6-digit SMS code (any 6 digits in the demo) → profile setup (English/Krio, emergency contact) → home.

- Search Freetown places, choose Okada / Keke / Car / Comfort AC / XL with live fares in Leones.
- Animated driver search → driver arriving (ride PIN, plate check, live ETA) → on-trip with the car moving along the route and an SOS button.
- Pay with Orange Money, Afrimoney, TrustRide Wallet (really deducts) or cash → rate with stars, tags and tip.
- Trips history with receipts, wallet top-up, account, safety centre (press-and-hold SOS, trusted contacts, ride settings).

**Driver** — document upload with review status, Go online toggle with busy-zone heat map, incoming request with 15-second countdown, accept → pickup (PIN) → complete trip (earnings update), weekly earnings chart and cash-out.
Open it from onboarding ("I want to drive") or Account → Drive with TrustRide.

**Admin** — Account → Admin console. Responsive: sidebar on wide screens, drawer on phones.
Overview KPIs and charts, SOS alert resolve, driver verification queue (approve/reject updates counts), trips table with filters, payout batch release.

## Project layout

```
lib/
  main.dart                app entry
  core/theme.dart          brand colours (navy → green from the logo), type, Leone formatter
  core/data.dart           ride types, Freetown places, demo data
  core/app_state.dart      app state (ChangeNotifier) — swap methods for API calls
  core/routes.dart         named routes + custom page transitions
  widgets/                 buttons with press animation, animated map painter, nav bar
  screens/rider|driver|admin/
```

Packages: `google_fonts` and `flutter_animate` (animations). Icons are Phosphor (MIT), bundled in `assets/fonts` with constants in `lib/core/icons.dart` — the `phosphor_flutter` package does not build on current Flutter. No API keys needed.

## Going to production

- **Maps & location:** replace `TRMap` (a drawn map) with `google_maps_flutter` or `flutter_map` + `geolocator`.
- **Backend:** auth/OTP, pricing, dispatch, trip tracking and payouts are simulated in `AppState`. Wire them to your server (Firebase, Supabase or your own API).
- **Payments:** Orange Money and Afrimoney need merchant API agreements with each operator.
- **Check before launch:** fares and commission (15%) are placeholders; confirm the emergency numbers shown (999 police, 117 NEMS ambulance) and add your real support line in `account_screen.dart`.
