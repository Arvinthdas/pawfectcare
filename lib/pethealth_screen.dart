import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // For chart visualization
import 'addmedicalrecords_screen.dart';
import 'addvaccination_screen.dart';
import 'vaccinationdetails_screen.dart';
import 'healthdocsdetails_screen.dart'; // Assuming this screen shows details of medical records

class PetHealthScreen extends StatefulWidget {
  final String petId; // Pet ID to identify the specific pet
  final String userId; // User ID of the pet owner
  final String petName; // Name of the pet

  PetHealthScreen(
      {required this.petId, required this.userId, required this.petName});

  @override
  _PetHealthScreenState createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends State<PetHealthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Controller for the tab navigation
  String _searchQueryMedicalRecords = ''; // Search query for medical records
  String _searchQueryVaccinations = ''; // Search query for vaccinations

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this); // Initialize TabController
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose the tab controller when not needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE2BF65),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () =>
              Navigator.pop(context), // Navigate back when button is pressed
        ),
        title: const Text(
          'Pet Health',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize:
              const Size.fromHeight(45), // Set the preferred height for the TabBar
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF037171),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black,
            labelStyle: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold),
            isScrollable: true, // Allow horizontal scrolling
            tabs: [
              const Tab(child: Text('Medical Records')), // Tab for medical records
              const Tab(
                  child:
                      Text('Vaccinations & Reminders')), // Tab for vaccinations
              const Tab(
                  child:
                      Text('Emotional Support')), // Tab for emotional support
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMedicalRecordsTab(), // Build the medical records tab
          _buildVaccinationsTab(), // Build the vaccinations tab
          _buildEmotionalSupportTab(), // Build the emotional support tab
        ],
      ),
    );
  }

// Medical Records Tab
  Widget _buildMedicalRecordsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Medical Records', onAddPressed: () {
            // Navigate to Add Medical Record screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddMedicalRecordScreen(
                    petId: widget.petId,
                    userId: widget.userId,
                    petName: widget.petName),
              ),
            );
          }),
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() =>
                _searchQueryMedicalRecords = value), // Update search query
            decoration: const InputDecoration(
              labelText: 'Search Medical Records',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _buildMedicalRecords(), // Display past records
          const SizedBox(height: 20),
          _buildUpcomingMedicalAppointments(), // Display future appointments
        ],
      ),
    );
  }

// Display only past medical records in _buildMedicalRecords
  Widget _buildMedicalRecords() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('medicalRecords')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator()); // Loading indicator while fetching data
        }
        if (snapshot.hasError) {
          return const Center(
              child: Text('Error fetching medical records')); // Error message
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text(
                  'No medical records available')); // No records found message
        }

        final records = snapshot.data!.docs;
        final pastRecords = records.where((record) {
          final timestamp = (record['timestamp'] as Timestamp).toDate();
          return timestamp.isBefore(DateTime.now()); // Filter past records only
        }).toList();

        if (pastRecords.isEmpty) {
          return const Center(
              child: Text(
                  'No past medical records available')); // No past records message
        }

        final filteredRecords = pastRecords.where((record) {
          final title = record['title']?.toLowerCase() ?? '';
          final doctor = record['doctor']?.toLowerCase() ?? '';
          final clinic = record['clinic']?.toLowerCase() ?? '';
          final treatment = record['treatment']?.toLowerCase() ?? '';
          final date = record['date']?.toLowerCase() ?? '';

          // Check if any of the record fields contain the search query
          return title.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              doctor.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              clinic.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              treatment.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              date.contains(_searchQueryMedicalRecords.toLowerCase());
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRecords.length,
          itemBuilder: (context, index) {
            final record = filteredRecords[index];
            return _buildRecordCard(
              record['title'] ?? 'No Title',
              record['date'] ?? 'No Date',
              record['doctor'] ?? 'Unknown Doctor',
              record['clinic'] ?? 'No Clinic',
              record['treatment'] ?? 'No Treatment',
              record['notes'] ?? 'No Notes',
              record,
            );
          },
        );
      },
    );
  }

