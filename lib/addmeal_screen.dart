import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AddMealScreen extends StatefulWidget {
  final String petId;
  final String userId;
  final String petName;

  AddMealScreen({required this.petId, required this.userId, required this.petName});

  @override
  _AddMealScreenState createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final TextEditingController _mealNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _addMeal() async {
    if (_mealNameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      DateTime mealDate = DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);
      String? imageUrl;

      if (_selectedImage != null) {
        imageUrl = await _uploadImageToFirebase(_selectedImage!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('meals')
          .add({
        'mealName': _mealNameController.text,
        'date': mealDate,
        'notes': _notesController.text,
        'imageUrl': imageUrl,
      });

      // Schedule notification
      await _scheduleNotification(mealDate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meal added successfully!')),
      );

      // Clear form and go back to the previous screen
      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding meal: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'meals/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _scheduleNotification(DateTime mealDate) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'meal_channel',
      'Meal Notifications',
      channelDescription: 'Channel for meal notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Meal Reminder',
      'Do not forget to prepare meal for ${widget.petName}',
      tz.TZDateTime.from(mealDate, tz.local),
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _clearForm() {
    _mealNameController.clear();
    _dateController.clear();
    _notesController.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Meal',style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        )),
        backgroundColor: Color(0xFFE2BF65),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _mealNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter Meal Name',
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 15),
            Text('Date & Time *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter Date & Time',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              readOnly: true,
              onTap: _selectDateTime,
            ),
            SizedBox(height: 15),
            Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter Notes',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              maxLines: 3,
            ),
            SizedBox(height: 15),
            Text('Upload Image (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Container(
              height: 150,
              color: Colors.grey[200],
              child: _selectedImage == null
                  ? Center(child: Text('Image Preview'))
                  : Stack(
                children: [
                  Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        color: Colors.black54,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE2BF65),
                foregroundColor: Colors.black,
              ),
            ),
            SizedBox(height: 20),
            _isUploading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addMeal,
                child: Text('Add Meal',
                style: TextStyle(
                  color: Colors.black,
                ),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE2BF65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        String formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime);
        setState(() {
          _dateController.text = formattedDateTime;
        });
      }
    }
  }
}
