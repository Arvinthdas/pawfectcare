import 'package:flutter/material.dart'; // Importing Flutter Material package for UI components.
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Authentication for managing user authentication.

class ForgotPasswordScreen extends StatefulWidget {
  // Defining a stateful widget for the forgot password screen.
  @override
  _ForgotPasswordScreenState createState() =>
      _ForgotPasswordScreenState(); // Creating the state for this widget.
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // State class for ForgotPasswordScreen.
  final FirebaseAuth _auth =
      FirebaseAuth.instance; // Creating an instance of FirebaseAuth.
  final TextEditingController _emailController =
      TextEditingController(); // Controller for the email input field.

  bool _isLoading = false; // Variable to track loading state for UI feedback.

  @override
  void dispose() {
    // Method to clean up controllers when the widget is removed from the tree.
    _emailController.dispose(); // Disposing the email controller.
    super.dispose(); // Calling the superclass dispose method.
  }

  // Function to send password reset email.
  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      // Check if the email field is empty.
      ScaffoldMessenger.of(context).showSnackBar(
        // Show a snack bar with a message.
        const SnackBar(
            content: Text(
                'Please enter your email address.')), // Prompt user to enter an email.
      );
      return; // Exit the function if the email is empty.
    }

    setState(() {
      // Update the UI to show loading state.
      _isLoading = true; // Set loading state to true.
    });

    try {
      await _auth.sendPasswordResetEmail(
          email: _emailController.text
              .trim()); // Sending the password reset email.
      ScaffoldMessenger.of(context).showSnackBar(
        // Show a success message.
        const SnackBar(
            content: Text(
                'Password reset link sent to your email.')), // Inform user that the email has been sent.
      );

      // Optionally, navigate back to the login screen after sending the reset email.
      Navigator.pop(context); // Navigate back to the previous screen.
    } on FirebaseAuthException catch (e) {
      // Catch any errors from FirebaseAuth.
      ScaffoldMessenger.of(context).showSnackBar(
        // Show an error message.
        SnackBar(
            content: Text("Error: ${e.message}")), // Display the error message.
      );
    } finally {
      // This block runs whether the try block succeeds or fails.
      setState(() {
        // Update the UI after the operation.
        _isLoading = false; // Reset loading state to false.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build method to render UI components.
    return Scaffold(
      // Scaffold widget provides a structure for the visual interface.
      backgroundColor:
          const Color(0xFFF7EFF1), // Light background color for the screen.
      body: Stack(
        // Stack allows overlapping of widgets.
        children: [
          // Decorative circles
          Positioned(
            // Positioning widget to place circles at specific locations.
            top: -50, // Distance from the top of the screen.
            right: -50, // Distance from the right of the screen.
            child: CircleAvatar(
              // Circular avatar widget for decoration.
              radius: 100, // Radius of the circle.
              backgroundColor: const Color(0xFFE2BF65)
                  .withOpacity(0.4), // Color with transparency.
            ),
          ),
          Positioned(
            // Another decorative circle.
            bottom: -80, // Distance from the bottom of the screen.
            left: -80, // Distance from the left of the screen.
            child: CircleAvatar(
              // Circular avatar widget for decoration.
              radius: 140, // Radius of the circle.
              backgroundColor: const Color(0xFFE2BF65)
                  .withOpacity(0.4), // Color with transparency.
            ),
          ),
          const Positioned(
            // Another decorative circle.
            top: 50, // Distance from the top of the screen.
            left: -60, // Distance from the left of the screen.
            child: CircleAvatar(
              // Circular avatar widget for decoration.
              radius: 50, // Radius of the circle.
              backgroundColor:
                  Color(0xFF61481C), // Darker color for the circle.
            ),
          ),
          const Positioned(
            // Another decorative circle.
            bottom: 100, // Distance from the bottom of the screen.
            right: -30, // Distance from the right of the screen.
            child: CircleAvatar(
              // Circular avatar widget for decoration.
              radius: 30, // Radius of the circle.
              backgroundColor:
                  Color(0xFF61481C), // Darker color for the circle.
            ),
          ),

          // Main content
          Center(
            // Center widget to align child widgets to the center of the screen.
            child: SingleChildScrollView(
              // Enables scrolling when content overflows.
              padding: const EdgeInsets.symmetric(
                  horizontal: 30), // Padding for the content.
              child: Column(
                // Column to arrange child widgets vertically.
                mainAxisAlignment:
                    MainAxisAlignment.center, // Centering column items.
                children: [

                  Image.asset(
                    'assets/images/Pawfectcare.png', // Path to the image.
                    height: 300, // Adjust height as needed.
                    width: 300, // Adjust width as needed.
                  ),
                  const SizedBox(height: 40), // Spacing before the email input field.

                  // Email TextField with Send Password Reset Link button.
                  TextField(
                    controller:
                        _emailController, // Assigning the email controller.
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email), // Icon for email input.
                      hintText:
                          'Email Address', // Placeholder text for the input.
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            10), // Rounded corners for the border.
                        borderSide: BorderSide.none, // No border side.
                      ),
                      filled: true, // Filling the background of the input.
                      fillColor: Colors.grey[
                          300], // Light grey background color for the input.
                    ),
                  ),
                  const SizedBox(height: 20), // Spacing before the reset link button.

                  // Send Password Reset Link Button
                  SizedBox(
                    width: double.infinity, // Full width for the button.
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFE2BF65), // Button background color.
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              10), // Rounded corners for the button.
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : _sendPasswordResetEmail, // Disable button if loading.
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors
                                  .black) // Show loading indicator if in progress.
                          : const Text(
                              'Send Reset Link', // Button text.
                              style: TextStyle(
                                color:
                                    Colors.black, // Text color for the button.
                                fontWeight: FontWeight.bold, // Bold text.
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
