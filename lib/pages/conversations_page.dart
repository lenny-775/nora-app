import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final User? user = Supabase.instance.client.auth.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text('Mes Messages', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFF8F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('conversations')
            .stream(primaryKey: ['id'])
            .order('updated_at', ascending: false), 
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
          }
          
          final allConversations = snapshot.data!;
          final myConversations = allConversations.where((c) {
            return c['user1_id'] == user!.id || c['user2_id'] == user!.id;
          }).toList();

          if (myConversations.isEmpty) {
            return const Center(child: Text("Aucune discussion pour le moment."));
          }

          return ListView.builder(
            itemCount: myConversations.length,
            itemBuilder: (context, index) {
              final conversation = myConversations[index];
              
              // Qui est l'autre ?
              final otherUserId = (conversation['user1_id'] == user!.id)
                  ? conversation['user2_id']
                  : conversation['user1_id'];

              return FutureBuilder<Map<String, dynamic>>(
                future: Supabase.instance.client
                    .from('profiles')
                    .select()
                    .eq('id', otherUserId)
                    .single(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink(); // Invisible tant que ça charge
                  }
                  
                  final otherProfile = snapshot.data!;
                  final otherName = otherProfile['first_name'] ?? 'Utilisateur';
                  final otherAvatar = otherProfile['avatar_url'];

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
                        child: otherAvatar == null ? Text(otherName[0]) : null,
                      ),
                      title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        conversation['last_message'] ?? '...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        // C'est ici que ça plantait avant : maintenant les arguments correspondent !
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              conversationId: conversation['id'],
                              receiverId: otherUserId,
                              receiverName: otherName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}