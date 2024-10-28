import 'package:flutter/material.dart'; // Import Flutter's Material UI components
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for database interactions
import 'package:intl/intl.dart'; // Import Intl for date formatting

// ActivityDetailsScreen class to show and edit activity details
class ActivityDetailsScreen extends StatefulWidget {
  final String activityId; // ID of the activity
  final String petId; // ID of the pet
  final String userId; // ID of the user

  ActivityDetailsScreen({
    required this.activityId,
    required this.petId,
    required this.userId,
  });

  @override
  _ActivityDetailsScreenState createState() => _ActivityDetailsScreenState();
}

// State class for ActivityDetailsScreen
class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final _durationController =
      TextEditingController(); // Controller for duration input
  final _notesController =
      TextEditingController(); // Controller for notes input
  String? _selectedActivityType; // Selected activity type
  String? _selectedIntensity; // Selected intensity level
  Timestamp? _selectedDate; // Selected date and time
  bool _isEditing = false; // Flag to indicate editing mode
  final List<String> _activityTypes = [
    'Walk',
    'Playtime',
    'Training',
    'Hiking',
    'Jogging',
    'Swimming'
  ]; // List of activity types
  final List<String> _intensityLevels = [
    'Low',
    'Moderate',
    'High'
  ]; // List of intensity levels
  bool _isLoading = true; // Flag to indicate loading state

  @override
  void initState() {
    super.initState();
    _loadActivityDetails(); // Load activity details when the screen is initialized
  }

  // Load activity details from Firestore
  Future<void> _loadActivityDetails() async {
    try {
      DocumentSnapshot activitySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('activityLogs')
          .doc(widget.activityId)
          .get(); // Fetch activity document

      if (activitySnapshot.exists) {
        // Check if document exists
        Map<String, dynamic> activityData = activitySnapshot.data()
            as Map<String, dynamic>; // Get activity data
        setState(() {
          // Update state with fetched data
          _selectedActivityType = activityData['activityType'];
          _selectedIntensity = activityData['intensity'];
          _durationController.text = activityData['duration'].toString();
          _notesController.text = activityData['notes'] ?? '';
          _selectedDate = activityData['date'];
          _isLoading = false; // Set loading to false
        });
      }
    } catch (e) {
      // Show error message if loading fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading activity details: $e')),
      );
    }
  }

  // Update activity details in Firestore
  Future<void> _updateActivity() async {
    if (!_validateFields()) {
      // Validate input fields
      return;
    }

    bool confirmSave =
        await _showConfirmationDialog(); // Show confirmation dialog
    if (!confirmSave) {
      return; // Don't proceed if user cancels
    }

    try {
      // Update activity document in Firestore
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
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity updated successfully!')),
      );
      setState(() {
        _isEditing = false; // Toggle back to view mode after saving
      });
    } catch (e) {
      // Show error message if updating fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating activity: $e')),
      );
    }
  }

  // Show a confirmation dialog before saving
  Future<bool> _showConfirmationDialog() async {
    return (await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Save'), // Dialog title
              content: const Text(
                  'Are you sure you want to save the changes?'), // Dialog content
              actions: [
                TextButton(
                  child: const Text('Cancel'), // Cancel button
                  onPressed: () {
                    Navigator.of(context).pop(false); // Return false on cancel
                  },
                ),
                TextButton(
                  child: const Text('Save'), // Save button
                  onPressed: () {
                    Navigator.of(context).pop(true); // Return true on save
                  },
                ),
              ],
            );
          },
        )) ??
        false; // Return false if dialog is dismissed
  }

  // Validate input fields
  bool _validateFields() {
    // Check if activity type is selected
    if (_selectedActivityType == null || _selectedActivityType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an activity type.')),
      );
      return false; // Validation failed
    }

    // Check if intensity level is selected
    if (_selectedIntensity == null || _selectedIntensity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an intensity level.')),
      );
      return false; // Validation failed
    }

    // Check if duration is valid
    if (_durationController.text.isEmpty ||
        int.tryParse(_durationController.text) == null ||
        int.parse(_durationController.text) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid duration.')),
      );
      return false; // Validation failed
    }

    // Check if date is selected
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time.')),
      );
      return false; // Validation failed
    }

    return true; // Validation passed
  }

  // Select date and time for the activity
  Future<void> _selectDateTime() async {
    // Show date picker dialog
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate != null ? _selectedDate!.toDate() : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      // If a date is picked
      // Show time picker dialog
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            _selectedDate != null ? _selectedDate!.toDate() : DateTime.now()),
      );

      if (pickedTime != null) {
        // If a time is picked
        setState(() {
          // Update selected date and time
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
    // Show loading indicator while loading activity details
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activity Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Format the selected date for display
    String formattedDate =
        DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!.toDate());

    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Background color of the screen
      appBar: AppBar(
        title: const Text(
          'Activity Details',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE2BF65), // AppBar color
        actions: [
          // Show save button if in editing mode, otherwise show edit button
          _isEditing
              ? IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _updateActivity,
                )
              : IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true; // Toggle to editing mode
                    });
                  },
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding around the content
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown(
                'Activity Type*', _activityTypes, _selectedActivityType,
                (value) {
              setState(() {
                _selectedActivityType = value; // Update selected activity type
              });
            }),
            const SizedBox(height: 15), // Space between fields
            _buildDropdown('Intensity *', _intensityLevels, _selectedIntensity,
                (value) {
              setState(() {
                _selectedIntensity = value; // Update selected intensity
              });
            }),
            const SizedBox(height: 15), // Space between fields
            _buildTextField('Duration (minutes) *', _durationController,
                inputType: TextInputType.number), // Duration input field
            const SizedBox(height: 15), // Space between fields
            GestureDetector(
              onTap: _isEditing
                  ? _selectDateTime
                  : null, // Open date picker if editing
              child: AbsorbPointer(
                // Prevent interaction if not in editing mode
                child: _buildTextField(
                    'Date & Time *',
                    TextEditingController(
                        text: formattedDate)), // Date & time input field
              ),
            ),
            const SizedBox(height: 15), // Space between fields
            _buildTextField('Notes', _notesController,
                maxLines: 3), // Notes input field
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
          onChanged: _isEditing
              ? onChanged
              : null, // Allow changes only in editing mode
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
          enabled: _isEditing, // Enable only if in editing mode
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
}
