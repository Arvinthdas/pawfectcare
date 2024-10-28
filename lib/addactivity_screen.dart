import 'package:flutter/material.dart'; // Import Flutter's Material UI components
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for database interactions
import 'package:intl/intl.dart'; // Import Intl for date formatting

// AddActivityScreen class for adding a new activity
class AddActivityScreen extends StatefulWidget {
  final String petId; // ID of the pet
  final String userId; // ID of the user

  AddActivityScreen({required this.petId, required this.userId});

  @override
  _AddActivityScreenState createState() => _AddActivityScreenState();
}

// State class for AddActivityScreen
class _AddActivityScreenState extends State<AddActivityScreen> {
  final _durationController =
      TextEditingController(); // Controller for duration input
  final _dateController = TextEditingController(); // Controller for date input
  final _notesController =
      TextEditingController(); // Controller for notes input
  String? _selectedActivityType; // Selected activity type
  String? _selectedIntensity; // Selected intensity level
  final List<String> _activityTypes = [
    'Walk',
    'Playtime',
    'Training',
    'Hiking',
    'Jogging',
    'Swimming'
  ]; // Activity types
  final List<String> _intensityLevels = [
    'Low',
    'Moderate',
    'High'
  ]; // Intensity levels
  bool _isSubmitting = false; // Flag for submission state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Background color of the screen
      appBar: AppBar(
        title: const Text(
          'Add Activity',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE2BF65), // AppBar color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding around the content
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown(
                'Activity Type *', _activityTypes, _selectedActivityType,
                (value) {
              setState(() {
                _selectedActivityType = value; // Update selected activity type
              });
            }),
            const SizedBox(height: 15), // Space between fields
            _buildTextField('Duration (minutes) *', _durationController,
                inputType: TextInputType.number), // Duration input field
            const SizedBox(height: 15), // Space between fields
            _buildDropdown('Intensity *', _intensityLevels, _selectedIntensity,
                (value) {
              setState(() {
                _selectedIntensity = value; // Update selected intensity
              });
            }),
            const SizedBox(height: 15), // Space between fields
            _buildDateTimeField(), // Date & time input field
            const SizedBox(height: 15), // Space between fields
            _buildTextField('Notes', _notesController,
                maxLines: 3), // Notes input field
            const SizedBox(height: 20), // Space between fields
            _isSubmitting // Show loading indicator or button based on submission state
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _addActivity, // Call _addActivity on button press
                      child: const Text('Add Activity'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: const Color(0xFFE2BF65),
                        padding: const EdgeInsets.symmetric(
                            vertical: 15), // Button padding
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // Build a dropdown field
  Widget _buildDropdown(String label, List<String> items, String? selectedValue,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)), // Dropdown label
        DropdownButtonFormField<String>(
          // Dropdown button
          value: selectedValue,
          hint: Text('Select $label'), // Hint text
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item), // Dropdown item
            );
          }).toList(),
          onChanged: onChanged, // Change handler
          decoration: InputDecoration(
            border: const OutlineInputBorder(), // Input decoration
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  // Build a text input field
  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)), // Input field label
        TextField(
          controller: controller, // Controller for the input field
          keyboardType: inputType, // Input type (text or number)
          maxLines: maxLines, // Number of lines for the input field
          decoration: InputDecoration(
            border: const OutlineInputBorder(), // Input decoration
            hintText: 'Enter $label', // Hint text
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  // Build a date & time input field
  Widget _buildDateTimeField() {
    return GestureDetector(
      onTap: _selectDateTime, // Open date picker on tap
      child: AbsorbPointer(
        // Prevent interaction if not editable
        child: _buildTextField('Date & Time of Activity *',
            _dateController), // Date & time input field
      ),
    );
  }

  // Function to select date and time
  Future<void> _selectDateTime() async {
    // Show date picker dialog
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      // If a date is picked
      // Show time picker dialog
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        // If a time is picked
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Format the selected date and time
        String formattedDateTime =
            DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime);
        setState(() {
          _dateController.text =
              formattedDateTime; // Update date controller text
        });
      }
    }
  }

  // Function to add the activity to Firestore
  Future<void> _addActivity() async {
    // Check for required fields
    if (_selectedActivityType == null ||
        _selectedIntensity == null ||
        _durationController.text.isEmpty ||
        _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill in all required fields')), // Show error message
      );
      return; // Exit if validation fails
    }

    setState(() {
      _isSubmitting = true; // Set submission state to true
    });

    try {
      // Parse the activity date from the date controller
      final DateTime activityDate =
          DateFormat('dd/MM/yyyy HH:mm').parse(_dateController.text);

      // Save activity data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .add({
        'activityType': _selectedActivityType, // Activity type
        'duration': int.parse(_durationController.text), // Duration in minutes
        'intensity': _selectedIntensity, // Intensity level
        'date': activityDate, // Date and time of activity
        'notes': _notesController.text, // Notes for the activity
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity added successfully!')),
      );

      // Clear form and go back to the previous screen
      _clearForm();
      Navigator.pop(context);
    } catch (e) {
      // Show error message if adding activity fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding activity: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false; // Reset submission state
      });
    }
  }

  // Clear the input form fields
  void _clearForm() {
    _durationController.clear(); // Clear duration field
    _dateController.clear(); // Clear date field
    _notesController.clear(); // Clear notes field
    setState(() {
      _selectedActivityType = null; // Reset activity type
      _selectedIntensity = null; // Reset intensity level
    });
  }
}
