import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:mc_space/widgets/custom_loading_indicator.dart';

class MachineDetailsScreen extends StatefulWidget {
  static const String id = 'machine_details_screen';

  const MachineDetailsScreen({super.key});

  @override
  _MachineDetailsScreenState createState() => _MachineDetailsScreenState();
}

class _MachineDetailsScreenState extends State<MachineDetailsScreen> {
  late Future<DocumentSnapshot> _machineFuture;
  late Future<double> _averageRatingFuture;
  late String _machineId;

  // --- Scroll Controller Variables ---
  late ScrollController _scrollController;
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    // --- Initialize Scroll Logic ---
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      // 220 is roughly where the image starts disappearing
      if (_scrollController.offset > 220 && !_showTitle) {
        setState(() => _showTitle = true);
      } else if (_scrollController.offset <= 220 && _showTitle) {
        setState(() => _showTitle = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final machineIdFromArgs = ModalRoute.of(context)!.settings.arguments;

    if (machineIdFromArgs is String) {
      _machineId = machineIdFromArgs;
    } else if (machineIdFromArgs is Map<String, String>) {
      _machineId = machineIdFromArgs['machineId']!;
    } else {
      // Initialize with safe/error values before popping to prevent LateInitializationError
      _machineId = '';
      _machineFuture = Future.error('Invalid arguments');
      _averageRatingFuture = Future.value(0.0);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).pop(),
      );
      return;
    }

    _machineFuture = _fetchMachineDetails();
    _averageRatingFuture = _getAverageRating();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- HELPER FOR TIMES NEW ROMAN FONT ---
  TextStyle _timesNewRomanStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Times New Roman',
      fontFamilyFallback: const [
        'serif',
      ], // Fallback for Android/iOS if font missing
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  Future<DocumentSnapshot> _fetchMachineDetails() {
    return FirebaseFirestore.instance
        .collection('machines')
        .doc(_machineId)
        .get();
  }

  Future<double> _getAverageRating() async {
    final reviewsSnapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('machineId', isEqualTo: _machineId)
        .get();

    if (reviewsSnapshot.docs.isEmpty) return 0.0;

    double totalRating = 0;
    for (var doc in reviewsSnapshot.docs) {
      totalRating += (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
    }

    return totalRating / reviewsSnapshot.docs.length;
  }

  double? _parsePrice(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _contactOwner(String userId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fetching owner contact details...'),
          duration: Duration(seconds: 1),
        ),
      );

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) throw 'Owner details not found.';

      final userData = userDoc.data() as Map<String, dynamic>;
      final String? contactNumber = userData['contactNumber'];

      if (contactNumber == null || contactNumber.isEmpty) {
        throw 'Owner has not provided a contact number.';
      }

