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
  final String petName;

  GroomingDetailScreen({
    required this.groomingRecord,
    required this.petId,
    required this.userId,
    required this.petName
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
  File? _imageFile; // Holds the newly uploaded image
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
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImageToStorage(String userId) async {
    if (_imageFile != null) {
      try {
        String fileName = 'grooming_tasks/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
          .doc(widget.groomingRecord.id)
          .update({
        'taskName': _taskNameController.text,
        'productsUsed': _productsUsedController.text,
        'notes': _notesController.text,
        'date': updatedDateTime,
        if (imageUrl != null) 'imageUrl': imageUrl, // Update with the new image URL
      });

      _scheduleNotification(updatedDateTime, _taskNameController.text, widget.petName);
      _showMessage('Changes saved successfully');

      // Refresh latest grooming record to show the new image
      await _fetchLatestGroomingRecord();

      setState(() {
        _isEditing = false;
        _imageFile = null; // Clear the uploaded image after saving
      });
    } catch (e) {
      print('Error updating grooming task: $e');
      _showMessage('Failed to save changes: $e');
    }
  }

  Future<void> _scheduleNotification(DateTime scheduledTime,String title, String petName) async {
    FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'grooming_channel_id',
      'Grooming Notifications',
      channelDescription: 'Reminder for upcoming grooming tasks',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    await notificationsPlugin.zonedSchedule(
      widget.groomingRecord.hashCode,
      'Grooming Reminder',
      '${widget.petName} got a $title grooming appointment',
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
          .update({'imageUrl': ''}); // Clear image URL

      // Fetch the updated record
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .doc(widget.groomingRecord.id)
          .get();

      setState(() {
        _latestGroomingRecord = updatedRecord; // Update the state
      });

      _showMessage('Image removed successfully.');
    } catch (e) {
      print('Error removing image from Firestore: $e');
      _showMessage('Failed to remove the image.');
    }
  }

  Widget _buildImageDisplay() {
    return Container(
      height: 200,
      width: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        color: Colors.grey[200],
      ),
      child: _imageFile != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          _imageFile!,
          fit: BoxFit.cover,
        ),
      )
          : (_latestGroomingRecord.data() != null &&
          (_latestGroomingRecord.data() as Map<String, dynamic>)['imageUrl'] != null &&
          (_latestGroomingRecord.data() as Map<String, dynamic>)['imageUrl'] != '')
          ? ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          (_latestGroomingRecord.data() as Map<String, dynamic>)['imageUrl'],
          fit: BoxFit.cover,
        ),
      )
          : Center(child: Text('No image uploaded')),
    );
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

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        fillColor: Colors.grey[200],
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.black,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.black,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Color(0xFFDAA520),
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        hintText: 'Enter $label',
        hintStyle: TextStyle(
          color: Colors.grey[500],
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text(
          'Grooming Details',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
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
            _buildStyledTextField(
              controller: _taskNameController,
              label: 'Task Name',
              enabled: _isEditing,
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectDate(context);
                }
              },
              child: AbsorbPointer(
                child: _buildStyledTextField(
                  controller: TextEditingController(
                      text: DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  label: 'Date',
                  enabled: _isEditing,
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectTime(context);
                }
              },
              child: AbsorbPointer(
                child: _buildStyledTextField(
                  controller: TextEditingController(
                      text: _selectedTime.format(context)),
                  label: 'Time',
                  enabled: _isEditing,
                  suffixIcon: Icon(Icons.access_time),
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildStyledTextField(
              controller: _productsUsedController,
              label: 'Products Used',
              enabled: _isEditing,
            ),
            SizedBox(height: 20),
            _buildStyledTextField(
              controller: _notesController,
              label: 'Notes',
              enabled: _isEditing,
              maxLines: 3,
            ),
            SizedBox(height: 20),
            _buildImageDisplay(),
            SizedBox(height: 20),
            if (_isEditing)
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Upload New Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Color(0xFFE2BF65),
                ),
              ),
            if (_isEditing &&
                (_latestGroomingRecord['imageUrl'] != null &&
                    _latestGroomingRecord['imageUrl'] != '' || _imageFile != null))
              ElevatedButton(
                onPressed: _showRemoveImageDialog,
                child: Text('Remove Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Color(0xFFE2BF65),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
