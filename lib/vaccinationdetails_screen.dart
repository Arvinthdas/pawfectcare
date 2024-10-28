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
  final DocumentSnapshot vaccinationRecord; // Record of the vaccination
  final String petId; // Pet's ID
  final String userId; // User's ID
  final String petName; // Pet's name

  VaccinationDetailScreen({
    required this.vaccinationRecord,
    required this.petId,
    required this.userId,
    required this.petName,
  });

  @override
  _VaccinationDetailScreenState createState() =>
      _VaccinationDetailScreenState();
}

class _VaccinationDetailScreenState extends State<VaccinationDetailScreen> {
  late TextEditingController
      _vaccineNameController; // Controller for vaccine name input
  late TextEditingController _clinicController; // Controller for clinic input
  late TextEditingController _notesController; // Controller for notes input
  late DateTime _selectedDate; // Selected vaccination date
  late TimeOfDay _selectedTime; // Selected vaccination time
  File? _imageFile; // Selected image file
  bool _isEditing = false; // State for editing mode
  late DocumentSnapshot _latestVaccinationRecord; // Latest vaccination record

  @override
  void initState() {
    super.initState();
    _latestVaccinationRecord =
        widget.vaccinationRecord; // Initialize with the passed record
    _fetchLatestVaccinationRecord(); // Fetch the latest vaccination record
    _initializeFields(); // Initialize the text fields
  }

