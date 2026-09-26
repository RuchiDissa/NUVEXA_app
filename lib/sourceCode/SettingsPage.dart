import 'package:flutter/material.dart';

import '../database/DatabaseHelper.dart';

import './NotificationService.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
  // DATABASE
  // ============================================================

  final DatabaseHelper _database = DatabaseHelper.instance;

  // ============================================================
  // SETTINGS VALUES
  // ============================================================

  bool _notificationsEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _challengeRemindersEnabled = true;
  bool _confirmDelete = true;

  int _weekStartDay = 1;

  String _dailyReminderTime = '20:00';

  // NEW: Independent challenge reminder time
  String _challengeReminderTime = '18:00';

  String _defaultActivityTime = '08:30';

  bool _isLoading = true;
  bool _isSaving = false;

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ============================================================
  // LOAD SETTINGS
  // ============================================================

  Future<void> _loadSettings() async {
    try {
      final settings = await _database.getSettings();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = (settings['notifications_enabled'] ?? 1) == 1;

        _dailyReminderEnabled = (settings['daily_reminder_enabled'] ?? 1) == 1;

        _challengeRemindersEnabled =
            (settings['challenge_reminders_enabled'] ?? 1) == 1;

        _confirmDelete = (settings['confirm_delete'] ?? 1) == 1;

        _weekStartDay = (settings['week_start_day'] ?? 1) as int;

        _dailyReminderTime =
            settings['daily_reminder_time']?.toString() ?? '20:00';

        // NEW: Load independent challenge reminder time
        _challengeReminderTime =
            settings['challenge_reminder_time']?.toString() ?? '18:00';

        _defaultActivityTime =
            settings['default_activity_time']?.toString() ?? '08:30';

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Unable to load settings.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SAVE SETTING
  // ============================================================

  Future<void> _saveSetting(
    Map<String, dynamic> values,
  ) async {
    try {
      if (mounted) {
        setState(() {
          _isSaving = true;
        });
      }

      await _database.updateSettings(values);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        'Unable to save setting.',
        isError: true,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? red : cardColor2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(String time) {
    try {
      final parts = time.split(':');

      if (parts.length < 2) {
        return time;
      }

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';

      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return time;
    }
  }

  // ============================================================
  // DAILY REMINDER TIME
  // ============================================================

  Future<void> _selectDailyReminderTime() async {
    final parts = _dailyReminderTime.split(':');

    int hour = 20;
    int minute = 0;

    if (parts.length >= 2) {
      hour = int.tryParse(parts[0]) ?? 20;
      minute = int.tryParse(parts[1]) ?? 0;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: hour,
        minute: minute,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accent,
              surface: cardColor,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final newTime = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() {
      _dailyReminderTime = newTime;
    });

    await _saveSetting({
      'daily_reminder_time': newTime,
    });

    if (!mounted) return;

    if (_notificationsEnabled) {
      await NotificationService.instance.syncNotifications();
    }

    if (!mounted) return;

    _showMessage(
      'Daily reminder time updated.',
    );
  }

  // ============================================================
  // CHALLENGE REMINDER TIME
  // ============================================================

  Future<void> _selectChallengeReminderTime() async {
    final parts = _challengeReminderTime.split(':');

    int hour = 18;
    int minute = 0;

    if (parts.length >= 2) {
      hour = int.tryParse(parts[0]) ?? 18;
      minute = int.tryParse(parts[1]) ?? 0;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: hour,
        minute: minute,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accent,
              surface: cardColor,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final newTime = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() {
      _challengeReminderTime = newTime;
    });

    await _saveSetting({
      'challenge_reminder_time': newTime,
    });

    if (!mounted) return;

    if (_notificationsEnabled && _challengeRemindersEnabled) {
      await NotificationService.instance.syncNotifications();
    }

    if (!mounted) return;

    _showMessage(
      'Challenge reminder time updated.',
    );
  }

  // ============================================================
  // DEFAULT ACTIVITY TIME
  // ============================================================

  Future<void> _selectDefaultActivityTime() async {
    final parts = _defaultActivityTime.split(':');

    int hour = 8;
    int minute = 30;

    if (parts.length >= 2) {
      hour = int.tryParse(parts[0]) ?? 8;
      minute = int.tryParse(parts[1]) ?? 30;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: hour,
        minute: minute,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accent,
              surface: cardColor,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final newTime = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() {
      _defaultActivityTime = newTime;
    });

    await _saveSetting({
      'default_activity_time': newTime,
    });

    if (!mounted) return;

    _showMessage(
      'Default activity time updated.',
    );
  }

  // ============================================================
  // WEEK START
  // ============================================================

  Future<void> _selectWeekStart() async {
    final selected = await showDialog<int>(
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
          title: const Text(
            'Week starts on',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRadioOption(
                value: 1,
                title: 'Monday',
                icon: Icons.calendar_today_rounded,
                dialogContext: dialogContext,
              ),
              _buildRadioOption(
                value: 7,
                title: 'Sunday',
                icon: Icons.calendar_month_rounded,
                dialogContext: dialogContext,
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _weekStartDay = selected;
    });

    await _saveSetting({
      'week_start_day': selected,
    });

    if (!mounted) return;

    _showMessage(
      'Week starts on ${selected == 1 ? 'Monday' : 'Sunday'}.',
    );
  }

  // ============================================================
  // RADIO OPTION
  // ============================================================

  Widget _buildRadioOption({
    required int value,
    required String title,
    required IconData icon,
    required BuildContext dialogContext,
  }) {
    final selected = _weekStartDay == value;

    return InkWell(
      onTap: () {
        Navigator.pop(dialogContext, value);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? accent : textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? textPrimary : textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? accent : textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATABASE INFORMATION
  // ============================================================

  Future<void> _showDatabaseInformation() async {
    try {
      final counts = await _database.getDatabaseCounts();

      if (!mounted) return;

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
            title: const Row(
              children: [
                Icon(
                  Icons.storage_rounded,
                  color: accent,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Database Information',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDatabaseRow(
                  'Database',
                  'addiction_tracker.db',
                ),
                _buildDatabaseRow(
                  'Version',
                  '7',
                ),
                _buildDatabaseRow(
                  'Activities',
                  '${counts['activities'] ?? 0}',
                ),
                _buildDatabaseRow(
                  'Completed activities',
                  '${counts['completed_activities'] ?? 0}',
                ),
                _buildDatabaseRow(
                  'Challenge days',
                  '${counts['challenge_days'] ?? 0}',
                ),
                _buildDatabaseRow(
                  'Completed challenge days',
                  '${counts['completed_challenge_days'] ?? 0}',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withOpacity(0.20),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: accent,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your activity and settings data are stored locally on this device.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (_) {
      _showMessage(
        'Unable to read database information.',
        isError: true,
      );
    }
  }

  // ============================================================
  // DATABASE ROW
  // ============================================================

  Widget _buildDatabaseRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESET ACTIVITY DATA
  // ============================================================

  Future<void> _resetActivityData() async {
    final firstConfirmation = await showDialog<bool>(
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
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: orange,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reset Activity Data?',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'This will permanently remove all activities, challenge days, and their completion progress.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'CONTINUE',
                style: TextStyle(
                  color: orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (firstConfirmation != true) return;

    if (!mounted) return;

    final secondConfirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: red.withOpacity(0.35),
            ),
          ),
          title: const Text(
            'Are you absolutely sure?',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'This action cannot be undone. Your profile and settings will remain, but all activity data will be deleted.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'DELETE ALL',
                style: TextStyle(
                  color: red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (secondConfirmation != true) return;

    try {
      await _database.resetAllActivities();

      await NotificationService.instance.syncNotifications();

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to reset activity data.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        24,
        4,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accent.withOpacity(0.18),
              ),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SETTINGS CARD
  // ============================================================

  Widget _buildSettingsCard({
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // SWITCH TILE
  // ============================================================

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool)? onChanged,
    Color iconColor = accent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged == null
                ? null
                : (bool newValue) async {
                    await onChanged(newValue);
                  },
            activeColor: accent,
            activeTrackColor: accent.withOpacity(0.35),
            inactiveThumbColor: textSecondary,
            inactiveTrackColor: border,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION TILE
  // ============================================================

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = accent,
    bool showArrow = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (showArrow)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: textSecondary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: border,
      indent: 66,
      endIndent: 14,
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: accent,
        strokeWidth: 2.5,
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

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _isLoading
          ? _buildLoading()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  30,
                ),
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.14),
                          cardColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: accent.withOpacity(0.25),
                            ),
                          ),
                          child: Image.asset(
                            'images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.settings_rounded,
                                color: accent,
                                size: 28,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NUVEXA Settings',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Customize your experience and preferences.',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // NOTIFICATIONS
                  // ==================================================

                  _buildSectionHeader(
                    'Notifications',
                    Icons.notifications_none_rounded,
                  ),

                  _buildSettingsCard(
                    child: Column(
                      children: [
                        // ==================================================
                        // MASTER NOTIFICATIONS
                        // ==================================================

                        _buildSwitchTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Notifications',
                          subtitle: 'Allow NUVEXA to send notifications.',
                          value: _notificationsEnabled,

                          // ==================================================
                          // NOTIFICATION HANDLER
                          // ==================================================

                          onChanged: (value) async {
                            setState(() {
                              _notificationsEnabled = value;
                            });

                            await _saveSetting({
                              'notifications_enabled': value ? 1 : 0,
                            });

                            if (value) {
                              // ------------------------------------------
                              // REQUEST NOTIFICATION PERMISSION
                              // ------------------------------------------

                              final granted = await NotificationService.instance
                                  .requestPermissions();

                              if (!granted) {
                                if (!mounted) return;

                                setState(() {
                                  _notificationsEnabled = false;
                                });

                                await _saveSetting({
                                  'notifications_enabled': 0,
                                });

                                if (!mounted) return;

                                _showMessage(
                                  'Notification permission was not granted.',
                                  isError: true,
                                );

                                return;
                              }

                              // ------------------------------------------
                              // REQUEST EXACT ALARM PERMISSION
                              // ------------------------------------------

                              await NotificationService.instance
                                  .requestExactAlarmPermission();

                              // ------------------------------------------
                              // SYNC SCHEDULED NOTIFICATIONS
                              // ------------------------------------------

                              await NotificationService.instance
                                  .syncNotifications();

                              // ------------------------------------------
                              // IMMEDIATE TEST NOTIFICATION
                              // ------------------------------------------

                              await NotificationService.instance
                                  .showTestNotification();

                              if (!mounted) return;

                              _showMessage(
                                'Notifications enabled. Test notification sent.',
                              );
                            } else {
                              // ------------------------------------------
                              // CANCEL ALL NOTIFICATIONS
                              // ------------------------------------------

                              await NotificationService.instance
                                  .cancelAllNotifications();

                              if (!mounted) return;

                              _showMessage(
                                'Notifications disabled.',
                              );
                            }
                          },
                        ),

                        _buildDivider(),

                        // ==================================================
                        // DAILY REMINDERS
                        // ==================================================

                        _buildSwitchTile(
                          icon: Icons.alarm_rounded,
                          title: 'Daily reminders',
                          subtitle:
                              'Receive a daily reminder to stay on track.',
                          value: _dailyReminderEnabled,
                          onChanged: !_notificationsEnabled
                              ? null
                              : (value) async {
                                  setState(() {
                                    _dailyReminderEnabled = value;
                                  });

                                  await _saveSetting({
                                    'daily_reminder_enabled': value ? 1 : 0,
                                  });

                                  await NotificationService.instance
                                      .syncNotifications();

                                  if (!mounted) return;

                                  _showMessage(
                                    value
                                        ? 'Daily reminders enabled.'
                                        : 'Daily reminders disabled.',
                                  );
                                },
                        ),

                        _buildDivider(),

                        // ==================================================
                        // DAILY REMINDER TIME
                        // ==================================================

                        _buildActionTile(
                          icon: Icons.schedule_rounded,
                          title: 'Daily reminder time',
                          subtitle: _formatTime(
                            _dailyReminderTime,
                          ),
                          onTap:
                              !_notificationsEnabled || !_dailyReminderEnabled
                                  ? () {}
                                  : _selectDailyReminderTime,
                          iconColor: cyan,
                        ),

                        _buildDivider(),

                        // ==================================================
                        // CHALLENGE REMINDERS
                        // ==================================================

                        _buildSwitchTile(
                          icon: Icons.flag_outlined,
                          title: 'Challenge reminders',
                          subtitle: 'Get reminders about active challenges.',
                          value: _challengeRemindersEnabled,
                          onChanged: !_notificationsEnabled
                              ? null
                              : (value) async {
                                  setState(() {
                                    _challengeRemindersEnabled = value;
                                  });

                                  await _saveSetting({
                                    'challenge_reminders_enabled':
                                        value ? 1 : 0,
                                  });

                                  await NotificationService.instance
                                      .syncNotifications();

                                  if (!mounted) return;

                                  _showMessage(
                                    value
                                        ? 'Challenge reminders enabled.'
                                        : 'Challenge reminders disabled.',
                                  );
                                },
                          iconColor: purple,
                        ),

                        _buildDivider(),

                        // ==================================================
                        // CHALLENGE REMINDER TIME
                        // ==================================================

                        _buildActionTile(
                          icon: Icons.flag_circle_outlined,
                          title: 'Challenge reminder time',
                          subtitle: _formatTime(
                            _challengeReminderTime,
                          ),
                          onTap: !_notificationsEnabled ||
                                  !_challengeRemindersEnabled
                              ? () {}
                              : _selectChallengeReminderTime,
                          iconColor: purple,
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // PREFERENCES
                  // ==================================================

                  _buildSectionHeader(
                    'Preferences',
                    Icons.tune_rounded,
                  ),

                  _buildSettingsCard(
                    child: Column(
                      children: [
                        _buildActionTile(
                          icon: Icons.calendar_today_rounded,
                          title: 'Week starts on',
                          subtitle: _weekStartDay == 1 ? 'Monday' : 'Sunday',
                          onTap: _selectWeekStart,
                          iconColor: accent,
                        ),
                        _buildDivider(),
                        _buildActionTile(
                          icon: Icons.access_time_rounded,
                          title: 'Default activity time',
                          subtitle: _formatTime(
                            _defaultActivityTime,
                          ),
                          onTap: _selectDefaultActivityTime,
                          iconColor: cyan,
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.delete_outline_rounded,
                          title: 'Confirm before deleting',
                          subtitle:
                              'Ask for confirmation before removing an activity.',
                          value: _confirmDelete,
                          onChanged: (value) async {
                            setState(() {
                              _confirmDelete = value;
                            });

                            await _saveSetting({
                              'confirm_delete': value ? 1 : 0,
                            });
                          },
                          iconColor: orange,
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // LOCAL DATA
                  // ==================================================

                  _buildSectionHeader(
                    'Local Data',
                    Icons.storage_rounded,
                  ),

                  _buildSettingsCard(
                    child: Column(
                      children: [
                        _buildActionTile(
                          icon: Icons.storage_outlined,
                          title: 'Database information',
                          subtitle: 'View local database statistics.',
                          onTap: _showDatabaseInformation,
                          iconColor: cyan,
                        ),
                        _buildDivider(),
                        _buildActionTile(
                          icon: Icons.delete_sweep_outlined,
                          title: 'Reset activity data',
                          subtitle:
                              'Delete all activities and challenge progress.',
                          onTap: _resetActivityData,
                          iconColor: red,
                          showArrow: false,
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // ABOUT
                  // ==================================================

                  _buildSectionHeader(
                    'About',
                    Icons.info_outline_rounded,
                  ),

                  _buildSettingsCard(
                    child: Column(
                      children: [
                        _buildActionTile(
                          icon: Icons.auto_awesome_rounded,
                          title: 'NUVEXA',
                          subtitle: 'Version 1.0.0',
                          onTap: () {},
                          iconColor: accent,
                          showArrow: false,
                        ),
                        _buildDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            14,
                            13,
                            14,
                            15,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: green.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.security_rounded,
                                  color: green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Local-first storage',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Your NUVEXA activity data is stored locally on your device.',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // FOOTER
                  // ==================================================

                  Center(
                    child: Column(
                      children: [
                        Text(
                          'NUVEXA',
                          style: TextStyle(
                            color: accent.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Build better habits. Build a better life.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 10,
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
}
