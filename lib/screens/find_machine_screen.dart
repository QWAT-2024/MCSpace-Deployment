import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'package:mc_space/screens/machine_details_screen.dart';
import 'package:lottie/lottie.dart';

class FindMachineScreen extends StatefulWidget {
  static const String id = '/find_machine';
  const FindMachineScreen({super.key});

  @override
  State<FindMachineScreen> createState() => _FindMachineScreenState();
}

class _FindMachineScreenState extends State<FindMachineScreen> {
  final TextEditingController _searchController = TextEditingController();

  // State variables
  String _searchQuery = '';
  String? _locationFilter;
  double _maxRateFilter = 5000.0; // Default max range
  bool _isGridView = true; // Toggle between Grid and List

  // Group and Category Filters
  final Set<String> _selectedGroupIds = <String>{};
  final Set<String> _selectedCategoryIds = <String>{};
  Map<String, String> _groupNames = {};
  Map<String, String> _categoryNames = {};

  // Stable Streams
  late Stream<QuerySnapshot> _groupsStream;
  late Stream<QuerySnapshot> _categoriesStream;
  late Stream<QuerySnapshot> _machinesStream;

  // Constants
  final Color _primaryColor = const Color.fromARGB(255, 2, 24, 90);
  final Color _accentColor = const Color(
    0xFFF97316,
  ); // Orange from your example
  static const double _absoluteMaxRate = 10000.0;

