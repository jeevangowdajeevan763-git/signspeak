import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double speechSpeed = 0.5;
double speechPitch = 1.0;
String selectedLanguage = "English";
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),

          // PROFILE
          const CircleAvatar(
            radius: 45,
            child: Icon(
              Icons.person,
              size: 50,
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              user?.displayName ?? "User",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              user?.email ?? "No email",
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 25),

          // APP SETTINGS
          const Text(
            "App Settings",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // DARK MODE
          SwitchListTile(
            value: context.watch<ThemeProvider>().isDarkMode,
            onChanged: (value) {
              context.read<ThemeProvider>().toggleTheme(value);
            },
            secondary: const Icon(Icons.dark_mode),
            title: const Text("Dark Mode"),
          ),

          // LANGUAGE
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: const Text("English"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text("Choose Language"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: const Text("English"),
                          onTap: () {
                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("English Selected"),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: const Text("Kannada"),
                          onTap: () {
                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Kannada Selected"),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: const Text("Hindi"),
                          onTap: () {
                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Hindi Selected"),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Text("Cancel"),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          // VOICE SETTINGS
         ListTile(
  leading: const Icon(Icons.volume_up),
  title: const Text("Voice Settings"),
  subtitle: Text(
    "Speed: ${speechSpeed.toStringAsFixed(1)} | "
    "Pitch: ${speechPitch.toStringAsFixed(1)}",
  ),
  trailing: const Icon(Icons.arrow_forward_ios),
  onTap: () {
    double tempSpeed = speechSpeed;
    double tempPitch = speechPitch;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text("Voice Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Speech Speed",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Slider(
                    value: tempSpeed,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: tempSpeed.toStringAsFixed(1),
                    onChanged: (value) {
                      setDialogState(() {
                        tempSpeed = value;
                      });
                    },
                  ),

                  Text(
                    "Speed: ${tempSpeed.toStringAsFixed(1)}",
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Pitch",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Slider(
                    value: tempPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: tempPitch.toStringAsFixed(1),
                    onChanged: (value) {
                      setDialogState(() {
                        tempPitch = value;
                      });
                    },
                  ),

                  Text(
                    "Pitch: ${tempPitch.toStringAsFixed(1)}",
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final prefs =
                        await SharedPreferences.getInstance();

                    await prefs.setDouble(
                      'speechSpeed',
                      tempSpeed,
                    );

                    await prefs.setDouble(
                      'speechPitch',
                      tempPitch,
                    );

                    setState(() {
                      speechSpeed = tempSpeed;
                      speechPitch = tempPitch;
                    });

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Voice settings saved",
                        ),
                      ),
                    );
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  },
),

          const Divider(),

          // DATA
          const Text(
            "Data",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text("Clear History"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("History Cleared"),
                ),
              );
            },
          ),

          const Divider(),

          // ABOUT
          const Text(
            "About",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About App"),
            subtitle: const Text("SignSpeak v1.0"),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text("About SignSpeak"),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sign_language,
                          size: 60,
                          color: Colors.deepPurple,
                        ),

                        SizedBox(height: 15),

                        Text(
                          "SignSpeak v1.0",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 10),

                        Text(
                          "AI Powered Sign Language Recognition App",
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 15),

                        Text(
                          "Developed by Jeevan Gowda",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Text("OK"),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const Divider(),

          // LOGOUT
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            title: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text("Logout"),
                    content: const Text(
                      "Are you sure you want to logout?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Text("Cancel"),
                      ),

                      TextButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);

                          await FirebaseAuth.instance.signOut();

                          if (!context.mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "Logout",
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}