import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = Supabase.instance.client.auth.currentUser;
  bool _isEditing = false;
  bool _isLoading = false;

  // Contrôleurs
  final _firstNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _statusController = TextEditingController();
  
  // Nouveaux contrôleurs
  final _ageController = TextEditingController();
  final _goalController = TextEditingController();

  // Pour l'affichage (données sécurisées)
  String _displayName = "";
  String _displayCity = "";
  String _displayStatus = "";
  String _displayAge = "";
  String _displayGoal = "";
  String _avatarUrl = "";

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  Future<void> _getProfile() async {
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user!.id)
          .single();

      setState(() {
        // ON SÉCURISE LES DONNÉES ICI (?? '')
        _firstNameController.text = data['first_name'] ?? '';
        _cityController.text = data['city'] ?? '';
        _statusController.text = data['status'] ?? '';
        _goalController.text = data['goal'] ?? '';
        _ageController.text = (data['age'] != null) ? data['age'].toString() : '';

        // Mise à jour des variables d'affichage
        _displayName = data['first_name'] ?? 'Utilisateur';
        _displayCity = data['city'] ?? 'Ville inconnue';
        _displayStatus = data['status'] ?? 'PVTiste';
        _displayGoal = data['goal'] ?? 'Découvrir le Canada';
        _displayAge = (data['age'] != null) ? "${data['age']} ans" : "";
        _avatarUrl = data['avatar_url'] ?? '';
      });
    } catch (e) {
      // Si le profil n'existe pas encore (cas rare), on ne fait rien
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final firstName = _firstNameController.text.trim();
      final city = _cityController.text.trim();
      final status = _statusController.text.trim();
      final goal = _goalController.text.trim();
      final int? age = int.tryParse(_ageController.text.trim());

      // Mise à jour avatar si le prénom change
      final newAvatarUrl = "https://api.dicebear.com/9.x/initials/png?seed=$firstName&backgroundColor=FF6B00&textColor=ffffff";

      await Supabase.instance.client.from('profiles').upsert({
        'id': user!.id,
        'first_name': firstName,
        'city': city,
        'status': status,
        'age': age,
        'goal': goal,
        'avatar_url': newAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // On rafraîchit l'affichage
      await _getProfile();
      
      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour !')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur mise à jour')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mon Profil', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit, color: _isEditing ? Colors.green : Colors.black),
            onPressed: () {
              if (_isEditing) {
                _updateProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- AVATAR ---
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                child: _avatarUrl.isEmpty ? Text(_displayName.isNotEmpty ? _displayName[0] : '?', style: const TextStyle(fontSize: 30)) : null,
              ),
            ),
            const SizedBox(height: 20),

            if (!_isEditing) ...[
              // --- MODE LECTURE (Joli affichage) ---
              Text(_displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (_displayAge.isNotEmpty) Text(_displayAge, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 5),
              Chip(
                label: Text(_displayStatus),
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                labelStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Carte Infos
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.location_on, "Ville", _displayCity),
                    const Divider(),
                    _buildInfoRow(Icons.flag, "Objectif", _displayGoal),
                    const Divider(),
                    _buildInfoRow(Icons.email, "Email", user?.email ?? ""),
                  ],
                ),
              ),
            ] else ...[
              // --- MODE ÉDITION (Champs texte) ---
              const SizedBox(height: 20),
              _buildTextField("Prénom", _firstNameController),
              const SizedBox(height: 10),
              _buildTextField("Âge", _ageController, isNumber: true),
              const SizedBox(height: 10),
              _buildTextField("Ville actuelle", _cityController),
              const SizedBox(height: 10),
              _buildTextField("Statut (Ex: PVTiste)", _statusController),
              const SizedBox(height: 10),
              _buildTextField("Mon objectif (Ex: Trouver un job)", _goalController),
              
              const SizedBox(height: 20),
              if (_isLoading) const CircularProgressIndicator(),
            ],

            const SizedBox(height: 30),
            
            // Bouton Déconnexion
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text("Se déconnecter", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value.isNotEmpty ? value : "Non renseigné", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}