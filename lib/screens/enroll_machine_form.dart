import 'dart:async'; // REQUIRED FOR TIMER
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnrollMachineForm extends StatefulWidget {
  static const String id = '/enroll_machine';
  final String? machineId;
  final String? contactNumber;

  const EnrollMachineForm({super.key, this.machineId, this.contactNumber});

  @override
  State<EnrollMachineForm> createState() => _EnrollMachineFormState();
}

class _EnrollMachineFormState extends State<EnrollMachineForm> {
  // --- GEMINI CONFIGURATION ---
  GenerativeModel? _geminiModel;

  // --- VOICE STATE ---
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';
  bool _isProcessingVoice = false;

  // New Timer Variables
  Timer? _recordingTimer;
  int _remainingSeconds = 60; // 1 minute limit

  // --- FORM STATE VARIABLES ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _machineNameController = TextEditingController();
  final TextEditingController _modelYearController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ratePerHourController = TextEditingController();
  final TextEditingController _ratePerDayController = TextEditingController();
  final TextEditingController _machineSeriesController =
      TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _otherCategoryController =
      TextEditingController();

  String _companyName = '';
  String _companyLocation = '';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  List<String> _machinePhotoUrls = [];
  String? _companyLogoUrl;
  List<String> _completedJobPhotoUrls = [];

  final String _listingType = 'rent';
  final List<TextEditingController> _techSpecControllers = [];
  final List<TextEditingController> _rentalTermControllers = [];
  final List<TextEditingController> _jobsDoneControllers = [];

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _categories = [];

  String? _selectedGroupId;
  String? _selectedCategoryId;

  static const String _othersOptionId = 'others_option_selected';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initGemini();
    _fetchCompanyInfo();
    _fetchGroups();

