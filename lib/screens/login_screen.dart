import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'forgot_password_screen.dart';
import 'package:mc_space/main.dart';
import '../widgets/firebase_recaptcha_verifier.dart';
import '../firebase_options.dart';

class LoginScreen extends StatefulWidget {
  static const String id = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLLERS ---
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // --- STATE VARIABLES ---
  bool _isLoading = false;
  String? _verificationId;
  String? _phoneInputError; // Error text for phone input
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- STYLING ---
  TextStyle _timesNewRomanStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Times New Roman',
      fontFamilyFallback: const ['serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // --- HELPERS ---
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _timesNewRomanStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 2, 24, 90),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _navigateToAuthWrapper() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AuthWrapper.id,
      (route) => false,
    );
  }

  // ===========================
  // 1. EMAIL LOGIN LOGIC
  // ===========================
  Future<void> _loginWithEmail() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        if (mounted && userCredential.user != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();
          if (userDoc.exists) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            String? contactNumber = userData['contactNumber'];

            if (contactNumber != null && contactNumber.isNotEmpty) {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('activeContactNumber', contactNumber);
              _navigateToAuthWrapper();
            } else {
              _showSnackBar("Contact number not found for this user.");
              await FirebaseAuth.instance.signOut();
            }
          } else {
            _showSnackBar("User profile not found in database.");
            await FirebaseAuth.instance.signOut();
          }
        }
      } on FirebaseAuthException catch (e) {
        String message = 'An error occurred.';
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          message = 'Invalid email or password.';
        } else if (e.code == 'wrong-password') {
          message = 'Wrong password provided.';
        }
        _showSnackBar(message);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ===========================
  // 2. PHONE LOGIN & FIRESTORE LOGIC
  // ===========================

  void _showPhoneLoginSheet() {
    _phoneController.clear();
    _otpController.clear();
    _phoneInputError = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _verificationId == null ? 'Phone Login' : 'Enter OTP',
                    textAlign: TextAlign.center,
                    style: _timesNewRomanStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_verificationId == null) ...[
                    // --- STEP 1: PHONE INPUT (+91 Default) ---
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number, // Digits only
                      maxLength: 10, // Max 10 digits
                      style: _timesNewRomanStyle(fontSize: 16),
                      onChanged: (value) {
                        if (_phoneInputError != null) {
                          setSheetState(() => _phoneInputError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '81100...',
                        // Pre-filled visual prefix
                        prefixText: '+91 ',
                        prefixStyle: _timesNewRomanStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        counterText: "", // Hides the "0/10" counter
                        labelStyle: _timesNewRomanStyle(
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                        errorText: _phoneInputError,
                        errorStyle: _timesNewRomanStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await _verifyPhoneNumber(setSheetState);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 2, 24, 90),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Send OTP',
                              style: _timesNewRomanStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ] else ...[
                    // --- STEP 2: OTP INPUT ---
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: _timesNewRomanStyle(
                        fontSize: 16,
                        letterSpacing: 4,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: "",
                        labelText: '6-Digit Code',
                        labelStyle: _timesNewRomanStyle(
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await _signInWithOTP(setSheetState);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 2, 24, 90),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Verify & Login',
                              style: _timesNewRomanStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        _verificationId = null;
        _isLoading = false;
        _phoneInputError = null;
      });
    });
  }

  // A. Check Firestore for Number
  Future<bool> _isPhoneNumberRegisteredInFirestore(
    String fullPhoneNumber,
  ) async {
    try {
      // Remove spaces just in case, though TextInputType.number helps prevent them
      String cleanNumber = fullPhoneNumber.replaceAll(' ', '');
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('contactNumber', isEqualTo: cleanNumber)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking phone number in Firestore: $e");
      return false;
    }
  }

  // B. Logic: Verify Number
  Future<void> _verifyPhoneNumber(StateSetter setSheetState) async {
    FocusScope.of(context).unfocus(); // Close keyboard

    String rawInput = _phoneController.text.trim();

    // 1. Validation for 10 digits
    if (rawInput.isEmpty) {
      setSheetState(() => _phoneInputError = "Please enter a phone number");
      return;
    }
    if (rawInput.length != 10) {
      setSheetState(
        () => _phoneInputError = "Please enter a valid 10-digit number",
      );
      return;
    }

    // 2. CONSTRUCT FULL NUMBER (+91 + 10 digits)
    String fullPhoneNumber = "+91$rawInput";

    setSheetState(() => _isLoading = true);

    // 3. CHECK DATABASE FIRST
    bool isRegistered = await _isPhoneNumberRegisteredInFirestore(
      fullPhoneNumber,
    );

    if (!isRegistered) {
      setSheetState(() {
        _isLoading = false;
        _phoneInputError = "Number not registered"; // RED TEXT ERROR
      });
      return;
    }

    // 4. Send OTP via In-App reCAPTCHA Modal ("Web Preview")
    try {
      // This shows the reCAPTCHA challenge inside a modal dialog
      final token = await showDialog<String>(
        context: context,
        builder: (context) => FirebaseRecaptchaVerifierModal(
          firebaseConfig: {
            'apiKey': DefaultFirebaseOptions.web.apiKey,
            'authDomain': DefaultFirebaseOptions.web.authDomain!,
            'projectId': DefaultFirebaseOptions.web.projectId,
            'storageBucket': DefaultFirebaseOptions.web.storageBucket!,
            'messagingSenderId': DefaultFirebaseOptions.web.messagingSenderId,
            'appId': DefaultFirebaseOptions.web.appId,
          },
          onVerify: (token) => Navigator.pop(context, token),
        ),
      );

      if (token != null && token.isNotEmpty) {
        // CALL REST API TO SEND OTP
        final response = await http.post(
          Uri.parse(
            'https://www.googleapis.com/identitytoolkit/v3/relyingparty/sendVerificationCode?key=${DefaultFirebaseOptions.android.apiKey}',
          ),
          body: jsonEncode({
            'phoneNumber': fullPhoneNumber,
            'recaptchaToken': token,
          }),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          setSheetState(() {
            _verificationId = data['sessionInfo'];
            _isLoading = false;
            _phoneInputError = null;
          });
          _showSnackBar("OTP Sent Successfully");
        } else {
          setSheetState(() {
            _isLoading = false;
            _phoneInputError =
                "Error: ${data['error']['message'] ?? 'Unknown error'}";
          });
        }
      } else {
        setSheetState(() => _isLoading = false);
      }
    } catch (e) {
      setSheetState(() {
        _isLoading = false;
        _phoneInputError = "Error: ${e.toString()}";
      });
    }
  }

  // --- REMOVED _executePhoneVerification (Using REST API instead) ---

  // C. Sign in with OTP
  Future<void> _signInWithOTP(StateSetter setSheetState) async {
    FocusScope.of(context).unfocus();
    String otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSnackBar("Please enter a valid 6-digit OTP");
      return;
    }

    setSheetState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        await _checkFirestoreAndLogin(userCredential.user!, setSheetState);
      }
    } on FirebaseAuthException catch (e) {
      setSheetState(() => _isLoading = false);
      if (e.code == 'invalid-verification-code') {
        _showSnackBar("Incorrect OTP code.");
      } else {
        _showSnackBar(e.message ?? "Login Failed");
      }
    } catch (e) {
      setSheetState(() => _isLoading = false);
      _showSnackBar("Error: $e");
    }
  }

  // D. Final Database Login Check
  Future<void> _checkFirestoreAndLogin(
    User user,
    StateSetter setSheetState,
  ) async {
    try {
      // Reconstruct number locally to match format
      String rawInput = _phoneController.text.trim();
      String localFormattedNumber = "+91$rawInput";

      // If user object has phone (it should), use that, otherwise use local
      String phoneNumber = user.phoneNumber ?? localFormattedNumber;

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('contactNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('activeContactNumber', phoneNumber);

        if (mounted) {
          Navigator.pop(context);
          _navigateToAuthWrapper();
        }
      } else {
        setSheetState(() => _isLoading = false);
        _showSnackBar("Account verification failed (User mismatch).");
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setSheetState(() => _isLoading = false);
      _showSnackBar("Database Error: $e");
    }
  }

  // ===========================
  // 3. UI BUILD
  // ===========================
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 2, 24, 90);
    final OutlineInputBorder borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login Image
                  Image.asset(
                    'assets/images/login.png',
                    height: 250,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image, size: 100, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Title
                  Text(
                    'Login',
                    textAlign: TextAlign.center,
                    style: _timesNewRomanStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: _timesNewRomanStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: _timesNewRomanStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      border: borderStyle,
                      enabledBorder: borderStyle,
                      focusedBorder: borderStyle.copyWith(
                        borderSide: const BorderSide(
                          color: primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter your email';
                      if (!value.contains('@'))
                        return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: _timesNewRomanStyle(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: _timesNewRomanStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: borderStyle,
                      enabledBorder: borderStyle,
                      focusedBorder: borderStyle.copyWith(
                        borderSide: const BorderSide(
                          color: primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter your password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, ForgotPasswordScreen.id);
                      },
                      child: Text(
                        'Forgot Password?',
                        style: _timesNewRomanStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login Button (Email)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Login',
                            style: _timesNewRomanStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),

                  const SizedBox(height: 15),

                  // OR DIVIDER
                  Row(
                    children: [
                      const Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          "OR",
                          style: _timesNewRomanStyle(color: Colors.grey),
                        ),
                      ),
                      const Expanded(child: Divider(thickness: 1)),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // PHONE LOGIN BUTTON
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _showPhoneLoginSheet,
                    icon: const Icon(Icons.phone_android, color: primaryColor),
                    label: Text(
                      'Login with Phone',
                      style: _timesNewRomanStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
