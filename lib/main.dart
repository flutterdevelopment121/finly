import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage
import 'homepage.dart';
import 'register.dart';
import 'profile.dart';
import 'category.dart';
import 'daily_allowance.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kndlnjiyetzggamqpydg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtuZGxuaml5ZXR6Z2dhbXFweWRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMwNjc1NTIsImV4cCI6MjA1ODY0MzU1Mn0.M2K1kAOfLS1s5VF6d6EcsC-GNjFue37y7gG0FSCPpV4',
  );

  runApp(BudgetApp());
}

class BudgetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Budget Calculator',
      initialRoute: '/',
      routes: {
        '/': (context) => AuthCheck(), // Use AuthCheck as the initial route
        '/home': (context) => HomePage(),
        '/register': (context) => RegisterPage(),
        '/login': (context) => LoginPage(),
        '/profile': (context) => ProfilePage(),
        // Corrected to use CategoryListPage from category.dart
        '/category_spending': (context) => CategoryListPage(),
        '/daily_allowance': (context) => DailyAllowancePage(),
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final supabase = Supabase.instance.client;
  final storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    print("_checkAuth started");
    final String? token = await storage.read(key: 'supabase_session');
    print("token: $token");
    if (token != null) {
      print("token is not null");
      try {
        await supabase.auth.setSession(token);
        print("session set successfully");
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        print('Error restoring session: $e');
        await storage.delete(key: 'supabase_session');
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      print("token is null");
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final supabase = Supabase.instance.client;
  final storage = FlutterSecureStorage();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool staySignedIn = false;
  bool _obsecureText = true;

  Future<void> signIn() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      if (response.user != null) {
        if (staySignedIn) {
          // Store the session in secure storage
          await storage.write(
              key: 'supabase_session', value: response.session?.accessToken);
        }
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (error) {
      print("Login failed: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $error")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              ),
              SizedBox(height: 10),
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obsecureText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _obsecureText = !_obsecureText;
                      });
                    },
                  ),
                ),
                obscureText: _obsecureText,
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: staySignedIn,
                    onChanged: (bool? value) {
                      setState(() {
                        staySignedIn = value ?? false;
                      });
                    },
                    shape: CircleBorder(),
                    checkColor: Colors.black,
                    activeColor: Colors.white,
                  ),
                  Text(
                    "Stay Signed In",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  side: BorderSide(color: Colors.white),
                ),
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
                    : Text("Login", style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () {
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
    );
  }
}
