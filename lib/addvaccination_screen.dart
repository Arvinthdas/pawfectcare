import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AddVaccinationScreen extends StatefulWidget {
  final String petId;
  final String userId;

  AddVaccinationScreen({required this.petId, required this.userId});

  @override
  _AddVaccinationScreenState createState() => _AddVaccinationScreenState();
}

class _AddVaccinationScreenState extends State<AddVaccinationScreen> {
  final _vaccineNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _veterinarianController = TextEditingController();
  final _clinicController = TextEditingController();
  final _notesController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedDocument;
  bool _isUploading = false;

  // Function to pick an image or document from the device
  Future<void> _pickDocument() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedDocument = File(pickedFile.path);
      });
    }
  }

  // Function to save vaccination details to Firestore
  Future<void> _addVaccination() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _isUploading = true;
      });

      String uid = user.uid;
      String documentUrl = '';

      // Upload document to storage if selected
      if (_selectedDocument != null) {
        documentUrl = await _uploadImageToStorage(uid, _selectedDocument!);
      }

      // Add vaccination details to Firestore
      await _firestore.collection('users').doc(uid).collection('pets')
          .doc(widget.petId).collection('vaccinations').add({
        'vaccineName': _vaccineNameController.text,
        'date': _dateController.text,
        'veterinarian': _veterinarianController.text,
        'clinic': _clinicController.text,
        'notes': _notesController.text,
        'documentUrl': documentUrl,
      });

      setState(() {
        _isUploading = false;
      });

      Navigator.pop(context); // Go back after adding the vaccination
    }
  }

  // Function to upload an image to Firebase Storage
  Future<String> _uploadImageToStorage(String uid, File imageFile) async {
    String fileName = 'vaccinations/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef = _storage.ref().child(fileName);
    UploadTask uploadTask = storageRef.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL(); // Get the download URL
  }

  // Function to show Date and Time Picker
  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        // Combine picked date and time
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Format the selected date and time as desired
        String formattedDateTime = "${selectedDateTime.toLocal()}".split(' ')[0] + " " +
            "${pickedTime.hour}:${pickedTime.minute.toString().padLeft(2, '0')}";

        setState(() {
          _dateController.text = formattedDateTime;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Vaccination Details'),
        backgroundColor: Color(0xFFE2BF65),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vaccine Name *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _vaccineNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter vaccine name',
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 15),
            Text('Date & Time of Vaccine *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter date and time',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              readOnly: true,
              onTap: _selectDateTime, // Show the date and time picker
            ),
            SizedBox(height: 15),
            Text('Veterinarian *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _veterinarianController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter veterinarian name',
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 15),
            Text('Clinic Name *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _clinicController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter clinic name',
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 15),
            Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter any notes',
                filled: true,
                fillColor: Colors.grey[200],
              ),
              maxLines: 3,
            ),
            SizedBox(height: 15),
            Text('Upload Document/Image', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            _selectedDocument != null
                ? Image.file(
              _selectedDocument!,
              height: 150,
              width: 150,
              fit: BoxFit.cover,
            )
                : Placeholder(
              fallbackHeight: 150,
              fallbackWidth: 150,
              color: Colors.grey,
              strokeWidth: 2,
            ),
            SizedBox(height: 15),
            ElevatedButton(
              onPressed: _pickDocument,
              child: Text('Pick Document/Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE2BF65),
                foregroundColor: Colors.black,
              ),
            ),
            SizedBox(height: 20),
            _isUploading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addVaccination,
                child: Text('Add Vaccination'),
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
