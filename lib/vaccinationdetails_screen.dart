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
  final DocumentSnapshot vaccinationRecord;
  final String petId;
  final String userId;
  final String petName;

  VaccinationDetailScreen({
    required this.vaccinationRecord,
    required this.petId,
    required this.userId,
    required this.petName
  });

  @override
  _VaccinationDetailScreenState createState() =>
      _VaccinationDetailScreenState();
}

class _VaccinationDetailScreenState extends State<VaccinationDetailScreen> {
  late TextEditingController _vaccineNameController;
  late TextEditingController _clinicController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  File? _imageFile;
  bool _isEditing = false;
  late DocumentSnapshot _latestVaccinationRecord;

  @override
  void initState() {
    super.initState();
    _latestVaccinationRecord = widget.vaccinationRecord;
    _fetchLatestVaccinationRecord();
    _initializeFields();
  }

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
        _latestVaccinationRecord = updatedRecord;
        _initializeFields();
      });
    } catch (e) {
      print('Error fetching latest vaccination record: $e');
    }
  }

  void _initializeFields() {
    _vaccineNameController =
        TextEditingController(text: _latestVaccinationRecord['vaccineName']);
    _clinicController =
        TextEditingController(text: _latestVaccinationRecord['clinic']);
    _notesController =
        TextEditingController(text: _latestVaccinationRecord['notes']);

    String dateStr = _latestVaccinationRecord['date'];
    try {
      final dateTime = DateFormat('dd/MM/yyyy HH:mm').parse(dateStr);
      _selectedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      _selectedTime = TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      print('Error parsing date: $e');
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _clinicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImageToStorage(String userId) async {
    if (_imageFile != null) {
      try {
        String fileName =
            'vaccinations/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(_imageFile!);
        TaskSnapshot snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
        return '';
      }
    }
    return '';
  }

  Future<void> _saveChanges() async {
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
      );
      final formattedDate =
      DateFormat('dd/MM/yyyy HH:mm').format(updatedDateTime);

      String imageUrl = await _uploadImageToStorage(widget.userId);

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

      _scheduleNotification(updatedDateTime,_vaccineNameController.text, widget.petName);
      _showMessage('Changes saved successfully');
      setState(() {
        _isEditing = false;
      });
    }
  }

  Future<void> _scheduleNotification(DateTime scheduledTime,String title, String petName) async {
    FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    await notificationsPlugin.zonedSchedule(
      widget.vaccinationRecord.hashCode,
      'Vaccination Reminder',
      '$petName `s $title vaccination appointment',
      scheduledDate,
      platformDetails,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Widget _buildImageDisplay() {
    if (_imageFile != null) {
      return Container(
        height: 200,
        width: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10), // Rounded corners
          border: Border.all(color: Colors.grey[300]!, width: 1), // Border color
          color: Colors.grey[200], // Background color
        ),
        child: GestureDetector(
          onTap: () {
            if (_isEditing) {
              _showRemoveImageDialog();
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10), // Ensure image fits within rounded corners
            child: Image.file(
              _imageFile!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else {
      String? documentUrl = _latestVaccinationRecord.data() != null &&
          (_latestVaccinationRecord.data() as Map<String, dynamic>)
              .containsKey('documentUrl')
          ? _latestVaccinationRecord['documentUrl']
          : null;

      if (documentUrl != null && documentUrl.isNotEmpty) {
        return Container(
          height: 200,
          width: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), // Rounded corners
            border: Border.all(color: Colors.grey[300]!, width: 1), // Border color
            color: Colors.grey[200], // Background color
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10), // Ensure image fits within rounded corners
            child: Image.network(
              documentUrl,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        return Container(
          height: 200,
          width: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), // Rounded corners
            border: Border.all(color: Colors.grey[300]!, width: 1), // Border color
            color: Colors.grey[200], // Background color
          ),
          child: Center( // Center the text inside the container
            child: Text(
              'No image uploaded',
              style: TextStyle(color: Colors.grey[600]), // Optional styling for the text
            ),
          ),
        );
      }
    }
  }



  Future<bool?> _showConfirmationDialog({required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

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

  void _removeImage() {
    // Clear the image locally and update the Firestore record
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

  Future<void> _removeImageFromFirestore() async {
    try {
      // Update Firestore to remove the image URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .doc(widget.vaccinationRecord.id)
          .update({'documentUrl': ''});

      // After removing from Firestore, we should fetch the latest data to update the local state
      DocumentSnapshot updatedRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .doc(widget.vaccinationRecord.id)
          .get();

      setState(() {
        _latestVaccinationRecord = updatedRecord;
      });

      _showMessage('Image removed successfully.');
    } catch (e) {
      print('Error removing image from Firestore: $e');
      _showMessage('Failed to remove the image.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text(
          'Vaccination Details',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
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
        child: Column(
          children: [
            _buildTextField(
              _vaccineNameController,
              'Vaccine Name',
              _isEditing,
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectDate(context);
                }
              },
              child: AbsorbPointer(
                child: _buildTextField(
                  TextEditingController(
                    text: _selectedDate != null
                        ? "${_selectedDate.toLocal()}".split(' ')[0]
                        : '',
                  ),
                  'Vaccination Date',
                  true,
                ),
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _selectTime(context);
                }
              },
              child: AbsorbPointer(
                child: _buildTextField(
                  TextEditingController(
                    text: _selectedTime.format(context),
                  ),
                  'Vaccination Time',
                  true,
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(
              _clinicController,
              'Clinic',
              _isEditing,
            ),
            SizedBox(height: 20),
            _buildTextField(
              _notesController,
              'Notes',
              _isEditing,
            ),
            SizedBox(height: 20),
            _buildImageDisplay(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isEditing ? _pickImage : null,
              child: Text(
                'Upload New Image',
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE2BF65), // Background color
              ),
            ),
            // Show the Remove Image button only if there is an image
            if (_imageFile != null || (_latestVaccinationRecord.data() != null && _latestVaccinationRecord['documentUrl'] != null && _latestVaccinationRecord['documentUrl'] != ''))
              TextButton(
                onPressed: _isEditing ? _showRemoveImageDialog : null,
                child: Text('Remove Image'),
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFFE2BF65),
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
        labelStyle: TextStyle(color: Colors.black),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: Colors.grey,
              width: 2), // Color and width for enabled border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: Color(0xFFE2BF65),
              width: 2), // Color and width for focused border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2), // Error border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide:
          BorderSide(color: Colors.red, width: 2), // Focused error border
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
      ),
      enabled: enabled,
    );
  }
}
