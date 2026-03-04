import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/avatar_generator.dart';

class UserPreferences {
  static const String _nicknameKey = 'user_nickname';
  static const String _avatarKey = 'user_avatar';
  static const String _setupCompleteKey = 'setup_complete';
  static const String _userIdKey = 'user_id';

  // Save nickname
  static Future<void> saveNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, nickname);
  }

  // Get nickname
  static Future<String?> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey);
  }

  // Save avatar
  static Future<void> saveAvatar(String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, avatar);
  }

  // Get avatar
  static Future<String?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarKey);
  }

  // Mark setup as complete
  static Future<void> markSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
  }

  // Check if setup is complete
  static Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey) ?? false;
  }

  // Get or create persistent user ID
  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);
    
    if (userId == null) {
      // Generate new UUID for this user
      userId = const Uuid().v4();
      await prefs.setString(_userIdKey, userId);
    }
    
    return userId;
  }

  // Initialize user (assign random avatar if not exists)
  static Future<void> initializeUser() async {
    final avatar = await getAvatar();
    if (avatar == null) {
      final randomAvatar = AvatarGenerator.getRandomAvatar();
      await saveAvatar(randomAvatar);
    }
  }

  // Clear all data (for testing)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // -- Blocked Users Management --
  static const String _blockedUsersKey = 'blocked_users';

  /// Returns the set of blocked user IDs
  static Future<Set<String>> getBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blockedUsersKey) ?? [];
    return list.toSet();
  }

  /// Blocks a user by their ID
  static Future<void> blockUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList(_blockedUsersKey) ?? [];
    if (!blocked.contains(userId)) {
      blocked.add(userId);
      await prefs.setStringList(_blockedUsersKey, blocked);
    }
  }

  /// Unblocks a user by their ID
  static Future<void> unblockUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList(_blockedUsersKey) ?? [];
    blocked.remove(userId);
    await prefs.setStringList(_blockedUsersKey, blocked);
  }
}
