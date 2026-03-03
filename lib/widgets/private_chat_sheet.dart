import 'dart:async';
import 'package:flutter/material.dart';
import '../models/private_message_model.dart';
import '../services/firebase_service.dart';
import '../utils/content_filter.dart';

class PrivateChatSheet extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUserNickname;
  final String otherUserAvatar;
  final FirebaseService firebaseService;

  const PrivateChatSheet({
    Key? key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserNickname,
    required this.otherUserAvatar,
    required this.firebaseService,
  }) : super(key: key);

  @override
  State<PrivateChatSheet> createState() => _PrivateChatSheetState();
}

class _PrivateChatSheetState extends State<PrivateChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Optimistic messages list for instant UI feedback
  final List<PrivateMessageModel> _optimisticMessages = [];
  
  Timer? _countdownTimer;

  // A reference to the latest list of real messages from Firebase
  List<PrivateMessageModel> _latestRealMessages = [];

  @override
  void initState() {
    super.initState();
    // Start a timer to force a redraw every second so counters tick down
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {}); // Redraw the UI
        
        // Cleanup expired optimistic messages just in case
        _optimisticMessages.removeWhere((msg) => msg.isExpired);
        
        // Force physical deletion from Firebase of any expired real messages we see
        // This is a collaborative cleanup where any active user helps keep the DB clean
        for (var msg in _latestRealMessages) {
          if (msg.isExpired) {
            widget.firebaseService.deletePrivateMessage(msg.chatId, msg.id);
          }
        }
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (ContentFilter.containsBannedWords(text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ContentFilter.getErrorMessage()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    _messageController.clear();

    // Optimistic UI update
    setState(() {
      _optimisticMessages.insert(0, PrivateMessageModel.mock(
        text,
        widget.currentUserId,
        widget.otherUserId,
      ));
    });

    // Send to Firebase
    await widget.firebaseService.sendPrivateMessage(
      text,
      widget.currentUserId,
      widget.otherUserId,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen height to make bottom sheet responsive
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.7, // Take 70% of screen height
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Text(
                  widget.otherUserAvatar,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUserNickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Text(
                        'Chat Privado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: StreamBuilder<List<PrivateMessageModel>>(
              stream: widget.firebaseService.getPrivateMessages(
                widget.currentUserId,
                widget.otherUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar mensajes'));
                }

                if (snapshot.connectionState == ConnectionState.waiting && 
                    !snapshot.hasData && 
                    _optimisticMessages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Combine real messages and optimistic ones 
                // We assume snapshot data is descending (newest first based on our query)
                List<PrivateMessageModel> realMessages = snapshot.data ?? [];
                
                // Keep reference for background deletion task
                _latestRealMessages = realMessages;
                
                // Filter out optimistic messages that have been confirmed in Firebase
                final currentOptimistic = _optimisticMessages.where((opt) => 
                  !realMessages.any((rm) => 
                    rm.text == opt.text && 
                    rm.senderId == opt.senderId &&
                    rm.timestamp.difference(opt.timestamp).inSeconds.abs() < 5
                  )
                ).toList();

                // Build full list of messages to display (all descending)
                final List<PrivateMessageModel> displayMessages = [
                  ...currentOptimistic,
                  ...realMessages
                ];

                if (displayMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Inicia una conversación con ${widget.otherUserNickname}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Start from bottom
                  padding: const EdgeInsets.all(16),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final msg = displayMessages[index];
                    final isMe = msg.senderId == widget.currentUserId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(widget.otherUserAvatar, style: const TextStyle(fontSize: 16)),
                            ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.deepPurple : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                                  bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.text,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Live Countdown Timer
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 10,
                                        color: isMe ? Colors.white70 : Colors.black54,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        msg.timeRemaining,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isMe ? Colors.white70 : Colors.black54,
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
                  },
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
