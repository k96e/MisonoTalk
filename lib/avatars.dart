import 'package:flutter/material.dart';


class Avatar {
  final String name;
  final int id;
  final String assetPath;
  Avatar(this.name, this.id, this.assetPath);
}

class AvatarManager  {
  AvatarManager._internal();
  static final AvatarManager _instance = AvatarManager._internal();
  factory AvatarManager() {
    return _instance;
  }

  List<Avatar> avatarList = [
    Avatar("Default", 0, "assets/avatar.png"),
    Avatar("SwimSuit", 1, "assets/avatar_swim.png"),
  ];

  int avatarIndex = 0;

  ImageProvider getAvatar() {
    if (avatarIndex < 0 || avatarIndex >= avatarList.length) {
      avatarIndex = 0;
    }
    return AssetImage(avatarList[avatarIndex].assetPath);
  }
}

