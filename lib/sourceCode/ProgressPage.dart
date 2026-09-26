import 'package:flutter/material.dart';

import '../database/DatabaseHelper.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
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

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _allChallengeDays = [];

  bool _isLoading = true;

  int _totalCompletions = 0;
  int _completedCompletions = 0;

  int _totalNormalActivities = 0;
  int _completedNormalActivities = 0;

  int _totalChallengeDays = 0;
  int _completedChallengeDays = 0;

  double _overallProgress = 0;

  List<double> _weeklyProgress = List.filled(7, 0);

  final List<String> _weekLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  List<double> _monthlyProgress = List.filled(6, 0);
  List<String> _monthLabels = [];

  int _currentStreak = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadProgress() async {
    try {
      final activities = await DatabaseHelper.instance.getActivities();

      final allChallengeDays =
          await DatabaseHelper.instance.getAllChallengeDays();

      if (!mounted) {
        return;
      }

      setState(() {
        _activities = activities;
        _allChallengeDays = allChallengeDays;

        _calculateProgress();

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading progress: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // SAFE INTEGER CONVERSION
  // ============================================================

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  // ============================================================
  // DATE PARSING
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseActivityDate(
    Map<String, dynamic> activity,
  ) {
    return _parseDate(
      activity['activity_date'],
    );
  }

  DateTime? _parseChallengeDate(
    Map<String, dynamic> challengeDay,
  ) {
    return _parseDate(
      challengeDay['challenge_date'],
    );
  }

  // ============================================================
  // SAME DAY
  // ============================================================

  bool _sameDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ============================================================
  // CALCULATE EVERYTHING
  // ============================================================

  void _calculateProgress() {
    _calculateOverallProgress();
    _calculateWeeklyProgress();
    _calculateMonthlyProgress();
    _calculateStreak();
  }

  // ============================================================
  // OVERALL PROGRESS
  //
  // Normal activity = 1 task
  // Challenge day = 1 task
  //
  // Challenge parent itself is NOT counted.
  // ============================================================

  void _calculateOverallProgress() {
    int normalTotal = 0;
    int normalCompleted = 0;

    for (final activity in _activities) {
      final bool isChallenge = _toInt(activity['is_challenge']) == 1;

      if (isChallenge) {
        continue;
      }

      normalTotal++;

      if (_toInt(activity['is_completed']) == 1) {
        normalCompleted++;
      }
    }

    int challengeTotal = _allChallengeDays.length;

    int challengeCompleted = _allChallengeDays.where((day) {
      return _toInt(day['is_completed']) == 1;
    }).length;

    _totalNormalActivities = normalTotal;
    _completedNormalActivities = normalCompleted;

    _totalChallengeDays = challengeTotal;
    _completedChallengeDays = challengeCompleted;

    _totalCompletions = normalTotal + challengeTotal;

    _completedCompletions = normalCompleted + challengeCompleted;

    if (_totalCompletions > 0) {
      _overallProgress = _completedCompletions / _totalCompletions;
    } else {
      _overallProgress = 0;
    }
  }

  // ============================================================
  // WEEKLY PROGRESS
  // ============================================================

  void _calculateWeeklyProgress() {
    final now = DateTime.now();

    final startOfWeek = now.subtract(
      Duration(
        days: now.weekday - DateTime.monday,
      ),
    );

    final List<double> progress = [];

    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + i,
      );

      int totalForDay = 0;
      int completedForDay = 0;

      // --------------------------------------------------------
      // NORMAL ACTIVITIES
      // --------------------------------------------------------

      for (final activity in _activities) {
        final bool isChallenge = _toInt(activity['is_challenge']) == 1;

        if (isChallenge) {
          continue;
        }

        final activityDate = _parseActivityDate(activity);

        if (activityDate == null) {
          continue;
        }

        if (_sameDay(activityDate, date)) {
          totalForDay++;

          if (_toInt(activity['is_completed']) == 1) {
            completedForDay++;
          }
        }
      }

      // --------------------------------------------------------
      // CHALLENGE DAYS
      // --------------------------------------------------------

      for (final challengeDay in _allChallengeDays) {
        final challengeDate = _parseChallengeDate(challengeDay);

        if (challengeDate == null) {
          continue;
        }

        if (_sameDay(challengeDate, date)) {
          totalForDay++;

          if (_toInt(
                challengeDay['is_completed'],
              ) ==
              1) {
            completedForDay++;
          }
        }
      }

      if (totalForDay == 0) {
        progress.add(0);
      } else {
        progress.add(
          completedForDay / totalForDay,
        );
      }
    }

    _weeklyProgress = progress;
  }

  // ============================================================
  // MONTHLY PROGRESS
  // Last 6 months
  // ============================================================

  void _calculateMonthlyProgress() {
    final now = DateTime.now();

    final List<double> progress = [];
    final List<String> labels = [];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(
        now.year,
        now.month - i,
        1,
      );

      int totalForMonth = 0;
      int completedForMonth = 0;

      // --------------------------------------------------------
      // NORMAL ACTIVITIES
      // --------------------------------------------------------

      for (final activity in _activities) {
        final bool isChallenge = _toInt(activity['is_challenge']) == 1;

        if (isChallenge) {
          continue;
        }

        final date = _parseActivityDate(activity);

        if (date == null) {
          continue;
        }

        if (date.year == month.year && date.month == month.month) {
          totalForMonth++;

          if (_toInt(activity['is_completed']) == 1) {
            completedForMonth++;
          }
        }
      }

      // --------------------------------------------------------
      // CHALLENGE DAYS
      // --------------------------------------------------------

      for (final challengeDay in _allChallengeDays) {
        final date = _parseChallengeDate(challengeDay);

        if (date == null) {
          continue;
        }

        if (date.year == month.year && date.month == month.month) {
          totalForMonth++;

          if (_toInt(
                challengeDay['is_completed'],
              ) ==
              1) {
            completedForMonth++;
          }
        }
      }

      double percentage = 0;

      if (totalForMonth > 0) {
        percentage = completedForMonth / totalForMonth;
      }

      progress.add(percentage);
      labels.add(
        _monthName(month.month),
      );
    }

    _monthlyProgress = progress;
    _monthLabels = labels;
  }

  // ============================================================
  // MONTH NAME
  // ============================================================

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  // ============================================================
  // STREAK
  //
  // A completed normal activity OR completed challenge day
  // makes that calendar date a completed date.
  // ============================================================

  void _calculateStreak() {
    final Set<DateTime> completedDates = {};

    // ----------------------------------------------------------
    // NORMAL ACTIVITIES
    // ----------------------------------------------------------

    for (final activity in _activities) {
      final bool isChallenge = _toInt(activity['is_challenge']) == 1;

      if (isChallenge) {
        continue;
      }

      if (_toInt(activity['is_completed']) != 1) {
        continue;
      }

      final date = _parseActivityDate(activity);

      if (date != null) {
        completedDates.add(
          DateTime(
            date.year,
            date.month,
            date.day,
          ),
        );
      }
    }

    // ----------------------------------------------------------
    // CHALLENGE DAYS
    // ----------------------------------------------------------

    for (final challengeDay in _allChallengeDays) {
      if (_toInt(
            challengeDay['is_completed'],
          ) !=
          1) {
        continue;
      }

      final date = _parseChallengeDate(challengeDay);

      if (date != null) {
        completedDates.add(
          DateTime(
            date.year,
            date.month,
            date.day,
          ),
        );
      }
    }

    DateTime checkDate = DateTime.now();

    checkDate = DateTime(
      checkDate.year,
      checkDate.month,
      checkDate.day,
    );

    int streak = 0;

    while (completedDates.contains(checkDate)) {
      streak++;

      checkDate = checkDate.subtract(
        const Duration(days: 1),
      );
    }

    _currentStreak = streak;
  }

  // ============================================================
  // PERCENTAGE
  // ============================================================

  String _percentage(double value) {
    return '${(value * 100).round()}%';
  }

  // ============================================================
  // BUILD
  // ============================================================

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
                onRefresh: _loadProgress,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildOverviewCard(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildStatistics(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSectionTitle(
                        'WEEKLY PROGRESS',
                        'Normal activities + individual challenge days',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildWeeklyChart(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSectionTitle(
                        'MONTHLY PROGRESS',
                        'Completion trend over the last 6 months',
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildMonthlyChart(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildChallengeSummary(),
                    ),
                    SliverToBoxAdapter(
                      child: _buildPerformanceCard(),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 30),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: border,
              ),
            ),
            child: Image.asset(
              'images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NUVEXA',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'YOUR PROGRESS',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: border,
              ),
            ),
            child: IconButton(
              onPressed: _loadProgress,
              icon: const Icon(
                Icons.refresh_rounded,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW
  // ============================================================

  Widget _buildOverviewCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0C4A6E),
            Color(0xFF075985),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accent.withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            height: 105,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _overallProgress,
                    strokeWidth: 9,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      cyan,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _percentage(
                        _overallProgress,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'COMPLETE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
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
                  'YOUR JOURNEY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _overallProgress >= 0.8
                      ? 'Excellent work!'
                      : _overallProgress >= 0.5
                          ? 'Keep pushing forward!'
                          : 'Every step matters.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_completedCompletions of '
                  '$_totalCompletions completions',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
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
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        5,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              Icons.check_circle_outline_rounded,
              'COMPLETED',
              '$_completedCompletions',
              accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              Icons.flag_rounded,
              'CHALLENGE DAYS',
              '$_completedChallengeDays',
              cyan,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              Icons.local_fire_department_rounded,
              'STREAK',
              '$_currentStreak',
              Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 8,
      ),
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
            color: iconColor,
            size: 23,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        26,
        20,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WEEKLY CHART
  // ============================================================

  Widget _buildWeeklyChart() {
    final double weeklyAverage = _weeklyProgress.isEmpty
        ? 0
        : _weeklyProgress.reduce(
              (a, b) => a + b,
            ) /
            _weeklyProgress.length;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        16,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '7 DAY ACTIVITY',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${(weeklyAverage * 100).round()}% avg.',
                style: const TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (index) {
                  return Expanded(
                    child: _buildBar(
                      _weekLabels[index],
                      _weeklyProgress[index],
                      index == DateTime.now().weekday - 1,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(
    String label,
    double value,
    bool isToday,
  ) {
    const double maxHeight = 125;

    final double barHeight = value <= 0 ? 6 : value.clamp(0.0, 1.0) * maxHeight;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 24,
            child: Text(
              value > 0 ? '${(value * 100).round()}%' : '',
              style: TextStyle(
                color: isToday ? cyan : textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: barHeight,
            width: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isToday
                    ? [
                        accentDark,
                        cyan,
                      ]
                    : [
                        const Color(0xFF164E63),
                        const Color(0xFF0E7490),
                      ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.25),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: isToday ? accent : textSecondary,
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTHLY CHART
  // ============================================================

  Widget _buildMonthlyChart() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        18,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: cyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '6 MONTH TREND',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _MonthlyChartPainter(
                values: _monthlyProgress,
                accent: accent,
                cyan: cyan,
                border: border,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              _monthLabels.length,
              (index) {
                return Expanded(
                  child: Text(
                    _monthLabels[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
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
  // CHALLENGE SUMMARY
  // ============================================================

  Widget _buildChallengeSummary() {
    final challengeActivities = _activities.where((activity) {
      return _toInt(
            activity['is_challenge'],
          ) ==
          1;
    }).toList();

    if (challengeActivities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        0,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.flag_rounded,
                color: cyan,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'CHALLENGE PROGRESS',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...challengeActivities.map(
            (activity) {
              final int? activityId = _toInt(activity['id']);

              if (activityId == null) {
                return const SizedBox.shrink();
              }

              final days = _allChallengeDays.where(
                (day) {
                  return _toInt(
                        day['activity_id'],
                      ) ==
                      activityId;
                },
              ).toList();

              days.sort(
                (a, b) {
                  final dateA = _parseChallengeDate(a) ?? DateTime(1900);

                  final dateB = _parseChallengeDate(b) ?? DateTime(1900);

                  return dateA.compareTo(dateB);
                },
              );

              final completed = days.where((day) {
                return _toInt(
                      day['is_completed'],
                    ) ==
                    1;
              }).length;

              final progress = days.isEmpty ? 0.0 : completed / days.length;

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${activity['emoji'] ?? '🎯'} '
                          '${activity['name'] ?? 'Challenge'}',
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$completed/${days.length}',
                          style: const TextStyle(
                            color: cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          cyan,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(progress * 100).round()}% complete',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERFORMANCE
  // ============================================================

  Widget _buildPerformanceCard() {
    String title;
    String description;
    IconData icon;

    if (_overallProgress >= 0.8) {
      title = 'Outstanding consistency';

      description =
          'You are building strong habits. Keep maintaining your momentum.';

      icon = Icons.workspace_premium_rounded;
    } else if (_overallProgress >= 0.5) {
      title = 'You are making progress';

      description =
          'Stay consistent and keep completing your planned activities.';

      icon = Icons.trending_up_rounded;
    } else {
      title = 'Start building momentum';

      description =
          'Small daily actions can create meaningful long-term progress.';

      icon = Icons.rocket_launch_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        0,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            cardColor2,
            cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 25,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
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
    );
  }
}

// ================================================================
// MONTHLY LINE CHART PAINTER
// ================================================================

class _MonthlyChartPainter extends CustomPainter {
  final List<double> values;
  final Color accent;
  final Color cyan;
  final Color border;

  _MonthlyChartPainter({
    required this.values,
    required this.accent,
    required this.cyan,
    required this.border,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (values.isEmpty) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    const double left = 10;
    const double rightPadding = 10;
    const double top = 15;
    const double bottomPadding = 15;

    final double right = size.width - rightPadding;

    final double bottom = size.height - bottomPadding;

    final double chartWidth = right - left;

    final double chartHeight = bottom - top;

    // ----------------------------------------------------------
    // GRID
    // ----------------------------------------------------------

    final gridPaint = Paint()
      ..color = border.withOpacity(0.55)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y = top + chartHeight * i / 4;

      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        gridPaint,
      );
    }

    // ----------------------------------------------------------
    // POINTS
    // ----------------------------------------------------------

    final List<Offset> points = [];

    for (int i = 0; i < values.length; i++) {
      final double x = values.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (values.length - 1);

      final double y = bottom - values[i].clamp(0.0, 1.0) * chartHeight;

      points.add(
        Offset(x, y),
      );
    }

    // ----------------------------------------------------------
    // AREA
    // ----------------------------------------------------------

    final areaPath = Path();

    areaPath.moveTo(
      points.first.dx,
      bottom,
    );

    for (final point in points) {
      areaPath.lineTo(
        point.dx,
        point.dy,
      );
    }

    areaPath.lineTo(
      points.last.dx,
      bottom,
    );

    areaPath.close();

    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        cyan.withOpacity(0.20),
        cyan.withOpacity(0.01),
      ],
    ).createShader(
      Rect.fromLTWH(
        left,
        top,
        chartWidth,
        chartHeight,
      ),
    );

    canvas.drawPath(
      areaPath,
      fillPaint,
    );

    // ----------------------------------------------------------
    // LINE
    // ----------------------------------------------------------

    final linePath = Path();

    if (points.isNotEmpty) {
      linePath.moveTo(
        points.first.dx,
        points.first.dy,
      );

      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(
          points[i].dx,
          points[i].dy,
        );
      }
    }

    paint.shader = LinearGradient(
      colors: [
        accent,
        cyan,
      ],
    ).createShader(
      Rect.fromLTWH(
        left,
        top,
        chartWidth,
        chartHeight,
      ),
    );

    canvas.drawPath(
      linePath,
      paint,
    );

    // ----------------------------------------------------------
    // POINTS
    // ----------------------------------------------------------

    for (final point in points) {
      canvas.drawCircle(
        point,
        5,
        Paint()..color = const Color(0xFF0F172A),
      );

      canvas.drawCircle(
        point,
        3,
        Paint()..color = cyan,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _MonthlyChartPainter oldDelegate,
  ) {
    return oldDelegate.values != values;
  }
}
