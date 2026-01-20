import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components.dart';
import 'profile_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart';
import 'post_details_page.dart';
import 'search_page.dart';
import 'welcome_page.dart';
import 'other_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 
  
  String _currentCityFilter = "Montréal"; 
  String _currentTopicFilter = "Tout";
  
  final List<String> _topics = ['Tout', '🏠 Logement', '💼 Emploi', '🍻 Sorties', '🆘 Entraide', '📢 Annonce'];
  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];

  // --- PALETTE DE COULEURS ---
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _softGrey = const Color(0xFFF4F6F8); 

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadProfile();
  }

  Future<void> _checkAuthAndLoadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
         Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()), 
          (route) => false,
        );
      }
      return;
    }
    try {
      final data = await Supabase.instance.client.from('profiles').select('city').eq('id', user.id).maybeSingle();
      if (mounted && data != null && data['city'] != null) {
        setState(() => _currentCityFilter = data['city']);
      }
    } catch (e) {
      debugPrint("Erreur profil: $e");
    }
  }

  // --- BADGE NOTIF ---
  Widget _buildChatIconWithBadge() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 26);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('messages').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.where((m) => m['read_at'] == null && m['sender_id'] != user.id).length;
        }

        if (unreadCount == 0) {
          return const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 26);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 26),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.redAccent, 
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- FILTRES ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: 450,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text("Filtrer le fil d'actu", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _darkText)),
                  const SizedBox(height: 30),
                  const Text("Ville", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 45,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cities.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final city = _cities[index];
                        final isSelected = _currentCityFilter == city;
                        return ChoiceChip(
                          label: Text(city),
                          selected: isSelected,
                          selectedColor: _creamyOrange,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSelected ? _creamyOrange : Colors.grey.shade200),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : _darkText, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          onSelected: (bool selected) {
                            setModalState(() => _currentCityFilter = city);
                            setState(() {}); 
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text("Sujet", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))]),
                    child: DropdownButtonFormField<String>(
                      value: _currentTopicFilter,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
                      decoration: InputDecoration(filled: true, fillColor: Colors.transparent, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
                      style: TextStyle(color: _darkText, fontWeight: FontWeight.w600, fontSize: 16),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) { setModalState(() => _currentTopicFilter = v!); setState(() {}); },
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      child: const Text("Appliquer", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _toggleSavePost(int postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final existing = await Supabase.instance.client.from('saved_posts').select().eq('user_id', user.id).eq('post_id', postId).maybeSingle();
      if (existing == null) {
        await Supabase.instance.client.from('saved_posts').insert({'user_id': user.id, 'post_id': postId});
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegardé ! 🔖")));
      } else {
        await Supabase.instance.client.from('saved_posts').delete().eq('user_id', user.id).eq('post_id', postId);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Retiré des favoris.")));
      }
      setState(() {}); 
    } catch (e) { debugPrint("Erreur favoris: $e"); }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    List<dynamic> likedBy = List.from(post['liked_by'] ?? []);
    setState(() {
      likedBy.contains(user.id) ? likedBy.remove(user.id) : likedBy.add(user.id);
    });
    await Supabase.instance.client.from('posts').update({'liked_by': likedBy}).eq('id', post['id']);
  }

  // --- APP BAR ---
  PreferredSizeWidget _buildAppBar() {
    if (_selectedIndex != 0) return AppBar(toolbarHeight: 0, elevation: 0, backgroundColor: _backgroundColor); 
    return AppBar(
      backgroundColor: _backgroundColor, elevation: 0, automaticallyImplyLeading: false, titleSpacing: 24,
      title: Row(
        children: [
          GestureDetector(
            onTap: _showFilterModal,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))]),
              child: const Icon(Icons.tune_rounded, color: Colors.black87, size: 22),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: _creamyOrange, size: 24),
                    const SizedBox(width: 12),
                    Text("Rechercher...", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage()));
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _creamyOrange, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: _creamyOrange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 10),
          child: Row(
            children: [
              Icon(Icons.location_on_rounded, size: 18, color: _creamyOrange),
              const SizedBox(width: 5),
              Text(_currentCityFilter, style: TextStyle(fontWeight: FontWeight.w800, color: _darkText, fontSize: 16)),
              const Spacer(),
              if (_currentTopicFilter != "Tout")
                 Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _creamyOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(_currentTopicFilter, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _creamyOrange))),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
              final allPosts = snapshot.data!;
              final posts = allPosts.where((p) {
                final matchCity = (p['city'] ?? '') == _currentCityFilter;
                final matchTopic = _currentTopicFilter == 'Tout' || (p['category'] ?? '') == _currentTopicFilter;
                return matchCity && matchTopic;
              }).toList();

              if (posts.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_none, size: 60, color: Colors.grey.shade300), const SizedBox(height: 20), Text("Rien ici pour l'instant à $_currentCityFilter...", style: TextStyle(color: Colors.grey.shade600))]));

              return ListView.builder(
                padding: const EdgeInsets.only(top: 5, bottom: 100), 
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return FutureBuilder<List<dynamic>>(
                    future: Future.wait<dynamic>([
                      Supabase.instance.client.from('profiles').select().eq('id', post['user_id']).single(), 
                      Supabase.instance.client.from('comments').count().eq('post_id', post['id']), 
                      myId != null ? Supabase.instance.client.from('saved_posts').select().eq('user_id', myId).eq('post_id', post['id']).maybeSingle() : Future.value(null)
                    ]),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox(); 
                      final data = snap.data!;
                      final author = Map<String, dynamic>.from(data[0] as Map);
                      final commentsCount = data[1] as int;
                      final isSaved = data[2] != null;
                      final createdAt = DateTime.tryParse(post['created_at'].toString()) ?? DateTime.now();
                      final diff = DateTime.now().difference(createdAt);
                      String timeAgo = diff.inMinutes < 60 ? "${diff.inMinutes} min" : diff.inHours < 24 ? "${diff.inHours} h" : "${diff.inDays} j";
                      List<dynamic> likedBy = post['liked_by'] ?? [];

                      return _buildModernPostCard(post, author, timeAgo, likedBy.contains(myId), likedBy.length, commentsCount, isSaved, myId);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- NOUVEAU DESIGN MODERNE DU POST ---
  Widget _buildModernPostCard(Map<String, dynamic> post, Map<String, dynamic> author, String timeAgo, bool isLiked, int likesCount, int commentsCount, bool isSaved, String? myId) {
    bool isMyPost = post['user_id'] == myId;
    
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: author['first_name'], timeAgo: timeAgo))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), // Coins très arrondis "Pill"
          boxShadow: [
            BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. EN-TÊTE DU POST
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => isMyPost ? setState(()=>_selectedIndex=2) : Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: post['user_id']))),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _creamyOrange.withOpacity(0.3), width: 2)), // Anneau subtil
                      child: CircleAvatar(radius: 20, backgroundImage: NetworkImage(author['avatar_url'] ?? "https://i.pravatar.cc/300")),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author['first_name'] ?? "User", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _darkText)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(timeAgo, style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.circle, size: 4, color: Colors.grey.shade300),
                            ),
                            // Badge Catégorie Minimaliste
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: _creamyOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(post['category'] ?? 'Divers', style: TextStyle(fontSize: 10, color: _creamyOrange, fontWeight: FontWeight.w800)),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Bouton Sauvegarder (Icône simple)
                  IconButton(
                    icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isSaved ? _creamyOrange : Colors.grey.shade300),
                    onPressed: () => _toggleSavePost(post['id']),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. CONTENU TEXTE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(post['content'] ?? "", style: TextStyle(fontSize: 15, height: 1.5, color: _darkText)),
            ),

            const SizedBox(height: 16),

            // 3. IMAGE (AVEC TAILLE MAXIMALE ET ROGNAGE PROPRE)
            if (post['image_url'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10), // Petit padding pour effet "cadre"
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25), // Arrondi harmonieux
                  child: Container(
                    height: 350, // <--- TAILLE MAX IMPOSÉE
                    width: double.infinity,
                    color: Colors.grey.shade100, // Fond gris en attendant
                    child: Image.network(
                      post['image_url'], 
                      fit: BoxFit.cover, // <--- C'est ici que la magie opère (remplit le cadre)
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ),

            // 4. BARRE D'ACTIONS "CAPSULES"
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Capsule Like
                  GestureDetector(
                    onTap: () => _toggleLike(post),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLiked ? Colors.red.withOpacity(0.1) : _softGrey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? Colors.redAccent : Colors.grey.shade600, size: 20),
                          const SizedBox(width: 6),
                          Text("$likesCount", style: TextStyle(color: isLiked ? Colors.redAccent : Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Capsule Commentaire
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _softGrey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 6),
                        Text("$commentsCount", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Bouton Share
                  IconButton(
                    icon: Icon(Icons.share_rounded, color: Colors.grey.shade400, size: 22),
                    onPressed: () {}, // Action future
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      extendBody: true,
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [ _buildFeed(), const ConversationsPage(), const ProfilePage() ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 34),
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: _darkText.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.home_rounded, Icons.home_outlined),
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 55, height: 55,
                decoration: BoxDecoration(
                  color: _selectedIndex == 1 ? _creamyOrange : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  boxShadow: [if(_selectedIndex == 1) BoxShadow(color: _creamyOrange.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))]
                ),
                child: Center(child: _selectedIndex == 1 ? _buildChatIconWithBadge() : Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey.shade500, size: 26)), 
              ),
            ),
            _buildNavItem(2, Icons.person_rounded, Icons.person_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isSelected ? _creamyOrange.withOpacity(0.1) : Colors.transparent, shape: BoxShape.circle),
        child: Icon(isSelected ? activeIcon : inactiveIcon, size: 30, color: isSelected ? _creamyOrange : Colors.grey.shade300),
      ),
    );
  }
}