import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _isLoading = false;
  
  // Contrôleurs
  final _firstNameController = TextEditingController();
  final _emailController = TextEditingController(); // Juste pour l'affichage
  
  String? _selectedCity;
  String? _selectedStatus;
  
  // Listes (Mêmes que l'inscription)
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _statusOptions = ['PVTiste', 'Expatrié', 'Étudiant', 'Touriste', 'Local'];

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  // 1. On charge les infos actuelles pour pré-remplir les champs
  Future<void> _loadCurrentData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      if (mounted) {
        setState(() {
          _firstNameController.text = data['first_name'] ?? '';
          _emailController.text = user.email ?? ''; // L'email vient de l'Auth, pas de la table profiles
          _selectedCity = data['city'];
          _selectedStatus = data['status'];
        });
      }
    }
  }

  // 2. On sauvegarde les modifications
  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;

    try {
      if (user != null) {
        await Supabase.instance.client.from('profiles').update({
          'first_name': _firstNameController.text.trim(),
          'city': _selectedCity,
          'status': _selectedStatus,
          // On peut ajouter l'avatar ici plus tard
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis à jour ! 🎉'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); // "true" pour dire à la page précédente de recharger
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text("Modifier mon profil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Champ Email (Lecture seule)
            NoraTextField(
              controller: _emailController,
              hintText: "Email",
              icon: Icons.lock_outline, // Cadenas pour montrer que c'est bloqué
              readOnly: true,
            ),
            const SizedBox(height: 5),
            Text("L'email ne peut pas être modifié pour l'instant.", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            
            const SizedBox(height: 20),

            // Champ Prénom
            NoraTextField(
              controller: _firstNameController,
              hintText: "Ton prénom",
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 15),

            // Dropdown Ville (Style Custom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCity,
                  isExpanded: true,
                  hint: const Row(children: [Icon(Icons.location_city, color: Colors.grey), SizedBox(width: 10), Text("Ta ville")]),
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCity = v),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Dropdown Statut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  hint: const Row(children: [Icon(Icons.badge, color: Colors.grey), SizedBox(width: 10), Text("Ton statut")]),
                  items: _statusOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Bouton Sauvegarder
            NoraButton(
              text: "Enregistrer les modifications",
              isLoading: _isLoading,
              onPressed: _updateProfile,
            ),
          ],
        ),
      ),
    );
  }
}