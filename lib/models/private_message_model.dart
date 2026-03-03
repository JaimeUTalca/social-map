import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateMessageModel {
  final String id;
  final String text;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final String chatId;

  PrivateMessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.chatId,
  });

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
    );
  }

  // Factory for Mock data/optimistic UI
  factory PrivateMessageModel.mock(String text, String senderId, String receiverId) {
    // Generate consistant chat ID regardless of who sends
    final ids = [senderId, receiverId]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    
    return PrivateMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      senderId: senderId,
      receiverId: receiverId,
      timestamp: DateTime.now(),
      chatId: chatId,
    );
  }
}
