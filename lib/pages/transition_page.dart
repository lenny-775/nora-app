import 'dart:async';
import 'package:flutter/material.dart';
import 'components.dart';
import 'home_page.dart';

class TransitionPage extends StatefulWidget {
  final String userName; // On reçoit le prénom ici

  const TransitionPage({super.key, required this.userName});

  @override
  State<TransitionPage> createState() => _TransitionPageState();
}

class _TransitionPageState extends State<TransitionPage> {
  
  final TextStyle _logoTextStyle = const TextStyle(
    fontSize: 50,
    fontWeight: FontWeight.bold,
    color: Color(0xFF3B4DA0),
    fontFamily: 'Avenir',
    height: 1.0, 
  );

  @override
  void initState() {
    super.initState();
    // Le chrono de 3 secondes avant d'aller sur la Home
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    });
  }

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
              
              // Le Logo qui tourne
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('N', style: _logoTextStyle),
                    const SizedBox(width: gapSize), 
                    // On garde le Hero tag pour la fluidité si jamais
                    const Hero(
                      tag: 'nora-logo-hero-transition', 
                      child: NoraPin3D(size: 50), 
                    ),
                    const SizedBox(width: gapSize), 
                    Text('R', style: _logoTextStyle),
                    const SizedBox(width: gapSize), 
                    Text('A', style: _logoTextStyle),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 1),
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Column(
                  children: [
                    Text(
                      "Bienvenue,",
                      style: TextStyle(fontSize: 22, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.userName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36, 
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF2D3436)
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "La communauté t'attend...",
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              const CircularProgressIndicator(
                color: Color(0xFFFF6B00),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}