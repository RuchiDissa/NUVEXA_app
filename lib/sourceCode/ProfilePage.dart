import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database/DatabaseHelper.dart';

import 'SettingsPage.dart';

class ProfilePage extends StatefulWidget {
  final Future<void> Function()? onDataChanged;

  const ProfilePage({
    super.key,
    this.onDataChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ============================================================
  // NUVEXA COLORS
  // ============================================================

  static const Color background = Color(0xFF020617);
  static const Color cardColor = Color(0xFF0F172A);
  static const Color cardColor2 = Color(0xFF111C32);
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentDark = Color(0xFF0EA5E9);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color border = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color green = Color(0xFF22C55E);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFFA78BFA);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _usernameController = TextEditingController();

  final TextEditingController _nicknameController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  bool _isSaving = false;

  String _username = 'NUVEXA User';
  String _nickname = '';
  String? _profileImage;

  int _totalActivities = 0;
  int _completedActivities = 0;
  int _totalChallenges = 0;
  int _completedChallenges = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE DATA
  // ============================================================

  Future<void> _loadProfileData() async {
    try {
      final profile = await DatabaseHelper.instance.getProfile();

      if (!mounted) return;

      final activities = await DatabaseHelper.instance.getActivities();

      if (!mounted) return;

      final challengeDays = await DatabaseHelper.instance.getAllChallengeDays();

      if (!mounted) return;

      final totalActivities = activities.length;

      final completedActivities = activities.where((activity) {
        return (activity['is_completed'] ?? 0) == 1;
      }).length;

      final totalChallenges = challengeDays.length;

      final completedChallenges = challengeDays.where((day) {
        return (day['is_completed'] ?? 0) == 1;
      }).length;

      final streakData = _calculateStreaks(challengeDays);

      if (!mounted) return;

      setState(() {
        _username = profile['username']?.toString().trim().isNotEmpty == true
            ? profile['username'].toString()
            : 'NUVEXA User';

        _nickname = profile['nickname']?.toString() ?? '';

        final image = profile['profile_image']?.toString();

        _profileImage = image != null && image.trim().isNotEmpty ? image : null;

        _usernameController.text = _username;
        _nicknameController.text = _nickname;

        _totalActivities = totalActivities;
        _completedActivities = completedActivities;

        _totalChallenges = totalChallenges;
        _completedChallenges = completedChallenges;

        _currentStreak = streakData['current'] ?? 0;
        _bestStreak = streakData['best'] ?? 0;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Error loading profile data: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnackBar(
        'Unable to load profile data.',
        isError: true,
      );
    }
  }

  // ============================================================
  // STREAK CALCULATION
  // ============================================================

  Map<String, int> _calculateStreaks(
    List<Map<String, dynamic>> challengeDays,
  ) {
    final completedDates = <DateTime>{};

    for (final day in challengeDays) {
      if ((day['is_completed'] ?? 0) == 1) {
        final dateString = day['challenge_date']?.toString();

        if (dateString == null || dateString.isEmpty) {
          continue;
        }

        final parsedDate = DateTime.tryParse(dateString);

        if (parsedDate != null) {
          completedDates.add(
            DateTime(
              parsedDate.year,
              parsedDate.month,
              parsedDate.day,
            ),
          );
        }
      }
    }

    if (completedDates.isEmpty) {
      return {
        'current': 0,
        'best': 0,
      };
    }

    final sortedDates = completedDates.toList()..sort((a, b) => a.compareTo(b));

    int bestStreak = 1;
    int runningStreak = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final difference = sortedDates[i].difference(sortedDates[i - 1]).inDays;

      if (difference == 1) {
        runningStreak++;
      } else {
        runningStreak = 1;
      }

      if (runningStreak > bestStreak) {
        bestStreak = runningStreak;
      }
    }

    final today = DateTime.now();

    final todayDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final yesterday = todayDate.subtract(
      const Duration(days: 1),
    );

    int currentStreak = 0;

    if (completedDates.contains(todayDate)) {
      DateTime checkDate = todayDate;

      while (completedDates.contains(checkDate)) {
        currentStreak++;

        checkDate = checkDate.subtract(
          const Duration(days: 1),
        );
      }
    } else if (completedDates.contains(yesterday)) {
      DateTime checkDate = yesterday;

      while (completedDates.contains(checkDate)) {
        currentStreak++;

        checkDate = checkDate.subtract(
          const Duration(days: 1),
        );
      }
    }

    return {
      'current': currentStreak,
      'best': bestStreak,
    };
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile({
    String? username,
    String? nickname,
    String? profileImage,
  }) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final newUsername = username ?? _usernameController.text.trim();

      final newNickname = nickname ?? _nicknameController.text.trim();

      final newImage = profileImage ?? _profileImage;

      await DatabaseHelper.instance.updateProfile(
        username: newUsername.isEmpty ? 'NUVEXA User' : newUsername,
        nickname: newNickname,
        profileImage: newImage,
      );

      if (!mounted) return;

      setState(() {
        _username = newUsername.isEmpty ? 'NUVEXA User' : newUsername;

        _nickname = newNickname;
        _profileImage = newImage;
        _isSaving = false;
      });

      _showSnackBar(
        'Profile updated successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showSnackBar(
        'Unable to save profile.',
        isError: true,
      );
    }
  }

  // ============================================================
  // PICK PROFILE IMAGE
  // ============================================================

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (!mounted) return;

      if (image == null) {
        return;
      }

      await _saveProfile(
        profileImage: image.path,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to select profile image.',
        isError: true,
      );
    }
  }

  // ============================================================
  // REMOVE PROFILE IMAGE
  // ============================================================

  Future<void> _removeProfileImage() async {
    await _saveProfile(
      profileImage: null,
    );
  }

  // ============================================================
  // USERNAME DIALOG
  // ============================================================

  Future<void> _showUsernameDialog() async {
    final controller = TextEditingController(
      text: _username,
    );

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(
                color: border,
              ),
            ),
            title: const Text(
              'Edit Username',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                color: textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter username',
                hintStyle: const TextStyle(
                  color: textSecondary,
                ),
                filled: true,
                fillColor: background,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: accent,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: background,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    controller.text.trim(),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (result != null && result.trim().isNotEmpty) {
        _usernameController.text = result.trim();

        await _saveProfile(
          username: result.trim(),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // NICKNAME DIALOG
  // ============================================================

  Future<void> _showNicknameDialog() async {
    final controller = TextEditingController(
      text: _nickname,
    );

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(
                color: border,
              ),
            ),
            title: const Text(
              'Edit Nickname',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                color: textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter nickname',
                hintStyle: const TextStyle(
                  color: textSecondary,
                ),
                filled: true,
                fillColor: background,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: accent,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: background,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    controller.text.trim(),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (result != null) {
        _nicknameController.text = result.trim();

        await _saveProfile(
          nickname: result.trim(),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // PROFILE IMAGE OPTIONS
  // ============================================================

  void _showProfileImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: accent,
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      color: textPrimary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    await _pickProfileImage();
                  },
                ),
                if (_profileImage != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: red,
                    ),
                    title: const Text(
                      'Remove Picture',
                      style: TextStyle(
                        color: red,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);

                      await _removeProfileImage();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<void> _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );

    if (!mounted) return;

    // Always refresh ProfilePage after returning.
    await _loadProfileData();

    // If Settings changed/deleted activity data,
    // notify MyHomePage as well.
    if (result == true) {
      await widget.onDataChanged?.call();
    }
  }

  // ============================================================
  // NOTIFICATION SETTINGS
  // ============================================================

  Future<void> _openNotificationSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );

    if (!mounted) return;

    // Refresh ProfilePage when returning from Settings.
    await _loadProfileData();

    // Notify the main page if Settings changed data.
    if (result == true) {
      await widget.onDataChanged?.call();
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? red : cardColor2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // PROFILE AVATAR
  // ============================================================

  Widget _buildProfileAvatar() {
    final hasImage = _profileImage != null &&
        _profileImage!.trim().isNotEmpty &&
        File(_profileImage!).existsSync();

    return GestureDetector(
      onTap: _showProfileImageOptions,
      child: Stack(
        children: [
          Container(
            width: 105,
            height: 105,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.25),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipOval(
              child: hasImage
                  ? Image.file(
                      File(_profileImage!),
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      'images/logo.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: background,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: background,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 27,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = accent,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: textSecondary,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 3,
        bottom: 10,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  // ============================================================
  // COMPLETION CARD
  // ============================================================

  Widget _buildCompletionCard({
    required String title,
    required int completed,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final double progress = total == 0 ? 0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 23,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$completed / $total',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: border,
              valueColor: AlwaysStoppedAnimation<Color>(
                color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'PROFILE',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: textSecondary,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: accent,
              ),
            )
          : RefreshIndicator(
              color: accent,
              backgroundColor: cardColor,
              onRefresh: _loadProfileData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  30,
                ),
                children: [
                  Center(
                    child: Column(
                      children: [
                        _buildProfileAvatar(),
                        const SizedBox(height: 16),
                        Text(
                          _username,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_nickname.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            '@$_nickname',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'Building better habits with NUVEXA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle(
                    'Personal Information',
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.person_outline,
                          title: 'Username',
                          subtitle: 'Edit your username',
                          onTap: _showUsernameDialog,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _buildInfoItem(
                    icon: Icons.badge_outlined,
                    title: 'Nickname',
                    subtitle: _nickname.isEmpty ? 'Add a nickname' : _nickname,
                    onTap: _showNicknameDialog,
                    iconColor: cyan,
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle(
                    'Your Statistics',
                  ),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;

                      final crossAxisCount = width >= 700 ? 4 : 2;

                      final itemWidth = (width - ((crossAxisCount - 1) * 10)) /
                          crossAxisCount;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _buildStatCard(
                              icon: Icons.task_alt,
                              value: '$_completedActivities',
                              label: 'Completed Activities',
                              color: green,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildStatCard(
                              icon: Icons.list_alt,
                              value: '$_totalActivities',
                              label: 'Total Activities',
                              color: accent,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildStatCard(
                              icon: Icons.local_fire_department,
                              value: '$_currentStreak',
                              label: 'Current Streak',
                              color: orange,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildStatCard(
                              icon: Icons.emoji_events_outlined,
                              value: '$_bestStreak',
                              label: 'Best Streak',
                              color: purple,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle(
                    'Progress Overview',
                  ),

                  _buildCompletionCard(
                    title: 'Activities',
                    completed: _completedActivities,
                    total: _totalActivities,
                    color: green,
                    icon: Icons.check_circle_outline,
                  ),

                  const SizedBox(height: 10),

                  _buildCompletionCard(
                    title: 'Challenge Days',
                    completed: _completedChallenges,
                    total: _totalChallenges,
                    color: purple,
                    icon: Icons.flag_outlined,
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle('App'),

                  _buildInfoItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Customize your NUVEXA experience',
                    onTap: _openSettings,
                    iconColor: accent,
                  ),

                  const SizedBox(height: 10),

                  // ========================================================
                  // NOTIFICATIONS
                  // ========================================================
                  _buildInfoItem(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    subtitle: 'Manage reminders and alerts',
                    onTap: _openNotificationSettings,
                    iconColor: orange,
                  ),

                  const SizedBox(height: 10),

                  _buildInfoItem(
                    icon: Icons.info_outline,
                    title: 'About NUVEXA',
                    subtitle: 'App information and version',
                    onTap: _showAboutDialog,
                    iconColor: cyan,
                  ),

                  const SizedBox(height: 25),

                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'images/logo.png',
                          width: 42,
                          height: 42,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'NUVEXA',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Build better. Live better.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // ABOUT DIALOG
  // ============================================================

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: border,
            ),
          ),
          title: Row(
            children: [
              Image.asset(
                'images/logo.png',
                width: 38,
                height: 38,
              ),
              const SizedBox(width: 12),
              const Text(
                'NUVEXA',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          content: const Text(
            'NUVEXA is a personal habit and activity '
            'management application designed to help you '
            'build consistency, track progress, complete '
            'challenges, and understand your personal growth.\n\n'
            'All core data is stored locally on your device.',
            style: TextStyle(
              color: textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Close',
                style: TextStyle(
                  color: accent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
