import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _controller = TextEditingController();
  String _selectedType = 'idea'; // 'idea', 'bug', 'other'
  bool _isSending = false;

  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  // ✅ FONCTION MODIFIÉE POUR AFFICHER LES ERREURS
  Future<void> _sendFeedback() async {
    print("--- 🟢 DÉBUT DE LA TENTATIVE D'ENVOI ---");

    if (_controller.text.trim().isEmpty) {
      print("⚠️ Erreur : Le champ texte est vide.");
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;

      // 1. VÉRIFICATION DE LA CONNEXION
      if (user == null) {
        print("❌ ERREUR CRITIQUE : User est NULL. L'utilisateur n'est pas connecté.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Tu dois être connecté pour envoyer un avis !"), 
              backgroundColor: Colors.red
            ),
          );
        }
        setState(() => _isSending = false);
        return;
      }

      print("✅ Utilisateur connecté trouvé : ${user.id}");
      print("🚀 Envoi vers la table 'app_feedback' en cours...");

      // 2. ENVOI VERS SUPABASE
      await Supabase.instance.client.from('app_feedback').insert({
        'user_id': user.id,
        'type': _selectedType,
        'content': _controller.text.trim(),
      });

      print("✅ SUCCÈS : Données insérées dans Supabase !");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Merci ! Ton retour a bien été envoyé. 💌")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // 3. ERREUR TECHNIQUE (RLS, Table inexistante, etc.)
      print("❌ ERREUR SUPABASE : $e");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur technique: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: BackButton(color: _darkText),
        title: Text("Ton avis compte", style: TextStyle(color: _darkText, fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tu as repéré un bug ou tu as une idée de génie ? Dis-nous tout ! 💡",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 25),
            
            Text("C'est à propos de quoi ?", style: TextStyle(fontWeight: FontWeight.bold, color: _darkText)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTypeChip("Idée 💡", 'idea'),
                const SizedBox(width: 10),
                _buildTypeChip("Bug 🪲", 'bug'),
                const SizedBox(width: 10),
                _buildTypeChip("Autre 💬", 'other'),
              ],
            ),

            const SizedBox(height: 25),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Décris-nous le problème ou ta suggestion...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _creamyOrange)),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _creamyOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Envoyer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                "Promis, on lit tout ! (On fait un point tous les mercredis 🗓️)",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    bool isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _creamyOrange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _creamyOrange : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: _creamyOrange.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}