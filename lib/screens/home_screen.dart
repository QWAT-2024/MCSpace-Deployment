import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for number formatting
import 'package:carousel_slider/carousel_slider.dart'; // Import for the carousel
import 'package:firebase_storage/firebase_storage.dart'; // Import for Firebase Storage

// Assuming your screen files are in a 'screens' directory
import 'package:mc_space/screens/category_machines_screen.dart';
import 'package:mc_space/screens/profile_details_screen.dart';
import 'package:mc_space/screens/enroll_machine_form.dart';
import 'package:mc_space/screens/find_machine_screen.dart';
import 'package:mc_space/screens/welcome_screen.dart';
import 'package:mc_space/screens/machine_details_screen.dart';
import 'package:mc_space/widgets/custom_loading_indicator.dart';
import 'package:mc_space/screens/enrolled_machines_screen.dart'; // Import EnrolledMachinesScreen

// Assuming your custom widget is in a 'widgets' directory
import 'package:mc_space/widgets/custom_bottom_navigation_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- HELPER CLASSES ---
class MachineWithRating {
  final QueryDocumentSnapshot machineDoc;
  final double averageRating;

  MachineWithRating({required this.machineDoc, required this.averageRating});
}

class _CategoryStyle {
  final Color backgroundColor;
  final Color iconColor;

  _CategoryStyle({required this.backgroundColor, required this.iconColor});
}

// Helper function to parse hex colors
Color _getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";
  }
  try {
    return Color(int.parse(hexColor, radix: 16));
  } catch (e) {
    return Colors.grey.shade200;
  }
}

