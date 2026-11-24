import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'camera_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'screens/dataset_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DatasetScreen(),
      ),
    );
  },
  child: const Icon(Icons.camera),
),
      body: IndexedStack(
        index: currentIndex,
        children: [
          const HomePage(),

          CameraScreen(
            isActive: currentIndex == 1,
          ),

          const StatsScreen(
            totalSigns: 0,
            lastSign: "None",
          ),

          const SettingsScreen(),
          const ProfileScreen(),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        height: 70,

        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            selectedIcon: Icon(Icons.home),
            label: "Home",
          ),

          NavigationDestination(
            icon: Icon(Icons.camera_alt),
            selectedIcon: Icon(Icons.camera_alt),
            label: "Detect",
          ),

          NavigationDestination(
            icon: Icon(Icons.analytics),
            selectedIcon: Icon(Icons.analytics),
            label: "Stats",
          ),

          NavigationDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings),
            label: "Settings",
          ),

          NavigationDestination(
            icon: Icon(Icons.person),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}