// Display only future medical appointments in _buildUpcomingMedicalAppointments
  Widget _buildUpcomingMedicalAppointments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Upcoming Medical Appointments',
          onAddPressed: () {},
          showAddButton: false,
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('pets')
              .doc(widget.petId)
              .collection('medicalRecords')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child:
                      CircularProgressIndicator()); // Loading indicator while fetching data
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text(
                      'Error fetching upcoming appointments')); // Error message
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text(
                      'No upcoming medical appointments')); // No records found message
            }

            final records = snapshot.data!.docs;
            final upcomingRecords = records.where((record) {
              final timestamp = (record['timestamp'] as Timestamp).toDate();
              return timestamp
                  .isAfter(DateTime.now()); // Filter future appointments only
            }).toList();

            if (upcomingRecords.isEmpty) {
              return const Center(
                  child: Text(
                      'No upcoming medical appointments available')); // No upcoming records message
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcomingRecords.length,
              itemBuilder: (context, index) {
                final record = upcomingRecords[index];
                return _buildRecordCard(
                  record['title'] ?? 'No Title',
                  record['date'] ?? 'No Date',
                  record['doctor'] ?? 'Unknown Doctor',
                  record['clinic'] ?? 'No Clinic',
                  record['treatment'] ?? 'No Treatment',
                  record['notes'] ?? 'No Notes',
                  record,
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Method to build a card for displaying medical records
  Widget _buildRecordCard(
      String title,
      String date,
      String doctor,
      String clinic,
      String treatment,
      String notes,
      DocumentSnapshot logRecord) {
    return InkWell(
      onTap: () {
        // Navigate to Health Log Detail screen when the card is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HealthLogDetailScreen(
                logRecord: logRecord,
                userId: widget.userId,
                petName: widget.petName),
          ),
        );
      },
      onLongPress: () {
        _showDeleteDialog(
            logRecord); // Show dialog to delete the record on long press
      },
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(10), // Rounded corners for the card
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(12.0), // Padding for content inside the card
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)), // Title of the record
              Text('Date: $date',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700])), // Date of the record
              Text('Doctor: $doctor',
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey[700])), // Doctor's name
              Text('Clinic: $clinic',
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey[700])), // Clinic name
              Text('Treatment: $treatment',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700])), // Treatment details
              Text('Notes: $notes',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700])), // Additional notes
            ],
          ),
        ),
      ),
    );
  }

  // Method to show dialog for deleting medical record
  Future<void> _showDeleteDialog(DocumentSnapshot logRecord) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Medical Record'), // Dialog title
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Are you sure you want to delete this medical record?'), // Confirmation message
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'), // Cancel button
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Delete'), // Delete button
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red, // Red background for delete button
              ),
              onPressed: () async {
                await logRecord.reference
                    .delete(); // Delete the record from Firestore
                Navigator.of(context).pop(); // Close the dialog
                _showMessage(
                    'Medical record deleted successfully.'); // Show success message
              },
            ),
          ],
        );
      },
    );
  }

  // Vaccinations & Reminders Tab
  Widget _buildVaccinationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Vaccination History', onAddPressed: () {
            // Navigate to Add Vaccination screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddVaccinationScreen(
                    petId: widget.petId,
                    userId: widget.userId,
                    petName: widget.petName),
              ),
            );
          }, showAddButton: false), // Set showAddButton to false
          const SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(
                () => _searchQueryVaccinations = value), // Update search query
            decoration: const InputDecoration(
              labelText: 'Search Vaccinations',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _buildVaccinationHistory(), // Display vaccination history
          const SizedBox(height: 20),
          _buildSectionHeader('Upcoming Vaccinations', onAddPressed: () {
            // Navigate to Add Vaccination screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddVaccinationScreen(
                    petId: widget.petId,
                    userId: widget.userId,
                    petName: widget.petName),
              ),
            );
          }),
          const SizedBox(height: 10),
          _buildUpcomingVaccinations(), // Display upcoming vaccinations
          const SizedBox(height: 20),
          _buildVaccinationGuidelines(), // Display vaccination guidelines
        ],
      ),
    );
  }

  // Method to display vaccination history
  Widget _buildVaccinationHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .orderBy('date', descending: true) // Order by date
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator()); // Loading indicator while fetching data
        }
        if (snapshot.hasError) {
          return const Center(
              child:
                  Text('Error fetching vaccination history')); // Error message
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text(
                  'No vaccination history available')); // No records found message
        }

        final records = snapshot.data!.docs;
        final pastRecords = records.where((record) {
          final dateString = record['date']; // Get date string
          final dateFormat =
              DateFormat('dd/MM/yyyy HH:mm'); // Define date format
          try {
            final vaccinationDate =
                dateFormat.parse(dateString); // Parse the date
            return vaccinationDate
                .isBefore(DateTime.now()); // Check if the date is in the past
          } catch (e) {
            return false; // If parsing fails, return false
          }
        }).toList();

        // Filter based on search query
        final filteredRecords = pastRecords.where((record) {
          final vaccineName = record['vaccineName']?.toLowerCase() ?? '';
          final clinic = record['clinic']?.toLowerCase() ?? '';
          final notes = record['notes']?.toLowerCase() ?? '';
          final date = record['date']?.toLowerCase() ?? '';

          return vaccineName.contains(_searchQueryVaccinations.toLowerCase()) ||
              clinic.contains(_searchQueryVaccinations.toLowerCase()) ||
              notes.contains(_searchQueryVaccinations.toLowerCase()) ||
              date.contains(_searchQueryVaccinations.toLowerCase());
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredRecords.length,
          itemBuilder: (context, index) {
            final record = filteredRecords[index];
            return _buildVaccinationCard(
              record['vaccineName'] ??
                  'No Vaccine Name', // Display vaccine name
              record['date'] ?? 'No Date', // Display date
              record['clinic'] ?? 'No Clinic', // Display clinic
              record['notes'] ?? 'No Notes', // Display notes
              record,
            );
          },
        );
      },
    );
  }

  // Method to build a card for displaying vaccination records
  Widget _buildVaccinationCard(String vaccineName, String date, String clinic,
      String notes, DocumentSnapshot logRecord) {
    return InkWell(
      onTap: () {
        // Navigate to Vaccination Detail screen when the card is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VaccinationDetailScreen(
              vaccinationRecord: logRecord,
              petId: widget.petId,
              userId: widget.userId,
              petName: widget.petName,
            ),
          ),
        );
      },
      onLongPress: () {
        _showVaccinationDeleteDialog(
            logRecord); // Show dialog to delete the vaccination record on long press
      },
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(10), // Rounded corners for the card
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(12.0), // Padding for content inside the card
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vaccineName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)), // Vaccine name
              Text('Date: $date',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700])), // Date of vaccination
              Text('Clinic: $clinic',
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey[700])), // Clinic name
              Text('Notes: $notes',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700])), // Additional notes
            ],
          ),
        ),
      ),
    );
  }

  // Method to show dialog for deleting vaccination record
  Future<void> _showVaccinationDeleteDialog(DocumentSnapshot logRecord) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Vaccination Record'), // Dialog title
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Are you sure you want to delete this vaccination record?'), // Confirmation message
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'), // Cancel button
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Delete'), // Delete button
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red, // Red background for delete button
              ),
              onPressed: () async {
                await logRecord.reference
                    .delete(); // Delete the vaccination record
                Navigator.of(context).pop(); // Close the dialog
                _showMessage(
                    'Vaccination record deleted successfully.'); // Show success message
              },
            ),
          ],
        );
      },
    );
  }

  // Method to display upcoming vaccinations
  Widget _buildUpcomingVaccinations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .orderBy('date', descending: false) // Order by date
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator()); // Loading indicator while fetching data
        }
        if (snapshot.hasError) {
          return const Center(
              child: Text(
                  'Error fetching upcoming vaccinations')); // Error message
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text(
                  'No upcoming vaccinations available')); // No records found message
        }

        final records = snapshot.data!.docs;
        final upcomingRecords = records.where((record) {
          final dateString = record['date']; // Get date string
          try {
            final vaccinationDate = DateFormat('dd/MM/yyyy HH:mm')
                .parse(dateString); // Parse the date
            return vaccinationDate
                .isAfter(DateTime.now()); // Check if the date is in the future
          } catch (e) {
            return false; // If parsing fails, return false
          }
        }).toList();

        if (upcomingRecords.isEmpty) {
          return const Center(
              child: Text(
                  'No upcoming vaccinations available')); // No upcoming records message
        }

        // Filter based on search query for upcoming vaccinations
        final filteredUpcomingRecords = upcomingRecords.where((record) {
          final vaccineName = record['vaccineName']?.toLowerCase() ?? '';
          final clinic = record['clinic']?.toLowerCase() ?? '';
          final notes = record['notes']?.toLowerCase() ?? '';
          final date = record['date']?.toLowerCase() ?? '';

          return vaccineName.contains(_searchQueryVaccinations.toLowerCase()) ||
              clinic.contains(_searchQueryVaccinations.toLowerCase()) ||
              notes.contains(_searchQueryVaccinations.toLowerCase()) ||
              date.contains(_searchQueryVaccinations.toLowerCase());
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredUpcomingRecords.length,
          itemBuilder: (context, index) {
            final record = filteredUpcomingRecords[index];
            return _buildVaccinationCard(
              record['vaccineName'] ??
                  'No Vaccine Name', // Display vaccine name
              record['date'] ?? 'No Date', // Display date
              record['clinic'] ?? 'No Clinic', // Display clinic
              record['notes'] ?? 'No Notes', // Display notes
              record,
            );
          },
        );
      },
    );
  }

  // Method to display vaccination guidelines
  Widget _buildVaccinationGuidelines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vaccination Tips',
          style: TextStyle(
            fontSize: 20, // Set font size for the title
            fontWeight: FontWeight.bold, // Make the title bold
            color: Colors.black,
            fontFamily: 'Poppins', // Add custom font if needed
          ),
        ),
        const SizedBox(
            height: 10), // Add some spacing between the title and the content
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 14, // Slightly smaller font size for the tips
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            children: [
              TextSpan(
                text: '1. Be an Example\n',
                style: TextStyle(
                    fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                    'Your pet is more likely to be calm if you are. If you’re stressed out before the vaccination appointment, your pet will feel your anxiety. High-pitched praise and rushed demeanor can quickly transfer stress to your pet, so try to keep a soft, calm voice and give yourself plenty of time to get to the office.\n\n',
              ),
              TextSpan(
                text: '2. Transport With Care\n',
                style: TextStyle(
                    fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                    'Condition your pet to car trips with short drives around the neighborhood. Provide positive reinforcement by rewarding good behavior with treats. Your pet’s carrier should be sitting flat, preferably on the seat behind the passenger seat and covered with a towel to reduce stimuli. A non-slip surface in the carrier is crucial. Be sure large dogs are safely harnessed in the car as well. Stick to quiet, calming music, which some pets find soothing.\n\n',
              ),
              TextSpan(
                text: '3. Take Advantage of Treats\n',
                style: TextStyle(
                    fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                    'Using treats to calm your furry friend may be more effective if he or she isn’t visiting on a full stomach, so if medically appropriate give a very light meal the day of the visit and don’t feed much several hours before the appointment. Fear Free Certified® veterinarians may use treats like peanut butter to soothe your dog during examinations or vaccine administrations.\n\n',
              ),
              TextSpan(
                text: '4. Utilize Synthetic Pheromones\n',
                style: TextStyle(
                    fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                    'Calming pheromones can be applied to the towel or liner of your pet’s carrier with a simple spray. Synthetic versions of natural chemicals may help soothe stressed pets; separate varieties are available for cats and dogs. Fear Free Certified veterinarians often continue the use of pheromones in their office and on their clothing.\n\n',
              ),
              TextSpan(
                text: '5. Partner With Your Veterinarian\n',
                style: TextStyle(
                    fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                    'Communicating all questions and concerns to your veterinarian is the best way to ensure your pet receives quality care and has a comfortable experience every time.\n',
              ),
            ],
          ),
        ),
      ],
    );
  }

