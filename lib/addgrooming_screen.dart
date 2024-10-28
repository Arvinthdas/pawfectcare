import 'package:flutter/material.dart'; // Import Flutter's Material UI components
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for database interactions
import 'package:intl/intl.dart'; // Import Intl for date formatting
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import local notifications package
import 'package:timezone/data/latest.dart' as tz; // Import timezone data
import 'package:timezone/timezone.dart' as tz; // Import timezone utilities
import 'package:image_picker/image_picker.dart'; // Import image picker for selecting images
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage for image uploads
import 'dart:io'; // Import Dart's IO library for file handling

class AddGroomingScreen extends StatefulWidget {
  final String petId; // Pet ID
  final String userId; // User ID
  final String petName; // Pet Name

  AddGroomingScreen(
      {required this.petId, required this.userId, required this.petName});

  @override
  _AddGroomingScreenState createState() => _AddGroomingScreenState();
}

// State class for AddGroomingScreen
class _AddGroomingScreenState extends State<AddGroomingScreen> {
  final _taskNameController =
      TextEditingController(); // Controller for task name input
  final _dateController =
      TextEditingController(); // Controller for date/time input
  final _productsUsedController =
      TextEditingController(); // Controller for products used input
  final _notesController =
      TextEditingController(); // Controller for notes input
  bool _isUploading = false; // Flag to indicate if an upload is in progress
  File? _selectedImage; // Selected image file

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin(); // Instance for notifications

  @override
  void initState() {
    super.initState();
    _initializeNotifications(); // Initialize notifications
    tz.initializeTimeZones(); // Initialize time zones
    tz.setLocalLocation(
        tz.getLocation('Asia/Kuala_Lumpur')); // Set timezone to Malaysia Time
  }

