import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // For Base64 decoding (backward compatibility)
import 'dart:io'; // For File operations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
// import 'package:google_fonts/google_fonts.dart'; // Removed
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  static const String id = '/edit_profile_screen';
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _companyNameController;
  late TextEditingController _registrationNumberController;
  late TextEditingController _locationController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _officialMailIdController;
  late TextEditingController _alternateNumberController;
  late TextEditingController _alternateMailIdController;
  late TextEditingController _preferredUserNameController;
  
  String? _currentImageUrl; // Stores the current URL or Base64 string
  File? _newImageFile; // Stores the newly picked file
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController(text: widget.userData['companyName'] ?? '');
    _registrationNumberController = TextEditingController(text: widget.userData['registrationNumber'] ?? '');
    _locationController = TextEditingController(text: widget.userData['location'] ?? '');
    _contactNameController = TextEditingController(text: widget.userData['contactName'] ?? '');
    _contactNumberController = TextEditingController(text: widget.userData['contactNumber'] ?? '');
    _officialMailIdController = TextEditingController(text: widget.userData['officialMailId'] ?? '');
    _alternateNumberController = TextEditingController(text: widget.userData['alternateNumber'] ?? '');
    _alternateMailIdController = TextEditingController(text: widget.userData['alternateMailId'] ?? '');
    _preferredUserNameController = TextEditingController(text: widget.userData['preferredUserName'] ?? '');
    
    _currentImageUrl = widget.userData['profileImage'];
  }

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
    super.dispose();
  }

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

  // Helper to upload image to Firebase Storage
  Future<String?> _uploadImage(File imageFile, String userId) async {
    try {
      // Create a unique filename
      final String fileName = 'profile_images/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      // Upload file
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          String? profileImageUrl = _currentImageUrl;

          // If a new image was picked, upload it first
          if (_newImageFile != null) {
            String? uploadedUrl = await _uploadImage(_newImageFile!, currentUser.uid);
            if (uploadedUrl != null) {
              profileImageUrl = uploadedUrl;
            }
          }

          Map<String, dynamic> updateData = {
            'companyName': _companyNameController.text.trim(),
            'registrationNumber': _registrationNumberController.text.trim(),
            'location': _locationController.text.trim(),
            'contactName': _contactNameController.text.trim(),
            'contactNumber': _contactNumberController.text.trim(),
            'officialMailId': _officialMailIdController.text.trim(),
            'alternateNumber': _alternateNumberController.text.trim(),
            'alternateMailId': _alternateMailIdController.text.trim(),
            'preferredUserName': _preferredUserNameController.text.trim(),
            'profileImage': profileImageUrl, // Save the URL (or old Base64)
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update(updateData);
          
          if (mounted) {
            Navigator.pop(context, true); // Return success
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _newImageFile = File(pickedFile.path);
      });
    }
  }

  // Helper to display the image (New File > URL > Base64 > Placeholder)
  ImageProvider? _getProfileImage() {
    if (_newImageFile != null) {
      return FileImage(_newImageFile!);
    }
    if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      if (_currentImageUrl!.startsWith('http')) {
        return NetworkImage(_currentImageUrl!);
      }
      try {
        return MemoryImage(base64Decode(_currentImageUrl!));
      } catch (_) {}
    }
    return null;
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: _timesNewRomanStyle(
            color: Colors.grey[700], 
            fontWeight: FontWeight.w600, 
            fontSize: 14
          )
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: _timesNewRomanStyle(fontSize: 15), // Input text style
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _timesNewRomanStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: readOnly ? Colors.grey[200] : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color.fromARGB(255, 2, 24, 90)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 2, 24, 90);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: _timesNewRomanStyle(
            color: Colors.black, 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              // --- IMAGE PICKER ---
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey[100],
                        backgroundImage: _getProfileImage(),
                        child: (_newImageFile == null && (_currentImageUrl == null || _currentImageUrl!.isEmpty))
                            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- FORM FIELDS ---
              _buildTextField(
                controller: _companyNameController,
                label: 'Company Name',
                hint: 'Enter company name',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _registrationNumberController,
                label: 'GST Number',
                hint: 'Enter GST number',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _locationController,
                label: 'Location',
                hint: 'City, State',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _contactNameController,
                label: 'Contact Person',
                hint: 'Full Name',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _contactNumberController,
                label: 'Contact Number',
                hint: 'Mobile Number',
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              _buildTextField(
                controller: _officialMailIdController,
                label: 'Official Email',
                hint: 'email@company.com',
                keyboardType: TextInputType.emailAddress,
                readOnly: true, // Email usually shouldn't change without verification
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _alternateNumberController,
                      label: 'Alt. Number',
                      hint: 'Optional',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildTextField(
                      controller: _preferredUserNameController,
                      label: 'User Name',
                      hint: 'Username',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              _buildTextField(
                controller: _alternateMailIdController,
                label: 'Alt. Email',
                hint: 'Optional',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 20),

              // --- UPDATE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Save Changes',
                          style: _timesNewRomanStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}