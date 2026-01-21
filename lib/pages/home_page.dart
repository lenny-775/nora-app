import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart'; 
import 'dart:ui'; 
import 'dart:async'; 
import '../widgets/nora_logo.dart'; 
import 'profile_page.dart';
import 'create_post_page.dart';
import 'conversations_page.dart';
import 'post_details_page.dart';
import 'welcome_page.dart';
import 'other_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; 
  
  // --- GESTION RECHERCHE ---
  bool _isSearching = false; 
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _foundProfiles = []; 
  Timer? _debounce; 

  // --- FILTRES (Listes réintégrées) ---
  String _currentCityFilter = "Montréal"; 
  String _currentTopicFilter = "Tout";

  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _topics = ['Tout', '🏠 Logement', '💼 Emploi', '🍻 Sorties', '🆘 Entraide', '📢 Annonce'];

  // --- VARIABLES "OPTIMISTIC UI" ---
  final Map<String, bool> _optimisticLikes = {}; 
  final Map<String, int> _optimisticCounts = {};
  
  // --- PALETTE ---
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);
  final Color _backgroundColor = const Color(0xFFFFF8F5); 

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadProfile();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomePage()), (route) => false);
      return;
    }
    try {
      final data = await Supabase.instance.client.from('profiles').select('city').eq('id', user.id).maybeSingle();
      if (mounted && data != null && data['city'] != null) {
        // On vérifie que la ville de l'utilisateur est bien dans notre liste, sinon on garde la défaut
        if (_cities.contains(data['city'])) {
          setState(() => _currentCityFilter = data['city']);
        }
      }
    } catch (e) {
      debugPrint("Erreur profil: $e");
    }
  }

  // --- RECHERCHE ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => _foundProfiles = []);
        return;
      }
      try {
        final res = await Supabase.instance.client.from('profiles').select().ilike('first_name', '%$query%').limit(5);
        if (mounted) setState(() => _foundProfiles = List<Map<String, dynamic>>.from(res));
      } catch (e) { debugPrint("Erreur recherche: $e"); }
    });
    setState(() {}); 
  }

  // --- LIKE INSTANTANÉ ---
  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final String postId = post['id'].toString();
    List<dynamic> currentDbLikes = List.from(post['liked_by'] ?? []);
    bool isLikedInDb = currentDbLikes.contains(user.id);

    bool currentlyLiked = _optimisticLikes[postId] ?? isLikedInDb;
    int currentCount = _optimisticCounts[postId] ?? currentDbLikes.length;

    setState(() {
      if (currentlyLiked) {
        _optimisticLikes[postId] = false;
        _optimisticCounts[postId] = (currentCount - 1).clamp(0, 9999);
      } else {
        _optimisticLikes[postId] = true;
        _optimisticCounts[postId] = currentCount + 1;
      }
    });

    try {
      if (isLikedInDb) {
        currentDbLikes.remove(user.id); 
        if (!currentlyLiked) currentDbLikes.add(user.id); 
      } else {
        currentDbLikes.add(user.id); 
      }
      await Supabase.instance.client.from('posts').update({'liked_by': currentDbLikes}).eq('id', postId);
    } catch (e) {
      debugPrint("ERREUR LIKE DB: $e");
      setState(() {
        _optimisticLikes.remove(postId);
        _optimisticCounts.remove(postId);
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: Impossible de liker.")));
    }
  }

  // --- SAUVEGARDE POST (MODIFIÉ : PLUS DE SNACKBAR) ---
  Future<void> _toggleSavePost(int postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final existing = await Supabase.instance.client.from('saved_posts').select().eq('user_id', user.id).eq('post_id', postId).maybeSingle();
      if (existing == null) {
        // Ajouter aux favoris
        await Supabase.instance.client.from('saved_posts').insert({'user_id': user.id, 'post_id': postId});
        // Pas de SnackBar ici
      } else {
        // Retirer des favoris
        await Supabase.instance.client.from('saved_posts').delete().eq('user_id', user.id).eq('post_id', postId);
        // Pas de SnackBar ici non plus
      }
      setState(() {}); // On met à jour l'icône (vide/plein)
    } catch (e) { 
      debugPrint("Erreur favoris: $e"); 
    }
  }

  // --- APP BAR ---
  PreferredSizeWidget _buildAppBar() {
    if (_selectedIndex != 0) return AppBar(toolbarHeight: 0, elevation: 0, backgroundColor: _backgroundColor);
    return AppBar(
      backgroundColor: _backgroundColor, elevation: 0, centerTitle: true, automaticallyImplyLeading: false,
      leading: _isSearching
        ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20), onPressed: () => setState(() { _isSearching = false; _searchController.clear(); _foundProfiles = []; }))
        : IconButton(icon: const Icon(Icons.search_rounded, color: Colors.black, size: 28), onPressed: () => setState(() => _isSearching = true)),
      title: _isSearching
        ? TextField(
            controller: _searchController, autofocus: true, style: TextStyle(color: _darkText, fontSize: 18), cursorColor: _creamyOrange,
            decoration: InputDecoration(hintText: "Chercher...", hintStyle: TextStyle(color: Colors.grey.shade400), border: InputBorder.none),
            onChanged: _onSearchChanged,
          )
        : Hero(
            tag: 'nora-logo-hero',
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                height: 40, 
                width: 120, 
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: const NoraLogo(size: 40),
                ),
              ),
            ),
          ),
      actions: [
        if (!_isSearching) 
          IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 28), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage())); setState(() {}); }),
        const SizedBox(width: 12),
      ],
    );
  }

  // --- WIDGET FILTRES ---
  Widget _buildFilterDropdowns() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // FILTRE VILLE
          Expanded(
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.black, width: 0.6), // Style V3
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _cities.contains(_currentCityFilter) ? _currentCityFilter : _cities[0],
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                  style: TextStyle(color: _darkText, fontWeight: FontWeight.bold, fontSize: 14),
                  items: _cities.map((String city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) setState(() => _currentCityFilter = newValue);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12), // Séparation
          // FILTRE THÈME
          Expanded(
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.black, width: 0.6), // Style V3
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _topics.contains(_currentTopicFilter) ? _currentTopicFilter : _topics[0],
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                  style: TextStyle(color: _darkText, fontWeight: FontWeight.bold, fontSize: 14),
                  items: _topics.map((String topic) {
                    return DropdownMenuItem<String>(
                      value: topic,
                      child: Text(topic, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) setState(() => _currentTopicFilter = newValue);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FEED ---
  Widget _buildFeed() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        
        final allPosts = snapshot.data!;
        final posts = allPosts.where((p) {
          final matchCity = (p['city'] ?? '') == _currentCityFilter;
          final matchTopic = _currentTopicFilter == 'Tout' || (p['category'] ?? '') == _currentTopicFilter;
          bool matchSearch = true;
          if (_isSearching && _searchController.text.isNotEmpty) matchSearch = (p['content'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase());
          return matchCity && matchTopic && matchSearch;
        }).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 100), // Padding pour le menu du bas
          children: [
            // 1. LES FILTRES (Affichés uniquement si on ne cherche pas)
            if (!_isSearching) _buildFilterDropdowns(),

            // 2. RÉSULTATS RECHERCHE (Personnes)
            if (_isSearching && _foundProfiles.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24), child: Text("Personnes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _foundProfiles.length, itemBuilder: (context, index) {
                final profile = _foundProfiles[index];
                return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: profile['id']))), child: Container(width: 70, margin: const EdgeInsets.only(right: 15), child: Column(children: [CircleAvatar(radius: 28, backgroundImage: NetworkImage(profile['avatar_url'] ?? "https://i.pravatar.cc/150")), const SizedBox(height: 5), Text(profile['first_name'] ?? "User", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])));
              })),
              const Divider(height: 30),
            ],

            // 3. POSTS OU VIDE
            if (posts.isEmpty && _foundProfiles.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 50), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_none, size: 50, color: Colors.grey.shade300), const SizedBox(height: 15), Text(_isSearching ? "Aucun résultat." : "Rien pour $_currentTopicFilter à $_currentCityFilter.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))]))),
            
            // 4. LISTE DES POSTS
            ...posts.map((post) {
              return FutureBuilder<List<dynamic>>(
                future: Future.wait<dynamic>([
                  Supabase.instance.client.from('profiles').select().eq('id', post['user_id']).single(), 
                  Supabase.instance.client.from('comments').count().eq('post_id', post['id']), 
                  myId != null ? Supabase.instance.client.from('saved_posts').select().eq('user_id', myId).eq('post_id', post['id']).maybeSingle() : Future.value(null)
                ]),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox(); 
                  final author = Map<String, dynamic>.from(snap.data![0] as Map);
                  final commentsCount = snap.data![1] as int;
                  final isSaved = snap.data![2] != null;
                  final createdAt = DateTime.tryParse(post['created_at'].toString()) ?? DateTime.now();
                  final diff = DateTime.now().difference(createdAt);
                  String timeAgo = diff.inMinutes < 60 ? "${diff.inMinutes}m" : diff.inHours < 24 ? "${diff.inHours}h" : "${diff.inDays}j";
                  
                  String postId = post['id'].toString();
                  List<dynamic> dbLikes = post['liked_by'] ?? [];
                  bool isLikedDb = dbLikes.contains(myId);
                  
                  bool finalIsLiked = _optimisticLikes[postId] ?? isLikedDb;
                  int finalCount = _optimisticCounts[postId] ?? dbLikes.length;

                  return _buildV3PostCard(post, author, timeAgo, finalIsLiked, finalCount, commentsCount, isSaved, myId);
                },
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildV3PostCard(Map<String, dynamic> post, Map<String, dynamic> author, String timeAgo, bool isLiked, int likesCount, int commentsCount, bool isSaved, String? myId) {
    bool isMyPost = post['user_id'] == myId;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: author['first_name'], timeAgo: timeAgo))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), // Padding adapté
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 0.6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
                GestureDetector(onTap: () => isMyPost ? setState(()=>_selectedIndex=2) : Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: post['user_id']))), child: CircleAvatar(radius: 18, backgroundImage: NetworkImage(author['avatar_url'] ?? "https://i.pravatar.cc/150"), backgroundColor: Colors.grey.shade200)),
                const SizedBox(width: 10), Expanded(child: Text(author['first_name'] ?? "User", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _darkText))),
                Text(timeAgo, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)), const SizedBox(width: 10),
                IconButton(icon: const Icon(Icons.ios_share_rounded, size: 20, color: Colors.black), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () { final String contentToShare = "${author['first_name']} a posté sur NORA : \n\n\"${post['content']}\"\n\nRejoins la communauté ! 🍁"; Share.share(contentToShare); })
            ]),
            const SizedBox(height: 12), Text(post['content'] ?? "", style: TextStyle(fontSize: 15, color: _darkText, height: 1.4)),
            const SizedBox(height: 12),
            if (post['image_url'] != null && post['image_url'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post['image_url'], width: double.infinity, height: 250, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const SizedBox()))),
            Row(children: [
                GestureDetector(onTap: () => _toggleLike(post), child: Row(children: [Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 22, color: isLiked ? Colors.red : Colors.black), const SizedBox(width: 6), Text("$likesCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))])),
                const SizedBox(width: 20), Row(children: [const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.black), const SizedBox(width: 6), Text("$commentsCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
                const Spacer(), GestureDetector(onTap: () => _toggleSavePost(post['id']), child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 24, color: isSaved ? _creamyOrange : Colors.black)),
            ])
        ]),
      ),
    );
  }

  // --- MENU ---
  Widget _buildChatIconWithBadge() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Icon(Icons.chat_bubble_outline_rounded, size: 26);
    return StreamBuilder<List<Map<String, dynamic>>>(stream: Supabase.instance.client.from('messages').stream(primaryKey: ['id']), builder: (context, snapshot) {
        int unreadCount = 0; if (snapshot.hasData) unreadCount = snapshot.data!.where((m) => m['read_at'] == null && m['sender_id'] != user.id).length;
        IconData icon = _selectedIndex == 1 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded;
        Color color = _selectedIndex == 1 ? _creamyOrange : Colors.grey.shade600;
        if (unreadCount == 0) return Icon(icon, color: color, size: 26);
        return Stack(clipBehavior: Clip.none, children: [Icon(icon, color: color, size: 26), Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), constraints: const BoxConstraints(minWidth: 18, minHeight: 18), child: Text(unreadCount > 9 ? '9+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, extendBody: true, appBar: _buildAppBar(),
      body: IndexedStack(index: _selectedIndex, children: [ _buildFeed(), const ConversationsPage(), const ProfilePage() ]),
      bottomNavigationBar: Container(margin: const EdgeInsets.only(left: 24, right: 24, bottom: 34), height: 70, child: ClipRRect(borderRadius: BorderRadius.circular(40), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.75), border: Border.all(color: Colors.white.withOpacity(0.2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildNavItem(0, Icons.home_rounded, Icons.home_outlined), GestureDetector(onTap: () => setState(() => _selectedIndex = 1), child: Container(width: 50, height: 50, color: Colors.transparent, child: Center(child: _buildChatIconWithBadge()))), _buildNavItem(2, Icons.person_rounded, Icons.person_outline_rounded)]))))),
    );
  }
  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon) { bool isSelected = _selectedIndex == index; return GestureDetector(onTap: () => setState(() => _selectedIndex = index), child: Container(padding: const EdgeInsets.all(10), color: Colors.transparent, child: Icon(isSelected ? activeIcon : inactiveIcon, size: 28, color: isSelected ? _creamyOrange : Colors.grey.shade600))); }
}