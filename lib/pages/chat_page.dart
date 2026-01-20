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
  final Map<String, dynamic>? pendingPost;

  const ChatPage({
    super.key, 
    required this.conversationId, 
    required this.receiverId,
    required this.receiverName,
    this.pendingPost, 
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _myId = Supabase.instance.client.auth.currentUser!.id;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  
  Map<String, dynamic>? _attachedPost;
  String? _receiverAvatarUrl; // Pour stocker la photo de l'autre

  // --- COULEURS STRICTES (RETOUR AU ORANGE) ---
  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    if (widget.pendingPost != null) {
      _attachedPost = widget.pendingPost;
    }
    _fetchReceiverProfile(); // On récupère l'avatar tout de suite
    _updateMyLastSeen();
    _markMessagesAsRead();
  }

  // Récupérer la photo de l'autre personne
  Future<void> _fetchReceiverProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', widget.receiverId)
          .single();
      if (mounted) {
        setState(() {
          _receiverAvatarUrl = data['avatar_url'];
        });
      }
    } catch (_) {}
  }

  Future<void> _updateMyLastSeen() async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('id', _myId);
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()}) 
          .eq('conversation_id', widget.conversationId)
          .neq('sender_id', _myId) 
          .filter('read_at', 'is', null); 
    } catch (e) {
      debugPrint("Erreur de lecture: $e");
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    if ((text == null || text.trim().isEmpty) && imageUrl == null && _attachedPost == null) return;
    
    _controller.clear();
    final postToSend = _attachedPost;
    setState(() {
      _attachedPost = null; 
    });

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _myId,
        'content': text,
        'image_url': imageUrl,
        'post_data': postToSend,
        'type': postToSend != null ? 'post_share' : (imageUrl != null ? 'image' : 'text'),
      });

      String lastMsgPreview = text ?? (imageUrl != null ? "📷 Photo" : "🔗 Post partagé");
      if (text != null && text.isEmpty) lastMsgPreview = (imageUrl != null ? "📷 Photo" : "🔗 Post partagé");

      await Supabase.instance.client.from('conversations').update({
        'last_message': lastMsgPreview,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.conversationId);
      
      _updateMyLastSeen();
      _scrollDown();

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur upload image")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
      backgroundColor: _backgroundColor, 
      
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(widget.receiverName, style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 18)),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('id', widget.receiverId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                return Text(_formatLastSeen(snapshot.data!.first['last_seen']), style: TextStyle(color: Colors.grey.shade600, fontSize: 12));
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // 1. LISTE DES MESSAGES
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('conversation_id', widget.conversationId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _creamyOrange));
                
                final messages = snapshot.data!;
                
                if (messages.isNotEmpty) {
                  final lastMsg = messages.first;
                  if (lastMsg['sender_id'] != _myId && lastMsg['read_at'] == null) {
                    Future.delayed(Duration.zero, () => _markMessagesAsRead());
                  }
                }

                if (messages.isEmpty) return const Center(child: Text("Dites bonjour ! 👋", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, 
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    final String? imageUrl = msg['image_url'];
                    final Map<String, dynamic>? postData = msg['post_data']; 
                    final String? readAt = msg['read_at'];
                    final String time = _formatTime(msg['created_at']);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // --- AVATAR DE L'AUTRE (REMIS EN PLACE) ---
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _receiverAvatarUrl != null ? NetworkImage(_receiverAvatarUrl!) : null,
                              child: _receiverAvatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 8),
                          ],

                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: (imageUrl != null || postData != null) 
                                      ? const EdgeInsets.all(5) 
                                      : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    // REVENU AU ORANGE CRÈME POUR MOI
                                    color: isMe ? _creamyOrange : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(5),
                                      bottomRight: isMe ? const Radius.circular(5) : const Radius.circular(20),
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // IMAGE
                                      if (imageUrl != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Image.network(imageUrl, width: 200, fit: BoxFit.cover),
                                        ),
                                      
                                      // POST PARTAGÉ
                                      if (postData != null)
                                        Container(
                                          width: 220,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.share_rounded, size: 14, color: _creamyOrange),
                                                  const SizedBox(width: 5),
                                                  const Expanded(child: Text("Post partagé", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Text(postData['content'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                            ],
                                          ),
                                        ),

                                      // TEXTE
                                      if (msg['content'] != null && msg['content'].toString().isNotEmpty)
                                        Text(
                                          msg['content'], 
                                          style: TextStyle(
                                            color: isMe ? Colors.white : _darkText, 
                                            fontSize: 16,
                                          )
                                        ),
                                    ],
                                  ),
                                ),
                                
                                // --- LE "VU" (REMIS EN PLACE) ---
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        // LE STATUT VU
                                        if (readAt != null)
                                          Text("Vu", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _creamyOrange))
                                        else
                                          const Icon(Icons.check, size: 12, color: Colors.grey),
                                      ]
                                    ],
                                  ),
                                )
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

          // 2. ZONE DE SAISIE FLOTTANTE
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  if (_attachedPost != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _creamyOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, color: _creamyOrange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_attachedPost!['content'] ?? "Post", maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.grey),
                            onPressed: () => setState(() => _attachedPost = null),
                          )
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      // BOUTON "+"
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: _creamyOrange.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.add_rounded, color: _creamyOrange, size: 24),
                        ),
                        onPressed: _isUploading ? null : _pickAndUploadImage,
                      ),
                      
                      // CHAMP TEXTE
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: "Message...",
                            hintStyle: TextStyle(color: Colors.grey.shade400), 
                            border: InputBorder.none, 
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14)
                          ),
                          onTap: () { 
                            _updateMyLastSeen(); 
                            _markMessagesAsRead(); 
                          },
                        ),
                      ),
                      
                      // BOUTON ENVOYER
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconButton(
                          icon: Icon(Icons.send_rounded, color: _creamyOrange),
                          onPressed: () => _sendMessage(text: _controller.text.trim()),
                        ),
                      ),
                    ],
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