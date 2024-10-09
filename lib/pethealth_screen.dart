import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'addmedicalrecords_screen.dart';
import 'addvaccination_screen.dart';
import 'healthdocsdetails_screen.dart'; // Assuming this screen shows details of medical records

class PetHealthScreen extends StatefulWidget {
  final String petId;
  final String userId;

  PetHealthScreen({required this.petId, required this.userId});

  @override
  _PetHealthScreenState createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends State<PetHealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQueryMedicalRecords = ''; // For searching medical records
  String _searchQueryVaccinations = ''; // For searching vaccinations

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
          onPressed: () => Navigator.pop(context),
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
          labelStyle: TextStyle(fontSize: 14),
          isScrollable: true,
          tabs: [
            Tab(text: 'Medical Records'),
            Tab(text: 'Vaccinations & Reminders'),
            Tab(text: 'Emotional Support'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMedicalRecordsTab(),
          _buildVaccinationsTab(),
          _buildEmptyEmotionalSupportTab(),
        ],
      ),
    );
  }

  // Medical Records Tab
  Widget _buildMedicalRecordsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Medical Records', onAddPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddMedicalRecordScreen(petId: widget.petId, userId: widget.userId),
              ),
            );
          }),
          SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _searchQueryMedicalRecords = value),
            decoration: InputDecoration(
              labelText: 'Search Medical Records',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          _buildMedicalRecords(),
        ],
      ),
    );
  }

  // Fetch medical records from Firestore and render them as cards
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
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching medical records'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No medical records available'));
        }

        final records = snapshot.data!.docs;
        final filteredRecords = records.where((record) {
          final title = record['title']?.toLowerCase() ?? '';
          final doctor = record['doctor']?.toLowerCase() ?? '';
          final clinic = record['clinic']?.toLowerCase() ?? '';
          final treatment = record['treatment']?.toLowerCase() ?? '';
          return title.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              doctor.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              clinic.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              treatment.contains(_searchQueryMedicalRecords.toLowerCase());
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
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

  // Card for displaying medical record entries with long press to delete
  Widget _buildRecordCard(String title, String date, String doctor, String clinic, String treatment, String notes, DocumentSnapshot logRecord) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HealthLogDetailScreen(logRecord: logRecord),
          ),
        );
      },
      onLongPress: () {
        _showDeleteDialog(logRecord);
      },
      child: Card(
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
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Date: $date', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Doctor: $doctor', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Clinic: $clinic', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Treatment: $treatment', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Notes: $notes', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }

  // Show confirmation dialog for deletion
  Future<void> _showDeleteDialog(DocumentSnapshot logRecord) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Medical Record'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this medical record?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                await logRecord.reference.delete();
                Navigator.of(context).pop();
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
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Vaccination History', onAddPressed: () {
            // Navigate to add vaccination record screen
          }),
          SizedBox(height: 10),

          // Search Bar for Vaccination Records
          TextField(
            onChanged: (value) => setState(() => _searchQueryVaccinations = value),
            decoration: InputDecoration(
              labelText: 'Search Vaccinations',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),

          // Vaccination History List
          _buildVaccinationHistory(),
          SizedBox(height: 20),

          _buildSectionHeader('Upcoming Vaccinations', onAddPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddVaccinationScreen(petId: widget.petId, userId: widget.userId),
              ),
            );
          }),

          SizedBox(height: 10),
          _buildUpcomingVaccinations(),
          SizedBox(height: 20),

          _buildSectionHeader('Vaccination Guidelines', onAddPressed: () {
            // Navigate to vaccination guidelines page
          }),
          SizedBox(height: 10),
          _buildVaccinationGuidelines(),
        ],
      ),
    );
  }

  // Fetch vaccination history from Firestore and render them as cards
  Widget _buildVaccinationHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .orderBy('date', descending: true) // Order by date descending
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching vaccination history'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No vaccination history available'));
        }

        final records = snapshot.data!.docs;
        final DateTime now = DateTime.now(); // Get current date and time

        // Filter records to include only past vaccinations
        final pastRecords = records.where((record) {
          final vaccinationDate = DateTime.parse(record['date']);
          return vaccinationDate.isBefore(now) || vaccinationDate.isAtSameMomentAs(now); // Check if the vaccination date is before or the same as now
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: pastRecords.length,
          itemBuilder: (context, index) {
            final record = pastRecords[index];
            return _buildVaccinationCard(
              record['vaccineName'] ?? 'No Vaccine Name',
              record['date'] ?? 'No Date',
              record['clinic'] ?? 'No Clinic',
              record['notes'] ?? 'No Notes',
              record,
            );
          },
        );
      },
    );
  }



  // Card for displaying vaccination entries
  Widget _buildVaccinationCard(String vaccineName, String date, String clinic, String notes, DocumentSnapshot logRecord) {
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
            Text(vaccineName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Date: $date', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            Text('Clinic: $clinic', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            Text('Notes: $notes', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }


  // Fetch upcoming vaccinations from Firestore and render them as cards
  Widget _buildUpcomingVaccinations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .orderBy('date', descending: false) // Order by date ascending
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching upcoming vaccinations'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No upcoming vaccinations available'));
        }

        final records = snapshot.data!.docs;
        final DateTime now = DateTime.now(); // Get the current date and time

        // Filter records to include only future vaccinations
        final upcomingRecords = records.where((record) {
          final vaccinationDate = DateTime.parse(record['date']);
          return vaccinationDate.isAfter(now); // Check if the vaccination date is after now
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: upcomingRecords.length,
          itemBuilder: (context, index) {
            final record = upcomingRecords[index];
            return _buildVaccinationCard(
              record['vaccineName'] ?? 'No Vaccine Name',
              record['date'] ?? 'No Date',
              record['clinic'] ?? 'No Clinic',
              record['notes'] ?? 'No Notes',
              record,
            );
          },
        );
      },
    );
  }


  // Display vaccination guidelines
  Widget _buildVaccinationGuidelines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. Vaccination is essential for preventing diseases.\n'
              '2. Consult your veterinarian for the vaccination schedule.\n'
              '3. Ensure your pet is healthy before vaccination.\n'
              '4. Follow-up vaccinations are important.\n'
              '5. Keep records of your pet\'s vaccinations.\n',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
      ],
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
        if (title == 'Upcoming Vaccinations') // Show Add Details button only for Upcoming Vaccinations
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
}
