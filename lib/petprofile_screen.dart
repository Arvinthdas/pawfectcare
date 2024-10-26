import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pethealth_screen.dart'; // Your PetHealthScreen
import 'nutrition_screen.dart'; // Your NutritionPage
import 'exercise_screen.dart'; // Your ExerciseMonitoringPage
import 'grooming_screen.dart'; // Your GroomingPage

class PetProfileScreen extends StatefulWidget {
  String petName;
  String petBreed;
  String petImageUrl;
  final bool isFemale;
  final double petWeight;
  final String petAge;
  final String petType;
  final String ageType;
  final String petId;
  final String userId;

  PetProfileScreen({
    required this.petName,
    required this.petBreed,
    required this.petImageUrl,
    required this.isFemale,
    required this.petWeight,
    required this.petAge,
    required this.petType,
    required this.ageType,
    required this.petId,
    required this.userId,
  });

  @override
  _PetProfileScreenState createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  bool _isEditing = false;
  int _selectedIndex = 0;

  // Local state variables to store editable fields
  String _petName = '';
  String _petBreed = '';
  String _petAge = '';
  double _petWeight = 0.0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _customPetTypeController =
      TextEditingController();
  final TextEditingController _customBreedController = TextEditingController();
  File? _selectedImage;
  String? _selectedPetType;
  String? _selectedBreed;
  String? _ageType;
  String? _gender;
  List<String> _breeds = [];
  bool _isFemale = false;

  // Editing state variables
  String _editPetName = '';
  String _editPetType = '';
  String _editBreed = '';
  String _editAge = '';
  String _editAgeType = '';
  String _editWeight = '';
  bool _editIsFemale = false;

  final List<String> _petTypes = ['Dog', 'Cat'];
  final List<String> _genderTypes = ['Male', 'Female'];
  final List<String> _ageTypes = ['Years', 'Months'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();

    // Initialize local state variables from widget properties
    _petName = widget.petName;
    _petBreed = widget.petBreed;
    _petWeight = widget.petWeight;
    _petAge = widget.petAge;

    _nameController.text = widget.petName;
    _weightController.text = widget.petWeight.toString();
    _ageController.text = widget.petAge;
    _selectedPetType = widget.petType;
    _isFemale = widget.isFemale;
    _gender = widget.isFemale ? 'Female' : 'Male';
    _ageType = widget.ageType;

    _editPetName = widget.petName;
    _editWeight = widget.petWeight.toString();
    _editAge = widget.petAge;
    _editPetType = widget.petType;
    _editIsFemale = widget.isFemale;
    _editBreed = widget.petBreed;
    _editAgeType = widget.ageType;

    if (_selectedPetType != 'Others') {
      _fetchBreeds(_selectedPetType!);
    } else {
      _customPetTypeController.text = widget.petType;
      _customBreedController.text = widget.petBreed;
    }
  }

