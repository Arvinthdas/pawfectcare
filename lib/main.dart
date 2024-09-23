import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication
import 'login_screen.dart';   // Import your LoginScreen
import 'home_screen.dart';    // Import your HomeScreen widget
import 'pethealth_screen.dart';   // Import your PetHealthScreen widget
import 'petprofile_screen.dart';  // Import your PetProfileScreen widget
import 'nutrition_screen.dart';   // Import your NutritionPage widget
import 'exercise_screen.dart';    // Import your ExerciseScreen widget
import 'grooming_screen.dart';    // Import your GroomingScreen widget

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Ensure widgets are initialized before Firebase
  await Firebase.initializeApp();            // Initialize Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCare App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthChecker(),  // Checks if the user is logged in or not
    );
  }
}

// Widget to check if the user is logged in or not
class AuthChecker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // Listen for user auth state changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading screen while checking the auth state
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          // If user is logged in, navigate to the MainScreen
          return MainScreen();
        } else {
          // If user is not logged in, navigate to LoginScreen
          return LoginScreen();
        }
      },
    );
  }
}

// Main screen that contains the BottomNavigationBar
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),         // Index 0
    PetHealthScreen(),     // Index 1
    NutritionPage(),       // Index 2
    ExerciseMonitoringPage(),      // Index 3
    GroomingPage(),      // Index 4
    PetProfileScreen(),    // Index 5
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFFE2BF65),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 30),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital_outlined, size: 30),
            label: 'HEALTH',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined, size: 30),
            label: 'NUTRITION',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run_outlined, size: 30),
            label: 'EXERCISE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.content_cut_outlined, size: 30),
            label: 'GROOMING',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets_outlined, size: 30),
            label: 'PET PROFILE',
          ),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}
