import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'addgrooming_screen.dart'; // Assume this is the screen to add grooming tasks
import 'groomingdetails_screen.dart'; // Screen to show details of grooming tasks

class GroomingPage extends StatefulWidget {
  final String petId;
  final String userId;
  final String petBreed; // Added breed information
  final String petName;

  GroomingPage({required this.petId, required this.userId, required this.petBreed, required this.petName});

  @override
  _GroomingPageState createState() => _GroomingPageState();
}

class _GroomingPageState extends State<GroomingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _skinIssue = '';
  List<dynamic> _videos = [];
  final String youtubeApiKey = 'AIzaSyBlSI4WvUAcAdrJ07JMbqhNBRd7LzPai1U'; // Replace with your actual YouTube API key
  YoutubePlayerController? _youtubePlayerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _youtubePlayerController?.dispose();
    super.dispose();
  }

  // Fetch YouTube videos based on breed and skin issue
  Future<void> _fetchVideos(String breed, String issue) async {
    final String query = '$breed $issue';
    final String url =
        'https://www.googleapis.com/youtube/v3/search?key=$youtubeApiKey&part=snippet&type=video&q=$query';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _videos = data['items'] ?? [];
      });
    } else {
      print('Failed to fetch videos: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        backgroundColor: Color(0xFFE2BF65),
        title: Text(
          'Grooming',
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Color(0xFF037171),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black,
          labelStyle: TextStyle(fontSize: 15,fontStyle: FontStyle.italic ,fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'Grooming Task History'),
            Tab(text: 'Skin Issues Tips & Guides'),
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
                builder: (context) => AddGroomingScreen(petId: widget.petId, userId: widget.userId, petName: widget.petName),
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
          final taskDate = (task['date'] as Timestamp).toDate();
          final formattedDate = DateFormat('dd/MM/yyyy').format(taskDate);

          // Check if the search query is either in task name or matches the date
          return taskName.contains(_searchQuery.toLowerCase()) ||
              formattedDate == _searchQuery; // Compare formatted date with the search query
        }).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildGroomingCard(
              task['taskName'] ?? 'No Task Name',
              task['date'] ?? Timestamp.now(),
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
            SizedBox(height: 15),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: upcomingTasks.length,
              itemBuilder: (context, index) {
                final task = upcomingTasks[index];
                return _buildGroomingCard(
                  task['taskName'] ?? 'No Task Name',
                  task['date'] ?? Timestamp.now(),
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
      formattedDate = date.toString();
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroomingDetailScreen(
              groomingRecord: taskRecord,
              petId: widget.petId,
              userId: widget.userId,
              petName: widget.petName,
            ),
          ),
        );
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

  // Skin & Coat Health Tab
  Widget _buildSkinCoatHealthTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkinIssueForm(),
          SizedBox(height: 20),
          _buildVideosSection(),
          SizedBox(height: 20),
          _buildTipsSection(),
        ],
      ),
    );
  }

  // 1st Compartment: Form to Add Pet's Skin Issue
  Widget _buildSkinIssueForm() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Skin Issue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            TextField(
              onChanged: (value) {
                _skinIssue = value;
              },
              decoration: InputDecoration(
                labelText: 'Enter skin issue',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (_skinIssue.isNotEmpty) {
                  _fetchVideos(widget.petBreed, _skinIssue);
                }
              },
              child: Text('Search Videos'),
            ),
          ],
        ),
      ),
    );
  }

  // 2nd Compartment: Display YouTube Videos with Embedded Player
  Widget _buildVideosSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YouTube Videos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _videos.isEmpty
                ? Text('No videos found. Please add a skin issue and search.')
                : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                final videoId = video['id']['videoId'];
                final title = video['snippet']['title'];
                return _buildYoutubePlayer(videoId, title);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYoutubePlayer(String videoId, String title) {
    _youtubePlayerController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );

    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        YoutubePlayer(
          controller: _youtubePlayerController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blueAccent,
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // 3rd Compartment: Hardcoded Tips for Pet Skin Care
  Widget _buildTipsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pet Skin Care Tips',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '1. Regularly check your pet’s skin for signs of irritation, redness, or dryness.\n'
                  '2. Use hypoallergenic shampoos that are gentle on the skin.\n'
                  '3. Keep your pet’s skin moisturized, especially during dry seasons.\n'
                  '4. Ensure a balanced diet with omega-3 fatty acids for healthy skin.\n'
                  '5. Consult a vet if any unusual symptoms persist.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
