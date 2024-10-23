import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MealDetailScreen extends StatefulWidget {
  final DocumentSnapshot mealRecord;
  final String petId;
  final String userId;

  MealDetailScreen({required this.mealRecord, required this.petId, required this.userId});

  @override
  _MealDetailScreenState createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late TextEditingController _mealNameController;
  late TextEditingController _notesController;
  late TextEditingController _dateController;
  File? _selectedImage;
  bool _isEditing = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _mealNameController = TextEditingController(text: widget.mealRecord['mealName']);
    _notesController = TextEditingController(text: widget.mealRecord['notes']);
    Timestamp dateTimestamp = widget.mealRecord['date'];
    _dateController = TextEditingController(text: DateFormat('dd/MM/yyyy HH:mm').format(dateTimestamp.toDate()));
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

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

  Future<void> _saveChanges() async {
    if (_mealNameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      DateTime mealDate = DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);
      String? imageUrl;

      // If a new image is selected, upload it
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToFirebase(_selectedImage!);
      } else {
        imageUrl = widget.mealRecord['imageUrl']; // Keep the existing image URL if no new image is uploaded
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('meals')
          .doc(widget.mealRecord.id)
          .update({
        'mealName': _mealNameController.text,
        'date': mealDate,
        'notes': _notesController.text,
        'imageUrl': imageUrl, // Update the image URL
      });

      // Reschedule notification
      await _rescheduleNotification(mealDate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Changes saved successfully!')),
      );

      // Go back to the previous screen
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating meal: $e')),
      );
    }
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'meals/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL(); // Get download URL
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _rescheduleNotification(DateTime mealDate) async {
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
      'Your pet has a meal scheduled!',
      tz.TZDateTime.from(mealDate, tz.local),
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Details'),
        backgroundColor: Color(0xFFE2BF65),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveChanges,
            )
          else
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _mealNameController,
              decoration: InputDecoration(labelText: 'Meal Name', border: OutlineInputBorder()),
              enabled: _isEditing,
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectDateTime();
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: _dateController,
                  decoration: InputDecoration(labelText: 'Date & Time', border: OutlineInputBorder()),
                  enabled: false, // Disable user input directly
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              enabled: _isEditing,
            ),
            SizedBox(height: 10),
            Text('Upload New Image (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Container(
              height: 150,
              color: Colors.grey[200],
              child: _selectedImage == null
                  ? (widget.mealRecord['imageUrl'] != null
                  ? Image.network(
                widget.mealRecord['imageUrl'],
                fit: BoxFit.cover,
              )
                  : Center(child: Text('No Image Preview')))
                  : Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 10),
            if (_isEditing)
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Pick New Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE2BF65),
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
        lastDate: DateTime(2101,
        ));

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
