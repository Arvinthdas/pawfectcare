import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:pawfectcare/login_screen.dart'; // Import the LoginScreen
import 'userprofile_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Color(0xFFE2BF65).withOpacity(0.4),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hey User,',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String value) async {
                          if (value == 'My Profile') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfilePage(),
                              ),
                            );
                          } else if (value == 'Log Out') {
                            try {
                              await FirebaseAuth.instance.signOut();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                            } catch (e) {
                              // Handle any errors during sign out
                              print('Sign out failed: $e');
                            }
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return {'My Profile', 'Log Out'}
                              .map((String choice) {
                            return PopupMenuItem<String>(
                              value: choice,
                              child: Text(choice),
                            );
                          }).toList();
                        },
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage:
                          AssetImage('assets/images/Pawfectcare.png'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // Rest of your HomeScreen widget...
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
