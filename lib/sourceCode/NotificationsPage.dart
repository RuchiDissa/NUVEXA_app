import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database/DatabaseHelper.dart';
import 'NotificationService.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color background = Color(0xFF020617);

  static const Color cardColor = Color(0xFF0F172A);

  static const Color cardColor2 = Color(0xFF111C32);

  static const Color accent = Color(0xFF38BDF8);

  static const Color accentDark = Color(0xFF0EA5E9);

  static const Color cyan = Color(0xFF22D3EE);

  static const Color border = Color(0xFF1E293B);

  // ============================================================
  // DATA
  // ============================================================

  List<PendingNotificationRequest> _pendingNotifications = [];

  Map<String, dynamic> _settings = {};

  bool _isLoading = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadNotifications();
  }

  // ============================================================
  // LOAD ALL NOTIFICATIONS
  // ============================================================

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await NotificationService.instance.initialize();

      // Sync current notification settings first.
      await NotificationService.instance.syncNotifications();

      final settings = await DatabaseHelper.instance.getSettings();

      final pending =
          await NotificationService.instance.getPendingNotifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;
        _pendingNotifications = pending;
        _isLoading = false;
      });

      debugPrint(
        'Notification page loaded.',
      );

      debugPrint(
        'Pending notifications: '
        '${pending.length}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Error loading notifications: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // BOOLEAN SETTING
  // ============================================================

  bool _settingIsEnabled(
    dynamic value,
  ) {
    if (value == null) {
      return false;
    }

    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    if (value is String) {
      final String lower = value.toLowerCase().trim();

      return lower == '1' || lower == 'true' || lower == 'yes';
    }

    return false;
  }

  // ============================================================
  // MASTER NOTIFICATIONS ENABLED
  // ============================================================

  bool get _notificationsEnabled {
    return _settingIsEnabled(
      _settings['notifications_enabled'],
    );
  }

  // ============================================================
  // DAILY REMINDER ENABLED
  // ============================================================

  bool get _dailyReminderEnabled {
    return _notificationsEnabled &&
        _settingIsEnabled(
          _settings['daily_reminder_enabled'],
        );
  }

  // ============================================================
  // CHALLENGE REMINDER ENABLED
  // ============================================================

  bool get _challengeReminderEnabled {
    return _notificationsEnabled &&
        _settingIsEnabled(
          _settings['challenge_reminders_enabled'],
        );
  }

  // ============================================================
  // CHECK PENDING
  // ============================================================

  bool _isPending(int id) {
    return _pendingNotifications.any(
      (notification) => notification.id == id,
    );
  }

  // ============================================================
  // DAILY TIME
  // ============================================================

  String get _dailyReminderTime {
    return _settings['daily_reminder_time']?.toString() ?? '20:00';
  }

  // ============================================================
  // CHALLENGE TIME
  // ============================================================

  String get _challengeReminderTime {
    return _settings['challenge_reminder_time']?.toString() ?? '18:00';
  }

  // ============================================================
  // DELETE NOTIFICATION
  // ============================================================

  Future<void> _deleteNotification(
    int id,
    String title,
  ) async {
    final bool? confirmed = await _showDeleteConfirmation(
      title,
    );

    if (confirmed != true) {
      return;
    }

    try {
      await NotificationService.instance.cancelNotification(id);

      await _loadNotifications();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification deleted.',
          ),
          backgroundColor: cardColor2,
        ),
      );
    } catch (e) {
      debugPrint(
        'Error deleting notification: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not delete notification.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<bool?> _showDeleteConfirmation(
    String title,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Notification?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Keep',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadNotifications,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: accent,
          backgroundColor: cardColor,
          onRefresh: _loadNotifications,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildScheduledSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final int notificationCount = _getDisplayCount();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor2,
            cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: accent,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stay on track',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  notificationCount == 0
                      ? 'You have no notifications configured.'
                      : '$notificationCount notification'
                          '${notificationCount == 1 ? '' : 's'} available.',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPLAY COUNT
  // ============================================================

  int _getDisplayCount() {
    int count = 0;

    if (_dailyReminderEnabled) {
      count++;
    }

    if (_challengeReminderEnabled) {
      count++;
    }

    for (final notification in _pendingNotifications) {
      final bool known =
          notification.id == NotificationService.dailyReminderId ||
              notification.id == NotificationService.challengeReminderId;

      if (!known) {
        count++;
      }
    }

    return count;
  }

  // ============================================================
  // SCHEDULED SECTION
  // ============================================================

  Widget _buildScheduledSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ALL NOTIFICATIONS',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          _buildLoadingCard()
        else if (_getDisplayCount() == 0)
          _buildEmptyCard()
        else ...[
          if (_dailyReminderEnabled)
            Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _buildDailyReminderCard(),
            ),
          if (_challengeReminderEnabled)
            Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: _buildChallengeReminderCard(),
            ),
          ..._buildOtherPendingCards(),
        ],
      ],
    );
  }

  // ============================================================
  // DAILY REMINDER CARD
  // ============================================================

  Widget _buildDailyReminderCard() {
    final bool pending = _isPending(
      NotificationService.dailyReminderId,
    );

    return _buildNotificationCard(
      id: NotificationService.dailyReminderId,
      icon: Icons.today_rounded,
      iconColor: accent,
      title: 'NUVEXA Daily Reminder',
      message: 'Take a moment to check in with your goals today.',
      type: 'Daily Reminder',
      time: _formatTime(
        _dailyReminderTime,
      ),
      pending: pending,
    );
  }

  // ============================================================
  // CHALLENGE REMINDER CARD
  // ============================================================

  Widget _buildChallengeReminderCard() {
    final bool pending = _isPending(
      NotificationService.challengeReminderId,
    );

    return _buildNotificationCard(
      id: NotificationService.challengeReminderId,
      icon: Icons.flag_rounded,
      iconColor: cyan,
      title: "Today's Challenge",
      message:
          'You have an incomplete challenge for today. Keep going with NUVEXA!',
      type: 'Challenge Reminder',
      time: _formatTime(
        _challengeReminderTime,
      ),
      pending: pending,
    );
  }

  // ============================================================
  // OTHER PENDING NOTIFICATIONS
  // ============================================================

  List<Widget> _buildOtherPendingCards() {
    final List<Widget> cards = [];

    for (final notification in _pendingNotifications) {
      final bool known =
          notification.id == NotificationService.dailyReminderId ||
              notification.id == NotificationService.challengeReminderId;

      if (known) {
        continue;
      }

      cards.add(
        Padding(
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: _buildNotificationCard(
            id: notification.id,
            icon: Icons.notifications_active_rounded,
            iconColor: Colors.amber,
            title: notification.title ?? 'Notification',
            message: notification.body ?? '',
            type: 'Scheduled Notification',
            time: 'Pending',
            pending: true,
          ),
        ),
      );
    }

    return cards;
  }

  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget _buildNotificationCard({
    required int id,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String type,
    required String time,
    required bool pending,
  }) {
    return Dismissible(
      key: ValueKey(
        'notification_$id',
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) {
        return _showDeleteConfirmation(
          title,
        );
      },
      onDismissed: (_) async {
        await NotificationService.instance.cancelNotification(id);

        await _loadNotifications();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(
          right: 22,
        ),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.redAccent.withOpacity(0.2),
          ),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 25,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: pending
                ? iconColor.withOpacity(
                    0.20,
                  )
                : border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(
                  13,
                ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      GestureDetector(
                        onTap: () {
                          _deleteNotification(
                            id,
                            title,
                          );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(
                              0.07,
                            ),
                            borderRadius: BorderRadius.circular(
                              10,
                            ),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(
                                0.12,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(
                    height: 9,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: iconColor,
                        size: 13,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: pending
                              ? accent.withOpacity(
                                  0.08,
                                )
                              : Colors.white.withOpacity(
                                  0.04,
                                ),
                          borderRadius: BorderRadius.circular(
                            7,
                          ),
                        ),
                        child: Text(
                          pending ? 'SCHEDULED' : 'NOT PENDING',
                          style: TextStyle(
                            color: pending ? accent : Colors.white38,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ID: $id',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 8,
                        ),
                      ),
                    ],
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
  // FORMAT TIME
  // ============================================================

  String _formatTime(
    String value,
  ) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return value;
    }

    final int? hour = int.tryParse(parts[0]);

    final int? minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return value;
    }

    final int hour12 = hour % 12 == 0 ? 12 : hour % 12;

    final String minuteText = minute.toString().padLeft(
          2,
          '0',
        );

    final String period = hour >= 12 ? 'PM' : 'AM';

    return '$hour12:$minuteText $period';
  }

  // ============================================================
  // LOADING CARD
  // ============================================================

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 25,
          height: 25,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: accent,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY CARD
  // ============================================================

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor2,
            cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: accent.withOpacity(
                0.07,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: accent,
              size: 27,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          const Text(
            'No notifications configured',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          const Text(
            'Enable reminders in your notification settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
