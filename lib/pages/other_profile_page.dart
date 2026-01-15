import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'chat_page.dart';

class OtherProfilePage extends StatefulWidget {
  final String userId; // L'ID de l'autre personne

  const OtherProfilePage({super.key, required this.userId});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  bool _isLoading = true;
  bool _isMessageLoading = false; // Pour le bouton message
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();
      
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Gérer l'erreur si le profil n'est pas trouvé
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIQUE MAGIQUE : TROUVER OU CRÉER LA CONVERSATION ---
  Future<void> _startChat() async {
    setState(() => _isMessageLoading = true);
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final otherId = widget.userId;

    try {
      // 1. On cherche si une conversation existe déjà (dans les deux sens)
      final existingConv = await Supabase.instance.client
          .from('conversations')
          .select()
          .or('and(user1_id.eq.$myId,user2_id.eq.$otherId),and(user1_id.eq.$otherId,user2_id.eq.$myId)')
          .maybeSingle();

      int conversationId;

      if (existingConv != null) {
        // Elle existe !
        conversationId = existingConv['id'];
      } else {
        // Elle n'existe pas, on la crée
        final newConv = await Supabase.instance.client
            .from('conversations')
            .insert({
              'user1_id': myId,
              'user2_id': otherId,
              'last_message': 'Nouvelle connexion 👋',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        conversationId = newConv['id'];
      }

      // 2. On ouvre la page de Chat avec toutes les infos requises
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              conversationId: conversationId, // L'ID qu'on vient de trouver/créer
              receiverId: otherId,
              receiverName: _profileData?['first_name'] ?? "Voyageur",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    } finally {
      if (mounted) setState(() => _isMessageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F5),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
      );
    }

    if (_profileData == null) {
      return const Scaffold(body: Center(child: Text("Utilisateur introuvable")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Avatar
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(_profileData?['avatar_url'] ?? "https://i.pravatar.cc/300"),
              ),
              
              const SizedBox(height: 20),
              
              // Nom et Infos
              Text(
                _profileData?['first_name'] ?? "Voyageur",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
              ),
              Text(
                "${_profileData?['status'] ?? 'Membre'} à ${_profileData?['city'] ?? 'Canada'}",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 40),

              // --- BOUTON ENVOYER UN MESSAGE ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isMessageLoading ? null : _startChat,
                  icon: _isMessageLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.chat_bubble_outline),
                  label: Text(_isMessageLoading ? "Chargement..." : "Envoyer un message"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}