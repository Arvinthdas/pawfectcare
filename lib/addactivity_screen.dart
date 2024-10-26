import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddActivityScreen extends StatefulWidget {
  final String petId;
  final String userId;

  AddActivityScreen({required this.petId, required this.userId});

  @override
  _AddActivityScreenState createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _durationController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController(); // New controller for notes
  String? _selectedActivityType;
  String? _selectedIntensity;
  final List<String> _activityTypes = ['Walk', 'Playtime', 'Training', 'Hiking', 'Jogging', 'Swimming'];
  final List<String> _intensityLevels = ['Low', 'Moderate', 'High'];
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Add Activity',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFE2BF65),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown('Activity Type *', _activityTypes, _selectedActivityType, (value) {
              setState(() {
                _selectedActivityType = value;
              });
            }),
            SizedBox(height: 15),
            _buildTextField('Duration (minutes) *', _durationController, inputType: TextInputType.number),
            SizedBox(height: 15),
            _buildDropdown('Intensity *', _intensityLevels, _selectedIntensity, (value) {
              setState(() {
                _selectedIntensity = value;
              });
            }),
            SizedBox(height: 15),
            _buildDateTimeField(),
            SizedBox(height: 15),
            _buildTextField('Notes', _notesController, maxLines: 3), // New Notes field
            SizedBox(height: 20),
            _isSubmitting
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addActivity,
                child: Text('Add Activity'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Color(0xFFE2BF65),
                  padding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? selectedValue, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(
          value: selectedValue,
          hint: Text('Select $label'),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType inputType = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: controller,
          keyboardType: inputType,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter $label',
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeField() {
    return GestureDetector(
      onTap: _selectDateTime,
      child: AbsorbPointer(
        child: _buildTextField('Date & Time of Activity *', _dateController),
      ),
    );
  }

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
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        String formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime);
        setState(() {
          _dateController.text = formattedDateTime;
        });
      }
    }
  }

  Future<void> _addActivity() async {
    if (_selectedActivityType == null || _selectedIntensity == null || _durationController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final DateTime activityDate = DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .add({
        'activityType': _selectedActivityType,
        'duration': int.parse(_durationController.text),
        'intensity': _selectedIntensity,
        'date': activityDate,
        'notes': _notesController.text, // Save the notes
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity added successfully!')),
      );

      // Clear form and go back to the previous screen
      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding activity: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _clearForm() {
    _durationController.clear();
    _dateController.clear();
    _notesController.clear(); // Clear notes field
    setState(() {
      _selectedActivityType = null;
      _selectedIntensity = null;
    });
  }
}
