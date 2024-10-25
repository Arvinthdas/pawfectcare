import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AddMedicalRecordScreen extends StatefulWidget {
  final String petId;
  final String userId;

  AddMedicalRecordScreen({required this.petId, required this.userId});

  @override
  _AddMedicalRecordScreenState createState() => _AddMedicalRecordScreenState();
}

class _AddMedicalRecordScreenState extends State<AddMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _treatmentController = TextEditingController();
  final TextEditingController _clinicController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _isSaving = false;
  File? _selectedImage;

  Future<void> _selectDateTime(BuildContext context) async {
    // Show Date Picker
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    // If a date is selected, show Time Picker
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
      );

      // Combine the selected date and time
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _dateController.text = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime!);
        });
      }
    }
  }

  Future<void> _saveMedicalRecord() async {
    if (_formKey.currentState!.validate() && _selectedDateTime != null) {
      setState(() {
        _isSaving = true;
      });

      try {
        String? imageUrl;
        if (_selectedImage != null) {
          imageUrl = await _uploadImageToFirebase(_selectedImage!);
        }

        final medicalRecordData = {
          'title': _titleController.text,
          'date': _selectedDateTime!.toLocal().toString().split(' ')[0],
          'doctor': _doctorController.text,
          'clinic': _clinicController.text,
          'treatment': _treatmentController.text,
          'notes': _notesController.text,
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('pets')
            .doc(widget.petId)
            .collection('medicalRecords')
            .add(medicalRecordData);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Medical record added successfully')));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add medical record')));
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    } else if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a date and time')));
    }
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName = 'medical_records/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL(); // Get download URL
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
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

  void _removeImage() {
    setState(() {
      _selectedImage = null; // Clear the selected image
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Add Medical Record',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),),
        backgroundColor: Color(0xFFE2BF65),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Title *', _titleController),
                SizedBox(height: 15),
                _buildDateTimeField(),
                SizedBox(height: 15),
                _buildTextField('Doctor *', _doctorController),
                SizedBox(height: 15),
                _buildTextField('Clinic *', _clinicController),
                SizedBox(height: 15),
                _buildTextField('Treatment *', _treatmentController, maxLines: 4),
                SizedBox(height: 15),
                _buildTextField('Notes', _notesController, maxLines: 4, isRequired: false),
                SizedBox(height: 15),
                _buildImageUploadSection(),
                SizedBox(height: 20),
                _isSaving
                    ? Center(child: CircularProgressIndicator())
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveMedicalRecord,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Color(0xFFE2BF65),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Save Record'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool isRequired = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter $label',
            filled: true,
            fillColor: Colors.grey[200],
          ),
          validator: (value) {
            if (isRequired && (value == null || value.isEmpty)) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }


  Widget _buildDateTimeField() {
    return GestureDetector(
      onTap: () => _selectDateTime(context),
      child: AbsorbPointer(
        child: _buildTextField('Date & Time *', _dateController),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Image (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        Container(
          height: 150,
          color: Colors.grey[200],
          child: _selectedImage == null
              ? Center(child: Text('Image Preview'))
              : Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _pickImage,
          child: Text('Pick Image'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Color(0xFFE2BF65),
          ),
        ),
        if (_selectedImage != null)
          TextButton(
            onPressed: _removeImage,
            child: Text('Remove Image'),
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFFE2BF65),
              foregroundColor: Colors.red,
            ),
          ),
      ],
    );
  }
}
