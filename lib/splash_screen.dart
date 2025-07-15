import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  const SplashScreen({Key? key, required this.onGetStarted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2C5364), // top
              Color(0xFF203A43), // bottom
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Concentric circles behind the icon
            Stack(
              alignment: Alignment.center,
              children: [
                // Outermost circle
                Container(
                  width: 340, // Increased from 320
                  height: 340, // Increased from 320
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
                // Middle circle
                Container(
                  width: 320, // Increased from 300
                  height: 320, // Increased from 300
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
                // Innermost circle
                Container(
                  width: 290, // Increased from 270
                  height: 290, // Increased from 270
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.13),
                  ),
                ),
                // Icon with border and text below
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 140, // Increased from 120
                          height: 140, // Increased from 120
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10), // Decreased from 18
                    const Text(
                      'Anti-Theft Alarm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20, // Decreased from 24
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onGetStarted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF203A43),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
