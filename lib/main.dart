import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';
// Import shared_preferences
// Import cloud_firestore

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/enroll_machine_form.dart';
import 'screens/find_machine_screen.dart';
import 'screens/machine_details_screen.dart';
import 'screens/profile_details_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'widgets/custom_loading_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // await FirebaseAppCheck.instance.activate(
  //   // For testing purposes, use AndroidProvider.debug to bypass Play Integrity checks
  //   // Remember to switch back to AndroidProvider.playIntegrity for production builds.
  //   androidProvider: AndroidProvider.debug,
  // );

  // Restrict app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MC space',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Times New Roman', // Set Times New Roman directly
      ),
      // 1. Set the initial route to our new AuthWrapper's ID.
      initialRoute: AuthWrapper.id,
      // 2. The 'home' property has been REMOVED completely.
      // 3. The routes map now handles all navigation.
      routes: {
        AuthWrapper.id: (context) => const AuthWrapper(),
        HomeScreen.id: (context) => const HomeScreen(),
        WelcomeScreen.id: (context) => const WelcomeScreen(),
        LoginScreen.id: (context) => const LoginScreen(),
        ForgotPasswordScreen.id: (context) => const ForgotPasswordScreen(),
        SignupScreen.id: (context) => const SignupScreen(),
        EnrollMachineForm.id: (context) => const EnrollMachineForm(),
        FindMachineScreen.id: (context) => const FindMachineScreen(),
        MachineDetailsScreen.id: (context) => const MachineDetailsScreen(),
        ProfileDetailsScreen.id: (context) => ProfileDetailsScreen(),
        EditProfileScreen.id: (context) => EditProfileScreen(
          userData:
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>,
        ),
      },
    );
  }
}

/// A wrapper widget that listens to Firebase auth state and shows the
/// correct screen based on whether the user is logged in or not.
class AuthWrapper extends StatefulWidget {
  // The route name for this wrapper.
  static const String id = '/';
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // We no longer need to store _futureContactNumber here directly,
  // as we'll pass the Firebase UID to HomeScreen immediately.

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, firebaseSnapshot) {
        if (firebaseSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: CustomLoadingIndicator());
        }

        if (firebaseSnapshot.hasData) {
          final User? firebaseUser = firebaseSnapshot.data;
          if (firebaseUser != null) {
            // Pass the Firebase UID directly to HomeScreen
            return HomeScreen(initialUserId: firebaseUser.uid);
          } else {
            // Should not happen if firebaseSnapshot.hasData is true, but for safety
            return const WelcomeScreen();
          }
        }
        return const WelcomeScreen();
      },
    );
  }
}
