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
  final String petId; // ID of the pet
  final String userId; // ID of the user
  final String petName; // Name of the pet

  AddMealScreen({required this.petId, required this.userId, required this.petName});

  @override
  _AddMealScreenState createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final TextEditingController _mealNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  File? _selectedImage; // Variable for the selected image
  bool _isUploading = false; // Flag to indicate upload status

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(); // For local notifications

  @override
  void initState() {
    super.initState();
    _initializeNotifications(); // Initialize notifications
  }

  // Initialize notification settings
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // Set the selected image
      });
    }
  }

  // Function to add meal details
  Future<void> _addMeal() async {
    if (_mealNameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')), // Show error if fields are empty
      );
      return;
    }

    setState(() {
      _isUploading = true; // Start the upload process
    });

    try {
      DateTime mealDate = DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text); // Parse date
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToFirebase(_selectedImage!);
      }

      // Add meal details to Firestore
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
        'imageUrl': imageUrl, // Optional image URL
      });

      // Schedule a notification for the meal
      await _scheduleNotification(mealDate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meal added successfully!')), // Success message
      );

      // Clear the form and go back
      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding meal: $e')), // Error message
      );
    } finally {
      setState(() {
        _isUploading = false; // Stop the upload process
      });
    }
  }

  // Function to upload an image to Firebase Storage
  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'meals/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Unique file name
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName); // Reference to storage
      UploadTask uploadTask = storageRef.putFile(imageFile); // Upload task
      TaskSnapshot snapshot = await uploadTask; // Wait for completion
      return await snapshot.ref.getDownloadURL(); // Get download URL
    } catch (e) {
      print('Error uploading image: $e'); // Log error
      return null; // Return null if failed
    }
  }

  // Function to schedule a notification
  Future<void> _scheduleNotification(DateTime mealDate) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'meal_channel', // Channel ID
      'Meal Notifications', // Channel name
      channelDescription: 'Channel for meal notifications', // Channel description
      importance: Importance.max, // Notification importance
      priority: Priority.high, // Notification priority
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    // Schedule the notification
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Meal Reminder', // Notification title
      'Do not forget to prepare meal for ${widget.petName}', // Notification body
      tz.TZDateTime.from(mealDate, tz.local), // Convert to TZDateTime
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, // Interpret as absolute time
    );
  }

  // Clear input fields
  void _clearForm() {
    _mealNameController.clear();
    _dateController.clear();
    _notesController.clear();
    setState(() {
      _selectedImage = null; // Clear selected image
    });
  }

  // Remove the selected image
  void _removeImage() {
    setState(() {
      _selectedImage = null; // Clear selected image
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Meal', style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        )),
        backgroundColor: Color(0xFFE2BF65), // AppBar color
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0), // Padding for the body
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title *', style: TextStyle(fontWeight: FontWeight.bold)), // Meal title label
            SizedBox(height: 5),
            TextField(
              controller: _mealNameController, // Controller for meal name input
              decoration: InputDecoration(
                border: OutlineInputBorder(), // Border style
                hintText: 'Enter Meal Name', // Hint text
                filled: true,
                fillColor: Colors.grey[200], // Fill color for text field
              ),
            ),
            SizedBox(height: 15),
            Text('Date & Time *', style: TextStyle(fontWeight: FontWeight.bold)), // Date/time label
            SizedBox(height: 5),
            TextField(
              controller: _dateController, // Controller for date input
              decoration: InputDecoration(
                border: OutlineInputBorder(), // Border style
                hintText: 'Enter Date & Time', // Hint text
                filled: true,
                fillColor: Colors.grey[200], // Fill color for text field
              ),
              readOnly: true, // Make field read-only
              onTap: _selectDateTime, // Function to select date/time
            ),
            SizedBox(height: 15),
            Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)), // Notes label
            SizedBox(height: 5),
            TextField(
              controller: _notesController, // Controller for notes input
              decoration: InputDecoration(
                border: OutlineInputBorder(), // Border style
                hintText: 'Enter Notes', // Hint text
                filled: true,
                fillColor: Colors.grey[200], // Fill color for text field
              ),
              maxLines: 3, // Maximum lines for notes
            ),
            SizedBox(height: 15),
            Text('Upload Image (optional)', style: TextStyle(fontWeight: FontWeight.bold)), // Image upload label
            SizedBox(height: 5),
            Container(
              height: 150,
              color: Colors.grey[200], // Background color for image preview
              child: _selectedImage == null
                  ? Center(child: Text('Image Preview')) // Placeholder if no image selected
                  : Stack(
                children: [
                  Image.file(
                    _selectedImage!, // Show selected image
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage, // Remove image on tap
                      child: Container(
                        color: Colors.black54, // Background for close button
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(Icons.close, color: Colors.white), // Close icon
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickImage, // Function to pick an image
              child: Text('Pick Image'), // Button text
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE2BF65), // Button color
                foregroundColor: Colors.black, // Text color
              ),
            ),
            SizedBox(height: 20),
            _isUploading
                ? Center(child: CircularProgressIndicator()) // Show loading indicator if uploading
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addMeal, // Function to add meal
                child: Text('Add Meal', style: TextStyle(color: Colors.black)), // Button text
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFE2BF65), // Button color
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to select date and time
  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // Initial date
      firstDate: DateTime.now(), // First selectable date
      lastDate: DateTime(2101), // Last selectable date
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(), // Initial time
      );

      if (pickedTime != null) {
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        String formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime); // Format date/time
        setState(() {
          _dateController.text = formattedDateTime; // Update date controller
        });
      }
    }
  }
}