  final FocusNode _searchFocusNode = FocusNode();
  bool _hasFocused = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });

    _groupsStream = FirebaseFirestore.instance.collection('groups').snapshots();
    _categoriesStream = FirebaseFirestore.instance.collection('categories').snapshots();
    _machinesStream = FirebaseFirestore.instance.collection('machines').snapshots();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasFocused) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args['autoFocus'] == true) {
          FocusScope.of(context).requestFocus(_searchFocusNode);
        }
        if (args['location'] != null) {
          _locationFilter = args['location'] as String?;
        }
      }
      _hasFocused = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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



  // --- MAIN BUILD ---
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
          'Find a Machine',
          style: _timesNewRomanStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. SEARCH BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.white,
            child: TextField(
              focusNode: _searchFocusNode,
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

          // 2. STREAM BUILDER (Data Logic)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _machinesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading data',
                      style: _timesNewRomanStyle(),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Lottie.asset(
                      'assets/images/loading.json',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                var filteredDocs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;

                  // Name Filter (Case Insensitive)
                  if (_searchQuery.trim().isNotEmpty) {
                    final name = (data['name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim();
                    final query = _searchQuery
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim();
                    if (!name.contains(query)) {
                      return false;
                    }
                  }

                  // Location Filter
                  if (_locationFilter != null &&
                      _locationFilter!.trim().isNotEmpty) {
                    String docLocation = (data['location'] ?? '')
                        .toString()
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim();
                    String filterLoc = _locationFilter!
                        .toLowerCase()
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim();
                    if (!docLocation.contains(filterLoc)) {
                      return false;
                    }
                  }

                  // Group Filter
                  if (_selectedGroupIds.isNotEmpty) {
                    if (!_selectedGroupIds.contains(data['groupId']?.toString())) {
                      return false;
                    }
                  }

                  // Category Filter
                  if (_selectedCategoryIds.isNotEmpty) {
                    if (!_selectedCategoryIds.contains(data['categoryId']?.toString())) {
                      return false;
                    }
                  }

                  // Max Rate Filter
                  double? rate = double.tryParse(
                    data['ratePerHour']?.toString() ?? '0',
                  );
                  // If rate is null/0, we usually keep it, or hide it. Here we keep it if it's below max.
                  if (rate != null && rate > _maxRateFilter) {
                    return false;
                  }

                  return true;
                }).toList();

                return Column(
                  children: [
                    // 4. FILTER BAR & COUNT (Rebuilt with filtered count)
                    _buildFilterBar(filteredDocs.length),

                    // 5. GRID / LIST VIEW
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
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
                                      fontSize: 18,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _isGridView
                          ? _buildGridView(filteredDocs)
                          : _buildListView(filteredDocs),
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

  // --- FILTER BAR SECTION ---
  Widget _buildFilterBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGroupDropdownFilter(),
                const SizedBox(width: 8),
                if (_selectedGroupIds.isNotEmpty) ...[
                  _buildCategoryDropdownFilter(),
                  const SizedBox(width: 8),
                ],
                _buildStyledFilterChip(
                  label: _locationFilter == null
                      ? 'Location'
                      : 'Loc: $_locationFilter',
                  icon: Icons.location_on_outlined,
                  isSelected: _locationFilter != null,
                  onTap: () async {
                    await _showTextFilterDialog(
                      title: 'Filter by Location',
                      hint: 'Enter city (e.g., Delhi)',
                      onSave: (val) => setState(
                        () => _locationFilter = val.isEmpty ? null : val,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildStyledFilterChip(
                  label: _maxRateFilter == _absoluteMaxRate
                      ? 'Price'
                      : '< ₹${_maxRateFilter.toInt()}/hr',
                  hasDropdown: true,
                  isSelected: _maxRateFilter < _absoluteMaxRate,
                  onTap: _showPriceFilterBottomSheet,
                ),
                    if (_locationFilter != null ||
                        _maxRateFilter < _absoluteMaxRate ||
                        _selectedGroupIds.isNotEmpty ||
                        _selectedCategoryIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _locationFilter = null;
                            _maxRateFilter = _absoluteMaxRate;
                            _selectedGroupIds.clear();
                            _selectedCategoryIds.clear();
                          });
                        },
                    child: Text(
                      'Reset',
                      style: _timesNewRomanStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Count & Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count machines found',
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
          const Divider(),
        ],
      ),
    );
  }

  // --- CATEGORY & GROUP LOGIC ---
  void _showMultiSelectFilterSheet({
    required String title,
    required Map<String, String> items,
    required Set<String> selectedIds,
    required Function(Set<String>) onApply,
  }) {
    Set<String> tempSelected = Set.from(selectedIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (stateContext, setModalState) {
            bool isAllSelected = items.isNotEmpty && tempSelected.length == items.length;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: items.length > 5 ? 0.6 : 0.4,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: _timesNewRomanStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                if (isAllSelected) {
                                  tempSelected.clear();
                                } else {
                                  tempSelected.addAll(items.keys);
                                }
                              });
                            },
                            child: Text(
                              isAllSelected ? 'Clear All' : 'Select All',
                              style: _timesNewRomanStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          String id = items.keys.elementAt(index);
                          String name = items.values.elementAt(index);
                          bool isSelected = tempSelected.contains(id);

                          return CheckboxListTile(
                            title: Text(name, style: _timesNewRomanStyle(fontSize: 16)),
                            value: isSelected,
                            activeColor: _accentColor,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (bool? value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelected.add(id);
                                } else {
                                  tempSelected.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            onApply(tempSelected);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Apply',
                            style: _timesNewRomanStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupDropdownFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: _groupsStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _groupNames = {
            for (var doc in snapshot.data!.docs)
              doc.id: (doc.data() as Map<String, dynamic>)['groupName'] ?? 'Unnamed',
          };
        }

        String label = 'Groups';
        if (_selectedGroupIds.length == 1) {
          label = _groupNames[_selectedGroupIds.first] ?? 'Group';
        } else if (_selectedGroupIds.length > 1) {
          label = 'Groups (${_selectedGroupIds.length})';
        }

        return _buildStyledFilterChip(
          label: label,
          hasDropdown: true,
          isSelected: _selectedGroupIds.isNotEmpty,
          onTap: () {
            if (_groupNames.isEmpty) return;
            _showMultiSelectFilterSheet(
              title: 'Filter by Group',
              items: _groupNames,
              selectedIds: _selectedGroupIds,
              onApply: (selectedIds) {
                setState(() {
                  _selectedGroupIds.clear();
                  _selectedGroupIds.addAll(selectedIds);
                  _selectedCategoryIds.clear();
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryDropdownFilter() {
    if (_selectedGroupIds.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _categoriesStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _categoryNames = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            // Only include categories that belong to the selected groups
            if (_selectedGroupIds.contains(data['groupId']?.toString())) {
               _categoryNames[doc.id] = data['name'] ?? 'Unnamed';
            }
          }
        }

        String label = 'Categories';
        if (_selectedCategoryIds.length == 1) {
          label = _categoryNames[_selectedCategoryIds.first] ?? 'Category';
        } else if (_selectedCategoryIds.length > 1) {
          label = 'Categories (${_selectedCategoryIds.length})';
        }

        return _buildStyledFilterChip(
          label: label,
          hasDropdown: true,
          isSelected: _selectedCategoryIds.isNotEmpty,
          onTap: () {
            if (_categoryNames.isEmpty) return;
            _showMultiSelectFilterSheet(
              title: 'Filter by Category',
              items: _categoryNames,
              selectedIds: _selectedCategoryIds,
              onApply: (selectedIds) {
                setState(() {
                  _selectedCategoryIds.clear();
                  _selectedCategoryIds.addAll(selectedIds);
                });
              },
            );
          },
        );
      },
    );
  }

  // --- FILTER LOGIC (Dialogs & Bottom Sheets) ---

  Future<void> _showTextFilterDialog({
    required String title,
    required String hint,
    required Function(String) onSave,
  }) async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) {
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
                Navigator.pop(dialogContext);
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

  void _showPriceFilterBottomSheet() {
    double tempRate = _maxRateFilter;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext stateContext, StateSetter setModalState) {
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
                    'Up to ${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(tempRate)} / hr',
                    style: _timesNewRomanStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  Slider(
                    value: tempRate,
                    min: 500,
                    max: _absoluteMaxRate,
                    divisions: 19, // Steps of 500 roughly
                    activeColor: _accentColor,
                    onChanged: (value) {
                      setModalState(() {
                        tempRate = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _maxRateFilter = tempRate;
                        });
                        Navigator.pop(sheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: _timesNewRomanStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildStyledFilterChip({
    required String label,
    IconData? icon,
    bool hasDropdown = false,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? _accentColor : Colors.grey[600],
                size: 18,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: _timesNewRomanStyle(
                color: isSelected ? _accentColor : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                color: isSelected ? _accentColor : Colors.black54,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isGridViewButton) {
    bool isSelected =
        (_isGridView && isGridViewButton) ||
        (!_isGridView && !isGridViewButton);
    return GestureDetector(
      onTap: () {
        if (!isSelected) setState(() => _isGridView = !_isGridView);
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
          size: 20,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.construction, color: Colors.grey, size: 40),
      ),
    );
  }

  // --- GRID VIEW BUILDER ---
  Widget _buildGridView(List<QueryDocumentSnapshot> docs) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.70, // Slightly taller for info
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        var data = docs[index].data() as Map<String, dynamic>;
        String imageUrl = '';
        if (data['machinePhotos'] != null &&
            (data['machinePhotos'] as List).isNotEmpty) {
          imageUrl = data['machinePhotos'][0];
        }

        return GestureDetector(
          onTap: () => _navigateToDetails(docs[index], data),
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
                      Positioned.fill(
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) =>
                                    _buildImagePlaceholder(),
                              )
                            : _buildImagePlaceholder(),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RENT',
                            style: _timesNewRomanStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
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
                        data['name'] ?? 'Unnamed',
                        style: _timesNewRomanStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.grey.shade600,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data['location'] ?? 'Unknown',
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
                      Text(
                        '₹${data['ratePerHour'] ?? 0}/hr',
                        style: _timesNewRomanStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
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

  // --- LIST VIEW BUILDER ---
  Widget _buildListView(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        var data = docs[index].data() as Map<String, dynamic>;
        String imageUrl = '';
        if (data['machinePhotos'] != null &&
            (data['machinePhotos'] as List).isNotEmpty) {
          imageUrl = data['machinePhotos'][0];
        }

        return GestureDetector(
          onTap: () => _navigateToDetails(docs[index], data),
          child: Card(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            elevation: 2,
            shadowColor: Colors.grey.withOpacity(0.15),
            child: SizedBox(
              height: 110,
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: imageUrl.isNotEmpty
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
                                data['name'] ?? 'Unnamed',
                                style: _timesNewRomanStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                    data['location'] ?? 'Unknown',
                                    style: _timesNewRomanStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${data['ratePerHour'] ?? 0}/hr',
                                style: _timesNewRomanStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Colors.blue,
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
          ),
        );
      },
    );
  }

  void _navigateToDetails(DocumentSnapshot doc, Map<String, dynamic> data) {
    Navigator.pushNamed(context, MachineDetailsScreen.id, arguments: doc.id);
  }
}
