import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountDetailsScreen extends StatefulWidget {
  final String? uid; // optional, for admin views
  final Future<void> Function(String)? onUsernameChanged;

  const AccountDetailsScreen({super.key, this.uid, this.onUsernameChanged});

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

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      _email = user?.email ?? 'no-email@example.com';
      _username = user?.displayName?.trim() ?? 'User';

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
            title: Text(
              'Edit username',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
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
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(context).pop(controller.text.trim());
                  }
                },
                child: Text(
                  'SAVE',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (result != null && result != _username) {
      await _updateUsername(result);
    }
  }

  Future<void> _updateUsername(String newUsername) async {
    setState(() => _saving = true);
    final old = _username;
    setState(() => _username = newUsername);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(newUsername);
        await user.reload();
      }

      final uid = _effectiveUid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).set({
          'username': newUsername,
        }, SetOptions(merge: true));
      }

      if (widget.onUsernameChanged != null) {
        await widget.onUsernameChanged!(newUsername);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Username updated', style: GoogleFonts.poppins()),
          ),
        );
      }
    } catch (e) {
      setState(() => _username = old);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update username: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF3E82C6);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: accentColor,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/logo/new_shield.png',
                        width: 100,
                        height: 100,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Account Details 👤',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage your personal information for a secure experience.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 3,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: accentColor.withOpacity(0.3),
                            child: Text(
                              _username.isNotEmpty
                                  ? _username[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: accentColor,
                              ),
                            ),
                          ),
                          title: Text(
                            _username,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            _email,
                            style: GoogleFonts.poppins(color: Colors.black54),
                          ),
                          trailing:
                              _saving
                                  ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                  : IconButton(
                                    tooltip: 'Edit username',
                                    icon: Icon(Icons.edit, color: accentColor),
                                    onPressed: _showEditUsernameDialog,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Account',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: Text(
                          'Email',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(_email, style: GoogleFonts.poppins()),
                        enabled: false,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: Text(
                          'Sign out',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (c) => AlertDialog(
                                  title: Text(
                                    'Sign out',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  content: Text(
                                    'Are you sure you want to sign out?',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(c).pop(),
                                      child: Text(
                                        'CANCEL',
                                        style: GoogleFonts.poppins(),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.of(c).pop();
                                        await FirebaseAuth.instance.signOut();
                                        if (mounted) {
                                          Navigator.of(
                                            context,
                                          ).pushReplacementNamed('/login');
                                        }
                                      },
                                      child: Text(
                                        'SIGN OUT',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                        ),
                                      ),
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
                          style: GoogleFonts.poppins(color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
      ),
    );
  }
}
