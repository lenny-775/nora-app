import 'dart:math';
import 'package:flutter/material.dart';
import 'components.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _controller.addListener(() {
      if (_controller.value >= 0.5 && !_showPin) {
        if (mounted) setState(() => _showPin = true);
      } else if (_controller.value < 0.5 && _showPin) {
        if (mounted) setState(() => _showPin = false);
      }
    });

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final TextStyle _logoTextStyle = const TextStyle(
    fontSize: 50,
    fontWeight: FontWeight.bold,
    color: Color(0xFF3B4DA0),
    fontFamily: 'Avenir',
    height: 1.0, 
  );

  @override
  Widget build(BuildContext context) {
    // Espacement serré
    const double gapSize = 2.0; 

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
                    
                    // LA CAGE DU O / PIN
                    SizedBox(
                      width: 50, 
                      height: 60,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            final angle = _animation.value;
                            return Transform(
                              transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                              alignment: Alignment.center,
                              child: _showPin 
                                // ON REVIENT AUX ICÔNES FLUTTER
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()..rotateY(pi),
                                    // "Sandwich" d'icônes
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
                                          child: const Icon(Icons.location_on, size: 55, color: Colors.white),
                                        ),
                                        // La petite feuille (standard pour l'instant)
                                        const Positioned(
                                          top: 10,
                                          child: Icon(Icons.eco, size: 18, color: Colors.white), 
                                        ),
                                      ],
                                    ),
                                  )
                                : Text('O', style: _logoTextStyle),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: gapSize), 
                    Text('R', style: _logoTextStyle),
                    const SizedBox(width: gapSize), 
                    Text('A', style: _logoTextStyle),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              Text(
                "La communauté des PVTistes\nau Canada",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
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