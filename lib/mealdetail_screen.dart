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
  bool _imageRemoved = false; // To track if the user removed the uploaded image
  final _formKey = GlobalKey<FormState>();

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
        _imageRemoved = false; // Reset the image removal flag
      });
    }
  }

  Future<void> _removeImage() async {
    if (_selectedImage != null) {
      setState(() {
        _selectedImage = null; // Clear the newly selected image
      });
    } else {
      setState(() {
        _imageRemoved = true; // Mark that the previously uploaded image was removed
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if the form is invalid
    }

    bool confirmSave = await _showConfirmationDialog();
    if (!confirmSave) {
      return; // Don't proceed if the user cancels
    }

    try {
      DateTime mealDate = DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);
      String? imageUrl = widget.mealRecord['imageUrl'];

      // If a new image is selected, upload it
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToFirebase(_selectedImage!);
      }

      // If the image was removed by the user, delete the previous image from Firestore and Firebase Storage
      if (_imageRemoved && widget.mealRecord['imageUrl'] != null) {
        await _deleteImageFromFirebase(widget.mealRecord['imageUrl']);
        imageUrl = null; // Set the image URL to null after deletion
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

      // Check if the meal date is in the future before scheduling a notification
      if (mealDate.isAfter(DateTime.now())) {
        // Reschedule notification
        await _rescheduleNotification(mealDate);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification was not rescheduled because the date is not in the future.')),
        );
      }

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

  Future<void> _deleteImageFromFirebase(String imageUrl) async {
    try {
      // Extract the file path from the image URL and delete it from Firebase Storage
      Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image removed successfully!')),
      );
    } catch (e) {
      print('Error deleting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing image: $e')),
      );
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

  Future<bool> _showConfirmationDialog() async {
    return (await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Save'),
          content: Text('Are you sure you want to save the changes?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    )) ?? false;
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _mealNameController,
                decoration: InputDecoration(labelText: 'Meal Name', border: OutlineInputBorder()),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the meal name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  if (_isEditing) {
                    _selectDateTime();
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dateController,
                    decoration: InputDecoration(labelText: 'Date & Time', border: OutlineInputBorder()),
                    enabled: false, // Disable user input directly
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select the date and time';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
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
                child: _selectedImage != null
                    ? Stack(
                  children: [
                    Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
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
                )
                    : (_imageRemoved || widget.mealRecord['imageUrl'] == null)
                    ? Center(child: Text('No Image Preview'))
                    : Stack(
                  children: [
                    Image.network(widget.mealRecord['imageUrl'], fit: BoxFit.cover, width: double.infinity),
                    if (_isEditing)
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