    if (widget.machineId != null) {
      _loadMachineData(widget.machineId!);
    } else {
      _addTechSpecField();
      _addRentalTermField();
      _addJobsDoneField();
    }
  }

  void _initSpeech() {
    _speech = stt.SpeechToText();
  }

  Future<void> _initGemini() async {
    try {
      debugPrint("Checking for cached Gemini API key...");
      final prefs = await SharedPreferences.getInstance();
      final cachedKey = prefs.getString('cached_gemini_api_key');

      if (cachedKey != null && cachedKey.isNotEmpty) {
        debugPrint("Found cached API key. Initializing model...");
        _geminiModel = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: cachedKey,
        );
        debugPrint("Successfully initialized Gemini Model from cache.");
        return;
      }

      debugPrint("Started fetching Gemini API key from Firestore...");
      final doc = await FirebaseFirestore.instance.collection('Gemini').doc('API').get();
      if (doc.exists) {
        final encodedKey = doc.data()?['API_KEY'] as String?;
        if (encodedKey != null) {
          final decodedBytes = base64.decode(encodedKey);
          final decodedApiKey = utf8.decode(decodedBytes);

          // Save to local cache
          await prefs.setString('cached_gemini_api_key', decodedApiKey);
          debugPrint("Saved API key to local cache.");

          _geminiModel = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: decodedApiKey,
          );
          debugPrint("Successfully initialized Gemini Model from Firestore");
        } else {
          debugPrint("Failed to initialize Gemini Model: API_KEY is null");
        }
      } else {
        debugPrint("Failed to initialize Gemini Model: Document Gemini/API does not exist");
      }
    } catch (e, stacktrace) {
      debugPrint('Error fetching Gemini API key: $e');
      debugPrint('Stacktrace: $stacktrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize AI Assistant: ${e.toString().split(']').last}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel(); // Cancel timer on dispose
    _machineNameController.dispose();
    _modelYearController.dispose();
    _descriptionController.dispose();
    _ratePerHourController.dispose();
    _ratePerDayController.dispose();
    _machineSeriesController.dispose();
    _gstController.dispose();
    _otherCategoryController.dispose();
    for (var controller in _techSpecControllers) {
      controller.dispose();
    }
    for (var controller in _rentalTermControllers) {
      controller.dispose();
    }
    for (var controller in _jobsDoneControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- VOICE LOGIC START ---

  void _toggleRecording() {
    if (_isListening) {
      _stopListeningAndProcess();
    } else {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission needed')),
        );
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        // Optional: specific status handling
      },
      onError: (errorNotification) => debugPrint('onError: $errorNotification'),
    );

    if (available) {
      setState(() {
        _isListening = true;
        _lastWords = '';
        _remainingSeconds = 60; // Reset timer to 60s
      });

      // Start the UI Countdown Timer
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            // Time is up!
            _stopListeningAndProcess();
          }
        });
      });

      // Start Speech to Text
      _speech.listen(
        onResult: (result) {
          setState(() => _lastWords = result.recognizedWords);
        },
        listenFor: const Duration(seconds: 60), // Hard limit for the listener
        pauseFor: const Duration(
          seconds: 10,
        ), // Wait longer before auto-stopping on silence
        localeId: "en_IN",
        cancelOnError: true,
      );
    }
  }

  Future<void> _stopListeningAndProcess() async {
    _recordingTimer?.cancel(); // Stop the UI timer

    setState(() {
      _isListening = false;
      _isProcessingVoice = true;
    });

    await _speech.stop();

    if (_lastWords.isNotEmpty) {
      await _fillFormWithGemini(_lastWords);
    } else {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No voice detected.")));
    }

    setState(() => _isProcessingVoice = false);
  }

  // --- GEMINI LOGIC ---
  Future<void> _fillFormWithGemini(String userVoiceText) async {
    if (_geminiModel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI assistant is not ready yet. Please ensure your internet connection works or try again.')),
        );
      }
      return;
    }
    try {
      final prompt =
          '''
        You are an intelligent data extraction assistant for a construction equipment rental app.
        The user said: "$userVoiceText"
        Please extract the following information into a strictly valid JSON object. 
        Do not include markdown formatting (like ```json), just the raw JSON.
        
        Fields to extract:
        - machineName (String)
        - machineSeries (String)
        - modelYear (String: YYYY)
        - description (String)
        - ratePerHour (String: number only)
        - ratePerDay (String: number only)
        - gstNumber (String)
        - groupName (String: Best guess based on input)
        - categoryName (String: Best guess based on input)
        - jobsDone (Array of Strings: Past work experience mentions)

        If a field is not mentioned, exclude it from the JSON.
      ''';

      final content = [Content.text(prompt)];
      final response = await _geminiModel!.generateContent(content);

      String? responseText = response.text;
      if (responseText == null) throw Exception('Empty response from Gemini');

      responseText = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final Map<String, dynamic> data = jsonDecode(responseText);

      setState(() {
        if (data['machineName'] != null)
          _machineNameController.text = data['machineName'];
        if (data['machineSeries'] != null)
          _machineSeriesController.text = data['machineSeries'];
        if (data['modelYear'] != null)
          _modelYearController.text = data['modelYear'];
        if (data['description'] != null)
          _descriptionController.text = data['description'];
        if (data['gstNumber'] != null) _gstController.text = data['gstNumber'];

        if (data['ratePerHour'] != null)
          _ratePerHourController.text = data['ratePerHour'].toString();
        if (data['ratePerDay'] != null)
          _ratePerDayController.text = data['ratePerDay'].toString();

        if (data['jobsDone'] != null && (data['jobsDone'] as List).isNotEmpty) {
          if (_jobsDoneControllers.length == 1 &&
              _jobsDoneControllers[0].text.isEmpty) {
            _jobsDoneControllers.clear();
          }
          for (var job in data['jobsDone']) {
            _jobsDoneControllers.add(
              TextEditingController(text: job.toString()),
            );
          }
        }

        if (data['groupName'] != null || data['categoryName'] != null) {
          _selectedGroupId = _othersOptionId;
          _categories = [
            {'id': _othersOptionId, 'name': 'Others'},
          ];
          _selectedCategoryId = _othersOptionId;
          String combinedName = "";
          if (data['groupName'] != null)
            combinedName += "${data['groupName']} ";
          if (data['categoryName'] != null)
            combinedName += data['categoryName'];
          _otherCategoryController.text = combinedName.trim();
        }
      });

      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Form filled by AI!')));
    } catch (e) {
      debugPrint("Gemini Error: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not interpret voice data.')),
        );
    }
  }

  // --- DATA FETCHING (Unchanged) ---
  Future<void> _fetchCompanyInfo() async {
    final String? contactNumberToFetch = widget.contactNumber;
    User? currentUser = FirebaseAuth.instance.currentUser;
    QuerySnapshot? querySnapshot;
    DocumentSnapshot? userDocById;

    if (contactNumberToFetch != null) {
      querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('contactNumber', isEqualTo: contactNumberToFetch)
          .limit(1)
          .get();
    } else if (currentUser != null) {
      userDocById = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
    }

    if (mounted) {
      try {
        Map<String, dynamic>? userData;
        if (querySnapshot != null && querySnapshot.docs.isNotEmpty) {
          userData = querySnapshot.docs.first.data() as Map<String, dynamic>?;
        } else if (userDocById != null && userDocById.exists) {
          userData = userDocById.data() as Map<String, dynamic>?;
        }

        if (userData != null) {
          setState(() {
            _companyName = userData!['companyName'] ?? 'N/A';
            _companyLocation = userData['location'] ?? 'N/A';
          });
        }
      } catch (e) {
        debugPrint('Error fetching company info: $e');
      }
    }
  }

  Future<void> _fetchGroups() async {
    try {
      QuerySnapshot groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .get();
      if (mounted) {
        setState(() {
          _groups = groupSnapshot.docs
              .map(
                (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
              )
              .toList();
          _groups.add({'id': _othersOptionId, 'groupName': 'Others'});
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching groups: ${e.toString()}')),
        );
    }
  }

  Future<void> _fetchCategories(String groupId) async {
    if (groupId == _othersOptionId) {
      setState(() {
        _categories = [
          {'id': _othersOptionId, 'name': 'Others'},
        ];
        _selectedCategoryId = _othersOptionId;
      });
      return;
    }

    try {
      QuerySnapshot categorySnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .where('groupId', isEqualTo: groupId)
          .get();
      if (mounted) {
        setState(() {
          _categories = categorySnapshot.docs
              .map(
                (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
              )
              .toList();
          _categories.add({'id': _othersOptionId, 'name': 'Others'});
          _selectedCategoryId = null;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching categories: ${e.toString()}')),
        );
    }
  }

  Future<void> _loadMachineData(String machineId) async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot machineDoc = await FirebaseFirestore.instance
          .collection('machines')
          .doc(machineId)
          .get();
      if (mounted && machineDoc.exists) {
        var data = machineDoc.data() as Map<String, dynamic>;
        _machineNameController.text = data['name'] ?? '';
        _modelYearController.text = data['modelYear'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _ratePerHourController.text = (data['ratePerHour'] ?? '').toString();
        _ratePerDayController.text = (data['ratePerDay'] ?? '').toString();
        _machineSeriesController.text = data['machineSeries'] ?? '';
        _gstController.text = data['gst'] ?? '';

        _machinePhotoUrls = List<String>.from(data['machinePhotos'] ?? []);
        _companyLogoUrl = data['companyLogo'];
        _completedJobPhotoUrls = List<String>.from(
          data['completedJobPhotos'] ?? [],
        );

        _techSpecControllers.clear();
        for (var spec in (data['technicalSpecifications'] as List? ?? [])) {
          _techSpecControllers.add(TextEditingController(text: spec));
        }
        if (_techSpecControllers.isEmpty) _addTechSpecField();

        _rentalTermControllers.clear();
        for (var term in (data['rentalTerms'] as List? ?? [])) {
          _rentalTermControllers.add(TextEditingController(text: term));
        }
        if (_rentalTermControllers.isEmpty) _addRentalTermField();

        _jobsDoneControllers.clear();
        for (var job in (data['jobsDone'] as List? ?? [])) {
          _jobsDoneControllers.add(TextEditingController(text: job));
        }
        if (_jobsDoneControllers.isEmpty) _addJobsDoneField();

        _selectedGroupId = data['groupId'];
        _selectedCategoryId = data['categoryId'];

        if (data['customCategoryName'] != null) {
          _selectedCategoryId = _othersOptionId;
          _otherCategoryController.text = data['customCategoryName'];
        }

        if (_selectedGroupId != null && _selectedGroupId != _othersOptionId) {
          await _fetchCategories(_selectedGroupId!);
        } else if (_selectedGroupId == _othersOptionId) {
          _categories = [
            {'id': _othersOptionId, 'name': 'Others'},
          ];
          _selectedCategoryId = _othersOptionId;
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading machine data: ${e.toString()}'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DYNAMIC FIELDS ---
  void _addTechSpecField() =>
      setState(() => _techSpecControllers.add(TextEditingController()));
  void _removeTechSpecField(int index) => setState(() {
    _techSpecControllers[index].dispose();
    _techSpecControllers.removeAt(index);
  });
  void _addRentalTermField() =>
      setState(() => _rentalTermControllers.add(TextEditingController()));
  void _removeRentalTermField(int index) => setState(() {
    _rentalTermControllers[index].dispose();
    _rentalTermControllers.removeAt(index);
  });
  void _addJobsDoneField() =>
      setState(() => _jobsDoneControllers.add(TextEditingController()));
  void _removeJobsDoneField(int index) => setState(() {
    _jobsDoneControllers[index].dispose();
    _jobsDoneControllers.removeAt(index);
  });

  // --- UPLOAD ---
  Future<String?> _uploadFile(XFile file, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
      final storageRef = FirebaseStorage.instance.ref().child(
        '$folder/$fileName',
      );
      final uploadTask = await storageRef.putFile(File(file.path));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File upload failed: $e')));
      return null;
    }
  }

  Future<void> _pickAndUploadImage(
    ImageSource source,
    void Function(String) onUploadComplete,
  ) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      String? downloadUrl = await _uploadFile(pickedFile, 'machine_images');
      if (downloadUrl != null) onUploadComplete(downloadUrl);
      setState(() => _isLoading = false);
    }
  }

  // --- SUBMIT ---
  Future<void> _listEquipment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final machineData = {
        'userId': user.uid,
        'name': _machineNameController.text.trim(),
        'modelYear': _modelYearController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _companyLocation,
        'listingType': _listingType,
        'technicalSpecifications': _techSpecControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'rentalTerms': _rentalTermControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'jobsDone': _jobsDoneControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),

        'groupId': _selectedGroupId,
        'categoryId': _selectedCategoryId,
        'customCategoryName': _selectedCategoryId == _othersOptionId
            ? _otherCategoryController.text.trim()
            : null,

        'machineSeries': _machineSeriesController.text.trim(),
        'gst': _gstController.text.trim(),
        'companyName': _companyName,
        'address': _companyLocation,
        'updatedAt': FieldValue.serverTimestamp(),
        'machinePhotos': _machinePhotoUrls,
        'companyLogo': _companyLogoUrl,
        'completedJobPhotos': _completedJobPhotoUrls,
        'ratePerHour': _ratePerHourController.text.trim().isEmpty
            ? null
            : double.tryParse(_ratePerHourController.text.trim()),
        'ratePerDay': _ratePerDayController.text.trim().isEmpty
            ? null
            : double.tryParse(_ratePerDayController.text.trim()),
      };

      if (widget.machineId == null) {
        machineData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('machines')
            .add(machineData);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment listed successfully!')),
          );
      } else {
        await FirebaseFirestore.instance
            .collection('machines')
            .doc(widget.machineId)
            .update(machineData);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Equipment updated successfully!')),
          );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0095D8);
    const appThemeColor = Color.fromARGB(255, 2, 24, 90);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: appThemeColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.machineId == null ? 'List your equipment' : 'Edit Equipment',
          style: _timesNewRomanStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 12.0,
            bottom: 16.0 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- TOGGLE MIC BUTTON ---
              GestureDetector(
                onTap: _isProcessingVoice ? null : _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.redAccent
                        : Colors.blueGrey[50],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _isListening
                          ? Colors.red
                          : Colors.blueGrey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isListening
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none,
                        color: _isListening ? Colors.white : Colors.blueGrey,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isListening
                            ? "Stop Recording ($_remainingSeconds s)" // Show Timer
                            : "Start Voice Form Fill (1 min limit)",
                        style: _timesNewRomanStyle(
                          color: _isListening ? Colors.white : Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- MAIN SUBMIT BUTTON ---
              ElevatedButton(
                onPressed: _isLoading || _isProcessingVoice || _isListening
                    ? null
                    : _listEquipment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appThemeColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.machineId == null
                            ? 'List Equipment'
                            : 'Save Changes',
                        style: _timesNewRomanStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),

      body: AbsorbPointer(
        absorbing: _isLoading || _isProcessingVoice || _isListening,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading || _isProcessingVoice)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(
                            _isProcessingVoice
                                ? "Gemini is filling the form..."
                                : "Processing...",
                            style: _timesNewRomanStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                _buildReadOnlyField(label: 'Company Name', value: _companyName),
                _buildReadOnlyField(label: 'Location', value: _companyLocation),

                _buildSectionHeader('Group & Category'),

                _buildDropdownField(
                  label: 'Select Group',
                  value: _selectedGroupId,
                  items: _groups
                      .map<DropdownMenuItem<String>>(
                        (group) => DropdownMenuItem<String>(
                          value: group['id'],
                          child: Text(
                            group['groupName'],
                            style: _timesNewRomanStyle(fontSize: 16),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedGroupId = val;
                      if (val != _othersOptionId) {
                        _fetchCategories(val!);
                      } else {
                        _categories = [
                          {'id': _othersOptionId, 'name': 'Others'},
                        ];
                        _selectedCategoryId = _othersOptionId;
                      }
                    });
                  },
                  validator: (v) => v == null ? 'Please select a group' : null,
                ),

                _buildDropdownField(
                  label: 'Select Category',
                  value: _selectedCategoryId,
                  items: _categories
                      .map<DropdownMenuItem<String>>(
                        (cat) => DropdownMenuItem<String>(
                          value: cat['id'],
                          child: Text(
                            cat['name'],
                            style: _timesNewRomanStyle(fontSize: 16),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() {
                    _selectedCategoryId = val;
                    if (val != _othersOptionId)
                      _otherCategoryController.clear();
                  }),
                  validator: (v) =>
                      v == null ? 'Please select a category' : null,
                  enabled: _selectedGroupId != null && _categories.isNotEmpty,
                ),

                if (_selectedCategoryId == _othersOptionId)
                  _buildTextField(
                    controller: _otherCategoryController,
                    label: 'Enter Category Name',
                    hint: 'e.g., All Terrain Crane',
                    validator: (v) =>
                        v!.isEmpty ? 'Please enter a category name' : null,
                  ),

                _buildSectionHeader('Machine Details'),
                _buildTextField(
                  controller: _machineNameController,
                  label: 'Machine Name',
                  hint: 'e.g., Excavator EX-200',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                _buildTextField(
                  controller: _machineSeriesController,
                  label: 'Machine Series',
                  hint: 'e.g., 320D',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                _buildTextField(
                  controller: _gstController,
                  label: 'GST Number (optional)',
                  hint: 'e.g., 22AAAAA0000A1Z5',
                ),
                _buildTextField(
                  controller: _modelYearController,
                  label: 'Model Year',
                  hint: 'e.g., 2022',
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),

                _buildSectionHeader('Jobs Done'),
                ..._jobsDoneControllers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: entry.value,
                            label: 'Job ${entry.key + 1}',
                            hint: 'e.g., Completed 150 hours of excavation',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeJobsDoneField(entry.key),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, color: primaryColor),
                    label: Text(
                      'Add Job Description',
                      style: _timesNewRomanStyle(
                        color: primaryColor,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _addJobsDoneField,
                  ),
                ),

                _buildTextArea(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Provide a detailed description of the machine',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),

                _buildSectionHeader('Rental Rates'),
                _buildTextField(
                  controller: _ratePerHourController,
                  label: 'Rate per Hour (optional)',
                  hint: '₹ 150',
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  controller: _ratePerDayController,
                  label: 'Rate per Day (optional)',
                  hint: '₹ 1200',
                  keyboardType: TextInputType.number,
                ),

                _buildSectionHeader('Technical Specifications'),
                ..._techSpecControllers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: entry.value,
                            label: 'Specification ${entry.key + 1}',
                            hint: 'e.g., Engine Power: 150 HP',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeTechSpecField(entry.key),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, color: primaryColor),
                    label: Text(
                      'Add Specification',
                      style: _timesNewRomanStyle(
                        color: primaryColor,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _addTechSpecField,
                  ),
                ),

                _buildSectionHeader('Rental Terms'),
                ..._rentalTermControllers.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: entry.value,
                            label: 'Term ${entry.key + 1}',
                            hint: 'e.g., Minimum rental: 4 hours',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeRentalTermField(entry.key),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, color: primaryColor),
                    label: Text(
                      'Add Rental Term',
                      style: _timesNewRomanStyle(
                        color: primaryColor,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _addRentalTermField,
                  ),
                ),

                _buildSectionHeader('Machine Photos'),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _machinePhotoUrls
                      .map(
                        (url) => Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                _buildPhotoUploader(
                  icon: Icons.camera_alt_outlined,
                  title: 'Add Machine Photos',
                  subtitle: 'Upload your machine photos',
                  onTap: () => _pickAndUploadImage(
                    ImageSource.gallery,
                    (url) => setState(() => _machinePhotoUrls.add(url)),
                  ),
                ),

                _buildSectionHeader('Company Logo'),
                if (_companyLogoUrl != null)
                  Image.network(_companyLogoUrl!, height: 100),
                const SizedBox(height: 10),
                _buildPhotoUploader(
                  icon: Icons.business_outlined,
                  title: 'Upload Company Logo',
                  subtitle: 'Your company logo for display',
                  onTap: () => _pickAndUploadImage(
                    ImageSource.gallery,
                    (url) => setState(() => _companyLogoUrl = url),
                  ),
                ),

                _buildSectionHeader('Completed Job Photos'),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _completedJobPhotoUrls
                      .map(
                        (url) => Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                _buildPhotoUploader(
                  icon: Icons.work_history_outlined,
                  title: 'Add Completed Job Photos',
                  subtitle: 'Photos of past work',
                  onTap: () => _pickAndUploadImage(
                    ImageSource.gallery,
                    (url) => setState(() => _completedJobPhotoUrls.add(url)),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
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

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
    child: Text(
      title,
      style: _timesNewRomanStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildReadOnlyField({required String label, required String value}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _timesNewRomanStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: _timesNewRomanStyle(fontSize: 16, color: Colors.grey[800]),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );

  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: _timesNewRomanStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: _timesNewRomanStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _timesNewRomanStyle(color: Colors.grey[400], fontSize: 14),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        validator: validator,
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildTextArea({
    required String label,
    required String hint,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: _timesNewRomanStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        minLines: 3,
        maxLines: 5,
        style: _timesNewRomanStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _timesNewRomanStyle(color: Colors.grey[400], fontSize: 14),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        validator: validator,
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
    bool enabled = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: _timesNewRomanStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        style: _timesNewRomanStyle(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          filled: true,
          fillColor: enabled ? Colors.grey[100] : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        validator: validator,
        isExpanded: true,
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildPhotoUploader({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const primaryColor = Color(0xFF0095D8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: primaryColor, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              style: _timesNewRomanStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: _timesNewRomanStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
