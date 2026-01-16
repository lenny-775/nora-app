import 'dart:io'; // Pour mobile
import 'dart:typed_data'; // Pour web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // ✅ Pour choisir la photo
import 'components.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;

  final _firstNameController = TextEditingController();
  final _bioController = TextEditingController(); // Nouvelle Bio
  
  String? _selectedCity;
  String? _selectedStatus;
  List<String> _selectedGoals = []; // Liste des objectifs
  String? _avatarUrl; // URL actuelle de l'avatar

  // Listes d'options (Identiques au Signup)
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _statusOptions = ['PVTiste', 'Expatrié', 'Étudiant', 'Touriste', 'Local'];
  final List<String> _goals = ['👋 Rencontrer du monde', '💼 Trouver un job', '🏠 Trouver un logement', '🍻 Boire des verres', '📍 Découvrir la ville', '🎨 Juste curieux'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // --- 1. CHARGEMENT DES DONNÉES ---
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _firstNameController.text = data['first_name'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _selectedCity = data['city'];
        _selectedStatus = data['status'];
        _avatarUrl = data['avatar_url'];

        // On récupère les objectifs stockés sous forme de texte "Job, Potes" -> Liste
        if (data['looking_for'] != null && data['looking_for'].isNotEmpty) {
          _selectedGoals = (data['looking_for'] as String).split(', ');
        }
        
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur chargement: $e")));
    }
  }

  // --- 2. UPLOAD PHOTO (Magie !) ---
  Future<void> _uploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    // Ouvre la galerie
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    
    if (image == null) return; // Annulé par l'utilisateur

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Upload vers Supabase Storage
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: image.mimeType));

      // 2. Récupérer l'URL publique
      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // 3. Mettre à jour l'affichage local
      setState(() {
        _avatarUrl = imageUrl;
        _isSaving = false;
      });
      
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur upload: $e")));
    }
  }

  // --- 3. SAUVEGARDE GLOBALE ---
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final goalsString = _selectedGoals.join(', ');

      await Supabase.instance.client.from('profiles').update({
        'first_name': _firstNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'city': _selectedCity,
        'status': _selectedStatus,
        'looking_for': goalsString,
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour ! 🎉")));
        Navigator.pop(context, true); // Revient en arrière et signale un changement
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur sauvegarde: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text("Modifier mon profil", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // --- SECTION AVATAR ---
                Center(
                  child: GestureDetector(
                    onTap: _isSaving ? null : _uploadAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                          child: _avatarUrl == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- CHAMPS TEXTE ---
                const Text("Infos perso", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                NoraTextField(controller: _firstNameController, hintText: "Prénom", icon: Icons.person),
                const SizedBox(height: 15),
                
                // Champ BIO (Zone de texte plus grande)
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Écris une petite bio sympa...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                
                const SizedBox(height: 30),

                // --- DROPDOWNS ---
                const Text("Ma situation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                DropdownButtonFormField(
                  value: _cities.contains(_selectedCity) ? _selectedCity : null,
                  decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.location_city, color: Colors.grey)),
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCity = v as String?),
                  hint: const Text("Ville"),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: _statusOptions.contains(_selectedStatus) ? _selectedStatus : null,
                  decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.badge, color: Colors.grey)),
                  items: _statusOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v as String?),
                  hint: const Text("Statut"),
                ),

                const SizedBox(height: 30),

                // --- RECHERCHE (Multi-select) ---
                const Text("Je recherche...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goals.map((goal) {
                    final isSelected = _selectedGoals.contains(goal);
                    return FilterChip(
                      label: Text(goal),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF6B00).withOpacity(0.2),
                      checkmarkColor: const Color(0xFFFF6B00),
                      labelStyle: TextStyle(color: isSelected ? const Color(0xFFFF6B00) : Colors.black),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedGoals.add(goal);
                          } else {
                            _selectedGoals.remove(goal);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 40),
                NoraButton(
                  text: "Enregistrer",
                  isLoading: _isSaving,
                  onPressed: _saveProfile,
                ),
              ],
            ),
    );
  }
}