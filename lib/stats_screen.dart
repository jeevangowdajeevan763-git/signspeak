import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  final int totalSigns;
  final String lastSign;

  const StatsScreen({
    super.key,
    required this.totalSigns,
    required this.lastSign,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistics"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            // Total Signs
            Card(
              elevation: 4,
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.numbers),
                ),

                title: const Text(
                  "Total Signs Recognized",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: Text(
                  "$totalSigns",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Last Sign
            Card(
              elevation: 4,
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.sign_language),
                ),

                title: const Text(
                  "Last Detected Sign",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: Text(
                  lastSign,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Information
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [

                    const Icon(
                      Icons.analytics,
                      size: 60,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      "Recognition Statistics",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "You have recognized "
                      "$totalSigns sign(s) so far.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Last recognized sign: $lastSign",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
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
}