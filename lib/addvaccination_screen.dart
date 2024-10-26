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
  final String petName;

  AddVaccinationScreen({required this.petId, required this.userId, required this.petName});

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

  Future<void> _pickDocument() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedDocument = File(pickedFile.path);
      });
    }
  }

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

    DateTime? vaccinationDate;
    try {
      vaccinationDate =
          DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);
      if (vaccinationDate.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a future date and time.')),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid date format.')),
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

      if (_selectedDocument != null) {
        documentUrl = await _uploadImageToStorage(uid, _selectedDocument!);
      }

      try {
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

        await _scheduleNotification(vaccinationDate, _vaccineNameController.text, widget.petName);

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

      Navigator.pop(context);
    }
  }

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

  Future<void> _scheduleNotification(DateTime vaccinationDate,String title, String petName) async {
    tz.TZDateTime scheduledDate =
    tz.TZDateTime.from(vaccinationDate, tz.local);

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
          '$petName `s $title vaccination appointment',
        scheduledDate,
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }

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
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        String formattedDateTime =
        DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime);

        setState(() {
          _dateController.text = formattedDateTime;
        });
      }
    }
  }

  void _clearForm() {
    _vaccineNameController.clear();
    _dateController.clear();
    _veterinarianController.clear();
    _clinicController.clear();
    _notesController.clear();
    setState(() {
      _selectedDocument = null;
      _isUploading = false;
    });
  }

  Future<void> _removeImage() async {
    bool? confirmed = await _showConfirmationDialog(
      title: 'Confirm Removal',
      content: 'Are you sure you want to remove the image?',
    );

    if (confirmed == true) {
      setState(() {
        _selectedDocument = null; // Clear the selected document
      });
    }
  }

  Future<bool?> _showConfirmationDialog({required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE2BF65)),
              child: Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreview() {
    if (_selectedDocument != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.file(
                _selectedDocument!,
                height: 200,
                width: 380,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(
        height: 200,
        width: 380,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(child: Text('No Image Selected')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Vaccination Details',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),),
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
            Text('Upload Image', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            _buildImagePreview(), // Update to only show the image without the button
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _pickDocument,
                  child: Text('Pick Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE2BF65),
                    foregroundColor: Colors.black,
                  ),
                ),
                if (_selectedDocument != null) // Only show this button if there is an image selected
                  TextButton(
                    onPressed: _removeImage,
                    child: Text('Remove Image'),
                    style: TextButton.styleFrom(
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
