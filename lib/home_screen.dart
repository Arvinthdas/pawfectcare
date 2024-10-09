import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'addpets_screen.dart';
import 'login_screen.dart';
import 'userprofile_screen.dart';
import 'petprofile_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  List<Map<String, dynamic>> _pets = [];
  List<DocumentSnapshot> _petDocs = [];
  List _articles = [];

  bool _isLoadingPets = true;
  bool _isLoadingNews = true;

  final String apiKey = '784971b15e5c460e943f7e70adba0831'; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchPets();
    _fetchNewsArticles();
  }

  Future<void> _fetchPets() async {
    if (_currentUser != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('pets')
            .get();

        setState(() {
          _pets = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
          _petDocs = snapshot.docs;
        });
      } catch (e) {
        print("Error fetching pets: $e");
      } finally {
        setState(() {
          _isLoadingPets = false;
        });
      }
    }
  }

  Future<void> _fetchNewsArticles() async {
    final url = 'https://newsapi.org/v2/everything?q=pets&pageSize=20&apiKey=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _articles = data['articles'];
        });
      } else {
        print('Failed to load articles');
      }
    } catch (error) {
      print('Error fetching articles: $error');
    } finally {
      setState(() {
        _isLoadingNews = false;
      });
    }
  }

  Future<void> _logOut() async {
    final bool shouldLogOut = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Log Out'),
          content: Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogOut) {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  Future<void> _confirmDeletePet(DocumentSnapshot petDoc) async {
    final bool shouldDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Pet'),
          content: Text('Are you sure you want to delete this pet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete) {
      try {
        await petDoc.reference.delete();
        _fetchPets(); // Refresh the pet list after deletion
      } catch (e) {
        print("Error deleting pet: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      appBar: AppBar(
        backgroundColor: Color(0xFFF7EFF1),
        elevation: 0,
        leadingWidth: 200,
        leading: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Pawfectcare',
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
            onSelected: (String value) {
              if (value == 'My Profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfilePage()),
                );
              } else if (value == 'Log Out') {
                _logOut();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'My Profile', 'Log Out'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage: AssetImage('assets/images/Pawfectcare.png'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Pets',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            _isLoadingPets
                                ? Center(child: CircularProgressIndicator())
                                : _pets.isNotEmpty
                                ? GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _pets.length,
                              itemBuilder: (context, index) {
                                final pet = _pets[index];
                                final petDoc = _petDocs[index];

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PetProfileScreen(
                                          petName: pet['name'],
                                          petBreed: pet['breed'],
                                          petImageUrl: pet['imageUrl'] ??
                                              'assets/images/placeholder.png',
                                          isFemale: pet['gender'] == 'Female',
                                          petWeight: pet['weight'] ?? 0.0,
                                          petAge: pet['age']?.toString() ?? '',
                                          petType: pet['type'] ?? 'Unknown',
                                          ageType: pet['ageType'] ?? 'Years',
                                          petId: petDoc.id,
                                          userId: _currentUser!.uid,
                                        ),
                                      ),
                                    ).then((_) {
                                      _fetchPets(); // Refresh pets after returning
                                    });
                                  },
                                  onLongPress: () => _confirmDeletePet(petDoc),
                                  child: Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: pet['imageUrl'] != null
                                            ? Image.network(
                                          pet['imageUrl'],
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        )
                                            : Image.asset(
                                          'assets/images/placeholder.png',
                                          height: 100,
                                          width: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        pet['name'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        pet['breed'] ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                                : Text('No pets added yet.'),
                            SizedBox(height: 20),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => AddPetsScreen()),
                                  );
                                  _fetchPets(); // Refresh pets after adding a new one
                                },
                                icon: Icon(Icons.add),
                                label: Text('Add More Pets'),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Color(0xFFE2BF65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
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
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Latest Pet News',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            _isLoadingNews
                                ? Center(child: CircularProgressIndicator())
                                : _articles.isNotEmpty
                                ? ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _articles.length,
                              itemBuilder: (context, index) {
                                final article = _articles[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (article['urlToImage'] != null)
                                      Image.network(
                                        article['urlToImage'],
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    SizedBox(height: 10),
                                    Text(
                                      article['title'],
                                      style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      article['description'] ?? 'No description available',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                      ),
                                    ),
                                    Divider(),
                                  ],
                                );
                              },
                            )
                                : Text('No news articles available.'),
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
