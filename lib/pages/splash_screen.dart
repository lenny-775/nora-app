import 'package:flutter/material.dart';
import 'welcome_page.dart';
import '../widgets/nora_logo.dart'; // <--- Assure-toi que ce chemin est bon

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
          transitionDuration: const Duration(milliseconds: 1500), // Transition lente et fluide
          pageBuilder: (context, animation, secondaryAnimation) => const WelcomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Le FadeTransition permet de faire apparaître le reste de la page Welcome en douceur
            // pendant que le Hero (le logo) voyage tout seul par-dessus.
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), // Même fond crème
      body: Center(
        child: Hero(
          tag: 'nora-logo-hero', // <--- MÊME TAG QUE SUR WELCOME PAGE (Très important)
          child: Material(
            color: Colors.transparent, // Nécessaire pour éviter les traits jaunes/noirs pendant le vol
            child: const NoraLogo(
              size: 90, // On le met bien gros (ex: 90) pour l'effet "Zoom out"
            ),
          ), 
        ),
      ),
    );
  }
}