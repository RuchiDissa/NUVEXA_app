import 'package:flutter/material.dart';
import '../database/DatabaseHelper.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage>
    with SingleTickerProviderStateMixin {
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

  final DatabaseHelper _db = DatabaseHelper.instance;

  // ============================================================
  // ANIMATION
  // ============================================================

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;

  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _challengeDays = [];

  double _completionRate = 0.0;

  int _totalActivities = 0;
  int _completedActivities = 0;

  int _totalChallengeDays = 0;
  int _completedChallengeDays = 0;

  int _currentStreak = 0;
  int _bestStreak = 0;

  String _bestDay = '—';

  List<double> _weeklyData = List<double>.filled(7, 0.0);

  List<_RecentPerformance> _recentPerformance = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _loadInsights();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadInsights() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final activities = await _db.getActivities();

      final challengeDays = await _db.getAllChallengeDays();

      if (!mounted) return;

      _activities = activities;
      _challengeDays = challengeDays;

      _calculateStatistics();
      _calculateWeeklyData();
      _calculateStreaks();
      _calculateBestDay();
      _calculateRecentPerformance();

      _animationController.reset();

      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      debugPrint(
        'Insights loading error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  void _calculateStatistics() {
    final normalActivities = _activities.where((activity) {
      return (activity['is_challenge'] ?? 0) != 1;
    }).toList();

    _totalActivities = normalActivities.length;

    _completedActivities = normalActivities.where((activity) {
      return (activity['is_completed'] ?? 0) == 1;
    }).length;

    _totalChallengeDays = _challengeDays.length;

    _completedChallengeDays = _challengeDays.where((day) {
      return (day['is_completed'] ?? 0) == 1;
    }).length;

    final int totalTasks = _totalActivities + _totalChallengeDays;

    final int completedTasks = _completedActivities + _completedChallengeDays;

    if (totalTasks == 0) {
      _completionRate = 0.0;
    } else {
      _completionRate = (completedTasks / totalTasks) * 100.0;
    }
  }

  // ============================================================
  // WEEKLY DATA
  // ============================================================

  void _calculateWeeklyData() {
    final DateTime today = _dateOnly(DateTime.now());

    final List<double> values = <double>[];

    for (int i = 6; i >= 0; i--) {
      final DateTime date = today.subtract(
        Duration(days: i),
      );

      final int completed = _completedTasksForDate(date);

      values.add(
        completed.toDouble(),
      );
    }

    _weeklyData = values;
  }

  int _completedTasksForDate(
    DateTime date,
  ) {
    int count = 0;

    for (final activity in _activities) {
      final bool isChallenge = (activity['is_challenge'] ?? 0) == 1;

      final bool isCompleted = (activity['is_completed'] ?? 0) == 1;

      if (isChallenge || !isCompleted) {
        continue;
      }

      final DateTime? activityDate = _parseDate(
        activity['activity_date'],
      );

      if (activityDate != null && _sameDate(activityDate, date)) {
        count++;
      }
    }

    for (final day in _challengeDays) {
      final bool isCompleted = (day['is_completed'] ?? 0) == 1;

      if (!isCompleted) continue;

      final DateTime? challengeDate = _parseDate(
        day['challenge_date'],
      );

      if (challengeDate != null && _sameDate(challengeDate, date)) {
        count++;
      }
    }

    return count;
  }

  // ============================================================
  // STREAKS
  // ============================================================

  void _calculateStreaks() {
    final Set<String> completedDates = <String>{};

    for (final activity in _activities) {
      final bool isChallenge = (activity['is_challenge'] ?? 0) == 1;

      final bool isCompleted = (activity['is_completed'] ?? 0) == 1;

      if (isChallenge || !isCompleted) {
        continue;
      }

      final DateTime? date = _parseDate(
        activity['activity_date'],
      );

      if (date != null) {
        completedDates.add(
          _dateKey(date),
        );
      }
    }

    for (final day in _challengeDays) {
      final bool isCompleted = (day['is_completed'] ?? 0) == 1;

      if (!isCompleted) continue;

      final DateTime? date = _parseDate(
        day['challenge_date'],
      );

      if (date != null) {
        completedDates.add(
          _dateKey(date),
        );
      }
    }

    if (completedDates.isEmpty) {
      _currentStreak = 0;
      _bestStreak = 0;
      return;
    }

    final List<DateTime> dates =
        completedDates.map(_parseDate).whereType<DateTime>().toList();

    dates.sort();

    int best = 1;
    int running = 1;

    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        running++;

        if (running > best) {
          best = running;
        }
      } else {
        running = 1;
      }
    }

    _bestStreak = best;

    final DateTime today = _dateOnly(DateTime.now());

    final DateTime yesterday = today.subtract(
      const Duration(days: 1),
    );

    if (completedDates.contains(
      _dateKey(today),
    )) {
      int streak = 1;

      DateTime check = yesterday;

      while (completedDates.contains(
        _dateKey(check),
      )) {
        streak++;

        check = check.subtract(
          const Duration(days: 1),
        );
      }

      _currentStreak = streak;
    } else if (completedDates.contains(
      _dateKey(yesterday),
    )) {
      int streak = 1;

      DateTime check = yesterday.subtract(
        const Duration(days: 1),
      );

      while (completedDates.contains(
        _dateKey(check),
      )) {
        streak++;

        check = check.subtract(
          const Duration(days: 1),
        );
      }

      _currentStreak = streak;
    } else {
      _currentStreak = 0;
    }
  }

  // ============================================================
  // BEST DAY
  // ============================================================

  void _calculateBestDay() {
    final Map<int, int> counts = <int, int>{};

    for (int i = 1; i <= 7; i++) {
      counts[i] = 0;
    }

    for (final activity in _activities) {
      final bool isChallenge = (activity['is_challenge'] ?? 0) == 1;

      final bool isCompleted = (activity['is_completed'] ?? 0) == 1;

      if (isChallenge || !isCompleted) {
        continue;
      }

      final DateTime? date = _parseDate(
        activity['activity_date'],
      );

      if (date != null) {
        counts[date.weekday] = (counts[date.weekday] ?? 0) + 1;
      }
    }

    for (final day in _challengeDays) {
      final bool isCompleted = (day['is_completed'] ?? 0) == 1;

      if (!isCompleted) continue;

      final DateTime? date = _parseDate(
        day['challenge_date'],
      );

      if (date != null) {
        counts[date.weekday] = (counts[date.weekday] ?? 0) + 1;
      }
    }

    int bestWeekday = 0;
    int highest = 0;

    counts.forEach(
      (weekday, count) {
        if (count > highest) {
          highest = count;
          bestWeekday = weekday;
        }
      },
    );

    if (bestWeekday == 0) {
      _bestDay = '—';
      return;
    }

    const List<String> names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    _bestDay = names[bestWeekday - 1];
  }

  // ============================================================
  // RECENT PERFORMANCE
  // ============================================================

  void _calculateRecentPerformance() {
    final List<_RecentPerformance> results = <_RecentPerformance>[];

    final Map<int, Map<String, dynamic>> activityMap =
        <int, Map<String, dynamic>>{};

    for (final activity in _activities) {
      final dynamic rawId = activity['id'];

      final int? id = rawId is int
          ? rawId
          : int.tryParse(
              rawId?.toString() ?? '',
            );

      if (id != null) {
        activityMap[id] = activity;
      }
    }

    final DateTime today = _dateOnly(DateTime.now());

    for (final activity in _activities) {
      final bool isChallenge = (activity['is_challenge'] ?? 0) == 1;

      if (isChallenge) continue;

      final DateTime? date = _parseDate(
        activity['activity_date'],
      );

      if (date == null || date.isAfter(today)) {
        continue;
      }

      results.add(
        _RecentPerformance(
          title: activity['name']?.toString() ?? 'Activity',
          emoji: activity['emoji']?.toString() ?? '✨',
          date: date,
          completed: (activity['is_completed'] ?? 0) == 1,
          isChallenge: false,
        ),
      );
    }

    for (final day in _challengeDays) {
      final DateTime? date = _parseDate(
        day['challenge_date'],
      );

      if (date == null || date.isAfter(today)) {
        continue;
      }

      final dynamic rawId = day['activity_id'];

      final int? activityId = rawId is int
          ? rawId
          : int.tryParse(
              rawId?.toString() ?? '',
            );

      final activity = activityId == null ? null : activityMap[activityId];

      results.add(
        _RecentPerformance(
          title: activity?['name']?.toString() ?? 'Challenge',
          emoji: activity?['emoji']?.toString() ?? '🏆',
          date: date,
          completed: (day['is_completed'] ?? 0) == 1,
          isChallenge: true,
        ),
      );
    }

    results.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    _recentPerformance = results.take(6).toList();
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return _dateOnly(value);
    }

    final String text = value.toString().trim();

    if (text.isEmpty) return null;

    final DateTime? parsed = DateTime.tryParse(text);

    if (parsed != null) {
      return _dateOnly(parsed);
    }

    return null;
  }

  bool _sameDate(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateKey(DateTime date) {
    final DateTime d = _dateOnly(date);

    final String month = d.month.toString().padLeft(2, '0');

    final String day = d.day.toString().padLeft(2, '0');

    return '${d.year}-$month-$day';
  }

  String _formatDate(DateTime date) {
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

    return '${months[date.month - 1]} ${date.day}';
  }

  String _weekdayShort(DateTime date) {
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    return days[date.weekday - 1];
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
                onRefresh: _loadInsights,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    110,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(
                          height: 24,
                        ),
                        _buildHeroProgress(),
                        const SizedBox(
                          height: 18,
                        ),
                        _buildStatisticsGrid(),
                        const SizedBox(
                          height: 18,
                        ),
                        _buildWeeklyChart(),
                        const SizedBox(
                          height: 18,
                        ),
                        _buildStreakSection(),
                        const SizedBox(
                          height: 18,
                        ),
                        _buildRecentPerformance(),
                        const SizedBox(
                          height: 18,
                        ),
                        _buildInsightsSection(),
                      ],
                    ),
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
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withOpacity(0.18),
                cyan.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: accent.withOpacity(0.22),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.insights_rounded,
                color: accent,
                size: 27,
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
                'Insights',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Understand your progress',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: _loadInsights,
            child: Container(
              width: 43,
              height: 43,
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
        ),
      ],
    );
  }

  // ============================================================
  // HERO PROGRESS
  // ============================================================

  Widget _buildHeroProgress() {
    final double progress =
        (_completionRate / 100.0).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.04),
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
                      'Overall Progress',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Your consistency at a glance',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'NUVEXA',
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 9,
                        color: border,
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: progress,
                      ),
                      duration: const Duration(
                        milliseconds: 1100,
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return SizedBox(
                          width: 108,
                          height: 108,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 9,
                            strokeCap: StrokeCap.round,
                            color: accent,
                            backgroundColor: Colors.transparent,
                          ),
                        );
                      },
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_completionRate.round()}%',
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'complete',
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
                    _buildMiniProgress(
                      'Activities',
                      _completedActivities,
                      _totalActivities,
                      accent,
                    ),
                    const SizedBox(height: 15),
                    _buildMiniProgress(
                      'Challenge Days',
                      _completedChallengeDays,
                      _totalChallengeDays,
                      purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgress(
    String title,
    int completed,
    int total,
    Color color,
  ) {
    final double value =
        total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '$completed / $total',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: border,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatisticsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'Completed',
            value: '${_completedActivities + _completedChallengeDays}',
            color: green,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _buildStatCard(
            icon: Icons.task_alt_rounded,
            title: 'Activities',
            value: '$_totalActivities',
            color: accent,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _buildStatCard(
            icon: Icons.emoji_events_outlined,
            title: 'Challenges',
            value: '$_completedChallengeDays',
            color: purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 9,
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
    final double maxValue = _weeklyData.isEmpty
        ? 1.0
        : _weeklyData.reduce(
            (double a, double b) => a > b ? a : b,
          );

    final double chartMax = maxValue <= 0 ? 1.0 : maxValue;

    final DateTime today = _dateOnly(DateTime.now());

    return _buildSectionCard(
      title: 'Weekly Activity',
      subtitle: 'Completed tasks over the last 7 days',
      trailing: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
            7,
            (index) {
              final double value =
                  index < _weeklyData.length ? _weeklyData[index] : 0.0;

              final double ratio =
                  (value / chartMax).clamp(0.0, 1.0).toDouble();

              final DateTime date = today.subtract(
                Duration(
                  days: 6 - index,
                ),
              );

              final bool isToday = _sameDate(
                date,
                today,
              );

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 18,
                        child: Text(
                          value.toInt().toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: value > 0 ? accent : textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0.0,
                              end: ratio,
                            ),
                            duration: Duration(
                              milliseconds: 500 + (index * 80),
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (
                              context,
                              animatedRatio,
                              child,
                            ) {
                              return FractionallySizedBox(
                                heightFactor:
                                    animatedRatio == 0 ? 0.02 : animatedRatio,
                                child: Container(
                                  width: 25,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        isToday ? cyan : accent,
                                        isToday ? accent : accentDark,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      8,
                                    ),
                                    boxShadow: value > 0
                                        ? [
                                            BoxShadow(
                                              color: accent.withOpacity(0.18),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        _weekdayShort(date),
                        style: TextStyle(
                          color: isToday ? accent : textSecondary,
                          fontSize: 10,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STREAK
  // ============================================================

  Widget _buildStreakSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStreakCard(
            icon: Icons.local_fire_department_rounded,
            title: 'Current Streak',
            value: '$_currentStreak',
            suffix: _currentStreak == 1 ? 'day' : 'days',
            color: orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStreakCard(
            icon: Icons.bolt_rounded,
            title: 'Best Streak',
            value: '$_bestStreak',
            suffix: _bestStreak == 1 ? 'day' : 'days',
            color: purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard({
    required IconData icon,
    required String title,
    required String value,
    required String suffix,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor2,
            cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 4,
                      ),
                      child: Text(
                        suffix,
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 9,
                        ),
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

  // ============================================================
  // RECENT PERFORMANCE
  // ============================================================

  Widget _buildRecentPerformance() {
    return _buildSectionCard(
      title: 'Recent Performance',
      subtitle: 'Your latest activity history',
      trailing: Icons.history_rounded,
      child: _recentPerformance.isEmpty
          ? _buildEmptyState(
              icon: Icons.history_rounded,
              message: 'No activity history yet.',
            )
          : Column(
              children: _recentPerformance.map(
                (item) {
                  return _buildPerformanceItem(
                    item,
                  );
                },
              ).toList(),
            ),
    );
  }

  Widget _buildPerformanceItem(
    _RecentPerformance item,
  ) {
    final Color itemColor = item.isChallenge ? purple : accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(14),
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
              color: itemColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              item.emoji,
              style: const TextStyle(
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.isChallenge ? 'Challenge' : 'Activity'}  •  ${_formatDate(item.date)}',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: item.completed
                  ? green.withOpacity(0.10)
                  : red.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.completed ? Icons.check_rounded : Icons.close_rounded,
              color: item.completed ? green : red,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INSIGHTS
  // ============================================================

  Widget _buildInsightsSection() {
    final List<Map<String, dynamic>> insights = _generateInsights();

    return _buildSectionCard(
      title: 'Your Insights',
      subtitle: 'Generated from your activity data',
      trailing: Icons.auto_awesome_rounded,
      child: insights.isEmpty
          ? _buildEmptyState(
              icon: Icons.auto_awesome_rounded,
              message: 'Complete more activities to unlock insights.',
            )
          : Column(
              children: insights.map(
                (insight) {
                  return _buildInsightItem(
                    icon: insight['icon'] as IconData,
                    title: insight['title'] as String,
                    description: insight['description'] as String,
                    color: insight['color'] as Color,
                  );
                },
              ).toList(),
            ),
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    final List<Map<String, dynamic>> insights = <Map<String, dynamic>>[];

    if (_completionRate >= 80) {
      insights.add({
        'icon': Icons.verified_rounded,
        'title': 'Strong consistency',
        'description':
            'Your completion rate is above 80%. You are maintaining a strong level of consistency.',
        'color': green,
      });
    } else if (_completionRate >= 50) {
      insights.add({
        'icon': Icons.trending_up_rounded,
        'title': 'Good progress',
        'description':
            'More than half of your tracked tasks are completed. Keep building your consistency.',
        'color': accent,
      });
    } else if (_completionRate > 0) {
      insights.add({
        'icon': Icons.play_arrow_rounded,
        'title': 'Keep building',
        'description':
            'You have started tracking your progress. Focus on completing a few activities consistently each day.',
        'color': orange,
      });
    }

    if (_currentStreak >= 7) {
      insights.add({
        'icon': Icons.local_fire_department_rounded,
        'title': 'Weekly streak',
        'description':
            'You have maintained a streak of at least 7 days. Consistency is becoming part of your routine.',
        'color': orange,
      });
    } else if (_currentStreak > 0) {
      insights.add({
        'icon': Icons.bolt_rounded,
        'title': 'Keep your streak alive',
        'description':
            'Your current streak is $_currentStreak ${_currentStreak == 1 ? 'day' : 'days'}. Complete something today to continue it.',
        'color': purple,
      });
    }

    if (_bestDay != '—') {
      insights.add({
        'icon': Icons.calendar_today_rounded,
        'title': 'Best day',
        'description':
            '$_bestDay is currently your most productive day based on completed tasks.',
        'color': cyan,
      });
    }

    if (_totalChallengeDays > 0) {
      final double challengeRate =
          (_completedChallengeDays / _totalChallengeDays) * 100.0;

      if (challengeRate >= 70) {
        insights.add({
          'icon': Icons.emoji_events_rounded,
          'title': 'Challenge progress',
          'description':
              'You have completed ${challengeRate.round()}% of your challenge days. Keep pushing toward the finish.',
          'color': purple,
        });
      }
    }

    final double weeklyTotal = _weeklyData.fold<double>(
      0.0,
      (sum, value) => sum + value,
    );

    if (weeklyTotal >= 7.0) {
      insights.add({
        'icon': Icons.insights_rounded,
        'title': 'Good weekly momentum',
        'description':
            'You completed ${weeklyTotal.toInt()} tasks during the last 7 days.',
        'color': accent,
      });
    }

    return insights.take(4).toList();
  }

  Widget _buildInsightItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cardColor2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: color,
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
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

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  trailing,
                  color: accent,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 20,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: textSecondary,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// RECENT PERFORMANCE MODEL
// ================================================================

class _RecentPerformance {
  final String title;
  final String emoji;
  final DateTime date;
  final bool completed;
  final bool isChallenge;

  const _RecentPerformance({
    required this.title,
    required this.emoji,
    required this.date,
    required this.completed,
    required this.isChallenge,
  });
}
