import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class AddFoodScreen extends StatefulWidget {
  final String petId;
  final String userId;

  AddFoodScreen({required this.petId, required this.userId});

  @override
  _AddFoodScreenState createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  String _foodName = '';
  String _foodType = 'Dry';
  double _carbs = 0;
  double _protein = 0;
  double _fat = 0;
  double _calcium = 0;
  double _vitamins = 0;
  File? _selectedImage;
  String? _imageUrl;
  bool _isUploading = false;
  DateTime _selectedDateTime = DateTime.now();

  Future<void> _saveFoodDetails() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      setState(() {
        _isUploading = true;
      });

      try {
        if (_selectedImage != null) {
          try {
            String fileName = 'food_images/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
            Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
            UploadTask uploadTask = storageRef.putFile(_selectedImage!);
            TaskSnapshot snapshot = await uploadTask;
            _imageUrl = await snapshot.ref.getDownloadURL();
          } catch (e) {
            print('Error uploading image: $e');
          }
        }


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
          SnackBar(content: Text('Food details added successfully!')),
        );

        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding food details: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      setState(() {
        _selectedImage = File(pickedImage.path);
      });
    }
  }

  Future<void> _selectDateAndTime(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        backgroundColor: Color(0xFFE2BF65), // Change to a warm amber color
        title: Text('Add Food Details',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
      ),
      //backgroundColor: Colors.grey[100], // Light grey background color
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomTextField('Food Name', (value) => _foodName = value ?? ''),
                SizedBox(height: 20),
                _buildFoodTypeDropdown(),
                SizedBox(height: 20),
                _buildCustomTextField('Carbohydrate (g)', (value) => _carbs = double.tryParse(value ?? '0') ?? 0, isNumeric: true),
                SizedBox(height: 20),
                _buildCustomTextField('Protein (g)', (value) => _protein = double.tryParse(value ?? '0') ?? 0, isNumeric: true),
                SizedBox(height: 20),
                _buildCustomTextField('Fat (g)', (value) => _fat = double.tryParse(value ?? '0') ?? 0, isNumeric: true),
                SizedBox(height: 20),
                _buildCustomTextField('Calcium (g)', (value) => _calcium = double.tryParse(value ?? '0') ?? 0, isNumeric: true),
                SizedBox(height: 20),
                _buildCustomTextField('Vitamins (g)', (value) => _vitamins = double.tryParse(value ?? '0') ?? 0, isNumeric: true),
                SizedBox(height: 20),
                _buildImagePicker(),
                SizedBox(height: 20),
                _isUploading
                    ? Center(child: CircularProgressIndicator())
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE2BF65),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _saveFoodDetails,
                    child: Text('Add Food',
                      style: TextStyle(color: Colors.black),
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

  Widget _buildCustomTextField(String label, Function(String?) onSaved, {bool isNumeric = false}) {
    return TextFormField(
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text, // Set numeric or text keyboard based on isNumeric
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black87),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onSaved: onSaved,
      validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
    );
  }

  Widget _buildFoodTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _foodType,
      items: ['Dry', 'Wet'].map((type) {
        return DropdownMenuItem(value: type, child: Text(type));
      }).toList(),
      onChanged: (value) => setState(() => _foodType = value!),
      decoration: InputDecoration(
        labelText: 'Type of Food',
        labelStyle: TextStyle(color: Colors.black87),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey),
        ),
        child: _selectedImage != null
            ? ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        )
            : Center(child: Text('Upload Image (optional)', style: TextStyle(color: Colors.black54))),
      ),
    );
  }
}
