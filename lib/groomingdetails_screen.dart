import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class GroomingDetailScreen extends StatefulWidget {
  final DocumentSnapshot groomingRecord;
  final String petId;
  final String userId;

  GroomingDetailScreen({
    required this.groomingRecord,
    required this.petId,
    required this.userId,
  });

  @override
  _GroomingDetailScreenState createState() => _GroomingDetailScreenState();
}

class _GroomingDetailScreenState extends State<GroomingDetailScreen> {
  late TextEditingController _taskNameController;
  late TextEditingController _productsUsedController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  File? _imageFile;
  bool _isEditing = false;
  late DocumentSnapshot _latestGroomingRecord;

  @override
  void initState() {
    super.initState();
    _latestGroomingRecord = widget.groomingRecord;
    _fetchLatestGroomingRecord();
    _initializeFields();
  }

  Future<void> _fetchLatestGroomingRecord() async {
    try {
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .doc(widget.groomingRecord.id)
          .get();

      setState(() {
        _latestGroomingRecord = updatedRecord;
        _initializeFields();
      });
    } catch (e) {
      print('Error fetching latest grooming record: $e');
    }
  }

  void _initializeFields() {
    _taskNameController =
        TextEditingController(text: _latestGroomingRecord['taskName']);
    _productsUsedController =
        TextEditingController(text: _latestGroomingRecord['productsUsed']);
    _notesController =
        TextEditingController(text: _latestGroomingRecord['notes']);

    Timestamp dateTimestamp = _latestGroomingRecord['date'];
    final dateTime = dateTimestamp.toDate();
    _selectedDate = dateTime;
    _selectedTime = TimeOfDay.fromDateTime(dateTime);
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _productsUsedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToStorage(String userId) async {
    if (_imageFile != null) {
      try {
        String fileName =
            'grooming_tasks/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
    if (_taskNameController.text.isEmpty) {
      _showMessage('Please fill in all required fields');
      return;
    }

    // Debugging print statements
    print('User ID: ${widget.userId}');
    print('Pet ID: ${widget.petId}');
    print('Grooming Record ID: ${widget.groomingRecord.id}');

    // Null checks for the IDs
    if (widget.userId.isEmpty ||
        widget.petId.isEmpty ||
        widget.groomingRecord.id.isEmpty) {
      _showMessage('Invalid user, pet, or grooming record ID.');
      return;
    }

    final updatedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    String? imageUrl = await _uploadImageToStorage(widget.userId);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .doc(widget.groomingRecord.id) // Ensure this is not null or empty
          .update({
        'taskName': _taskNameController.text,
        'productsUsed': _productsUsedController.text,
        'notes': _notesController.text,
        'date': updatedDateTime,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });

      _scheduleNotification(updatedDateTime);
      _showMessage('Changes saved successfully');
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      print('Error updating grooming task: $e');
      _showMessage('Failed to save changes: $e');
    }
  }

  Future<void> _scheduleNotification(DateTime scheduledTime) async {
    FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'grooming_channel_id',
      'Grooming Notifications',
      channelDescription: 'Reminder for upcoming grooming tasks',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    await notificationsPlugin.zonedSchedule(
      widget.groomingRecord.hashCode,
      'Grooming Reminder',
      'Your pet has a grooming appointment',
      scheduledDate,
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    setState(() {
      _imageFile = null; // Clear the local image file

      if (_latestGroomingRecord.data() != null) {
        Map<String, dynamic> updatedData = Map<String, dynamic>.from(
            _latestGroomingRecord.data() as Map<String, dynamic>);
        updatedData['imageUrl'] = ''; // Clear the image URL
        _latestGroomingRecord = _latestGroomingRecord;
      }
    });

    _removeImageFromFirestore();
  }

  Future<void> _removeImageFromFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .doc(widget.groomingRecord.id)
          .update({'imageUrl': ''});

      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .doc(widget.groomingRecord.id)
          .get();

      setState(() {
        _latestGroomingRecord = updatedRecord;
      });

      _showMessage('Image removed successfully.');
    } catch (e) {
      print('Error removing image from Firestore: $e');
      _showMessage('Failed to remove the image.');
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
      String? imageUrl =
          (_latestGroomingRecord.data() as Map<String, dynamic>)['imageUrl'];

      if (imageUrl != null && imageUrl.isNotEmpty) {
        return Column(
          children: [
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _showRemoveImageDialog();
                }
              },
              child: Image.network(
                imageUrl,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Grooming Details'),
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
              controller: _taskNameController,
              decoration: InputDecoration(
                  labelText: 'Task Name',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65))),
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
                      text: DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  decoration: InputDecoration(
                    labelText: 'Date',
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
                    labelText: 'Time',
                    labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  enabled: _isEditing,
                ),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _productsUsedController,
              decoration: InputDecoration(
                  labelText: 'Products Used',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65))),
              enabled: _isEditing,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65))),
              enabled: _isEditing,
            ),
            SizedBox(height: 20),
            _buildImageDisplay(),
            SizedBox(height: 10),
            if (_isEditing)
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Upload New Image'),
              ),
          ],
        ),
      ),
    );
  }
}
