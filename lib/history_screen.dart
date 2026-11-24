import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  final List<String> history;

  const HistoryScreen({
    super.key,
    required this.history,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                widget.history.clear();
              });
            },
          ),
        ],
      ),
      body: widget.history.isEmpty
          ? const Center(
              child: Text(
                "No signs detected yet",
                style: TextStyle(fontSize: 20),
              ),
            )
          : ListView.builder(
              itemCount: widget.history.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(widget.history[index]),
                );
              },
            ),
    );
  }
}

