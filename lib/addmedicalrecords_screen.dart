import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AddMedicalRecordScreen extends StatefulWidget {
  final String petId; // Pet's ID
  final String userId; // User's ID
  final String petName; // Pet's name

  AddMedicalRecordScreen({
    required this.petId,
    required this.userId,
    required this.petName,
  });

  @override
  _AddMedicalRecordScreenState createState() => _AddMedicalRecordScreenState();
}

class _AddMedicalRecordScreenState extends State<AddMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final TextEditingController _titleController = TextEditingController(); // Controller for title
  final TextEditingController _doctorController = TextEditingController(); // Controller for doctor name
  final TextEditingController _treatmentController = TextEditingController(); // Controller for treatment details
  final TextEditingController _clinicController = TextEditingController(); // Controller for clinic name
  final TextEditingController _notesController = TextEditingController(); // Controller for additional notes
  final TextEditingController _dateController = TextEditingController(); // Controller for date and time

  DateTime? _selectedDateTime; // Variable for storing selected date and time
  bool _isSaving = false; // Flag to indicate if data is being saved
  File? _selectedImage; // Variable for storing selected image

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(); // For local notifications

  @override
  void initState() {
    super.initState();
    _initializeNotifications(); // Initialize notifications
  }

  // Initialize notification settings
  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings); // Set up notification initialization
  }

  // Function to select date and time
  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _dateController.text = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime!); // Format date
        });
      }
    }
  }

  // Function to schedule notifications
  Future<void> _scheduleNotification(DateTime scheduledDateTime, String title, String petName) async {
    final tz.TZDateTime tzScheduledDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local); // Convert to TZDateTime

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Medical Appointment Reminder',
      '$petName’s $title appointment', // Notification message
      tzScheduledDateTime, // Scheduled time
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medical_channel_id',
          'Medical Reminders',
          channelDescription: 'Notifications for scheduled medical reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true, // Allow notification even when idle
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Match time components for repeat notifications
    );
  }

  // Function to save the medical record
  Future<void> _saveMedicalRecord() async {
    if (_formKey.currentState!.validate() && _selectedDateTime != null) {
      setState(() {
        _isSaving = true; // Start saving process
      });

      try {
        String? imageUrl;
        // Upload image if one was selected
        if (_selectedImage != null) {
          imageUrl = await _uploadImageToFirebase(_selectedImage!);
        }

        // Prepare medical record data
        final medicalRecordData = {
          'title': _titleController.text,
          'date': DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime!),
          'doctor': _doctorController.text,
          'clinic': _clinicController.text,
          'treatment': _treatmentController.text,
          'notes': _notesController.text,
          'imageUrl': imageUrl,
          'timestamp': Timestamp.fromDate(_selectedDateTime!), // Timestamp for Firestore
        };

        // Save medical record to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('pets')
            .doc(widget.petId)
            .collection('medicalRecords')
            .add(medicalRecordData);

        // Schedule notification
        await _scheduleNotification(_selectedDateTime!, _titleController.text, widget.petName);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Medical record added successfully')));
        Navigator.pop(context); // Go back after saving
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add medical record')));
      } finally {
        setState(() {
          _isSaving = false; // End saving process
        });
      }
    } else if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a date and time')));
    }
  }

  // Function to upload an image to Firebase Storage
  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'medical_records/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Unique file name
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName); // Reference to storage
      UploadTask uploadTask = storageRef.putFile(imageFile); // Upload task
      TaskSnapshot snapshot = await uploadTask; // Wait for upload to complete
      return await snapshot.ref.getDownloadURL(); // Get download URL
    } catch (e) {
      print('Error uploading image: $e'); // Log error
      return null; // Return null if failed
    }
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // Set the selected image
      });
    }
  }

  // Function to remove the selected image
  void _removeImage() {
    setState(() {
      _selectedImage = null; // Clear the selected image
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1), // Background color
      appBar: AppBar(
        title: Text('Add Medical Record',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFE2BF65), // AppBar color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Padding for the body
        child: Form(
          key: _formKey, // Form key for validation
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Title *', _titleController), // Title field
                SizedBox(height: 15),
                _buildDateTimeField(), // Date and time field
                SizedBox(height: 15),
                _buildTextField('Doctor *', _doctorController), // Doctor field
                SizedBox(height: 15),
                _buildTextField('Clinic *', _clinicController), // Clinic field
                SizedBox(height: 15),
                _buildTextField('Treatment *', _treatmentController, maxLines: 4), // Treatment field
                SizedBox(height: 15),
                _buildTextField('Notes', _notesController, maxLines: 4, isRequired: false), // Notes field
                SizedBox(height: 15),
                _buildImageUploadSection(), // Image upload section
                SizedBox(height: 20),
                _isSaving
                    ? Center(child: CircularProgressIndicator()) // Show loading indicator while saving
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveMedicalRecord, // Save button
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Color(0xFFE2BF65),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Save Record'), // Button text
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Function to build a text field
  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool isRequired = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)), // Label for the text field
        TextFormField(
          controller: controller, // Controller for the field
          maxLines: maxLines, // Max lines for the field
          decoration: InputDecoration(
            border: OutlineInputBorder(), // Border style
            hintText: 'Enter $label', // Hint text
            filled: true,
            fillColor: Colors.grey[200], // Fill color
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'Please enter $label'; // Validation error
            }
            return null; // No error
          },
        ),
      ],
    );
  }

  // Function to build date and time field
  Widget _buildDateTimeField() {
    return GestureDetector(
      onTap: () => _selectDateTime(context), // Open date picker on tap
      child: AbsorbPointer(
        child: _buildTextField('Date & Time *', _dateController), // Date and time text field
      ),
    );
  }

  // Function to build the image upload section
  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Image (optional)', style: TextStyle(fontWeight: FontWeight.bold)), // Upload section label
        SizedBox(height: 5),
        Container(
          height: 200,
          width: 380,
          color: Colors.grey[200], // Background color for image preview
          child: _selectedImage == null
              ? Center(child: Text('Image Preview')) // Placeholder text when no image is selected
              : Image.file(
            _selectedImage!,
            fit: BoxFit.cover, // Fit image in the container
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _pickImage, // Button to pick an image
          child: Text('Pick Image'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Color(0xFFE2BF65),
          ),
        ),
        if (_selectedImage != null) // Show remove button if an image is selected
          TextButton(
            onPressed: _removeImage,
            child: Text('Remove Image'),
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFE2BF65),
              foregroundColor: Colors.black,
            ),
          ),
      ],
    );
  }
}
