import 'package:flutter/material.dart';

import '../database/DatabaseHelper.dart';
import 'AddActivityPage.dart';
import 'ProfilePage.dart';
import 'ProgressPage.dart';
import 'AchievementsPage.dart';
import 'InsightsPage.dart';
import 'NotificationsPage.dart';
import 'NotificationService.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // ============================================================
  // NAVIGATION
  // ============================================================

  int _currentIndex = 0;

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> _activities = [];

  // Only today's challenge days.
  List<Map<String, dynamic>> _todayChallengeDays = [];

  // ALL challenge days.
  // Used to display D1, D2, D3... D30 etc.
  List<Map<String, dynamic>> _allChallengeDays = [];

  bool _isLoadingActivities = true;
  bool _hasUnreadNotifications = false;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color background = Color(0xFF020617);
  static const Color cardColor = Color(0xFF0F172A);
  static const Color cardColor2 = Color(0xFF111C32);
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentDark = Color(0xFF0EA5E9);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color border = Color(0xFF1E293B);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _checkUnreadNotifications();
  }

  // ============================================================
// CHECK NOTIFICATIONS
// ============================================================

  Future<void> _checkUnreadNotifications() async {
    try {
      final notifications =
          await NotificationService.instance.getPendingNotifications();

      if (!mounted) {
        return;
      }

      setState(() {
        _hasUnreadNotifications = notifications.isNotEmpty;
      });
    } catch (e) {
      debugPrint(
        'Error checking notifications: $e',
      );
    }
  }

  // ============================================================
  // LOAD ACTIVITIES
  // ============================================================

  Future<void> _loadActivities() async {
    try {
      final activities = await DatabaseHelper.instance.getActivities();

      // Get only today's challenge days.
      final todayChallengeDays =
          await DatabaseHelper.instance.getTodayChallengeDays();

      // Get every challenge day.
      final allChallengeDays =
          await DatabaseHelper.instance.getAllChallengeDays();

      if (!mounted) {
        return;
      }

      setState(() {
        _activities = activities;
        _todayChallengeDays = todayChallengeDays;
        _allChallengeDays = allChallengeDays;
        _isLoadingActivities = false;
      });
    } catch (e) {
      debugPrint(
        'Error loading activities: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingActivities = false;
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshActivities() async {
    await _loadActivities();
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isActivityToday(
    Map<String, dynamic> activity,
  ) {
    final dateString = activity['activity_date']?.toString();

    if (dateString == null) {
      return false;
    }

    final date = DateTime.tryParse(dateString);

    if (date == null) {
      return false;
    }

    // Normal activity.
    if (activity['is_challenge'] != 1) {
      return _isToday(date);
    }

    // Challenge.
    final startString = activity['challenge_start_date']?.toString();

    final endString = activity['challenge_end_date']?.toString();

    if (startString == null || endString == null) {
      return _isToday(date);
    }

    final start = DateTime.tryParse(startString);

    final end = DateTime.tryParse(endString);

    if (start == null || end == null) {
      return _isToday(date);
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final startOnly = DateTime(
      start.year,
      start.month,
      start.day,
    );

    final endOnly = DateTime(
      end.year,
      end.month,
      end.day,
    );

    return !today.isBefore(startOnly) && !today.isAfter(endOnly);
  }

  // ============================================================
  // TODAY NORMAL ACTIVITIES
  // ============================================================

  List<Map<String, dynamic>> _getTodayNormalActivities() {
    return _activities.where((activity) {
      if (activity['is_challenge'] == 1) {
        return false;
      }

      return _isActivityToday(activity);
    }).toList();
  }

  // ============================================================
  // TODAY CHALLENGE ACTIVITIES
  // ============================================================

  List<Map<String, dynamic>> _getTodayChallengeActivities() {
    return _activities.where((activity) {
      if (activity['is_challenge'] != 1) {
        return false;
      }

      return _isActivityToday(activity);
    }).toList();
  }

  // ============================================================
  // TODAY PROGRESS
  // ============================================================

  int _getTodayTotal() {
    final normalActivities = _getTodayNormalActivities();

    // Each challenge day counts as one activity for today.
    final todayChallengeDays = _todayChallengeDays.length;

    return normalActivities.length + todayChallengeDays;
  }

  int _getTodayCompleted() {
    final normalActivities = _getTodayNormalActivities();

    final normalCompleted = normalActivities
        .where(
          (activity) => activity['is_completed'] == 1,
        )
        .length;

    // Count completed challenge days individually.
    final challengeCompleted = _todayChallengeDays
        .where(
          (day) => day['is_completed'] == 1,
        )
        .length;

    return normalCompleted + challengeCompleted;
  }

  double _getTodayProgress() {
    final total = _getTodayTotal();

    if (total == 0) {
      return 0;
    }

    final completed = _getTodayCompleted();

    return (completed / total).clamp(0.0, 1.0);
  }

  // ============================================================
  // STREAK
  // ============================================================

  int _calculateStreak() {
    final completedDates = <String>{};

    // Normal activities.
    for (final activity in _activities) {
      if (activity['is_completed'] != 1) {
        continue;
      }

      final dateString = activity['activity_date']?.toString();

      if (dateString == null) {
        continue;
      }

      final date = DateTime.tryParse(dateString);

      if (date != null) {
        completedDates.add(
          _dateKey(date),
        );
      }
    }

    // Today's completed challenge days.
    for (final day in _todayChallengeDays) {
      if (day['is_completed'] == 1) {
        completedDates.add(
          _dateKey(DateTime.now()),
        );
      }
    }

    int streak = 0;

    DateTime cursor = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    while (completedDates.contains(
      _dateKey(cursor),
    )) {
      streak++;

      cursor = cursor.subtract(
        const Duration(days: 1),
      );
    }

    return streak;
  }

  // ============================================================
  // TOGGLE NORMAL ACTIVITY
  // ============================================================

  Future<void> _toggleActivityCompletion(
    Map<String, dynamic> activity,
  ) async {
    final int? id = int.tryParse(
      activity['id'].toString(),
    );

    if (id == null) {
      return;
    }

    final bool currentlyCompleted = activity['is_completed'] == 1;

    final bool newStatus = !currentlyCompleted;

    try {
      await DatabaseHelper.instance.updateActivityCompletion(
        id,
        newStatus,
      );

      await _loadActivities();
    } catch (e) {
      debugPrint(
        'Error completing activity: $e',
      );
    }
  }

  // ============================================================
  // TOGGLE CHALLENGE DAY
  // ============================================================

  Future<void> _toggleChallengeDay(
    Map<String, dynamic> day,
  ) async {
    final int? dayId = int.tryParse(
      day['id'].toString(),
    );

    if (dayId == null) {
      return;
    }

    final bool currentlyCompleted = day['is_completed'] == 1;

    try {
      await DatabaseHelper.instance.updateChallengeDayCompletion(
        dayId,
        !currentlyCompleted,
      );

      await _loadActivities();
    } catch (e) {
      debugPrint(
        'Error completing challenge day: $e',
      );
    }
  }

  // ============================================================
  // DELETE ACTIVITY
  // ============================================================

  Future<void> _deleteActivity(
    Map<String, dynamic> activity,
  ) async {
    final int? id = int.tryParse(
      activity['id'].toString(),
    );

    if (id == null) {
      return;
    }

    try {
      await DatabaseHelper.instance.deleteActivity(id);

      await _loadActivities();
    } catch (e) {
      debugPrint(
        'Error deleting activity: $e',
      );
    }
  }

  // ============================================================
  // CONFIRM DELETE
  // ============================================================

  Future<bool> _confirmDelete(
    Map<String, dynamic> activity,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Activity?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${activity['name']}"?',
            style: const TextStyle(
              color: Colors.white54,
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
                'Cancel',
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

    return result ?? false;
  }

  // ============================================================
  // EDIT ACTIVITY
  // ============================================================

  Future<void> _editActivity(
    Map<String, dynamic> activity,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityPage(
          activityToEdit: activity,
        ),
      ),
    );

    if (result == true) {
      await _loadActivities();
    }
  }

  // ============================================================
  // ADD ACTIVITY
  // ============================================================

  Future<void> _openAddActivity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddActivityPage(),
      ),
    );

    if (result == true) {
      await _loadActivities();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // CURRENT PAGE
  // ============================================================

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 1:
        return _buildProgressPage();

      case 3:
        return const InsightsPage();

      case 4:
        return const AchievementsPage();

      case 5:
        return ProfilePage(
          onDataChanged: _loadActivities,
        );

      default:
        return _buildHomePage();
    }
  }

  // ============================================================
  // HOME
  // ============================================================

  Widget _buildHomePage() {
    return RefreshIndicator(
      color: accent,
      backgroundColor: cardColor,
      onRefresh: _refreshActivities,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                20,
                0,
              ),
              child: _buildHeader(),
            ),
          ),

          // WELCOME
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                25,
                20,
                0,
              ),
              child: _buildWelcomeSection(),
            ),
          ),

          // PROGRESS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                22,
                20,
                0,
              ),
              child: _buildProgressCard(),
            ),
          ),

          // QUICK ACTIONS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                24,
                20,
                0,
              ),
              child: _buildSectionTitle(
                'Quick Actions',
                'Manage your journey',
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                0,
              ),
              child: _buildQuickActions(),
            ),
          ),

          // DAILY GOAL
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                25,
                20,
                0,
              ),
              child: _buildDailyGoal(),
            ),
          ),

          // ACTIVITIES
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                25,
                20,
                0,
              ),
              child: _buildTodayActivitiesSection(),
            ),
          ),

          // MOTIVATION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                25,
                20,
                30,
              ),
              child: _buildMotivationCard(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
// HEADER
// ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.06),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Image.asset(
            'images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'NUVEXA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const Spacer(),

        // ========================================================
        // NOTIFICATION BUTTON + RED DOT
        // ========================================================

        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: border,
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white70,
                  size: 22,
                ),
                onPressed: () async {
                  // Remove the red dot while viewing notifications.
                  if (mounted) {
                    setState(() {
                      _hasUnreadNotifications = false;
                    });
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                },
              ),
            ),

            // RED UNREAD DOT
            if (_hasUnreadNotifications)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: background,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WELCOME BACK',
          style: TextStyle(
            color: accent.withOpacity(0.75),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Build a better\nversion of yourself.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Small steps today create meaningful change tomorrow.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.48),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROGRESS CARD
  // ============================================================

  Widget _buildProgressCard() {
    final progress = _getTodayProgress();
    final percent = (progress * 100).round();
    final completed = _getTodayCompleted();
    final streak = _calculateStreak();

    return Container(
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withOpacity(0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: accentDark.withOpacity(0.07),
            blurRadius: 25,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR PROGRESS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Keep going.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          accent,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'today',
                          style: TextStyle(
                            color: Colors.white38,
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
          const SizedBox(height: 22),
          Container(
            height: 1,
            color: border,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStat(
                Icons.local_fire_department_outlined,
                '$streak',
                'Day Streak',
              ),
              _buildVerticalDivider(),
              _buildStat(
                Icons.check_circle_outline_rounded,
                '$completed',
                'Completed',
              ),
              _buildVerticalDivider(),
              _buildStat(
                Icons.trending_up_rounded,
                '$percent%',
                'Progress',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT
  // ============================================================

  Widget _buildStat(
    IconData icon,
    String value,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: accent,
            size: 19,
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 42,
      color: border,
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white24,
          size: 14,
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            Icons.track_changes_rounded,
            'Track',
            'Activity',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProgressPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            Icons.add_task_rounded,
            'Add',
            'Progress',
            _openAddActivity,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            Icons.insights_rounded,
            'View',
            'Insights',
            () {
              setState(() {
                _currentIndex = 3;
              });
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTION CARD
  // ============================================================

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  0.12,
                ),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 21,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DAILY GOAL
  // ============================================================

  Widget _buildDailyGoal() {
    final total = _getTodayTotal();
    final completed = _getTodayCompleted();

    final target = total < 4 ? 4 : total;

    final progress = target == 0 ? 0.0 : (completed / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  color: cyan,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Goal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total == 0
                          ? 'Create activities for today'
                          : 'Complete $target activities today',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$completed/$target',
                style: const TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TODAY ACTIVITIES SECTION
  // ============================================================

  Widget _buildTodayActivitiesSection() {
    final normal = _getTodayNormalActivities();

    final challenges = _getTodayChallengeActivities();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Activities",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete your tasks for today',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (normal.isNotEmpty || challenges.isNotEmpty)
              Text(
                '${normal.length + challenges.length}',
                style: const TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isLoadingActivities)
          _buildLoadingCard()
        else if (normal.isEmpty && challenges.isEmpty)
          _buildEmptyActivityCard()
        else ...[
          ...normal.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _buildNormalActivityCard(
                activity,
              ),
            ),
          ),
          ...challenges.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _buildChallengeActivityCard(
                activity,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // LOADING CARD
  // ============================================================

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: accent,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY ACTIVITY
  // ============================================================

  Widget _buildEmptyActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
          color: accent.withOpacity(0.12),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.playlist_add_rounded,
              color: accent,
              size: 25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No activities today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Start building your routine.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _openAddActivity,
            icon: const Icon(
              Icons.add_rounded,
              color: accent,
              size: 18,
            ),
            label: const Text(
              'Add Activity',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NORMAL ACTIVITY CARD
  // ============================================================

  Widget _buildNormalActivityCard(
    Map<String, dynamic> activity,
  ) {
    final bool completed = activity['is_completed'] == 1;

    final String emoji = activity['emoji']?.toString() ?? '🔥';

    final String name = activity['name']?.toString() ?? 'Activity';

    final String time = _formatTime(
      activity['start_time']?.toString(),
    );

    return Dismissible(
      key: ValueKey(
        'activity_${activity['id']}',
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(activity),
      onDismissed: (_) {
        _deleteActivity(activity);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(
          right: 22,
        ),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: completed
                ? [
                    accentDark.withOpacity(0.12),
                    cardColor,
                  ]
                : [
                    cardColor2,
                    cardColor,
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: completed ? accent.withOpacity(0.25) : border,
          ),
          boxShadow: [
            BoxShadow(
              color: completed
                  ? accent.withOpacity(0.05)
                  : Colors.black.withOpacity(
                      0.12,
                    ),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _toggleActivityCompletion(
              activity,
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  // EMOJI
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(
                          fontSize: 25,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  // NAME
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            decoration:
                                completed ? TextDecoration.lineThrough : null,
                            decorationColor: accent,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Colors.white30,
                              size: 13,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Text(
                              time,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  // EDIT
                  _buildSmallActionButton(
                    Icons.edit_rounded,
                    () => _editActivity(
                      activity,
                    ),
                  ),

                  const SizedBox(
                    width: 7,
                  ),

                  // DELETE
                  _buildSmallActionButton(
                    Icons.delete_outline_rounded,
                    () async {
                      final confirmed = await _confirmDelete(
                        activity,
                      );

                      if (confirmed) {
                        await _deleteActivity(
                          activity,
                        );
                      }
                    },
                    delete: true,
                  ),

                  const SizedBox(
                    width: 7,
                  ),

                  // COMPLETE
                  GestureDetector(
                    onTap: () => _toggleActivityCompletion(
                      activity,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 200,
                      ),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: completed ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: completed ? accent : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: completed
                          ? const Icon(
                              Icons.check_rounded,
                              color: background,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SMALL ACTION BUTTON
  // ============================================================

  Widget _buildSmallActionButton(
    IconData icon,
    VoidCallback onTap, {
    bool delete = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: delete
              ? Colors.redAccent.withOpacity(0.07)
              : accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: delete
                ? Colors.redAccent.withOpacity(0.14)
                : accent.withOpacity(0.12),
          ),
        ),
        child: Icon(
          icon,
          color: delete ? Colors.redAccent : accent,
          size: 16,
        ),
      ),
    );
  }

  // ============================================================
  // CHALLENGE CARD
  // ============================================================

  Widget _buildChallengeActivityCard(
    Map<String, dynamic> activity,
  ) {
    final String emoji = activity['emoji']?.toString() ?? '🔥';

    final String name = activity['name']?.toString() ?? 'Challenge';

    final String time = _formatTime(
      activity['start_time']?.toString(),
    );

    final int activityId = int.tryParse(
          activity['id'].toString(),
        ) ??
        -1;

    // ==========================================================
    // IMPORTANT FIX
    //
    // Use ALL challenge days instead of today's challenge day.
    // ==========================================================

    final days = _allChallengeDays.where(
      (day) {
        final dayActivityId = int.tryParse(
          day['activity_id'].toString(),
        );

        return dayActivityId == activityId;
      },
    ).toList();

    // Sort by date.
    days.sort(
      (a, b) {
        final dateA = DateTime.tryParse(
              a['challenge_date']?.toString() ?? '',
            ) ??
            DateTime(1900);

        final dateB = DateTime.tryParse(
              b['challenge_date']?.toString() ?? '',
            ) ??
            DateTime(1900);

        return dateA.compareTo(dateB);
      },
    );

    // Calculate total challenge progress.
    final completedDays = days
        .where(
          (day) => day['is_completed'] == 1,
        )
        .length;

    final progress = days.isEmpty ? 0.0 : completedDays / days.length;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor2,
            cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: cyan.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: cyan.withOpacity(0.04),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          // ====================================================
          // CHALLENGE HEADER
          // ====================================================

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cyan.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(
                    15,
                  ),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 25,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: Colors.white30,
                          size: 13,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(
                          width: 9,
                        ),
                        const Icon(
                          Icons.flag_rounded,
                          color: cyan,
                          size: 12,
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        const Text(
                          'Challenge',
                          style: TextStyle(
                            color: cyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildSmallActionButton(
                Icons.edit_rounded,
                () => _editActivity(
                  activity,
                ),
              ),
              const SizedBox(width: 7),
              _buildSmallActionButton(
                Icons.delete_outline_rounded,
                () async {
                  final confirmed = await _confirmDelete(
                    activity,
                  );

                  if (confirmed) {
                    await _deleteActivity(
                      activity,
                    );
                  }
                },
                delete: true,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ====================================================
          // PROGRESS
          // ====================================================

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Challenge Progress',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$completedDays/${days.length}',
                style: const TextStyle(
                  color: cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                cyan,
              ),
            ),
          ),

          const SizedBox(height: 15),

          // ====================================================
          // DAY BOXES
          // ====================================================

          if (days.isEmpty)
            const Text(
              'No challenge days found.',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 10,
              ),
            )
          else
            SizedBox(
              height: 57,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(
                  width: 7,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];

                  final bool completed = day['is_completed'] == 1;

                  // ==================================================
                  // DAY NUMBER
                  //
                  // Database does NOT have day_number.
                  // Therefore:
                  //
                  // first challenge date = D1
                  // second challenge date = D2
                  // third challenge date = D3
                  // etc.
                  // ==================================================

                  final int dayNumber = index + 1;

                  return GestureDetector(
                    onTap: () => _toggleChallengeDay(
                      day,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      width: 47,
                      decoration: BoxDecoration(
                        color: completed
                            ? accent.withOpacity(
                                0.14,
                              )
                            : cardColor,
                        borderRadius: BorderRadius.circular(
                          13,
                        ),
                        border: Border.all(
                          color: completed ? accent : border,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'D$dayNumber',
                            style: TextStyle(
                              color: completed ? accent : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Icon(
                            completed
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: completed ? accent : Colors.white24,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(
    String? time,
  ) {
    if (time == null || time.isEmpty) {
      return '--:--';
    }

    final parts = time.split(':');

    if (parts.length < 2) {
      return time;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return time;
    }

    final timeOfDay = TimeOfDay(
      hour: hour,
      minute: minute,
    );

    final hour12 = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;

    final minuteText = minute.toString().padLeft(
          2,
          '0',
        );

    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour12:$minuteText $period';
  }

  // ============================================================
  // MOTIVATION
  // ============================================================

  Widget _buildMotivationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentDark.withOpacity(0.16),
            cyan.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: accent,
            size: 25,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S REMINDER",
                  style: TextStyle(
                    color: accent.withOpacity(
                      0.7,
                    ),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Progress, not perfection.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
  // PROGRESS PAGE
  // ============================================================

  Widget _buildProgressPage() {
    return const ProgressPage();
  }

  // ============================================================
  // INSIGHTS
  // ============================================================

  Widget _buildInsightsPage() {
    return _buildPlaceholderPage(
      Icons.insights_rounded,
      'Insights',
      'Understand your habits and progress.',
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfilePage() {
    return const ProfilePage();
  }

  // ============================================================
  // PLACEHOLDER
  // ============================================================

  Widget _buildPlaceholderPage(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withOpacity(
                    0.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(
                      0.05,
                    ),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: accent,
                size: 34,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            8,
            10,
            8,
            8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                Icons.home_rounded,
                'Home',
                0,
              ),
              _buildNavItem(
                Icons.trending_up_rounded,
                'Progress',
                1,
              ),
              _buildAddButton(),
              _buildNavItem(
                Icons.insights_rounded,
                'Insights',
                3,
              ),
              _buildNavItem(
                Icons.emoji_events_rounded,
                'Achievements',
                4,
              ),
              _buildNavItem(
                Icons.person_outline_rounded,
                'Profile',
                5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAV ITEM
  // ============================================================

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    final bool selected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? accent : Colors.white.withOpacity(0.35),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? accent
                    : Colors.white.withOpacity(
                        0.35,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADD BUTTON
  // ============================================================

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _openAddActivity,
      child: Container(
        width: 52,
        height: 52,
        transform: Matrix4.translationValues(
          0,
          -10,
          0,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              accentDark,
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: background,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: background,
          size: 28,
        ),
      ),
    );
  }
}
