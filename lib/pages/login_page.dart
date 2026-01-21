import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _resetEmailController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  
  // Pour gérer l'œil du mot de passe
  bool _isPasswordVisible = false;
  
  final Color _creamyOrange = const Color(0xFFFF914D); 
  final Color _darkText = const Color(0xFF2D3436);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE CONNEXION ---
  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar("Merci de remplir tous les champs");
      return;
    }
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
      // Si c'est une erreur de login, on affiche la belle POP-UP au milieu
      if (e.message.toLowerCase().contains("invalid login") || e.message.toLowerCase().contains("credentials")) {
        if (mounted) _showLoginErrorDialog();
      } else {
        if (mounted) _showErrorSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Erreur de connexion inconnue');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _socialSignIn(OAuthProvider provider) async {
    setState(() {
      if (provider == OAuthProvider.google) _isGoogleLoading = true;
      if (provider == OAuthProvider.apple) _isAppleLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
    } catch (e) {
      if (mounted) _showErrorSnackBar('Erreur connexion sociale: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _isAppleLoading = false;
        });
      }
    }
  }

  // --- LOGIQUE MOT DE PASSE OUBLIÉ ---
  Future<void> _resetPassword() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar("Entre ton email pour recevoir le lien");
      return;
    }
    
    Navigator.pop(context); // Ferme la pop-up
    _showSuccessSnackBar("Envoi en cours...");

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutterquickstart://reset-callback/',
      );
      if (mounted) _showSuccessSnackBar("Email de réinitialisation envoyé ! Vérifie tes spams.");
    } catch (e) {
      if (mounted) _showErrorSnackBar("Erreur: ${e.toString()}");
    }
  }

  // --- NOUVELLE MODALE D'ERREUR STYLÉE (AU MILIEU) ---
  void _showLoginErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.15), blurRadius: 25, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône d'erreur stylée
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.no_accounts_rounded, size: 32, color: Colors.redAccent),
              ),
              const SizedBox(height: 15),
              
              Text("Oups !", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _darkText)),
              const SizedBox(height: 10),
              
              Text(
                "Email ou mot de passe incorrect.\nTu veux le réinitialiser ?", 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4)
              ),
              
              const SizedBox(height: 25),
              
              // Bouton Réinitialiser
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Ferme l'erreur
                    _showForgotPasswordDialog(); // Ouvre la demande de reset
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _creamyOrange, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0
                  ),
                  child: const Text("Réinitialiser mon mot de passe", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              
              // Bouton Réessayer
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Réessayer", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- MODALE MOT DE PASSE OUBLIÉ ---
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Color(0xFFFFF8F5), shape: BoxShape.circle),
                child: Icon(Icons.lock_reset_rounded, size: 32, color: _creamyOrange),
              ),
              const SizedBox(height: 15),
              const Text("Mot de passe oublié ?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2D3436))),
              const SizedBox(height: 10),
              Text("Pas de panique. Entre ton email et on t'envoie un lien magique.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              
              TextField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Ton email",
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _resetPassword,
                  style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                  child: const Text("Envoyer le lien", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO (Correction V3 : FittedBox) ---
              Hero(
                tag: 'nora-logo-hero',
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    height: 80,
                    width: 250,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: const NoraLogo(size: 80),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              const Text(
                "Bon retour !",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2D3436), letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                "La communauté t'attend.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.4),
              ),

              const SizedBox(height: 40),

              _buildPillTextField(controller: _emailController, hint: "Email", icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              
              // --- CHAMP MOT DE PASSE (AVEC L'ŒIL) ---
              _buildPillTextField(
                controller: _passwordController, 
                hint: "Mot de passe", 
                icon: Icons.lock_outline_rounded, 
                isPassword: !_isPasswordVisible, 
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey.shade400),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                )
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: Text("Mot de passe oublié ?", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("Se connecter", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 30),

              Row(children: [Expanded(child: Divider(color: Colors.grey.shade300)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("Ou continue avec", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500))), Expanded(child: Divider(color: Colors.grey.shade300))]),
              
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
                    isLoading: _isAppleLoading,
                    onTap: () => _socialSignIn(OAuthProvider.apple),
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
                    child: Text("Rejoindre NORA", style: TextStyle(fontWeight: FontWeight.bold, color: _creamyOrange, decoration: TextDecoration.underline, decorationColor: _creamyOrange, fontSize: 15)),
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
    Widget? suffixIcon
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))]),
      child: TextField(
        controller: controller, obscureText: isPassword, keyboardType: keyboardType, style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 10), child: Icon(icon, color: Colors.grey.shade400, size: 22)),
          suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 10), child: suffixIcon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _creamyOrange, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildSocialCircle({required Widget child, required VoidCallback onTap, required bool isLoading}) {
    return InkWell(
      onTap: isLoading ? null : onTap, borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 65, height: 65, padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 1.5), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4))]),
        child: isLoading ? const CircularProgressIndicator(strokeWidth: 2) : Center(child: child),
      ),
    );
  }
}