// --- HomeScreen (Main Page Frame) ---
class HomeScreen extends StatefulWidget {
  static const String id = '/home';
  // Now accepts initialUserId, which is the Firebase UID
  final String? initialUserId;
  const HomeScreen({super.key, this.initialUserId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // _widgetOptions will now be created dynamically based on initialUserId
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      _HomeContent(
        userId: widget.initialUserId,
        onProfileTap: () => _onItemTapped(3),
      ), // Home
      EnrolledMachinesScreen(
        userId: widget.initialUserId,
      ), // My Space (Enrolled Machines)
      const Center(
        child: Text(
          'Messages Page',
          style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
        ),
      ), // Messages
      ProfileDetailsScreen(userId: widget.initialUserId), // Profile
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      // UPDATED: Used IndexedStack to preserve the state of each tab.
      // This prevents the AdvertisementCarousel from refetching images on navigation.
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: const Color.fromARGB(255, 2, 24, 90),
        onPressed: () async {
          // Mark as async
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            // Fetch contactNumber from Firestore for the current user
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            String? contactNumber;
            if (userDoc.exists) {
              contactNumber = (userDoc.data())?['contactNumber'];
            }

            Navigator.pushNamed(
              context,
              EnrollMachineForm.id,
              arguments: contactNumber, // Pass the fetched contactNumber
            );
          } else {
            Navigator.pushNamed(context, WelcomeScreen.id);
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

// --- _HomeContent (The main UI) ---
class _HomeContent extends StatefulWidget {
  // Now accepts userId, which is the Firebase UID
  final String? userId;
  final VoidCallback? onProfileTap;
  const _HomeContent({super.key, this.userId, this.onProfileTap});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _selectedLocation; // Locally overridden location

  final List<_CategoryStyle> _fallbackStyles = [
    _CategoryStyle(
      backgroundColor: const Color(0xFFFFF0E5),
      iconColor: const Color(0xFFF96937),
    ),
    _CategoryStyle(
      backgroundColor: const Color(0xFFE3F9E5),
      iconColor: const Color(0xFF34C759),
    ),
    _CategoryStyle(
      backgroundColor: const Color(0xFFE4F2FF),
      iconColor: const Color(0xFF007AFF),
    ),
    _CategoryStyle(
      backgroundColor: const Color(0xFFF5EEFF),
      iconColor: const Color(0xFFAF52DE),
    ),
    _CategoryStyle(
      backgroundColor: const Color(0xFFFFF8E1),
      iconColor: const Color(0xFFFFC107),
    ),
    _CategoryStyle(
      backgroundColor: const Color(0xFFFFEBEE),
      iconColor: const Color(0xFFE53935),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    // Use widget.userId (Firebase UID) to fetch the user document directly
    final String? userIdToFetch = widget.userId;

    if (userIdToFetch != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userIdToFetch)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          setState(() => _userData = userDoc.data() as Map<String, dynamic>);
        }
        setState(() => _isLoading = false);
      }
    } else {
      // If no userId is provided (should ideally not happen if AuthWrapper works),
      // consider showing an error or redirecting.
      debugPrint('Error: _HomeContent received null userId.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<MachineWithRating>> _fetchAndProcessPopularMachines(String? locationFilter) async {
    List<MachineWithRating> topMachines = [];
    final machinesSnapshot = await FirebaseFirestore.instance
        .collection('machines')
        .limit(20) // Removed limit of 5 to allow client-side filtering to find 5 valid ones
        .get();

    for (final machineDoc in machinesSnapshot.docs) {
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('machineId', isEqualTo: machineDoc.id)
          .get();

      double averageRating = 0.0;
      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0.0;
        for (final reviewDoc in reviewsSnapshot.docs) {
          totalRating += (reviewDoc.data()['rating'] ?? 0.0).toDouble();
        }
        averageRating = totalRating / reviewsSnapshot.docs.length;
      }

      // Apply location filter before adding to list
      if (locationFilter != null && locationFilter.trim().isNotEmpty) {
        String docLocation = (machineDoc.data() as Map<String, dynamic>)['location']?.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
        String filterLoc = locationFilter.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        if (!docLocation.contains(filterLoc)) {
          continue; // Skip this machine if it doesn't match the location
        }
      }

      topMachines.add(
        MachineWithRating(machineDoc: machineDoc, averageRating: averageRating),
      );
    }

    topMachines.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    // Limit to top 5 after sorting
    return topMachines.take(5).toList();
  }

  IconData _getIconForCategory(String categoryName) {
    switch (categoryName) {
      case 'Forming Machines':
        return Icons.construction;
      case 'Material Removal Machines':
        return Icons.handyman;
      case 'CNC & Automation':
        return Icons.precision_manufacturing;
      case 'Joining Machines':
        return Icons.bolt;
      case 'Cutting Machines':
        return Icons.content_cut;
      case 'Miscellaneous':
        return Icons.settings;
      default:
        return Icons.category;
    }
  }

  // --- UPDATED HELPER: BUILD PROFILE IMAGE ---
  ImageProvider? _buildProfileImage(String? imageString) {
    if (imageString == null || imageString.isEmpty) {
      return null;
    }

    // Check if it's a URL (Firebase Storage)
    if (imageString.startsWith('http')) {
      return NetworkImage(imageString);
    }

    // Assume Base64
    try {
      return MemoryImage(base64Decode(imageString));
    } catch (e) {
      return null; // Fallback if decoding fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: _buildHeader(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                final isUserLoggedIn =
                    FirebaseAuth.instance.currentUser != null;
                if (isUserLoggedIn && widget.onProfileTap != null) {
                  widget.onProfileTap!();
                } else {
                  Navigator.pushNamed(context, WelcomeScreen.id);
                }
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey[200],
                // UPDATED: Uses the helper method to handle URL or Base64
                backgroundImage: _isLoading || _userData == null
                    ? null
                    : _buildProfileImage(_userData!['profileImage']),
                child:
                    _isLoading ||
                        (_userData != null &&
                            _userData!['profileImage'] != null)
                    ? null
                    : Icon(Icons.person, color: Colors.grey[800]),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: _buildSearchBar(),
          ),
        ),
      ),
      body: _isLoading
          ? const CustomLoadingIndicator()
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchUserProfile(); // Ensure profile is refreshed too
                setState(() {});
              },
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const AdvertisementCarousel(),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            title: 'Categories',
                            onTap: () {
                              final isUserLoggedIn =
                                  FirebaseAuth.instance.currentUser != null;
                              Navigator.pushNamed(
                                context,
                                isUserLoggedIn
                                    ? FindMachineScreen.id
                                    : WelcomeScreen.id,
                                arguments: {'location': _selectedLocation ?? _userData?['location']},
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildCategoriesList(),
                          const SizedBox(height: 15),
                          _buildActionButtons(context),
                          const SizedBox(height: 20),
                          _buildSectionTitle(title: 'Popular Rentals'),
                          const SizedBox(height: 20),
                          _buildPopularRentalsList(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGETS ---

  // === UPDATED WIDGET ===
  Widget _buildCategoryItem({
    required String name,
    required IconData iconData,
    required VoidCallback onTap,
    String? iconImageBase64,
  }) {
    Widget iconHolder;

    if (iconImageBase64 != null && iconImageBase64.isNotEmpty) {
      try {
        final imageBytes = base64Decode(iconImageBase64.split(',').last);
        iconHolder = Image.memory(
          imageBytes,
          fit: BoxFit.fill,
          errorBuilder: (c, e, s) {
            return Center(
              child: Icon(iconData, color: Colors.black54, size: 30),
            );
          },
        );
      } catch (e) {
        iconHolder = Center(
          child: Icon(iconData, color: Colors.black54, size: 30),
        );
      }
    } else {
      iconHolder = Center(
        child: Icon(iconData, color: Colors.black54, size: 30),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.grey.shade100, // Background color of the box
                borderRadius: BorderRadius.circular(16.0),
                // ADDED a subtle box shadow for depth
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(
                      255,
                      255,
                      255,
                      255,
                    ).withOpacity(0.2), // Shadow color
                    spreadRadius: 1, // How much the shadow spreads
                    blurRadius: 5, // How blurry the shadow is
                    offset: const Offset(0, 3), // Moves the shadow down
                  ),
                ],
              ),
              child: iconHolder,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularRentalCard(
    BuildContext context,
    MachineWithRating machineWithRating,
  ) {
    final doc = machineWithRating.machineDoc;
    final data = doc.data()! as Map<String, dynamic>;

    final imageUrlList = data['machinePhotos'] as List<dynamic>?;
    final imageUrl = (imageUrlList != null && imageUrlList.isNotEmpty)
        ? imageUrlList[0] as String?
        : null;

    final name = data['name'] ?? 'Unnamed Machine';
    final location = data['location'] ?? 'Unknown Location';
    final listingType = data['listingType'] ?? 'rent';
    final rating = machineWithRating.averageRating;

    final String rateDisplay;
    if (listingType == 'sale') {
      final price = (data['salePrice'] ?? 0).toDouble();
      rateDisplay = NumberFormat.compactCurrency(
        locale: 'en_IN',
        symbol: '₹',
      ).format(price);
    } else {
      final rate = (data['ratePerDay'] ?? data['ratePerHour'] ?? 0).toDouble();
      rateDisplay = '₹${rate.toStringAsFixed(0)}/hr';
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.3;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          MachineDetailsScreen.id,
          arguments: doc.id,
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 120,
                      width: imageWidth,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: imageWidth,
                        height: 120,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildImagePlaceholder(
                            width: imageWidth,
                            height: 120,
                          ),
                    )
                  : _buildImagePlaceholder(width: imageWidth, height: 120),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            style: TextStyle(color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            rateDisplay,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.fade,
                          ),
                        ),
                        if (rating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final location =
        _selectedLocation ??
        (_isLoading || _userData == null
            ? 'Loading...'
            : _userData!['location'] ?? 'Set Location');
    return GestureDetector(
      onTap: _showLocationPicker,
      child: Row(
        children: [
          Image.asset(
            'assets/images/mcspace.png',
            height: 35,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: const Color.fromARGB(255, 2, 24, 90),
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Delivering to',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        location,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color.fromARGB(255, 2, 24, 90),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationPicker() {
    final TextEditingController locationController = TextEditingController(
      text:
          _selectedLocation ??
          (_userData != null ? _userData!['location'] ?? '' : ''),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Change Location',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Machines available near your location will be shown.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: locationController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter city or area (e.g., Delhi)',
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: Color.fromARGB(255, 2, 24, 90),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 2, 24, 90),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final newLocation = locationController.text.trim();
                    if (newLocation.isNotEmpty) {
                      setState(() {
                        _selectedLocation = newLocation;
                      });
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 2, 24, 90),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (_selectedLocation != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      setState(() => _selectedLocation = null);
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Reset to Profile Location',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      readOnly: true,
      onTap: () {
        Navigator.pushNamed(
          context,
          FindMachineScreen.id,
          arguments: {'autoFocus': true, 'location': _selectedLocation ?? _userData?['location']},
        );
      },
      decoration: InputDecoration(
        hintText: 'Search machines, equipment...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade100,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 15.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required String title, VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'View All',
              style: TextStyle(
                color: Color(0xFFFF4F11),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoriesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: CustomLoadingIndicator(width: 80, height: 80),
          );
        if (snapshot.hasError)
          return const Center(child: Text('Could not load categories.'));
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('No categories found.'));

        var docs = snapshot.data!.docs;

        return SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final groupName = data['groupName'] ?? 'Unnamed';

              final IconData categoryIcon = _getIconForCategory(groupName);
              final String? iconImageBase64 = data['iconImageBase64'];

              return SizedBox(
                width: 70,
                child: _buildCategoryItem(
                  name: groupName,
                  iconData: categoryIcon,
                  iconImageBase64: iconImageBase64,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryMachinesScreen(
                          groupId: doc.id,
                          groupName: groupName,
                          initialLocation: _selectedLocation ?? _userData?['location'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 20),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isUserLoggedIn = FirebaseAuth.instance.currentUser != null;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            label: const FittedBox(
              child: Text('Post Machine', textAlign: TextAlign.center),
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                isUserLoggedIn ? EnrollMachineForm.id : WelcomeScreen.id,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 2, 24, 90),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.search, color: Colors.white),
            label: const FittedBox(
              child: Text('Browse Rentals', textAlign: TextAlign.center),
            ),
            onPressed: () {
              Navigator.pushNamed(
                context,
                isUserLoggedIn ? FindMachineScreen.id : WelcomeScreen.id,
                arguments: {'location': _selectedLocation ?? _userData?['location']},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 16, 102, 231),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularRentalsList() {
    final location = _selectedLocation ?? _userData?['location'];
    return FutureBuilder<List<MachineWithRating>>(
      future: _fetchAndProcessPopularMachines(location),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Error fetching popular machines."));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CustomLoadingIndicator();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No popular machines found.'));
        }
        final topMachines = snapshot.data!;
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topMachines.length,
          itemBuilder: (context, index) {
            final machineWithRating = topMachines[index];
            return _buildPopularRentalCard(context, machineWithRating);
          },
          separatorBuilder: (context, index) => const SizedBox(height: 16),
        );
      },
    );
  }

  Widget _buildImagePlaceholder({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
        size: 40,
      ),
    );
  }
}

// --- WIDGET FOR THE ADVERTISEMENT CAROUSEL (3-image view) ---

class AdvertisementCarousel extends StatefulWidget {
  const AdvertisementCarousel({super.key});

  @override
  State<AdvertisementCarousel> createState() => _AdvertisementCarouselState();
}

class _AdvertisementCarouselState extends State<AdvertisementCarousel> {
  List<String> _imageUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdvertisementImages();
  }

  Future<void> _fetchAdvertisementImages() async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('advertisements');
      final listResult = await storageRef.listAll();

      final urls = await Future.wait(
        listResult.items.map((item) => item.getDownloadURL()),
      );

      if (mounted) {
        setState(() {
          _imageUrls = urls;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching advertisement images: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 200.0, child: CustomLoadingIndicator());
    }

    if (_imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return CarouselSlider.builder(
      itemCount: _imageUrls.length,
      itemBuilder: (context, index, realIndex) {
        final imageUrl = _imageUrls[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: 1000,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  color: const Color.fromARGB(255, 2, 24, 90),
                ),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.error, color: Colors.red),
            ),
          ),
        );
      },
      options: CarouselOptions(
        height: 200.0,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.7,
        enlargeFactor: 0.2,
        aspectRatio: 16 / 9,
        autoPlayInterval: const Duration(seconds: 4),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: _imageUrls.length > 1,
      ),
    );
  }
}
