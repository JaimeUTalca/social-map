import 'package:cloud_firestore/cloud_firestore.dart';
import 'latlng.dart';

class MessageModel {
  final String id;
  final String text;
  final LatLng position;
  final DateTime timestamp;
  final String nickname;
  final String avatar;
  final String userId; // User who sent the message

  MessageModel({
    required this.id,
    required this.text,
    required this.position,
    required this.timestamp,
    required this.nickname,
    required this.avatar,
    required this.userId,
  });

  bool get isExpired => DateTime.now().difference(timestamp).inSeconds > 300;

  // Factory for Firestore
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // GeoFlutterFire stores position as a Map with 'geopoint' and 'geohash'
    // We need to handle both Map (GeoFlutterFire) and GeoPoint (Legacy/Direct)
    final dynamic positionData = data['position'];
    GeoPoint geo;
    
    if (positionData is GeoPoint) {
      geo = positionData;
    } else if (positionData is Map) {
      geo = positionData['geopoint'] as GeoPoint;
    } else {
      // Fallback or throw
      throw Exception("Invalid position format");
    }
    
    return MessageModel(
      id: doc.id,
      text: data['text'] ?? '',
      position: LatLng(geo.latitude, geo.longitude),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      nickname: data['nickname'] ?? 'Anónimo',
      avatar: data['avatar'] ?? '👤',
      userId: data['userId'] ?? '',
    );
  }

  // Factory for Mock data
  factory MessageModel.mock(String text, LatLng pos, String nickname, String avatar, String userId) {
    return MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      position: pos,
      timestamp: DateTime.now(),
      nickname: nickname,
      avatar: avatar,
      userId: userId,
    );
  }
}
