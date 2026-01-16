import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final int conversationId;
  final String receiverId;
  final String receiverName;
  final Map<String, dynamic>? pendingPost; // NOUVEAU : Le post qu'on veut partager

  const ChatPage({
    super.key, 
    required this.conversationId, 
    required this.receiverId,
    required this.receiverName,
    this.pendingPost, // Optionnel
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser!.id;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  
  // Variable pour stocker le post en "pièce jointe" temporaire
  Map<String, dynamic>? _attachedPost;

  @override
  void initState() {
    super.initState();
    // Si on arrive depuis la Home avec un post, on le met en pièce jointe
    if (widget.pendingPost != null) {
      _attachedPost = widget.pendingPost;
    }
    _updateMyLastSeen();
    _markMessagesAsRead();
  }

  Future<void> _updateMyLastSeen() async {
    await Supabase.instance.client
        .from('profiles')
        .update({'last_seen': DateTime.now().toIso8601String()})
        .eq('id', _myId);
  }

  Future<void> _markMessagesAsRead() async {
    await Supabase.instance.client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', widget.conversationId)
        .eq('sender_id', widget.receiverId)
        .filter('read_at', 'is', null);
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    // On peut envoyer si : Texte pas vide OU Image pas vide OU Post attaché
    if ((text == null || text.trim().isEmpty) && imageUrl == null && _attachedPost == null) return;
    
    _controller.clear();
    
    // On sauvegarde le post attaché localement pour l'envoi, puis on vide l'interface
    final postToSend = _attachedPost;
    setState(() {
      _attachedPost = null; // On enlève la preview
    });

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _myId,
        'content': text,
        'image_url': imageUrl,
        'post_share_id': postToSend?['id'], // On ajoute l'ID du post si présent
      });

      String lastMsgPreview = text ?? (imageUrl != null ? "📷 Photo" : "🔗 Post partagé");
      if (text != null && text.isEmpty) lastMsgPreview = (imageUrl != null ? "📷 Photo" : "🔗 Post partagé");

      await Supabase.instance.client.from('conversations').update({
        'last_message': lastMsgPreview,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.conversationId);
      
      _updateMyLastSeen();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploading = true);
      final Uint8List imageBytes = await image.readAsBytes();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final String path = 'chat_images/$fileName';

      await Supabase.instance.client.storage
          .from('chat-uploads')
          .uploadBinary(path, imageBytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));

      final imageUrl = Supabase.instance.client.storage
          .from('chat-uploads')
          .getPublicUrl(path);

      await _sendMessage(text: null, imageUrl: imageUrl);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur upload: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatTime(String createdAt) {
    final date = DateTime.parse(createdAt).toLocal();
    return DateFormat('HH:mm').format(date);
  }

  String _formatLastSeen(String? lastSeenStr) {
    if (lastSeenStr == null) return "Hors ligne";
    final lastSeen = DateTime.parse(lastSeenStr).toLocal();
    final difference = DateTime.now().difference(lastSeen);
    if (difference.inMinutes < 5) return "En ligne";
    if (difference.inDays == 0) return "Vu à ${DateFormat('HH:mm').format(lastSeen)}";
    return "Vu le ${DateFormat('dd/MM').format(lastSeen)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(
          children: [
            Text(widget.receiverName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            StreamBuilder<Map<String, dynamic>>(
              stream: Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('id', widget.receiverId).map((e) => e.first),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return Text(_formatLastSeen(snapshot.data!['last_seen']), style: const TextStyle(color: Colors.green, fontSize: 12));
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. LA LISTE DES MESSAGES
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('conversation_id', widget.conversationId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
                
                if (snapshot.data!.isNotEmpty) {
                  final lastMsg = snapshot.data!.first;
                  if (lastMsg['sender_id'] != _myId && lastMsg['read_at'] == null) {
                    Future.microtask(() => _markMessagesAsRead());
                  }
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) return Center(child: Text("Dites bonjour à ${widget.receiverName} 👋"));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    final String? imageUrl = msg['image_url'];
                    final int? postShareId = msg['post_share_id'];
                    final String? readAt = msg['read_at'];
                    
                    String statusText = "";
                    if (isMe) statusText = (readAt == null) ? "Distribué" : "Vu à ${_formatTime(readAt)}";

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: (imageUrl != null || postShareId != null) 
                                ? const EdgeInsets.all(5) 
                                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isMe ? const LinearGradient(colors: [Color(0xFFFFA07A), Color(0xFFFF6B00)]) : null,
                              color: isMe ? null : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imageUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.network(imageUrl, width: 200, fit: BoxFit.cover),
                                  ),
                                
                                // --- AFFICHAGE D'UN POST DÉJÀ ENVOYÉ DANS L'HISTORIQUE ---
                                if (postShareId != null)
                                  FutureBuilder<Map<String, dynamic>>(
                                    future: Supabase.instance.client.from('posts').select().eq('id', postShareId).single(),
                                    builder: (context, postSnap) {
                                      if (!postSnap.hasData) return const SizedBox(width: 200, height: 60, child: Center(child: CircularProgressIndicator()));
                                      final post = postSnap.data!;
                                      return Container(
                                        width: 220,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(isMe ? 0.9 : 1.0),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.share, size: 16, color: Colors.orange),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text("Post partagé • ${post['city']}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(post['content'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),

                                if (msg['content'] != null && msg['content'].toString().isNotEmpty)
                                  Padding(
                                    padding: (imageUrl != null || postShareId != null) ? const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 4) : EdgeInsets.zero,
                                    child: Text(msg['content'], style: TextStyle(color: isMe ? Colors.white : const Color(0xFF2D3436), fontSize: 16)),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, right: 5, left: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_formatTime(msg['created_at']), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                if (isMe) ...[
                                  const SizedBox(width: 5),
                                  Text("• $statusText", style: TextStyle(color: readAt != null ? Colors.blue.shade300 : Colors.grey.shade400, fontSize: 10, fontWeight: readAt != null ? FontWeight.bold : FontWeight.normal)),
                                  if (readAt != null) Icon(Icons.done_all, size: 12, color: Colors.blue.shade300)
                                ]
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
          ),

          // 2. ZONE DE SAISIE (AVEC PRÉVISUALISATION DU POST)
          SafeArea(
            child: Container(
              color: const Color(0xFFFFF8F5),
              child: Column(
                children: [
                  // --- ZONE DE "PRÉVISUALISATION" DU POST EN ATTENTE ---
                  if (_attachedPost != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFFF6B00), width: 1), // Bordure orange pour dire "C'est prêt"
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.share, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Partager le post de ${_attachedPost!['city']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                Text(
                                  _attachedPost!['content'] ?? "", 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          // Bouton Croix pour annuler le partage
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _attachedPost = null;
                              });
                            },
                          )
                        ],
                      ),
                    ),

                  // --- BARRE DE SAISIE CLASSIQUE ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: _isUploading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.image_outlined, color: Colors.grey, size: 28),
                          onPressed: _isUploading ? null : _pickAndUploadImage,
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                            child: TextField(
                              controller: _controller,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: _attachedPost != null ? "Ajouter un message..." : "Écrivez votre message...", // Texte change si post
                                hintStyle: TextStyle(color: Colors.grey.shade400), 
                                border: InputBorder.none, 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                              ),
                              onTap: () { _updateMyLastSeen(); _markMessagesAsRead(); },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _sendMessage(text: _controller.text.trim()),
                          child: Container(
                            padding: const EdgeInsets.all(12), 
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFFA07A), Color(0xFFFF6B00)])), 
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 24)
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}