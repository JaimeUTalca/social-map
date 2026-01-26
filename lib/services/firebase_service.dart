import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/latlng.dart';

class FirebaseService {
  final _firestore = FirebaseFirestore.instance;
  final _geo = GeoFlutterFire();

  /// Sends a message to Firestore with GeoHash
  Future<void> sendMessage(String text, LatLng position, String nickname, String avatar, String userId) async {
    GeoFirePoint myLocation = _geo.point(
      latitude: position.latitude, 
      longitude: position.longitude
    );

    // Calculate expiration time (5 minutes from now)
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(minutes: 5))
    );

    debugPrint("Sending message to Firestore: $text at ${myLocation.data}");
    debugPrint("Message will expire at: ${expiresAt.toDate()}");
    
    await _firestore.collection('mensajes').add({
      'text': text,
      'position': myLocation.data,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt, // TTL field for automatic deletion
      'nickname': nickname,
      'avatar': avatar,
      'userId': userId, // Add user ID to associate message with sender
    }).then((_) => debugPrint("Message sent successfully"))
      .catchError((e) => debugPrint("Error sending message: $e"));
  }

  /// Gets nearby messages within 2km radius using GeoFlutterFire (server-side filtering)
  Stream<List<MessageModel>> getNearbyMessages(LatLng center) {
    debugPrint("📡 Setting up GeoFlutterFire stream for messages");
    debugPrint("   Center: ${center.latitude}, ${center.longitude}");
    debugPrint("   Radius: 2km");
    
    GeoFirePoint centerPoint = _geo.point(
      latitude: center.latitude,
      longitude: center.longitude,
    );

    // Use GeoFlutterFire for efficient server-side geo-queries
    // This only fetches messages within 2km radius from Firestore
    var collectionRef = _firestore.collection('mensajes');
    Stream<List<DocumentSnapshot>> stream = _geo
        .collection(collectionRef: collectionRef)
        .within(center: centerPoint, radius: 2, field: 'position');

    return stream.map((List<DocumentSnapshot> documentList) {
      debugPrint("📨 GeoFlutterFire returned ${documentList.length} nearby documents");
      final now = DateTime.now();
      List<MessageModel> messages = [];

      for (DocumentSnapshot doc in documentList) {
        if (doc.data() == null) continue;

        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // Check expiration
          bool isExpired = false;
          
          // Try to use expiresAt field first (new messages)
          final expiresAtRaw = data['expiresAt'];
          if (expiresAtRaw is Timestamp) {
            final expiresAt = expiresAtRaw.toDate();
            isExpired = expiresAt.isBefore(now);
            
            if (isExpired) {
              debugPrint("⏰ Skipping expired message (expiresAt): ${data['text']}");
              continue;
            }
          } else {
            // Fallback: check timestamp for old messages without expiresAt
            final timestampRaw = data['timestamp'];
            if (timestampRaw is Timestamp) {
              final timestamp = timestampRaw.toDate();
              // Consider expired if older than 5 minutes
              isExpired = now.difference(timestamp).inSeconds > 300;
              
              if (isExpired) {
                debugPrint("⏰ Skipping expired message (timestamp): ${data['text']}");
                continue;
              }
            }
          }
          
          // Add non-expired message
          messages.add(MessageModel.fromFirestore(doc));
        } catch (e) {
          debugPrint("Error parsing message: $e");
        }
      }

      debugPrint("✅ Filtered to ${messages.length} valid messages");
      return messages;
    });
  }

  /// Broadcasts user presence (location, nickname, avatar)
  Future<void> updateUserPresence(LatLng position, String nickname, String avatar, String userId) async {
    GeoFirePoint myLocation = _geo.point(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    debugPrint("Updating user presence: $nickname at ${myLocation.data}");
    
    await _firestore.collection('users').doc(userId).set({
      'nickname': nickname,
      'avatar': avatar,
      'position': myLocation.data,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true))
    .then((_) => debugPrint("User presence updated"))
    .catchError((e) => debugPrint("Error updating presence: $e"));
  }

  /// Gets nearby users within 2km radius
  Stream<List<Map<String, dynamic>>> getNearbyUsers(LatLng center, String myUserId) {
    GeoFirePoint centerPoint = _geo.point(
      latitude: center.latitude,
      longitude: center.longitude,
    );

    var collectionRef = _firestore.collection('users');
    Stream<List<DocumentSnapshot>> stream = _geo
        .collection(collectionRef: collectionRef)
        .within(center: centerPoint, radius: 2, field: 'position');

    return stream.map((List<DocumentSnapshot> documentList) {
      debugPrint("Found ${documentList.length} nearby users");
      final now = DateTime.now();
      List<Map<String, dynamic>> users = [];

      for (DocumentSnapshot doc in documentList) {
        if (doc.data() == null || doc.id == myUserId) continue; // Skip self
        
        try {
          final data = doc.data() as Map<String, dynamic>;
          final lastSeenRaw = data['lastSeen'];
          
          if (lastSeenRaw is Timestamp) {
            final lastSeen = lastSeenRaw.toDate();
            // Only show users active in last 30 seconds
            if (now.difference(lastSeen).inSeconds < 30) {
              users.add({
                'id': doc.id,
                'nickname': data['nickname'] ?? 'Usuario',
                'avatar': data['avatar'] ?? '👤',
                'position': data['position'],
              });
            }
          }
        } catch (e) {
          debugPrint("Error parsing user: $e");
        }
      }
      
      return users;
    });
  }

  /// Removes user presence when they disconnect
  Future<void> removeUserPresence(String userId) async {
    await _firestore.collection('users').doc(userId).delete()
      .then((_) => debugPrint("User presence removed"))
      .catchError((e) => debugPrint("Error removing presence: $e"));
  }
}
