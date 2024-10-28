import 'dart:io'; // Importing Dart's IO library for file handling.
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:cloud_firestore/cloud_firestore.dart'; // Importing Cloud Firestore for database interactions.
import 'package:intl/intl.dart'; // Importing Intl package for date formatting.
import 'package:image_picker/image_picker.dart'; // Importing image picker for selecting images.
import 'package:firebase_storage/firebase_storage.dart'; // Importing Firebase Storage for image uploading.

class FoodDetailScreen extends StatefulWidget {
  final String foodId; // ID of the food item.
  final String userId; // ID of the user.
  final String petId; // ID of the pet.

  FoodDetailScreen({
    required this.foodId,
    required this.userId,
    required this.petId,
  });

  @override
  _FoodDetailScreenState createState() =>
      _FoodDetailScreenState(); // Creating state for this screen.
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  // Controllers for text fields to capture user input.
  TextEditingController? _foodNameController;
  TextEditingController? _calciumController;
  TextEditingController? _carbsController;
  TextEditingController? _fatController;
  TextEditingController? _proteinController;
  TextEditingController? _vitaminsController;

  String? _selectedFoodType; // Variable to store selected food type.
  late DateTime _selectedDate; // Variable to store selected date.
  late TimeOfDay _selectedTime; // Variable to store selected time.
  File? _imageFile; // Variable to store the picked image file.
  bool _isEditing = false; // Flag to indicate if the screen is in editing mode.
  late DocumentSnapshot
      _latestFoodRecord; // Variable to hold the latest food record from Firestore.
  String? _imageUrl; // Variable to store the image URL from Firestore.

  final List<String> _foodTypes = [
    // List of food types.
    'Dry',
    'Wet',
    'Semi-Moist',
    'Raw',
  ];

  @override
  void initState() {
    super.initState(); // Calling the superclass's initState method.
    _selectedDate =
        DateTime.now(); // Initializing selected date to current date.
    _selectedTime =
        TimeOfDay.now(); // Initializing selected time to current time.
    _fetchFoodDetails(); // Fetching food details from Firestore.
  }

  // Fetch food details from Firestore.
  Future<void> _fetchFoodDetails() async {
    try {
      // Getting the food document from Firestore using userId, petId, and foodId.
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('foods')
          .doc(widget.foodId)
          .get();

      if (snapshot.exists) {
        // Checking if the food item exists.
        setState(() {
          _latestFoodRecord = snapshot; // Storing the fetched record.
          _initializeFields(); // Initializing fields with fetched data.
          _imageUrl = _latestFoodRecord['imageUrl']; // Getting the image URL.
        });
      } else {
        throw Exception(
            "Food item not found"); // Throwing an error if food item is not found.
      }
    } catch (e) {
      print(
          'Error fetching food details: $e'); // Printing error message to console.
      _showMessage(
          'Error fetching food details: $e'); // Showing error message to the user.
    }
  }

  // Initializing fields with data from the latest food record.
  void _initializeFields() {
    // Initializing text controllers with data from the fetched record.
    _foodNameController =
        TextEditingController(text: _latestFoodRecord['foodName'] ?? '');
    _calciumController = TextEditingController(
        text: (_latestFoodRecord['calcium'] ?? 0).toString());
    _carbsController = TextEditingController(
        text: (_latestFoodRecord['carbs'] ?? 0).toString());
    _fatController =
        TextEditingController(text: (_latestFoodRecord['fat'] ?? 0).toString());
    _proteinController = TextEditingController(
        text: (_latestFoodRecord['protein'] ?? 0).toString());
    _vitaminsController = TextEditingController(
        text: (_latestFoodRecord['vitamins'] ?? 0).toString());
    _selectedFoodType =
        _latestFoodRecord['foodType'] ?? 'Dry'; // Getting the food type.

    // Getting the timestamp and converting it to DateTime.
    Timestamp? dateTimestamp = _latestFoodRecord['timestamp'];
    final dateTime =
        dateTimestamp != null ? dateTimestamp.toDate() : DateTime.now();
    _selectedDate = dateTime; // Setting the selected date.
    _selectedTime =
        TimeOfDay.fromDateTime(dateTime); // Setting the selected time.
  }

  @override
  void dispose() {
    // Disposing controllers to free up resources.
    _foodNameController?.dispose();
    _calciumController?.dispose();
    _carbsController?.dispose();
    _fatController?.dispose();
    _proteinController?.dispose();
    _vitaminsController?.dispose();
    super.dispose(); // Calling superclass's dispose method.
  }

