import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AddGroomingScreen extends StatefulWidget {
  final String petId;
  final String userId;

  AddGroomingScreen({required this.petId, required this.userId});

  @override
  _AddGroomingScreenState createState() => _AddGroomingScreenState();
}

class _AddGroomingScreenState extends State<AddGroomingScreen> {
  final _taskNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _productsUsedController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isUploading = false;
  File? _selectedImage;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Add Grooming Details',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFE2BF65),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Grooming Task Name *', _taskNameController),
            SizedBox(height: 15),
            _buildDateTimeField(),
            SizedBox(height: 15),
            _buildTextField('Products Used', _productsUsedController),
            SizedBox(height: 15),
            _buildTextField('Notes', _notesController, maxLines: 3),
            SizedBox(height: 15),
            _buildUploadImageSection(),
            SizedBox(height: 20),
            _isUploading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addGroomingTask,
                child: Text('Add Grooming Task'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Color(0xFFE2BF65),
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter $label',
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeField() {
    return GestureDetector(
      onTap: _selectDateTime,
      child: AbsorbPointer(
        child: _buildTextField('Date & Time of Grooming *', _dateController),
      ),
    );
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

        String formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime);
        setState(() {
          _dateController.text = formattedDateTime;
        });
      }
    }
  }

  Widget _buildUploadImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Image (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        Container(
          height: 150,
          color: Colors.grey[200],
          child: _selectedImage == null
              ? Center(child: Text('Image Preview'))
              : Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Document/Image'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Color(0xFFE2BF65),
              ),
            ),
            if (_selectedImage != null) // Show remove button only if an image is selected
              SizedBox(width: 10),
            if (_selectedImage != null)
              ElevatedButton(
                onPressed: _removeImage,
                child: Text('Remove Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Color(0xFFE2BF65), // Red color for remove button
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _addGroomingTask() async {
    if (_taskNameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final DateTime groomingDate = DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);
      String? imageUrl;

      if (_selectedImage != null) {
        imageUrl = await _uploadImageToFirebase(_selectedImage!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .add({
        'taskName': _taskNameController.text,
        'date': groomingDate,
        'productsUsed': _productsUsedController.text,
        'notes': _notesController.text,
        'imageUrl': imageUrl, // Save image URL
      });

      // Schedule notification
      await _scheduleNotification(groomingDate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grooming task added successfully!')),
      );

      // Clear form and go back to the previous screen
      _clearForm();
      Navigator.pop(context); // This line pops the current screen off the navigation stack
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding grooming task: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'grooming_tasks/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL(); // Get download URL
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _scheduleNotification(DateTime groomingDate) async {
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(groomingDate, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'grooming_channel',
      'Grooming Notifications',
      channelDescription: 'Channel for grooming notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Grooming Reminder',
        'Your pet is scheduled for grooming!',
        scheduledDate,
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
      );
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }

  void _clearForm() {
    _taskNameController.clear();
    _dateController.clear();
    _productsUsedController.clear();
    _notesController.clear();
    setState(() {
      _selectedImage = null; // Clear the selected image
    });
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _dateController.dispose();
    _productsUsedController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