      final Uri launchUri = Uri(scheme: 'tel', path: contactNumber);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch phone dialer.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _machineFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Lottie.asset(
                'assets/images/loading.json',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Machine not found.')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String userId = data['userId'] ?? '';

        // Data Extraction
        final machinePhotos = data['machinePhotos'] as List<dynamic>? ?? [];
        final name = data['name'] ?? 'Unnamed Machine';
        final description = data['description'] ?? 'No description available.';
        final location = data['location'] ?? 'Unknown Location';
        final ratePerHour = _parsePrice(data['ratePerHour']);
        final salePrice = _parsePrice(data['salePrice']);
        final model = data['machineSeries'] ?? data['model'] ?? 'N/A';
        final category = data['category'] ?? 'Heavy Machinery';
        final jobsDone = data['jobsDone'] as List<dynamic>?;
        final techSpecs = data['technicalSpecifications'] as List<dynamic>?;
        final rentalTerms = data['rentalTerms'] as List<dynamic>?;
        final createdAt = data['createdAt'] as Timestamp?;
        final effectiveDate = createdAt ?? data['updatedAt'] as Timestamp?;

        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: BottomAppBar(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 10,
            color: Colors.white,
            child: ElevatedButton.icon(
              onPressed: () {
                if (userId.isNotEmpty) {
                  _contactOwner(userId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Owner information is missing.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 2, 24, 90),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.call, color: Colors.white),
              label: Text(
                'Contact Owner',
                style: _timesNewRomanStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                backgroundColor: const Color.fromARGB(255, 2, 24, 90),
                // --- Conditional Title ---
                title: _showTitle
                    ? Text(
                        'Machine Details',
                        style: _timesNewRomanStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
                centerTitle: true,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _showTitle ? Colors.transparent : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: _showTitle ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _ImageCarousel(
                    photoUrls: machinePhotos.cast<String>(),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(
                          category,
                          style: _timesNewRomanStyle(
                            color: Colors.blue.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Header
                      _buildHeader(name),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: _timesNewRomanStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 30),

                      // Prices
                      _buildPriceSection(
                        ratePerHour: ratePerHour,
                        salePrice: salePrice,
                      ),

                      const Divider(height: 30),

                      // Machine Overview
                      _buildSectionTitle('Machine Overview'),
                      const SizedBox(height: 10),
                      _buildModelInfo(model),

                      const SizedBox(height: 24),

                      // Description
                      _buildSectionTitle('Description'),
                      const SizedBox(height: 8),
                      Text(
                        (description.isEmpty)
                            ? 'No description provided.'
                            : description,
                        style: _timesNewRomanStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),

                      // Lists
                      _buildStyledInfoBox(
                        title: 'Project History / Jobs Executed',
                        items: jobsDone,
                        icon: Icons.work_history_outlined,
                        headerColor: Colors.orange.shade50,
                      ),

                      _buildStyledInfoBox(
                        title: 'Technical Specifications',
                        items: techSpecs,
                        icon: Icons.settings_outlined,
                        headerColor: Colors.blue.shade50,
                      ),

                      _buildStyledInfoBox(
                        title: 'Rental Terms & Conditions',
                        items: rentalTerms,
                        icon: Icons.gavel_outlined,
                        headerColor: Colors.grey.shade100,
                      ),

                      // Owner Details
                      const SizedBox(height: 24),
                      _buildSectionTitle('Owner / Company Details'),
                      const SizedBox(height: 10),
                      if (userId.isNotEmpty)
                        _buildOwnerDetails(userId)
                      else
                        const Text("No owner information available."),

                      // Footer Date
                      const SizedBox(height: 30),
                      if (effectiveDate != null)
                        Center(
                          child: Text(
                            "Last updated on ${DateFormat('MMM d, yyyy').format(effectiveDate.toDate())}",
                            style: _timesNewRomanStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildOwnerDetails(String userId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(10.0),
            child: CustomLoadingIndicator(width: 50, height: 50),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Text("Could not load owner details.");
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        // Profile Info
        final String companyName = userData['companyName'] ?? 'Unknown Company';
        final String contactName = userData['contactName'] ?? 'Unknown Name';
        final String location = userData['location'] ?? 'Unknown Location';
        final String? profileImage = userData['profileImage'];

        // Contact Fields
        final String? officialMailId = userData['officialMailId'];
        final String? alternateMailId = userData['alternateMailId'];
        final String? contactNumber = userData['contactNumber'];
        final String? alternateNumber = userData['alternateNumber'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Main Profile Section
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                      image: profileImage != null && profileImage.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(profileImage),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: profileImage == null || profileImage.isEmpty
                        ? const Icon(Icons.person, size: 30, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          style: _timesNewRomanStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color.fromARGB(255, 2, 24, 90),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              contactName,
                              style: _timesNewRomanStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: _timesNewRomanStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // 2. Detailed Contact Information
              if (contactNumber != null && contactNumber.isNotEmpty)
                _buildContactInfoRow(Icons.phone, "Mobile", contactNumber),

              if (alternateNumber != null && alternateNumber.isNotEmpty)
                _buildContactInfoRow(
                  Icons.phone_iphone,
                  "Alt. Mobile",
                  alternateNumber,
                ),

              if (officialMailId != null && officialMailId.isNotEmpty)
                _buildContactInfoRow(
                  Icons.email_outlined,
                  "Email",
                  officialMailId,
                ),

              if (alternateMailId != null && alternateMailId.isNotEmpty)
                _buildContactInfoRow(
                  Icons.alternate_email,
                  "Alt. Email",
                  alternateMailId,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color.fromARGB(255, 2, 24, 90)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: _timesNewRomanStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: _timesNewRomanStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Standard Helpers ---
  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            name,
            style: _timesNewRomanStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.black87,
            ),
          ),
        ),
        _buildRatingIndicator(),
      ],
    );
  }

  Widget _buildRatingIndicator() {
    return FutureBuilder<double>(
      future: _averageRatingFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == 0.0)
          return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                snapshot.data!.toStringAsFixed(1),
                style: _timesNewRomanStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceSection({double? ratePerHour, double? salePrice}) {
    if (ratePerHour == null && salePrice == null)
      return const SizedBox.shrink();
    final formatCurrency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 240, 245, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          if (ratePerHour != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "RATE PER HOUR",
                      style: _timesNewRomanStyle(
                        color: Colors.blueGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${formatCurrency.format(ratePerHour)} / hour",
                      style: _timesNewRomanStyle(
                        color: const Color.fromARGB(255, 2, 24, 90),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (ratePerHour != null && salePrice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(color: Colors.blue.shade100, thickness: 1),
            ),
          if (salePrice != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SALE PRICE",
                      style: _timesNewRomanStyle(
                        color: Colors.blueGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatCurrency.format(salePrice),
                      style: _timesNewRomanStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "For Sale",
                    style: _timesNewRomanStyle(
                      color: Colors.orange.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildModelInfo(String model) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Machine Series / Model",
                style: _timesNewRomanStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                model,
                style: _timesNewRomanStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: _timesNewRomanStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildStyledInfoBox({
    required String title,
    List<dynamic>? items,
    required IconData icon,
    required Color headerColor,
  }) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle(title),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: headerColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              bool isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    minLeadingWidth: 20,
                    leading: Icon(icon, color: Colors.black87, size: 20),
                    title: Text(
                      entry.value.toString(),
                      style: _timesNewRomanStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 50, color: Colors.grey.shade300),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  final List<String> photoUrls;
  const _ImageCarousel({required this.photoUrls});
  @override
  _ImageCarouselState createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _currentPage = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            itemCount: widget.photoUrls.length,
            onPageChanged: (value) => setState(() => _currentPage = value),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Image.network(
                  widget.photoUrls[index],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (c, e, s) =>
                      const Center(child: Icon(Icons.error, color: Colors.red)),
                ),
              );
            },
          ),
          if (widget.photoUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photoUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.all(4.0),
                    width: _currentPage == index ? 10.0 : 6.0,
                    height: _currentPage == index ? 10.0 : 6.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
