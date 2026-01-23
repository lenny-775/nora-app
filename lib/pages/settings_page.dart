import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/nora_logo.dart'; // ✅ Import du logo nécessaire
import 'welcome_page.dart';
import 'edit_profile_page.dart';
import 'feedback_page.dart'; // ✅ Import de la page feedback

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // COULEURS
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  bool _notificationsEnabled = true;

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer mon compte ?"),
        content: const Text(
          "Cette action est irréversible. Toutes vos données seront définitivement effacées.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Compte en cours de suppression...")));
        await _signOut();
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
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Paramètres", style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Mon Compte"),
          _buildSettingsTile(
            icon: Icons.person_outline_rounded,
            title: "Modifier le profil",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage())),
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            title: "Sécurité & Mot de passe",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityPage())),
          ),

          const SizedBox(height: 25),
          _buildSectionHeader("Préférences"),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
            child: SwitchListTile(
              activeColor: _creamyOrange,
              title: Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, color: _darkText, fontSize: 15)),
              subtitle: Text("Recevoir des alertes push", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _creamyOrange.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.notifications_outlined, color: _creamyOrange, size: 20),
              ),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
          ),

          const SizedBox(height: 25),
          _buildSectionHeader("Assistance & Légal"),
          
          // ✅ AJOUT DU BOUTON FEEDBACK ICI
          _buildSettingsTile(
            icon: Icons.bug_report_rounded,
            title: "Signaler un bug / Suggérer",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackPage())),
          ),

          _buildSettingsTile(
            icon: Icons.help_outline_rounded,
            title: "Aide & Support",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpPage())),
          ),
          _buildSettingsTile(
            icon: Icons.policy_outlined,
            title: "Politique de confidentialité",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPage())),
          ),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            title: "À propos de NORA",
            trailing: const Text("v1.0.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage())),
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // BOUTONS D'ACTION
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, color: Colors.orange),
            label: const Text("Se déconnecter", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          TextButton.icon(
            onPressed: _confirmDeleteAccount,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            label: const Text("Supprimer mon compte", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(title.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, VoidCallback? onTap, Widget? trailing}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(icon, color: _darkText, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _darkText, fontSize: 15))),
            if (trailing != null) trailing else Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 16)
          ],
        ),
      ),
    );
  }
}

// --- PAGES SECONDAIRES ---

class SimpleContentPage extends StatelessWidget {
  final String title;
  final String content;
  const SimpleContentPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
      ),
    );
  }
}

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text("Sécurité", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            leading: const Icon(Icons.lock_reset, color: Colors.orange),
            title: const Text("Changer le mot de passe"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Supabase.instance.client.auth.resetPasswordForEmail(Supabase.instance.client.auth.currentUser!.email!);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email de réinitialisation envoyé !")));
            },
          ),
        ],
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const SimpleContentPage(
      title: "Aide & Support",
      content: "Besoin d'aide ?\n\nContactez notre équipe support à l'adresse :\nsupport@nora-app.com",
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const SimpleContentPage(
      title: "Confidentialité",
      content: "Politique de confidentialité de NORA.\n\nNous respectons votre vie privée. Vos données sont stockées de manière sécurisée et ne sont jamais revendues à des tiers.",
    );
  }
}

// ✅ PAGE À PROPOS MISE À JOUR (Texte "NORA" supprimé)
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. LOGO NORA
            const NoraLogo(size: 80),
            
            const SizedBox(height: 20),
            // Le texte "NORA" a été supprimé ici
            const Text("Version 1.0.0", style: TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text("L'application d'entraide pour les nouveaux arrivants au Canada. 🍁", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF2D3436))),
            ),
            
            const SizedBox(height: 60),
            
            // 2. ANNÉE 2026
            const Text("© 2026 NORA Inc.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            
            const SizedBox(height: 10),
            
            // 3. CRÉDITS EN ANGLAIS
            const Text("Conceived by Cameron & Lenny", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const Text("Designed by Lenny", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}