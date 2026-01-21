import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart'; 
import 'login_page.dart';
import 'signup_page.dart';
import '../widgets/nora_logo.dart'; 

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  bool _isGoogleLoading = false;
  late final AnimationController _controller;

  final Color _creamyOrange = const Color(0xFFFF914D); 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1), 
              
              SizedBox(
                height: 250, 
                width: double.infinity,
                child: Lottie.asset(
                  'assets/animations/community.json', 
                  controller: _controller,
                  fit: BoxFit.contain,
                  onLoaded: (composition) {
                    _controller
                      ..duration = composition.duration 
                      ..forward(); 
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.people, size: 80, color: Colors.orange));
                  },
                ),
              ),
              
              const SizedBox(height: 20),

              Column(
                children: [
                  const Text(
                    "Bienvenue sur",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.w900, 
                      color: Color(0xFF2D3436),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // --- CORRECTION DÉFINITIVE LOGO (Départ sécurisé) ---
                  Hero(
                    tag: 'nora-logo-hero', 
                    child: Material(
                      color: Colors.transparent, 
                      child: SizedBox(
                        height: 55, // Hauteur voulue
                        width: 180, // Largeur de sécurité
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: const NoraLogo(size: 55),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              
              Text(
                "Rencontre, partage et vis ton expatriation à fond.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
              ),

              const Spacer(flex: 2), 

              _buildPillButton(
                text: "Continuer avec Email",
                icon: Icons.mail_outline,
                color: _creamyOrange, 
                textColor: Colors.white, 
                borderColor: _creamyOrange, 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupPage())),
              ),
              
              const SizedBox(height: 15),

              _buildPillButton(
                text: "Continuer avec Google",
                customIcon: _isGoogleLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : Image.network("https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png", height: 22),
                color: Colors.white,
                textColor: Colors.black,
                borderColor: Colors.grey.shade300,
                onTap: _continueWithGoogle,
              ),

              const SizedBox(height: 15),

              _buildPillButton(
                text: "Continuer avec Apple",
                icon: Icons.apple,
                color: Colors.white,
                textColor: Colors.black,
                borderColor: Colors.grey.shade300,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bientôt disponible !"))),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Déjà un compte ? ", style: TextStyle(color: Colors.grey.shade600)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage())),
                    child: Text(
                      "Se connecter",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _creamyOrange,
                        decoration: TextDecoration.underline,
                        decorationColor: _creamyOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required String text,
    IconData? icon,
    Widget? customIcon,
    required Color color,
    required Color textColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55, 
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: borderColor, width: 1.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null) ...[customIcon, const SizedBox(width: 12)] 
            else if (icon != null) ...[Icon(icon, size: 24, color: textColor), const SizedBox(width: 12)],
            Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }
}