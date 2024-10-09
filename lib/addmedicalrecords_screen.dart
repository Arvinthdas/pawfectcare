import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController _clinicController = TextEditingController();  // Controller for clinic
  final TextEditingController _notesController = TextEditingController();  // Controller for notes
  final TextEditingController _dateController = TextEditingController(); // Controller for date

  DateTime? _selectedDate;
  bool _isSaving = false;

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
        _dateController.text = _selectedDate!.toLocal().toString().split(' ')[0];
      });
    }
  }

  Future<void> _saveMedicalRecord() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      setState(() {
        _isSaving = true;
      });

      try {
        final medicalRecordData = {
          'title': _titleController.text,
          'date': _selectedDate!.toLocal().toString().split(' ')[0],
          'doctor': _doctorController.text,
          'clinic': _clinicController.text, // Save clinic information
          'treatment': _treatmentController.text,
          'notes': _notesController.text, // Save notes
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
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a date')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Add Medical Record'),
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
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                  validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        hintText: 'Select a date',
                      ),
                      validator: (value) => _selectedDate == null ? 'Please select a date' : null,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _doctorController,
                  decoration: InputDecoration(labelText: 'Doctor'),
                  validator: (value) => value!.isEmpty ? 'Please enter doctor\'s name' : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _clinicController,
                  decoration: InputDecoration(labelText: 'Clinic'),
                  validator: (value) => value!.isEmpty ? 'Please enter the clinic\'s name' : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _treatmentController,
                  decoration: InputDecoration(labelText: 'Treatment'),
                  maxLines: 4,
                  validator: (value) => value!.isEmpty ? 'Please enter the treatment details' : null,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(labelText: 'Notes'),
                  maxLines: 4,
                  validator: (value) => value!.isEmpty ? 'Please enter notes' : null,
                ),
                SizedBox(height: 20),
                _isSaving
                    ? Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _saveMedicalRecord,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Color(0xFFE2BF65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Save Record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
