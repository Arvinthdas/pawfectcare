import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FoodDetailScreen extends StatefulWidget {
  final String foodId;
  final String userId;
  final String petId;

  FoodDetailScreen(
      {required this.foodId, required this.userId, required this.petId});

  @override
  _FoodDetailScreenState createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  TextEditingController? _foodNameController;
  TextEditingController? _calciumController;
  TextEditingController? _carbsController;
  TextEditingController? _fatController;
  TextEditingController? _proteinController;
  TextEditingController? _vitaminsController;

  String? _selectedFoodType;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  File? _imageFile;
  bool _isEditing = false;
  late DocumentSnapshot _latestFoodRecord;
  String? _imageUrl;

  final List<String> _foodTypes = [
    'Dry',
    'Wet',
    'Semi-Moist',
    'Raw',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _fetchFoodDetails();
  }

  Future<void> _fetchFoodDetails() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('foods')
          .doc(widget.foodId)
          .get();

      if (snapshot.exists) {
        setState(() {
          _latestFoodRecord = snapshot;
          _initializeFields();
          _imageUrl = _latestFoodRecord['imageUrl'];
        });
      } else {
        throw Exception("Food item not found");
      }
    } catch (e) {
      print('Error fetching food details: $e');
    }
  }

  void _initializeFields() {
    _foodNameController =
        TextEditingController(text: _latestFoodRecord['foodName']);
    _calciumController =
        TextEditingController(text: _latestFoodRecord['calcium'].toString());
    _carbsController =
        TextEditingController(text: _latestFoodRecord['carbs'].toString());
    _fatController =
        TextEditingController(text: _latestFoodRecord['fat'].toString());
    _proteinController =
        TextEditingController(text: _latestFoodRecord['protein'].toString());
    _vitaminsController =
        TextEditingController(text: _latestFoodRecord['vitamins'].toString());
    _selectedFoodType = _latestFoodRecord['foodType'];
    Timestamp dateTimestamp = _latestFoodRecord['timestamp'];
    final dateTime = dateTimestamp.toDate();
    _selectedDate = dateTime;
    _selectedTime = TimeOfDay.fromDateTime(dateTime);
  }

  @override
  void dispose() {
    _foodNameController?.dispose();
    _calciumController?.dispose();
    _carbsController?.dispose();
    _fatController?.dispose();
    _proteinController?.dispose();
    _vitaminsController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrl = null;
      });
    }
  }

  Future<String?> _uploadImageToStorage(String userId) async {
    if (_imageFile != null) {
      try {
        String fileName =
            'food_images/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(_imageFile!);
        TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
        return null;
      }
    }
    return null;
  }

  Future<void> _saveChanges() async {
    if (_foodNameController?.text.isEmpty ??
        true || _selectedFoodType == null) {
      _showMessage('Please fill in all required fields');
      return;
    }

    final updatedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    String? imageUrl = await _uploadImageToStorage(widget.userId) ?? _imageUrl;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('foods')
          .doc(widget.foodId)
          .update({
        'foodName': _foodNameController!.text,
        'foodType': _selectedFoodType,
        'calcium': double.tryParse(_calciumController?.text ?? '0') ?? 0,
        'carbs': double.tryParse(_carbsController?.text ?? '0') ?? 0,
        'fat': double.tryParse(_fatController?.text ?? '0') ?? 0,
        'protein': double.tryParse(_proteinController?.text ?? '0') ?? 0,
        'vitamins': double.tryParse(_vitaminsController?.text ?? '0') ?? 0,
        'imageUrl': imageUrl,
        'timestamp': Timestamp.fromDate(updatedDateTime),
      });

      setState(() {
        _imageUrl = imageUrl;
        _isEditing = false;
        _imageFile = null;
      });

      _showMessage('Changes saved successfully');
    } catch (e) {
      print('Error updating food item: $e');
      _showMessage('Failed to save changes: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        backgroundColor: Color(0xFFE2BF65),
        title: Text(
          'Food Details',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing
                ? _saveChanges
                : () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _foodNameController,
                decoration: InputDecoration(
                    labelText: 'Food Name', border: OutlineInputBorder()),
                enabled: _isEditing,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _calciumController,
                decoration: InputDecoration(
                    labelText: 'Calcium', border: OutlineInputBorder()),
                enabled: _isEditing,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _carbsController,
                decoration: InputDecoration(
                    labelText: 'Carbs', border: OutlineInputBorder()),
                enabled: _isEditing,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _fatController,
                decoration: InputDecoration(
                    labelText: 'Fat', border: OutlineInputBorder()),
                enabled: _isEditing,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _proteinController,
                decoration: InputDecoration(
                    labelText: 'Protein', border: OutlineInputBorder()),
                enabled: _isEditing,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _vitaminsController,
                decoration: InputDecoration(
                    labelText: 'Vitamins', border: OutlineInputBorder()),
                enabled: _isEditing,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedFoodType,
                items: _foodTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: _isEditing
                    ? (String? newValue) {
                        setState(() {
                          _selectedFoodType = newValue;
                        });
                      }
                    : null,
                decoration: InputDecoration(
                    labelText: 'Food Type', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  if (_isEditing) _selectDate(context);
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: TextEditingController(
                      text: DateFormat('dd/MM/yyyy').format(_selectedDate),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    enabled: true, // Allow interaction in editing mode
                  ),
                ),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  if (_isEditing) _selectTime(context);
                },
                child: AbsorbPointer(
                  child: TextField(
                    controller: TextEditingController(
                      text: _selectedTime.format(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Time',
                      suffixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    enabled: true, // Allow interaction in editing mode
                  ),
                ),
              ),
              SizedBox(height: 20),
              if (_imageFile != null)
                Column(
                  children: [
                    Image.file(_imageFile!, height: 150, width: 250),
                    if (_isEditing)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _imageFile = null;
                            _imageUrl = null;
                          });
                        },
                        child: Text('Remove Image'),
                      ),
                  ],
                ),
              if (_imageUrl != null &&
                  _imageUrl!.isNotEmpty &&
                  _imageFile == null)
                Column(
                  children: [
                    Image.network(_imageUrl!, height: 150, width: 250),
                    if (_isEditing)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _imageFile = null;
                            _imageUrl = null;
                          });
                        },
                        child: Text('Remove Image'),
                      ),
                  ],
                ),
              if (_isEditing)
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Pick Image'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
