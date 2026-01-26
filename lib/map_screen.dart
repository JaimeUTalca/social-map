import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  final Set<Marker> _markers = {};
  
  // Timer for cleanup
  Timer? _cleanupTimer;

  // Internal list of messages to manage state and timers
  final List<_MockMessage> _activeMessages = [];

  static const CameraPosition _kDefaultPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _startCleanupTimer();
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _startCleanupTimer() {
    // Check every second for expired messages
    _cleanupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeMessages.isNotEmpty) {
        setState(() {
          _activeMessages.removeWhere((msg) => msg.isExpired);
          _refreshMarkers();
        });
      }
    });
  }

  Future<void> _initializeLocation() async {
    try {
      Position position = await _locationService.determinePosition();
      _goToPosition(position);
    } catch (e) {
      debugPrint("Location error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _goToPosition(Position position) async {
    final GoogleMapController controller = await _controller.future;
    CameraPosition newPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 17,
    );
    controller.animateCamera(CameraUpdate.newCameraPosition(newPosition));
  }

  Future<void> _refreshMarkers() async {
    Set<Marker> newMarkers = {};
    for (var msg in _activeMessages) {
      final BitmapDescriptor icon = await _createCustomMarkerBitmap(msg.text);
      newMarkers.add(
        Marker(
          markerId: MarkerId(msg.id),
          position: msg.position,
          icon: icon,
          // Optional: simple fade effect could be done by alpha if supported, 
          // but markers don't support dynamic opacity easily without regenerating.
        ),
      );
    }
    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(String text) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.white;
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.3);
    final double radius = 10.0;
    
    final TextSpan span = TextSpan(
      style: const TextStyle(
        color: Colors.black,
        fontSize: 24.0, // adjusted size
        fontWeight: FontWeight.bold,
      ),
      text: text.length > 20 ? "${text.substring(0, 17)}..." : text,
    );
    
    final TextPainter painter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    
    final double padding = 20.0;
    final double width = painter.width + padding * 2;
    final double height = painter.height + padding * 2;
    
    // Draw Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, width, height),
        Radius.circular(radius),
      ),
      shadowPaint,
    );

    // Draw Bubble
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(radius),
      ),
      paint,
    );
    
    // Draw Triangle (Pointer)
    final Path path = Path();
    path.moveTo(width / 2 - 10, height);
    path.lineTo(width / 2, height + 15);
    path.lineTo(width / 2 + 10, height);
    path.close();
    canvas.drawPath(path, paint);

    // Draw Text
    painter.paint(canvas, Offset(padding, padding));

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      (width + 8).toInt(), // extra space for shadow
      (height + 20).toInt(),
    );
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  void _showAddMessageDialog() {
    TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Grita al mundo"),
        content: TextField(
          controller: textController,
          maxLength: 30,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "¿Qué está pasando?",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.isNotEmpty) {
                 final String text = textController.text;
                 Navigator.pop(context); // Close dialog first

                 // Get current camera target as the position for the message
                 final GoogleMapController controller = await _controller.future;
                 final LatLng center = await controller.getLatLng(
                   ScreenCoordinate(x: 0, y: 0) // Not used, logic below
                 );
                 // Better: use the user's current location if available, otherwise map center
                 // For this "Habbo" style, usually it's where the user IS.
                 
                 Position? userPos;
                 try {
                   userPos = await _locationService.determinePosition();
                 } catch (_) {}

                 final LatLng msgPos = userPos != null 
                    ? LatLng(userPos.latitude, userPos.longitude)
                    : (await controller.getVisibleRegion()).northeast; // Fallback

                 // Add to active messages with expiration
                 final newMessage = _MockMessage(
                   id: DateTime.now().millisecondsSinceEpoch.toString(),
                   text: text,
                   position: msgPos,
                   createdAt: DateTime.now(),
                 );

                 setState(() {
                   _activeMessages.add(newMessage);
                   _refreshMarkers();
                 });
                 
                 // Simulating "Visual Rise"? 
                 // We could technically update the marker position slightly up every 100ms
                 // in a separate loop, but Google Maps Markers might flickering if updated too fast.
                 // For now, the visual pop in/out is sufficient for V1.
              }
            },
            child: const Text("Publicar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kDefaultPosition, // Will update to user loc
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
          ),
          // Custom FAB area
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "loc",
                  mini: true,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blueGrey),
                  onPressed: _initializeLocation,
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "add",
                  backgroundColor: Colors.deepPurple,
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  onPressed: _showAddMessageDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockMessage {
  final String id;
  final String text;
  final LatLng position;
  final DateTime createdAt;

  _MockMessage({
    required this.id,
    required this.text,
    required this.position,
    required this.createdAt,
  });

  // Message expires after 30 seconds
  bool get isExpired => DateTime.now().difference(createdAt).inSeconds > 30;
}
