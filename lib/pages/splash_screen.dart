import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showPin = false; // Pour savoir si on affiche le "O" ou le "Pin"

  @override
  void initState() {
    super.initState();

    // 1. Configuration de l'animation (Durée 2 secondes)
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // L'animation va de 0 à 2*Pi (un tour complet 360°)
    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    // Écouter l'animation pour changer l'objet à la moitié du tour
    _controller.addListener(() {
      if (_controller.value >= 0.5 && !_showPin) {
        setState(() {
          _showPin = true; // On passe du O au Pin
        });
      }
    });

    // 2. Lancer l'animation + Vérifier la connexion
    _startApp();
  }

  Future<void> _startApp() async {
    // On lance l'animation
    await _controller.forward();
    
    // Petite pause pour admirer le logo fini
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. Vérification : L'utilisateur est-il déjà connecté ?
    final session = Supabase.instance.client.auth.currentSession;
    
    if (mounted) {
      if (session != null) {
        // Déjà connecté -> Accueil
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Pas connecté -> Page de Bienvenue
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F2), // Ton fond crème
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Lettre N
            const Text(
              'N',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B4DA0), // Bleu foncé du logo NORA
                fontFamily: 'Avenir',
              ),
            ),
            
            const SizedBox(width: 8),

            // --- L'ANIMATION DU O / PIN ---
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                // On calcule l'angle.
                // Matrix4.rotationY permet de faire tourner comme une pièce
                final angle = _animation.value;
                
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Effet de perspective 3D
                    ..rotateY(angle),
                  alignment: Alignment.center,
                  child: _showPin 
                    // Si on a dépassé la moitié, on affiche le PIN (il faut le retourner pour qu'il soit à l'endroit)
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi), // Miroir pour corriger la rotation
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Le Pin dégradé
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFFF0055), Color(0xFFFF6B00)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ).createShader(bounds),
                              child: const Icon(Icons.location_on, size: 65, color: Colors.white),
                            ),
                            // La feuille d'érable
                            const Positioned(
                              top: 12,
                              child: Icon(Icons.eco, size: 22, color: Colors.white), 
                            ),
                          ],
                        ),
                      )
                    // Sinon, on affiche le "O"
                    : const Text(
                        'O',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B4DA0), // Bleu
                        ),
                      ),
                );
              },
            ),

            const SizedBox(width: 8),

            // Lettres RA
            const Text(
              'RA',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B4DA0), // Bleu
                fontFamily: 'Avenir',
              ),
            ),
          ],
        ),
      ),
    );
  }
}