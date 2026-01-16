import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'other_profile_page.dart';

class PostDetailsPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String userName;
  final String? avatarUrl;
  final String timeAgo;

  const PostDetailsPage({
    super.key,
    required this.post,
    required this.userName,
    this.avatarUrl,
    required this.timeAgo,
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final TextEditingController _commentController = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser!.id;
  bool _isSending = false;
  
  // Variables locales pour gérer les likes en direct sur cette page
  late List<dynamic> _likedBy;
  late bool _isLikedByMe;

  @override
  void initState() {
    super.initState();
    // On initialise avec les données reçues
    _likedBy = List.from(widget.post['liked_by'] ?? []);
    _isLikedByMe = _likedBy.contains(_myId);
  }

  // --- LOGIQUE LIKE (Similaire à Home mais avec setState local) ---
  Future<void> _toggleLike() async {
    // 1. Mise à jour visuelle immédiate (Optimiste)
    setState(() {
      if (_isLikedByMe) {
        _likedBy.remove(_myId);
        _isLikedByMe = false;
      } else {
        _likedBy.add(_myId);
        _isLikedByMe = true;
      }
    });

    // 2. Envoi à Supabase
    try {
      await Supabase.instance.client
          .from('posts')
          .update({'liked_by': _likedBy})
          .eq('id', widget.post['id']);
    } catch (e) {
      // Si erreur, on annule (optionnel, mais propre)
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de connexion")));
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('comments').insert({
        'content': text,
        'user_id': _myId,
        'post_id': widget.post['id'], 
      });

      _commentController.clear();
      if (mounted) FocusScope.of(context).unfocus();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text("Commentaires", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // --- 1. LE POST EN HAUT ---
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Carte du post avec gestion du LIKE
                  NoraPostCard(
                    userName: widget.userName,
                    avatarUrl: widget.avatarUrl,
                    timeAgo: widget.timeAgo,
                    content: widget.post['content'] ?? "",
                    likes: _likedBy.length, // On utilise la liste locale à jour
                    comments: 0,
                    isLiked: _isLikedByMe,  // État local
                    onLike: _toggleLike,    // Fonction locale
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Réponses", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),

                  // --- 2. LA LISTE DES COMMENTAIRES ---
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('comments')
                        .stream(primaryKey: ['id'])
                        .eq('post_id', widget.post['id'])
                        .order('created_at', ascending: true),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }

                      final comments = snapshot.data!;

                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text("Sois le premier à répondre !", style: TextStyle(color: Colors.grey.shade500)),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];

                          return FutureBuilder<Map<String, dynamic>>(
                            future: Supabase.instance.client
                                .from('profiles')
                                .select('first_name, avatar_url')
                                .eq('id', comment['user_id'])
                                .single(),
                            builder: (context, profileSnap) {
                              final name = profileSnap.data?['first_name'] ?? "Voyageur";
                              final avatar = profileSnap.data?['avatar_url'];

                              return ListTile(
                                leading: GestureDetector(
                                  onTap: () {
                                    if (comment['user_id'] != _myId) {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: comment['user_id'])));
                                    }
                                  },
                                  child: CircleAvatar(
                                    backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                                    radius: 18,
                                    child: avatar == null ? Text(name[0]) : null,
                                  ),
                                ),
                                title: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(comment['content'] ?? "", style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // --- 3. LA BARRE DE SAISIE ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Ajouter un commentaire...",
                      filled: true,
                      fillColor: const Color(0xFFFFF8F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : CircleAvatar(
                      backgroundColor: const Color(0xFFFF6B00),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: _sendComment,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}