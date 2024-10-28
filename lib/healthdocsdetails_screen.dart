import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class HealthLogDetailScreen extends StatefulWidget {
  late final DocumentSnapshot logRecord; // Log record from Firestore
  final String userId; // User ID
  final String petName; // Pet name for notifications

  HealthLogDetailScreen({
    required this.logRecord,
    required this.userId,
    required this.petName, // Accept petName in the constructor
  });

  @override
  _HealthLogDetailScreenState createState() => _HealthLogDetailScreenState();
}

class _HealthLogDetailScreenState extends State<HealthLogDetailScreen> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  late TextEditingController _titleController; // Controller for task title
  late TextEditingController _doctorController; // Controller for doctor name
  late TextEditingController _clinicController; // Controller for clinic name
  late TextEditingController
      _treatmentController; // Controller for treatment details
  late TextEditingController _notesController; // Controller for notes
  DateTime? _selectedDate; // Selected date for the log entry
  bool _isEditing = false; // Edit mode toggle
  File? _selectedImage; // Holds the selected image

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin(); // Notification plugin instance

  @override
  void initState() {
    super.initState();
    _initializeNotifications(); // Initialize notifications
    _titleController = TextEditingController(
        text: widget.logRecord['title'] ?? ''); // Initialize controllers
    if (widget.logRecord['date'] != null) {
      _selectedDate = DateFormat('dd/MM/yyyy HH:mm')
          .parse(widget.logRecord['date']); // Parse date
    }
    _doctorController =
        TextEditingController(text: widget.logRecord['doctor'] ?? '');
    _clinicController =
        TextEditingController(text: widget.logRecord['clinic'] ?? '');
    _treatmentController =
        TextEditingController(text: widget.logRecord['treatment'] ?? '');
    _notesController =
        TextEditingController(text: widget.logRecord['notes'] ?? '');
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Android notification settings

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid, // Set Android settings
    );

    flutterLocalNotificationsPlugin
        .initialize(initializationSettings); // Initialize plugin
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      // Date picker
      context: context,
      initialDate: _selectedDate ?? DateTime.now(), // Default to today
      firstDate: DateTime(2000), // Earliest selectable date
      lastDate: DateTime(2101), // Latest selectable date
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        // Time picker
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            _selectedDate ?? DateTime.now()), // Default to current time
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            // Combine date and time
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _scheduleNotification(DateTime scheduledDateTime) async {
    final tz.TZDateTime tzScheduledDateTime =
        tz.TZDateTime.from(scheduledDateTime, tz.local); // Convert to TZ date

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Medical Appointment Reminder',
      '${widget.petName}`s ${_titleController.text} appointment', // Notification content
      tzScheduledDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medical_channel_id',
          'Medical Reminders',
          channelDescription: 'Notifications for scheduled medical reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      // Validate form
      bool? confirmed = await _showConfirmationDialog(); // Confirmation dialog
      if (confirmed == true) {
        String? imageUrl;

        if (_selectedImage != null) {
          imageUrl = await _uploadImageToFirebase(
              _selectedImage!); // Upload image if selected
        }

        await widget.logRecord.reference.update({
          'title': _titleController.text,
          'date': _selectedDate != null
              ? DateFormat('dd/MM/yyyy HH:mm')
                  .format(_selectedDate!) // Format date
              : null,
          'doctor': _doctorController.text,
          'clinic': _clinicController.text,
          'treatment': _treatmentController.text,
          'notes': _notesController.text,
          'imageUrl': imageUrl,
          'timestamp': _selectedDate != null
              ? Timestamp.fromDate(_selectedDate!) // Update timestamp
              : null,
        }).then((_) {
          setState(() {
            (widget.logRecord.data() as Map<String, dynamic>)['imageUrl'] =
                imageUrl; // Update local record
            _selectedImage = null; // Clear selected image
            _isEditing = false; // Exit edit mode
          });
          _showMessage('Changes saved successfully.'); // Success message

          // Schedule notification after saving changes
          if (_selectedDate != null) {
            _scheduleNotification(_selectedDate!); // Schedule notification
          }
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message))); // Show message
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Save'),
          content: const Text('Are you sure you want to save the changes?'),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // Cancel action
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Save action
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2BF65)),
              child: const Text('Save', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName =
          'medical_records/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Image file path
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child(fileName); // Reference to storage
      UploadTask uploadTask = storageRef.putFile(imageFile); // Upload task
      TaskSnapshot snapshot = await uploadTask; // Wait for upload to complete
      return await snapshot.ref.getDownloadURL(); // Return download URL
    } catch (e) {
      print('Error uploading image: $e'); // Log errors
      return null; // Return null on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Background color
      appBar: AppBar(
        title: const Text(
          'Medical Record Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFE2BF65), // App bar color
        actions: [
          IconButton(
            icon: Icon(_isEditing
                ? Icons.save
                : Icons.edit), // Icon changes based on editing state
            onPressed: () {
              if (_isEditing) {
                _saveRecord(); // Save changes if editing
              } else {
                setState(() {
                  _isEditing = true; // Enter edit mode
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // Fetch log record
        future: widget.logRecord.reference.get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator()); // Loading indicator
          }
          final logRecord = snapshot.data!; // Retrieved log record
          return _buildForm(logRecord); // Build form with data
        },
      ),
    );
  }

  Widget _buildForm(DocumentSnapshot logRecord) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16), // Padding for the form
      child: Form(
        key: _formKey, // Form key for validation
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align children to start
          children: [
            _buildTextField(_titleController, 'Title',
                emptyMsg: 'Title cannot be empty'), // Title field
            const SizedBox(height: 10), // Space between fields
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectDate(context); // Open date picker if editing
                }
              },
              child: AbsorbPointer(
                // Prevents editing directly in the text field
                child: TextFormField(
                  controller: TextEditingController(
                    text: _selectedDate != null
                        ? DateFormat('dd/MM/yyyy HH:mm')
                            .format(_selectedDate!) // Format date
                        : '',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Date & Time', // Label for date field
                    labelStyle: TextStyle(color: Colors.black),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.grey), // Border color
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Color(0xFFE2BF65)), // Focused border color
                    ),
                    suffixIcon: Icon(Icons.calendar_today,
                        color: Color(0xFFE2BF65)), // Calendar icon
                  ),
                  enabled: _isEditing, // Enable field only if editing
                  validator: (value) => _selectedDate == null
                      ? 'Please select a date'
                      : null, // Validation
                ),
              ),
            ),
            const SizedBox(height: 20), // Space between fields
            _buildTextField(_doctorController, 'Doctor',
                emptyMsg: 'Doctor name cannot be empty'), // Doctor field
            _buildTextField(_clinicController, 'Clinic',
                emptyMsg: 'Clinic name cannot be empty'), // Clinic field
            _buildTextField(_treatmentController, 'Treatment',
                emptyMsg:
                    'Treatment details cannot be empty'), // Treatment field
            _buildTextField(_notesController, 'Notes'), // Notes field
            _buildImageSection(logRecord), // Image section display
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? emptyMsg}) {
    return Column(
      children: [
        TextFormField(
          controller: controller, // Controller for the text field
          decoration: InputDecoration(
            labelText: label, // Label for the text field
            labelStyle: const TextStyle(color: Colors.black),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey), // Border color
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide:
                  BorderSide(color: Color(0xFFE2BF65)), // Focused border color
            ),
          ),
          enabled: _isEditing, // Enable field only if editing
          validator: (value) => emptyMsg != null && value!.isEmpty
              ? emptyMsg
              : null, // Validation message
        ),
        const SizedBox(height: 20), // Space between fields
      ],
    );
  }

  Widget _buildImageSection(DocumentSnapshot logRecord) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uploaded Image',
            style: TextStyle(
                fontWeight: FontWeight.bold)), // Section title for image
        const SizedBox(height: 10), // Space between title and image
        Container(
          height: 200, // Fixed height for the image container
          width: 380, // Fixed width for the image container
          color: Colors.grey[200], // Background color for the container
          child: _selectedImage == null // Check if there is a selected image
              ? (logRecord['imageUrl'] != null
                  ? Image.network(
                      // Display image from URL
                      logRecord['imageUrl'],
                      fit: BoxFit.cover, // Fill container
                    )
                  : const Center(
                      child:
                          Text('No image uploaded'))) // Placeholder if no image
              : Image.file(
                  // Display selected image
                  _selectedImage!,
                  fit: BoxFit.cover, // Fill container
                ),
        ),
        const SizedBox(height: 20), // Space below image
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _isEditing
                  ? _pickImage
                  : null, // Allow image selection if editing
              child: const Text('Change Image'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFFE2BF65), // Button background color
              ),
            ),
            if (logRecord['imageUrl'] != null ||
                _selectedImage != null) // Display remove button if image exists
              TextButton(
                onPressed: _isEditing
                    ? _removeImage
                    : null, // Allow removal if editing
                child: const Text('Remove Image'),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE2BF65), // Button background color
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker(); // Initialize image picker
    final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery); // Open gallery for image selection
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path); // Set selected image
      });
    }
  }

  void _removeImage() async {
    bool? confirmed =
        await _showConfirmationDialogRemove(); // Confirmation for image removal
    if (confirmed == true) {
      try {
        await widget.logRecord.reference
            .update({'imageUrl': null}); // Remove image URL from Firestore
        DocumentSnapshot updatedLogRecord =
            await widget.logRecord.reference.get(); // Fetch updated record
        setState(() {
          _selectedImage = null; // Clear selected image
          (widget.logRecord.data() as Map<String, dynamic>)['imageUrl'] =
              updatedLogRecord['imageUrl']; // Update local state
        });
      } catch (e) {
        print('Error removing image from Firestore: $e'); // Log errors
      }
    }
  }

  Future<bool?> _showConfirmationDialogRemove() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Removal'),
          content: const Text(
              'Are you sure you want to remove the image?'), // Confirmation dialog message
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // Cancel action
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Remove action
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2BF65)),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}