  // Show a dialog to choose between camera and gallery
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Image Source"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text("Camera"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera); // Pick image from camera
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery); // Pick image from gallery
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Image picker to select a new pet image
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Fetch breeds based on pet type
  Future<void> _fetchBreeds(String type) async {
    String url;
    if (type == 'Dog') {
      url = 'https://api.thedogapi.com/v1/breeds';
    } else {
      url = 'https://api.thecatapi.com/v1/breeds';
    }

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'x-api-key': type == 'Dog'
            ? 'live_gdeVpBmEWPcIzSXTmRv6SFnANFY4xhJx4hmBLsQJEPUSSgA6bKtd1CBB9bpYzDiS'
            : 'live_YyuWaIhIU2TypI76GHDS9dno1j7wga3Iqhv0uCXaftZDKpLnuJpwtgQBvdDrDkAF'
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _breeds = data.map((breed) => breed['name'].toString()).toList();

          // Ensure the breed exists in the fetched list
          if (_breeds.isNotEmpty) {
            if (_breeds.contains(widget.petBreed)) {
              _selectedBreed = widget.petBreed;
            } else {
              _selectedBreed =
                  _breeds.first; // Default to first breed if not found
            }
          }
        });
      } else {
        print("Failed to load breeds: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching breeds: $e");
    }
  }

  // Validation for all fields
  bool _validateFields() {
    if (_nameController.text.isEmpty) {
      _showValidationMessage('Please enter the pet name');
      return false;
    }

    if (_editPetType.isEmpty) {
      _showValidationMessage('Please select the pet type');
      return false;
    }

    if (_editBreed.isEmpty) {
      _showValidationMessage('Please select the pet breed');
      return false;
    }

    if (_ageController.text.isEmpty ||
        int.tryParse(_ageController.text) == null) {
      _showValidationMessage('Please enter a valid age');
      return false;
    }

    if (_weightController.text.isEmpty ||
        double.tryParse(_weightController.text) == null) {
      _showValidationMessage('Please enter a valid weight');
      return false;
    }

    if (_editAgeType.isEmpty) {
      _showValidationMessage('Please select the age type');
      return false;
    }

    return true;
  }

  // Show validation message using a SnackBar
  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Show a confirmation dialog before saving
  Future<bool> _showConfirmationDialog() async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Confirm Save"),
              content: Text("Are you sure you want to save these changes?"),
              actions: [
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text("Save"),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Save changes to Firestore
  Future<void> _saveChangesWithConfirmation() async {
    if (!_validateFields()) return;

    // Show confirmation dialog
    bool confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    try {
      // Update local state first to reflect changes immediately
      setState(() {
        _editPetName = _nameController.text; // Update from the controller
        _editWeight = _weightController.text; // Update from the controller
        _editAge = _ageController.text; // Update from the controller
        _selectedPetType = _editPetType;
        _selectedBreed =
            _editBreed == 'Others' ? _customBreedController.text : _editBreed;
        _isFemale = _editIsFemale;
        _ageType = _editAgeType;

        // Update local state variables to reflect new values
        _petName = _editPetName;
        _petWeight = double.tryParse(_editWeight) ?? _petWeight;
        _petAge = _editAge;
      });

      // Ensure proper data type conversions for Firestore
      String imageUrl = widget.petImageUrl; // Start with the existing imageUrl
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToStorage(widget.userId, _selectedImage!);
        setState(() {
          widget.petImageUrl = imageUrl; // Update the image URL after upload
        });
      }

      // Prepare data for Firestore update
      final updatedData = {
        'name': _petName,
        'breed': _selectedBreed ?? widget.petBreed,
        'type': _editPetType == 'Others'
            ? _customPetTypeController.text
            : _editPetType,
        'age': int.tryParse(_petAge) ?? widget.petAge, // Ensure integer age
        'ageType': _editAgeType,
        'gender': _editIsFemale ? 'Female' : 'Male',
        'weight': _petWeight, // Use the updated state variable
        'imageUrl': imageUrl, // Update Firestore with the new image URL
      };

      // Update Firestore with the new data
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .update(updatedData);

      // Clear image after saving and disable editing mode
      setState(() {
        _selectedImage = null;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pet details updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update pet details: $e')));
    }
  }

  // Upload new image to Firebase Storage
  Future<String> _uploadImageToStorage(String uid, File imageFile) async {
    String fileName = 'pets/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef = _storage.ref().child(fileName);
    UploadTask uploadTask = storageRef.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Navigation bar items to show the respective pages
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      // Only show AppBar for Profile tab
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: Color(0xFFE2BF65),
              elevation: 0,
              title: Text('Pet Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit),
                  onPressed: _isEditing
                      ? _saveChangesWithConfirmation
                      : () {
                          setState(() {
                            _isEditing = true;
                            _editPetName = _nameController.text;
                            _editWeight = _weightController.text;
                            _editAge = _ageController.text;
                            _editPetType = _selectedPetType!;
                            _editIsFemale = _isFemale;
                            _editBreed = _selectedBreed!;
                            _editAgeType = _ageType!;
                          });
                        },
                ),
              ],
            )
          : null, // No AppBar for other screens
      // IndexedStack to switch between different pages
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildProfileView(), // PetProfileView
          PetHealthScreen(
              petId: widget.petId,
              userId: widget.userId,
              petName: widget.petName), // Pass petId and userId
          NutritionPage(petId: widget.petId, userId: widget.userId, petName: widget.petName),
          ExerciseMonitoringPage(
            petId: widget.petId,
            userId: widget.userId,
            petType: widget.petType,
            breed: widget.petBreed,
            age: int.tryParse(widget.petAge) ?? 0, // Convert age to integer
          ),
          GroomingPage(
            petId: widget.petId,
            userId: widget.userId,
            petBreed: widget.petBreed, petName: widget.petName
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFFE2BF65),
        selectedItemColor: Color(0xFF048A81), // Color for selected label
        unselectedItemColor: Colors.black, // Color for unselected label
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          fontSize: 15, // Set your desired font size for selected item
          color: Colors.grey, // Ensure this matches the selectedItemColor
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          fontSize: 13, // Set your desired font size for unselected item
          color: Colors.black, // Ensure this matches the unselectedItemColor
        ),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/petprofile.png', height: 30),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/health.png', height: 30),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/nutrition.png', height: 30),
            label: 'Nutrition',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/exercise.png', height: 30),
            label: 'Exercise',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/grooming.png', height: 30),
            label: 'Grooming',
          ),
        ],
      ),
    );
  }

  // Example profile view widget
  Widget _buildProfileView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _isEditing
                ? GestureDetector(
                    onTap: () => _showImageSourceDialog(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(75),
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!,
                              height: 150, width: 150, fit: BoxFit.cover)
                          : Image.network(widget.petImageUrl,
                              height: 150, width: 150, fit: BoxFit.cover),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(75),
                    child: Image.network(
                      widget.petImageUrl,
                      height: 150,
                      width: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          SizedBox(height: 20),

          // Gender field
          _isEditing
              ? _buildGenderField()
              : _buildTextFieldWithIcon(
                  'Gender', widget.isFemale ? 'Female' : 'Male'),

          SizedBox(height: 20),

          // Pet Name field
          _isEditing
              ? _buildEditableField('Pet Name', _nameController,
                  hintText: 'Enter pet name')
              : _buildTextField('Pet Name', _petName),

          SizedBox(height: 20),

          // Pet Type field
          _isEditing
              ? _buildPetTypeField()
              : _buildTextField('Pet Type', _selectedPetType),

          SizedBox(height: 20),

          // Breed field
          _isEditing
              ? _buildBreedField()
              : _buildTextField('Breed', _selectedBreed),

          SizedBox(height: 20),

          // Age field
          _buildAgeField(),

          SizedBox(height: 20),

          // Weight field
          _isEditing
              ? _buildEditableField('Weight (kg)', _weightController,
                  hintText: 'Enter weight')
              : _buildTextField('Weight (kg)', _petWeight.toString()),
        ],
      ),
    );
  }

