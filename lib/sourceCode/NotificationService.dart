import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/DatabaseHelper.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final DatabaseHelper _database = DatabaseHelper.instance;

  // ============================================================
  // NOTIFICATION IDS
  // ============================================================

  static const int dailyReminderId = 1001;

  static const int challengeReminderId = 1002;

  static const int testNotificationId = 9999;

  // ============================================================
  // NOTIFICATION CHANNEL
  // ============================================================

  static const String _channelId = 'nuvexa_reminders';

  static const String _channelName = 'NUVEXA Reminders';

  static const String _channelDescription =
      'NUVEXA daily and challenge reminders.';

  // ============================================================
  // STATE
  // ============================================================

  bool _initialized = false;

  bool _syncInProgress = false;

  bool _challengeSyncInProgress = false;

  Timer? _challengeSyncTimer;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    debugPrint(
      '==========================================',
    );

    debugPrint(
      'NUVEXA NotificationService',
    );

    debugPrint(
      'Initializing notifications...',
    );

    debugPrint(
      '==========================================',
    );

    // ----------------------------------------------------------
    // Initialize timezone
    // ----------------------------------------------------------

    tz.initializeTimeZones();

    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(
        tz.getLocation(timeZone),
      );

      debugPrint(
        'Notification timezone: $timeZone',
      );
    } catch (e) {
      debugPrint(
        'Timezone initialization error: $e',
      );
    }

    // ----------------------------------------------------------
    // Android settings
    // ----------------------------------------------------------

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // ----------------------------------------------------------
    // iOS settings
    // ----------------------------------------------------------

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // ----------------------------------------------------------
    // General settings
    // ----------------------------------------------------------

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    // ----------------------------------------------------------
    // Initialize plugin
    // ----------------------------------------------------------

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // ----------------------------------------------------------
    // Android notification channel
    // ----------------------------------------------------------

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
      );

      await androidPlugin.createNotificationChannel(
        channel,
      );
    }

    _initialized = true;

    debugPrint(
      'NotificationService initialized successfully.',
    );

    // ----------------------------------------------------------
    // Start automatic challenge checking
    // ----------------------------------------------------------

    _startChallengeSyncTimer();
  }

  // ============================================================
  // CHALLENGE SYNC TIMER
  // ============================================================

  void _startChallengeSyncTimer() {
    _challengeSyncTimer?.cancel();

    _challengeSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (!_initialized) {
          return;
        }

        if (_challengeSyncInProgress) {
          return;
        }

        await syncTodayChallengeNotification();
      },
    );

    debugPrint(
      'Challenge sync timer started.',
    );
  }

  // ============================================================
  // MAIN NOTIFICATION SYNC
  // ============================================================

  Future<void> syncNotifications() async {
    if (_syncInProgress) {
      debugPrint(
        'Notification sync already running.',
      );

      return;
    }

    _syncInProgress = true;

    try {
      if (!_initialized) {
        await initialize();
      }

      final Map<String, dynamic> settings = await _database.getSettings();

      debugPrint(
        '------------------------------------------',
      );

      debugPrint(
        'Synchronizing NUVEXA notifications...',
      );

      debugPrint(
        'Settings: $settings',
      );

      // --------------------------------------------------------
      // MASTER NOTIFICATION SWITCH
      // --------------------------------------------------------

      final bool notificationsEnabled = _settingIsEnabled(
        settings['notifications_enabled'],
      );

      debugPrint(
        'Notifications enabled: '
        '$notificationsEnabled',
      );

      if (!notificationsEnabled) {
        await _notifications.cancel(
          dailyReminderId,
        );

        await _notifications.cancel(
          challengeReminderId,
        );

        debugPrint(
          'All notifications disabled.',
        );

        return;
      }

      // --------------------------------------------------------
      // CHECK PERMISSION
      // --------------------------------------------------------

      final bool permissionGranted = await areNotificationsAllowed();

      debugPrint(
        'Notification permission: '
        '$permissionGranted',
      );

      if (!permissionGranted) {
        debugPrint(
          'Notification permission not granted.',
        );

        return;
      }

      // ========================================================
      // DAILY REMINDER
      // ========================================================

      await _notifications.cancel(
        dailyReminderId,
      );

      final bool dailyReminderEnabled = _settingIsEnabled(
        settings['daily_reminder_enabled'],
      );

      final String dailyReminderTime =
          settings['daily_reminder_time']?.toString() ?? '20:00';

      debugPrint(
        'Daily reminder enabled: '
        '$dailyReminderEnabled',
      );

      debugPrint(
        'Daily reminder time: '
        '$dailyReminderTime',
      );

      if (dailyReminderEnabled) {
        await scheduleDailyReminder(
          time: dailyReminderTime,
        );
      }

      // ========================================================
      // TODAY'S CHALLENGE
      // ========================================================

      await _notifications.cancel(
        challengeReminderId,
      );

      await syncTodayChallengeNotification(
        settings: settings,
      );

      debugPrint(
        'Notification synchronization finished.',
      );

      debugPrint(
        '------------------------------------------',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Notification synchronization error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    } finally {
      _syncInProgress = false;
    }
  }

  // ============================================================
  // DAILY REMINDER
  // ============================================================

  Future<void> scheduleDailyReminder({
    required String time,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final TimeOfDay? parsedTime = _parseTime(time);

    if (parsedTime == null) {
      debugPrint(
        'Invalid daily reminder time: $time',
      );

      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(
        const Duration(days: 1),
      );
    }

    debugPrint(
      'Daily reminder scheduled for: '
      '$scheduled',
    );

    await _notifications.zonedSchedule(
      dailyReminderId,
      'NUVEXA Daily Reminder',
      'Take a moment to check in with your goals today.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );

    debugPrint(
      'Daily reminder scheduled successfully.',
    );
  }

  // ============================================================
  // CHECK TODAY'S CHALLENGE
  // ============================================================

  Future<void> syncTodayChallengeNotification({
    Map<String, dynamic>? settings,
  }) async {
    if (_challengeSyncInProgress) {
      return;
    }

    _challengeSyncInProgress = true;

    try {
      if (!_initialized) {
        await initialize();
      }

      final Map<String, dynamic> currentSettings =
          settings ?? await _database.getSettings();

      // --------------------------------------------------------
      // MASTER SWITCH
      // --------------------------------------------------------

      final bool notificationsEnabled = _settingIsEnabled(
        currentSettings['notifications_enabled'],
      );

      if (!notificationsEnabled) {
        await cancelChallengeReminder();

        return;
      }

      // --------------------------------------------------------
      // CHALLENGE SWITCH
      // --------------------------------------------------------

      final bool challengeRemindersEnabled = _settingIsEnabled(
        currentSettings['challenge_reminders_enabled'],
      );

      debugPrint(
        'Challenge reminders enabled: '
        '$challengeRemindersEnabled',
      );

      if (!challengeRemindersEnabled) {
        await cancelChallengeReminder();

        return;
      }

      // --------------------------------------------------------
      // PERMISSION
      // --------------------------------------------------------

      final bool permissionGranted = await areNotificationsAllowed();

      if (!permissionGranted) {
        debugPrint(
          'Challenge reminder skipped: '
          'permission not granted.',
        );

        return;
      }

      // --------------------------------------------------------
      // GET CHALLENGE DAYS
      // --------------------------------------------------------

      final List<Map<String, dynamic>> challengeDays =
          await _database.getAllChallengeDays();

      debugPrint(
        'Challenge days found: '
        '${challengeDays.length}',
      );

      // --------------------------------------------------------
      // TODAY
      // --------------------------------------------------------

      final DateTime now = DateTime.now();

      final DateTime today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      // --------------------------------------------------------
      // FIND TODAY'S INCOMPLETE CHALLENGE
      // --------------------------------------------------------

      Map<String, dynamic>? todayChallenge;

      for (final Map<String, dynamic> day in challengeDays) {
        final DateTime? challengeDate = _getChallengeDate(day);

        if (challengeDate == null) {
          continue;
        }

        final bool isToday = _isSameDate(
          challengeDate,
          today,
        );

        final bool incomplete = _isIncompleteChallenge(
          day['is_completed'],
        );

        debugPrint(
          'Challenge: '
          'date=${challengeDate.toIso8601String()}, '
          'isToday=$isToday, '
          'incomplete=$incomplete',
        );

        if (isToday && incomplete) {
          todayChallenge = day;
          break;
        }
      }

      // --------------------------------------------------------
      // NO INCOMPLETE CHALLENGE TODAY
      // --------------------------------------------------------

      if (todayChallenge == null) {
        await cancelChallengeReminder();

        debugPrint(
          'No incomplete challenge found for today.',
        );

        return;
      }

      debugPrint(
        'TODAY INCOMPLETE CHALLENGE FOUND: '
        '$todayChallenge',
      );

      // --------------------------------------------------------
      // REMINDER TIME
      // --------------------------------------------------------

      final String challengeReminderTime =
          currentSettings['challenge_reminder_time']?.toString() ?? '18:00';

      // --------------------------------------------------------
      // SCHEDULE
      // --------------------------------------------------------

      await _scheduleTodayChallengeReminder(
        time: challengeReminderTime,
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Challenge notification error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    } finally {
      _challengeSyncInProgress = false;
    }
  }

  // ============================================================
  // SCHEDULE TODAY'S CHALLENGE
  // ============================================================

  Future<void> _scheduleTodayChallengeReminder({
    required String time,
  }) async {
    final TimeOfDay? parsedTime = _parseTime(time);

    if (parsedTime == null) {
      debugPrint(
        'Invalid challenge reminder time: $time',
      );

      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    final tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    if (!scheduled.isAfter(now)) {
      await cancelChallengeReminder();

      debugPrint(
        'Challenge reminder time already passed today.',
      );

      return;
    }

    await _notifications.cancel(
      challengeReminderId,
    );

    await _notifications.zonedSchedule(
      challengeReminderId,
      "Today's Challenge",
      'You have an incomplete challenge for today. Keep going with NUVEXA!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'challenge_reminder',
    );

    debugPrint(
      'TODAY challenge reminder scheduled successfully.',
    );
  }

  // ============================================================
  // CANCEL CHALLENGE REMINDER
  // ============================================================

  Future<void> cancelChallengeReminder() async {
    await _notifications.cancel(
      challengeReminderId,
    );

    debugPrint(
      'Challenge reminder cancelled.',
    );
  }

  // ============================================================
  // CANCEL ALL NOTIFICATIONS
  // ============================================================

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();

    debugPrint(
      'All notifications cancelled.',
    );
  }

  // ============================================================
  // GET ALL PENDING NOTIFICATIONS
  // ============================================================

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) {
      await initialize();
    }

    final List<PendingNotificationRequest> pending =
        await _notifications.pendingNotificationRequests();

    debugPrint(
      'Pending notifications: ${pending.length}',
    );

    return pending;
  }

  // ============================================================
  // CANCEL ONE NOTIFICATION
  // ============================================================

  Future<void> cancelNotification(
    int id,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    await _notifications.cancel(id);

    debugPrint(
      'Notification cancelled: ID=$id',
    );
  }

  // ============================================================
  // TEST NOTIFICATION
  // ============================================================

  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    await _notifications.show(
      testNotificationId,
      'NUVEXA Test Notification',
      'Notifications are working correctly.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'test_notification',
    );

    debugPrint(
      'Test notification shown.',
    );
  }

  // ============================================================
  // REQUEST NOTIFICATION PERMISSION
  // ============================================================

  Future<bool> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
          await androidPlugin?.requestNotificationsPermission();

      debugPrint(
        'Android notification permission: '
        '$granted',
      );

      return granted ?? false;
    }

    return true;
  }

  // ============================================================
  // CHECK NOTIFICATION PERMISSION
  // ============================================================

  Future<bool> areNotificationsAllowed() async {
    if (!_initialized) {
      await initialize();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? enabled = await androidPlugin?.areNotificationsEnabled();

      debugPrint(
        'Android notifications enabled: '
        '$enabled',
      );

      return enabled ?? false;
    }

    return true;
  }

  // ============================================================
  // EXACT ALARM PERMISSION
  // ============================================================

  Future<bool> requestExactAlarmPermission() async {
    if (!_initialized) {
      await initialize();
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      return false;
    }

    try {
      final bool? granted = await androidPlugin.requestExactAlarmsPermission();

      debugPrint(
        'Exact alarm permission: '
        '$granted',
      );

      return granted ?? false;
    } catch (e) {
      debugPrint(
        'Exact alarm permission error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // NOTIFICATION RESPONSE
  // ============================================================

  void _onNotificationResponse(
    NotificationResponse response,
  ) {
    debugPrint(
      'Notification tapped: '
      'ID=${response.id}, '
      'payload=${response.payload}',
    );
  }

  // ============================================================
  // SETTINGS BOOLEAN
  // ============================================================

  bool _settingIsEnabled(dynamic value) {
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
  // CHALLENGE COMPLETION
  // ============================================================

  bool _isIncompleteChallenge(dynamic value) {
    if (value == null) {
      return true;
    }

    if (value is bool) {
      return !value;
    }

    if (value is int) {
      return value == 0;
    }

    if (value is String) {
      final String lower = value.toLowerCase().trim();

      return lower == '0' || lower == 'false' || lower == 'no';
    }

    return true;
  }

  // ============================================================
  // GET CHALLENGE DATE
  // ============================================================

  DateTime? _getChallengeDate(
    Map<String, dynamic> day,
  ) {
    final List<dynamic> possibleDates = [
      day['challenge_date'],
      day['day_date'],
      day['date'],
      day['activity_date'],
      day['scheduled_date'],
    ];

    for (final dynamic value in possibleDates) {
      if (value == null) {
        continue;
      }

      final DateTime? parsed = DateTime.tryParse(
        value.toString(),
      );

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  // ============================================================
  // SAME DATE
  // ============================================================

  bool _isSameDate(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  // ============================================================
  // PARSE HH:MM
  // ============================================================

  TimeOfDay? _parseTime(
    String value,
  ) {
    try {
      final List<String> parts = value.trim().split(':');

      if (parts.length != 2) {
        return null;
      }

      final int hour = int.parse(parts[0]);

      final int minute = int.parse(parts[1]);

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return null;
      }

      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _challengeSyncTimer?.cancel();

    _challengeSyncTimer = null;
  }
}