  // Function to initialize local notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Initialize Android settings

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid); // Combine settings

    await flutterLocalNotificationsPlugin
        .initialize(initializationSettings); // Initialize notifications
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1), // Set background color
      appBar: AppBar(
        title: Text(
          'Add Grooming Details',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFE2BF65), // AppBar color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding for the body
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
                'Grooming Task Name *', _taskNameController), // Task name input
            SizedBox(height: 15),
            _buildDateTimeField(), // Date and time input
            SizedBox(height: 15),
            _buildTextField('Products Used',
                _productsUsedController), // Products used input
            SizedBox(height: 15),
            _buildTextField('Notes', _notesController,
                maxLines: 3), // Notes input
            SizedBox(height: 15),
            _buildUploadImageSection(), // Image upload section
            SizedBox(height: 20),
            _isUploading
                ? Center(
                    child:
                        CircularProgressIndicator()) // Show loading indicator if uploading
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _addGroomingTask, // Call function to add grooming task
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

  // Function to build a text field with a label
  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold)), // Label for the text field
        TextField(
          controller: controller, // Assign controller
          maxLines: maxLines, // Set maximum lines
          decoration: InputDecoration(
            border: OutlineInputBorder(), // Outline border style
            hintText: 'Enter $label', // Hint text
            filled: true,
            fillColor: Colors.grey[200], // Fill color for the text field
          ),
        ),
      ],
    );
  }

  // Function to build a date/time field
  Widget _buildDateTimeField() {
    return GestureDetector(
      onTap: _selectDateTime, // Call function to select date/time
      child: AbsorbPointer(
        child: _buildTextField(
            'Date & Time of Grooming *', _dateController), // Date/time input
      ),
    );
  }

  // Function to select date and time
  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // Current date
      firstDate: DateTime(2000), // Minimum date
      lastDate: DateTime(2101), // Maximum date
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(), // Current time
      );

      if (pickedTime != null) {
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        String formattedDateTime = DateFormat('dd/MM/yyyy HH:mm')
            .format(selectedDateTime); // Format date/time
        setState(() {
          _dateController.text =
              formattedDateTime; // Set formatted date/time to controller
        });
      }
    }
  }

  // Function to build the image upload section
  Widget _buildUploadImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Image (optional)',
            style: TextStyle(fontWeight: FontWeight.bold)), // Section title
        SizedBox(height: 5),
        Container(
          height: 150,
          color: Colors.grey[200], // Background color for image preview
          child: _selectedImage == null
              ? Center(
                  child:
                      Text('Image Preview')) // Placeholder if no image selected
              : Image.file(
                  _selectedImage!, // Display selected image
                  fit: BoxFit.cover, // Image fit style
                ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            ElevatedButton(
              onPressed: _pickImage, // Call function to pick image
              child: Text('Pick Document/Image'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Color(0xFFE2BF65),
              ),
            ),
            if (_selectedImage !=
                null) // Show remove button if image is selected
              SizedBox(width: 10),
            if (_selectedImage != null)
              ElevatedButton(
                onPressed: _removeImage, // Call function to remove image
                child: Text('Remove Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Color(0xFFE2BF65),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final pickedFile =
        await _picker.pickImage(source: ImageSource.gallery); // Open gallery
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // Set selected image
      });
    }
  }

  // Function to remove the selected image
  void _removeImage() {
    setState(() {
      _selectedImage = null; // Clear selected image
    });
  }

  // Function to add a grooming task
  Future<void> _addGroomingTask() async {
    // Check required fields
    if (_taskNameController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please fill in all required fields')), // Show error message
      );
      return;
    }

    setState(() {
      _isUploading = true; // Start uploading
    });

    try {
      final DateTime groomingDate = DateFormat('dd/MM/yyyy HH:mm')
          .parse(_dateController.text); // Parse date
      String? imageUrl;

      if (_selectedImage != null) {
        imageUrl = await _uploadImageToFirebase(
            _selectedImage!); // Upload image and get URL
      }

      // Save grooming task details to Firestore
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
      await _scheduleNotification(
          groomingDate, _taskNameController.text, widget.petName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Grooming task added successfully!')), // Success message
      );

      // Clear form and navigate back
      _clearForm();
      Navigator.pop(context); // Close current screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error adding grooming task: $e')), // Error message
      );
    } finally {
      setState(() {
        _isUploading = false; // Stop uploading
      });
    }
  }

  // Function to upload an image to Firebase Storage
  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName =
          'grooming_tasks/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Unique file name
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child(fileName); // Reference to storage location
      UploadTask uploadTask = storageRef.putFile(imageFile); // Upload task
      TaskSnapshot snapshot = await uploadTask; // Wait for upload to complete
      return await snapshot.ref.getDownloadURL(); // Get download URL
    } catch (e) {
      print('Error uploading image: $e');
      return null; // Return null if there's an error
    }
  }

  // Function to schedule a notification for the grooming task
  Future<void> _scheduleNotification(
      DateTime groomingDate, String title, String petName) async {
    tz.TZDateTime scheduledDate =
        tz.TZDateTime.from(groomingDate, tz.local); // Convert to TZDateTime

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'grooming_channel', // Channel ID
      'Grooming Notifications', // Channel name
      channelDescription:
          'Channel for grooming notifications', // Channel description
      importance: Importance.max, // Notification importance
      priority: Priority.high, // Notification priority
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android:
            androidPlatformChannelSpecifics); // Set platform-specific details

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Grooming Reminder', // Notification title
        '${widget.petName} got a $title grooming appointment', // Notification body
        scheduledDate, // Scheduled date and time
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true, // Allow notification while the app is idle
      );
    } catch (e) {
      print("Error scheduling notification: $e"); // Log error
    }
  }

  // Function to clear the form fields
  void _clearForm() {
    _taskNameController.clear();
    _dateController.clear();
    _productsUsedController.clear();
    _notesController.clear();
    setState(() {
      _selectedImage = null; // Clear selected image
    });
  }

  @override
  void dispose() {
    _taskNameController.dispose(); // Dispose controllers
    _dateController.dispose();
    _productsUsedController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
