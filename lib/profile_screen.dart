import 'package:flutter/material.dart';
import 'package:studify/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final client = Supabase.instance.client;
final user = client.auth.currentUser!;


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future? _profile;

  Future<bool> _confirmDelete(BuildContext context) async {
    var confirmed = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to delete this profile?'),
          titlePadding: const EdgeInsets.all(20),
          content: Text('Deleting this profile will delete all courses, topics, and notes.'),
          contentPadding: const EdgeInsets.all(20),
          actions: [
            TextButton(
              onPressed: () {
                confirmed = true;
                if (context.mounted) Navigator.pop(context);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.error),
              ),
              child: Text('Yes',
                style: TextStyle(color: Theme.of(context).colorScheme.surface),
              ),
            ),
            TextButton(
              onPressed: () {
                confirmed = false;
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
    return confirmed;
  }

  void _deleteUser(BuildContext context) async {
    await client.auth.admin.deleteUser(user.id);
    await client
      .from('profiles')
      .delete()
      .eq('id', user.id);
    if (context.mounted) _goLogin(context);
  }

  void _goLogin(BuildContext context) {
    Navigator.pushReplacement(context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(),
      ),
    );
  }

  void _loadProfile() async {
    _profile = client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .single();
  }

  void _signOut(BuildContext context) {
    client.auth.signOut();
    _goLogin(context);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder(
                  future: _profile,
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    return snapshot.hasData ? ProfileCard(profile: profile) : CircularProgressIndicator();
                  },
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sign Out'),
                        IconButton(
                          onPressed: () => _signOut(context),
                          icon: Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final confirmed = await _confirmDelete(context);
                  if (confirmed && context.mounted) _deleteUser(context);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.error),
                ),
                child: Text('Delete profile',
                  style: TextStyle(color: Theme.of(context).colorScheme.surface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ProfileCard extends StatefulWidget {
  final Map profile;

  const ProfileCard({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  final _usernameController = TextEditingController();

  void _updateUsername() async {
    final username = _usernameController.text.trim();
    await client
      .from('profiles')
      .update({'username': username})
      .eq('id', user.id);
    _usernameController.text = username;
  }

  @override
  void initState() {
    super.initState();
    if (widget.profile['username'] != null) _usernameController.text = widget.profile['username'];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 20,
          children: [
            Expanded(
              child: TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Username',
                  border: InputBorder.none,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => _updateUsername(),
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}