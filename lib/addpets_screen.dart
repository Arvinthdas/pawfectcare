import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddPetsScreen extends StatefulWidget {
  @override
  _AddPetsScreenState createState() => _AddPetsScreenState();
}

class _AddPetsScreenState extends State<AddPetsScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedImage;
  bool _isUploading = false;
  String? _selectedPetType;
  String? _selectedBreed;
  String? _ageType = 'Years'; // Default age type is "Years"
  String? _gender = 'Male';
  final List<String> _petTypes = ['Dog', 'Cat'];
  final List<String> _genderTypes = ['Male', 'Female'];
  //final List<String> _ageTypes = ['Years']; // Only "Years" is available

  List<String> _breeds = [];

  // Function to fetch breeds from the API
  Future<void> _fetchBreeds(String type) async {
    final apiKey = type == 'Dog'
        ? 'live_gdeVpBmEWPcIzSXTmRv6SFnANFY4xhJx4hmBLsQJEPUSSgA6bKtd1CBB9bpYzDiS' // Replace with your actual Dog API key
        : 'live_YyuWaIhIU2TypI76GHDS9dno1j7wga3Iqhv0uCXaftZDKpLnuJpwtgQBvdDrDkAF'; // Replace with your actual Cat API key

    final url = Uri.parse(type == 'Dog'
        ? 'https://api.thedogapi.com/v1/breeds'
        : 'https://api.thecatapi.com/v1/breeds');

    try {
      final response = await http.get(url, headers: {'x-api-key': apiKey});
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _breeds = data.map((breed) => breed['name'].toString()).toList();
        });
      } else {
        print("Failed to load breeds: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching breeds: $e");
    }
  }

  // Function to add pet details to Firestore
  Future<void> _addPet() async {
    User? user = _auth.currentUser;
    if (user != null &&
        _selectedImage != null &&
        _nameController.text.isNotEmpty &&
        _ageController.text.isNotEmpty &&
        _weightController.text.isNotEmpty &&
        _selectedBreed != null) {
      setState(() {
        _isUploading = true;
      });

      String uid = user.uid; // Get user ID
      String imageUrl = await _uploadImageToStorage(uid, _selectedImage!);

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
        _isUploading = false;
      });

      Navigator.pop(context); // Go back after adding the pet
    }
  }

  // Function to pick an image from camera or gallery
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
    String fileName =
        'pets/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Organize by user ID
    Reference storageRef = _storage.ref().child(fileName);
    UploadTask uploadTask = storageRef.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL(); // Get the download URL
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
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
        backgroundColor: Color(0xFFE2BF65),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                fillColor: Colors.grey[200],
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
            if (_selectedPetType != null &&
                (_selectedPetType == 'Dog' || _selectedPetType == 'Cat')) ...[
              Text('Select Breed *',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
            if (_selectedPetType == 'Others') ...[
              Text('Breed *', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter breed',
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
            ],
            SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Age (${_ageType!}) *',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                    ],
                  ),
                ),
              ],
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
            Text('Weight (kg) *',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
