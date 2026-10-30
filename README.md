# TrustRide

*Your journey, our trust.* Ride-hailing for Sierra Leone: rider app, driver app and admin console in one Flutter project, running on **Firebase** (SMS login + live database) and **OpenStreetMap** (maps, place search, routes — no API keys).

There is no demo or sample data. Everything you see comes from your Firebase project.

---

## How it works

| Who | What they do |
|---|---|
| **Rider** | Signs in with an SMS code → searches a real place → sees the real route, distance and fare → books → watches the driver approach live → shares the PIN → rides → pays cash or from wallet → rates. SOS alerts the admin console and calls the police number. |
| **Driver** | Applies in the app (vehicle, plate, NIN, licence, payout number) → admin approves after checking documents in person → goes online (live GPS) → gets nearby requests with a 20 s countdown → accepts → navigates (Google Maps / OSM) → enters rider PIN → completes and confirms cash. Earnings and cash-outs are calculated from real trips. |
| **Admin** | Live overview and SOS alerts, approves/rejects/suspends drivers, sees every trip, pays out driver cash-out requests, credits rider wallets after receiving cash, and edits fares, commission and support/emergency numbers — changes reach all phones instantly. |

**Money model at launch:** riders pay **cash** to the driver or from their **TrustRide Wallet**. Wallet credit is added by an admin after receiving cash (agent/office). On cash trips the driver owes TrustRide the commission; on wallet trips TrustRide owes the driver their share. The driver's Earnings screen shows the running balance. Orange Money / Afrimoney can be added once you have merchant APIs.

---

## Set up (about 30 minutes, once)

You need: Flutter 3.24+, Node.js (for the Firebase CLI), a Google account.

### 1. Create the Firebase project
1. Go to <https://console.firebase.google.com> → **Add project** → name it `trustride`.
2. **Build → Authentication → Get started → Sign-in method → Phone → Enable.**
3. **Build → Firestore Database → Create database** → *Production mode* → pick a region close to West Africa (e.g. `europe-west1`).
4. Phone sign-in sends real SMS, which needs the **Blaze (pay-as-you-go)** plan; you are billed per SMS. While testing you can stay on the free plan by adding **test phone numbers** (Authentication → Sign-in method → Phone → *Phone numbers for testing*), e.g. `+232 76 000 001` with code `123456`.

### 2. Connect this app to the project
```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
cd trustride
flutterfire configure --platforms=android,web
```
Pick your `trustride` project. This **replaces `lib/firebase_options.dart`** with your keys (the file in the repo is a placeholder that shows a "Connect TrustRide to Firebase" screen).

### 3. Publish the security rules
Firebase console → **Firestore Database → Rules** → paste the contents of [`firestore.rules`](firestore.rules) → **Publish**.
These rules stop riders changing fares or adding wallet credit, stop drivers approving themselves, and keep each person's trips private.

### 4. Android phone sign-in
```bash
cd android && ./gradlew signingReport
```
Copy the **SHA-1** and **SHA-256** of the `debug` variant (and later your release key) into Firebase console → **Project settings → Your apps → Android (sl.trustride.app) → Add fingerprint**. Then run `flutterfire configure` again so the app picks them up.

### 5. Run it
```bash
flutter pub get
flutter run                 # Android phone (recommended for riders/drivers)
flutter run -d chrome       # admin console in the browser
```
If `pub get` reports version conflicts with a newer Flutter, run `flutter pub upgrade --major-versions`.

### 6. Make yourself an admin
1. Sign in once in the app with your phone number and finish your profile.
2. Firebase console → **Firestore → users →** your document → change `role` from `rider` to `admin`.
3. Open the app again: on the web you go straight to the admin console; on a phone it's under **Account → Admin console**.

### 7. Before opening to the public
- **Admin → Prices & settings:** set fares for each ride type, the commission, your **support phone number**, and confirm the **police and ambulance numbers** shown in the Safety centre.
- Recruit drivers: they apply under **Account → Drive with TrustRide**; you approve them under **Driver verification** after checking their NIN card, licence and vehicle papers in person.

---

## Publish

**Admin console (web):**
```bash
flutter build web
firebase init hosting      # public directory: build/web, single-page app: yes
firebase deploy --only hosting
```
Add the hosting domain under Authentication → Settings → **Authorized domains**.

**Android (Play Store):** create an upload key, set up signing in `android/app/build.gradle.kts` ([guide](https://docs.flutter.dev/deployment/android)), add the release SHA fingerprints to Firebase, then `flutter build appbundle`.

---

## Project layout
```
lib/
  main.dart                 Firebase start-up
  firebase_options.dart     generated by `flutterfire configure`
  core/models.dart          users, drivers, trips, wallet, payouts, SOS, prices
  core/app_state.dart       signed-in user, live profile/driver/config, booking
  core/launch.dart          where to send a user after launch/sign-in
  services/db.dart          every Firestore read/write
  services/auth_service.dart  SMS sign-in
  services/geo_service.dart   place search, reverse geocoding, routes (OSM)
  services/location_service.dart  GPS
  widgets/live_map.dart     OpenStreetMap map with markers and routes
  screens/rider|driver|admin/
firestore.rules             security rules — publish these
```

Firestore collections: `users`, `drivers`, `trips`, `walletTx`, `payouts`, `sos`, `config/app`.

## Scaling notes
- **Maps and search** use the free public OpenStreetMap tile, Nominatim and OSRM servers, which have fair-use limits. When traffic grows, switch `LiveMap.tileUrl` and the hosts in `GeoService` to a paid provider (MapTiler, Stadia, Geoapify) or your own server.
- **Trust-critical logic** (wallet debits, payouts) is protected by security rules. As you grow, move fare calculation and payments into Firebase Cloud Functions so they run on the server.
- **Document photos:** drivers' documents are checked in person. To collect photos in-app, add Firebase Storage + `image_picker` (Storage requires the Blaze plan).
- **Notifications:** add Firebase Cloud Messaging to alert offline drivers of requests and riders when the driver arrives.
