import 'package:flutter/material.dart';
import 'petprofile_screen.dart'; // Import your PetProfileScreen
import 'nutrition_screen.dart'; // Import your NutritionPage
import 'exercise_screen.dart'; // Import your ExerciseMonitoringPage
import 'grooming_screen.dart'; // Import your GroomingPage

class PetHealthScreen extends StatefulWidget {
  @override
  _PetHealthScreenState createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends State<PetHealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        backgroundColor: Color(0xFFE2BF65),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Navigates back to the previous screen
        ),
        title: Text(
          'Pet Health',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontSize: 14), // Adjust font size
          isScrollable: true, // This allows the tabs to be scrollable
          tabs: [
            Tab(text: 'Health Log'), // First tab
            Tab(text: 'Vaccinations & Reminders'), // Second tab
            Tab(text: 'Emotional Support'), // Third tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHealthLogTab(),      // Health Log tab content
          _buildEmptyVaccinationsTab(),    // Vaccinations & Reminders tab content
          _buildEmptyEmotionalSupportTab() // Emotional Support tab content
        ],
      ),
    );
  }

  // Health Log Tab
  Widget _buildHealthLogTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health Checkup Logs
          _buildSectionHeader('Health Checkup Logs', onAddPressed: () {
            // Handle Add Details action
          }),
          SizedBox(height: 10),
          _buildHealthCheckupLogs(),

          SizedBox(height: 20),

          // Medical History
          _buildSectionHeader('Medical History', onAddPressed: () {
            // Handle Add Details action
          }),
          SizedBox(height: 10),
          _buildMedicalHistory(),
        ],
      ),
    );
  }

  // Health Checkup Logs Content
  Widget _buildHealthCheckupLogs() {
    return Column(
      children: [
        _buildLogCard('Annual Checkup', 'Mon 24 Jan', 'Dr. Green', 'All good, no concerns.'),
        _buildLogCard('Dental Checkup', 'Tue 12 Feb', 'Dr. Raam', 'Clean teeth, no issues.'),
        // Add more checkup logs here
      ],
    );
  }

  // Medical History Content
  Widget _buildMedicalHistory() {
    return Column(
      children: [
        _buildLogCard('Skin Infection', 'Wed 13 Mar', 'Dr. Jerry', 'Antibiotics and cream.'),
        _buildLogCard('Ear Infection', 'Mon 24 Apr', 'Dr. Smith', 'Treatment ongoing.'),
        // Add more medical history entries here
      ],
    );
  }

  // Vaccinations & Reminders Tab
  Widget _buildEmptyVaccinationsTab() {
    return Center(
      child: Text(
        'Vaccinations & Reminders will be loaded from the database',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  // Emotional Support Tab
  Widget _buildEmptyEmotionalSupportTab() {
    return Center(
      child: Text(
        'Emotional Support content will be loaded from the database',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  // Section Header with "Add Details" button
  Widget _buildSectionHeader(String title, {required VoidCallback onAddPressed}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        TextButton(
          onPressed: onAddPressed,
          child: Row(
            children: [
              Icon(Icons.add, color: Colors.black),
              Text('Add Details', style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
      ],
    );
  }

  // Card for displaying log entries
  Widget _buildLogCard(String title, String date, String doctor, String notes) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Date: $date',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 5),
            Text(
              'Doctor: $doctor',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 5),
            Text(
              'Notes: $notes',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
