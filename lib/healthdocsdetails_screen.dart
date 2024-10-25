import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class HealthLogDetailScreen extends StatefulWidget {
  late final DocumentSnapshot logRecord;
  final String userId;

  HealthLogDetailScreen({required this.logRecord, required this.userId});

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

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.logRecord['title'] ?? '');
    _selectedDate = DateTime.tryParse(widget.logRecord['date'] ?? '');
    _doctorController =
        TextEditingController(text: widget.logRecord['doctor'] ?? '');
    _clinicController =
        TextEditingController(text: widget.logRecord['clinic'] ?? '');
    _treatmentController =
        TextEditingController(text: widget.logRecord['treatment'] ?? '');
    _notesController =
        TextEditingController(text: widget.logRecord['notes'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _clinicController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      // Show confirmation dialog before saving changes
      bool? confirmed = await _showConfirmationDialog();
      if (confirmed == true) {
        String? imageUrl;
        // Check if an image is selected, if not, set imageUrl to null
        if (_selectedImage != null) {
          imageUrl = await _uploadImageToFirebase(_selectedImage!);
        } else {
          imageUrl = null; // Explicitly set to null if no image is selected
        }
        await widget.logRecord.reference.update({
          'title': _titleController.text,
          'date': _selectedDate?.toIso8601String().split('T')[0],
          'doctor': _doctorController.text,
          'clinic': _clinicController.text,
          'treatment': _treatmentController.text,
          'notes': _notesController.text,
          'imageUrl': imageUrl,
        }).then((_) {
          // After saving, force the state to update
          setState(() {
            // Update the local logRecord to reflect changes
            (widget.logRecord.data() as Map<String, dynamic>)['imageUrl'] = imageUrl;
            _selectedImage = null; // Clear selected image after saving
            _isEditing = false; // Toggle to view mode
          });
          _showMessage('Changes saved successfully.');
        });
      }
    }
  }
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Color(0xFFE2BF65)),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _uploadImageToFirebase(File imageFile) async {
    try {
      String fileName =
          'medical_records/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
            _buildTextField(_titleController, 'Title',
                emptyMsg: 'Title cannot be empty'),
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
                        ? "${_selectedDate!.toLocal()}".split(' ')[0]
                        : '',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Date',
                    labelStyle: TextStyle(color: Colors.black),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE2BF65)),
                    ),
                    suffixIcon:
                        Icon(Icons.calendar_today, color: Color(0xFFE2BF65)),
                  ),
                  enabled: _isEditing,
                  validator: (value) =>
                      _selectedDate == null ? 'Please select a date' : null,
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(_doctorController, 'Doctor',
                emptyMsg: 'Doctor name cannot be empty'),
            _buildTextField(_clinicController, 'Clinic',
                emptyMsg: 'Clinic name cannot be empty'),
            _buildTextField(_treatmentController, 'Treatment',
                emptyMsg: 'Treatment details cannot be empty'),
            _buildTextField(
                _notesController, 'Notes'), // Updated to make Notes optional
            _buildImageSection(logRecord),
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
          validator: (value) =>
              emptyMsg != null && value!.isEmpty ? emptyMsg : null,
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
        SizedBox(height: 5),
        Container(
          height: 150,
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
        SizedBox(height: 10),
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
        // Attempt to remove the image from Firestore
        await widget.logRecord.reference.update({'imageUrl': null});

        // Force refresh Firestore data to ensure the removal was successful
        DocumentSnapshot updatedLogRecord =
            await widget.logRecord.reference.get();

        setState(() {
          _selectedImage = null;
          // Update the log record data in case Firestore successfully removed the image
          (widget.logRecord.data() as Map<String, dynamic>)['imageUrl'] =
              updatedLogRecord['imageUrl'];
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: Color(0xFFE2BF65)),
              child: Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}
