import 'package:flutter/material.dart';
import 'package:sippichat_client/features/profile/edit_profile_page.dart';

import '../../app/app_dependencies.dart';

class ProfilePage extends StatefulWidget{
  const ProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => _ProfilePageState();

}

class _ProfilePageState extends State<ProfilePage> {

  final controller = AppDependencies.profileController;


  @override
  void initState() {
    super.initState();

    controller.addListener(_update);
    controller.loadProfile();
  }


  void _update() {
    if (mounted) {
      setState(() {});
    }
  }


  @override
  void dispose() {
    controller.removeListener(_update);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;

    if(profile == null){
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.displayName,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text("@${profile.username}"),
            const SizedBox(height: 20),
            Text(profile.bio ?? "No bio yet"),

            const SizedBox(height: 30),
            ElevatedButton(onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
            }, child: const Text("Edit profile"))
          ],


        ),


      ),

    );
  }
}