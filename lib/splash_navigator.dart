import 'package:flutter/material.dart';
import 'splash_screen.dart';

class SplashNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget Function() buildHome;
  const SplashNavigator({
    required this.navigatorKey,
    required this.buildHome,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      onGetStarted: () {
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => buildHome()),
        );
      },
    );
  }
}
