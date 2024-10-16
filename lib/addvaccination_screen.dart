import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AddVaccinationScreen extends StatefulWidget {
  final String petId;
  final String userId;

  AddVaccinationScreen({required this.petId, required this.userId});

  @override
  _AddVaccinationScreenState createState() => _AddVaccinationScreenState();
}

class _AddVaccinationScreenState extends State<AddVaccinationScreen> {
  final _vaccineNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _veterinarianController = TextEditingController();
  final _clinicController = TextEditingController();
  final _notesController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedDocument;
  bool _isUploading = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    tz.initializeTimeZones(); // Initialize time zones
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur')); // Set Malaysia Time
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create the notification channel
    _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'vaccination_channel', // Channel ID
      'Vaccination Notifications', // Channel name
      description: 'This channel is for vaccination notifications',
      importance: Importance.max, // Importance level
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  // Function to pick an image or document from the device
  Future<void> _pickDocument() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedDocument = File(pickedFile.path);
      });
    }
  }

  // Function to save vaccination details to Firestore
  Future<void> _addVaccination() async {
    if (_vaccineNameController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _veterinarianController.text.isEmpty ||
        _clinicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _isUploading = true;
      });

      String uid = user.uid;
      String documentUrl = '';

      // Upload document to storage if selected
      if (_selectedDocument != null) {
        documentUrl = await _uploadImageToStorage(uid, _selectedDocument!);
      }

      try {
        // Parse the vaccination date
        DateTime vaccinationDateTime =
        DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);

        // Ensure you are scheduling for a future time
        if (vaccinationDateTime.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a future date and time.')),
          );
          return;
        }

        // Add vaccination details to Firestore
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('pets')
            .doc(widget.petId)
            .collection('vaccinations')
            .add({
          'vaccineName': _vaccineNameController.text,
          'date': _dateController.text,
          'veterinarian': _veterinarianController.text,
          'clinic': _clinicController.text,
          'notes': _notesController.text,
          'documentUrl': documentUrl,
        });

        // Schedule notification
        await _scheduleNotification(vaccinationDateTime);

        // Show confirmation and clear the form
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vaccination added successfully!')),
        );
        _clearForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding vaccination: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }

      Navigator.pop(context); // Go back after adding the vaccination
    }
  }

  // Function to upload an image to Firebase Storage
  Future<String> _uploadImageToStorage(String uid, File imageFile) async {
    try {
      String fileName =
          'vaccinations/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }

  // Function to schedule notification
  Future<void> _scheduleNotification(DateTime vaccinationDate) async {
    tz.TZDateTime scheduledDate =
    tz.TZDateTime.from(vaccinationDate, tz.local); // Ensure using local time

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'vaccination_channel',
      'Vaccination Notifications',
      channelDescription: 'Channel for vaccination notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Vaccination Reminder',
        'Your pet is due for a vaccination!',
        scheduledDate,
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }

  // Function to show Date and Time Picker
  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        // Combine picked date and time
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Format the selected date and time
        String formattedDateTime =
        DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime);

        setState(() {
          _dateController.text = formattedDateTime;
        });
      }
    }
  }

  // Function to clear the form
  void _clearForm() {
    _vaccineNameController.clear();
    _dateController.clear();
    _veterinarianController.clear();
    _clinicController.clear();
    _notesController.clear();
    _selectedDocument = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Vaccination Details'),
        backgroundColor: Color(0xFFE2BF65),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vaccine Name *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _vaccineNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter vaccine name',
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 15),
            Text('Date & Time of Vaccine *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter date and time',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              readOnly: true,
              onTap: _selectDateTime,
            ),
            SizedBox(height: 15),
            Text('Veterinarian *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _veterinarianController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter veterinarian name',
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 15),
            Text('Clinic Name *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _clinicController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter clinic name',
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 15),
            Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter any notes',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              maxLines: 3,
            ),
            SizedBox(height: 15),
            Text('Upload Document/Image', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            _selectedDocument != null
                ? Image.file(
              _selectedDocument!,
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
            ElevatedButton(
              onPressed: _pickDocument,
              child: Text('Pick Document/Image'),
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
                onPressed: _addVaccination,
                child: Text('Add Vaccination'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE2BF65),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
