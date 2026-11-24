import 'package:flutter/material.dart';
import 'screens/learn_sign_page.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About SignSpeak"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SignSpeak",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "A Sign Language to Speech Conversion App.",
              style: TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 20),

            const Text(
              "Features:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text("• Sign Detection"),
            const Text("• Text Conversion"),
            const Text("• Speech Output"),
            const Text("• Recognition History"),

            const SizedBox(height: 25),

            // Learn button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LearnSignPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.menu_book),
                label: const Text(
                  "Learn Sign Language",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Developed By:",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              "Jeevan Gowda",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}