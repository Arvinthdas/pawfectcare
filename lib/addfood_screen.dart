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
        // Upload image if selected
        if (_selectedImage != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('user_uploads/${widget.userId}/pets/${widget.petId}/foods/${DateTime.now().millisecondsSinceEpoch}.jpg');

          final uploadTask = storageRef.putFile(_selectedImage!);
          final snapshot = await uploadTask;
          _imageUrl = await snapshot.ref.getDownloadURL();
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
          'timestamp': _selectedDateTime, // Store selected date and time
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
    // Show date picker
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), // Prevent future dates
    );

    if (pickedDate != null) {
      // Show time picker
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
      appBar: AppBar(
        title: Text('Add Food Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'Food Name'),
                  onSaved: (value) => _foodName = value ?? '',
                  validator: (value) => value!.isEmpty ? 'Please enter a food name' : null,
                ),
                DropdownButtonFormField<String>(
                  value: _foodType,
                  items: ['Dry', 'Wet'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) => setState(() => _foodType = value!),
                  decoration: InputDecoration(labelText: 'Type of Food'),
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Carbs (g)'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _carbs = double.tryParse(value ?? '0') ?? 0,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Protein (g)'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _protein = double.tryParse(value ?? '0') ?? 0,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Fat (g)'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _fat = double.tryParse(value ?? '0') ?? 0,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Calcium (mg)'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _calcium = double.tryParse(value ?? '0') ?? 0,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Vitamins (IU)'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _vitamins = double.tryParse(value ?? '0') ?? 0,
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickImage,
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, height: 200)
                      : Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(child: Text('Tap to select an image')),
                  ),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () => _selectDateAndTime(context),
                  child: Text('Select Date & Time: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime)}'),
                ),
                SizedBox(height: 20),
                _isUploading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _saveFoodDetails,
                  child: Text('Add Food'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
