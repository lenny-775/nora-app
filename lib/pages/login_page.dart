import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart'; // Import des composants

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (response.user != null) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de connexion'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), // Fond crème
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bouton Retour simple
              IconButton(
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 30),

              const Text(
                "Bon retour !",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              const SizedBox(height: 10),
              Text(
                "Connecte-toi pour retrouver tes potes.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
              const SizedBox(height: 50),

              // Champs Stylisés
              NoraTextField(
                controller: _emailController,
                hintText: "Ton email",
                icon: Icons.email_outlined,
              ),
              NoraTextField(
                controller: _passwordController,
                hintText: "Ton mot de passe",
                icon: Icons.lock_outline,
                obscureText: true,
              ),

              const Spacer(),

              // Bouton Principal
              NoraButton(
                text: "Se connecter",
                isLoading: _isLoading,
                onPressed: _signIn,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}