import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// REMOVE: import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // No longer needed for session
import 'dart:async'; // Import async library for StreamSubscription

// Import your page files
import 'homepage.dart';
import 'register.dart';
import 'profile.dart';
import 'category.dart';
import 'daily_allowance.dart';
import 'set_goals.dart';
import 'goals_details_page.dart'; // Assuming you might need this route later
import 'balance.dart'; // Assuming you might need this route later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kndlnjiyetzggamqpydg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuZGxuaml5ZXR6Z2dhbXFweWRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMwNjc1NTIsImV4cCI6MjA1ODY0MzU1Mn0.M2K1kAOfLS1s5VF6d6EcsC-GNjFue37y7gG0FSCPpV4',
    // Supabase Flutter automatically handles session persistence using shared_preferences by default.
    // You can customize storage using `localStorage` parameter if needed, but default is usually fine.
  );

  runApp(BudgetApp());
}

// Get a reference to the Supabase client instance
final supabase = Supabase.instance.client;

class BudgetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FINLY Budget', // Updated title
      theme: ThemeData(
        // Optional: Define a base theme
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade900,
        // Add other theme properties as needed
      ),
      initialRoute: '/', // Start with AuthCheck
      routes: {
        '/': (context) => AuthCheck(),
        '/home': (context) => HomePage(),
        '/register': (context) => RegisterPage(),
        '/login': (context) => LoginPage(),
        '/profile': (context) => ProfilePage(),
        '/category_spending': (context) => CategoryListPage(),
        '/daily_allowance': (context) => DailyAllowancePage(),
        '/set_goals': (context) => SetGoalsPage(),
        // Add routes for BalancePage and GoalDetailsPage if needed directly
        // Example: '/balance': (context) => BalancePage(...), // Needs arguments
        // Example: '/goal_details': (context) => GoalDetailsPage(...), // Needs arguments
      },
    );
  }
}

// AuthCheck: Listens to Supabase auth state changes
class AuthCheck extends StatefulWidget {
  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  // Subscription to the auth state stream
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();

    // Listen to authentication state changes
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;

      // Ensure the widget is still mounted before navigating
      if (!mounted) return;

      if (session != null) {
        // User is signed in (or session restored), navigate to home
        print("AuthCheck: Session found, navigating to /home");
        // Use pushReplacementNamed to prevent going back to AuthCheck/Login
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // User is signed out (or no session found initially), navigate to login
        print("AuthCheck: No session found, navigating to /login");
        Navigator.pushReplacementNamed(context, '/login');
      }
    }, onError: (error) {
      // Handle potential errors in the stream
      print("AuthCheck: Error in auth stream: $error");
      if (mounted) {
        // Optionally show an error message or navigate to login on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Authentication error. Please login again.")),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    // Cancel the subscription when the widget is disposed to prevent memory leaks
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while waiting for the initial auth state
    return Scaffold(
      // Match background color for consistency
      backgroundColor: Colors.grey.shade900,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// LoginPage: Handles user login
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // REMOVE: final storage = FlutterSecureStorage(); // Not needed for session
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  // REMOVE: bool staySignedIn = false; // Persistence is automatic
  bool _obscureText = true; // Keep for password visibility toggle

  // Inside main.dart -> _LoginPageState class

  Future<void> signIn() async {
    // Check if the widget is still mounted before proceeding
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(), // Trim input
        password: passwordController.text.trim(), // Trim input
      );

      // --- ADD EXPLICIT NAVIGATION HERE ---
      // Check if login was successful (response.user is not null)
      // AND ensure the widget is still mounted before navigating.
      if (mounted && response.user != null) {
        print("Login successful in LoginPage, navigating to /home");
        // Explicitly navigate to the home page.
        // AuthCheck's listener might also trigger this, but pushReplacementNamed
        // handles replacing the current route gracefully.
        Navigator.pushReplacementNamed(context, '/home');
      }
      // Optional: Handle the unlikely case where signIn succeeds but user is null
      else if (mounted && response.user == null) {
        print("Login response user is null after successful call.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Login completed but user data is missing. Please try again.")),
        );
      }
      // --- END OF ADDED NAVIGATION ---

      // REMOVE: Manual session saving logic
      // if (staySignedIn) { ... }

      // REMOVE: Old explicit navigation comment - we added it back above
      // Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (error) {
      // Catch specific Supabase auth errors
      print("Login failed: ${error.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: ${error.message}")),
        );
      }
    } catch (error) {
      // Catch any other unexpected errors
      print("Login failed with unexpected error: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred during login.")),
        );
      }
    } finally {
      // Ensure loading state is reset only if the widget is still mounted
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is removed
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          // Use SingleChildScrollView to prevent overflow on smaller screens
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FINLY Title (unchanged)
                Stack(
                  children: [
                    Text(
                      "FINLY",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.white,
                      ),
                    ),
                    Positioned.fill(
                      child: Text(
                        "FINLY",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),
                // Email Field
                TextField(
                  controller: emailController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      )),
                  keyboardType: TextInputType.emailAddress, // Set keyboard type
                ),
                SizedBox(height: 10),
                // Password Field
                TextField(
                  controller: passwordController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: TextStyle(color: Colors.white),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    // Password visibility toggle
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureText,
                ),
                SizedBox(height: 10),
                // REMOVE: "Stay Signed In" Checkbox Row
                // Row(...)
                SizedBox(height: 20), // Adjusted spacing
                // Login Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    side: BorderSide(color: Colors.white),
                    padding: EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15), // Added padding
                  ),
                  // Disable button while loading
                  onPressed: isLoading ? null : signIn,
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text("Login",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16)), // Increased font size
                ),
                SizedBox(height: 10),
                // Register Button
                TextButton(
                  // Disable button while loading
                  onPressed: isLoading
                      ? null
                      : () {
                          // Use pushNamed for standard navigation, or pushReplacementNamed
                          // if you don't want users going back to Login from Register
                          Navigator.pushNamed(context, '/register');
                        },
                  child: Text(
                    "Not a user? Register",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
