// lib/screens/account_details_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountDetailsScreen extends StatefulWidget {
  final String? uid; // optional, useful for admin views
  final Future<void> Function(String)? onUsernameChanged;

  const AccountDetailsScreen({Key? key, this.uid, this.onUsernameChanged})
    : super(key: key);

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _username = '';
  String _email = '';
  bool _loading = true;
  bool _saving = false;

  String? get _effectiveUid => widget.uid ?? _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // LOAD: prefer FirebaseAuth.displayName (original username)
  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      _email = user?.email ?? 'no-email@example.com';
      // Use displayName as the "original" username
      _username = user?.displayName?.trim() ?? 'User';

      // If displayName missing, optionally read Firestore username
      final uid = _effectiveUid;
      if ((user?.displayName == null || user!.displayName!.trim().isEmpty) &&
          uid != null) {
        final snap = await _firestore.collection('users').doc(uid).get();
        final fsName = (snap.data()?['username'] as String?)?.trim();
        if (fsName != null && fsName.isNotEmpty) _username = fsName;
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      _username = _auth.currentUser?.displayName ?? 'User';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditUsernameDialog() async {
    final controller = TextEditingController(text: _username);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit username'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter a display name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Username cannot be empty';
                  if (value.trim().length < 3) return 'Minimum 3 characters';
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(controller.text.trim());
                  }
                },
                child: const Text('SAVE'),
              ),
            ],
          ),
    );

    if (result != null && result != _username) {
      await _updateUsername(result);
    }
  }

  // UPDATE: update FirebaseAuth.displayName (authoritative) and mirror to Firestore
  Future<void> _updateUsername(String newUsername) async {
    setState(() => _saving = true);
    final old = _username;
    setState(() => _username = newUsername);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Update FirebaseAuth displayName (authoritative)
        await user.updateDisplayName(newUsername);
        // reload to ensure currentUser reflects change
        await user.reload();
      }

      // Mirror to Firestore (optional but recommended)
      final uid = _effectiveUid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).set({
          'username': newUsername,
        }, SetOptions(merge: true));
      }

      // optional external hook
      if (widget.onUsernameChanged != null) {
        await widget.onUsernameChanged!(newUsername);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Username updated')));
      }
    } catch (e) {
      // rollback
      setState(() => _username = old);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update username: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              _username.isNotEmpty
                                  ? _username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            _username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(_email),
                          trailing:
                              _saving
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : IconButton(
                                    tooltip: 'Edit username',
                                    icon: const Icon(Icons.edit),
                                    onPressed: _showEditUsernameDialog,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Account',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(_email),
                        enabled: false,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Sign out'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (c) => AlertDialog(
                                  title: const Text('Sign out'),
                                  content: const Text(
                                    'Are you sure you want to sign out?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(c).pop(),
                                      child: const Text('CANCEL'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.of(c).pop();
                                        await FirebaseAuth.instance.signOut();
                                        if (mounted)
                                          Navigator.of(
                                            context,
                                          ).pushReplacementNamed('/login');
                                      },
                                      child: const Text('SIGN OUT'),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                      const Spacer(),
                      Center(
                        child: Text(
                          'Tap the pencil icon to edit your username.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
