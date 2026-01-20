import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart'; // <--- AJOUTÉ
import '../widgets/nora_logo.dart'; 
import 'signup_page.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  
  final Color _creamyOrange = const Color(0xFFFF914D); 

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (response.user != null && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Erreur de connexion inconnue');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _socialSignIn(OAuthProvider provider) async {
    if (provider == OAuthProvider.google) setState(() => _isGoogleLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
    } catch (e) {
      if (mounted) _showError('Erreur sociale: $e');
    } finally {
      if (mounted && provider == OAuthProvider.google) setState(() => _isGoogleLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3436)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(minHeight: screenHeight * 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- ANIMATION AJOUTÉE ICI ---
              SizedBox(
                height: 200,
                child: Lottie.asset('assets/animations/login.json', fit: BoxFit.contain),
              ),
              
              const SizedBox(height: 20),

              const Text(
                "Bon retour !",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3436),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "La communauté t'attend. Reprends là où tu t'es arrêté.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4),
              ),

              const SizedBox(height: 40),

              _buildPillTextField(
                controller: _emailController,
                hint: "Email",
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildPillTextField(
                controller: _passwordController,
                hint: "Mot de passe",
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bientôt disponible !"))),
                  child: Text("Mot de passe oublié ?", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ),
              ),

              const SizedBox(height: 20),

              // BOUTON PRINCIPAL AVEC L'ORANGE CRÉMEUX
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _creamyOrange, 
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("Se connecter", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text("Ou continue avec", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialCircle(
                    isLoading: _isGoogleLoading,
                    onTap: () => _socialSignIn(OAuthProvider.google),
                    child: Image.network("https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png", width: 24),
                  ),
                  const SizedBox(width: 20),
                  _buildSocialCircle(
                    isLoading: false,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Apple bientôt disponible"))),
                    child: const Icon(Icons.apple, size: 30, color: Colors.black),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Pas encore de compte ? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignupPage())),
                    child: Text(
                      "Rejoindre NORA",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _creamyOrange,
                        decoration: TextDecoration.underline,
                        decorationColor: _creamyOrange,
                        fontSize: 15
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(icon, color: Colors.grey.shade400, size: 22)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: _creamyOrange, width: 1.5), 
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCircle({required Widget child, required VoidCallback onTap, required bool isLoading}) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 65, height: 65,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: isLoading ? const CircularProgressIndicator(strokeWidth: 2) : Center(child: child),
      ),
    );
  }
}