import 'package:flutter/material.dart'; // Import Flutter's Material UI components
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for database interactions
import 'package:image_picker/image_picker.dart'; // Import image picker for selecting images
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage for image uploads
import 'dart:io'; // Import Dart's IO library for file handling
import 'package:intl/intl.dart'; // Import Intl for date formatting (if needed)

class AddFoodScreen extends StatefulWidget {
  final String petId; // Pet ID
  final String userId; // User ID

  AddFoodScreen({required this.petId, required this.userId});

  @override
  _AddFoodScreenState createState() => _AddFoodScreenState();
}

// State class for AddFoodScreen
class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>(); // Global key for form validation
  String _foodName = ''; // Food name
  String _foodType = 'Dry'; // Default food type
  double _carbs = 0; // Carbohydrates
  double _protein = 0; // Protein
  double _fat = 0; // Fat
  double _calcium = 0; // Calcium
  double _vitamins = 0; // Vitamins
  File? _selectedImage; // Selected image file
  String? _imageUrl; // URL of uploaded image
  bool _isUploading = false; // Flag to indicate if an upload is in progress
  DateTime _selectedDateTime = DateTime.now(); // Selected date and time

  // Function to save food details
  Future<void> _saveFoodDetails() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save(); // Save form data

      setState(() {
        _isUploading = true; // Start uploading
      });

      try {
        // Upload image if selected
        if (_selectedImage != null) {
          try {
            String fileName =
                'food_images/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
            Reference storageRef =
                FirebaseStorage.instance.ref().child(fileName);
            UploadTask uploadTask = storageRef.putFile(_selectedImage!);
            TaskSnapshot snapshot = await uploadTask;
            _imageUrl = await snapshot.ref.getDownloadURL(); // Get download URL
          } catch (e) {
            print('Error uploading image: $e'); // Log upload error
          }
        }

        // Save food details to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('pets')
            .doc(widget.petId)
            .collection('foods')
            .add({
          'foodName': _foodName,
          'foodType': _foodType,
          'carbs': _carbs,
          'protein': _protein,
          'fat': _fat,
          'calcium': _calcium,
          'vitamins': _vitamins,
          'imageUrl': _imageUrl ?? '',
          'timestamp': _selectedDateTime,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Food details added successfully!')), // Show success message
        );

        Navigator.of(context).pop(); // Go back to the previous screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error adding food details: $e')), // Show error message
        );
      } finally {
        setState(() {
          _isUploading = false; // Reset upload state
        });
      }
    }
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedImage =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path); // Set selected image
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Background color
      appBar: AppBar(
        backgroundColor: const Color(0xFFE2BF65), // AppBar color
        title: const Text(
          'Add Food Details',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0, // No shadow under AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Padding around the form
        child: Form(
          key: _formKey, // Assign form key
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomTextField('Food Name',
                    (value) => _foodName = value ?? ''), // Food name input
                const SizedBox(height: 20),
                _buildFoodTypeDropdown(), // Food type dropdown
                const SizedBox(height: 20),
                _buildCustomTextField('Carbohydrate (g)',
                    (value) => _carbs = double.tryParse(value ?? '0') ?? 0,
                    isNumeric: true), // Carbs input
                const SizedBox(height: 20),
                _buildCustomTextField('Protein (g)',
                    (value) => _protein = double.tryParse(value ?? '0') ?? 0,
                    isNumeric: true), // Protein input
                const SizedBox(height: 20),
                _buildCustomTextField('Fat (g)',
                    (value) => _fat = double.tryParse(value ?? '0') ?? 0,
                    isNumeric: true), // Fat input
                const SizedBox(height: 20),
                _buildCustomTextField('Calcium (g)',
                    (value) => _calcium = double.tryParse(value ?? '0') ?? 0,
                    isNumeric: true), // Calcium input
                const SizedBox(height: 20),
                _buildCustomTextField('Vitamins (g)',
                    (value) => _vitamins = double.tryParse(value ?? '0') ?? 0,
                    isNumeric: true), // Vitamins input
                const SizedBox(height: 20),
                _buildImagePicker(), // Image picker widget
                const SizedBox(height: 20),
                _isUploading
                    ? const Center(
                        child:
                            CircularProgressIndicator()) // Show loading spinner while uploading
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFE2BF65), // Button color
                            padding: const EdgeInsets.symmetric(
                                vertical: 16), // Button padding
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10), // Rounded corners
                            ),
                          ),
                          onPressed:
                              _saveFoodDetails, // Call save function on button press
                          child: const Text(
                            'Add Food',
                            style: TextStyle(
                                color: Colors.black), // Button text color
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Custom text field builder for form inputs
  Widget _buildCustomTextField(String label, Function(String?) onSaved,
      {bool isNumeric = false}) {
    return TextFormField(
      keyboardType: isNumeric
          ? TextInputType.number
          : TextInputType.text, // Numeric or text keyboard
      decoration: InputDecoration(
        labelText: label, // Field label
        labelStyle: const TextStyle(color: Colors.black87),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 16), // Padding inside the field
      ),
      onSaved: onSaved, // Save callback
      validator: (value) =>
          value!.isEmpty ? 'Please enter $label' : null, // Validation message
    );
  }

  // Dropdown for food type selection
  Widget _buildFoodTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _foodType, // Current selected value
      items: ['Dry', 'Wet'].map((type) {
        return DropdownMenuItem(
            value: type, child: Text(type)); // Dropdown items
      }).toList(),
      onChanged: (value) =>
          setState(() => _foodType = value!), // Update selected food type
      decoration: InputDecoration(
        labelText: 'Type of Food', // Field label
        labelStyle: const TextStyle(color: Colors.black87),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 16), // Padding inside the field
      ),
    );
  }

  // Widget for image picker
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage, // Open image picker on tap
      child: Container(
        height: 150, // Container height
        decoration: BoxDecoration(
          color: Colors.white, // Background color
          borderRadius: BorderRadius.circular(10), // Rounded corners
          border: Border.all(color: Colors.grey), // Border style
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10), // Rounded corners
                child: Image.file(
                  _selectedImage!, // Display selected image
                  fit: BoxFit.cover, // Image fit style
                  width: double.infinity, // Full width
                ),
              )
            : const Center(
                child: Text('Upload Image (optional)',
                    style: TextStyle(
                        color: Colors.black54))), // Prompt for image upload
      ),
    );
  }
}
