import 'package:flutter/material.dart';
import 'package:sippichat_client/features/profile/profile_service.dart';

import 'model/profile.dart';

class ProfileController extends ChangeNotifier{
  final ProfileService service;

  ProfileController(this.service);

  Profile? _profile;
  Profile? get profile => _profile;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> loadProfile() async{
    _loading = true;
    notifyListeners();

    try{
      _profile = await service.getMe();
    }finally{
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
  }) async{
    print("UPDATING PROFILE");
    print(displayName);
    print(bio);
    final updated = await service.updateProfile(
      displayName: displayName,
      bio: bio,
    );

    print("SERVER RETURNED:");
    print(updated.displayName);
    print(updated.bio);

    _profile = updated;
    notifyListeners();
  }
}