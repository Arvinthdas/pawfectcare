import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Function to send password reset email
  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your email address.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to your email.')),
      );

      // Optionally, navigate back to the login screen after sending the reset email
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.message}")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7EFF1), // Light background color
      body: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Color(0xFFE2BF65).withOpacity(0.4),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: Color(0xFFE2BF65).withOpacity(0.4),
            ),
          ),
          Positioned(
            top: 50,
            left: -60,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF61481C),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -30,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFF61481C),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Replace the 'My APP Icon' text with your image
                  Image.asset(
                    'assets/images/Pawfectcare.png', // Path to your image
                    height: 300,           // Adjust height as needed
                    width: 300,            // Adjust width as needed
                  ),
                  SizedBox(height: 40),

                  // Email TextField with Send Password Reset Link button
                  TextField(
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
                  ),
                  SizedBox(height: 20),

                  // Send Password Reset Link Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFE2BF65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _sendPasswordResetEmail,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.black)
                          : Text(
                        'Send Reset Link',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
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
