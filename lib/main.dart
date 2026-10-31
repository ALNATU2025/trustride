import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/lock_screen.dart';
import 'services/app_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(SetupNeededApp(error: e.toString()));
    return;
  }

  await AppLock.instance.load();
  final state = AppState()..start();
  runApp(TrustRideApp(state: state));
}

class TrustRideApp extends StatelessWidget {
  const TrustRideApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'TrustRide',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: R.splash,
        onGenerateRoute: R.generate,
        builder: (context, child) => LockGate(child: child ?? const SizedBox()),
      ),
    );
  }
}

/// Shown when Firebase has not been configured for this build.
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 120, height: 120),
                const SizedBox(height: 20),
                Text('Connect TrustRide to Firebase', style: TS.h2),
                const SizedBox(height: 10),
                Text(
                    'Run `flutterfire configure` in the project folder, then restart the app. Full steps are in README.md.',
                    style: TS.body),
                const SizedBox(height: 16),
                SelectableText(error, style: TS.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
