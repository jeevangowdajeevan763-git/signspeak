import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class GalleryScreen extends StatefulWidget {
  final List<String> images;

  const GalleryScreen({
    super.key,
    required this.images,
  });

  @override
  State<GalleryScreen> createState() =>
      _GalleryScreenState();
}

class _GalleryScreenState
    extends State<GalleryScreen> {
  late List<String> images;

  @override
  void initState() {
    super.initState();
    images = widget.images;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text("Gallery"),
  actions: [
    IconButton(
      icon: const Icon(Icons.delete_forever),
      onPressed: () async {
        final prefs =
            await SharedPreferences.getInstance();

        setState(() {
          images.clear();
        });

        await prefs.remove('captured_images');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "All photos deleted",
            ),
          ),
        );
      },
    ),
  ],
),
      body: images.isEmpty
          ? const Center(
              child: Text("No Images Found"),
            )
          : ListView.builder(
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      Image.file(
                        File(images[index]),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final prefs =
                                await SharedPreferences
                                    .getInstance();

                            final file =
                                File(images[index]);

                            if (file.existsSync()) {
                              file.deleteSync();
                            }

                            setState(() {
                              images.removeAt(index);
                            });

                            await prefs.setStringList(
                              'captured_images',
                              images,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}