// Gender dropdown field
  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _editIsFemale ? 'Female' : 'Male',
      items: _genderTypes.map((gender) {
        return DropdownMenuItem<String>(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _editIsFemale = value == 'Female';
        });
      },
      decoration: InputDecoration(
        labelText: 'Gender',
        labelStyle: TextStyle(fontSize: 18), // Maintain label font size
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12), // Increase height here
      ),
    );
  }

  // Gender display with icon
  Widget _buildTextFieldWithIcon(String label, String value) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF7EFF1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(value == 'Female' ? Icons.female : Icons.male,
              color: value == 'Female' ? Colors.pink : Colors.blue, size: 30),
          SizedBox(width: 8),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

// Pet type dropdown field
  Widget _buildPetTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _editPetType,
          items: _petTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _editPetType = value!;
              _fetchBreeds(_editPetType); // Fetch breeds based on the selected pet type
            });
          },
          decoration: InputDecoration(
            labelText: 'Pet Type',
            labelStyle: TextStyle(fontSize: 18), // Maintain label font size
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12), // Increase height here
          ),
        ),
      ],
    );
  }

// Breed field with dropdown
  Widget _buildBreedField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _breeds.contains(_editBreed) ? _editBreed : null,
          items: _breeds.map((breed) {
            return DropdownMenuItem<String>(
              value: breed,
              child: Text(breed),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _editBreed = value!;
            });
          },
          decoration: InputDecoration(
            labelText: 'Breed',
            labelStyle: TextStyle(fontSize: 18), // Increase label font size
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12), // Increase height here
          ),
        ),
      ],
    );
  }

// Helper for read-only text fields when not editing
  Widget _buildTextField(String label, String? value) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width *
            0.9, // Set width to 80% of the screen
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 5),
            Text(value ?? '', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

// Editable field for user input with label aligned with the border
  Widget _buildEditableField(String label, TextEditingController controller, {String? hintText}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[700], // Label color
            fontSize: 18, // Maintain label font size
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always, // Always show the label
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Colors.grey.shade400,
            ),
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12), // Increase height here
        ),
        style: TextStyle(fontSize: 17), // Maintain text field font size
      ),
    );
  }



// Age field for view mode and edit mode
  Widget _buildAgeField() {
    return _isEditing
        ? TextField(
      controller: _ageController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Age (Years)',
        labelStyle: TextStyle(fontSize: 18), // Maintain label font size
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12), // Increase height here
      ),
      style: TextStyle(fontSize: 18), // Maintain text field font size
    )
        : Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9, // Set width to 90% of the screen
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade400), // Add border
        ),
        child: Card(
          color: Colors.grey[200],
          elevation: 0, // Set elevation to 0 to avoid double shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Age',
                  style: TextStyle(
                    fontSize: 18, // Increase font size for the label
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '${_ageController.text} ${widget.ageType}',
                  style: TextStyle(
                    fontSize: 18, // Increase font size for the value
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
