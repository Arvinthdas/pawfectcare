import 'package:flutter/material.dart'; // For UI components
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore database access
import 'package:intl/intl.dart'; // For date formatting
import 'package:http/http.dart' as http; // For making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // For YouTube video playback
import 'addgrooming_screen.dart'; // Screen for adding grooming tasks
import 'groomingdetails_screen.dart'; // Screen for viewing grooming task details

class GroomingPage extends StatefulWidget {
  final String petId; // ID of the pet
  final String userId; // ID of the user
  final String petBreed; // Breed of the pet
  final String petName; // Name of the pet

  GroomingPage(
      {required this.petId,
      required this.userId,
      required this.petBreed,
      required this.petName});

  @override
  _GroomingPageState createState() =>
      _GroomingPageState(); // State for this widget
}

class _GroomingPageState extends State<GroomingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Controller for the tabs
  String _searchQuery = ''; // Query for searching grooming tasks
  String _skinIssue = ''; // Skin issue for fetching videos
  List<dynamic> _videos = []; // List to hold video data
  final String youtubeApiKey =
      'Youtube API Key'; // YouTube API key
  YoutubePlayerController?
      _youtubePlayerController; // Controller for YouTube player

  @override
  void initState() {
    super.initState(); // Initialize state
    _tabController =
        TabController(length: 2, vsync: this); // Set up the tab controller
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose of the tab controller
    _youtubePlayerController?.dispose(); // Dispose of the YouTube controller
    super.dispose(); // Call the superclass dispose method
  }

  List<YoutubePlayerController> _youtubePlayerControllers = [];


  Future<void> _fetchVideos(String breed, String issue) async {
    final String query = '$breed $issue'; // Build search query
    final String url =
        'https://www.googleapis.com/youtube/v3/search?key=$youtubeApiKey&part=snippet&type=video&q=$query'; // Construct API URL

    final response = await http.get(Uri.parse(url)); // Send GET request

    if (response.statusCode == 200) {
      // Check for a successful response
      final data = json.decode(response.body); // Decode the JSON response
      setState(() {
        _videos = data['items'] ?? []; // Update _videos with fetched video data
        _youtubePlayerControllers = _videos.map((video) {
          return YoutubePlayerController(
            initialVideoId: video['id']['videoId'],
            flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
          );
        }).toList(); // Update controllers based on the videos
      });
    } else {
      print('Failed to fetch videos: ${response.statusCode}'); // Log error if request fails
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold widget to provide structure
      backgroundColor: const Color(0xFFF7EFF1), // Set background color
      appBar: AppBar(
        // AppBar widget for the title and tabs
        backgroundColor: const Color(0xFFE2BF65), // AppBar color
        title: const Text(
          'Grooming', // Title text
          style: TextStyle(
              color: Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold), // Title styling
        ),
        bottom: TabBar(
          // TabBar for switching between views
          controller: _tabController,
          indicatorColor: const Color(0xFF037171), // Indicator color
          labelColor: Colors.white, // Color for selected label
          unselectedLabelColor: Colors.black, // Color for unselected labels
          labelStyle: const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold), // Label styling
          tabs: [
            const Tab(text: 'Grooming Task History'), // First tab
            const Tab(text: 'Skin Issues Tips & Guides'), // Second tab
          ],
        ),
      ),
      body: TabBarView(
        // Content for each tab
        controller: _tabController,
        children: [
          _buildGroomingScheduleTab(), // Tab for grooming schedule
          _buildSkinCoatHealthTab(), // Tab for skin and coat health
        ],
      ),
    );
  }

  Widget _buildGroomingScheduleTab() {
    return SingleChildScrollView(
      // Allows scrolling for content
      padding: const EdgeInsets.all(16.0), // Padding around the content
      child: Column(
        // Column for vertical arrangement
        crossAxisAlignment: CrossAxisAlignment.start, // Align items to start
        children: [
          _buildSectionHeader('Grooming Task History', onAddPressed: () {
            Navigator.push(
              // Navigate to add grooming screen
              context,
              MaterialPageRoute(
                // Create a route to the new screen
                builder: (context) => AddGroomingScreen(
                    petId: widget.petId,
                    userId: widget.userId,
                    petName: widget.petName),
              ),
            );
          }),
          const SizedBox(height: 10), // Spacing after header
          TextField(
            // Search field for grooming tasks
            onChanged: (value) =>
                setState(() => _searchQuery = value), // Update search query
            decoration: const InputDecoration(
              labelText: 'Search Grooming Tasks', // Placeholder for search
              border: OutlineInputBorder(), // Input border style
            ),
          ),
          const SizedBox(height: 10), // Spacing after search field
          _buildGroomingTasks(), // Build list of grooming tasks
          const SizedBox(height: 20), // Spacing before upcoming tasks
          _buildUpcomingGroomingTasks(), // Build upcoming grooming tasks section
        ],
      ),
    );
  }

  Widget _buildGroomingTasks() {
    return StreamBuilder<QuerySnapshot>(
      // Listen to grooming tasks stream
      stream: FirebaseFirestore.instance // Access Firestore instance
          .collection('users') // Access the users collection
          .doc(widget.userId) // Access specific user document
          .collection('pets') // Access pets collection
          .doc(widget.petId) // Access specific pet document
          .collection('groomingTasks') // Access grooming tasks collection
          .where('date',
              isLessThanOrEqualTo: DateTime.now()) // Filter past tasks
          .orderBy('date', descending: true) // Order by date
          .snapshots(), // Listen for real-time updates
      builder: (context, snapshot) {
        // Build method for the snapshot
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Check if data is loading
          return const Center(
              child: CircularProgressIndicator()); // Show loading spinner
        }
        if (snapshot.hasError) {
          // Check for errors
          return const Center(
              child:
                  Text('Error fetching grooming tasks')); // Show error message
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Check if no tasks available
          return const Center(
              child:
                  Text('No grooming tasks available')); // Show no tasks message
        }

        final tasks = snapshot.data!.docs.where((task) {
          // Filter tasks based on search query
          final taskName =
              task['taskName']?.toLowerCase() ?? ''; // Get task name
          final taskDate = (task['date'] as Timestamp)
              .toDate(); // Convert timestamp to DateTime
          final formattedDate =
              DateFormat('dd/MM/yyyy').format(taskDate); // Format date

          // Check if task name or formatted date matches search query
          return taskName.contains(_searchQuery.toLowerCase()) ||
              formattedDate == _searchQuery;
        }).toList(); // Convert filtered tasks to list

        return ListView.builder(
          // ListView to display tasks
          shrinkWrap: true, // Allow ListView to take only necessary space
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling
          itemCount: tasks.length, // Number of tasks
          itemBuilder: (context, index) {
            // Build method for each task
            final task = tasks[index]; // Get task at current index
            return _buildGroomingCard(
              // Build individual grooming card
              task['taskName'] ?? 'No Task Name', // Task name
              task['date'] ?? Timestamp.now(), // Task date
              task['productsUsed'] ?? 'No Products Used', // Products used
              task['notes'] ?? 'No Notes', // Additional notes
              task, // Pass entire task document
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingGroomingTasks() {
    return StreamBuilder<QuerySnapshot>(
      // Listen to upcoming tasks stream
      stream: FirebaseFirestore.instance // Access Firestore instance
          .collection('users') // Access the users collection
          .doc(widget.userId) // Access specific user document
          .collection('pets') // Access pets collection
          .doc(widget.petId) // Access specific pet document
          .collection('groomingTasks') // Access grooming tasks collection
          .where('date', isGreaterThan: DateTime.now()) // Filter future tasks
          .orderBy('date', descending: true) // Order by date
          .snapshots(), // Listen for real-time updates
      builder: (context, snapshot) {
        // Build method for the snapshot
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Check if data is loading
          return const Center(
              child: CircularProgressIndicator()); // Show loading spinner
        }
        if (snapshot.hasError) {
          // Check for errors
          return const Center(
              child: Text(
                  'Error fetching upcoming grooming tasks')); // Show error message
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Check if no upcoming tasks are found
          return const Center(
              child: Text(
                  'No upcoming grooming tasks available')); // Show no upcoming tasks message
        }

        final upcomingTasks =
            snapshot.data!.docs; // Get the list of upcoming tasks

        return Column(
          // Column for upcoming tasks
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align items to the start
          children: [
            const Text('Upcoming Grooming Tasks',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold)), // Header for upcoming tasks
            const SizedBox(height: 15), // Spacing before the upcoming tasks list
            ListView.builder(
              // ListView to display upcoming tasks
              shrinkWrap: true, // Allow ListView to take only necessary space
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling
              itemCount: upcomingTasks.length, // Number of upcoming tasks
              itemBuilder: (context, index) {
                // Build method for each upcoming task
                final task =
                    upcomingTasks[index]; // Get task at the current index
                return _buildGroomingCard(
                  // Build individual grooming card
                  task['taskName'] ?? 'No Task Name', // Task name
                  task['date'] ?? Timestamp.now(), // Task date
                  task['productsUsed'] ?? 'No Products Used', // Products used
                  task['notes'] ?? 'No Notes', // Additional notes
                  task, // Pass entire task document
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroomingCard(String taskName, dynamic date, String productsUsed,
      String notes, DocumentSnapshot taskRecord) {
    String formattedDate; // Variable to hold the formatted date

    if (date is Timestamp) {
      // Check if the date is a Timestamp
      formattedDate = DateFormat('dd/MM/yyyy HH:mm')
          .format(date.toDate()); // Format the date
    } else {
      formattedDate =
          date.toString(); // Convert date to string if not a Timestamp
    }

    return GestureDetector(
      onTap: () {
        // On tap action
        Navigator.push(
          // Navigate to the GroomingDetailScreen
          context,
          MaterialPageRoute(
            // Create a route to the new screen
            builder: (context) => GroomingDetailScreen(
              // Pass the grooming record and other data
              groomingRecord: taskRecord,
              petId: widget.petId,
              userId: widget.userId,
              petName: widget.petName,
            ),
          ),
        );
      },
      onLongPress: () {
        // Show confirmation dialog on long press
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Confirmation'),
              content: const Text('Are you sure you want to delete this task?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    // Delete the task from Firestore
                    await taskRecord.reference.delete();
                    Navigator.of(context).pop(); // Close dialog after deletion

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Delete Successful'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      child: Card(
        // Card widget for displaying grooming task details
        color: Colors.white, // Card background color
        elevation: 3, // Elevation for shadow effect
        shape: RoundedRectangleBorder(
          // Shape of the card
          borderRadius: BorderRadius.circular(10), // Rounded corners
        ),
        child: Padding(
          // Padding around the card content
          padding: const EdgeInsets.all(12.0), // Padding value
          child: Column(
            // Column to arrange text widgets vertically
            crossAxisAlignment:
            CrossAxisAlignment.start, // Align items to the start
            children: [
              Text(taskName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)), // Task name
              Text('Date: $formattedDate',
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey[700])), // Formatted date
              Text('Products Used: $productsUsed',
                  style: TextStyle(
                      fontSize: 16, color: Colors.grey[700])), // Products used
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


  Widget _buildSectionHeader(String title,
      {required VoidCallback onAddPressed}) {
    // Method to build section header
    return Row(
      // Row for header and button
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween, // Space between header and button
      children: [
        Text(
          // Header text
          title, // Section title
          style: const TextStyle(
            // Text style for the header
            fontSize: 20, // Font size
            fontWeight: FontWeight.bold, // Font weight
            color: Colors.black87, // Text color
          ),
        ),
        TextButton(
          // Button to add a new grooming task
          onPressed: onAddPressed, // Function to call on button press
          child: const Row(
            // Row for button content
            children: [
              Icon(Icons.add, color: Colors.black), // Add icon
              Text('Add', style: TextStyle(color: Colors.black)), // Add text
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkinCoatHealthTab() {
    // Method to build the skin and coat health tab
    return SingleChildScrollView(
      // Allows scrolling for content
      padding: const EdgeInsets.all(16.0), // Padding around the content
      child: Column(
        // Column for vertical arrangement
        crossAxisAlignment: CrossAxisAlignment.start, // Align items to start
        children: [
          _buildSkinIssueForm(), // Form to add skin issue
          const SizedBox(height: 20), // Spacing after the form
          _buildVideosSection(), // Section to display YouTube videos
          const SizedBox(height: 20), // Spacing after video section
          _buildTipsSection(), // Section for pet care tips
        ],
      ),
    );
  }

  Widget _buildSkinIssueForm() {
    // Method to build the skin issue form
    return Card(
      // Card widget for the form
      elevation: 3, // Elevation for shadow effect
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)), // Rounded corners
      child: Padding(
        // Padding around the card content
        padding: const EdgeInsets.all(16.0), // Padding value
        child: Column(
          // Column for vertical arrangement
          crossAxisAlignment: CrossAxisAlignment.start, // Align items to start
          children: [
            const Text(
              // Header for the form
              'Add Skin Issue',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold), // Header style
            ),
            const SizedBox(height: 10), // Spacing after the header
            TextField(
              // TextField for entering skin issue
              onChanged: (value) {
                // Callback on text change
                _skinIssue = value; // Update skin issue variable
              },
              decoration: const InputDecoration(
                // Decoration for the TextField
                labelText: 'Enter skin issue', // Label for input
                border: OutlineInputBorder(), // Border style
              ),
            ),
            const SizedBox(height: 10), // Spacing after the TextField
            ElevatedButton(
              // Button to search for videos
              onPressed: () {
                // Callback on button press
                if (_skinIssue.isNotEmpty) {
                  // Check if skin issue is not empty
                  _fetchVideos(widget.petBreed,
                      _skinIssue); // Fetch videos based on breed and skin issue
                }
              },
              child: const Text('Search Videos'), // Button text
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosSection() {
    // Method to build the YouTube videos section
    return Card(
      // Card widget for the videos section
      elevation: 3, // Elevation for shadow effect
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)), // Rounded corners
      child: Padding(
        // Padding around the card content
        padding: const EdgeInsets.all(16.0), // Padding value
        child: Column(
          // Column for vertical arrangement
          crossAxisAlignment: CrossAxisAlignment.start, // Align items to start
          children: [
            const Text(
              // Header for the videos section
              'YouTube Videos',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold), // Header style
            ),
            const SizedBox(height: 10), // Spacing after the header
            _videos.isEmpty // Check if there are no videos
                ? const Text(
                    'No videos found. Please add a skin issue and search.') // Message for no videos
                : ListView.builder(
                    // ListView to display videos
                    shrinkWrap:
                        true, // Allow ListView to take only necessary space
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable scrolling
                    itemCount: _videos.length, // Number of videos
                    itemBuilder: (context, index) {
                      // Build method for each video
                      final video =
                          _videos[index]; // Get video at current index
                      final videoId =
                          video['id']['videoId']; // Extract video ID
                      final title =
                          video['snippet']['title']; // Extract video title
                      return _buildYoutubePlayer(index); // Build YouTube player for the video
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildYoutubePlayer(int index) {
    final video = _videos[index]; // Get the video at the specified index
    final videoController = _youtubePlayerControllers[index]; // Get the corresponding controller
    final title = video['snippet']['title']; // Get the video title

    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        YoutubePlayer(
          controller: videoController,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blueAccent,
        ),
        const SizedBox(height: 16),
      ],
    );
  }



  Widget _buildTipsSection() {
    // Method to build the tips section
    return Card(
      // Card widget for the tips section
      elevation: 3, // Elevation for shadow effect
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)), // Rounded corners
      child: const Padding(
        // Padding around the card content
        padding: EdgeInsets.all(16.0), // Padding value
        child: Column(
          // Column for vertical arrangement
          crossAxisAlignment: CrossAxisAlignment.start, // Align items to start
          children: [
            Text(
              // Header for the tips section
              'Pet Skin Care Tips',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold), // Header style
            ),
            SizedBox(height: 10), // Spacing after the header
            Text(
              // Tips for pet skin care
              '1. Regularly check your pet’s skin for signs of irritation, redness, or dryness.\n'
              '2. Use hypoallergenic shampoos that are gentle on the skin.\n'
              '3. Keep your pet’s skin moisturized, especially during dry seasons.\n'
              '4. Ensure a balanced diet with omega-3 fatty acids for healthy skin.\n'
              '5. Consult a vet if any unusual symptoms persist.',
              style: TextStyle(fontSize: 16), // Style for tips text
            ),
          ],
        ),
      ),
    );
  }
}
