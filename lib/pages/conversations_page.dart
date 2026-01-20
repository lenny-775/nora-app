import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // COULEURS DESIGN SYSTEM
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
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Créer un groupe", style: TextStyle(fontWeight: FontWeight.bold, color: _darkText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: InputDecoration(hintText: "Nom (ex: Chill à Montréal)", filled: true, fillColor: _softGrey, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            TextField(controller: descController, decoration: InputDecoration(hintText: "Description (facultatif)", filled: true, fillColor: _softGrey, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _creamyOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            onPressed: () async {
              if (nameController.text.isNotEmpty && user != null) {
                try {
                  final res = await Supabase.instance.client.from('communities').insert({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'city': 'Monde', 
                  }).select().single();
                  
                  await Supabase.instance.client.from('community_members').insert({
                    'community_id': res['id'], 'user_id': user!.id
                  });

                  if (mounted) {
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                    setState(() {}); 
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
                }
              }
            },
            child: const Text("Créer", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- 2. MENU "+" (MODERNE) ---
  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              
              Text("Nouvelle discussion", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkText)),
              const SizedBox(height: 20),

              _buildMenuOption(
                icon: Icons.person_rounded, 
                title: "Message Privé", 
                subtitle: "Discuter avec un autre membre",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage()));
                }
              ),
              
              const SizedBox(height: 15),

              _buildMenuOption(
                icon: Icons.groups_rounded, 
                title: "Communauté / Groupe", 
                subtitle: "Rejoindre ou créer un groupe",
                onTap: () {
                  Navigator.pop(context);
                  _showGroupSelectionSheet();
                }
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _softGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: _creamyOrange),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400)
          ],
        ),
      ),
    );
  }

  // --- 3. SÉLECTION GROUPE ---
  void _showGroupSelectionSheet() {
    final cities = ['Montréal', 'Québec', 'Toronto', 'Vancouver', 'Ottawa'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text("Rejoindre un groupe", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _darkText)),
                  const SizedBox(height: 20),
                  
                  // Créer Nouveau
                  GestureDetector(
                    onTap: () {
                       Navigator.pop(context);
                       _showCreateGroupDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: _creamyOrange, width: 1.5),
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: _creamyOrange),
                          const SizedBox(width: 10),
                          Text("Créer mon propre groupe", style: TextStyle(color: _creamyOrange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.centerLeft, child: Text("Populaires", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: cities.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(color: _softGrey, borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(Icons.location_city_rounded, color: _creamyOrange, size: 20),
                            ),
                            title: Text("PVTistes ${cities[index]}", style: TextStyle(fontWeight: FontWeight.bold, color: _darkText)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _darkText, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0)
                              ),
                              onPressed: () async {
                                final comm = await Supabase.instance.client.from('communities').select().ilike('name', '%${cities[index]}%').maybeSingle();
                                if (comm != null && user != null) {
                                  try {
                                    await Supabase.instance.client.from('community_members').insert({'community_id': comm['id'], 'user_id': user!.id});
                                    if (mounted) {
                                      Navigator.pop(context);
                                      setState(() {});
                                    }
                                  } catch (e) {
                                    if (mounted) Navigator.pop(context);
                                  }
                                }
                              },
                              child: const Text("Rejoindre", style: TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      
      // APP BAR AVEC LE BOUTON "+"
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text("Messages", style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 26)),
        centerTitle: false,
        actions: [
          // BOUTON AJOUTER QUI OUVRE LE MENU
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: _showAddMenu, // <-- LANCE LA FONCTION DU MENU
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Icon(Icons.add_rounded, color: _creamyOrange, size: 28),
              ),
            ),
          )
        ],
      ),

      body: Column(
        children: [
          // --- 1. SEGMENTED CONTROL (SWITCH) ---
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]
            ),
            child: Row(
              children: [
                _buildSegmentButton(0, "Privé"),
                _buildSegmentButton(1, "Groupes"),
              ],
            ),
          ),

          // --- 2. LISTE ---
          Expanded(
            child: _currentTabIndex == 0 ? _buildPrivateChats() : _buildMyGroups(),
          ),
        ],
      ),
      
      // PLUS DE FLOATING ACTION BUTTON ICI !
    );
  }

  Widget _buildSegmentButton(int index, String text) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _creamyOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            text, 
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isSelected ? Colors.white : Colors.grey.shade500
            ),
          ),
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

        if (myConversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 50, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text("Aucune conversation", style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 80),
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

  // --- LISTE GROUPES ---
  Widget _buildMyGroups() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('community_members')
          .select('community_id, communities(id, name, description, image_url)')
          .eq('user_id', user!.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
        final memberships = snapshot.data!;
        
        if (memberships.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.groups_rounded, size: 50, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                Text("Aucun groupe rejoint", style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          itemCount: memberships.length,
          itemBuilder: (context, index) {
            final group = memberships[index]['communities'] as Map<String, dynamic>;
            return _buildTile(
              title: group['name'],
              subtitle: group['description'] ?? "Groupe",
              isGroup: true,
              img: group['image_url'],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommunityChatPage(communityId: group['id'], communityName: group['name']))),
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
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Marge comme sur le design
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), // Coins arrondis
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            // AVATAR
            Stack(
              children: [
                CircleAvatar(
                  radius: 28, 
                  backgroundColor: isGroup ? Colors.orange.shade50 : Colors.grey.shade200,
                  backgroundImage: img != null ? NetworkImage(img) : null, 
                  child: img == null ? Icon(isGroup ? Icons.groups_rounded : Icons.person_rounded, color: isGroup ? _creamyOrange : Colors.grey) : null
                ),
                if (unread > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(color: _creamyOrange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    ),
                  )
              ],
            ),
            const SizedBox(width: 15),
            
            // TEXTES
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _darkText)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: TextStyle(color: unread > 0 ? _darkText : Colors.grey.shade500, fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal)
                  ),
                ],
              ),
            ),
            
            // TEMPS & BADGE
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null && time.isNotEmpty) 
                  Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                    decoration: BoxDecoration(color: _creamyOrange, borderRadius: BorderRadius.circular(10)), 
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                  )
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}