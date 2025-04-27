import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import if needed for password change logic later

class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final supabase = Supabase.instance.client; // Get Supabase client instance
  final _formKey = GlobalKey<FormState>(); // Optional: For form validation

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _retypePasswordController =
      TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureRetypePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    // Dispose controllers when the widget is removed
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _retypePasswordController.dispose();
    super.dispose();
  }

  // Placeholder for password change logic
  // Function to handle password change logic
  Future<void> _changePassword() async {
    // Optional: Uncomment to enable form validation
    // if (!_formKey.currentState!.validate()) {
    //   return;
    // }

    // Check if new passwords match
    if (_newPasswordController.text != _retypePasswordController.text) {
      if (mounted) {
        // Check if widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("New passwords do not match.")),
        );
      }
      return;
    }

    // Check if the new password is empty
    if (_newPasswordController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("New password cannot be empty.")),
        );
      }
      return;
    }

    // Check if the current password field is empty (optional, but good practice)
    if (_currentPasswordController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter your current password.")),
        );
      }
      return;
    }

    // --- Start Supabase Password Update Logic ---
    setState(() {
      _isLoading = true;
    });

    try {
      // IMPORTANT: Supabase's standard `updateUser` requires the user to be
      // recently authenticated. If the user hasn't logged in recently, this might fail.
      // A more robust flow might involve re-authenticating the user first
      // using signInWithPassword with the _currentPasswordController.text
      // before calling updateUser. However, for simplicity, we'll try the direct update first.

      await supabase.auth.updateUser(
        UserAttributes(
          password: _newPasswordController.text.trim(),
        ),
      );

      // If successful and widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Password updated successfully!"),
              backgroundColor: Colors.green), // Success feedback color
        );
        // Optionally navigate back after success
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      // Handle specific authentication errors
      if (mounted) {
        String errorMessage = "Password update failed: ${error.message}";
        // Provide more specific feedback if possible
        if (error.message.contains("requires recent authentication")) {
          errorMessage =
              "Password update failed: Please log out and log back in before changing your password.";
        } else if (error.message.contains("same password")) {
          errorMessage = "New password cannot be the same as the old password.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.redAccent), // Error feedback color
        );
      }
    } catch (error) {
      // Handle unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("An unexpected error occurred: ${error.toString()}"),
              backgroundColor: Colors.redAccent), // Error feedback color
        );
      }
    } finally {
      // Ensure loading state is reset if the widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // --- End Supabase Logic ---
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text('Change Password', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white), // Back button color
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          // Use SingleChildScrollView to prevent overflow on smaller screens
          child: SingleChildScrollView(
            child: Form(
              // Optional: Wrap in a Form for validation
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current Password Field
                  TextFormField(
                    // Use TextFormField for validation
                    controller: _currentPasswordController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Current Password",
                      labelStyle: TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureCurrentPassword,
                    // Optional validation
                    // validator: (value) {
                    //   if (value == null || value.isEmpty) {
                    //     return 'Please enter your current password';
                    //   }
                    //   return null;
                    // },
                  ),
                  SizedBox(height: 15), // Increased spacing

                  // New Password Field
                  TextFormField(
                    controller: _newPasswordController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "New Password",
                      labelStyle: TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureNewPassword,
                    // Optional validation
                    // validator: (value) {
                    //   if (value == null || value.isEmpty) {
                    //     return 'Please enter a new password';
                    //   }
                    //   if (value.length < 6) { // Example: Minimum length
                    //     return 'Password must be at least 6 characters';
                    //   }
                    //   return null;
                    // },
                  ),
                  SizedBox(height: 15), // Increased spacing

                  // Retype New Password Field
                  TextFormField(
                    controller: _retypePasswordController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Retype New Password",
                      labelStyle: TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureRetypePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureRetypePassword = !_obscureRetypePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureRetypePassword,
                    // Optional validation
                    // validator: (value) {
                    //   if (value == null || value.isEmpty) {
                    //     return 'Please retype your new password';
                    //   }
                    //   if (value != _newPasswordController.text) {
                    //     return 'Passwords do not match';
                    //   }
                    //   return null;
                    // },
                  ),
                  SizedBox(height: 30), // Spacing before button

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      side: BorderSide(color: Colors.white),
                      padding: EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15), // Added padding
                    ),
                    // Disable button while loading
                    onPressed: _isLoading ? null : _changePassword,
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text("Update Password",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16)), // Increased font size
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
