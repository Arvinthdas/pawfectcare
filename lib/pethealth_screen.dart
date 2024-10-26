import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // For chart visualization
import 'addmedicalrecords_screen.dart';
import 'addvaccination_screen.dart';
import 'vaccinationdetails_screen.dart';
import 'healthdocsdetails_screen.dart'; // Assuming this screen shows details of medical records

class PetHealthScreen extends StatefulWidget {
  final String petId;
  final String userId;
  final String petName;

  PetHealthScreen({required this.petId, required this.userId, required this.petName});

  @override
  _PetHealthScreenState createState() => _PetHealthScreenState();
}

class _PetHealthScreenState extends State<PetHealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQueryMedicalRecords = '';
  String _searchQueryVaccinations = '';

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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pet Health',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(45), // Set the preferred height for the TabBar
          child: TabBar(
            controller: _tabController,
            indicatorColor: Color(0xFF037171),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black,
            labelStyle: TextStyle(fontSize: 15,fontStyle: FontStyle.italic ,fontWeight: FontWeight.bold),
            isScrollable: true, // Allow horizontal scrolling
            tabs: [
              Tab(child: Text('Medical Records')),
              Tab(child: Text('Vaccinations & Reminders')),
              Tab(child: Text('Emotional Support')),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMedicalRecordsTab(),
          _buildVaccinationsTab(),
          _buildEmotionalSupportTab(),
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
                builder: (context) => AddMedicalRecordScreen(petId: widget.petId, userId: widget.userId, petName: widget.petName),
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
          _buildMedicalRecords(),  // Display past records
          SizedBox(height: 20),
          _buildUpcomingMedicalAppointments(),  // Display future appointments
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
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching medical records'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No medical records available'));
        }

        final records = snapshot.data!.docs;
        final pastRecords = records.where((record) {
          final timestamp = (record['timestamp'] as Timestamp).toDate();
          return timestamp.isBefore(DateTime.now()); // Filter past records only
        }).toList();

        if (pastRecords.isEmpty) {
          return Center(child: Text('No past medical records available'));
        }

        final filteredRecords = pastRecords.where((record) {
          final title = record['title']?.toLowerCase() ?? '';
          final doctor = record['doctor']?.toLowerCase() ?? '';
          final clinic = record['clinic']?.toLowerCase() ?? '';
          final treatment = record['treatment']?.toLowerCase() ?? '';
          final date = record['date']?.toLowerCase() ?? '';

          return title.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              doctor.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              clinic.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              treatment.contains(_searchQueryMedicalRecords.toLowerCase()) ||
              date.contains(_searchQueryMedicalRecords.toLowerCase());
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
        SizedBox(height: 20),
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
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error fetching upcoming appointments'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('No upcoming medical appointments'));
            }

            final records = snapshot.data!.docs;
            final upcomingRecords = records.where((record) {
              final timestamp = (record['timestamp'] as Timestamp).toDate();
              return timestamp.isAfter(DateTime.now()); // Filter future appointments only
            }).toList();

            if (upcomingRecords.isEmpty) {
              return Center(child: Text('No upcoming medical appointments available'));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
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


  Widget _buildRecordCard(String title, String date, String doctor, String clinic, String treatment, String notes, DocumentSnapshot logRecord) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HealthLogDetailScreen(logRecord: logRecord, userId: widget.userId, petName: widget.petName),
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
                _showMessage('Medical record deleted successfully.');
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddVaccinationScreen(petId: widget.petId, userId: widget.userId, petName: widget.petName),
              ),
            );
          }, showAddButton: false), // Set showAddButton to false
          SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _searchQueryVaccinations = value),
            decoration: InputDecoration(
              labelText: 'Search Vaccinations',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          _buildVaccinationHistory(),
          SizedBox(height: 20),
          _buildSectionHeader('Upcoming Vaccinations', onAddPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddVaccinationScreen(petId: widget.petId, userId: widget.userId, petName: widget.petName),
              ),
            );
          }),
          SizedBox(height: 10),
          _buildUpcomingVaccinations(),
          SizedBox(height: 20),
          _buildVaccinationGuidelines(),
        ],
      ),
    );
  }


  Widget _buildVaccinationHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .orderBy('date', descending: true)
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
        final pastRecords = records.where((record) {
          final dateString = record['date'];
          final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
          try {
            final vaccinationDate = dateFormat.parse(dateString);
            return vaccinationDate.isBefore(DateTime.now());
          } catch (e) {
            return false;
          }
        }).toList();

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
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredRecords.length,
          itemBuilder: (context, index) {
            final record = filteredRecords[index];
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

  Widget _buildVaccinationCard(String vaccineName, String date, String clinic, String notes, DocumentSnapshot logRecord) {
    return InkWell(
      onTap: () {
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
        _showVaccinationDeleteDialog(logRecord);
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
              Text(vaccineName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Date: $date', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Clinic: $clinic', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Notes: $notes', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVaccinationDeleteDialog(DocumentSnapshot logRecord) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Vaccination Record'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this vaccination record?'),
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
                _showMessage('Vaccination record deleted successfully.');
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingVaccinations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('vaccinations')
          .orderBy('date', descending: false)
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
        final upcomingRecords = records.where((record) {
          final dateString = record['date'];
          try {
            final vaccinationDate = DateFormat('dd/MM/yyyy HH:mm').parse(dateString);
            return vaccinationDate.isAfter(DateTime.now());
          } catch (e) {
            return false;
          }
        }).toList();

        if (upcomingRecords.isEmpty) {
          return Center(child: Text('No upcoming vaccinations available'));
        }

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
          physics: NeverScrollableScrollPhysics(),
          itemCount: filteredUpcomingRecords.length,
          itemBuilder: (context, index) {
            final record = filteredUpcomingRecords[index];
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
        const SizedBox(height: 10), // Add some spacing between the title and the content
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14, // Slightly smaller font size for the tips
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            children: [
              TextSpan(
                text: '1. Be an Example\n',
                style: TextStyle(fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                'Your pet is more likely to be calm if you are. If you’re stressed out before the vaccination appointment, your pet will feel your anxiety. High-pitched praise and rushed demeanor can quickly transfer stress to your pet, so try to keep a soft, calm voice and give yourself plenty of time to get to the office.\n\n',
              ),
              TextSpan(
                text: '2. Transport With Care\n',
                style: TextStyle(fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                'Condition your pet to car trips with short drives around the neighborhood. Provide positive reinforcement by rewarding good behavior with treats. Your pet’s carrier should be sitting flat, preferably on the seat behind the passenger seat and covered with a towel to reduce stimuli. A non-slip surface in the carrier is crucial. Be sure large dogs are safely harnessed in the car as well. Stick to quiet, calming music, which some pets find soothing.\n\n',
              ),
              TextSpan(
                text: '3. Take Advantage of Treats\n',
                style: TextStyle(fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                'Using treats to calm your furry friend may be more effective if he or she isn’t visiting on a full stomach, so if medically appropriate give a very light meal the day of the visit and don’t feed much several hours before the appointment. Fear Free Certified® veterinarians may use treats like peanut butter to soothe your dog during examinations or vaccine administrations.\n\n',
              ),
              TextSpan(
                text: '4. Utilize Synthetic Pheromones\n',
                style: TextStyle(fontWeight: FontWeight.bold), // Bold for mini title
              ),
              TextSpan(
                text:
                'Calming pheromones can be applied to the towel or liner of your pet’s carrier with a simple spray. Synthetic versions of natural chemicals may help soothe stressed pets; separate varieties are available for cats and dogs. Fear Free Certified veterinarians often continue the use of pheromones in their office and on their clothing.\n\n',
              ),
              TextSpan(
                text: '5. Partner With Your Veterinarian\n',
                style: TextStyle(fontWeight: FontWeight.bold), // Bold for mini title
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
              _showMoodTrackerDialog();
            },
            showFilterButton: true, // Show filter button in Mood Tracker
          ),
          SizedBox(height: 16), // Space between the header and the mood history
          _buildMoodHistory(),
          SizedBox(height: 20), // Space between mood history and mood trends
          _buildSectionHeader(
            'Mood Trends',
            showAddButton: false, // Hide "+ Add" button for Mood Trends
          ), // No filter button here
          SizedBox(height: 16), // Space between the header and the chart
          _buildMoodTrends(),
        ],
      ),
    );
  }


  void _showMoodTrackerDialog() {
    final _moodController = TextEditingController();
    String selectedMood = 'Happy';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFFF7EFF1),
          title: Text('Log Mood'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMood,
                  items: ['Happy', 'Calm', 'Anxious', 'Stressed', 'Playful']
                      .map((mood) => DropdownMenuItem(
                    value: mood,
                    child: Text(mood),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMood = value!;
                    });
                  },
                  decoration: InputDecoration(labelText: 'Mood'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _moodController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                _addMoodLog(selectedMood, _moodController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addMoodLog(String mood, String notes) async {
    final now = DateTime.now();
    final moodLog = {
      'mood': mood,
      'notes': notes,
      'date': DateFormat('dd/MM/yyyy HH:mm').format(now),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('pets')
        .doc(widget.petId)
        .collection('moodTracker')
        .add(moodLog);

    // Refresh the UI immediately after adding the mood log
    setState(() {
      _showMessage('Mood log added successfully.');
    });
  }


// Mood History showing today's data by default with date filter
  Widget _buildMoodHistory() {
    final filterDate = selectedDate ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(filterDate);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('moodTracker')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching mood history'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No mood history available'));
        }

        // Filter mood logs to show only entries for selected date
        final moodLogs = snapshot.data!.docs.where((doc) {
          final dateString = doc['date'];
          final logDate = dateString.split(' ')[0]; // Extract date part only
          return logDate == formattedDate;
        }).toList();

        if (moodLogs.isEmpty) {
          return Center(child: Text('No mood history available for selected date'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: moodLogs.length,
          itemBuilder: (context, index) {
            final moodLog = moodLogs[index];
            return _buildMoodCard(
              moodLog['mood'] ?? 'Unknown',
              moodLog['date'] ?? 'No Date',
              moodLog['notes'] ?? 'No Notes',
              moodLog,
            );
          },
        );
      },
    );
  }


  Widget _buildMoodCard(String mood, String date, String notes, DocumentSnapshot moodLog) {
    return GestureDetector(
      onLongPress: () {
        _showDeleteMoodDialog(moodLog);
      },
      child: Card(
        color: _getMoodBackgroundColor(mood), // Different background colors for each mood
        elevation: 5, // Increased elevation for better shadow effect
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // More rounded corners
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Increased padding for better spacing
          child: Row(
            children: [
              _getMoodIcon(mood), // Icon representing the mood
              SizedBox(width: 16), // Space between the icon and the text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mood,
                      style: TextStyle(
                        fontSize: 20, // Larger font size
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // White text for better contrast
                      ),
                    ),
                    Text(
                      'Date: $date',
                      style: TextStyle(fontSize: 16, color: Colors.white70), // White70 for a softer appearance
                    ),
                    if (notes.isNotEmpty)
                      Text(
                        'Notes: $notes',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
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

  Future<void> _showDeleteMoodDialog(DocumentSnapshot moodLog) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Mood Log'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this mood log?'),
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
                await moodLog.reference.delete();
                Navigator.of(context).pop();
                _showMessage('Mood log deleted successfully.');
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
        iconData = Icons.sentiment_satisfied_alt;
        break;
      case 'Calm':
        iconData = Icons.self_improvement;
        break;
      case 'Anxious':
        iconData = Icons.sentiment_dissatisfied;
        break;
      case 'Stressed':
        iconData = Icons.sentiment_very_dissatisfied;
        break;
      case 'Playful':
        iconData = Icons.pets;
        break;
      default:
        iconData = Icons.sentiment_neutral;
        break;
    }
    return Icon(iconData, size: 40, color: Colors.white); // Larger icon size with white color
  }

  // Method to get the background color based on the mood
  Color _getMoodBackgroundColor(String mood) {
    switch (mood) {
      case 'Happy':
        return Colors.green;
      case 'Calm':
        return Colors.blue;
      case 'Anxious':
        return Colors.orange;
      case 'Stressed':
        return Colors.red;
      case 'Playful':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

// Mood Trends Pie Chart showing today's data by default with date filter
  Widget _buildMoodTrends() {
    final filterDate = selectedDate ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(filterDate);

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('moodTracker')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No mood data available for selected date'));
        }

        // Filter mood logs to show only entries for selected date
        final moodData = snapshot.data!.docs.where((doc) {
          final dateString = doc['date'];
          final logDate = dateString.split(' ')[0]; // Extract date part only
          return logDate == formattedDate;
        }).toList();

        if (moodData.isEmpty) {
          return Center(child: Text('No mood trends available for selected date'));
        }

        Map<String, int> moodCount = {};
        for (var log in moodData) {
          final mood = log['mood'] ?? 'Unknown';
          moodCount[mood] = (moodCount[mood] ?? 0) + 1;
        }

        // Create pie chart sections based on mood counts
        final chartData = moodCount.entries.map((entry) {
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '${entry.key} (${entry.value})',
            color: _getMoodColor(entry.key),
            radius: 70,
            titleStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          );
        }).toList();

        return SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sections: chartData,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
            ),
          ),
        );
      },
    );
  }


  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Happy':
        return Colors.green;
      case 'Calm':
        return Colors.blue;
      case 'Anxious':
        return Colors.orange;
      case 'Stressed':
        return Colors.red;
      case 'Playful':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

// Section Header with optional Date Filter Button
  DateTime? selectedDate; // Variable to store the selected date

  Widget _buildSectionHeader(String title, {bool showAddButton = true, bool showFilterButton = false, VoidCallback? onAddPressed}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            if (showAddButton)
              TextButton.icon(
                icon: Icon(Icons.add, color: Colors.black),
                label: Text('Add', style: TextStyle(color: Colors.black)),
                onPressed: onAddPressed,
              ),
            if (showFilterButton) // Only show the filter button if specified
              IconButton(
                icon: Icon(Icons.filter_list, color: Colors.black), // Filter icon for date selection
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
              ),
          ],
        ),
      ],
    );
  }


  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
