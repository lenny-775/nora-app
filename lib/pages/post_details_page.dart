import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostDetailsPage extends StatefulWidget {
  final Map<String, dynamic> post; // On reçoit les infos du post cliqué

  const PostDetailsPage({super.key, required this.post});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final _commentController = TextEditingController();
  final User? user = Supabase.instance.client.auth.currentUser;
  bool _isLoading = false;

  // Fonction pour envoyer un commentaire
  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // On récupère les infos fraîches du profil pour l'avatar et le nom
      final userProfile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user!.id)
          .single();

      final authorName = userProfile['first_name'] ?? 'Anonyme';
      final avatarUrl = userProfile['avatar_url'] ?? '';

      // Envoi dans Supabase
      await Supabase.instance.client.from('comments').insert({
        'post_id': widget.post['id'], // Lien avec le post
        'content': content,
        'author_name': authorName,
        'avatar_url': avatarUrl,
      });

      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus(); // Ferme le clavier
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Utilitaires visuels (mêmes que Home)
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final difference = DateTime.now().difference(date);
      if (difference.inMinutes < 60) return "Il y a ${difference.inMinutes} min";
      if (difference.inHours < 24) return "Il y a ${difference.inHours} h";
      return "${date.day}/${date.month}";
    } catch (e) { return "Récemment"; }
  }

  Color _getTagColor(String tag) {
    switch (tag.toLowerCase()) {
      case 'job': return Colors.green.shade100;
      case 'logement': return Colors.orange.shade100;
      case 'sortie': return Colors.purple.shade100;
      case 'aide': return Colors.red.shade100;
      default: return Colors.blue.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Flux des commentaires pour CE post précis
    final Stream<List<Map<String, dynamic>>> _commentsStream = Supabase.instance.client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', widget.post['id'])
        .order('created_at', ascending: true); // Plus anciens en haut (comme un chat)

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Discussion'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      body: Column(
        children: [
          // 1. LE POST ORIGINAL (En haut, fixe ou scrollable avec le reste)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Carte du Post
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blueGrey.shade100,
                              child: Text((widget.post['author'] as String)[0], style: const TextStyle(color: Colors.black87)),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.post['author'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(_formatDate(widget.post['created_at']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getTagColor(widget.post['tag'] ?? ''),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(widget.post['tag'] ?? 'Général', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(widget.post['content'], style: const TextStyle(fontSize: 16, height: 1.5)),
                      ],
                    ),
                  ),

                  // Titre section commentaires
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Commentaires", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                  ),

                  // LISTE DES COMMENTAIRES (StreamBuilder imbriqué dans le scroll)
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _commentsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }
                      final comments = snapshot.data!;
                      
                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: Text("Sois le premier à répondre !", style: TextStyle(color: Colors.grey))),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true, // Important car dans un SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Le scroll est géré par le parent
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final avatar = comment['avatar_url'] ?? '';
                          final name = comment['author_name'] ?? 'Inconnu';

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                  backgroundColor: Colors.grey.shade200,
                                  child: avatar.isEmpty ? Text(name[0]) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(comment['content'] ?? '', style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 80), // Espace pour ne pas cacher le dernier com derrière la zone de saisie
                ],
              ),
            ),
          ),
          
          // 2. ZONE DE SAISIE (En bas, fixe)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Ajouter un commentaire...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _sendComment,
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.send, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}