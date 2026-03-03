import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateMessageModel {
  final String id;
  final String text;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final String chatId;
  final DateTime expiresAt;

  PrivateMessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.chatId,
    required this.expiresAt,
  });

  // Check if message is older than its expiration time
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Get formatted time remaining e.g "09:59"
  String get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return "00:00";
    
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  // Factory constructor for Firestore
  factory PrivateMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PrivateMessageModel(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
      chatId: data['chatId'] ?? '',
      expiresAt: data['expiresAt'] != null 
          ? (data['expiresAt'] as Timestamp).toDate() 
          : DateTime.now().add(const Duration(minutes: 1)),
    );
  }

  // Factory for Mock data
  factory PrivateMessageModel.mock(String text, String senderId, String receiverId) {
    // Generates a mock chatId
    final List<String> ids = [senderId, receiverId];
    ids.sort();
    final chatId = ids.join('_');
    
    return PrivateMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      senderId: senderId,
      receiverId: receiverId,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      chatId: chatId,
    );
  }
}
