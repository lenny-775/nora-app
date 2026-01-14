import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fond couleur crème/pêche très doux comme sur l'image
      backgroundColor: const Color(0xFFFFF5F2), 
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 50), // Espace du haut

              // --- LOGO NORA ---
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'N',
                        style: TextStyle(
                          fontSize: 50, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF2D3436), // Gris foncé
                          fontFamily: 'Avenir', // Ou police par défaut
                        ),
                      ),
                      // Simulation du O avec la feuille d'érable
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.location_on, size: 55, color: Colors.redAccent.shade700),
                          const Positioned(
                            top: 10,
                            child: Icon(Icons.eco, size: 20, color: Colors.white), // Petite feuille dedans
                          ),
                        ],
                      ),
                      const Text(
                        'RA',
                        style: TextStyle(
                          fontSize: 50, 
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF2D3436)
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // --- TEXTES CENTRAUX ---
              const Column(
                children: [
                  Text(
                    'Bienvenue sur NORA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "La communauté d'entraide pour les\nPVTistes francophones au Canada",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF636E72), // Gris moyen
                      height: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- BOUTONS ---
              Column(
                children: [
                  // BOUTON CRÉER UN COMPTE (Dégradé Orange/Rouge)
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF6B00), // Orange vif
                          Color(0xFFFF0055), // Rouge rosé
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0055).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Créer un compte',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BOUTON SE CONNECTER (Blanc)
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A1A1A), // Texte noir
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Mentions légales
                  Text(
                    'En continuant, tu acceptes nos conditions d\'utilisation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}