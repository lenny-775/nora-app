import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class OtherProfilePage extends StatefulWidget {
  final String userId; // L'ID de la personne qu'on visite

  const OtherProfilePage({super.key, required this.userId});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  final myId = Supabase.instance.client.auth.currentUser!.id;
  bool _isLoading = false;

  // Logique pour DÉMARRER ou REPRENDRE une conversation
  Future<void> _startConversation(String otherName) async {
    setState(() => _isLoading = true);
    
    try {
      final client = Supabase.instance.client;

      // 1. Vérifier si une conversation existe déjà
      // On cherche une conv où (user1=moi ET user2=lui) OU (user1=lui ET user2=moi)
      final existingParams = await client.from('conversations').select().or(
        'and(user1_id.eq.$myId, user2_id.eq.${widget.userId}), and(user1_id.eq.${widget.userId}, user2_id.eq.$myId)'
      );

      int conversationId;

      if (existingParams.isNotEmpty) {
        // La conversation existe déjà, on prend son ID
        conversationId = existingParams[0]['id'];
      } else {
        // 2. Sinon, on la crée
        final newConv = await client.from('conversations').insert({
          'user1_id': myId,
          'user2_id': widget.userId,
          'last_message': 'Nouvelle discussion',
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single(); // .select().single() permet de récupérer l'objet créé immédiatement
        
        conversationId = newConv['id'];
      }

      if (mounted) {
        // 3. On ouvre le chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              conversationId: conversationId,
              otherUserName: otherName,
            ),
          ),
        );
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // On n'affiche pas le bouton message si on visite son propre profil
    final bool isMe = widget.userId == myId;

    return Scaffold(
      appBar: AppBar(title: const Text("Profil"), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
      backgroundColor: const Color(0xFFF5F7FA),
      body: FutureBuilder<Map<String, dynamic>>(
        future: Supabase.instance.client.from('profiles').select().eq('id', widget.userId).single(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final profile = snapshot.data!;
          final firstName = profile['first_name'] ?? 'Inconnu';
          final city = profile['city'] ?? 'Monde';
          final status = profile['status'] ?? 'Voyageur';
          final avatarUrl = profile['avatar_url'] ?? '';

          return Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 60,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty ? Text(firstName[0]) : null,
                ),
                const SizedBox(height: 20),
                Text(firstName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text("$status à $city", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                
                const SizedBox(height: 40),

                if (!isMe)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _startConversation(firstName),
                    icon: const Icon(Icons.chat_bubble),
                    label: const Text("Envoyer un message"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}