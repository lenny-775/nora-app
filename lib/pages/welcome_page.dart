import 'package:flutter/material.dart';
import 'components.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  
  final TextStyle _logoTextStyle = const TextStyle(
    fontSize: 50,
    fontWeight: FontWeight.bold,
    color: Color(0xFF3B4DA0),
    fontFamily: 'Avenir',
    height: 1.0, 
  );

  @override
  Widget build(BuildContext context) {
    const double gapSize = 5.0; 

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('N', style: _logoTextStyle),
                    const SizedBox(width: gapSize), 
                    
                    // --- LE LOGO ARRIVE ICI ET COMMENCE À TOURNER ---
                    const Hero(
                      tag: 'nora-logo-hero',
                      // Ici on ne met pas isAnimating: false, donc par défaut c'est true !
                      // Il va se mettre à tourner dès qu'il arrive.
                      child: NoraPin3D(size: 50), 
                    ),
                    
                    const SizedBox(width: gapSize), 
                    Text('R', style: _logoTextStyle),
                    const SizedBox(width: gapSize), 
                    Text('A', style: _logoTextStyle),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Text(
                  "La communauté des PVTistes\nau Canada",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
                ),
              ),

              const Spacer(),

              NoraButton(
                text: "Commencer l'aventure",
                onPressed: () => Navigator.pushNamed(context, '/signup'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text("J'ai déjà un compte", style: TextStyle(color: Color(0xFF2D3436), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}