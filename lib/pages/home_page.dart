import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart'; 
import 'dart:ui'; 
import 'dart:async'; 
import '../widgets/nora_logo.dart'; 
import 'profile_page.dart';
import 'create_post_page.dart'; // ✅ Utilisé pour l'édition
import 'conversations_page.dart';
import 'post_details_page.dart';
import 'welcome_page.dart';
import 'other_profile_page.dart';
import 'housing_map_page.dart'; 
import 'all_housing_map_page.dart'; 

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

  // --- FILTRES ---
  String _currentCityFilter = "Montréal"; 
  String _currentTopicFilter = "Tout";

  final List<String> _cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa', 'Calgary', 'Edmonton', 'Winnipeg', 'Halifax', 'Victoria'];
  final List<String> _topics = ['Tout', '🏠 Logement', '💼 Emploi', '🍻 Sorties', '🆘 Entraide', '📢 Annonce'];

  // --- OPTIMISTIC UI ---
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

  // --- LIKE ---
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
      setState(() {
        _optimisticLikes.remove(postId);
        _optimisticCounts.remove(postId);
      });
    }
  }

  // --- FAVORIS ---
  Future<void> _toggleSavePost(int postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final existing = await Supabase.instance.client.from('saved_posts').select().eq('user_id', user.id).eq('post_id', postId).maybeSingle();
      if (existing == null) {
        await Supabase.instance.client.from('saved_posts').insert({'user_id': user.id, 'post_id': postId});
      } else {
        await Supabase.instance.client.from('saved_posts').delete().eq('user_id', user.id).eq('post_id', postId);
      }
      setState(() {}); 
    } catch (e) { debugPrint("Erreur favoris: $e"); }
  }

  // --- 🗑️ SUPPRIMER POST (Silencieux) ---
  Future<void> _deletePost(int postId) async {
    try {
      await Supabase.instance.client.from('posts').delete().eq('id', postId);
      // Pas de SnackBar, le Stream met à jour l'UI automatiquement
    } catch (e) {
      debugPrint("Erreur suppression: $e");
    }
  }

  // --- ⚙️ MENU OPTIONS (Design V3 - Popup Stylé) ---
  void _showPostOptions(Map<String, dynamic> post) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    bool isMyPost = post['user_id'] == myId;

    if (!isMyPost) return; 

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Pour avoir des coins arrondis flottants
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barre de drag
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 25),
              
              // Option Modifier
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CreatePostPage(postToEdit: post)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200)
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                        child: Icon(Icons.edit_rounded, color: Colors.blue.shade700, size: 22),
                      ),
                      const SizedBox(width: 15),
                      Text("Modifier le post", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkText)),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400)
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 15),

              // Option Supprimer
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context, 
                    builder: (ctx) => AlertDialog(
                      title: const Text("Supprimer ?"), 
                      content: const Text("Cette action est irréversible."),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      actions: [
                        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: (){ 
                            Navigator.pop(ctx); // Ferme l'alerte
                            Navigator.pop(context); // Ferme le menu
                            _deletePost(post['id']); 
                          }, 
                          child: const Text("Supprimer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        ),
                      ]
                    )
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade100)
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 15),
                      const Text("Supprimer le post", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
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
              child: SizedBox(height: 40, width: 120, child: FittedBox(fit: BoxFit.contain, child: const NoraLogo(size: 40))),
            ),
          ),
      actions: [
        if (!_isSearching) ...[
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.black, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => AllHousingMapPage(city: _currentCityFilter)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 28), 
            onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage())); setState(() {}); }
          ),
        ],
        const SizedBox(width: 12),
      ],
    );
  }

  // --- FILTRES ---
  Widget _buildFilterDropdowns() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.black, width: 0.6)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _cities.contains(_currentCityFilter) ? _currentCityFilter : _cities[0], isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                  style: TextStyle(color: _darkText, fontWeight: FontWeight.bold, fontSize: 14),
                  items: _cities.map((String city) => DropdownMenuItem<String>(value: city, child: Text(city, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (String? newValue) { if (newValue != null) setState(() => _currentCityFilter = newValue); },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12), 
          Expanded(
            child: Container(
              height: 45, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.black, width: 0.6)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _topics.contains(_currentTopicFilter) ? _currentTopicFilter : _topics[0], isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                  style: TextStyle(color: _darkText, fontWeight: FontWeight.bold, fontSize: 14),
                  items: _topics.map((String topic) => DropdownMenuItem<String>(value: topic, child: Text(topic, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (String? newValue) { if (newValue != null) setState(() => _currentTopicFilter = newValue); },
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
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            if (!_isSearching) _buildFilterDropdowns(),
            if (_isSearching && _foundProfiles.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 24), child: Text("Personnes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _foundProfiles.length, itemBuilder: (context, index) {
                final profile = _foundProfiles[index];
                return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: profile['id']))), child: Container(width: 70, margin: const EdgeInsets.only(right: 15), child: Column(children: [CircleAvatar(radius: 28, backgroundImage: NetworkImage(profile['avatar_url'] ?? "https://i.pravatar.cc/150")), const SizedBox(height: 5), Text(profile['first_name'] ?? "User", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])));
              })),
              const Divider(height: 30),
            ],
            if (posts.isEmpty && _foundProfiles.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 50), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.filter_none, size: 50, color: Colors.grey.shade300), const SizedBox(height: 15), Text(_isSearching ? "Aucun résultat." : "Rien pour $_currentTopicFilter à $_currentCityFilter.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500))]))),
            
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

  // --- POST CARD ---
  Widget _buildV3PostCard(Map<String, dynamic> post, Map<String, dynamic> author, String timeAgo, bool isLiked, int likesCount, int commentsCount, bool isSaved, String? myId) {
    bool isMyPost = post['user_id'] == myId; 
    bool hasLocation = post['category'] == '🏠 Logement' && post['latitude'] != null;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post, userName: author['first_name'], timeAgo: timeAgo))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 0.6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
                GestureDetector(onTap: () => isMyPost ? setState(()=>_selectedIndex=2) : Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfilePage(userId: post['user_id']))), child: CircleAvatar(radius: 18, backgroundImage: NetworkImage(author['avatar_url'] ?? "https://i.pravatar.cc/150"), backgroundColor: Colors.grey.shade200)),
                const SizedBox(width: 10), 
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author['first_name'] ?? "User", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _darkText)),
                    Text(timeAgo, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)), 
                  ],
                )),
                
                if (isMyPost) ...[
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => _showPostOptions(post),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.transparent, 
                      child: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade600),
                    ),
                  )
                ] else ...[
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, size: 20, color: Colors.black), 
                    padding: EdgeInsets.zero, 
                    constraints: const BoxConstraints(), 
                    onPressed: () { 
                      final String contentToShare = "${author['first_name']} a posté sur NORA : \n\n\"${post['content']}\"\n\nRejoins la communauté ! 🍁"; 
                      Share.share(contentToShare); 
                    }
                  )
                ]
            ]),

            const SizedBox(height: 12), 
            Text(post['content'] ?? "", style: TextStyle(fontSize: 15, color: _darkText, height: 1.4)),
            const SizedBox(height: 12),
            if (post['image_url'] != null && post['image_url'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post['image_url'], width: double.infinity, height: 250, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const SizedBox()))),
            
            if (hasLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HousingMapPage(post: post))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.map_rounded, color: Colors.blue.shade700, size: 20), const SizedBox(width: 8),
                        Text("Voir le logement sur la carte", style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 13)), const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.blue.shade300, size: 14),
                    ]),
                  ),
                ),
              ),

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