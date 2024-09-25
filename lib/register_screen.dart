import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _quote;

  final String apiKey = 'XOfHWWJgQcCgZGlFEREVDQ==DWSUUw0KN5cGogaA'; // Replace with your API Ninja key
  final String zeroBounceApiKey = 'f9bf0e1152d5400795b03e6d4dca6165'; // Replace with your ZeroBounce API key

  @override
  void initState() {
    super.initState();
    _fetchRandomHappinessQuote(); // Fetch the random happiness quote on screen load
  }

  Future<void> _fetchRandomHappinessQuote() async {
    final url = Uri.parse('https://api.api-ninjas.com/v1/quotes?category=happiness');
    try {
      final response = await http.get(
        url,
        headers: {'X-Api-Key': apiKey}, // Add API key to the request header
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _quote = data[0]['quote']; // Get the first quote from the response
        });
      } else {
        setState(() {
          _quote = "Happiness is the best gift for your pet!";
        });
      }
    } catch (e) {
      setState(() {
        _quote = "Error loading quote.";
      });
    }
  }

  Future<bool> _validateEmail(String email) async {
    final url = Uri.parse('https://api.zerobounce.net/v2/validate?api_key=$zeroBounceApiKey&email=$email');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['status'] == 'valid'; // Return true if the email is valid
    } else {
      throw Exception("Failed to validate email");
    }
  }

  // Dispose controllers
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validate password with more constraints
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password cannot be empty';
    } else if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    } else if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    } else if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    } else if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Password must contain at least one digit';
    } else if (!RegExp(r'(?=.*[@$!%*?&])').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      // Validate the email before registration
      bool isValidEmail = await _validateEmail(_emailController.text.trim());
      if (!isValidEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Invalid email address")),
        );
        return;
      }

      if (_passwordController.text == _confirmPasswordController.text) {
        setState(() {
          _isLoading = true;
        });

        try {
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          User? user = userCredential.user;

          if (user != null) {
            // Navigate to LoginScreen after successful registration
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          }
        } on FirebaseAuthException catch (e) {
          String message;
          switch (e.code) {
            case 'email-already-in-use':
              message = "This email is already registered";
              break;
            case 'invalid-email':
              message = "The email address is not valid";
              break;
            default:
              message = "Registration failed: ${e.message}";
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Passwords do not match")),
        );
      }
    }
  }

  // Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Color(0xFFE2BF65).withOpacity(0.4),
            ),
          ),
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Color(0xFF61481C),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      "Hey there! 👋",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 10),
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
                        textAlign: TextAlign.center,
                      ),
                    )
                        : CircularProgressIndicator(),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        hintText: 'Email Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[300],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        hintText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[300],
                      ),
                      validator: _validatePassword,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: _toggleConfirmPasswordVisibility,
                        ),
                        hintText: 'Confirm Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[300],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty || value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    _isLoading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _register,
                      child: Text('Register'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Color(0xFFE2BF65),
                        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => LoginScreen()),
                        );
                      },
                      child: Text(
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

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }
}
