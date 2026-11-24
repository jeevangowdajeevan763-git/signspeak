import 'package:flutter/material.dart';
import 'camera_screen.dart';
import 'history_screen.dart';
import 'learn.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SignSpeak"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            // ==============================
            // WELCOME
            // ==============================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),

                gradient: const LinearGradient(
                  colors: [
                    Colors.deepPurple,
                    Colors.purple,
                  ],
                ),
              ),

              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    "Hello 👋",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    "Convert Sign Language Into Speech Instantly",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==============================
            // START RECOGNITION
            // ==============================

            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.camera_alt,
                ),

                label: const Text(
                  "Start Recognition",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),

                onPressed: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) => const CameraScreen(
                        isActive: true,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // ==============================
            // LEARN SIGN LANGUAGE
            // ==============================

            Card(
              elevation: 4,

              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.menu_book,
                  ),
                ),

                title: const Text(
                  "Learn Sign Language",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: const Text(
                  "View sign language alphabet images",
                ),

                trailing: const Icon(
                  Icons.arrow_forward_ios,
                ),

                onTap: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (context) {
                        return const LearnSignPage();
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // ==============================
            // HISTORY
            // ==============================

            Card(
              elevation: 4,

              child: ListTile(
                leading: const Icon(
                  Icons.history,
                ),

                title: const Text(
                  "History",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: const Text(
                  "View previous sign detections",
                ),

                trailing: const Icon(
                  Icons.arrow_forward_ios,
                ),

                onTap: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (context) {
                        return HistoryScreen(
                          history: const [],
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ==============================
            // RECENT DETECTIONS
            // ==============================

            const Card(
              elevation: 4,

              child: ListTile(
                leading: Icon(
                  Icons.analytics,
                ),

                title: Text(
                  "Recent Detections",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: Text(
                  "No detections yet",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}