import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mc_space/screens/enroll_machine_form.dart'; // For editing
import 'package:mc_space/screens/machine_details_screen.dart'; // For viewing details
import 'package:mc_space/widgets/custom_loading_indicator.dart';

class EnrolledMachinesScreen extends StatefulWidget {
  static const String id = '/enrolled_machines';
  // Add an optional userId to the constructor
  final String? userId;
  const EnrolledMachinesScreen({super.key, this.userId});

  @override
  State<EnrolledMachinesScreen> createState() => _EnrolledMachinesScreenState();
}

class _EnrolledMachinesScreenState extends State<EnrolledMachinesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _activeUserId; // Use this to store the user ID for fetching data

  @override
  void initState() {
    super.initState();
    // Prioritize widget.userId if provided, otherwise fallback to Firebase Auth UID
    _activeUserId = widget.userId ?? _auth.currentUser?.uid;
  }

  Future<void> _deleteMachine(String machineId) async {
    // Show a confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // Ensure the dialog background is also pure white
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you sure you want to delete this machine? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _firestore.collection('machines').doc(machineId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Machine deleted successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting machine: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUserId == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text('Please log in to view your enrolled machines.'),
        ),
      );
    }

    return Scaffold(
      // Set the main background color to pure white
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Space'),
        backgroundColor: const Color.fromARGB(255, 2, 24, 90),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('machines')
            .where('userId', isEqualTo: _activeUserId) // Use _activeUserId here
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CustomLoadingIndicator();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('You have not enrolled any machines yet.'),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var machineDoc = snapshot.data!.docs[index];
              var machineData = machineDoc.data() as Map<String, dynamic>;
              String machineId = machineDoc.id;

              String imageUrl = '';
              if (machineData['machinePhotos'] != null &&
                  machineData['machinePhotos'].isNotEmpty) {
                imageUrl = machineData['machinePhotos'][0];
              }

              return Card(
                // Set Card background to pure white
                color: Colors.white,
                // Remove the default Material 3 surface tint
                surfaceTintColor: Colors.white,
                elevation:
                    3, // Keep shadow to separate card from the white background
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.construction, size: 50),
                  title: Text(machineData['name'] ?? 'Unnamed Machine'),
                  subtitle: Text(machineData['location'] ?? 'Unknown Location'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EnrollMachineForm(machineId: machineId),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMachine(machineId),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      MachineDetailsScreen.id,
                      arguments: machineId,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            String? contactNumber;
            if (userDoc.exists) {
              contactNumber = (userDoc.data())?['contactNumber'];
            }
            if (context.mounted) {
              Navigator.pushNamed(
                context,
                EnrollMachineForm.id,
                arguments: contactNumber,
              );
            }
          }
        },
        backgroundColor: const Color.fromARGB(255, 2, 24, 90),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
