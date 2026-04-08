import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // Removed

class WelcomeScreen extends StatelessWidget {
  static const String id = '/welcome';
  const WelcomeScreen({super.key});

  // --- HELPER FOR TIMES NEW ROMAN FONT ---
  TextStyle _timesNewRomanStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Times New Roman',
      fontFamilyFallback: const ['serif'], // Fallback for Android/iOS if font missing
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 2, 24, 90);

    return Scaffold(
      backgroundColor: Colors.white, // A clean white background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Spacer to push content from the top
              const Spacer(),

              // The illustration from your assets
              Image.asset(
                'assets/images/welcome.png',
                height: 300, // Adjust height as needed
              ),

              const SizedBox(height: 24),

              // "Hello" Title
              Text(
                'Hello',
                textAlign: TextAlign.center,
                style: _timesNewRomanStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 10),

              // Welcome Subtitle
              Text(
                'Welcome To Little Drop, where you manage your daily tasks',
                textAlign: TextAlign.center,
                style: _timesNewRomanStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              // Spacer to push buttons towards the bottom
              const Spacer(),

              // Login Button (Filled Style)
              ElevatedButton(
                onPressed: () {
                  // Routing for the Login screen
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Login',
                  style: _timesNewRomanStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Sign Up Button (Outlined Style)
              OutlinedButton(
                onPressed: () {
                  // Routing for the Sign Up screen
                  Navigator.pushNamed(context, '/signup');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor, width: 2),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Sign Up',
                  style: _timesNewRomanStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),

              // Bottom padding
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}