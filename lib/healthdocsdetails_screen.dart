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
  late final DocumentSnapshot logRecord;
  final String userId;
  final String petName; // Added petName parameter

  HealthLogDetailScreen({
    required this.logRecord,
    required this.userId,
    required this.petName, // Accept petName in the constructor
  });

  @override
  _HealthLogDetailScreenState createState() => _HealthLogDetailScreenState();
}

class _HealthLogDetailScreenState extends State<HealthLogDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _doctorController;
  late TextEditingController _clinicController;
  late TextEditingController _treatmentController;
  late TextEditingController _notesController;
  DateTime? _selectedDate;
  bool _isEditing = false;
  File? _selectedImage;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _titleController = TextEditingController(text: widget.logRecord['title'] ?? '');
    if (widget.logRecord['date'] != null) {
      _selectedDate = DateFormat('dd/MM/yyyy HH:mm').parse(widget.logRecord['date']);
    }
    _doctorController = TextEditingController(text: widget.logRecord['doctor'] ?? '');
    _clinicController = TextEditingController(text: widget.logRecord['clinic'] ?? '');
    _treatmentController = TextEditingController(text: widget.logRecord['treatment'] ?? '');
    _notesController = TextEditingController(text: widget.logRecord['notes'] ?? '');
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
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
    final tz.TZDateTime tzScheduledDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      'Medical Appointment Reminder',
      '${widget.petName}`s ${_titleController.text} appointment', // Use petName and title
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      bool? confirmed = await _showConfirmationDialog();
      if (confirmed == true) {
        String? imageUrl;

        if (_selectedImage != null) {
          imageUrl = await _uploadImageToFirebase(_selectedImage!);
        }

        await widget.logRecord.reference.update({
          'title': _titleController.text,
          'date': _selectedDate != null
              ? DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!)
              : null,
          'doctor': _doctorController.text,
          'clinic': _clinicController.text,
          'treatment': _treatmentController.text,
          'notes': _notesController.text,
          'imageUrl': imageUrl,
          'timestamp': _selectedDate != null
              ? Timestamp.fromDate(_selectedDate!)
              : null,
        }).then((_) {
          setState(() {
            (widget.logRecord.data() as Map<String, dynamic>)['imageUrl'] = imageUrl;
            _selectedImage = null;
            _isEditing = false;
          });
          _showMessage('Changes saved successfully.');

          // Schedule notification after saving changes
          if (_selectedDate != null) {
            _scheduleNotification(_selectedDate!);
          }
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _showConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Save'),
          content: Text('Are you sure you want to save the changes?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE2BF65)),
              child: Text('Save', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'medical_records/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Medical Record Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Color(0xFFE2BF65),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveRecord();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: widget.logRecord.reference.get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final logRecord = snapshot.data!;
          return _buildForm(logRecord);
        },
      ),
    );
  }

  Widget _buildForm(DocumentSnapshot logRecord) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_titleController, 'Title', emptyMsg: 'Title cannot be empty'),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectDate(context);
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(
                    text: _selectedDate != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!) // Display both date and time
                        : '',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Date & Time',
                    labelStyle: TextStyle(color: Colors.black),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE2BF65)),
                    ),
                    suffixIcon: Icon(Icons.calendar_today, color: Color(0xFFE2BF65)),
                  ),
                  enabled: _isEditing,
                  validator: (value) => _selectedDate == null ? 'Please select a date' : null,
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(_doctorController, 'Doctor', emptyMsg: 'Doctor name cannot be empty'),
            _buildTextField(_clinicController, 'Clinic', emptyMsg: 'Clinic name cannot be empty'),
            _buildTextField(_treatmentController, 'Treatment', emptyMsg: 'Treatment details cannot be empty'),
            _buildTextField(_notesController, 'Notes'), // Updated to make Notes optional
            _buildImageSection(logRecord),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {String? emptyMsg}) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.black),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE2BF65)),
            ),
          ),
          enabled: _isEditing,
          validator: (value) => emptyMsg != null && value!.isEmpty ? emptyMsg : null,
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildImageSection(DocumentSnapshot logRecord) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Uploaded Image', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Container(
          height: 200,
          width: 380,
          color: Colors.grey[200],
          child: _selectedImage == null
              ? (logRecord['imageUrl'] != null
              ? Image.network(
            logRecord['imageUrl'],
            fit: BoxFit.cover,
          )
              : Center(child: Text('No image uploaded')))
              : Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _isEditing ? _pickImage : null,
              child: Text('Change Image'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Color(0xFFE2BF65),
              ),
            ),
            if (logRecord['imageUrl'] != null || _selectedImage != null)
              TextButton(
                onPressed: _isEditing ? _removeImage : null,
                child: Text('Remove Image'),
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFFE2BF65),
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _removeImage() async {
    bool? confirmed = await _showConfirmationDialogRemove();
    if (confirmed == true) {
      try {
        await widget.logRecord.reference.update({'imageUrl': null});
        DocumentSnapshot updatedLogRecord = await widget.logRecord.reference.get();
        setState(() {
          _selectedImage = null;
          (widget.logRecord.data() as Map<String, dynamic>)['imageUrl'] = updatedLogRecord['imageUrl'];
        });
      } catch (e) {
        print('Error removing image from Firestore: $e');
      }
    }
  }

  Future<bool?> _showConfirmationDialogRemove() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Removal'),
          content: Text('Are you sure you want to remove the image?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFE2BF65)),
              child: Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}
