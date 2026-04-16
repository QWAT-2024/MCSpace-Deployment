import 'dart:convert'; // Import for Base64 decoding
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_fonts/google_fonts.dart'; // Removed as we are using Times New Roman
import 'package:mc_space/screens/edit_profile_screen.dart';
import 'package:mc_space/screens/login_screen.dart';
import 'package:mc_space/widgets/custom_loading_indicator.dart';

class ProfileDetailsScreen extends StatefulWidget {
  static const String id = '/profile_details_screen';
  // Add an optional userId to the constructor
  final String? userId;
  const ProfileDetailsScreen({super.key, this.userId});

  @override
  _ProfileDetailsScreenState createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    // We now consistently use the Firebase Auth UID as the document ID.
    // The userId is passed from HomeScreen.
    final String? userIdToFetch =
        widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (userIdToFetch == null) {
      debugPrint(
        'Error: ProfileDetailsScreen received null userId and no current Firebase user.',
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userIdToFetch)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>?;
          });
        } else {
          debugPrint('Profile document not found for userId: $userIdToFetch');
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider? _buildProfileImage(String? imageString) {
    if (imageString == null || imageString.isEmpty) return null;
    if (imageString.startsWith('http')) {
      return NetworkImage(imageString);
    }
    try {
      return MemoryImage(base64Decode(imageString));
    } catch (e) {
      return null;
    }
  }

  // --- HELPER FOR TIMES NEW ROMAN FONT ---
  TextStyle _timesNewRomanStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Times New Roman',
      // Fallback to generic serif if Times New Roman isn't on the device
      fontFamilyFallback: const ['serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: CustomLoadingIndicator(),
      );
    }

    if (_userData == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('No profile data available.')),
      );
    }

    // --- CONSTANTS ---
    const primaryColor = Color.fromARGB(255, 2, 24, 90);
    final String companyName =
        _userData?['companyName'] ?? 'N/A'; // Null-safe access
    final String location = _userData?['location'] ?? 'N/A'; // Null-safe access
    final String? imageString =
        _userData?['profileImage'] as String?; // Null-safe access and cast

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // Removed AppBar completely
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- TOP HEADER SECTION (Custom Design) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60.0,
                bottom: 30.0,
              ), // Added top padding for status bar
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Profile Image Stack with Edit Button
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: _buildProfileImage(imageString),
                          child: imageString == null
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                      // The Pencil Icon Button
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              EditProfileScreen.id,
                              arguments: _userData,
                            );
                            if (result == true) {
                              _fetchUserProfile();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors
                                  .blue, // Bright color for the edit button
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                const BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),
                  Text(
                    companyName,
                    style: _timesNewRomanStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        location,
                        style: _timesNewRomanStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- DETAILS SECTIONS ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // 1. Basic Info Card
                  _buildInfoCard(
                    title: "Registration Info",
                    children: [
                      if ((_userData?['registrationNumber'] as String?)
                              ?.isNotEmpty ==
                          true) // Fully null-safe check
                        _buildProfileRow(
                          Icons.badge,
                          "GST Number (optional)",
                          _userData?['registrationNumber'] as String?,
                        ), // Null-safe access
                      _buildProfileRow(
                        Icons.person_outline,
                        "Preferred Name",
                        _userData?['preferredUserName'] as String?,
                      ), // Null-safe access
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Contact Info Card
                  _buildInfoCard(
                    title: "Contact Details",
                    children: [
                      _buildProfileRow(
                        Icons.person,
                        "Contact Person",
                        _userData?['contactName'] as String?,
                      ), // Null-safe access
                      _buildProfileRow(
                        Icons.phone,
                        "Phone Number",
                        _userData?['contactNumber'] as String?,
                      ), // Null-safe access
                      _buildProfileRow(
                        Icons.email_outlined,
                        "Official Email",
                        _userData?['officialMailId'] as String?,
                      ), // Null-safe access
                      if ((_userData?['alternateNumber'] as String?)
                              ?.isNotEmpty ==
                          true) // Fully null-safe check
                        _buildProfileRow(
                          Icons.phone_iphone,
                          "Alt. Number",
                          _userData?['alternateNumber'] as String?,
                        ), // Null-safe access
                      if ((_userData?['alternateMailId'] as String?)
                              ?.isNotEmpty ==
                          true) // Fully null-safe check
                        _buildProfileRow(
                          Icons.alternate_email,
                          "Alt. Email",
                          _userData?['alternateMailId'] as String?,
                        ), // Null-safe access
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 3. Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          LoginScreen.id,
                          (Route<dynamic> route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.shade100),
                        ),
                      ),
                      icon: const Icon(Icons.logout),
                      label: Text(
                        'Logout',
                        style: _timesNewRomanStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _timesNewRomanStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 2, 24, 90),
            ),
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: const Color.fromARGB(255, 2, 24, 90),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _timesNewRomanStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'N/A',
                  style: _timesNewRomanStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
