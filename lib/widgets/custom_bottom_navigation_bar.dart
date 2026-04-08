import 'package:flutter/material.dart';
import 'package:mc_space/screens/chat_screen.dart';
import 'package:mc_space/screens/enrolled_machines_screen.dart';

class CustomBottomNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<CustomBottomNavigationBar> createState() => _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -5), // changes position of shadow
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.transparent, // Make BottomAppBar transparent to show Container's color and shadow
        shape: const CircularNotchedRectangle(),
        notchMargin: 5.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(context, Icons.home, 'Home', 0),
            _buildNavItem(context, Icons.list_alt, 'My space', 1), // Changed icon and label
            const SizedBox(width: 20), // The space for the floating action button
            _buildNavItem(context, Icons.chat, 'chat', 2),
            _buildNavItem(context, Icons.person, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index) {
    final bool isSelected = widget.selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (index == 1) { // Enrolled icon
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EnrolledMachinesScreen()),
            );
          } else if (index == 2) { // Messages icon
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          } else {
            widget.onItemTapped(index);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color.fromARGB(255, 2, 24, 90) : Colors.grey,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color.fromARGB(255, 2, 24, 90) : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
