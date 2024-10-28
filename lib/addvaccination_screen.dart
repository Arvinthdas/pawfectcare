import 'package:flutter/material.dart'; // Import Flutter Material package for UI components.
import 'package:cloud_firestore/cloud_firestore.dart'; // Import for Firebase Firestore database interaction.
import 'package:firebase_auth/firebase_auth.dart'; // Import for Firebase authentication.
import 'package:image_picker/image_picker.dart'; // Import for image picking from the gallery or camera.
import 'package:firebase_storage/firebase_storage.dart'; // Import for Firebase storage to upload images.
import 'dart:io'; // Import for file handling.
import 'package:intl/intl.dart'; // Import for date formatting.
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import for local notifications.
import 'package:timezone/data/latest.dart' as tz; // Import for timezone data.
import 'package:timezone/timezone.dart' as tz; // Import for timezone operations.

class AddVaccinationScreen extends StatefulWidget {
  final String petId; // Pet ID parameter.
  final String userId; // User ID parameter.
  final String petName; // Pet name parameter.

  AddVaccinationScreen(
      {required this.petId, required this.userId, required this.petName}); // Constructor for initialization.

  @override
  _AddVaccinationScreenState createState() => _AddVaccinationScreenState(); // State creation.
}

class _AddVaccinationScreenState extends State<AddVaccinationScreen> {
  final _vaccineNameController = TextEditingController(); // Controller for vaccine name input.
  final _dateController = TextEditingController(); // Controller for date input.
  final _veterinarianController = TextEditingController(); // Controller for veterinarian name input.
  final _clinicController = TextEditingController(); // Controller for clinic name input.
  final _notesController = TextEditingController(); // Controller for notes input.
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance for user authentication.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance for database operations.
  final FirebaseStorage _storage = FirebaseStorage.instance; // Firebase Storage instance for image storage.

  File? _selectedDocument; // Variable to store the selected document/image.
  bool _isUploading = false; // Flag to indicate if an upload is in progress.

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin(); // Instance for managing local notifications.

  @override
  void initState() {
    super.initState();
    _initializeNotifications(); // Initialize notifications when the screen loads.
    tz.initializeTimeZones(); // Initialize timezone data.
    tz.setLocalLocation(
        tz.getLocation('Asia/Kuala_Lumpur')); // Set timezone to Malaysia Time.
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Android specific initialization.

    final InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid); // Settings for notifications.

    await flutterLocalNotificationsPlugin.initialize(initializationSettings); // Initialize the plugin.

