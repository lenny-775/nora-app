import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/nora_logo.dart'; // Import du logo
import 'chat_page.dart';
import 'community_chat_page.dart';
import 'search_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final User? user = Supabase.instance.client.auth.currentUser;
  int _currentTabIndex = 0; // 0 = Privé, 1 = Groupes

  // COULEURS V3
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _darkText = const Color(0xFF2D3436);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _softGrey = const Color(0xFFF4F6F8);

  String _formatTime(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) {
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.day}/${date.month}";
  }

  // --- 1. CRÉATION GROUPE ---
  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    String selectedPrivacy = 'public';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text("Nouveau Groupe", style: TextStyle(fontWeight: FontWeight.w900, color: _darkText)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController, 
                    decoration: InputDecoration(
                      hintText: "Nom du groupe", 
                      filled: true, 
                      fillColor: _softGrey, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                    )
                  ),
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.centerLeft, child: Text("Type d'accès", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 13))),
                  const SizedBox(height: 10),
                  
                  _buildRadioOption("Public", "Tout le monde peut rejoindre", 'public', selectedPrivacy, (val) => setDialogState(() => selectedPrivacy = val)),
                  _buildRadioOption("Sur invitation", "Visible mais fermé", 'invite', selectedPrivacy, (val) => setDialogState(() => selectedPrivacy = val)),
                  _buildRadioOption("Privé", "Secret (invisible)", 'private', selectedPrivacy, (val) => setDialogState(() => selectedPrivacy = val)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                  onPressed: () async {
                    if (nameController.text.isNotEmpty && user != null) {
                      try {
                        final res = await Supabase.instance.client.from('groups').insert({
                          'name': nameController.text.trim(),
                          'privacy': selectedPrivacy,
                          'creator_id': user!.id, 
                        }).select().single();
                        
                        await Supabase.instance.client.from('group_members').insert({
                          'group_id': res['id'], 'user_id': user!.id
                        });

                        if (mounted) { Navigator.pop(context); setState(() {}); }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
                      }
                    }
                  },
                  child: const Text("Créer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildRadioOption(String title, String subtitle, String value, String groupValue, Function(String) onChanged) {
    bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _creamyOrange.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _creamyOrange : Colors.transparent)
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? _creamyOrange : Colors.grey.shade400, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _darkText, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- REJOINDRE GROUPE ---
  Future<void> _joinGroup(int groupId, String groupName) async {
    try {
      await Supabase.instance.client.from('group_members').insert({'group_id': groupId, 'user_id': user!.id});
      if (mounted) {
        Navigator.pop(context); 
        setState(() {}); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tu as rejoint \"$groupName\" !")));
      }
    } catch (e) { if(mounted) Navigator.pop(context); }
  }

  // --- MENU "+" ---
  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text("Nouvelle discussion", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkText)),
              const SizedBox(height: 20),
              _buildMenuOption(Icons.person_rounded, "Message Privé", "Discuter avec un membre", () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage())); }),
              const SizedBox(height: 15),
              _buildMenuOption(Icons.groups_rounded, "Groupe", "Rejoindre ou créer", () { Navigator.pop(context); _showGroupSelectionSheet(); }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _softGrey, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: _creamyOrange)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText)), Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))])),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400)
          ],
        ),
      ),
    );
  }

  // --- SÉLECTION / REJOINDRE GROUPE (AVEC AUTO-CRÉATION DES VILLES) ---
  void _showGroupSelectionSheet() {
    final defaultCities = ['PVTistes Montréal', 'PVTistes Québec', 'PVTistes Toronto', 'PVTistes Vancouver', 'PVTistes Ottawa'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text("Rejoindre un groupe", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _darkText)),
                  const SizedBox(height: 20),
                  
                  GestureDetector(
                    onTap: _showCreateGroupDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: _creamyOrange, width: 1.5), borderRadius: BorderRadius.circular(25)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, color: _creamyOrange), const SizedBox(width: 10), Text("Créer mon propre groupe", style: TextStyle(color: _creamyOrange, fontWeight: FontWeight.bold, fontSize: 16))]),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  Align(alignment: Alignment.centerLeft, child: Text("Populaires", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14))),
                  const SizedBox(height: 15),

                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      // On charge les groupes publics. S'ils n'existent pas, on pourra les créer ici (logique simplifiée)
                      future: _fetchPublicGroups(defaultCities), 
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
                        final publicGroups = snapshot.data!;

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: publicGroups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final group = publicGroups[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: _softGrey, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                children: [
                                  Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.groups_2_rounded, color: _creamyOrange, size: 22)),
                                  const SizedBox(width: 15),
                                  Expanded(child: Text(group['name'], style: TextStyle(fontWeight: FontWeight.bold, color: _darkText, fontSize: 16))),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: _darkText, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), elevation: 0),
                                    onPressed: () => _joinGroup(group['id'], group['name']),
                                    child: const Text("Rejoindre", style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Fonction utilitaire pour récupérer (et créer si besoin) les groupes par défaut
  Future<List<Map<String, dynamic>>> _fetchPublicGroups(List<String> defaults) async {
    // 1. Récupérer les groupes publics existants
    final existing = await Supabase.instance.client.from('groups').select().eq('privacy', 'public');
    
    // 2. Vérifier s'il manque des villes par défaut (Montréal, etc.)
    // Note: Pour une vraie prod, on ferait ça via un script admin, mais ici c'est pratique pour tester
    for (String cityName in defaults) {
      if (!existing.any((g) => g['name'] == cityName)) {
        try {
          await Supabase.instance.client.from('groups').insert({
            'name': cityName,
            'privacy': 'public',
            'creator_id': user!.id // Créé par l'utilisateur courant (admin système temporaire)
          });
        } catch (e) {
          // Ignorer si erreur (déjà créé entre temps)
        }
      }
    }
    
    // 3. Re-fetch final
    return await Supabase.instance.client.from('groups').select().eq('privacy', 'public').order('created_at');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      
      // --- APP BAR V3 (LOGO CENTRÉ) ---
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Hero(
          tag: 'nora-logo-hero',
          child: Material(
            color: Colors.transparent,
            child: SizedBox(height: 35, width: 120, child: FittedBox(fit: BoxFit.contain, child: const NoraLogo(size: 35))),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 28),
              onPressed: _showAddMenu, 
            ),
          )
        ],
      ),

      body: Column(
        children: [
          // --- SEGMENTED CONTROL ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            padding: const EdgeInsets.all(4),
            height: 50,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.black, width: 0.6)), // Bordure fine V3
            child: Row(
              children: [
                _buildSegmentButton(0, "Privé"),
                _buildSegmentButton(1, "Groupes"),
              ],
            ),
          ),

          // --- LISTE ---
          Expanded(child: _currentTabIndex == 0 ? _buildPrivateChats() : _buildMyGroups()),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String text) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? _creamyOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade500, fontSize: 15)),
        ),
      ),
    );
  }

  // --- LISTE PRIVÉE ---
  Widget _buildPrivateChats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('conversations').stream(primaryKey: ['id']).order('updated_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final myConversations = snapshot.data!.where((c) => c['user1_id'] == user!.id || c['user2_id'] == user!.id).toList();

        if (myConversations.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline_rounded, size: 50, color: Colors.grey.shade300), const SizedBox(height: 10), Text("Aucune conversation", style: TextStyle(color: Colors.grey.shade500))]));

        return ListView.builder(
          padding: const EdgeInsets.only(top: 5, bottom: 80),
          itemCount: myConversations.length,
          itemBuilder: (context, index) {
            final conversation = myConversations[index];
            final otherUserId = (conversation['user1_id'] == user!.id) ? conversation['user2_id'] : conversation['user1_id'];

            return FutureBuilder<List<dynamic>>(
              future: Future.wait<dynamic>([
                Supabase.instance.client.from('profiles').select().eq('id', otherUserId).single(),
                Supabase.instance.client.from('messages').select('id, read_at').eq('conversation_id', conversation['id']).eq('sender_id', otherUserId)
              ]),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final profile = snap.data![0] as Map<String, dynamic>;
                final messages = snap.data![1] as List<dynamic>;
                final unreadCount = messages.where((m) => m['read_at'] == null).length;

                return _buildTile(
                  title: profile['first_name'] ?? 'Utilisateur',
                  subtitle: conversation['last_message'] ?? '...',
                  img: profile['avatar_url'],
                  time: conversation['updated_at'] != null ? _formatTime(conversation['updated_at']) : '',
                  unread: unreadCount,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(conversationId: conversation['id'], receiverId: otherUserId, receiverName: profile['first_name']))),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- LISTE MES GROUPES ---
  Widget _buildMyGroups() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client.from('group_members').select('group_id, groups(id, name, privacy)').eq('user_id', user!.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final memberships = snapshot.data!;
        
        if (memberships.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.groups_rounded, size: 50, color: Colors.grey.shade300), const SizedBox(height: 10), Text("Aucun groupe rejoint", style: TextStyle(color: Colors.grey.shade500))]));

        return ListView.builder(
          padding: const EdgeInsets.only(top: 5, bottom: 80),
          itemCount: memberships.length,
          itemBuilder: (context, index) {
            final groupData = memberships[index]['groups'] as Map<String, dynamic>;
            return _buildTile(
              title: groupData['name'],
              subtitle: groupData['privacy'] == 'public' ? "Public" : "Privé",
              isGroup: true,
              img: null, 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommunityChatPage(communityId: groupData['id'], communityName: groupData['name']))),
            );
          },
        );
      },
    );
  }

  Widget _buildTile({required String title, required String subtitle, String? img, String? time, int unread = 0, bool isGroup = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), 
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black, width: 0.6)), // Bordure V3
        child: Row(
          children: [
            CircleAvatar(
              radius: 26, 
              backgroundColor: isGroup ? Colors.orange.shade50 : Colors.grey.shade200,
              backgroundImage: img != null ? NetworkImage(img) : null, 
              child: img == null ? Icon(isGroup ? Icons.groups_rounded : Icons.person_rounded, color: isGroup ? _creamyOrange : Colors.grey) : null
            ),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _darkText)), const SizedBox(height: 4), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? _darkText : Colors.grey.shade500, fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal))])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (time != null && time.isNotEmpty) Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold)), if (unread > 0) ...[const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _creamyOrange, borderRadius: BorderRadius.circular(10)), child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]]),
          ],
        ),
      ),
    );
  }
}