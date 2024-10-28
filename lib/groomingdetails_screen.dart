import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore for database
import 'package:intl/intl.dart'; // Date formatting
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Local notifications
import 'package:image_picker/image_picker.dart'; // Image picker for selecting images
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage for uploading images
import 'package:timezone/data/latest.dart' as tz; // Timezone data
import 'package:timezone/timezone.dart' as tz; // Timezone utilities
import 'dart:io'; // File handling

class GroomingDetailScreen extends StatefulWidget {
  final DocumentSnapshot groomingRecord; // Grooming record from Firestore
  final String petId; // Pet ID
  final String userId; // User ID
  final String petName; // Pet name

  GroomingDetailScreen({
    required this.groomingRecord,
    required this.petId,
    required this.userId,
    required this.petName,
  });

  @override
  _GroomingDetailScreenState createState() =>
      _GroomingDetailScreenState(); // State management
}

class _GroomingDetailScreenState extends State<GroomingDetailScreen> {
  late TextEditingController _taskNameController; // Controller for task name
  late TextEditingController
      _productsUsedController; // Controller for products used
  late TextEditingController _notesController; // Controller for notes
  late DateTime _selectedDate; // Selected date for the task
  late TimeOfDay _selectedTime; // Selected time for the task
  File? _imageFile; // Holds the uploaded image
  bool _isEditing = false; // Flag for editing mode
  late DocumentSnapshot _latestGroomingRecord; // Latest grooming record

  @override
  void initState() {
    super.initState();
    _latestGroomingRecord =
        widget.groomingRecord; // Initialize with passed record
    _fetchLatestGroomingRecord(); // Get latest grooming record
    _initializeFields(); // Set up input fields
  }

  Future<void> _fetchLatestGroomingRecord() async {
    // Fetching updated grooming record
    try {
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users') // User collection
          .doc(widget.userId) // User document
          .collection('pets') // Pets collection
          .doc(widget.petId) // Pet document
          .collection('groomingTasks') // Grooming tasks collection
          .doc(widget.groomingRecord.id) // Specific task document
          .get(); // Get the document

      setState(() {
        _latestGroomingRecord = updatedRecord; // Update local record
        _initializeFields(); // Re-initialize fields
      });
    } catch (e) {
      print('Error fetching latest grooming record: $e'); // Log errors
    }
  }

  void _initializeFields() {
    _taskNameController = // Initialize task name input
        TextEditingController(text: _latestGroomingRecord['taskName']);
    _productsUsedController = // Initialize products used input
        TextEditingController(text: _latestGroomingRecord['productsUsed']);
    _notesController = // Initialize notes input
        TextEditingController(text: _latestGroomingRecord['notes']);

    Timestamp dateTimestamp =
        _latestGroomingRecord['date']; // Get date from record
    final dateTime = dateTimestamp.toDate(); // Convert timestamp to DateTime
    _selectedDate = dateTime; // Set selected date
    _selectedTime = TimeOfDay.fromDateTime(dateTime); // Set selected time
  }

  @override
  void dispose() {
    // Clean up controllers
    _taskNameController.dispose(); // Dispose task name controller
    _productsUsedController.dispose(); // Dispose products used controller
    _notesController.dispose(); // Dispose notes controller
    super.dispose(); // Call superclass dispose
  }

