import 'dart:convert'; // For JSON encoding/decoding
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore for database
import 'package:flutter/material.dart'; // Flutter material design components
import 'package:firebase_auth/firebase_auth.dart'; // Firebase authentication
import 'package:http/http.dart' as http; // For making HTTP requests
import 'addpets_screen.dart'; // Screen to add pets
import 'login_screen.dart'; // Screen for user login
import 'petprofile_screen.dart'; // Screen to display pet profile

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // Firebase authentication instance
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance

  User? _currentUser; // Current user
  List<Map<String, dynamic>> _pets = []; // List of pets
  List<DocumentSnapshot> _petDocs = []; // List of pet document snapshots
  List _articles = []; // List of news articles

  bool _isLoadingPets = true; // Loading state for pets
  bool _isLoadingNews = true; // Loading state for news articles

  final String apiKey =
      'News Api Key'; // Replace with your actual API key

  @override
  void initState() {
    super.initState(); // Initialize state
    _currentUser = _auth.currentUser; // Get current user
    _fetchPets(); // Fetch pets
    _fetchNewsArticles(); // Fetch news articles
  }

  Future<void> _fetchPets() async {
    if (_currentUser != null) {
      // Check if user is logged in
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('pets')
            .get(); // Get pet documents

        setState(() {
          _pets = snapshot.docs
              .map((doc) =>
                  doc.data() as Map<String, dynamic>) // Map documents to data
              .toList();
          _petDocs = snapshot.docs; // Store document snapshots
        });
      } catch (e) {
        print("Error fetching pets: $e"); // Log errors
      } finally {
        setState(() {
          _isLoadingPets = false; // Set loading state to false
        });
      }
    }
  }

  Future<void> _fetchNewsArticles() async {
    final url =
        'https://newsapi.org/v2/everything?q=pets&pageSize=20&apiKey=$apiKey'; // API URL
    try {
      final response = await http.get(Uri.parse(url)); // Fetch articles
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); // Decode JSON response
        setState(() {
          _articles = data['articles']; // Store articles
        });
      } else {
        print('Failed to load articles'); // Log failure
      }
    } catch (error) {
      print('Error fetching articles: $error'); // Log errors
    } finally {
      setState(() {
        _isLoadingNews = false; // Set loading state to false
      });
    }
  }

  Future<void> _logOut() async {
    final bool shouldLogOut = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'), // Confirmation dialog for log out
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Cancel action
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Confirm log out
              },
              child: const Text('Log Out'),
            ),
          ], // Closing bracket for actions
        ); // Closing bracket for AlertDialog
      },
    );

    if (shouldLogOut) {
      await _auth.signOut(); // Sign out the user
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => LoginScreen()), // Navigate to login screen
      );
    }
  }

  Future<void> _confirmDeletePet(DocumentSnapshot petDoc) async {
    final bool shouldDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
              const Text('Delete Pet'), // Confirmation dialog for pet deletion
          content: const Text('Are you sure you want to delete this pet?'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // Cancel action
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(true), // Confirm deletion
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete) {
      try {
        await petDoc.reference.delete(); // Delete pet document
        _fetchPets(); // Refresh the pet list after deletion
      } catch (e) {
        print("Error deleting pet: $e"); // Log errors
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1), // Background color
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7EFF1), // App bar color
        elevation: 0, // Remove shadow
        leadingWidth: 200, // Width of leading widget
        leading: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Pawfectcare', // App title
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            // Menu for log out option
            onSelected: (String value) {
              if (value == 'Log Out') {
                _logOut(); // Log out if selected
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Log Out'}.map((String choice) {
                // Popup menu item
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
            child: CircleAvatar(
              // User avatar
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage: const AssetImage(
                  'assets/images/Pawfectcare.png'), // Avatar image
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20), // Padding for body
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0), // Card padding
                    child: Card(
                      elevation: 5, // Card elevation
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15), // Rounded corners
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0), // Inner padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Pets', // Section title
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                                height: 10), // Space between title and content
                            _isLoadingPets
                                ? const Center(
                                    child:
                                        CircularProgressIndicator()) // Loading spinner
                                : _pets.isNotEmpty
                                    ? GridView.builder(
                                        shrinkWrap: true, // Prevent overflow
                                        physics:
                                            const NeverScrollableScrollPhysics(), // Disable scrolling
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2, // Two columns
                                          childAspectRatio:
                                              0.8, // Aspect ratio for items
                                          crossAxisSpacing:
                                              10, // Spacing between items
                                          mainAxisSpacing:
                                              10, // Spacing between rows
                                        ),
                                        itemCount: _pets.length, // Total pets
                                        itemBuilder: (context, index) {
                                          final pet =
                                              _pets[index]; // Current pet
                                          final petDoc = _petDocs[
                                              index]; // Corresponding document

                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PetProfileScreen(
                                                    petName: pet[
                                                        'name'], // Pass pet details
                                                    petBreed: pet['breed'],
                                                    petImageUrl: pet[
                                                            'imageUrl'] ??
                                                        'assets/images/placeholder.png',
                                                    isFemale: pet['gender'] ==
                                                        'Female',
                                                    petWeight:
                                                        pet['weight'] ?? 0.0,
                                                    petAge: pet['age']
                                                            ?.toString() ??
                                                        '',
                                                    petType: pet['type'] ??
                                                        'Unknown',
                                                    ageType: pet['ageType'] ??
                                                        'Years',
                                                    petId: petDoc
                                                        .id, // Pet document ID
                                                    userId: _currentUser!
                                                        .uid, // User ID
                                                  ),
                                                ),
                                              ).then((_) {
                                                _fetchPets(); // Refresh pets after returning
                                              });
                                            },
                                            onLongPress: () => _confirmDeletePet(
                                                petDoc), // Confirm deletion on long press
                                            child: Column(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10), // Rounded corners for image
                                                  child: pet['imageUrl'] != null
                                                      ? Image.network(
                                                          pet['imageUrl'], // Load pet image from URL
                                                          height: 100,
                                                          width: 100,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Image.asset(
                                                          'assets/images/placeholder.png', // Placeholder if no image
                                                          height: 100,
                                                          width: 100,
                                                          fit: BoxFit.cover,
                                                        ),
                                                ),
                                                const SizedBox(
                                                    height:
                                                        8), // Space below image
                                                Text(
                                                  pet['name'] ??
                                                      'Unknown', // Pet name
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  pet['breed'] ??
                                                      '', // Pet breed
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 14,
                                                    color: Colors.grey[
                                                        600], // Grey color for breed text
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    : const Text(
                                        'No pets added yet.'), // Message when no pets are present
                            const SizedBox(
                                height: 20), // Space before add button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            AddPetsScreen()), // Navigate to add pets screen
                                  );
                                  _fetchPets(); // Refresh pets after adding a new one
                                },
                                icon: const Icon(Icons.add), // Add icon
                                label:
                                    const Text('Add More Pets'), // Button label
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black, // Text color
                                  backgroundColor:
                                      const Color(0xFFE2BF65), // Button color
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        10), // Rounded button
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0), // Padding for news card
                    child: Card(
                      elevation: 5, // Card elevation
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(15), // Rounded corners
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                            16.0), // Inner padding for news card
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Latest Pet News', // Section title
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                                height: 10), // Space between title and content
                            _isLoadingNews
                                ? const Center(
                                    child:
                                        CircularProgressIndicator()) // Loading spinner for news
                                : _articles.isNotEmpty
                                    ? ListView.builder(
                                        shrinkWrap: true, // Prevent overflow
                                        physics:
                                            const NeverScrollableScrollPhysics(), // Disable scrolling
                                        itemCount:
                                            _articles.length, // Total articles
                                        itemBuilder: (context, index) {
                                          final article = _articles[
                                              index]; // Current article
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (article['urlToImage'] !=
                                                  null) // Check if image URL exists
                                                Image.network(
                                                  article[
                                                      'urlToImage'], // Load article image
                                                  height: 200,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              const SizedBox(
                                                  height:
                                                      10), // Space below image
                                              Text(
                                                article[
                                                    'title'], // Article title
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(
                                                  height:
                                                      5), // Space below title
                                              Text(
                                                article['description'] ??
                                                    'No description available', // Article description
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const Divider(), // Divider between articles
                                            ],
                                          );
                                        },
                                      )
                                    : const Text(
                                        'No news articles available.'), // Message when no articles are present
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
