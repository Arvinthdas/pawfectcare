import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'addgrooming_screen.dart'; // Assume this is the screen to add grooming tasks
import 'groomingdetails_screen.dart'; // Screen to show details of grooming tasks

class GroomingPage extends StatefulWidget {
  final String petId;
  final String userId;

  GroomingPage({required this.petId, required this.userId});

  @override
  _GroomingPageState createState() => _GroomingPageState();
}

class _GroomingPageState extends State<GroomingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: Text(
          'Grooming',
          style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black,
          tabs: [
            Tab(text: 'Grooming Task History'),
            Tab(text: 'Skin & Coat Health'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroomingScheduleTab(),
          _buildSkinCoatHealthTab(),
        ],
      ),
    );
  }

  // Grooming Schedule Tab
  Widget _buildGroomingScheduleTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Grooming Task History', onAddPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddGroomingScreen(petId: widget.petId, userId: widget.userId),
              ),
            );
          }),
          SizedBox(height: 10),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              labelText: 'Search Grooming Tasks',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          _buildGroomingTasks(),
          SizedBox(height: 20),
          _buildUpcomingGroomingTasks(),
        ],
      ),
    );
  }

  Widget _buildGroomingTasks() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .where('date', isLessThanOrEqualTo: DateTime.now())
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching grooming tasks'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No grooming tasks available'));
        }

        final tasks = snapshot.data!.docs.where((task) {
          final taskName = task['taskName']?.toLowerCase() ?? '';
          return taskName.contains(_searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildGroomingCard(
              task['taskName'] ?? 'No Task Name',
              task['date'] ?? Timestamp.now(), // Handle date properly
              task['productsUsed'] ?? 'No Products Used',
              task['notes'] ?? 'No Notes',
              task,
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingGroomingTasks() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('pets')
          .doc(widget.petId)
          .collection('groomingTasks')
          .where('date', isGreaterThan: DateTime.now())
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching upcoming grooming tasks'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No upcoming grooming tasks available'));
        }

        final upcomingTasks = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming Grooming Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: upcomingTasks.length,
              itemBuilder: (context, index) {
                final task = upcomingTasks[index];
                return _buildGroomingCard(
                  task['taskName'] ?? 'No Task Name',
                  task['date'] ?? Timestamp.now(), // Handle date properly
                  task['productsUsed'] ?? 'No Products Used',
                  task['notes'] ?? 'No Notes',
                  task,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroomingCard(String taskName, dynamic date, String productsUsed, String notes, DocumentSnapshot taskRecord) {
    String formattedDate;

    if (date is Timestamp) {
      formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date.toDate());
    } else {
      formattedDate = date.toString(); // Fallback in case of any issue
    }

    return InkWell(
      onTap: () {
        // Navigate to grooming details screen with valid petId and userId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroomingDetailScreen(
              groomingRecord: taskRecord,
              petId: widget.petId, // Ensure you're passing the petId
              userId: widget.userId, // Ensure you're passing the userId
            ),
          ),
        );
      },
      onLongPress: () {
        _showDeleteDialog(taskRecord);
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
              Text(taskName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Date: $formattedDate', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Products Used: $productsUsed', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text('Notes: $notes', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _showDeleteDialog(DocumentSnapshot taskRecord) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Grooming Task'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this grooming task?'),
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
                await taskRecord.reference.delete();
                Navigator.of(context).pop();
                _showMessage('Grooming task deleted successfully.');
              },
            ),
          ],
        );
      },
    );
  }

  // Skin & Coat Health Tab
  Widget _buildSkinCoatHealthTab() {
    return Center(
      child: Text('Skin and Coat Health Tracker Content'),
    );
  }

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
              Text('Add', style: TextStyle(color: Colors.black)),
            ],
          ),
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
