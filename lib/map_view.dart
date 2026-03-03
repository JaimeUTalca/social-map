import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';
import 'services/firebase_service.dart';
import 'services/user_preferences.dart';
import 'models/message_model.dart';
import 'models/latlng.dart' as models;
import 'widgets/nickname_dialog.dart';
import 'widgets/private_chat_sheet.dart';
import 'utils/content_filter.dart';
import 'utils/location_fuzzing.dart';

import 'package:flutter/foundation.dart'; // For kIsWeb

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final FirebaseService _firebaseService = FirebaseService();
  
  // Real-time Messages
  List<MessageModel> _messages = [];
  final List<MessageModel> _optimisticMessages = []; // Local queue
  latlong.LatLng? _userGpsPosition; // Store actual GPS position (for queries)
  latlong.LatLng? _userDisplayPosition; // Fuzzed position for display (privacy)
  
  // User info
  String? _userNickname;
  String? _userAvatar;
  late final String _userId; // Unique ID for this user
  
  // User presence
  List<Map<String, dynamic>> _nearbyUsers = [];
  StreamSubscription<List<Map<String, dynamic>>>? _usersStream;
  Timer? _presenceBroadcastTimer;
  
  // Message tracking for haptic feedback
  int _previousMessageCount = 0;
  
  // Subscriptions
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<List<MessageModel>>? _messagesStream;
  
  Timer? _localCleanupTimer;
  
  // Firebase optimization
  Timer? _queryThrottleTimer;
  DateTime? _lastQueryTime;
  latlong.LatLng? _lastQueryPosition;
  final List<MessageModel> _messageCache = []; // Local cache
  static const double _minMovementMeters = 10.0; // Minimum movement to trigger query (reduced for testing)
  static const Duration _queryThrottle = Duration(seconds: 2); // Query throttle time (reduced for testing)

  // Ads
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _useMockAd = kIsWeb; // Use mock ad only on web, real ads on mobile
  String? _activeChatUserId; // Tracks which chat is currently open

  @override
  void initState() {
    super.initState();
    _initializeUserId();
    _checkNicknameAndInit();
    
    // Load AdMob banner (only on mobile platforms)
    if (!kIsWeb) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-4566173049235624/3975499794' // Production ID
          : 'ca-app-pub-4566173049235624/3975499794', // Same ID for iOS (create separate if needed)
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Failed to load a banner ad: ${err.message}');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  Future<void> _initializeUserId() async {
    // Get or create persistent user ID
    _userId = await UserPreferences.getUserId();
  }

  Future<void> _checkNicknameAndInit() async {
    // Initialize user (assign avatar if needed)
    await UserPreferences.initializeUser();
    
    // Check if setup is complete
    final isComplete = await UserPreferences.isSetupComplete();
    
    if (!isComplete && mounted) {
      // Show nickname dialog
      final nickname = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const NicknameDialog(),
      );
      
      if (nickname != null) {
        setState(() {
          _userNickname = nickname;
        });
      }
    }
    
    // Load user data
    _userNickname = await UserPreferences.getNickname();
    _userAvatar = await UserPreferences.getAvatar();
    
    // Initialize location
    _initializeLocation();
    _startLocalCleanup();
    _startPresenceBroadcast(); // Start broadcasting presence
  }

  void _startPresenceBroadcast() {
    // Broadcast presence every 5 seconds
    _presenceBroadcastTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_userGpsPosition != null && _userNickname != null && _userAvatar != null) {
        _firebaseService.updateUserPresence(
          models.LatLng(_userGpsPosition!.latitude, _userGpsPosition!.longitude),
          _userNickname!,
          _userAvatar!,
          _userId,
        );
      }
    });
  }

  void _updateNearbyUsersStream(models.LatLng center) {
    _usersStream?.cancel();
    _usersStream = _firebaseService.getNearbyUsers(center, _userId).listen((users) {
      if (mounted) {
        setState(() {
          _nearbyUsers = users;
          debugPrint("👥 Nearby users: ${users.length}");
        });
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _messagesStream?.cancel();
    _localCleanupTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _startLocalCleanup() {
    _localCleanupTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      
      // Realizar la limpieza colaborativa: Borrar físicamente de Firebase los mensajes vigentes que acaban de expirar.
      // Así mantenemos la BD limpia desde cualquier cliente conectado al mapa.
      for (var msg in _messages) {
        if (msg.isExpired) {
          _firebaseService.deletePublicMessage(msg.id);
        }
      }

      setState(() {
         _messages.removeWhere((m) => m.isExpired);
         _optimisticMessages.removeWhere((m) => m.isExpired);
      });
    });
  }

  Future<void> _initializeLocation() async {
    try {
      Position pos = await _locationService.determinePosition();
      latlong.LatLng initialPos = latlong.LatLng(pos.latitude, pos.longitude);
      
      // Center map on user location
      _mapController.move(initialPos, 18.0);
      
      // Update User Marker immediately
      _updateUserMarker(initialPos);

      // Listen to position updates
      _positionStream = _locationService.getPositionStream().listen((position) {
         latlong.LatLng newPos = latlong.LatLng(position.latitude, position.longitude);
         _updateUserMarker(newPos);
         _updateMessageStream(models.LatLng(newPos.latitude, newPos.longitude));
         _updateNearbyUsersStream(models.LatLng(newPos.latitude, newPos.longitude));
      });
      
      // Initial stream setup
      _updateMessageStream(models.LatLng(initialPos.latitude, initialPos.longitude));
      _updateNearbyUsersStream(models.LatLng(initialPos.latitude, initialPos.longitude));

    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  void _updateMessageStream(models.LatLng center) {
    // Check if we need to update the stream
    // Only recreate stream if user moved more than 1km from last query position
    if (_lastQueryPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastQueryPosition!.latitude,
        _lastQueryPosition!.longitude,
        center.latitude,
        center.longitude,
      );
      
      // If user hasn't moved significantly, don't recreate the stream
      // This allows the existing stream to receive real-time updates from other users
      if (distance < 1000) { // 1km threshold
        debugPrint("📍 User moved only ${distance.toStringAsFixed(0)}m, keeping existing stream");
        return;
      }
      
      debugPrint("📍 User moved ${distance.toStringAsFixed(0)}m, recreating stream");
    }
    
    debugPrint("🔄 Creating new Firebase stream for messages at: ${center.latitude}, ${center.longitude}");
    _lastQueryPosition = latlong.LatLng(center.latitude, center.longitude);
    
    // Cancel previous stream and create new one
    _messagesStream?.cancel();
    _messagesStream = _firebaseService.getNearbyMessages(center).listen((newMessages) {
      if (mounted) {
        debugPrint("📨 Received ${newMessages.length} messages from Firebase");
        
        // Haptic feedback on new messages (only from others, not own optimistic messages)
        if (newMessages.length > _previousMessageCount && _previousMessageCount > 0) {
          HapticFeedback.mediumImpact();
          debugPrint("📳 Haptic feedback triggered for new message");
        }
        _previousMessageCount = newMessages.length;
        
        setState(() {
          _messages = newMessages;
          
          // Update cache
          _messageCache.clear();
          _messageCache.addAll(newMessages);
          
          // Cleanup optimistic messages
          _optimisticMessages.removeWhere((opt) => 
            _messages.any((real) => 
              real.text == opt.text && 
              real.timestamp.difference(opt.timestamp).inSeconds.abs() < 5
            )
          );
          
          debugPrint("💬 Total messages displayed: ${_messages.length + _optimisticMessages.length}");
        });
      }
    });
  }

   void _updateUserMarker(latlong.LatLng pos) {
     setState(() {
       _userGpsPosition = pos;
       // Apply fuzzing for display (privacy)
       final fuzzed = LocationFuzzing.fuzzLocation(
         models.LatLng(pos.latitude, pos.longitude),
         _userId,
         radiusMeters: 300.0,
       );
       _userDisplayPosition = latlong.LatLng(fuzzed.latitude, fuzzed.longitude);
     });
   }

  void _sendMessage(String text) async {
      debugPrint("📤 _sendMessage called with text: '$text'");
      
      // Content filter validation
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
        return; // Don't send the message
      }
      
      latlong.LatLng target;
      
      // User current position logic with guaranteed timeout
      try {
        debugPrint("📍 Attempting to get current position...");
        Position userPos = await Geolocator.getCurrentPosition().timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            debugPrint("⏱️ GPS timeout after 1 second");
            throw TimeoutException('GPS timeout');
          },
        );
        target = latlong.LatLng(userPos.latitude, userPos.longitude);
        debugPrint("✅ Got GPS position: ${target.latitude}, ${target.longitude}");
        _updateUserMarker(target);
      } catch (e) {
         debugPrint("⚠️ GPS failed: $e. Using fallback position.");
         target = _userGpsPosition ?? latlong.LatLng(-35.4031, -71.6345);
         debugPrint("📷 Using fallback position: ${target.latitude}, ${target.longitude}");
      }

      debugPrint("🎯 Creating optimistic message at: ${target.latitude}, ${target.longitude}");
      
      // Optimistic UI: Add to separate list
      setState(() {
        _optimisticMessages.add(MessageModel.mock(
          text, 
          models.LatLng(target.latitude, target.longitude),
          _userNickname ?? 'Anónimo',
          _userAvatar ?? '👤',
          _userId, // Add userId
        ));
        debugPrint("➕ Added to optimistic list. Total optimistic: ${_optimisticMessages.length}");
      });

      // Send to Firebase
      debugPrint("🔥 Sending to Firebase...");
      await _firebaseService.sendMessage(
        text, 
        models.LatLng(target.latitude, target.longitude),
        _userNickname ?? 'Anónimo',
        _userAvatar ?? '👤',
        _userId, // Add userId
      );
      debugPrint("✅ Sent to Firebase successfully");
      
      // Stream will automatically receive the update from Firebase
      // No need to manually refresh
  }

  void _openPrivateChat(String otherUserId, String otherUserNickname, String otherUserAvatar) {
    if (_userNickname == null || _userAvatar == null) {
      // User must set up their profile first
      return;
    }
    
    // Marcar como leídos los mensajes no leídos que este usuario nos ha enviado
    _firebaseService.markMessagesAsRead(_userId, otherUserId);

    // Track that we are actively chatting with this user
    setState(() {
      _activeChatUserId = otherUserId;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PrivateChatSheet(
          currentUserId: _userId,
          otherUserId: otherUserId,
          otherUserNickname: otherUserNickname,
          otherUserAvatar: otherUserAvatar,
          firebaseService: _firebaseService,
        ),
      ),
    ).whenComplete(() {
      // Clear active chat tracking when bottom sheet is closed
      if (mounted) {
        setState(() {
          _activeChatUserId = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Combine all messages for display
    final allMessages = [..._messages, ..._optimisticMessages];
    
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userGpsPosition ?? latlong.LatLng(-35.4031, -71.6345),
              initialZoom: 18.0,
              minZoom: 3.0,
              maxZoom: 19.0,
            ),
            children: [
              // OpenStreetMap tiles (free!)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.geo_social_app',
              ),
              
              // Gray overlay outside 2km circle
              if (_userGpsPosition != null)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: [
                        // Large rectangle covering entire world
                        latlong.LatLng(-90, -180),
                        latlong.LatLng(90, -180),
                        latlong.LatLng(90, 180),
                        latlong.LatLng(-90, 180),
                      ],
                      holePointsList: [
                        // Hole in the middle (2km circle approximation with 64 points)
                        List.generate(64, (index) {
                          final angle = (index * 360 / 64) * (3.14159265359 / 180);
                          // 2km = approximately 0.018 degrees at equator
                          // Adjust for latitude using cosine
                          final latRadians = _userGpsPosition!.latitude * 3.14159265359 / 180;
                          final latOffset = 0.018 * cos(angle);
                          final lngOffset = 0.018 * sin(angle) / cos(latRadians);
                          return latlong.LatLng(
                            _userGpsPosition!.latitude + latOffset,
                            _userGpsPosition!.longitude + lngOffset,
                          );
                        }),
                      ],
                      color: Colors.black.withOpacity(0.3),
                      isFilled: true,
                    ),
                  ],
                ),
              
              // 2km visibility circle border
              if (_userGpsPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userGpsPosition!,
                      radius: 2000, // 2km in meters
                      useRadiusInMeter: true,
                      color: Colors.transparent,
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              
              // Uncertainty circle around user (100m radius)
              if (_userDisplayPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userDisplayPosition!,
                      radius: 300, // 300m fuzzing radius
                      useRadiusInMeter: true,
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderColor: Colors.deepPurple.withOpacity(0.3),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              
              // Markers layer
              MarkerLayer(
                markers: [
                  // User marker (violet) - using fuzzed position for privacy
                  if (_userDisplayPosition != null)
                    Marker(
                      point: _userDisplayPosition!,
                      width: 80,
                      height: 100,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar emoji (large)
                          Text(
                            _userAvatar ?? '👤',
                            style: const TextStyle(fontSize: 50),
                          ),
                          // Nickname below avatar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _userNickname ?? 'Yo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Nearby users markers (other connected users) - with fuzzing
                  ..._nearbyUsers.map((user) {
                    final position = user['position'];
                    if (position == null || position['geopoint'] == null) return null;
                    
                    final geopoint = position['geopoint'];
                    final lat = geopoint.latitude;
                    final lng = geopoint.longitude;
                    
                    // Apply fuzzing to other users' positions for privacy
                    final fuzzed = LocationFuzzing.fuzzLocation(
                      models.LatLng(lat, lng),
                      user['id'], // Use other user ID for consistent random offset
                      radiusMeters: 300.0,
                    );
                    
                    return Marker(
                      point: latlong.LatLng(fuzzed.latitude, fuzzed.longitude),
                      width: 70,
                      height: 90,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                          _openPrivateChat(
                            user['id'],
                            user['nickname'] ?? 'Usuario',
                            user['avatar'] ?? '👤',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8.0), // Extiende el área táctil
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                          children: [
                            // Avatar emoji
                            Text(
                              user['avatar'] ?? '👤',
                              style: const TextStyle(fontSize: 40),
                            ),
                            // Nickname below avatar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user['nickname'] ?? 'Usuario',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                       ),
                      ),
                      
                      // Notification Badge
                      Positioned(
                        top: 0,
                        right: 8,
                        child: StreamBuilder<int>(
                          stream: _firebaseService.getUnreadCount(_userId, user['id']),
                          builder: (context, snapshot) {
                            // Don't show badge if we are currently chatting with this user
                            if (_activeChatUserId == user['id']) {
                               // Make sure their messages are marked as read while chat is open
                               _firebaseService.markMessagesAsRead(_userId, user['id']);
                               return const SizedBox.shrink();
                            }
                            
                            final count = snapshot.data ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Center(
                                child: Text(
                                  count > 9 ? '9+' : count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }).whereType<Marker>(),
                  
                  
                  // Message markers - displayed at user's fuzzed position
                  ...() {
                    // Create map of userId -> fuzzed position
                    final Map<String, latlong.LatLng> userPositions = {};
                    
                    // Add current user's fuzzed position
                    if (_userDisplayPosition != null) {
                      userPositions[_userId] = _userDisplayPosition!;
                    }
                    
                    // Add nearby users' fuzzed positions
                    for (final user in _nearbyUsers) {
                      final position = user['position'];
                      if (position != null && position['geopoint'] != null) {
                        final geopoint = position['geopoint'];
                        final fuzzed = LocationFuzzing.fuzzLocation(
                          models.LatLng(geopoint.latitude, geopoint.longitude),
                          user['id'], // Provide the other user's id
                          radiusMeters: 300.0,
                        );
                        userPositions[user['id']] = latlong.LatLng(fuzzed.latitude, fuzzed.longitude);
                      }
                    }
                    
                    // Group messages by userId
                    final Map<String, List<MessageModel>> messagesByUser = {};
                    for (final msg in allMessages) {
                      if (!messagesByUser.containsKey(msg.userId)) {
                        messagesByUser[msg.userId] = [];
                      }
                      messagesByUser[msg.userId]!.add(msg);
                    }
                    
                    // Create markers for each user's messages
                    final List<Marker> messageMarkers = [];
                    messagesByUser.forEach((userId, messages) {
                      final userPosition = userPositions[userId];
                      if (userPosition == null) return; // Skip if user position not found
                      
                      // Sort messages by timestamp (oldest first)
                      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                      
                      // Create stacked markers for this user's messages
                      for (int i = 0; i < messages.length; i++) {
                        final msg = messages[i];
                        final invertedIndex = messages.length - 1 - i;
                        final verticalOffset = invertedIndex * 85.0; // 85px per message
                        
                        messageMarkers.add(Marker(
                          point: userPosition,
                          width: 140,
                          height: 100 + verticalOffset,
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                offset: Offset(0, -verticalOffset),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Sender info (avatar + nickname)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            msg.avatar,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            msg.nickname,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Message text
                                      Text(
                                        msg.text,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ));
                      }
                    });
                    
                    return messageMarkers;
                  }(),
                ],
              ),
            ],
          ),
          
          // Debug overlay showing marker count
          Positioned(
            top: 20, left: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📍 Markers: ${allMessages.length + (_userGpsPosition != null ? 1 : 0)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '💬 Mensajes: ${allMessages.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '👥 Usuarios cerca: ${_nearbyUsers.length}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (_userGpsPosition != null)
                    Text(
                      '📍 GPS: ${_userGpsPosition!.latitude.toStringAsFixed(4)}, ${_userGpsPosition!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),

          // UI Controls
          Positioned(
             bottom: 100 + (_useMockAd ? 60.0 : 0), // Adjust for Ad height
             right: 20,
             child: Column(
               children: [
                 FloatingActionButton(
                   heroTag: "center",
                   mini: true,
                   backgroundColor: Colors.white,
                   child: const Icon(Icons.my_location, color: Colors.blueGrey),
                   onPressed: () {
                     if (_userGpsPosition != null) {
                       _mapController.move(_userGpsPosition!, 18.0);
                     }
                   },
                 ),
                 const SizedBox(height: 16),
                 FloatingActionButton(
                   heroTag: "settings",
                   mini: true,
                   backgroundColor: Colors.white,
                   child: const Icon(Icons.settings, color: Colors.blueGrey),
                   onPressed: () => _showSettingsDialog(context),
                 ),
                 const SizedBox(height: 16),
                 FloatingActionButton.extended(
                   heroTag: "msg",
                   onPressed: () => _showInputDialog(context),
                   backgroundColor: Colors.deepPurple,
                   icon: const Icon(Icons.edit, color: Colors.white),
                   label: const Text(
                     "Escribir",
                     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                   ),
                   elevation: 4,
                 ),
               ],
             ),
          ),
          
          // Ad Banner
          if (_isBannerAdReady || _useMockAd)
            Align(
              alignment: Alignment.bottomCenter,
              child: _isBannerAdReady && !_useMockAd
                ? SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  )
                : Container(
                    width: 320,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black12)],
                    ),
                    child: Row(
                      children: [
                        // Ad Badge
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text('Ad', style: TextStyle(color: Colors.green, fontSize: 8)),
                        ),
                        // Icon
                        Container(
                          width: 40, height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: Colors.blueAccent,
                          child: const Icon(Icons.star, color: Colors.white),
                        ),
                        // Text
                        const Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Super Juego Gratis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Instalar ahora', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        // Button
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('ABRIR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
            ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) async {
    final newNickname = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const NicknameDialog(),
    );
    
    if (newNickname != null && mounted) {
      // Reload user data after settings change
      final updatedNickname = await UserPreferences.getNickname();
      final updatedAvatar = await UserPreferences.getAvatar();
      
      setState(() {
        _userNickname = updatedNickname;
        _userAvatar = updatedAvatar;
      });
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perfil actualizado: $_userNickname $_userAvatar'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showInputDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          controller: textController,
          maxLength: 40,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Di algo..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                _sendMessage(textController.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Enviar"),
          )
        ],
      ),
    );
  }
}
