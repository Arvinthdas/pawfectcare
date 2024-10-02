import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';  // For selecting images
import 'package:firebase_storage/firebase_storage.dart';  // For uploading images
import 'dart:io';

class AddPetsScreen extends StatefulWidget {
  @override
  _AddPetsScreenState createState() => _AddPetsScreenState();
}

class _AddPetsScreenState extends State<AddPetsScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _breedController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _addPet() async {
    User? user = _auth.currentUser;

    if (user != null && _selectedImage != null) {
      setState(() {
        _isUploading = true;
      });

      String uid = user.uid;  // Get the user's UID

      // Upload image to Firebase Storage and get the download URL
      String imageUrl = await _uploadImageToStorage(uid, _selectedImage!);

      // Save pet details along with image URL under this user's UID
      await _firestore
          .collection('users')
          .doc(uid)  // Use UID as document ID
          .collection('pets')  // Save pet details in 'pets' sub-collection
          .add({
        'name': _nameController.text,
        'age': int.parse(_ageController.text),
        'breed': _breedController.text,
        'imageUrl': imageUrl,  // Store the image URL
      });

      setState(() {
        _isUploading = false;
      });

      Navigator.pop(context);  // Return to the previous screen after adding
    }
  }

  // Function to pick image either from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Function to upload image to Firebase Storage
  Future<String> _uploadImageToStorage(String uid, File imageFile) async {
    String fileName = 'pets/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef = _storage.ref().child(fileName);
    UploadTask uploadTask = storageRef.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Pet'),
        backgroundColor: Color(0xFFE2BF65),  // Follow app theme color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Pet Name'),
            ),
            TextField(
              controller: _ageController,
              decoration: InputDecoration(labelText: 'Pet Age'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _breedController,
              decoration: InputDecoration(labelText: 'Pet Breed'),
            ),
            SizedBox(height: 20),

            // Image Selection
            _selectedImage != null
                ? Image.file(
              _selectedImage!,
              height: 150,
              width: 150,
              fit: BoxFit.cover,
            )
                : Placeholder(
              fallbackHeight: 150,
              fallbackWidth: 150,
              color: Colors.grey,
              strokeWidth: 2,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE2BF65),  // Follow theme color
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo),
                  label: Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE2BF65),  // Follow theme color
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            _isUploading
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _selectedImage == null ? null : _addPet,
              child: Text('Add Pet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE2BF65),  // Follow theme color
              ),
            ),
          ],
        ),
      ),
    );
  }
}
