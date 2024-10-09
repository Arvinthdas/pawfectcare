import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthLogDetailScreen extends StatefulWidget {
  final DocumentSnapshot logRecord;

  HealthLogDetailScreen({required this.logRecord});

  @override
  _HealthLogDetailScreenState createState() => _HealthLogDetailScreenState();
}

class _HealthLogDetailScreenState extends State<HealthLogDetailScreen> {
  final _formKey = GlobalKey<FormState>(); // Form key to manage validation
  late TextEditingController _titleController;
  late TextEditingController _doctorController;
  late TextEditingController _clinicController;
  late TextEditingController _treatmentController;
  late TextEditingController _notesController;
  DateTime? _selectedDate; // Variable to hold the selected date
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.logRecord['title'] ?? '');
    _selectedDate = DateTime.tryParse(widget.logRecord['date'] ?? ''); // Parse date from log
    _doctorController = TextEditingController(text: widget.logRecord['doctor'] ?? '');
    _clinicController = TextEditingController(text: widget.logRecord['clinic'] ?? '');
    _treatmentController = TextEditingController(text: widget.logRecord['treatment'] ?? '');
    _notesController = TextEditingController(text: widget.logRecord['notes'] ?? '');
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

  // Function to show date picker
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

  // Function to validate and save the record
  void _saveRecord() async {
    if (_formKey.currentState!.validate()) {
      // Show confirmation dialog
      bool? confirmed = await _showConfirmationDialog();
      if (confirmed == true) {
        widget.logRecord.reference.update({
          'title': _titleController.text,
          'date': _selectedDate?.toIso8601String().split('T')[0], // Save date in ISO format
          'doctor': _doctorController.text,
          'clinic': _clinicController.text,
          'treatment': _treatmentController.text,
          'notes': _notesController.text,
        }).then((_) => Navigator.pop(context));
      }
    }
  }

  // Function to show confirmation dialog
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE2BF65), // Using the app's theme color
              ),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Medical Record Details'),
        backgroundColor: Color(0xFFE2BF65), // Using the app's theme color
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveRecord, // Call the save function when saving
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey, // Assign the form key
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Title cannot be empty';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  if (_isEditing) {
                    _selectDate(context); // Open date picker on tap
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(
                        text: _selectedDate != null
                            ? "${_selectedDate!.toLocal()}".split(' ')[0]
                            : ''), // Display selected date
                    decoration: InputDecoration(
                      labelText: 'Date',
                      labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE2BF65)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFE2BF65)),
                      ),
                      suffixIcon: Icon(Icons.calendar_today, color: Color(0xFFE2BF65)),
                    ),
                    enabled: _isEditing,
                    validator: (value) {
                      if (_selectedDate == null) {
                        return 'Please select a date';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _doctorController,
                decoration: InputDecoration(
                  labelText: 'Doctor',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Doctor name cannot be empty';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _clinicController,
                decoration: InputDecoration(
                  labelText: 'Clinic',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Clinic name cannot be empty';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _treatmentController,
                decoration: InputDecoration(
                  labelText: 'Treatment',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                ),
                enabled: _isEditing,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Treatment details cannot be empty';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: TextStyle(color: Color(0xFFE2BF65)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE2BF65)),
                  ),
                ),
                enabled: _isEditing,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Notes cannot be empty';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