    _createNotificationChannel(); // Create a notification channel for notifications.
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'vaccination_channel', // Channel ID.
      'Vaccination Notifications', // Channel name.
      description: 'This channel is for vaccination notifications', // Channel description.
      importance: Importance.max, // Importance level set to maximum.
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel); // Create the notification channel if platform supports it.
    }
  }

  Future<void> _pickDocument() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery); // Open image picker to select an image.
    if (pickedFile != null) {
      setState(() {
        _selectedDocument = File(pickedFile.path); // Store the selected file.
      });
    }
  }

  Future<void> _addVaccination() async {
    if (_vaccineNameController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _veterinarianController.text.isEmpty ||
        _clinicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')), // Show message if required fields are empty.
      );
      return;
    }

    DateTime? vaccinationDate;
    try {
      vaccinationDate =
          DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text); // Parse the entered date and time.
      if (vaccinationDate.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a future date and time.')), // Show message if date is in the past.
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid date format.')), // Show message if date format is invalid.
      );
      return;
    }

    User? user = _auth.currentUser; // Get the current user.
    if (user != null) {
      setState(() {
        _isUploading = true; // Set uploading state to true.
      });

      String uid = user.uid; // Get user ID.
      String documentUrl = '';

      if (_selectedDocument != null) {
        documentUrl = await _uploadImageToStorage(uid, _selectedDocument!); // Upload image if it exists.
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
        }); // Add vaccination details to Firestore.

        await _scheduleNotification(
            vaccinationDate, _vaccineNameController.text, widget.petName); // Schedule a notification.

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vaccination added successfully!')), // Show success message.
        );
        _clearForm(); // Clear the form after submission.
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding vaccination: $e')), // Show error message if adding fails.
        );
      } finally {
        setState(() {
          _isUploading = false; // Reset uploading state.
        });
      }

      Navigator.pop(context); // Navigate back after adding.
    }
  }

  Future<String> _uploadImageToStorage(String uid, File imageFile) async {
    try {
      String fileName =
          'vaccinations/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Define file name for storage.
      Reference storageRef = _storage.ref().child(fileName); // Create storage reference.
      UploadTask uploadTask = storageRef.putFile(imageFile); // Upload the file.
      TaskSnapshot snapshot = await uploadTask; // Wait for upload to complete.
      return await snapshot.ref.getDownloadURL(); // Get and return the file URL.
    } catch (e) {
      print('Error uploading image: $e'); // Print error if upload fails.
      return '';
    }
  }

  Future<void> _scheduleNotification(
      DateTime vaccinationDate, String title, String petName) async {
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(vaccinationDate, tz.local); // Convert date to timezone-aware object.

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
        '$petName `s $title vaccination appointment', // Notification message content.
        scheduledDate,
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime, // Schedule the notification.
      );
    } catch (e) {
      print("Error scheduling notification: $e"); // Print error if scheduling fails.
    }
  }

  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    ); // Show date picker.

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      ); // Show time picker if date is picked.

      if (pickedTime != null) {
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        ); // Combine date and time.

        String formattedDateTime =
        DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime); // Format the date and time.

        setState(() {
          _dateController.text = formattedDateTime; // Set formatted date and time to controller.
        });
      }
    }
  }

  void _clearForm() {
    _vaccineNameController.clear(); // Clear vaccine name.
    _dateController.clear(); // Clear date.
    _veterinarianController.clear(); // Clear veterinarian name.
    _clinicController.clear(); // Clear clinic name.
    _notesController.clear(); // Clear notes.
    setState(() {
      _selectedDocument = null; // Reset selected document.
      _isUploading = false; // Reset uploading state.
    });
  }

  Future<void> _removeImage() async {
    bool? confirmed = await _showConfirmationDialog(
      title: 'Confirm Removal',
      content: 'Are you sure you want to remove the image?',
    ); // Show confirmation dialog.

    if (confirmed == true) {
      setState(() {
        _selectedDocument = null; // Clear the selected document if confirmed.
      });
    }
  }

  Future<bool?> _showConfirmationDialog(
      {required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title), // Dialog title.
          content: Text(content), // Dialog content.
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style:
              ElevatedButton.styleFrom(backgroundColor: Color(0xFFE2BF65)),
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
      ); // Show image if available.
    } else {
      return Container(
        height: 200,
        width: 380,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(child: Text('No Image Selected')), // Placeholder if no image is selected.
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Vaccination Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Color(0xFFE2BF65), // App bar color.
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vaccine Name *',
                style: TextStyle(fontWeight: FontWeight.bold)), // Vaccine name label.
            SizedBox(height: 5),
            TextField(
              controller: _vaccineNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter vaccine name',
                filled: true,
                fillColor: Colors.grey[200],
              ), // Text field for vaccine name.
            ),
            SizedBox(height: 15),
            Text('Date & Time of Vaccine *',
                style: TextStyle(fontWeight: FontWeight.bold)), // Date label.
            SizedBox(height: 5),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter date and time',
                filled: true,
                fillColor: Colors.grey[200],
              ), // Text field for date and time.
              readOnly: true,
              onTap: _selectDateTime, // Open date picker on tap.
            ),
            SizedBox(height: 15),
            Text('Veterinarian *',
                style: TextStyle(fontWeight: FontWeight.bold)), // Veterinarian label.
            SizedBox(height: 5),
            TextField(
              controller: _veterinarianController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter veterinarian name',
                filled: true,
                fillColor: Colors.grey[200],
              ), // Text field for veterinarian name.
            ),
            SizedBox(height: 15),
            Text('Clinic Name *',
                style: TextStyle(fontWeight: FontWeight.bold)), // Clinic label.
            SizedBox(height: 5),
            TextField(
              controller: _clinicController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter clinic name',
                filled: true,
                fillColor: Colors.grey[200],
              ), // Text field for clinic name.
            ),
            SizedBox(height: 15),
            Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)), // Notes label.
            SizedBox(height: 5),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter any notes',
                filled: true,
                fillColor: Colors.grey[200],
              ), // Text field for notes.
              maxLines: 3,
            ),
            SizedBox(height: 15),
            Text('Upload Image', style: TextStyle(fontWeight: FontWeight.bold)), // Upload image label.
            SizedBox(height: 5),
            _buildImagePreview(), // Display image preview.
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _pickDocument,
                  child: Text('Pick Image'), // Button to pick image.
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE2BF65),
                    foregroundColor: Colors.black,
                  ),
                ),
                if (_selectedDocument !=
                    null) // Button to remove image if one is selected.
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
                ? Center(child: CircularProgressIndicator()) // Show loading indicator if uploading.
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addVaccination,
                child: Text('Add Vaccination'), // Button to add vaccination.
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
