import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mc_space/screens/machine_details_screen.dart';
import 'package:mc_space/widgets/custom_loading_indicator.dart';

// Helper class to store machine data
class MachineData {
  final QueryDocumentSnapshot machineDoc;
  final String categoryId;
  final String? firstMachinePhotoUrl;

  MachineData({
    required this.machineDoc,
    required this.categoryId,
    this.firstMachinePhotoUrl,
  });
}

class CategoryMachinesScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? initialLocation;

  const CategoryMachinesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.initialLocation,
  });

  @override
  _CategoryMachinesScreenState createState() => _CategoryMachinesScreenState();
}

class _CategoryMachinesScreenState extends State<CategoryMachinesScreen> {
  late Future<List<MachineData>> _machinesFuture;
  final TextEditingController _searchController = TextEditingController();

  // UI State
  bool _isGridView = true;
  String _searchQuery = '';
  String? _locationFilter;

  // Filter States
  final Set<String> _selectedCategoryIds = <String>{};
  Map<String, String> _categoryNames = {};

  // Price Filter State
  static const double _absoluteMaxRate = 10000.0;
  double _maxRateFilter = _absoluteMaxRate;

  // Theme Constants
  final Color _primaryColor = const Color.fromARGB(255, 2, 24, 90);
  final Color _accentColor = const Color(0xFFF97316); // Orange

