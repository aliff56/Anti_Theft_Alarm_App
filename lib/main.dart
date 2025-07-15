import 'package:flutter/material.dart';
import 'theme.dart';
import 'splash_navigator.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Anti-Theft',
      theme: getAppTheme(),
      home: SplashNavigator(
        navigatorKey: navigatorKey,
        buildHome: () => const MyHomePage(title: 'Anti-Theft'),
      ),
    );
  }
}
