import 'package:flutter/material.dart';

class LearnSignPage extends StatelessWidget {
  const LearnSignPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Language Alphabet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF0D47A1),
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Practice each hand sign before using the camera detection.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/images/sign_language_alphabet.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}