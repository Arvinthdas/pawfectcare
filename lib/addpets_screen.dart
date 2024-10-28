import 'package:flutter/material.dart'; // Importing Flutter's material design library for UI components.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Firebase Firestore for database functions.
import 'package:firebase_auth/firebase_auth.dart'; // Importing Firebase Authentication for user sign-in.
import 'package:image_picker/image_picker.dart'; // Importing image picker for choosing images from camera or gallery.
import 'package:firebase_storage/firebase_storage.dart'; // Importing Firebase Storage to store images.
import 'dart:io'; // Dart library for File and IO operations.
import 'package:http/http.dart' as http; // HTTP package for handling API requests.
import 'dart:convert'; // Dart's convert library to handle JSON encoding and decoding.

class AddPetsScreen extends StatefulWidget { // A StatefulWidget to manage the UI and state changes.
  @override
  _AddPetsScreenState createState() => _AddPetsScreenState(); // Creating the state for AddPetsScreen.
}

class _AddPetsScreenState extends State<AddPetsScreen> {
  // Controllers to handle text input for pet details.
  final _nameController = TextEditingController(); // For pet name input.
  final _ageController = TextEditingController(); // For pet age input.
  final _weightController = TextEditingController(); // For pet weight input.
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance for managing user sessions.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations.
  final FirebaseStorage _storage = FirebaseStorage.instance; // Firebase Storage instance for file storage.

  File? _selectedImage; // Holds the selected image file.
  bool _isUploading = false; // Flag to show uploading status.
  String? _selectedPetType; // Selected pet type (Dog or Cat).
  String? _selectedBreed; // Selected breed based on pet type.
  String? _ageType = 'Years'; // Age unit, default set to 'Years'.
  String? _gender = 'Male'; // Gender selection, default set to 'Male'.
  final List<String> _petTypes = ['Dog', 'Cat']; // List of pet types.
  final List<String> _genderTypes = ['Male', 'Female']; // List of available genders.

  List<String> _breeds = []; // List to store breeds fetched from the API.

  // Function to fetch breeds based on selected pet type.
  Future<void> _fetchBreeds(String type) async {
    final apiKey = type == 'Dog'
        ? 'live_gdeVpBmEWPcIzSXTmRv6SFnANFY4xhJx4hmBLsQJEPUSSgA6bKtd1CBB9bpYzDiS' // API key for dog breeds
        : 'live_YyuWaIhIU2TypI76GHDS9dno1j7wga3Iqhv0uCXaftZDKpLnuJpwtgQBvdDrDkAF'; // API key for cat breeds

    // URL for API based on the pet type.
    final url = Uri.parse(type == 'Dog'
        ? 'https://api.thedogapi.com/v1/breeds' // Dog breeds API endpoint.
        : 'https://api.thecatapi.com/v1/breeds'); // Cat breeds API endpoint.

    try {
      final response = await http.get(url, headers: {'x-api-key': apiKey}); // Sending GET request with API key.
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body); // Parsing JSON data.
        setState(() {
          _breeds = data.map((breed) => breed['name'].toString()).toList(); // Extracting breed names.
        });
      } else {
        print("Failed to load breeds: ${response.statusCode}"); // Log if the response status is not successful.
      }
    } catch (e) {
      print("Error fetching breeds: $e"); // Log in case of exceptions.
    }
  }

  // Function to add pet details to Firestore database.
  Future<void> _addPet() async {
    User? user = _auth.currentUser; // Getting the current authenticated user.
    if (user != null &&
        _selectedImage != null &&
        _nameController.text.isNotEmpty &&
        _ageController.text.isNotEmpty &&
        _weightController.text.isNotEmpty &&
        _selectedBreed != null) { // Checking if all fields are filled.

      setState(() {
        _isUploading = true; // Show uploading indicator.
      });

      String uid = user.uid; // User ID for the authenticated user.
      String imageUrl = await _uploadImageToStorage(uid, _selectedImage!); // Uploading image and getting URL.

      // Adding pet details to Firestore under the user's collection.
      await _firestore.collection('users').doc(uid).collection('pets').add({
        'name': _nameController.text,
        'age': int.parse(_ageController.text),
        'ageType': _ageType,
        'breed': _selectedBreed,
        'gender': _gender,
        'weight': double.parse(_weightController.text),
        'imageUrl': imageUrl,
        'type': _selectedPetType,
      });

      setState(() {
        _isUploading = false; // Hide uploading indicator.
      });

      Navigator.pop(context); // Go back to the previous screen after saving.
    }
  }

  // Function to pick an image from camera or gallery.
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source); // Launch image picker.
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // Set the selected image file.
      });
    }
  }

  // Function to upload image to Firebase Storage.
  Future<String> _uploadImageToStorage(String uid, File imageFile) async {
    String fileName = 'pets/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Unique file path in storage.
    Reference storageRef = _storage.ref().child(fileName); // Reference to the storage path.
    UploadTask uploadTask = storageRef.putFile(imageFile); // Start uploading image.
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL(); // Get and return image URL.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1), // Background color for the screen.
      appBar: AppBar(
        title: Text(
          'Add Pet',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color(0xFFE2BF65), // AppBar color.
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding around the form.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pet Name *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter pet name',
                filled: true,
                fillColor: Colors.grey[200], // TextField styling for pet name.
              ),
            ),
            SizedBox(height: 15),
            Text('Pet Type *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            DropdownButtonFormField<String>(
              value: _selectedPetType,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              items: _petTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPetType = value;
                  _selectedBreed = null;
                  _breeds = [];
                });
                if (value == 'Dog' || value == 'Cat') _fetchBreeds(value!);
              },
              hint: Text('Select Pet Type'),
            ),
            SizedBox(height: 15),
            if (_selectedPetType != null && (_selectedPetType == 'Dog' || _selectedPetType == 'Cat')) ...[
              Text('Select Breed *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: _selectedBreed,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                items: _breeds.map((breed) {
                  return DropdownMenuItem<String>(
                    value: breed,
                    child: Text(breed),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBreed = value;
                  });
                },
                hint: Text('Select Breed'),
              ),
            ],
            SizedBox(height: 15),
            Text('Age (${_ageType!}) *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _ageController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter age in ${_ageType!}',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 15),
            Text('Gender *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              items: _genderTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _gender = value;
                });
              },
            ),
            SizedBox(height: 15),
            Text('Weight (kg) *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _weightController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter weight in kg',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 15),
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
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE2BF65),
                    foregroundColor: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo),
                  label: Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE2BF65),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _isUploading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedImage == null ? null : _addPet,
                child: Text('Add Pet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE2BF65),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
