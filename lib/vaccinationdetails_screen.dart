import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class VaccinationDetailScreen extends StatefulWidget {
  final DocumentSnapshot vaccinationRecord;
  final String petId;
  final String userId;

  VaccinationDetailScreen({
    required this.vaccinationRecord,
    required this.petId,
    required this.userId,
  });

  @override
  _VaccinationDetailScreenState createState() => _VaccinationDetailScreenState();
}

class _VaccinationDetailScreenState extends State<VaccinationDetailScreen> {
  late TextEditingController _vaccineNameController;
  late TextEditingController _clinicController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  File? _imageFile;
  bool _isEditing = false;
  late DocumentSnapshot _latestVaccinationRecord;

  @override
  void initState() {
    super.initState();
    _latestVaccinationRecord = widget.vaccinationRecord;
    _fetchLatestVaccinationRecord();
    _initializeFields();
  }

  Future<void> _fetchLatestVaccinationRecord() async {
    try {
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .doc(widget.vaccinationRecord.id)
          .get();

      setState(() {
        _latestVaccinationRecord = updatedRecord;
        _initializeFields();
      });
    } catch (e) {
      print('Error fetching latest vaccination record: $e');
    }
  }

  void _initializeFields() {
    _vaccineNameController = TextEditingController(
        text: _latestVaccinationRecord['vaccineName']);
    _clinicController =
        TextEditingController(text: _latestVaccinationRecord['clinic']);
    _notesController =
        TextEditingController(text: _latestVaccinationRecord['notes']);

    String dateStr = _latestVaccinationRecord['date'];
    try {
      final dateTime = DateFormat('dd/MM/yyyy HH:mm').parse(dateStr);
      _selectedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      _selectedTime = TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      print('Error parsing date: $e');
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _clinicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImageToStorage(String userId) async {
    if (_imageFile != null) {
      try {
        String fileName = 'vaccinations/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(_imageFile!);
        TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
        return '';
      }
    }
    return '';
  }

  Future<void> _saveChanges() async {
    if (_vaccineNameController.text.isEmpty ||
        _clinicController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
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
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(updatedDateTime);

    String imageUrl = await _uploadImageToStorage(widget.userId);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('pets')
        .doc(widget.petId)
        .collection('vaccinations')
        .doc(widget.vaccinationRecord.id)
        .update({
      'vaccineName': _vaccineNameController.text,
      'clinic': _clinicController.text,
      'notes': _notesController.text,
      'date': formattedDate,
      'documentUrl': imageUrl,
    });

    _scheduleNotification(updatedDateTime);
    _showMessage('Changes saved successfully');
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _scheduleNotification(DateTime scheduledTime) async {
    FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'vaccine_channel_id',
      'Vaccination Notifications',
      channelDescription: 'Reminder for upcoming vaccinations',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    await notificationsPlugin.zonedSchedule(
      widget.vaccinationRecord.hashCode,
      'Vaccination Reminder',
      'Your pet has a vaccination appointment',
      scheduledDate,
      platformDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Widget _buildImageDisplay() {
    if (_imageFile != null) {
      return Column(
        children: [
          GestureDetector(
            onTap: () {
              if (_isEditing) {
                _showRemoveImageDialog();
              }
            },
            child: Image.file(
              _imageFile!,
              height: 150,
              width: 150,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 10),
        ],
      );
    } else {
      String? documentUrl = _latestVaccinationRecord.data() != null &&
          (_latestVaccinationRecord.data() as Map<String, dynamic>)
              .containsKey('documentUrl')
          ? _latestVaccinationRecord['documentUrl']
          : null;

      if (documentUrl != null && documentUrl.isNotEmpty) {
        return Column(
          children: [
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _showRemoveImageDialog();
                }
              },
              child: Image.network(
                documentUrl,
                height: 150,
                width: 150,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 10),
          ],
        );
      } else {
        return Text('No image uploaded');
      }
    }
  }

  void _showRemoveImageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove Image'),
          content: Text('Are you sure you want to remove this image?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _removeImage(); // Remove image from the UI
              },
              child: Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  void _removeImage() {
    // Clear the image locally and update the Firestore record
    setState(() {
      _imageFile = null; // Clear the local image file

      // Clear the documentUrl in the local _latestVaccinationRecord
      if (_latestVaccinationRecord.data() != null) {
        Map<String, dynamic> updatedData = Map<String, dynamic>.from(
            _latestVaccinationRecord.data() as Map<String, dynamic>);
        updatedData['documentUrl'] = ''; // Clear the image URL
        _latestVaccinationRecord = _latestVaccinationRecord;
      }
    });

    // Now update Firestore to reflect the changes
    _removeImageFromFirestore();
  }

  Future<void> _removeImageFromFirestore() async {
    try {
      // Update Firestore to remove the image URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .doc(widget.vaccinationRecord.id)
          .update({'documentUrl': ''});

      // After removing from Firestore, we should fetch the latest data to update the local state
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .doc(widget.vaccinationRecord.id)
          .get();

      setState(() {
        _latestVaccinationRecord = updatedRecord;
      });

      _showMessage('Image removed successfully.');
    } catch (e) {
      print('Error removing image from Firestore: $e');
      _showMessage('Failed to remove the image.');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Vaccination Details'),
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
          children: [
            TextField(
              controller: _vaccineNameController,
              decoration: InputDecoration(labelText: 'Vaccine Name', labelStyle: TextStyle(color: Color(0xFFE2BF65))),
              enabled: _isEditing,
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectDate(context);
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: TextEditingController(
                      text: _selectedDate != null
                          ? "${_selectedDate.toLocal()}".split(' ')[0]
                          : ''),
                  decoration: InputDecoration(
                    labelText: 'Vaccination Date',
                    labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  enabled: _isEditing,
                ),
              ),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectTime(context);
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: TextEditingController(
                      text: _selectedTime.format(context)),
                  decoration: InputDecoration(
                    labelText: 'Vaccination Time',
                    labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  enabled: _isEditing,
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _clinicController,
              decoration: InputDecoration(labelText: 'Clinic', labelStyle: TextStyle(color: Color(0xFFE2BF65))),
              enabled: _isEditing,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: 'Notes', labelStyle: TextStyle(color: Color(0xFFE2BF65))),
              enabled: _isEditing,
            ),
            SizedBox(height: 20),
            _buildImageDisplay(),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isEditing ? _pickImage : null,
              child: Text('Upload New Image'),
            ),
          ],
        ),
      ),
    );
  }
}
