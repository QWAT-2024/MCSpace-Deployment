import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/firebase_recaptcha_verifier.dart';
import '../firebase_options.dart';

class SignupScreen extends StatefulWidget {
  static const String id = '/signup';
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _registrationNumberController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _officialMailIdController =
      TextEditingController();
  final TextEditingController _alternateNumberController =
      TextEditingController();
  final TextEditingController _alternateMailIdController =
      TextEditingController();
  final TextEditingController _preferredUserNameController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // State Variables
  bool _isLoading = false;
  String? _verificationId;
  bool _isOtpSent = false;
  bool _isPhoneVerified = false;
  PhoneAuthCredential? _phoneAuthCredential;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _companyNameController.dispose();
    _registrationNumberController.dispose();
    _locationController.dispose();
    _contactNameController.dispose();
    _contactNumberController.dispose();
    _officialMailIdController.dispose();
    _alternateNumberController.dispose();
    _alternateMailIdController.dispose();
    _preferredUserNameController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  TextStyle _timesNewRomanStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Times New Roman',
      fontFamilyFallback: const ['serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // --- Logic ---

  Future<void> _sendOtp() async {
    String rawNumber = _phoneNumberController.text.trim();
    if (rawNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Append +91 automatically
    String fullPhoneNumber = '+91$rawNumber';

    // Send OTP via In-App reCAPTCHA Modal ("Web Preview")
    try {
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
          setState(() {
            _verificationId = data['sessionInfo'];
            _isOtpSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OTP Sent Successfully")),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Error: ${data['error']['message'] ?? 'Unknown error'}",
              ),
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter the OTP.')));
      return;
    }
    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Verification ID missing.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create the credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      // We store it to link later after email signup
      setState(() {
        _phoneAuthCredential = credential;
        _isPhoneVerified = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP Verified! Click Sign Up to finish.')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please try again.')),
      );
    }
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      // Enforce phone verification before signup
      if (!_isPhoneVerified || _phoneAuthCredential == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify your phone number first.'),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // 1. Create User with Email
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _officialMailIdController.text.trim(),
              password: _passwordController.text.trim(),
            );

        // 2. Link Phone Number to this new account
        if (userCredential.user != null && _phoneAuthCredential != null) {
          await userCredential.user!.linkWithCredential(_phoneAuthCredential!);
        }

        // 3. Save Data to Firestore
        await _saveUserData(userCredential.user!.uid);

        // Store the active contact number in SharedPreferences for consistent access
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'activeContactNumber',
          '+91${_phoneNumberController.text.trim()}',
        );

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } on FirebaseAuthException catch (e) {
        String message = e.message ?? 'An error occurred.';
        if (e.code == 'credential-already-in-use') {
          message = 'This phone number is already linked to another account.';
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _saveUserData(String firebaseUid) async {
    // Use the Firebase Authentication UID as the document ID.
    // Store the contactNumber as a field within the document.
    final String contactNumber = '+91${_phoneNumberController.text.trim()}';

    await FirebaseFirestore.instance.collection('users').doc(firebaseUid).set({
      'companyName': _companyNameController.text.trim(),
      'registrationNumber': _registrationNumberController.text.trim(),
      'location': _locationController.text.trim(),
      'contactName': _contactNameController.text.trim(),
      'contactNumber': contactNumber, // Store the contact number as a field
      'officialMailId': _officialMailIdController.text.trim(),
      'alternateNumber': _alternateNumberController.text.trim(),
      'alternateMailId': _alternateMailIdController.text.trim(),
      'preferredUserName': _preferredUserNameController.text.trim(),
      'phoneNumber':
          contactNumber, // Store the consistent formatted phone number
      'createdAt': Timestamp.now(),
    });
  }

  // --- UI Helpers ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    bool isRequired = false, // Added flag
    TextInputType keyboardType = TextInputType.text,
    bool isObscure = false,
    String? prefixText, // Added for +91
    int? maxLength, // Added for phone restriction
    bool readOnly = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    const primaryColor = Color.fromARGB(255, 2, 24, 90);
    final borderStyle = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    // Construct label with asterisk if required
    final Widget labelWidget = RichText(
      text: TextSpan(
        text: labelText,
        style: _timesNewRomanStyle(color: Colors.grey[600], fontSize: 14),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isObscure,
      readOnly: readOnly,
      maxLength: maxLength,
      style: _timesNewRomanStyle(fontSize: 16),
      decoration: InputDecoration(
        label: labelWidget,
        prefixText: prefixText,
        prefixStyle: _timesNewRomanStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        suffixIcon: suffixIcon,
        border: borderStyle,
        enabledBorder: borderStyle,
        focusedBorder: borderStyle.copyWith(
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        counterText: "", // Hides the default character counter
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 2, 24, 90);

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
                  const SizedBox(height: 10),

                  // Image
                  Image.asset('assets/images/signup.png', height: 200),
                  const SizedBox(height: 20),

                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: _timesNewRomanStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Fields
                  _buildTextField(
                    controller: _companyNameController,
                    labelText: 'Company Name',
                    isRequired: true,
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter company name' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _registrationNumberController,
                    labelText: 'GST Number',
                    isRequired: true,
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter GST number' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _locationController,
                    labelText: 'Location',
                    isRequired: true,
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter location' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _contactNameController,
                    labelText: 'Contact Name',
                    isRequired: true,
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter contact name' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _contactNumberController,
                    labelText: 'Contact Number',
                    isRequired: true,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter contact number' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _officialMailIdController,
                    labelText: 'Official Mail ID',
                    isRequired: true,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please enter an email';
                      if (!v.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Optional Fields
                  _buildTextField(
                    controller: _alternateNumberController,
                    labelText: 'Alternate Number (Optional)',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _alternateMailIdController,
                    labelText: 'Alternate Mail ID (Optional)',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _preferredUserNameController,
                    labelText: 'Preferred User Name',
                    isRequired: true,
                    validator: (v) =>
                        v!.isEmpty ? 'Please choose a username' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    isRequired: true,
                    isObscure: _obscurePassword,
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
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please create a password';
                      if (v.length < 6)
                        return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),

                  // Phone Number Section
                  _buildTextField(
                    controller: _phoneNumberController,
                    labelText: 'Phone Number',
                    isRequired: true,
                    prefixText: '+91 ', // Default +91
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    // If OTP sent or Verified, disable editing the phone number
                    readOnly: _isOtpSent || _isPhoneVerified,
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please enter your phone number';
                      if (v.length != 10)
                        return 'Phone number must be 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Send OTP Button
                  if (!_isOtpSent && !_isPhoneVerified)
                    SizedBox(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Send OTP"),
                      ),
                    ),

                  // OTP Field and Verify Button
                  if (_isOtpSent && !_isPhoneVerified) ...[
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _otpController,
                      labelText: 'Enter OTP',
                      isRequired: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Please enter the OTP';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Verify OTP"),
                      ),
                    ),
                  ],

                  // Verified Indicator
                  if (_isPhoneVerified) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 10),
                          Text(
                            "Phone Number Verified",
                            style: _timesNewRomanStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Main Sign Up Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : Text(
                            'Sign Up',
                            style: _timesNewRomanStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
