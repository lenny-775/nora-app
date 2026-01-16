import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart'; // Pour utiliser NoraPostCard
import 'chat_page.dart';
import 'post_details_page.dart';

class OtherProfilePage extends StatefulWidget {
  final String userId; // L'ID de la personne qu'on visite

  const OtherProfilePage({super.key, required this.userId});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  bool _isLoading = true;
  bool _isMessageLoading = false;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = []; // Pour stocker ses posts

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      // 1. Récupérer le Profil
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      // 2. Récupérer ses Posts
      final posts = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(first_name, avatar_url)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profileData = profile;
          _userPosts = List<Map<String, dynamic>>.from(posts);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur chargement: $e")));
      }
    }
  }

  // --- LOGIQUE DE CHAT (Mise à jour avec RPC) ---
  Future<void> _startChat() async {
    setState(() => _isMessageLoading = true);
    final myId = Supabase.instance.client.auth.currentUser!.id;

    try {
      // 1. On cherche la conversation via la fonction SQL (plus robuste)
      final existingConvId = await Supabase.instance.client.rpc('get_conversation_id', params: {
        'user1': myId, 
        'user2': widget.userId
      });
      
      int conversationId;

      if (existingConvId != null) {
        // Elle existe déjà
        conversationId = existingConvId;
      } else {
        // Elle n'existe pas, on la crée
        final newConv = await Supabase.instance.client.from('conversations').insert({}).select().single();
        conversationId = newConv['id'];
        
        // On ajoute les participants
        await Supabase.instance.client.from('conversation_participants').insert([
          {'conversation_id': conversationId, 'user_id': myId},
          {'conversation_id': conversationId, 'user_id': widget.userId}
        ]);
      }

      // 2. On ouvre le Chat
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChatPage(
            conversationId: conversationId,
            receiverId: widget.userId,
            receiverName: _profileData?['first_name'] ?? "Utilisateur",
          )),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur chat: $e")));
    } finally {
      if (mounted) setState(() => _isMessageLoading = false);
    }
  }

  // Helper pour formater la date
  String _formatDate(String dateString) {
    final date = DateTime.tryParse(dateString) ?? DateTime.now();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";
    return "${diff.inDays} j";
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

    // Préparation des données
    final String firstName = _profileData?['first_name'] ?? "Voyageur";
    final String? avatarUrl = _profileData?['avatar_url'];
    final String bio = _profileData?['bio'] ?? "";
    final String city = _profileData?['city'] ?? "Inconnu";
    final String status = _profileData?['status'] ?? "PVTiste";
    
    List<String> lookingFor = [];
    if (_profileData?['looking_for'] != null && (_profileData?['looking_for'] as String).isNotEmpty) {
      lookingFor = (_profileData?['looking_for'] as String).split(', ');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(firstName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // --- HEADER PROFIL ---
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                ),
                const SizedBox(height: 15),
                Text(firstName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                Text("$city • $status", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                
                const SizedBox(height: 20),
                
                // BOUTON MESSAGE
                SizedBox(
                  width: 200,
                  child: ElevatedButton.icon(
                    onPressed: _isMessageLoading ? null : _startChat,
                    icon: _isMessageLoading 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.chat_bubble_outline),
                    label: const Text("Message"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 25),

          // --- BIO ---
          if (bio.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)],
              ),
              child: Text(bio, style: const TextStyle(fontSize: 15, height: 1.4)),
            ),

          const SizedBox(height: 15),

          // --- TAGS (Looking For) ---
          if (lookingFor.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: lookingFor.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(tag, style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 12)),
              )).toList(),
            ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),
          
          Text("${_userPosts.length} Publications", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // --- LISTE DES POSTS ---
          if (_userPosts.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("Aucune publication pour l'instant.", style: TextStyle(color: Colors.grey)),
            ))
          else
            ..._userPosts.map((post) {
              final timeAgo = _formatDate(post['created_at']);
              final likesCount = (post['liked_by'] as List?)?.length ?? 0;
              final myId = Supabase.instance.client.auth.currentUser?.id;
              final isLiked = (post['liked_by'] as List?)?.contains(myId) ?? false;

              return GestureDetector(
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: firstName, timeAgo: timeAgo)));
                },
                child: NoraPostCard(
                  userName: firstName,
                  avatarUrl: avatarUrl,
                  timeAgo: timeAgo,
                  content: post['content'] ?? "",
                  likes: likesCount,
                  comments: 0,
                  isLiked: isLiked,
                  onLike: () {}, // On désactive le like sur le profil des autres pour simplifier l'UI ici
                  onShare: null, // Pas de partage ici
                ),
              );
            }),
        ],
      ),
    );
  }
}