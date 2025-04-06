import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ReferencesGuide extends StatefulWidget {
  const ReferencesGuide({super.key});
  @override
  State<ReferencesGuide> createState() => _ReferencesGuideState();
}

class _ReferencesGuideState extends State<ReferencesGuide> {
  List<Map<String, String>> userReferences = [];

  final List<Map<String, String>> defaultReferences = [
    {'name': 'Codecademy', 'url': 'https://www.codecademy.com/'},
    {'name': 'Udemy', 'url': 'https://www.udemy.com/'},
    {'name': 'Duolingo', 'url': 'https://www.duolingo.com/'},
    {'name': 'Google Scholar', 'url': 'https://scholar.google.ca/'},
    {'name': 'freeCodeCamp', 'url': 'https://www.freecodecamp.org/'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserReference();
  }

  Future<void> _loadUserReference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? referencesJson = prefs.getString('userReferences');
    if (referencesJson != null) {
      setState(() {
        userReferences = List<Map<String, String>>.from(
          json
              .decode(referencesJson)
              .map((item) => Map<String, String>.from(item)),
        );
      });
    }
  }

  Future<void> _saveUserReference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userReferences', json.encode(userReferences));
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _addReference() {
    TextEditingController nameController = TextEditingController();
    TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Center(
            child: Text(
              'Add Reference',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL'),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    String name = nameController.text.trim();
                    String url = urlController.text.trim();

                    if (name.isNotEmpty && url.isNotEmpty) {
                      setState(() {
                        userReferences.add({'name': name, 'url': url});
                      });
                      _saveUserReference();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _deleteReference(int index) {
    setState(() {
      userReferences.removeAt(index);
    });
    _saveUserReference();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic References'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Center(
            child: Text(
              'Our Proud Partnered References',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          ...defaultReferences.map((reference) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.push_pin_rounded, color: Color.fromARGB(255, 149, 189, 130)),
                title: Text(reference['name']!),
                subtitle: Text(reference['url']!, style: const TextStyle(
                  color: Color.fromARGB(179, 139, 135, 135),
                ),),
                onTap: () => _launchURL(reference['url']!),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Your Added References',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          ...userReferences.map((reference) {
            return Dismissible(
              key: Key(reference['name']!),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: Color.fromARGB(255, 212, 99, 91),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) {
                _deleteReference(userReferences.indexOf(reference));
              },
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.link_rounded, color: Color.fromARGB(255, 214, 134, 184)),
                  title: Text(reference['name']!),
                  subtitle: Text(reference['url']!, style: const TextStyle(
                    color: Color.fromARGB(179, 139, 135, 135),
                  ),),
                  onTap: () => _launchURL(reference['url']!),
                ),
              ),
            );
          }).toList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReference,
        child: const Icon(Icons.add),
      ),
    );
  }
}
