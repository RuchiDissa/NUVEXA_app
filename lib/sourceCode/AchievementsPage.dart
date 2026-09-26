import 'package:flutter/material.dart';

import '../database/DatabaseHelper.dart';

class AchievementsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const AchievementsPage({
    super.key,
    this.onBack,
  });

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  // ------------------------------------------------------------
  // NUVEXA COLORS
  // ------------------------------------------------------------

  static const Color background = Color(0xFF020617);
  static const Color cardColor = Color(0xFF0F172A);
  static const Color cardColor2 = Color(0xFF111C32);
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentDark = Color(0xFF0EA5E9);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color border = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF94A3B8);

  bool _isLoading = true;

  int _completedTasks = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _completedChallenges = 0;

  List<Map<String, dynamic>> _achievements = [];

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  // ------------------------------------------------------------
  // LOAD DATA
  // ------------------------------------------------------------

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final activities = await DatabaseHelper.instance.getActivities();

      final challengeDays = await DatabaseHelper.instance.getAllChallengeDays();

      // --------------------------------------------------------
      // COMPLETED NORMAL ACTIVITIES
      // --------------------------------------------------------

      final completedNormalActivities = activities
          .where((activity) =>
              activity['is_challenge'] != 1 && activity['is_completed'] == 1)
          .length;

      // --------------------------------------------------------
      // COMPLETED CHALLENGE DAYS
      // --------------------------------------------------------

      final completedChallengeDays =
          challengeDays.where((day) => day['is_completed'] == 1).length;

      _completedTasks = completedNormalActivities + completedChallengeDays;

      // --------------------------------------------------------
      // COMPLETED CHALLENGES
      // --------------------------------------------------------

      final challengeActivities = activities
          .where((activity) => activity['is_challenge'] == 1)
          .toList();

      int completedChallenges = 0;

      for (final challenge in challengeActivities) {
        final activityId = challenge['id'];

        final days = challengeDays
            .where((day) => day['activity_id'] == activityId)
            .toList();

        if (days.isNotEmpty && days.every((day) => day['is_completed'] == 1)) {
          completedChallenges++;
        }
      }

      _completedChallenges = completedChallenges;

      // --------------------------------------------------------
      // STREAKS
      // --------------------------------------------------------

      final completedDates = <DateTime>{};

      for (final activity in activities) {
        if (activity['is_challenge'] != 1 && activity['is_completed'] == 1) {
          final date = DateTime.tryParse(
            activity['activity_date']?.toString() ?? '',
          );

          if (date != null) {
            completedDates.add(
              DateTime(date.year, date.month, date.day),
            );
          }
        }
      }

      for (final day in challengeDays) {
        if (day['is_completed'] == 1) {
          final date = DateTime.tryParse(
            day['challenge_date']?.toString() ?? '',
          );

          if (date != null) {
            completedDates.add(
              DateTime(date.year, date.month, date.day),
            );
          }
        }
      }

      _currentStreak = _calculateCurrentStreak(completedDates);
      _longestStreak = _calculateLongestStreak(completedDates);

      // --------------------------------------------------------
      // ACHIEVEMENTS
      // --------------------------------------------------------

      _achievements = [
        {
          'icon': Icons.emoji_events_rounded,
          'title': 'First Step',
          'description': 'Complete your first activity.',
          'unlocked': _completedTasks >= 1,
          'progress': _completedTasks >= 1 ? 1.0 : 0.0,
          'progressText': '${_completedTasks.clamp(0, 1)}/1',
        },
        {
          'icon': Icons.local_fire_department_rounded,
          'title': '3-Day Streak',
          'description': 'Stay consistent for 3 consecutive days.',
          'unlocked': _longestStreak >= 3,
          'progress': (_longestStreak / 3).clamp(0.0, 1.0),
          'progressText': '${_longestStreak.clamp(0, 3)}/3 days',
        },
        {
          'icon': Icons.local_fire_department_rounded,
          'title': '7-Day Streak',
          'description': 'Maintain your routine for one full week.',
          'unlocked': _longestStreak >= 7,
          'progress': (_longestStreak / 7).clamp(0.0, 1.0),
          'progressText': '${_longestStreak.clamp(0, 7)}/7 days',
        },
        {
          'icon': Icons.bolt_rounded,
          'title': '14-Day Streak',
          'description': 'Stay consistent for two weeks.',
          'unlocked': _longestStreak >= 14,
          'progress': (_longestStreak / 14).clamp(0.0, 1.0),
          'progressText': '${_longestStreak.clamp(0, 14)}/14 days',
        },
        {
          'icon': Icons.whatshot_rounded,
          'title': '30-Day Streak',
          'description': 'Complete a full month of consistency.',
          'unlocked': _longestStreak >= 30,
          'progress': (_longestStreak / 30).clamp(0.0, 1.0),
          'progressText': '${_longestStreak.clamp(0, 30)}/30 days',
        },
        {
          'icon': Icons.flag_rounded,
          'title': 'Challenge Starter',
          'description': 'Complete your first challenge.',
          'unlocked': _completedChallenges >= 1,
          'progress': (_completedChallenges / 1).clamp(0.0, 1.0),
          'progressText': '${_completedChallenges.clamp(0, 1)}/1',
        },
        {
          'icon': Icons.workspace_premium_rounded,
          'title': 'Half Century',
          'description': 'Complete 50 tasks.',
          'unlocked': _completedTasks >= 50,
          'progress': (_completedTasks / 50).clamp(0.0, 1.0),
          'progressText': '${_completedTasks.clamp(0, 50)}/50',
        },
        {
          'icon': Icons.military_tech_rounded,
          'title': 'Century',
          'description': 'Complete 100 tasks.',
          'unlocked': _completedTasks >= 100,
          'progress': (_completedTasks / 100).clamp(0.0, 1.0),
          'progressText': '${_completedTasks.clamp(0, 100)}/100',
        },
      ];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Achievements loading error: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // CURRENT STREAK
  // ------------------------------------------------------------

  int _calculateCurrentStreak(Set<DateTime> dates) {
    if (dates.isEmpty) {
      return 0;
    }

    final today = DateTime.now();

    DateTime currentDate = DateTime(today.year, today.month, today.day);

    // If today is not completed, allow the streak to continue
    // from yesterday.
    if (!dates.contains(currentDate)) {
      currentDate = currentDate.subtract(const Duration(days: 1));

      if (!dates.contains(currentDate)) {
        return 0;
      }
    }

    int streak = 0;

    while (dates.contains(currentDate)) {
      streak++;

      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  // ------------------------------------------------------------
  // LONGEST STREAK
  // ------------------------------------------------------------

  int _calculateLongestStreak(Set<DateTime> dates) {
    if (dates.isEmpty) {
      return 0;
    }

    final sortedDates = dates.toList()..sort();

    int longest = 1;
    int current = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final difference = sortedDates[i].difference(sortedDates[i - 1]).inDays;

      if (difference == 1) {
        current++;
      } else {
        if (current > longest) {
          longest = current;
        }

        current = 1;
      }
    }

    if (current > longest) {
      longest = current;
    }

    return longest;
  }

  // ------------------------------------------------------------
  // UNLOCKED COUNT
  // ------------------------------------------------------------

  int get _unlockedCount {
    return _achievements
        .where((achievement) => achievement['unlocked'] == true)
        .length;
  }

  // ------------------------------------------------------------
  // PAGE
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: accent,
                ),
              )
            : RefreshIndicator(
                color: accent,
                backgroundColor: cardColor,
                onRefresh: _loadAchievements,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildAchievementSummary(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildStats(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSectionTitle(),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        30,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildAchievementCard(
                              _achievements[index],
                            );
                          },
                          childCount: _achievements.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        8,
      ),
      child: Row(
        children: [
          if (widget.onBack != null)
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: border,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: textPrimary,
                  size: 21,
                ),
              ),
            ),
          if (widget.onBack != null) const SizedBox(width: 12),
          Image.asset(
            'images/logo.png',
            width: 42,
            height: 42,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: accent,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievements',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Track your milestones',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadAchievements,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: border,
                ),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: textSecondary,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY
  // ------------------------------------------------------------

  Widget _buildAchievementSummary() {
    final total = _achievements.length;
    final progress = total == 0 ? 0.0 : _unlockedCount / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        12,
      ),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor2,
            cardColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: border.withOpacity(0.65),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      accent,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_unlockedCount',
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'unlocked',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$_unlockedCount of $total achievements unlocked',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).round()}% complete',
                  style: const TextStyle(
                    color: accent,
                    fontSize: 12,
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

  // ------------------------------------------------------------
  // STATS
  // ------------------------------------------------------------

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        22,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              Icons.task_alt_rounded,
              '$_completedTasks',
              'Tasks',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              Icons.local_fire_department_rounded,
              '$_currentStreak',
              'Current Streak',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              Icons.flag_rounded,
              '$_completedChallenges',
              'Challenges',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: accent,
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

  Widget _buildSectionTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        12,
      ),
      child: Text(
        'Milestones',
        style: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ACHIEVEMENT CARD
  // ------------------------------------------------------------

  Widget _buildAchievementCard(
    Map<String, dynamic> achievement,
  ) {
    final bool unlocked = achievement['unlocked'] == true;

    final double progress =
        (achievement['progress'] as num?)?.toDouble() ?? 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? cardColor2 : cardColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: unlocked ? accent.withOpacity(0.35) : border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ICON
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: unlocked ? accent.withOpacity(0.12) : background,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: unlocked ? accent.withOpacity(0.25) : border,
              ),
            ),
            child: Icon(
              achievement['icon'] as IconData,
              color: unlocked ? accent : textSecondary.withOpacity(0.45),
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          // CONTENT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement['title'].toString(),
                        style: TextStyle(
                          color: unlocked ? textPrimary : textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      unlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_rounded,
                      color:
                          unlocked ? accent : textSecondary.withOpacity(0.45),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  achievement['description'].toString(),
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            unlocked ? accent : textSecondary.withOpacity(0.35),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      achievement['progressText'].toString(),
                      style: TextStyle(
                        color: unlocked ? accent : textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
