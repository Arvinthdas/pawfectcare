import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final String activityId;
  final String petId;
  final String userId;

  ActivityDetailsScreen({
    required this.activityId,
    required this.petId,
    required this.userId,
  });

  @override
  _ActivityDetailsScreenState createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedActivityType;
  String? _selectedIntensity;
  Timestamp? _selectedDate;
  bool _isEditing = false;
  final List<String> _activityTypes = ['Walk', 'Playtime', 'Training', 'Hiking', 'Jogging', 'Swimming'];
  final List<String> _intensityLevels = ['Low', 'Moderate', 'High'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivityDetails();
  }

  Future<void> _loadActivityDetails() async {
    try {
      DocumentSnapshot activitySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .doc(widget.activityId)
          .get();

      if (activitySnapshot.exists) {
        Map<String, dynamic> activityData = activitySnapshot.data() as Map<String, dynamic>;
        setState(() {
          _selectedActivityType = activityData['activityType'];
          _selectedIntensity = activityData['intensity'];
          _durationController.text = activityData['duration'].toString();
          _notesController.text = activityData['notes'] ?? '';
          _selectedDate = activityData['date'];
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity details: $e')),
      );
    }
  }

  Future<void> _updateActivity() async {
    if (!_validateFields()) {
      return;
    }

    bool confirmSave = await _showConfirmationDialog();
    if (!confirmSave) {
      return; // If the user cancels, don't proceed with saving.
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .doc(widget.activityId)
          .update({
        'activityType': _selectedActivityType,
        'intensity': _selectedIntensity,
        'duration': int.parse(_durationController.text),
        'notes': _notesController.text,
        'date': _selectedDate,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity updated successfully!')),
      );
      setState(() {
        _isEditing = false; // Toggle back to view mode after saving
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating activity: $e')),
      );
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return (await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Save'),
          content: Text('Are you sure you want to save the changes?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    )) ?? false;
  }

  bool _validateFields() {
    if (_selectedActivityType == null || _selectedActivityType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an activity type.')),
      );
      return false;
    }

    if (_selectedIntensity == null || _selectedIntensity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an intensity level.')),
      );
      return false;
    }

    if (_durationController.text.isEmpty || int.tryParse(_durationController.text) == null || int.parse(_durationController.text) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid duration.')),
      );
      return false;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date and time.')),
      );
      return false;
    }

    return true;
  }

  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null ? _selectedDate!.toDate() : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate != null ? _selectedDate!.toDate() : DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = Timestamp.fromDate(
            DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Activity Details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!.toDate());

    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        title: Text('Activity Details',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFE2BF65),
        actions: [
          _isEditing
              ? IconButton(
            icon: Icon(Icons.save),
            onPressed: _updateActivity,
          )
              : IconButton(
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown('Activity Type*', _activityTypes, _selectedActivityType, (value) {
              setState(() {
                _selectedActivityType = value;
              });
            }),
            SizedBox(height: 15),
            _buildDropdown('Intensity *', _intensityLevels, _selectedIntensity, (value) {
              setState(() {
                _selectedIntensity = value;
              });
            }),
            SizedBox(height: 15),
            _buildTextField('Duration (minutes) *', _durationController, inputType: TextInputType.number),
            SizedBox(height: 15),
            GestureDetector(
              onTap: _isEditing ? _selectDateTime : null,
              child: AbsorbPointer(
                child: _buildTextField('Date & Time *', TextEditingController(text: formattedDate)),
              ),
            ),
            SizedBox(height: 15),
            _buildTextField('Notes', _notesController, maxLines: 3),
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
          onChanged: _isEditing ? onChanged : null,
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
          enabled: _isEditing,
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
}