  // Picking an image from the gallery.
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery); // Picking image from gallery.
    if (pickedFile != null) {
      // Checking if an image was picked.
      setState(() {
        _imageFile = File(pickedFile.path); // Storing the picked image file.
        _imageUrl = null; // Clearing the previous image URL.
      });
    }
  }

  // Uploading the image to Firebase Storage.
  Future<String?> _uploadImageToStorage(String userId) async {
    if (_imageFile != null) {
      // Checking if an image file is selected.
      try {
        String fileName =
            'food_images/${userId}/${DateTime.now().millisecondsSinceEpoch}.jpg'; // Creating a unique file name.
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child(fileName); // Getting a reference to storage.
        UploadTask uploadTask =
            storageRef.putFile(_imageFile!); // Uploading the image file.
        TaskSnapshot snapshot =
            await uploadTask; // Getting the snapshot of the upload.
        return await snapshot.ref
            .getDownloadURL(); // Returning the download URL of the uploaded image.
      } catch (e) {
        print(
            'Error uploading image: $e'); // Printing error message to console.
        return null; // Returning null if upload fails.
      }
    }
    return null; // Returning null if no image is selected.
  }

  // Confirming whether to save changes.
  Future<void> _confirmSaveChanges() async {
    final result = await showDialog<bool>(
      // Showing a confirmation dialog.
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Save'), // Dialog title.
          content: const Text(
              'Are you sure you want to save the changes?'), // Dialog content.
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // Cancel action.
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Save action.
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // If user confirms saving changes.
      _saveChanges(); // Calling the function to save changes.
    }
  }

  // Saving changes to Firestore.
  Future<void> _saveChanges() async {
    if (_foodNameController?.text.isEmpty ??
        true || _selectedFoodType == null) {
      _showMessage(
          'Please fill in all required fields'); // Alerting user if required fields are empty.
      return; // Exiting the function if fields are invalid.
    }

    // Creating a DateTime object for the selected date and time.
    final updatedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Uploading the image and getting the URL or using the previous image URL.
    String? imageUrl = await _uploadImageToStorage(widget.userId) ?? _imageUrl;

    try {
      // Updating the food document in Firestore with new values.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('foods')
          .doc(widget.foodId)
          .update({
        'foodName': _foodNameController!.text, // Updating food name.
        'foodType': _selectedFoodType, // Updating food type.
        'calcium': double.tryParse(_calciumController?.text ?? '0') ??
            0, // Updating calcium.
        'carbs': double.tryParse(_carbsController?.text ?? '0') ??
            0, // Updating carbs.
        'fat':
            double.tryParse(_fatController?.text ?? '0') ?? 0, // Updating fat.
        'protein': double.tryParse(_proteinController?.text ?? '0') ??
            0, // Updating protein.
        'vitamins': double.tryParse(_vitaminsController?.text ?? '0') ??
            0, // Updating vitamins.
        'imageUrl': imageUrl, // Updating image URL.
        'timestamp': Timestamp.fromDate(updatedDateTime), // Updating timestamp.
      });

      setState(() {
        _imageUrl = imageUrl; // Setting the new image URL.
        _isEditing = false; // Setting editing mode to false.
        _imageFile = null; // Clearing the image file.
      });

      _showMessage('Changes saved successfully'); // Alerting user of success.
    } catch (e) {
      print('Error updating food item: $e'); // Printing error message.
      _showMessage('Failed to save changes: $e'); // Alerting user of failure.
    }
  }

  // Confirming whether to remove the image.
  Future<void> _confirmRemoveImage() async {
    final result = await showDialog<bool>(
      // Showing a confirmation dialog.
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Image'), // Dialog title.
          content: const Text(
              'Are you sure you want to remove this image?'), // Dialog content.
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // Cancel action.
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(true), // Remove action.
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // If user confirms removal.
      setState(() {
        _imageFile = null; // Clearing the image file.
        _imageUrl = null; // Clearing the image URL.
      });
    }
  }

  // Selecting a date from the date picker.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate, // Preselected date.
      firstDate: DateTime(2000), // Earliest selectable date.
      lastDate: DateTime(2101), // Latest selectable date.
    );
    if (picked != null) {
      // If a date was picked.
      setState(() {
        _selectedDate = picked; // Updating the selected date.
      });
    }
  }

  // Selecting a time from the time picker.
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime, // Preselected time.
    );
    if (picked != null) {
      // If a time was picked.
      setState(() {
        _selectedTime = picked; // Updating the selected time.
      });
    }
  }

  // Showing a message to the user via a SnackBar.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)), // Creating a SnackBar with the message.
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Setting background color.
      appBar: AppBar(
        backgroundColor: const Color(0xFFE2BF65), // AppBar color.
        title: const Text(
          'Food Details', // AppBar title.
          style: TextStyle(
            color: Colors.black, // Title text color.
            fontFamily: 'Poppins', // Title font family.
            fontWeight: FontWeight.bold, // Title text weight.
            fontSize: 20, // Title font size.
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing
                ? Icons.save
                : Icons.edit), // Icon changes based on editing state.
            onPressed: _isEditing
                ? _confirmSaveChanges // Call the confirm save function if editing.
                : () {
                    setState(() {
                      _isEditing = true; // Set editing mode to true.
                    });
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Padding around the body.
        child: SingleChildScrollView(
          // Allowing scroll for the body content.
          child: Column(
            children: [
              TextField(
                controller:
                    _foodNameController, // Controller for food name input.
                decoration: const InputDecoration(
                  labelText: 'Food Name', // Label for food name input.
                  labelStyle: TextStyle(fontSize: 20), // Label font size.
                  border: OutlineInputBorder(), // Border style for the input.
                ),
                enabled:
                    _isEditing, // Enable editing based on the editing state.
              ),
              const SizedBox(height: 20), // Spacing between input fields.
              TextField(
                controller: _calciumController, // Controller for calcium input.
                decoration: const InputDecoration(
                  labelText: 'Calcium (g)', // Label for calcium input.
                  labelStyle: TextStyle(fontSize: 20), // Label font size.
                  border: OutlineInputBorder(), // Border style for the input.
                ),
                enabled:
                    _isEditing, // Enable editing based on the editing state.
                keyboardType:
                    TextInputType.number, // Numeric keyboard for input.
              ),
              const SizedBox(height: 20), // Spacing between input fields.
              TextField(
                controller:
                    _carbsController, // Controller for carbohydrates input.
                decoration: const InputDecoration(
                  labelText:
                      'Carbohydrate (g)', // Label for carbohydrate input.
                  labelStyle: TextStyle(fontSize: 20), // Label font size.
                  border: OutlineInputBorder(), // Border style for the input.
                ),
                enabled:
                    _isEditing, // Enable editing based on the editing state.
                keyboardType:
                    TextInputType.number, // Numeric keyboard for input.
              ),
              const SizedBox(height: 20), // Spacing between input fields.
              TextField(
                controller: _fatController, // Controller for fat input.
                decoration: const InputDecoration(
                  labelText: 'Fat (g)', // Label for fat input.
                  labelStyle: TextStyle(fontSize: 20), // Label font size.
                  border: OutlineInputBorder(), // Border style for the input.
                ),
                enabled:
                    _isEditing, // Enable editing based on the editing state.
                keyboardType:
                    TextInputType.number, // Numeric keyboard for input.
              ),
              const SizedBox(height: 20), // Spacing between input fields.
              TextField(
                controller: _proteinController, // Controller for protein input.
                decoration: const InputDecoration(
                  labelText: 'Protein (g)', // Label for protein input.
                  labelStyle: TextStyle(fontSize: 20), // Label font size.
                  border: OutlineInputBorder(), // Border style for the input.
                ),
                enabled:
                    _isEditing, // Enable editing based on the editing state.
                keyboardType:
                    TextInputType.number, // Numeric keyboard for input.
              ),
              const SizedBox(height: 20), // Spacing between input fields.
              TextField(
                controller:
                    _vitaminsController, // Controller for vitamins input.
                decoration: const InputDecoration(
                  labelText: 'Vitamins (g)', // Label for vitamins input.
                  labelStyle: TextStyle(fontSize: 20), // Label font size.
                  border: OutlineInputBorder(), // Border style for the input.
                ),
                enabled:
                    _isEditing, // Enable editing based on the editing state.
                keyboardType:
                    TextInputType.number, // Numeric keyboard for input.
              ),
              const SizedBox(height: 20), // Spacing between input fields.
              DropdownButtonFormField<String>(
                // Dropdown for selecting food type.
                value: _selectedFoodType, // Current selected food type.
                items: _foodTypes.map((String type) {
                  // Mapping food types to dropdown items.
                  return DropdownMenuItem<String>(
                    // Creating dropdown menu item.
                    value: type,
                    child: Text(type), // Displaying food type.
                  );
                }).toList(),
                onChanged: _isEditing // Only allow changing food type if editing.
                    ? (String? newValue) {
                        setState(() {
                          _selectedFoodType =
                              newValue; // Updating the selected food type.
                        });
                      }
                    : null, // Disable changing food type when not in editing mode.
                decoration: const InputDecoration(
                  labelText: 'Food Type', // Label for food type dropdown.
                  labelStyle: TextStyle(fontSize: 20), // Label font size.
                  border:
                      OutlineInputBorder(), // Border style for the dropdown.
                ),
              ),
              const SizedBox(height: 20), // Spacing before the date field.
              GestureDetector(
                // Detecting taps on the date field.
                onTap: () {
                  if (_isEditing)
                    _selectDate(
                        context); // Open date picker if in editing mode.
                },
                child: AbsorbPointer(
                  // Preventing user input directly into the text field.
                  child: TextField(
                    controller: TextEditingController(
                      text: DateFormat('dd/MM/yyyy').format(
                          _selectedDate), // Displaying the selected date.
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Date', // Label for date input.
                      labelStyle: TextStyle(fontSize: 20), // Label font size.
                      suffixIcon: Icon(
                          Icons.calendar_today), // Icon for date selection.
                      border:
                          OutlineInputBorder(), // Border style for the input.
                    ),
                    enabled: true, // The field is always enabled.
                  ),
                ),
              ),
              const SizedBox(height: 20), // Spacing before the time field.
              GestureDetector(
                // Detecting taps on the time field.
                onTap: () {
                  if (_isEditing)
                    _selectTime(
                        context); // Open time picker if in editing mode.
                },
                child: AbsorbPointer(
                  // Preventing user input directly into the text field.
                  child: TextField(
                    controller: TextEditingController(
                      text: _selectedTime
                          .format(context), // Displaying the selected time.
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Time', // Label for time input.
                      labelStyle: TextStyle(fontSize: 20), // Label font size.
                      suffixIcon:
                          Icon(Icons.access_time), // Icon for time selection.
                      border:
                          OutlineInputBorder(), // Border style for the input.
                    ),
                    enabled: true, // The field is always enabled.
                  ),
                ),
              ),
              const SizedBox(height: 20), // Spacing before the image display.
              if (_imageFile != null ||
                  _imageUrl !=
                      null) // Conditional to check if image is available.
                Column(
                  children: [
                    GestureDetector(
                      // Detecting tap on the image area to pick a new image.
                      onTap:
                          _pickImage, // Allow users to tap and pick a new image.
                      child: Container(
                        height: 150, // Fixed height for the image container.
                        width: double
                            .infinity, // Full width of the parent container.
                        decoration: BoxDecoration(
                          color: Colors.white, // White background color.
                          borderRadius:
                              BorderRadius.circular(10), // Rounded corners.
                          border: Border.all(
                              color: Colors
                                  .grey.shade400), // Light grey border color.
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                // Clipping the image with rounded corners.
                                borderRadius: BorderRadius.circular(
                                    10), // Applying rounded corners.
                                child: Image.file(
                                  _imageFile!, // Displaying the picked image file.
                                  fit: BoxFit
                                      .cover, // Covering the container without distortion.
                                  width: double
                                      .infinity, // Full width for the image.
                                ),
                              )
                            : (_imageUrl != null && _imageFile == null
                                ? ClipRRect(
                                    // Clipping the network image with rounded corners.
                                    borderRadius: BorderRadius.circular(
                                        10), // Applying rounded corners.
                                    child: Image.network(
                                      _imageUrl!, // Displaying the image from URL.
                                      fit: BoxFit
                                          .cover, // Covering the container without distortion.
                                      width: double
                                          .infinity, // Full width for the image.
                                    ),
                                  )
                                : const Center(
                                    child: Text(
                                      'Upload Image (optional)', // Placeholder text when no image is available.
                                      style: TextStyle(
                                        color: Colors
                                            .grey, // Light grey text color.
                                        fontSize:
                                            16, // Font size for the placeholder text.
                                      ),
                                    ),
                                  )),
                      ),
                    ),
                    if (_isEditing && (_imageFile != null || _imageUrl != null))
                      const SizedBox(
                          height:
                              10), // Space between image and button if in editing mode.
                    if (_isEditing && (_imageFile != null || _imageUrl != null))
                      ElevatedButton(
                        onPressed:
                            _confirmRemoveImage, // Button to confirm image removal.
                        child: const Text(
                          'Remove Image', // Button text for removing the image.
                          style: TextStyle(
                              color:
                                  Colors.black), // Text color for the button.
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                              0xFFE2BF65), // Background color for the button.
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 20), // Spacing before the pick image button.
              if (_isEditing) // Show pick image button only if in editing mode.
                ElevatedButton(
                  onPressed: _pickImage, // Button to trigger image picking.
                  child: const Text(
                    'Pick Image', // Button text for picking an image.
                    style: TextStyle(
                        color: Colors.black), // Text color for the button.
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFE2BF65), // Background color for the button.
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
