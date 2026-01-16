import 'package:flutter/material.dart';
import 'welcome_page.dart';
import 'components.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _navigateToWelcome();
  }

  _navigateToWelcome() async {
    // On attend 2 secondes pour bien voir le logo fixe
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1500), // Transition un peu plus lente pour apprécier le vol
          pageBuilder: (context, animation, secondaryAnimation) => const WelcomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- ICI : On demande au logo de NE PAS tourner ---
            const Hero(
              tag: 'nora-logo-hero', 
              child: NoraPin3D(
                size: 100, // On le met bien gros au début
                isAnimating: false, // STOP ! Pas de rotation ici.
              ), 
            ),
          ],
        ),
      ),
    );
  }
}