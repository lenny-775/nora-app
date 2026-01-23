import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart'; // Pour le bouton Message
import 'post_details_page.dart'; // Pour cliquer sur les posts

class OtherProfilePage extends StatefulWidget {
  final String userId;

  const OtherProfilePage({super.key, required this.userId});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  final _myId = Supabase.instance.client.auth.currentUser?.id;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = [];

  // COULEURS
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    _fetchProfileAndPosts();
  }

  Future<void> _fetchProfileAndPosts() async {
    try {
      // 1. Récupérer le profil
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      // 2. Récupérer les posts
      final posts = await Supabase.instance.client
          .from('posts')
          .select()
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIQUE SIGNALER ---
  Future<void> _reportUser() async {
    if (_myId == null) return;
    try {
      await Supabase.instance.client.from('reports').insert({
        'reporter_id': _myId,
        'reported_id': widget.userId,
        'reason': 'Signalement via profil'
      });
      if (mounted) {
        Navigator.pop(context); // Ferme le popup
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Utilisateur signalé. Merci de votre vigilance."))
        );
      }
    } catch (e) {
      debugPrint("Erreur report: $e");
    }
  }

  // --- LOGIQUE BLOQUER ---
  Future<void> _blockUser() async {
    if (_myId == null) return;
    try {
      await Supabase.instance.client.from('blocked_users').insert({
        'blocker_id': _myId,
        'blocked_id': widget.userId,
      });
      if (mounted) {
        Navigator.pop(context); // Ferme le popup
        Navigator.pop(context); // Revient à la page précédente (quitte le profil)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Utilisateur bloqué."))
        );
      }
    } catch (e) {
      // Si déjà bloqué ou erreur
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur ou utilisateur déjà bloqué")));
    }
  }

  // --- MENU POPUP ---
  void _showOptionsPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            
            // SIGNALER
            GestureDetector(
              onTap: _reportUser,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, color: _creamyOrange, size: 24),
                    const SizedBox(width: 15),
                    Text("Signaler cet utilisateur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _creamyOrange)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // BLOQUER
            GestureDetector(
              onTap: () {
                // Confirmation avant de bloquer
                showDialog(
                  context: context, 
                  builder: (ctx) => AlertDialog(
                    title: const Text("Bloquer ?"),
                    content: const Text("Vous ne verrez plus ses posts et il ne pourra plus vous contacter."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
                      TextButton(onPressed: () { Navigator.pop(ctx); _blockUser(); }, child: const Text("Bloquer", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                  )
                );
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Colors.red, size: 24),
                    const SizedBox(width: 15),
                    const Text("Bloquer cet utilisateur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: _backgroundColor, body: Center(child: CircularProgressIndicator(color: _creamyOrange)));
    if (_profileData == null) return const Scaffold(body: Center(child: Text("Profil introuvable")));

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // ✅ LES 3 PETITS POINTS SONT ICI
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: _darkText),
            onPressed: _showOptionsPopup,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // AVATAR
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: _profileData!['avatar_url'] != null ? NetworkImage(_profileData!['avatar_url']) : null,
              child: _profileData!['avatar_url'] == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
            ),
            const SizedBox(height: 15),
            
            // NOM
            Text(
              _profileData!['first_name'] ?? "Utilisateur",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _darkText),
            ),
            
            // VILLE & TAGS
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_profileData!['city'] != null) ...[
                  Icon(Icons.location_on, size: 14, color: _creamyOrange),
                  const SizedBox(width: 4),
                  Text(_profileData!['city'], style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                ],
                Text("•  ${_profileData!['status'] ?? 'Membre'}", style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),

            const SizedBox(height: 20),

            // BOUTON MESSAGE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Redirection vers le chat avec cet ID
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(
                    conversationId: 0, // Le chat page cherchera le bon ID
                    receiverId: widget.userId,
                    receiverName: _profileData!['first_name'] ?? "User",
                  )));
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                label: const Text("Message", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _creamyOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                  elevation: 5,
                  shadowColor: _creamyOrange.withOpacity(0.4),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // TAGS (Looking For)
            if (_profileData!['looking_for'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: (_profileData!['looking_for'] as String).split(', ').map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 14, color: _creamyOrange),
                          const SizedBox(width: 5),
                          Text(tag, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 30),
            
            // SECTION PUBLICATIONS
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("${_userPosts.length} Publications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _darkText)),
              ),
            ),
            const SizedBox(height: 15),

            // LISTE DES POSTS
            if (_userPosts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(child: Text("Aucune publication pour le moment.", style: TextStyle(color: Colors.grey.shade400))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: _userPosts.length,
                itemBuilder: (context, index) {
                  final post = _userPosts[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(
                      post: post, 
                      userName: _profileData!['first_name'], 
                      timeAgo: "..." // Pas besoin de calculer précis ici
                    ))),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 3))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post['content'] ?? "", maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: _darkText, fontSize: 14)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 5),
                              Text("Posté récemment", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey.shade300)
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}