// Emotional Support Tab with Mood Tracker and Date Filter
  Widget _buildEmotionalSupportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          _buildSectionHeader(
            'Mood Tracker',
            onAddPressed: () {
              _showMoodTrackerDialog(); // Show dialog to log mood
            },
            showFilterButton: true, // Show filter button in Mood Tracker
          ),
          const SizedBox(height: 16), // Space between the header and the mood history
          _buildMoodHistory(), // Display mood history
          const SizedBox(height: 20), // Space between mood history and mood trends
          _buildSectionHeader(
            'Mood Trends',
            showAddButton: false, // Hide "+ Add" button for Mood Trends
          ), // No filter button here
          const SizedBox(height: 16), // Space between the header and the chart
          _buildMoodTrends(), // Display mood trends
        ],
      ),
    );
  }

  // Method to show dialog for logging mood
  void _showMoodTrackerDialog() {
    final _moodController =
        TextEditingController(); // Controller for mood text input
    String selectedMood = 'Happy'; // Default mood selected

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF7EFF1), // Background color for the dialog
          title: const Text('Log Mood'), // Dialog title
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  // Dropdown for selecting mood
                  value: selectedMood,
                  items: ['Happy', 'Calm', 'Anxious', 'Stressed', 'Playful']
                      .map((mood) => DropdownMenuItem(
                            value: mood,
                            child: Text(mood),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMood = value!; // Update selected mood
                    });
                  },
                  decoration:
                      const InputDecoration(labelText: 'Mood'), // Label for dropdown
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _moodController, // Controller for notes input
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)', // Label for notes input
                    border: OutlineInputBorder(), // Border style
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'), // Cancel button
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Save'), // Save button
              onPressed: () {
                _addMoodLog(
                    selectedMood, _moodController.text); // Save mood log
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Method to add mood log to Firestore
  Future<void> _addMoodLog(String mood, String notes) async {
    final now = DateTime.now();
    final moodLog = {
      'mood': mood, // Mood value
      'notes': notes, // Notes for the mood
      'date':
          DateFormat('dd/MM/yyyy HH:mm').format(now), // Current date formatted
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('pets')
        .doc(widget.petId)
        .collection('moodTracker')
        .add(moodLog); // Add mood log to Firestore

    // Refresh the UI immediately after adding the mood log
    setState(() {
      _showMessage('Mood log added successfully.'); // Show success message
    });
  }

// Mood History showing today's data by default with date filter
  Widget _buildMoodHistory() {
    final filterDate =
        selectedDate ?? DateTime.now(); // Use selected date or today's date
    final formattedDate =
        DateFormat('dd/MM/yyyy').format(filterDate); // Format the date

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('moodTracker')
          .orderBy('date', descending: true) // Order by date
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator()); // Loading indicator while fetching data
        }
        if (snapshot.hasError) {
          return const Center(
              child: Text('Error fetching mood history')); // Error message
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text(
                  'No mood history available')); // No records found message
        }

        // Filter mood logs to show only entries for selected date
        final moodLogs = snapshot.data!.docs.where((doc) {
          final dateString = doc['date']; // Get date string
          final logDate = dateString.split(' ')[0]; // Extract date part only
          return logDate == formattedDate; // Compare dates
        }).toList();

        if (moodLogs.isEmpty) {
          return const Center(
              child: Text(
                  'No mood history available for selected date')); // No logs found message
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: moodLogs.length,
          itemBuilder: (context, index) {
            final moodLog = moodLogs[index];
            return _buildMoodCard(
              moodLog['mood'] ?? 'Unknown', // Mood value
              moodLog['date'] ?? 'No Date', // Date value
              moodLog['notes'] ?? 'No Notes', // Notes value
              moodLog, // Pass the entire log for detail view
            );
          },
        );
      },
    );
  }

  // Method to build a card for displaying mood logs
  Widget _buildMoodCard(
      String mood, String date, String notes, DocumentSnapshot moodLog) {
    return GestureDetector(
      onLongPress: () {
        _showDeleteMoodDialog(
            moodLog); // Show dialog to delete the mood log on long press
      },
      child: Card(
        color: _getMoodBackgroundColor(
            mood), // Different background colors for each mood
        elevation: 5, // Increased elevation for better shadow effect
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // More rounded corners
        ),
        child: Padding(
          padding: const EdgeInsets.all(
              16.0), // Increased padding for better spacing
          child: Row(
            children: [
              _getMoodIcon(mood), // Icon representing the mood
              const SizedBox(width: 16), // Space between the icon and the text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mood,
                      style: const TextStyle(
                        fontSize: 20, // Larger font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // White text for better contrast
                      ),
                    ),
                    Text(
                      'Date: $date',
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors
                              .white70), // White70 for a softer appearance
                    ),
                    if (notes.isNotEmpty)
                      Text(
                        'Notes: $notes',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white70), // Notes text
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to show dialog for deleting mood log
  Future<void> _showDeleteMoodDialog(DocumentSnapshot moodLog) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Mood Log'), // Dialog title
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Are you sure you want to delete this mood log?'), // Confirmation message
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'), // Cancel button
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Delete'), // Delete button
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red, // Red background for delete button
              ),
              onPressed: () async {
                await moodLog.reference.delete(); // Delete the mood log
                Navigator.of(context).pop(); // Close the dialog
                _showMessage(
                    'Mood log deleted successfully.'); // Show success message
                setState(() {}); // Refresh the page after deletion
              },
            ),
          ],
        );
      },
    );
  }

  // Method to get an icon representing the mood
  Widget _getMoodIcon(String mood) {
    IconData iconData;
    switch (mood) {
      case 'Happy':
        iconData = Icons.sentiment_satisfied_alt; // Icon for happy mood
        break;
      case 'Calm':
        iconData = Icons.self_improvement; // Icon for calm mood
        break;
      case 'Anxious':
        iconData = Icons.sentiment_dissatisfied; // Icon for anxious mood
        break;
      case 'Stressed':
        iconData = Icons.sentiment_very_dissatisfied; // Icon for stressed mood
        break;
      case 'Playful':
        iconData = Icons.pets; // Icon for playful mood
        break;
      default:
        iconData = Icons.sentiment_neutral; // Neutral icon for unknown mood
        break;
    }
    return Icon(iconData,
        size: 40, color: Colors.white); // Larger icon size with white color
  }

  // Method to get the background color based on the mood
  Color _getMoodBackgroundColor(String mood) {
    switch (mood) {
      case 'Happy':
        return Colors.green; // Green background for happy mood
      case 'Calm':
        return Colors.blue; // Blue background for calm mood
      case 'Anxious':
        return Colors.orange; // Orange background for anxious mood
      case 'Stressed':
        return Colors.red; // Red background for stressed mood
      case 'Playful':
        return Colors.purple; // Purple background for playful mood
      default:
        return Colors.grey; // Grey background for unknown mood
    }
  }

  // Mood Trends Pie Chart showing today's data by default with date filter
  Widget _buildMoodTrends() {
    final filterDate =
        selectedDate ?? DateTime.now(); // Use selected date or today's date
    final formattedDate =
        DateFormat('dd/MM/yyyy').format(filterDate); // Format the date

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('moodTracker')
          .get(), // Get all mood logs from Firestore
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
                  CircularProgressIndicator()); // Loading indicator while fetching data
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text(
                  'No mood data available for selected date')); // Error or no data message
        }

        // Filter mood logs to show only entries for selected date
        final moodData = snapshot.data!.docs.where((doc) {
          final dateString = doc['date']; // Get date string
          final logDate = dateString.split(' ')[0]; // Extract date part only
          return logDate == formattedDate; // Compare dates
        }).toList();

        if (moodData.isEmpty) {
          return const Center(
              child: Text(
                  'No mood trends available for selected date')); // No trends found message
        }

        Map<String, int> moodCount = {}; // To count occurrences of each mood
        for (var log in moodData) {
          final mood = log['mood'] ?? 'Unknown'; // Get mood from log
          moodCount[mood] =
              (moodCount[mood] ?? 0) + 1; // Increment count for the mood
        }

        // Create pie chart sections based on mood counts
        final chartData = moodCount.entries.map((entry) {
          return PieChartSectionData(
            value: entry.value.toDouble(), // Value for the pie chart section
            title: '${entry.key} (${entry.value})', // Title for the section
            color: _getMoodColor(entry.key), // Color based on mood
            radius: 70, // Radius of the pie chart section
            titleStyle: const TextStyle(
              fontSize: 15, // Font size for the title
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          );
        }).toList();

        return SizedBox(
          height: 250, // Height of the pie chart
          child: PieChart(
            PieChartData(
              sections: chartData, // Sections of the pie chart
              centerSpaceRadius: 40, // Space in the center of the pie chart
              sectionsSpace: 2, // Space between sections
              borderData: FlBorderData(show: false), // Hide borders
            ),
          ),
        );
      },
    );
  }

  // Method to get the color for the mood
  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Happy':
        return Colors.green; // Green for happy mood
      case 'Calm':
        return Colors.blue; // Blue for calm mood
      case 'Anxious':
        return Colors.orange; // Orange for anxious mood
      case 'Stressed':
        return Colors.red; // Red for stressed mood
      case 'Playful':
        return Colors.purple; // Purple for playful mood
      default:
        return Colors.grey; // Grey for unknown mood
    }
  }

  // Section Header with optional Date Filter Button
  DateTime? selectedDate; // Variable to store the selected date

  Widget _buildSectionHeader(String title,
      {bool showAddButton = true,
      bool showFilterButton = false,
      VoidCallback? onAddPressed}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            if (showAddButton)
              TextButton.icon(
                icon: const Icon(Icons.add,
                    color: Colors.black), // Icon for adding records
                label: const Text('Add',
                    style: TextStyle(
                        color: Colors.black)), // Label for adding records
                onPressed: onAddPressed,
              ),
            if (showFilterButton) // Only show the filter button if specified
              IconButton(
                icon: const Icon(Icons.filter_list,
                    color: Colors.black), // Filter icon for date selection
                onPressed: () async {
                  // Show date picker for selecting a date
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ??
                        DateTime.now(), // Default to today's date
                    firstDate: DateTime(2000), // Minimum selectable date
                    lastDate: DateTime.now(), // Maximum selectable date
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate; // Update selected date
                    });
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  // Method to show messages at the bottom of the screen
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)), // Show message in a Snackbar
    );
  }
}
