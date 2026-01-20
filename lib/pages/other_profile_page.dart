import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart'; 
import 'chat_page.dart';
import 'post_details_page.dart';

class OtherProfilePage extends StatefulWidget {
  final String userId; 

  const OtherProfilePage({super.key, required this.userId});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  bool _isLoading = true;
  bool _isMessageLoading = false;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userPosts = [];

  // COULEURS DESIGN SYSTEM
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _softGrey = const Color(0xFFF4F6F8);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      // 1. Profil
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();

      // 2. Posts
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

  // --- START CHAT (Rpc) ---
  Future<void> _startChat() async {
    setState(() => _isMessageLoading = true);
    final myId = Supabase.instance.client.auth.currentUser!.id;

    try {
      final existingConvId = await Supabase.instance.client.rpc('get_conversation_id', params: {
        'user1': myId, 
        'user2': widget.userId
      });
      
      int conversationId;

      if (existingConvId != null) {
        conversationId = existingConvId;
      } else {
        final newConv = await Supabase.instance.client.from('conversations').insert({}).select().single();
        conversationId = newConv['id'];
        await Supabase.instance.client.from('conversation_participants').insert([
          {'conversation_id': conversationId, 'user_id': myId},
          {'conversation_id': conversationId, 'user_id': widget.userId}
        ]);
      }

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

  String _formatDate(String dateString) {
    final date = DateTime.tryParse(dateString) ?? DateTime.now();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";
    return "${date.day}/${date.month}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(child: CircularProgressIndicator(color: _creamyOrange)),
      );
    }

    if (_profileData == null) {
      return const Scaffold(body: Center(child: Text("Utilisateur introuvable")));
    }

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
      backgroundColor: _backgroundColor,
      // SafeArea pour éviter l'encoche
      body: SafeArea(
        child: Stack(
          children: [
            // SCROLL VIEW PRINCIPALE
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24), // Marge en haut pour le bouton retour
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // --- AVATAR GLOW ---
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? Icon(Icons.person_rounded, size: 60, color: Colors.grey.shade400) : null,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // --- INFOS ---
                  Text(firstName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _darkText)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_rounded, size: 16, color: _creamyOrange),
                      const SizedBox(width: 4),
                      Text("$city • $status", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // --- BOUTON MESSAGE (PILLULE LARGE) ---
                  SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isMessageLoading ? null : _startChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _creamyOrange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        shadowColor: _creamyOrange.withOpacity(0.4),
                      ),
                      child: _isMessageLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                              SizedBox(width: 10),
                              Text("Message", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- BIO ---
                  if (bio.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Text(bio, style: TextStyle(fontSize: 15, height: 1.5, color: _darkText), textAlign: TextAlign.center),
                    ),

                  const SizedBox(height: 20),

                  // --- TAGS ---
                  if (lookingFor.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: lookingFor.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _creamyOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(tag, style: TextStyle(color: _creamyOrange, fontWeight: FontWeight.w700, fontSize: 13)),
                      )).toList(),
                    ),

                  const SizedBox(height: 30),
                  
                  // Titre Section Posts
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("${_userPosts.length} Publications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkText))
                  ),
                  const SizedBox(height: 15),

                  // --- LISTE DES POSTS ---
                  if (_userPosts.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text("Aucune publication pour l'instant.", style: TextStyle(color: Colors.grey.shade500)),
                    ))
                  else
                    ..._userPosts.map((post) {
                      final timeAgo = _formatDate(post['created_at']);
                      return _buildProfilePostCard(post, firstName, timeAgo);
                    }),
                ],
              ),
            ),

            // BOUTON RETOUR FLOTTANT (En haut à gauche)
            Positioned(
              top: 10,
              left: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: _darkText, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARTE POST MODERNE (Identique à ProfilePage) ---
  Widget _buildProfilePostCard(Map<String, dynamic> post, String userName, String timeAgo) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: userName, timeAgo: timeAgo))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post['image_url'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: Image.network(post['image_url'], fit: BoxFit.cover),
                  ),
                ),
              ),
              
            Text(post['content'], maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, height: 1.5, color: _darkText)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: _creamyOrange),
                const SizedBox(width: 6),
                Text(timeAgo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _softGrey, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: _darkText),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}