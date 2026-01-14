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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Mes Messages', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Pas de flèche retour sur les onglets principaux
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // On récupère les conversations où JE suis impliqué (soit user1, soit user2)
        stream: Supabase.instance.client
            .from('conversations')
            .stream(primaryKey: ['id'])
            .order('updated_at', ascending: false), 
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Filtrage manuel car le stream .or() complexe est parfois capricieux en Flutter direct
          final allConversations = snapshot.data!;
          final myConversations = allConversations.where((c) {
            return c['user1_id'] == user!.id || c['user2_id'] == user!.id;
          }).toList();

          if (myConversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Aucune discussion pour le moment."),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: myConversations.length,
            itemBuilder: (context, index) {
              final conversation = myConversations[index];
              
              // Déterminer qui est l'autre personne
              final otherUserId = (conversation['user1_id'] == user!.id)
                  ? conversation['user2_id']
                  : conversation['user1_id'];

              // On doit récupérer les infos de l'autre personne (Nom, Avatar)
              // Pour simplifier l'affichage dans la liste, on utilise un FutureBuilder
              return FutureBuilder<Map<String, dynamic>>(
                future: Supabase.instance.client
                    .from('profiles')
                    .select()
                    .eq('id', otherUserId)
                    .single(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.grey),
                      title: Text("Chargement..."),
                    );
                  }
                  
                  final otherProfile = snapshot.data!;
                  final otherName = otherProfile['first_name'] ?? 'Utilisateur';
                  final otherAvatar = otherProfile['avatar_url'] ?? '';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: otherAvatar.isNotEmpty ? NetworkImage(otherAvatar) : null,
                        child: otherAvatar.isEmpty ? Text(otherName[0]) : null,
                      ),
                      title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        conversation['last_message'] ?? 'Nouvelle conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        // Ouvrir le chat
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              conversationId: conversation['id'],
                              otherUserName: otherName,
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