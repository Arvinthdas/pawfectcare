import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MealDetailScreen extends StatefulWidget {
  final DocumentSnapshot mealRecord; // Holds the meal record data
  final String petId; // Pet ID associated with the meal
  final String userId; // User ID of the logged-in user
  final String petName; // Name of the pet

  MealDetailScreen({
    required this.mealRecord,
    required this.petId,
    required this.userId,
    required this.petName,
  });

  @override
  _MealDetailScreenState createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late TextEditingController
      _mealNameController; // Controller for meal name input
  late TextEditingController _notesController; // Controller for notes input
  late TextEditingController _dateController; // Controller for date input
  File? _selectedImage; // Holds the selected image
  bool _isEditing = false; // State variable to toggle edit mode
  bool _imageRemoved = false; // Tracks if the user removed the uploaded image
  final _formKey = GlobalKey<FormState>(); // Key for the form

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin(); // For local notifications

  @override
  void initState() {
    super.initState();
    _mealNameController = TextEditingController(
        text: widget.mealRecord['mealName']); // Initialize meal name controller
    _notesController = TextEditingController(
        text: widget.mealRecord['notes']); // Initialize notes controller
    Timestamp dateTimestamp =
        widget.mealRecord['date']; // Get the date timestamp
    _dateController = TextEditingController(
        text: DateFormat('dd/MM/yyyy HH:mm')
            .format(dateTimestamp.toDate())); // Format date for display
    _initializeNotifications(); // Initialize notifications
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Android settings

    final InitializationSettings initializationSettings =
        const InitializationSettings(
            android:
                initializationSettingsAndroid); // General initialization settings

    await flutterLocalNotificationsPlugin
        .initialize(initializationSettings); // Initialize local notifications
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery); // Open gallery to pick an image
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // Set the selected image file
        _imageRemoved = false; // Reset the image removal flag
      });
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null; // Clear the newly selected image
      _imageRemoved =
          true; // Mark that the previously uploaded image was removed
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return; // Don't proceed if the form is invalid
    }

    bool confirmSave =
        await _showConfirmationDialog(); // Show confirmation dialog
    if (!confirmSave) {
      return; // Don't proceed if the user cancels
    }

    try {
      DateTime mealDate = DateFormat('dd/MM/yyyy HH:mm')
          .parse(_dateController.text); // Parse meal date
      String? imageUrl = widget.mealRecord['imageUrl']; // Get current image URL

      // If a new image is selected, upload it
      if (_selectedImage != null) {
        imageUrl = await _uploadImageToFirebase(
            _selectedImage!); // Upload new image and get URL
      }

      // If the image was removed by the user, delete the previous image from Firestore and Firebase Storage
      if (_imageRemoved && widget.mealRecord['imageUrl'] != null) {
        await _deleteImageFromFirebase(
            widget.mealRecord['imageUrl']); // Remove the image from Firebase
        imageUrl = null; // Set image URL to null after deletion
      }

      // Update meal record in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('meals')
          .doc(widget.mealRecord.id)
          .update({
        'mealName': _mealNameController.text, // Update meal name
        'date': mealDate, // Update date
        'notes': _notesController.text, // Update notes
        'imageUrl': imageUrl, // Update image URL
      });

      // Check if the meal date is in the future before scheduling a notification
      if (mealDate.isAfter(DateTime.now())) {
        await _rescheduleNotification(
            mealDate); // Reschedule notification if the date is valid
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Notification was not rescheduled because the date is not in the future.')), // Inform user about notification
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Changes saved successfully!')), // Inform user about successful save
      );

      // Toggle back to view mode without leaving the screen
      setState(() {
        _isEditing = false; // Set to view mode
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error updating meal: $e')), // Show error message
      );
    }
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName =
          'meals/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Create a unique file name
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child(fileName); // Reference to Firebase Storage
      UploadTask uploadTask = storageRef.putFile(imageFile); // Upload the file
      TaskSnapshot snapshot = await uploadTask; // Wait for upload to complete
      return await snapshot.ref.getDownloadURL(); // Get download URL
    } catch (e) {
      print('Error uploading image: $e'); // Log error
      return null;
    }
  }

  Future<void> _deleteImageFromFirebase(String imageUrl) async {
    try {
      Reference storageRef = FirebaseStorage.instance
          .refFromURL(imageUrl); // Reference to the image in Firebase Storage
      await storageRef.delete(); // Delete the image
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Image removed successfully!')), // Inform user about removal
      );
    } catch (e) {
      print('Error deleting image: $e'); // Log error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error removing image: $e')), // Show error message
      );
    }
  }

  Future<void> _rescheduleNotification(DateTime mealDate) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'meal_channel', // Channel ID
      'Meal Notifications', // Channel name
      channelDescription:
          'Channel for meal notifications', // Channel description
      importance: Importance.max, // Importance level
      priority: Priority.high, // Notification priority
      showWhen:
          false, // Do not show the time when the notification is triggered
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics); // Notification details

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Meal Reminder', // Notification title
      'Do not forget to prepare meal for ${widget.petName}', // Notification content
      tz.TZDateTime.from(mealDate, tz.local), // Scheduled date and time
      platformChannelSpecifics, // Notification details
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation
              .absoluteTime, // Interpretation method
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return (await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Save'), // Dialog title
              content: const Text(
                  'Are you sure you want to save the changes?'), // Dialog content
              actions: [
                TextButton(
                  child: const Text('Cancel'), // Cancel button
                  onPressed: () {
                    Navigator.of(context)
                        .pop(false); // Close dialog and return false
                  },
                ),
                TextButton(
                  child: const Text('Save'), // Save button
                  onPressed: () {
                    Navigator.of(context)
                        .pop(true); // Close dialog and return true
                  },
                ),
              ],
            );
          },
        )) ??
        false; // Return false if dialog is dismissed
  }

  @override
  void dispose() {
    _mealNameController.dispose(); // Dispose of the controller
    _notesController.dispose(); // Dispose of the controller
    _dateController.dispose(); // Dispose of the controller
    super.dispose(); // Call super
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Set background color
      appBar: AppBar(
        title: const Text(
          'Meal Details', // Title of the screen
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFE2BF65), // App bar color
        actions: [
          if (_isEditing) // Show save icon if in editing mode
            IconButton(
              icon: const Icon(Icons.save), // Save icon
              onPressed: _saveChanges, // Call save function
            )
          else // Show edit icon if not in editing mode
            IconButton(
              icon: const Icon(Icons.edit), // Edit icon
              onPressed: () {
                setState(() {
                  _isEditing = true; // Switch to editing mode
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding for the body
        child: Form(
          key: _formKey, // Use form key for validation
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align children to the start
            children: [
              const SizedBox(height: 20), // Spacer
              TextFormField(
                controller: _mealNameController, // Meal name input
                decoration: const InputDecoration(
                  labelText: 'Meal Name',
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(), // Rounded border
                ),
                enabled: _isEditing, // Enable if editing
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the meal name'; // Validation message
                  }
                  return null; // Valid input
                },
              ),
              const SizedBox(height: 20), // Spacer
              TextFormField(
                controller: _dateController, // Date input
                decoration: const InputDecoration(
                  labelText: 'Date & Time',
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(), // Rounded border
                ),
                enabled: _isEditing, // Enable if editing
                onTap: _isEditing ? _selectDateTime : null, // Open date picker
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select the date and time'; // Validation message
                  }
                  return null; // Valid input
                },
              ),
              const SizedBox(height: 20), // Spacer
              TextFormField(
                controller: _notesController, // Notes input
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(), // Rounded border
                ),
                enabled: _isEditing, // Enable if editing
              ),
              const SizedBox(height: 20), // Spacer
              const Text('Upload New Image (optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold)), // Label for image upload
              const SizedBox(height: 10), // Spacer
              Container(
                height: 150,
                color: Colors.grey[200], // Placeholder color
                child: _selectedImage != null // If an image is selected
                    ? Stack(
                        children: [
                          Image.file(_selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity), // Display selected image
                        ],
                      )
                    : (_imageRemoved ||
                            widget.mealRecord['imageUrl'] ==
                                null) // If image was removed or doesn't exist
                        ? const Center(
                            child: Text('No Image Preview')) // No image message
                        : Stack(
                            children: [
                              Image.network(widget.mealRecord['imageUrl'],
                                  fit: BoxFit.cover,
                                  width: double
                                      .infinity), // Display existing image
                            ],
                          ),
              ),
              const SizedBox(height: 20), // Spacer
              if (_isEditing) // Show button if editing
                ElevatedButton(
                  onPressed: _pickImage, // Pick image action
                  child: const Text('Pick New Image',
                      style: TextStyle(color: Colors.black)), // Button text
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE2BF65), // Button color
                  ),
                ),
              if (_isEditing &&
                  widget.mealRecord['imageUrl'] !=
                      null) // Show remove button only if an image exists
                ElevatedButton(
                  onPressed: _removeImage, // Remove image action
                  child: const Text('Remove Image',
                      style: TextStyle(color: Colors.black)), // Button text
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE2BF65), // Button color
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
      initialDate: DateTime.now(), // Current date as default
      firstDate: DateTime.now(), // Minimum date selectable
      lastDate: DateTime(2101), // Maximum date selectable
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(), // Current time as default
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
            .format(selectedDateTime); // Format selected date and time
        setState(() {
          _dateController.text =
              formattedDateTime; // Update the date controller text
        });
      }
    }
  }
}
