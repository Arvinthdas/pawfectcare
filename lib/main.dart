import 'package:flutter/material.dart'; // Import the Flutter Material package for UI components
import 'package:firebase_core/firebase_core.dart'; // Import Firebase core package for initialization
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase authentication package
import 'package:permission_handler/permission_handler.dart'; // Import package for handling permissions
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import package for local notifications
import 'package:timezone/data/latest.dart'
    as tz; // Import timezone data for handling time zones
import 'package:timezone/timezone.dart' as tz; // Import timezone utilities
import 'login_screen.dart'; // Import the login screen widget
import 'home_screen.dart'; // Import the home screen widget

// Initialize FlutterLocalNotificationsPlugin instance for notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure Flutter bindings are initialized
  await Firebase.initializeApp(); // Initialize Firebase

  tz.initializeTimeZones(); // Initialize time zones
  tz.setLocalLocation(
      tz.getLocation('Asia/Kuala_Lumpur')); // Set local timezone

  await _initializeNotifications(); // Initialize notifications
  runApp(MyApp()); // Run the main application
}

Future<void> _initializeNotifications() async {
  // Define Android-specific settings for notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // Combine Android settings with platform-specific settings
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
      initializationSettings); // Initialize notifications with settings
  _createNotificationChannel(); // Create a notification channel
}

Future<void> _createNotificationChannel() async {
  // Define a notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'vaccination_channel', // Channel ID
    'Vaccination Notifications', // Channel name
    description:
        'This channel is for vaccination notifications', // Channel description
    importance: Importance.max, // Importance level for notifications
  );

  // Resolve platform-specific implementation for Android
  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(
        channel); // Create the channel if Android plugin is available
  }
}

// Main application widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCare App', // Application title
      theme:
          ThemeData(primarySwatch: Colors.blue), // Theme settings for the app
      home: SplashScreen(), // Start with the SplashScreen
      debugShowCheckedModeBanner: false, // Hide debug banner
    );
  }
}

// Splash screen widget
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

// State for the SplashScreen
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller; // Animation controller for animations
  late Animation<double> _fadeAnimation; // Fade animation
  late Animation<double> _scaleAnimation; // Scale animation

  @override
  void initState() {
    super.initState();

    // Initialize AnimationController with duration
    _controller = AnimationController(
      vsync: this, // Provide the TickerProvider
      duration: Duration(seconds: 2), // Duration for the animation
    );

    // Initialize fade and scale animations
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: Curves.easeIn), // Curve for fade animation
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut), // Curve for scale animation
    );

    // Start the animation
    _controller.forward();

    // Navigate to AuthChecker after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => AuthChecker()), // Navigate to AuthChecker
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Background color of the splash screen
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation, // Use fade animation
          child: ScaleTransition(
            scale: _scaleAnimation, // Use scale animation
            child: Image.asset(
              'assets/images/splash.png', // Path to your logo image
              width: 500, // Adjust the size as needed
              height: 500,
            ),
          ),
        ),
      ),
    );
  }
}

// AuthChecker widget to determine user authentication status
class AuthChecker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance
          .authStateChanges(), // Listen to authentication state changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
                child:
                    CircularProgressIndicator()), // Show loading indicator while waiting
          );
        } else if (snapshot.hasData) {
          return HomeScreen(); // If authenticated, navigate to HomeScreen
        } else {
          _requestPermissions(); // Request permissions if not authenticated
          return LoginScreen(); // Show LoginScreen if not authenticated
        }
      },
    );
  }

  // Function to request necessary permissions
  void _requestPermissions() async {
    var storageStatus =
        await Permission.storage.status; // Check storage permission status
    if (!storageStatus.isGranted) {
      await Permission.storage
          .request(); // Request storage permission if not granted
    }

    var notificationStatus = await Permission
        .notification.status; // Check notification permission status
    if (!notificationStatus.isGranted) {
      await Permission.notification
          .request(); // Request notification permission if not granted
    }
  }
}