  Future<void> _pickImage() async {
    // Method to pick an image
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery); // Open gallery
    if (pickedFile != null) {
      // Check if an image was selected
      setState(() {
        _imageFile = File(pickedFile.path); // Set the image file
      });
    }
  }

  Future<String?> _uploadImageToStorage(String userId) async {
    // Upload image to storage
    if (_imageFile != null) {
      // Ensure an image is selected
      try {
        String fileName =
            'grooming_tasks/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Create file name
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child(fileName); // Reference to storage
        UploadTask uploadTask = storageRef.putFile(_imageFile!); // Upload task
        TaskSnapshot snapshot = await uploadTask; // Await upload completion
        return await snapshot.ref.getDownloadURL(); // Return download URL
      } catch (e) {
        print('Error uploading image: $e'); // Log upload errors
        return null; // Return null on failure
      }
    }
    return null; // Return null if no image present
  }

  Future<void> _saveChanges() async {
    // Method to save changes
    if (_taskNameController.text.isEmpty) {
      // Validate input
      _showMessage('Please fill in all required fields'); // Show error message
      return; // Exit if validation fails
    }

    final updatedDateTime = DateTime(
      // Create DateTime object
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    String? imageUrl =
        await _uploadImageToStorage(widget.userId); // Upload image

    try {
      await FirebaseFirestore.instance // Access Firestore
          .collection('users') // Users collection
          .doc(widget.userId) // User document
          .collection('pets') // Pets collection
          .doc(widget.petId) // Pet document
          .collection('groomingTasks') // Grooming tasks collection
          .doc(widget.groomingRecord.id) // Specific grooming task
          .update({
        // Update the document
        'taskName': _taskNameController.text, // Update task name
        'productsUsed': _productsUsedController.text, // Update products used
        'notes': _notesController.text, // Update notes
        'date': updatedDateTime, // Update date
        if (imageUrl != null)
          'imageUrl': imageUrl, // Update image URL if present
      });

      _scheduleNotification(updatedDateTime, _taskNameController.text,
          widget.petName); // Schedule notification
      _showMessage('Changes saved successfully'); // Success message

      await _fetchLatestGroomingRecord(); // Refresh the latest grooming record

      setState(() {
        // Update state
        _isEditing = false; // Exit editing mode
        _imageFile = null; // Clear the uploaded image
      });
    } catch (e) {
      print('Error updating grooming task: $e'); // Log update errors
      _showMessage('Failed to save changes: $e'); // Show error message
    }
  }

  Future<void> _scheduleNotification(
      DateTime scheduledTime, String title, String petName) async {
    // Schedule notification
    FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin(); // Notification plugin instance

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      // Android notification details
      'grooming_channel_id',
      'Grooming Notifications',
      channelDescription: 'Reminder for upcoming grooming tasks',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails); // Platform notification details

    tz.TZDateTime scheduledDate =
        tz.TZDateTime.from(scheduledTime, tz.local); // Convert to TZDateTime

    await notificationsPlugin.zonedSchedule(
      // Schedule the notification
      widget.groomingRecord.hashCode, // Notification ID
      'Grooming Reminder', // Notification title
      '${widget.petName} got a $title grooming appointment', // Notification body
      scheduledDate, // Scheduled time
      platformDetails, // Notification details
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation
              .absoluteTime, // Interpretation method
      matchDateTimeComponents: DateTimeComponents.time, // Match time components
    );
  }

  void _showMessage(String message) {
    // Show a message in a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      // Show snackbar
      SnackBar(content: Text(message)), // Message content
    );
  }

  void _showRemoveImageDialog() {
    // Show dialog to confirm image removal
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Build dialog widget
        return AlertDialog(
          title: const Text('Remove Image'), // Dialog title
          content: const Text(
              'Are you sure you want to remove this image?'), // Dialog content
          actions: [
            // Dialog actions
            TextButton(
              // Cancel button
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'), // Button label
            ),
            TextButton(
              // Remove button
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _removeImage(); // Remove image from the UI
              },
              child: const Text('Remove'), // Button label
            ),
          ],
        );
      },
    );
  }

  void _removeImage() {
    // Remove image method
    setState(() {
      _imageFile = null; // Clear the image file
    });

    _removeImageFromFirestore(); // Remove image URL from Firestore
  }

  Future<void> _removeImageFromFirestore() async {
    // Remove image from Firestore
    try {
      await FirebaseFirestore.instance // Access Firestore
          .collection('users') // Users collection
          .doc(widget.userId) // User document
          .collection('pets') // Pets collection
          .doc(widget.petId) // Pet document
          .collection('groomingTasks') // Grooming tasks collection
          .doc(widget.groomingRecord.id) // Specific grooming task
          .update({'imageUrl': ''}); // Clear image URL

      // Fetch updated record
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users') // Access Firestore
          .doc(widget.userId) // User document
          .collection('pets') // Pets collection
          .doc(widget.petId) // Pet document
          .collection('groomingTasks') // Grooming tasks collection
          .doc(widget.groomingRecord.id) // Specific grooming task
          .get(); // Get updated document

      setState(() {
        _latestGroomingRecord = updatedRecord; // Update local record
      });

      _showMessage('Image removed successfully.'); // Success message
    } catch (e) {
      print('Error removing image from Firestore: $e'); // Log errors
      _showMessage('Failed to remove the image.'); // Error message
    }
  }

  Widget _buildImageDisplay() {
    // Build image display widget
    return Container(
      height: 200, // Height of the container
      width: 380, // Width of the container
      decoration: BoxDecoration(
        // Container decoration
        borderRadius: BorderRadius.circular(10), // Rounded corners
        border:
            Border.all(color: Colors.grey[300]!, width: 1), // Border styling
        color: Colors.grey[200], // Background color
      ),
      child: _imageFile != null // Check if a new image is selected
          ? ClipRRect(
              // Clip the image
              borderRadius:
                  BorderRadius.circular(10), // Rounded corners for the image
              child: Image.file(
                // Display the image file
                _imageFile!, // Image file to display
                fit: BoxFit.cover, // Fit image within the container
              ),
            )
          : (_latestGroomingRecord.data() !=
                      null && // Check if previous image exists
                  (_latestGroomingRecord.data()
                          as Map<String, dynamic>)['imageUrl'] !=
                      null &&
                  (_latestGroomingRecord.data()
                          as Map<String, dynamic>)['imageUrl'] !=
                      '')
              ? ClipRRect(
                  // Clip the network image
                  borderRadius: BorderRadius.circular(
                      10), // Rounded corners for the image
                  child: Image.network(
                    // Load image from the network
                    (_latestGroomingRecord.data()
                        as Map<String, dynamic>)['imageUrl'],
                    fit: BoxFit.cover, // Fit image within the container
                  ),
                )
              : const Center(
                  child: Text(
                      'No image uploaded')), // Message when no image is available
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    // Method to select a date
    final DateTime? picked = await showDatePicker(
      // Show date picker
      context: context,
      initialDate: _selectedDate, // Current selected date
      firstDate: DateTime(2000), // Earliest selectable date
      lastDate: DateTime(2101), // Latest selectable date
    );
    if (picked != null) {
      // Check if a date was selected
      setState(() {
        _selectedDate = picked; // Update selected date
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    // Method to select time
    final TimeOfDay? picked = await showTimePicker(
      // Show time picker
      context: context,
      initialTime: _selectedTime, // Current selected time
    );
    if (picked != null) {
      // Check if a time was selected
      setState(() {
        _selectedTime = picked; // Update selected time
      });
    }
  }

  Widget _buildStyledTextField({
    // Method to build styled text fields
    required TextEditingController controller, // Text editing controller
    required String label, // Label for the text field
    bool enabled = true, // Whether the field is editable
    int maxLines = 1, // Maximum number of lines
    Widget? suffixIcon, // Optional suffix icon
  }) {
    return TextField(
      // Text field widget
      controller: controller, // Controller for the field
      maxLines: maxLines, // Max lines for input
      enabled: enabled, // Enable or disable the field
      decoration: InputDecoration(
        // Input decoration styling
        labelText: label, // Label text
        labelStyle: const TextStyle(
          // Label styling
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        fillColor: Colors.grey[200], // Background color
        filled: true, // Fill the background
        border: OutlineInputBorder(
          // Border styling
          borderRadius: BorderRadius.circular(10), // Rounded corners
          borderSide: const BorderSide(color: Colors.black), // Border color
        ),
        enabledBorder: OutlineInputBorder(
          // Border when enabled
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          // Border when focused
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: Color(0xFFDAA520), width: 2), // Highlighted border
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16), // Padding
        hintText: 'Enter $label', // Hint text
        hintStyle: TextStyle(
          // Hint text styling
          color: Colors.grey[500],
        ),
        suffixIcon: suffixIcon, // Optional suffix icon
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build method
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Background color
      appBar: AppBar(
        title: const Text(
          // App bar title
          'Grooming Details',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE2BF65), // App bar color
        actions: [
          if (_isEditing) // Conditional action button for saving
            IconButton(
              icon: const Icon(Icons.save), // Save icon
              onPressed: _saveChanges, // Save changes action
            )
          else // Action button for editing
            IconButton(
              icon: const Icon(Icons.edit), // Edit icon
              onPressed: () {
                setState(() {
                  _isEditing = true; // Set to editing mode
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        // Scrollable body
        padding: const EdgeInsets.all(16.0), // Padding for the body
        child: Column(
          children: [
            _buildStyledTextField(
              // Task name text field
              controller: _taskNameController,
              label: 'Task Name',
              enabled: _isEditing, // Enable if editing
            ),
            const SizedBox(height: 20), // Spacer
            GestureDetector(
              // Date selection
              onTap: () {
                if (_isEditing) {
                  _selectDate(context); // Open date picker
                }
              },
              child: AbsorbPointer(
                // Prevent editing directly
                child: _buildStyledTextField(
                  // Date text field
                  controller: TextEditingController(
                      text: DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  label: 'Date',
                  enabled: _isEditing, // Enable if editing
                  suffixIcon: const Icon(Icons.calendar_today), // Calendar icon
                ),
              ),
            ),
            const SizedBox(height: 20), // Spacer
            GestureDetector(
              // Time selection
              onTap: () {
                if (_isEditing) {
                  _selectTime(context); // Open time picker
                }
              },
              child: AbsorbPointer(
                // Prevent editing directly
                child: _buildStyledTextField(
                  // Time text field
                  controller: TextEditingController(
                      text: _selectedTime.format(context)),
                  label: 'Time',
                  enabled: _isEditing, // Enable if editing
                  suffixIcon: const Icon(Icons.access_time), // Time icon
                ),
              ),
            ),
            const SizedBox(height: 20), // Spacer
            _buildStyledTextField(
              // Products used text field
              controller: _productsUsedController,
              label: 'Products Used',
              enabled: _isEditing, // Enable if editing
            ),
            const SizedBox(height: 20), // Spacer
            _buildStyledTextField(
              // Notes text field
              controller: _notesController,
              label: 'Notes',
              enabled: _isEditing, // Enable if editing
              maxLines: 3, // Allow multiple lines
            ),
            const SizedBox(height: 20), // Spacer
            _buildImageDisplay(), // Display image widget
            const SizedBox(height: 20), // Spacer
            if (_isEditing) // Button to upload new image
              ElevatedButton(
                onPressed: _pickImage, // Open image picker
                child: const Text('Upload New Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black, // Text color
                  backgroundColor: const Color(0xFFE2BF65), // Button color
                ),
              ),
            if (_isEditing && // Button to remove image
                (_latestGroomingRecord['imageUrl'] != null &&
                        _latestGroomingRecord['imageUrl'] != '' ||
                    _imageFile != null))
              ElevatedButton(
                onPressed: _showRemoveImageDialog, // Show remove image dialog
                child: const Text('Remove Image'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black, // Text color
                  backgroundColor: const Color(0xFFE2BF65), // Button color
                ),
              ),
          ],
        ),
      ),
    );
  }
}