  // Fetch the latest vaccination record from Firestore
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
        _latestVaccinationRecord = updatedRecord; // Update the local record
        _initializeFields(); // Reinitialize fields with the latest record data
      });
    } catch (e) {
      print('Error fetching latest vaccination record: $e'); // Handle errors
    }
  }

  // Initialize text fields with existing vaccination record data
  void _initializeFields() {
    _vaccineNameController =
        TextEditingController(text: _latestVaccinationRecord['vaccineName']);
    _clinicController =
        TextEditingController(text: _latestVaccinationRecord['clinic']);
    _notesController =
        TextEditingController(text: _latestVaccinationRecord['notes']);

    String dateStr = _latestVaccinationRecord['date']; // Get date string
    try {
      final dateTime =
          DateFormat('dd/MM/yyyy HH:mm').parse(dateStr); // Parse date
      _selectedDate =
          DateFormat('dd/MM/yyyy').parse(dateStr); // Store selected date
      _selectedTime = TimeOfDay.fromDateTime(dateTime); // Store selected time
    } catch (e) {
      print('Error parsing date: $e'); // Handle parsing errors
      _selectedDate = DateTime.now(); // Default to current date
      _selectedTime = TimeOfDay.now(); // Default to current time
    }
  }

  // Dispose controllers when not needed
  @override
  void dispose() {
    _vaccineNameController.dispose();
    _clinicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path); // Store selected image file
      });
    }
  }

  // Upload the selected image to Firebase Storage
  Future<String> _uploadImageToStorage(String userId) async {
    if (_imageFile != null) {
      try {
        String fileName =
            'vaccinations/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Unique file name
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(_imageFile!); // Start upload
        TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL(); // Return the download URL
      } catch (e) {
        print('Error uploading image: $e'); // Handle upload errors
        return ''; // Return empty string if upload fails
      }
    }
    return ''; // Return empty string if no image selected
  }

  // Save changes to the vaccination record
  Future<void> _saveChanges() async {
    // Validate required fields
    if (_vaccineNameController.text.isEmpty ||
        _clinicController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      _showMessage('Please fill in all required fields');
      return;
    }

    // Show confirmation dialog before saving changes
    bool? confirmed = await _showConfirmationDialog(
      title: 'Confirm Save',
      content: 'Are you sure you want to save the changes?',
    );

    if (confirmed == true) {
      final updatedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ); // Combine date and time
      final formattedDate =
          DateFormat('dd/MM/yyyy HH:mm').format(updatedDateTime); // Format date

      String imageUrl = await _uploadImageToStorage(
          widget.userId); // Upload image and get URL

      // Update Firestore with the new data
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

      _scheduleNotification(updatedDateTime, _vaccineNameController.text,
          widget.petName); // Schedule notification
      _showMessage('Changes saved successfully'); // Show success message
      setState(() {
        _isEditing = false; // Exit editing mode
      });
    }
  }

  // Schedule a notification for the vaccination
  Future<void> _scheduleNotification(
      DateTime scheduledTime, String title, String petName) async {
    FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Define Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'vaccine_channel_id',
      'Vaccination Notifications',
      channelDescription: 'Reminder for upcoming vaccinations',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        scheduledTime, tz.local); // Convert to timezone-aware date

    await notificationsPlugin.zonedSchedule(
      widget.vaccinationRecord.hashCode,
      'Vaccination Reminder',
      '$petName\'s $title vaccination appointment',
      scheduledDate,
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Show a message using SnackBar
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Select a date for vaccination
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked; // Update selected date
      });
    }
  }

  // Select a time for vaccination
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked; // Update selected time
      });
    }
  }

  // Build image display for vaccination record
  Widget _buildImageDisplay() {
    if (_imageFile != null) {
      return Container(
        height: 200,
        width: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10), // Rounded corners
          border:
              Border.all(color: Colors.grey[300]!, width: 1), // Border color
          color: Colors.grey[200], // Background color
        ),
        child: GestureDetector(
          onTap: () {
            if (_isEditing) {
              _showRemoveImageDialog(); // Show dialog to remove image
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
                10), // Ensure image fits within rounded corners
            child: Image.file(
              _imageFile!, // Display the selected image
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else {
      // If no image has been uploaded, check for an existing URL in Firestore
      String? documentUrl = _latestVaccinationRecord.data() != null &&
              (_latestVaccinationRecord.data() as Map<String, dynamic>)
                  .containsKey('documentUrl')
          ? _latestVaccinationRecord['documentUrl']
          : null;

      if (documentUrl != null && documentUrl.isNotEmpty) {
        // Display the image from the URL if it exists
        return Container(
          height: 200,
          width: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), // Rounded corners
            border:
                Border.all(color: Colors.grey[300]!, width: 1), // Border color
            color: Colors.grey[200], // Background color
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
                10), // Ensure image fits within rounded corners
            child: Image.network(
              documentUrl, // Display image from the network
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        // Show a placeholder if no image is available
        return Container(
          height: 200,
          width: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), // Rounded corners
            border:
                Border.all(color: Colors.grey[300]!, width: 1), // Border color
            color: Colors.grey[200], // Background color
          ),
          child: Center(
            // Center the text inside the container
            child: Text(
              'No image uploaded',
              style: TextStyle(
                  color: Colors.grey[600]), // Optional styling for the text
            ),
          ),
        );
      }
    }
  }

  // Show a confirmation dialog with title and content
  Future<bool?> _showConfirmationDialog(
      {required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title), // Set the title of the dialog
          content: Text(content), // Set the content of the dialog
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false); // Close the dialog without confirmation
              },
              child: const Text('Cancel'), // Cancel button
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm action
              },
              child: const Text('Confirm'), // Confirm button
            ),
          ],
        );
      },
    );
  }

  // Show a dialog to confirm removal of the image
  void _showRemoveImageDialog() async {
    // Show confirmation dialog before removing the image
    bool? confirmed = await _showConfirmationDialog(
      title: 'Remove Image',
      content: 'Are you sure you want to remove this image?',
    );

    if (confirmed == true) {
      _removeImage(); // Remove image from the UI
    }
  }

  // Clear the image locally and update the Firestore record
  void _removeImage() {
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

  // Update Firestore to remove the image URL
  Future<void> _removeImageFromFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .doc(widget.vaccinationRecord.id)
          .update({'documentUrl': ''}); // Clear the document URL

      // Fetch the latest data to update the local state
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .doc(widget.vaccinationRecord.id)
          .get();

      setState(() {
        _latestVaccinationRecord = updatedRecord; // Update local state
      });

      _showMessage('Image removed successfully.'); // Show success message
    } catch (e) {
      print('Error removing image from Firestore: $e'); // Handle errors
      _showMessage('Failed to remove the image.'); // Show failure message
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1),
      appBar: AppBar(
        title: const Text(
          'Vaccination Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFE2BF65), // AppBar color
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save), // Save icon
              onPressed: _saveChanges, // Call save changes function
            )
          else
            IconButton(
              icon: const Icon(Icons.edit), // Edit icon
              onPressed: () {
                setState(() {
                  _isEditing = true; // Enter editing mode
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(
              _vaccineNameController, // Vaccine name input
              'Vaccine Name',
              _isEditing,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectDate(context); // Allow date selection if editing
                }
              },
              child: AbsorbPointer(
                child: _buildTextField(
                  TextEditingController(
                    text: _selectedDate != null
                        ? "${_selectedDate.toLocal()}"
                            .split(' ')[0] // Display selected date
                        : '',
                  ),
                  'Vaccination Date',
                  true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectTime(context); // Allow time selection if editing
                }
              },
              child: AbsorbPointer(
                child: _buildTextField(
                  TextEditingController(
                    text:
                        _selectedTime.format(context), // Display selected time
                  ),
                  'Vaccination Time',
                  true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              _clinicController, // Clinic input
              'Clinic',
              _isEditing,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              _notesController, // Notes input
              'Notes',
              _isEditing,
            ),
            const SizedBox(height: 20),
            _buildImageDisplay(), // Display the uploaded image
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isEditing
                  ? _pickImage
                  : null, // Pick image only if in editing mode
              child: const Text(
                'Upload New Image',
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2BF65), // Button background color
              ),
            ),
            // Show the Remove Image button only if there is an image
            if (_imageFile != null ||
                (_latestVaccinationRecord.data() != null &&
                    _latestVaccinationRecord['documentUrl'] != null &&
                    _latestVaccinationRecord['documentUrl'] != ''))
              TextButton(
                onPressed: _isEditing
                    ? _showRemoveImageDialog
                    : null, // Allow removal if editing
                child: const Text('Remove Image'),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE2BF65),
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Create a reusable method for text fields
  Widget _buildTextField(
      TextEditingController controller, String label, bool enabled) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.grey,
              width: 2), // Color and width for enabled border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Color(0xFFE2BF65),
              width: 2), // Color and width for focused border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2), // Error border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide:
              const BorderSide(color: Colors.red, width: 2), // Focused error border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
      ),
      enabled: enabled, // Enable or disable based on editing state
    );
  }
}
