import 'package:flutter/material.dart';
import 'package:sippichat_client/app/app_dependencies.dart';

class EditProfilePage extends StatefulWidget{
  const EditProfilePage({super.key});

  @override
  State<StatefulWidget> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>{
  late TextEditingController displayNameController;
  late TextEditingController bioController;

  @override
  void initState() {
    super.initState();

    final profile = AppDependencies.profileController.profile;

    displayNameController = TextEditingController(
      text: profile?.displayName ?? ""
    );

    bioController = TextEditingController(
      text: profile?.bio ?? ""
    );
  }

  @override
  void dispose() {
    displayNameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> save() async{
    await AppDependencies.profileController.updateProfile(
      displayName: displayNameController.text.trim(),
      bio: bioController.text.trim(),
    );
    if (mounted){
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text("Edit Profile"),

        actions: [

          IconButton(
            icon: const Icon(Icons.save),

            onPressed: save,
          )

        ],
      ),


      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            TextField(
              controller: displayNameController,

              decoration: const InputDecoration(
                labelText: "Display name",
              ),
            ),


            const SizedBox(height: 20),


            TextField(
              controller: bioController,

              maxLines: 4,

              decoration: const InputDecoration(
                labelText: "Bio",
              ),
            ),

          ],
        ),
      ),
    );
  }
}