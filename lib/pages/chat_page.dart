import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isLoading = true; 
  
  late int _realConversationId; 
  Map<String, dynamic>? _attachedPost;
  String? _receiverAvatarUrl;

  late final RealtimeChannel _typingChannel;
  bool _isReceiverTyping = false;
  Timer? _typingTimer;

  final Color _creamyOrange = const Color(0xFFFF914D);
  final Color _backgroundColor = const Color(0xFFFFF8F5);
  final Color _darkText = const Color(0xFF2D3436);

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    if (widget.pendingPost != null) _attachedPost = widget.pendingPost;
    _realConversationId = widget.conversationId;
    _initChat();
  }

  Future<void> _initChat() async {
    await _fetchReceiverProfile();
    await _findTrueConversationId(); 
    await _markMessagesAsRead();     
    _setupTypingIndicator();
    _updateMyLastSeen();
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _findTrueConversationId() async {
    try {
      final data = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .or('and(user1_id.eq.$_myId,user2_id.eq.${widget.receiverId}),and(user1_id.eq.${widget.receiverId},user2_id.eq.$_myId)')
          .maybeSingle();

      if (data != null && mounted) {
        setState(() => _realConversationId = data['id']);
      }
    } catch (e) {
      debugPrint("Erreur recherche ID: $e");
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _setupTypingIndicator() {
    // Utilisation d'un ID temporaire si pas encore de conv pour éviter crash channel
    final channelId = _realConversationId != 0 ? _realConversationId : 'new_${widget.receiverId}';
    _typingChannel = Supabase.instance.client.channel('typing_$channelId');
    _typingChannel
        .onBroadcast(event: 'typing', callback: (payload) {
          final userId = payload['user_id'];
          final isTyping = payload['is_typing'];
          if (userId == widget.receiverId && mounted) {
            setState(() => _isReceiverTyping = isTyping);
          }
        })
        .subscribe();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_controller.text.isNotEmpty) {
      _sendTypingStatus(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () => _sendTypingStatus(false));
    } else {
      _sendTypingStatus(false);
    }
  }

  Future<void> _sendTypingStatus(bool isTyping) async {
    try {
      await _typingChannel.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': _myId, 'is_typing': isTyping},
      );
    } catch (_) {}
  }

  Future<void> _fetchReceiverProfile() async {
    try {
      final data = await Supabase.instance.client.from('profiles').select('avatar_url').eq('id', widget.receiverId).maybeSingle();
      if (mounted && data != null) setState(() => _receiverAvatarUrl = data['avatar_url']);
    } catch (_) {}
  }

  Future<void> _updateMyLastSeen() async {
    try { await Supabase.instance.client.from('profiles').update({'last_seen': DateTime.now().toIso8601String()}).eq('id', _myId); } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('sender_id', widget.receiverId) 
          .eq('receiver_id', _myId)           
          .filter('read_at', 'is', null);     
    } catch (e) {
      debugPrint("Erreur lecture: $e");
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> msg) async {
    try {
      final messageId = msg['id'];
      List<dynamic> currentLikes = List.from(msg['liked_by'] ?? []);
      if (currentLikes.contains(_myId)) currentLikes.remove(_myId); else currentLikes.add(_myId);
      await Supabase.instance.client.from('messages').update({'liked_by': currentLikes}).eq('id', messageId);
    } catch (e) { debugPrint("Erreur like: $e"); }
  }

  // --- C'EST ICI QUE LA MAGIE OPÈRE POUR CORRIGER LE BUG ---
  Future<void> _sendMessage({String? text, String? imageUrl, String? audioUrl}) async {
    if ((text == null || text.trim().isEmpty) && imageUrl == null && audioUrl == null && _attachedPost == null) return;
    
    // 1. Si la conversation n'existe pas encore (ID = 0), on la crée MAINTENANT
    if (_realConversationId == 0) {
      try {
        final newConv = await Supabase.instance.client
            .from('conversations')
            .insert({
              'user1_id': _myId,
              'user2_id': widget.receiverId,
              'last_message': text ?? "Nouveau message", // Valeur par défaut
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        
        setState(() {
          _realConversationId = newConv['id'];
        });
        debugPrint("✅ Conversation créée : $_realConversationId");
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur création chat: $e")));
        return; // On arrête si on n'a pas pu créer la conv
      }
    }

    // 2. Maintenant on est sûr d'avoir un ID valide, on envoie le message
    _sendTypingStatus(false);
    _typingTimer?.cancel();
    _controller.clear();
    final postToSend = _attachedPost;
    setState(() => _attachedPost = null);

    String type = 'text';
    if (postToSend != null) type = 'post_share';
    else if (imageUrl != null) type = 'image';
    else if (audioUrl != null) type = 'audio';

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': _realConversationId, // Ici ce ne sera jamais 0
        'sender_id': _myId,
        'receiver_id': widget.receiverId,
        'content': audioUrl ?? imageUrl ?? text,
        'post_data': postToSend,
        'type': type,
        'liked_by': [],
      });

      String lastMsgPreview = type == 'text' ? text! : (type == 'image' ? "📷 Photo" : "🎤 Vocal");
      
      // Mise à jour du dernier message
      await Supabase.instance.client.from('conversations').update({
        'last_message': lastMsgPreview, 
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', _realConversationId);
      
      _updateMyLastSeen();
      _scrollDown();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur envoi: $e")));
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (image == null) return;
      setState(() => _isUploading = true);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$_myId.${image.name.split('.').last}';
      await Supabase.instance.client.storage.from('chat_images').uploadBinary(fileName, await image.readAsBytes(), fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      final url = Supabase.instance.client.storage.from('chat_images').getPublicUrl(fileName);
      await _sendMessage(imageUrl: url);
    } catch (_) {} finally { if(mounted) setState(() => _isUploading = false); }
  }

  Future<void> _toggleRecording() async {
    if (kIsWeb) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vocaux dispos sur mobile 📱"))); return; }
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);
        if (path != null) {
          setState(() => _isUploading = true);
          final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}_$_myId.m4a';
          await Supabase.instance.client.storage.from('chat_images').uploadBinary(fileName, await File(path).readAsBytes(), fileOptions: const FileOptions(contentType: 'audio/m4a', upsert: true));
          final url = Supabase.instance.client.storage.from('chat_images').getPublicUrl(fileName);
          await _sendMessage(audioUrl: url);
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          await _audioRecorder.start(const RecordConfig(), path: '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a');
          setState(() => _isRecording = true);
        } else { await Permission.microphone.request(); }
      }
    } catch (_) {} finally { if(mounted) setState(() => _isUploading = false); }
  }

  void _scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.minScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _formatTime(String createdAt) {
    return DateFormat('HH:mm').format(DateTime.parse(createdAt).toLocal());
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
          onPressed: () => Navigator.pop(context)
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _receiverAvatarUrl != null ? NetworkImage(_receiverAvatarUrl!) : null,
              backgroundColor: Colors.grey.shade300,
              child: _receiverAvatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName, style: TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 16)), 
                if (_isReceiverTyping)
                   Text("écrit...", style: TextStyle(color: _creamyOrange, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))
                else
                   StreamBuilder<List<Map<String, dynamic>>>(
                     stream: Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('id', widget.receiverId), 
                     builder: (context, snapshot) { 
                       if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink(); 
                       return Text(
                         _formatLastSeen(snapshot.data!.first['last_seen']), 
                         style: TextStyle(color: Colors.grey.shade600, fontSize: 11)
                       ); 
                     }
                   )
              ],
            ),
          ],
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: _creamyOrange)) 
        : Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // 🔒 VERROU SUPABASE : Uniquement les messages de cette conversation
              stream: Supabase.instance.client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('conversation_id', _realConversationId)
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
                    final String type = msg['type'] ?? 'text';
                    final String content = msg['content'] ?? '';
                    final Map<String, dynamic>? postData = msg['post_data']; 
                    final String? readAt = msg['read_at'];
                    final String time = _formatTime(msg['created_at']);
                    final bool isLiked = (msg['liked_by'] ?? []).contains(_myId);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade300, backgroundImage: _receiverAvatarUrl != null ? NetworkImage(_receiverAvatarUrl!) : null, child: _receiverAvatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onDoubleTap: () => _toggleLike(msg),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: (type == 'image' || type == 'audio' || postData != null) ? const EdgeInsets.all(5) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isMe ? _creamyOrange : Colors.white,
                                          borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(5), bottomRight: isMe ? const Radius.circular(5) : const Radius.circular(20)),
                                          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (type == 'image') ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(content, width: 200, fit: BoxFit.cover)),
                                            if (postData != null) Container(width: 220, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.share_rounded, size: 14, color: _creamyOrange), const SizedBox(width: 5), const Expanded(child: Text("Post partagé", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)))]), const SizedBox(height: 5), Text(postData['content'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 13))])),
                                            if (type == 'audio') _AudioPlayerBubble(url: content, isMe: isMe),
                                            if (type == 'text' && content.isNotEmpty) Text(content, style: TextStyle(color: isMe ? Colors.white : _darkText, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                      if (isLiked) Positioned(bottom: -8, right: isMe ? null : -5, left: isMe ? -5 : null, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)]), child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 14)))
                                    ],
                                  ),
                                ),
                                Padding(padding: const EdgeInsets.only(top: 4, left: 2, right: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)), if (isMe) ...[const SizedBox(width: 4), if (readAt != null) Text("Vu", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _creamyOrange)) else const Icon(Icons.check, size: 12, color: Colors.grey)]])),
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
          
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(35), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  if (_attachedPost != null) Container(margin: const EdgeInsets.fromLTRB(16, 16, 16, 0), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _creamyOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.share_rounded, color: _creamyOrange), const SizedBox(width: 12), Expanded(child: Text(_attachedPost!['content'] ?? "Post", maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => setState(() => _attachedPost = null))])),
                  Row(children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _isRecording ? Colors.redAccent : _creamyOrange.withOpacity(0.1), shape: BoxShape.circle),
                        child: _isUploading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                          : Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: _isRecording ? Colors.white : _creamyOrange, size: 24),
                      ),
                      onPressed: _isUploading ? null : _toggleRecording,
                    ),
                    IconButton(icon: Icon(Icons.photo_camera_rounded, color: Colors.grey.shade400), onPressed: _isUploading || _isRecording ? null : _pickAndUploadImage),
                    Expanded(child: TextField(controller: _controller, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: _isRecording ? "Enregistrement..." : "Message...", hintStyle: TextStyle(color: _isRecording ? Colors.redAccent : Colors.grey.shade400), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14)), onTap: () { _updateMyLastSeen(); _markMessagesAsRead(); })),
                    Padding(padding: const EdgeInsets.only(right: 8.0), child: IconButton(icon: Icon(Icons.send_rounded, color: _creamyOrange), onPressed: () => _sendMessage(text: _controller.text.trim()))),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioPlayerBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const _AudioPlayerBubble({required this.url, required this.isMe});
  @override
  State<_AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}

class _AudioPlayerBubbleState extends State<_AudioPlayerBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  @override
  void dispose() { _player.dispose(); super.dispose(); }
  Future<void> _togglePlay() async { if (_isPlaying) { await _player.pause(); } else { await _player.play(UrlSource(widget.url)); } }
  @override
  void initState() { super.initState(); _player.onPlayerStateChanged.listen((state) { if(mounted) setState(() => _isPlaying = state == PlayerState.playing); }); }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          IconButton(icon: Icon(_isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: widget.isMe ? Colors.white : const Color(0xFFFF914D), size: 35), onPressed: _togglePlay),
          Expanded(child: Container(height: 4, decoration: BoxDecoration(color: widget.isMe ? Colors.white54 : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(width: 10),
          Text("Audio", style: TextStyle(color: widget.isMe ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}