  @override
  void initState() {
    super.initState();
    _locationFilter = widget.initialLocation;
    _machinesFuture = _fetchMachines();

    // Add Search Listener
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
          // Refresh data when search changes
          _machinesFuture = _fetchMachines();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      fontFamilyFallback: const ['serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // --- DATA FETCHING LOGIC ---
  Future<List<MachineData>> _fetchMachines() async {
    final firestore = FirebaseFirestore.instance;
    List<MachineData> allMachines = [];

    Query query = firestore
        .collection('machines')
        .where('groupId', isEqualTo: widget.groupId);

    // Apply Category Filter in Firestore Query
    if (_selectedCategoryIds.isNotEmpty) {
      query = query.where('categoryId', whereIn: _selectedCategoryIds.toList());
    }

    final machinesSnapshot = await query.get();

    for (var machineDoc in machinesSnapshot.docs) {
      final data = machineDoc.data() as Map<String, dynamic>;
      String? firstPhotoUrl;

      final photoUrls = data['machinePhotos'] as List<dynamic>?;
      if (photoUrls != null && photoUrls.isNotEmpty) {
        firstPhotoUrl = photoUrls[0] as String?;
      }

      allMachines.add(
        MachineData(
          machineDoc: machineDoc,
          categoryId: data['categoryId'] ?? '',
          firstMachinePhotoUrl: firstPhotoUrl,
        ),
      );
    }

    // --- CLIENT SIDE FILTERING ---

    // 1. Filter by Search Query (Name)
    if (_searchQuery.trim().isNotEmpty) {
      allMachines.retainWhere((machineData) {
        final data = machineData.machineDoc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final query = _searchQuery
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return name.contains(query);
      });
    }

    // 2. Filter by Location
    if (_locationFilter != null && _locationFilter!.trim().isNotEmpty) {
      allMachines.retainWhere((machineData) {
        final data = machineData.machineDoc.data() as Map<String, dynamic>;
        final docLocation = (data['location'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final filterLoc = _locationFilter!
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        return docLocation.contains(filterLoc);
      });
    }

    // 3. Filter by Price
    if (_maxRateFilter < _absoluteMaxRate) {
      allMachines.retainWhere((machineData) {
        final data = machineData.machineDoc.data() as Map<String, dynamic>;

        // Parse Price
        double? price = double.tryParse(data['ratePerHour']?.toString() ?? '0');
        if (price == null || price == 0) {
          price = double.tryParse(data['ratePerDay']?.toString() ?? '0');
        }

        if (price == null) return false;

        return price <= _maxRateFilter;
      });
    }

    return allMachines;
  }

  void _toggleCategoryFilter(String categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
      _machinesFuture = _fetchMachines();
    });
  }

  void _resetAllFilters() {
    setState(() {
      _selectedCategoryIds.clear();
      _maxRateFilter = _absoluteMaxRate;
      _locationFilter = null;
      _searchController.clear(); // Clear search too
      _machinesFuture = _fetchMachines();
    });
  }

  String _getCategoryButtonLabel() {
    if (_selectedCategoryIds.length == 1) {
      final selectedId = _selectedCategoryIds.first;
      return _categoryNames[selectedId] ?? 'Category';
    }
    if (_selectedCategoryIds.length > 1) {
      return 'Multiple';
    }
    return 'Categories';
  }

  String _getPriceButtonLabel() {
    if (_maxRateFilter == _absoluteMaxRate) {
      return 'Price';
    }
    return '< ₹${_maxRateFilter.toInt()}';
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.groupName,
          style: _timesNewRomanStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        // Removed Search Icon from AppBar Actions
        actions: [],
      ),
      body: Column(
        children: [
          // 1. SEARCH BAR (Added here)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              style: _timesNewRomanStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search machine name...',
                hintStyle: _timesNewRomanStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: _primaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          // 2. FILTER BAR & LIST
          Expanded(
            child: FutureBuilder<List<MachineData>>(
              future: _machinesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CustomLoadingIndicator();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Something went wrong: ${snapshot.error}',
                      style: _timesNewRomanStyle(),
                    ),
                  );
                }

                final machineDataList = snapshot.data ?? [];

                return Column(
                  children: [
                    _buildFilterBar(machineDataList.length),
                    if (machineDataList.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 60,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No machines found.',
                                style: _timesNewRomanStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: _isGridView
                            ? _buildGridView(machineDataList)
                            : _buildListView(machineDataList),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- FILTER BAR ---
  Widget _buildFilterBar(int machineCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterChipsRow(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$machineCount machines found',
                style: _timesNewRomanStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _buildViewToggleButton(Icons.grid_view_rounded, true),
                  const SizedBox(width: 8),
                  _buildViewToggleButton(Icons.view_list_rounded, false),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    bool hasActiveFilters =
        _selectedCategoryIds.isNotEmpty ||
        _maxRateFilter < _absoluteMaxRate ||
        _searchQuery.isNotEmpty;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _buildCategoryDropdownFilter(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await _showTextFilterDialog(
                title: 'Filter by Location',
                hint: 'Enter city (e.g., Delhi)',
                onSave: (val) {
                  setState(() {
                    _locationFilter = val.isEmpty ? null : val;
                    _machinesFuture = _fetchMachines();
                  });
                },
              );
            },
            child: _buildStyledFilterChip(
              label: _locationFilter == null ? 'Location' : 'Loc: $_locationFilter',
              icon: Icons.location_on_outlined,
              isSelected: _locationFilter != null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showPriceFilter,
            child: _buildStyledFilterChip(
              label: _getPriceButtonLabel(),
              hasDropdown: true,
              isSelected: _maxRateFilter < _absoluteMaxRate,
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _resetAllFilters,
              child: Center(
                child: Text(
                  'Reset',
                  style: _timesNewRomanStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- PRICE FILTER BOTTOM SHEET ---
  void _showPriceFilter() {
    double tempRate = _maxRateFilter;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Max Hourly Rate',
                    style: _timesNewRomanStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tempRate == _absoluteMaxRate
                        ? 'Any Price'
                        : 'Up to ${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(tempRate)} / hr',
                    style: _timesNewRomanStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  Slider(
                    value: tempRate,
                    min: 500,
                    max: _absoluteMaxRate,
                    divisions: 19,
                    activeColor: _accentColor,
                    onChanged: (value) {
                      setModalState(() {
                        tempRate = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _maxRateFilter = _absoluteMaxRate;
                              _machinesFuture = _fetchMachines();
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Reset',
                            style: _timesNewRomanStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _maxRateFilter = tempRate;
                              _machinesFuture = _fetchMachines();
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                          ),
                          child: Text(
                            'Apply',
                            style: _timesNewRomanStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- LOCATION TEXT FILTER DIALOG ---
  Future<void> _showTextFilterDialog({
    required String title,
    required String hint,
    required Function(String) onSave,
  }) async {
    final TextEditingController controller = TextEditingController(text: _locationFilter ?? '');
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            title,
            style: _timesNewRomanStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: TextField(
            controller: controller,
            style: _timesNewRomanStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _timesNewRomanStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _primaryColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: _timesNewRomanStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Apply',
                style: _timesNewRomanStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- CATEGORY FILTER ---
  Widget _buildCategoryDropdownFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('groupId', isEqualTo: widget.groupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _categoryNames = {
            for (var doc in snapshot.data!.docs)
              doc.id: (doc.data() as Map<String, dynamic>)['name'] ?? 'Unnamed',
          };
        } else {
          return _buildStyledFilterChip(label: 'Categories', hasDropdown: true);
        }
        return PopupMenuButton<String>(
          onSelected: _toggleCategoryFilter,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          color: Colors.white,
          elevation: 3,
          child: _buildStyledFilterChip(
            label: _getCategoryButtonLabel(),
            hasDropdown: true,
            isSelected: _selectedCategoryIds.isNotEmpty,
          ),
          itemBuilder: (BuildContext context) {
            return snapshot.data!.docs.map((doc) {
              final categoryName = _categoryNames[doc.id]!;
              final isSelected = _selectedCategoryIds.contains(doc.id);
              return CheckedPopupMenuItem<String>(
                value: doc.id,
                checked: isSelected,
                child: Text(
                  categoryName,
                  style: _timesNewRomanStyle(fontSize: 14),
                ),
              );
            }).toList();
          },
        );
      },
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildStyledFilterChip({
    required String label,
    IconData? icon,
    bool hasDropdown = false,
    bool isSelected = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? _accentColor.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isSelected ? _accentColor : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              color: isSelected ? _accentColor : Colors.grey[600],
              size: 18,
            ),
          if (icon != null) const SizedBox(width: 6),
          Text(
            label,
            style: _timesNewRomanStyle(
              color: isSelected ? _accentColor : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (hasDropdown) const SizedBox(width: 4),
          if (hasDropdown)
            Icon(
              Icons.keyboard_arrow_down,
              color: isSelected ? _accentColor : Colors.black54,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isGridViewButton) {
    bool isSelected =
        (_isGridView && isGridViewButton) ||
        (!_isGridView && !isGridViewButton);
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _isGridView = !_isGridView;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? _accentColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade600,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.construction, color: Colors.grey, size: 50),
      ),
    );
  }

  Widget _buildTag(String listingType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: listingType == 'sale'
            ? const Color(0xFF2E7D32)
            : const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        listingType == 'sale' ? 'FOR SALE' : 'FOR RENT',
        style: _timesNewRomanStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  // --- GRID VIEW CARD ---
  Widget _buildGridView(List<MachineData> machineDataList) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: machineDataList.length,
      itemBuilder: (context, index) {
        final machineData = machineDataList[index];
        final doc = machineData.machineDoc;
        final data = doc.data()! as Map<String, dynamic>;
        final imageUrl = machineData.firstMachinePhotoUrl;

        final name = data['name'] ?? 'Unnamed Machine';
        final listingType = data['listingType'] ?? 'rent';
        final modelYear = data['modelYear']?.toString() ?? 'N/A';
        final location = data['location'] ?? 'Unknown Location';
        final rating = (data['averageRating'] ?? 0.0).toDouble();

        final String priceDisplay;
        if (listingType == 'sale') {
          final price = (data['salePrice'] ?? 0).toDouble();
          priceDisplay = NumberFormat.compactCurrency(
            locale: 'en_IN',
            symbol: '₹',
          ).format(price);
        } else {
          final rate = (data['ratePerDay'] ?? data['ratePerHour'] ?? 0)
              .toDouble();
          priceDisplay = '₹${rate.toStringAsFixed(0)}/hr';
        }

        return GestureDetector(
          onTap: () {
            final arguments = {
              'groupId': widget.groupId,
              'categoryId': machineData.categoryId,
              'machineId': doc.id,
            };
            Navigator.pushNamed(
              context,
              MachineDetailsScreen.id,
              arguments: arguments,
            );
          },
          child: Card(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 3,
            shadowColor: Colors.grey.withOpacity(0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      (imageUrl != null && imageUrl.isNotEmpty)
                          ? Positioned.fill(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildImagePlaceholder(),
                              ),
                            )
                          : _buildImagePlaceholder(),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildTag(listingType),
                      ),
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 14,
                          child: Icon(
                            Icons.favorite_border,
                            size: 18,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: _timesNewRomanStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$modelYear Model',
                        style: _timesNewRomanStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.grey.shade600,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: _timesNewRomanStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            priceDisplay,
                            style: _timesNewRomanStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: _timesNewRomanStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- LIST VIEW TILE ---
  Widget _buildListView(List<MachineData> machineDataList) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: machineDataList.length,
      itemBuilder: (context, index) {
        final machineData = machineDataList[index];
        final doc = machineData.machineDoc;
        final data = doc.data()! as Map<String, dynamic>;
        final imageUrl = machineData.firstMachinePhotoUrl;

        final name = data['name'] ?? 'Unnamed Machine';
        final listingType = data['listingType'] ?? 'rent';
        final modelYear = data['modelYear']?.toString() ?? 'N/A';
        final location = data['location'] ?? 'Unknown Location';
        final rating = (data['averageRating'] ?? 0.0).toDouble();
        final String priceDisplay;
        if (listingType == 'sale') {
          final price = (data['salePrice'] ?? 0).toDouble();
          priceDisplay = NumberFormat.compactCurrency(
            locale: 'en_IN',
            symbol: '₹',
          ).format(price);
        } else {
          final rate = (data['ratePerDay'] ?? data['ratePerHour'] ?? 0)
              .toDouble();
          priceDisplay = '₹${rate.toStringAsFixed(0)}/day';
        }

        return GestureDetector(
          onTap: () {
            final arguments = {
              'groupId': widget.groupId,
              'categoryId': machineData.categoryId,
              'machineId': doc.id,
            };
            Navigator.pushNamed(
              context,
              MachineDetailsScreen.id,
              arguments: arguments,
            );
          },
          child: Card(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 2,
            shadowColor: Colors.grey.withOpacity(0.15),
            child: SizedBox(
              height: 120,
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: _timesNewRomanStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$modelYear Model',
                                style: _timesNewRomanStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                priceDisplay,
                                style: _timesNewRomanStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: _timesNewRomanStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.grey.shade600,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        location,
                                        style: _timesNewRomanStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }
}
