import 'package:flutter/material.dart';
import '../services/user_preferences.dart';
import '../utils/avatar_generator.dart';
import '../utils/content_filter.dart';

class NicknameDialog extends StatefulWidget {
  const NicknameDialog({super.key});

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  String _avatar = '👤';

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatar = await UserPreferences.getAvatar();
    if (avatar != null && mounted) {
      setState(() {
        _avatar = avatar;
      });
    }
  }

  bool _isValidNickname(String nickname) {
    if (nickname.isEmpty) {
      setState(() {
        _errorText = 'El nickname no puede estar vacío';
      });
      return false;
    }
    if (nickname.length < 3) {
      setState(() {
        _errorText = 'Mínimo 3 caracteres';
      });
      return false;
    }
    if (nickname.length > 15) {
      setState(() {
        _errorText = 'Máximo 15 caracteres';
      });
      return false;
    }
    // Only allow letters, numbers, and underscores
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(nickname)) {
      setState(() {
        _errorText = 'Solo letras, números y _';
      });
      return false;
    }
    
    // Check for offensive content
    if (ContentFilter.containsBannedWords(nickname)) {
      setState(() {
        _errorText = 'El apodo no está permitido.';
      });
      return false;
    }
    
    setState(() {
      _errorText = null;
    });
    return true;
  }

  Future<void> _continue() async {
    final nickname = _controller.text.trim();
    if (_isValidNickname(nickname)) {
      await UserPreferences.saveNickname(nickname);
      await UserPreferences.markSetupComplete();
      if (mounted) {
        Navigator.of(context).pop(nickname);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get all 10 avatars
    final avatarOptions = List.generate(
      AvatarGenerator.avatarCount,
      (index) => AvatarGenerator.getAvatarByIndex(index),
    );
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing
      child: AlertDialog(
        title: const Text(
          '¡Bienvenido!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Elige tu avatar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Avatar selection grid using Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(avatarOptions.length, (index) {
                  final avatar = avatarOptions[index];
                  final isSelected = avatar == _avatar;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _avatar = avatar;
                      });
                      UserPreferences.saveAvatar(avatar);
                    },
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              const Text(
                'Ahora elige tu nickname',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: false,
                maxLength: 15,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Nickname',
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                onChanged: (value) {
                  _isValidNickname(value);
                },
                onSubmitted: (_) => _continue(),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: _errorText == null && _controller.text.isNotEmpty
                ? _continue
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continuar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
