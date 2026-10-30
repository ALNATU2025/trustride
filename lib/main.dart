import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'core/routes.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(TrustRideApp(state: AppState()));
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
      ),
    );
  }
}
