import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // Import the login screen

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initialize Firebase Auth
  final _formKey = GlobalKey<FormState>(); // Key to identify the form

  // Controllers for input fields
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false; // Loading state for registration process
  bool _isPasswordVisible = false; // State for password visibility
  bool _isConfirmPasswordVisible =
      false; // State for confirm password visibility
  String? _quote; // Variable to hold a random quote

  // API keys for external services
  final String apiKey =
      'XOfHWWJgQcCgZGlFEREVDQ==DWSUUw0KN5cGogaA'; // Replace with your API Ninja key
  final String zeroBounceApiKey =
      'f9bf0e1152d5400795b03e6d4dca6165'; // Replace with your ZeroBounce API key

  @override
  void initState() {
    super.initState();
    _fetchRandomHappinessQuote(); // Fetch a random quote on screen load
  }

  // Fetch a random happiness quote from the API
  Future<void> _fetchRandomHappinessQuote() async {
    final url = Uri.parse(
        'https://api.api-ninjas.com/v1/quotes?category=happiness'); // API endpoint for quotes
    try {
      final response = await http.get(
        url,
        headers: {'X-Api-Key': apiKey}, // Add API key to the request header
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Decode the JSON response
        setState(() {
          _quote = data[0]['quote']; // Get the first quote from the response
        });
      } else {
        // If API call fails, set a default quote
        setState(() {
          _quote = "Happiness is the best gift for your pet!";
        });
      }
    } catch (e) {
      // Handle any errors during the API call
      setState(() {
        _quote = "Error loading quote.";
      });
    }
  }

  // Validate the email using ZeroBounce API
  Future<bool> _validateEmail(String email) async {
    final url = Uri.parse(
        'https://api.zerobounce.net/v2/validate?api_key=$zeroBounceApiKey&email=$email');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body); // Decode the response
      return data['status'] == 'valid'; // Return true if the email is valid
    } else {
      throw Exception("Failed to validate email"); // Handle errors
    }
  }

  // Dispose controllers when not needed
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validate the password according to specified constraints
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty'; // Check if password is empty
    } else if (value.length < 6) {
      return 'Password must be at least 6 characters long'; // Check minimum length
    } else if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter'; // Check for lowercase
    } else if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter'; // Check for uppercase
    } else if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one digit'; // Check for digit
    } else if (!RegExp(r'(?=.*[@$!%*?&])').hasMatch(value)) {
      return 'Password must contain at least one special character'; // Check for special character
    }
    return null; // Return null if validation is successful
  }

  // Register the user
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      // Validate form fields
      // Validate the email before registration
      bool isValidEmail = await _validateEmail(_emailController.text.trim());
      if (!isValidEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Invalid email address")), // Show invalid email message
        );
        return;
      }

      // Check if passwords match
      if (_passwordController.text == _confirmPasswordController.text) {
        setState(() {
          _isLoading = true; // Set loading state
        });

        try {
          // Create a user with email and password
          UserCredential userCredential =
              await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          User? user = userCredential.user; // Get the user

          if (user != null) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Account created successfully!")),
            );

            // Navigate to LoginScreen after showing success message
            Future.delayed(const Duration(seconds: 2), () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            });
          }
        } on FirebaseAuthException catch (e) {
          String message;
          switch (e.code) {
            case 'email-already-in-use':
              message =
                  "This email is already registered"; // Handle email already in use error
              break;
            case 'invalid-email':
              message =
                  "The email address is not valid"; // Handle invalid email error
              break;
            default:
              message =
                  "Registration failed: ${e.message}"; // Handle other registration errors
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)), // Show the error message
          );
        } finally {
          setState(() {
            _isLoading = false; // Reset loading state
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Passwords do not match")), // Show password mismatch message
        );
      }
    }
  }

  // Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7EFF1),
      body: Stack(
        children: [
          // Background circles for aesthetic
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: const Color(0xFFE2BF65)
                  .withOpacity(0.4), // Semi-transparent circle
            ),
          ),
          const Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Color(0xFF61481C), // Solid circle
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 30), // Horizontal padding
              child: Form(
                key: _formKey, // Assign form key
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Hey there! 👋",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Display quote or loading indicator
                    _quote != null
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              _quote!,
                              style: TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center, // Center align quote
                            ),
                          )
                        : const CircularProgressIndicator(), // Show loading indicator
                    const SizedBox(height: 20),
                    // Email input field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email), // Email icon
                        hintText: 'Email Address', // Hint text
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[300],
                      ),
                      validator: (value) {
                        // Validate email input
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return 'Please enter a valid email'; // Show validation message
                        }
                        return null; // Return null if validation is successful
                      },
                    ),
                    const SizedBox(height: 20),
                    // Password input field
                    TextFormField(
                      controller: _passwordController,
                      obscureText:
                          !_isPasswordVisible, // Toggle password visibility
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock), // Password icon
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off, // Toggle icon
                          ),
                          onPressed:
                              _togglePasswordVisibility, // Toggle password visibility
                        ),
                        hintText: 'Password', // Hint text
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[300],
                      ),
                      validator: _validatePassword, // Validate password input
                    ),
                    const SizedBox(height: 20),
                    // Confirm password input field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText:
                          !_isConfirmPasswordVisible, // Toggle confirm password visibility
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.lock), // Confirm password icon
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off, // Toggle icon
                          ),
                          onPressed:
                              _toggleConfirmPasswordVisibility, // Toggle confirm password visibility
                        ),
                        hintText: 'Confirm Password', // Hint text
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[300],
                      ),
                      validator: (value) {
                        // Validate confirm password input
                        if (value == null ||
                            value.isEmpty ||
                            value != _passwordController.text) {
                          return 'Passwords do not match'; // Show validation message
                        }
                        return null; // Return null if validation is successful
                      },
                    ),
                    const SizedBox(height: 20),
                    // Register button
                    _isLoading
                        ? const CircularProgressIndicator() // Show loading indicator if in loading state
                        : ElevatedButton(
                            onPressed:
                                _register, // Call register function on press
                            child: const Text('Register'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor: const Color(0xFFE2BF65),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 100),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    // Navigate to login screen
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Already have an account? Login',
                        style: TextStyle(
                          color: Color(0xFF61481C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Toggle visibility for password
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible; // Toggle the visibility state
    });
  }

  // Toggle visibility for confirm password
  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible =
          !_isConfirmPasswordVisible; // Toggle the visibility state
    });
  }
}
