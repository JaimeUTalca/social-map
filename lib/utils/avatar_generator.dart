import 'dart:math';

class AvatarGenerator {
  static final List<String> _avatars = [
    '👽', // Alien
    '👾', // Alien Monster
    '👻', // Ghost
    '🤖', // Robot
    '🦊', // Fox
    '🐱', // Cat
    '🐼', // Panda
    '🐨', // Koala
    '🐸', // Frog
    '🐵', // Monkey
    '🦄', // Unicorn
    '🐙', // Octopus
    '🦖', // T-Rex
    '🐢', // Turtle
    '🦉', // Owl
    '🦝', // Raccoon
    '😎', // Cool Face
    '🤠', // Cowboy
    '🥸', // Disguised Face
    '🤡', // Clown
    '🧑‍🚀', // Astronaut (gender neutral)
    '🦸', // Superhero (gender neutral)
    '🧛', // Vampire (gender neutral)
    '🧟', // Zombie (gender neutral)
    '🍀', // Clover
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
