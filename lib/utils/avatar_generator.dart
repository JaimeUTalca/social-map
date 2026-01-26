import 'dart:math';

class AvatarGenerator {
  static final List<String> _avatars = [
    '👨‍🚀', // Astronaut (male)
    '👩‍🚀', // Astronaut (female)
    '👨‍💼', // Business person (male)
    '👩‍💼', // Business person (female)
    '👨‍🎓', // Student (male)
    '👩‍🎓', // Student (female)
    '👨‍🎨', // Artist (male)
    '👩‍🎨', // Artist (female)
    '👨‍⚕️', // Doctor (male)
    '👩‍⚕️', // Doctor (female)
  ];

  static String getRandomAvatar() {
    final random = Random();
    return _avatars[random.nextInt(_avatars.length)];
  }

  static String getAvatarByIndex(int index) {
    return _avatars[index % _avatars.length];
  }

  static int get avatarCount => _avatars.length;
}
