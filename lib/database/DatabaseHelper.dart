import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    return instance;
  }

  // ============================================================
  // DATABASE
  // ============================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      'addiction_tracker.db',
    );

    return await openDatabase(
      path,

      // UPDATED: 6 -> 7
      version: 7,

      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (db, version) async {
        await _createDatabase(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeDatabase(
          db,
          oldVersion,
          newVersion,
        );
      },
    );
  }

  // ============================================================
  // CREATE DATABASE
  // ============================================================

  Future<void> _createDatabase(Database db) async {
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emoji TEXT NOT NULL,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        activity_date TEXT NOT NULL,
        is_challenge INTEGER NOT NULL DEFAULT 0,
        challenge_start_date TEXT,
        challenge_end_date TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE challenge_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        challenge_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        FOREIGN KEY (activity_id)
          REFERENCES activities(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_challenge_days_activity_id
      ON challenge_days(activity_id)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_challenge_days_unique
      ON challenge_days(activity_id, challenge_date)
    ''');

    // ==========================================================
    // PROFILE
    // ==========================================================

    await db.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL DEFAULT 'NUVEXA User',
        nickname TEXT NOT NULL DEFAULT '',
        profile_image TEXT
      )
    ''');

    await db.insert(
      'profile',
      {
        'id': 1,
        'username': 'NUVEXA User',
        'nickname': '',
        'profile_image': null,
      },
    );

    // ==========================================================
    // SETTINGS
    // ==========================================================

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        daily_reminder_enabled INTEGER NOT NULL DEFAULT 1,
        daily_reminder_time TEXT NOT NULL DEFAULT '20:00',
        challenge_reminders_enabled INTEGER NOT NULL DEFAULT 1,
        challenge_reminder_time TEXT NOT NULL DEFAULT '18:00',

        week_start_day INTEGER NOT NULL DEFAULT 1,
        default_activity_time TEXT NOT NULL DEFAULT '08:30',
        confirm_delete INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.insert(
      'settings',
      {
        'id': 1,
        'notifications_enabled': 1,
        'daily_reminder_enabled': 1,
        'daily_reminder_time': '20:00',
        'challenge_reminders_enabled': 1,

        // NEW
        'challenge_reminder_time': '18:00',

        'week_start_day': 1,
        'default_activity_time': '08:30',
        'confirm_delete': 1,
      },
    );
  }

  // ============================================================
  // DATABASE UPGRADE
  // ============================================================

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version 1 -> 2
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE activities
        ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0
      ''');
    }

    // Version 2 -> 3
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS challenge_days (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          activity_id INTEGER NOT NULL,
          challenge_date TEXT NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          completed_at TEXT,
          FOREIGN KEY (activity_id)
            REFERENCES activities(id)
            ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_challenge_days_activity_id
        ON challenge_days(activity_id)
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_challenge_days_unique
        ON challenge_days(activity_id, challenge_date)
      ''');
    }

    // Version 3 -> 4
    if (oldVersion < 4) {
      await _backfillExistingChallenges(db);
    }

    // Version 4 -> 5
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS profile (
          id INTEGER PRIMARY KEY,
          username TEXT NOT NULL DEFAULT 'NUVEXA User',
          nickname TEXT NOT NULL DEFAULT '',
          profile_image TEXT
        )
      ''');

      final profile = await db.query(
        'profile',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (profile.isEmpty) {
        await db.insert(
          'profile',
          {
            'id': 1,
            'username': 'NUVEXA User',
            'nickname': '',
            'profile_image': null,
          },
        );
      }
    }

    // Version 5 -> 6
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          id INTEGER PRIMARY KEY,
          notifications_enabled INTEGER NOT NULL DEFAULT 1,
          daily_reminder_enabled INTEGER NOT NULL DEFAULT 1,
          daily_reminder_time TEXT NOT NULL DEFAULT '20:00',
          challenge_reminders_enabled INTEGER NOT NULL DEFAULT 1,
          week_start_day INTEGER NOT NULL DEFAULT 1,
          default_activity_time TEXT NOT NULL DEFAULT '08:30',
          confirm_delete INTEGER NOT NULL DEFAULT 1
        )
      ''');

      final settings = await db.query(
        'settings',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );

      if (settings.isEmpty) {
        await db.insert(
          'settings',
          {
            'id': 1,
            'notifications_enabled': 1,
            'daily_reminder_enabled': 1,
            'daily_reminder_time': '20:00',
            'challenge_reminders_enabled': 1,
            'week_start_day': 1,
            'default_activity_time': '08:30',
            'confirm_delete': 1,
          },
        );
      }
    }

    // ==========================================================
    // Version 6 -> 7
    // Add independent challenge reminder time
    // ==========================================================

    if (oldVersion < 7) {
      await db.execute('''
        ALTER TABLE settings
        ADD COLUMN challenge_reminder_time TEXT NOT NULL DEFAULT '18:00'
      ''');
    }
  }

  // ============================================================
  // BACKFILL OLD CHALLENGES
  // ============================================================

  Future<void> _backfillExistingChallenges(
    Database db,
  ) async {
    final challenges = await db.query(
      'activities',
      where: '''
        is_challenge = 1
        AND challenge_start_date IS NOT NULL
        AND challenge_end_date IS NOT NULL
      ''',
    );

    for (final challenge in challenges) {
      final activityId = challenge['id'] as int;

      final startString = challenge['challenge_start_date']?.toString();

      final endString = challenge['challenge_end_date']?.toString();

      if (startString == null || endString == null) {
        continue;
      }

      final start = DateTime.tryParse(startString);
      final end = DateTime.tryParse(endString);

      if (start == null || end == null) {
        continue;
      }

      DateTime current = DateTime(
        start.year,
        start.month,
        start.day,
      );

      final endOnly = DateTime(
        end.year,
        end.month,
        end.day,
      );

      while (!current.isAfter(endOnly)) {
        final dateString = _dateOnlyString(current);

        await db.insert(
          'challenge_days',
          {
            'activity_id': activityId,
            'challenge_date': dateString,
            'is_completed': 0,
            'completed_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        current = current.add(
          const Duration(days: 1),
        );
      }
    }
  }

  // ============================================================
  // DATE HELPER
  // ============================================================

  String _dateOnlyString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<Map<String, dynamic>> getProfile() async {
    final db = await database;

    final result = await db.query(
      'profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (result.isEmpty) {
      await db.insert(
        'profile',
        {
          'id': 1,
          'username': 'NUVEXA User',
          'nickname': '',
          'profile_image': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      return {
        'id': 1,
        'username': 'NUVEXA User',
        'nickname': '',
        'profile_image': null,
      };
    }

    return result.first;
  }

  Future<int> updateProfile({
    required String username,
    required String nickname,
    String? profileImage,
  }) async {
    final db = await database;

    return await db.update(
      'profile',
      {
        'username': username.trim().isEmpty ? 'NUVEXA User' : username.trim(),
        'nickname': nickname.trim(),
        'profile_image': profileImage,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<Map<String, dynamic>> getSettings() async {
    final db = await database;

    final result = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (result.isEmpty) {
      final defaultSettings = {
        'id': 1,
        'notifications_enabled': 1,
        'daily_reminder_enabled': 1,
        'daily_reminder_time': '20:00',
        'challenge_reminders_enabled': 1,

        // NEW
        'challenge_reminder_time': '18:00',

        'week_start_day': 1,
        'default_activity_time': '08:30',
        'confirm_delete': 1,
      };

      await db.insert(
        'settings',
        defaultSettings,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      return defaultSettings;
    }

    return result.first;
  }

  Future<int> updateSettings(
    Map<String, dynamic> values,
  ) async {
    final db = await database;

    return await db.update(
      'settings',
      values,
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ============================================================
  // DATABASE INFORMATION
  // ============================================================

  Future<Map<String, int>> getDatabaseCounts() async {
    final db = await database;

    final activityResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM activities',
    );

    final challengeDayResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM challenge_days',
    );

    final completedActivityResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM activities
      WHERE is_completed = 1
      ''',
    );

    final completedChallengeResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM challenge_days
      WHERE is_completed = 1
      ''',
    );

    return {
      'activities': (activityResult.first['count'] as int?) ?? 0,
      'challenge_days': (challengeDayResult.first['count'] as int?) ?? 0,
      'completed_activities':
          (completedActivityResult.first['count'] as int?) ?? 0,
      'completed_challenge_days':
          (completedChallengeResult.first['count'] as int?) ?? 0,
    };
  }

  // ============================================================
  // RESET ALL ACTIVITY DATA
  // ============================================================

  Future<void> resetAllActivities() async {
    final db = await database;

    await db.transaction(
      (txn) async {
        await txn.delete('challenge_days');
        await txn.delete('activities');
      },
    );
  }

  // ============================================================
  // INSERT ACTIVITY
  // ============================================================

  Future<int> insertActivity(
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    return await db.insert(
      'activities',
      data,
    );
  }

  // ============================================================
  // INSERT ACTIVITY + CHALLENGE DAYS
  // ============================================================

  Future<int> insertActivityWithChallengeDays(
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    int activityId = -1;

    await db.transaction(
      (txn) async {
        activityId = await txn.insert(
          'activities',
          data,
        );

        if (data['is_challenge'] == 1) {
          final startString = data['challenge_start_date']?.toString();

          final endString = data['challenge_end_date']?.toString();

          if (startString != null && endString != null) {
            final start = DateTime.tryParse(startString);
            final end = DateTime.tryParse(endString);

            if (start != null && end != null) {
              DateTime current = DateTime(
                start.year,
                start.month,
                start.day,
              );

              final endOnly = DateTime(
                end.year,
                end.month,
                end.day,
              );

              while (!current.isAfter(endOnly)) {
                await txn.insert(
                  'challenge_days',
                  {
                    'activity_id': activityId,
                    'challenge_date': _dateOnlyString(current),
                    'is_completed': 0,
                    'completed_at': null,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );

                current = current.add(
                  const Duration(days: 1),
                );
              }
            }
          }
        }
      },
    );

    return activityId;
  }

  // ============================================================
  // CREATE CHALLENGE DAYS
  // ============================================================

  Future<void> createChallengeDays(
    int activityId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;

    DateTime current = DateTime(
      start.year,
      start.month,
      start.day,
    );

    final endOnly = DateTime(
      end.year,
      end.month,
      end.day,
    );

    while (!current.isAfter(endOnly)) {
      await db.insert(
        'challenge_days',
        {
          'activity_id': activityId,
          'challenge_date': _dateOnlyString(current),
          'is_completed': 0,
          'completed_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      current = current.add(
        const Duration(days: 1),
      );
    }
  }

  // ============================================================
  // GET ALL ACTIVITIES
  // ============================================================

  Future<List<Map<String, dynamic>>> getActivities() async {
    final db = await database;

    return await db.query(
      'activities',
      orderBy: 'activity_date ASC, start_time ASC',
    );
  }

  // ============================================================
  // GET ALL CHALLENGE DAYS
  // ============================================================

  Future<List<Map<String, dynamic>>> getAllChallengeDays() async {
    final db = await database;

    return await db.query(
      'challenge_days',
      orderBy: 'activity_id ASC, challenge_date ASC',
    );
  }

  // ============================================================
  // GET CHALLENGE DAYS FOR ONE ACTIVITY
  // ============================================================

  Future<List<Map<String, dynamic>>> getChallengeDays(
    int activityId,
  ) async {
    final db = await database;

    return await db.query(
      'challenge_days',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'challenge_date ASC',
    );
  }

  // ============================================================
  // GET CHALLENGE DAYS WITH PROGRESS
  // ============================================================

  Future<List<Map<String, dynamic>>> getChallengeDaysWithProgress(
    int activityId,
  ) async {
    return await getChallengeDays(activityId);
  }

  // ============================================================
  // GET ONE CHALLENGE DAY
  // ============================================================

  Future<Map<String, dynamic>?> getChallengeDay(
    int activityId,
    String date,
  ) async {
    final db = await database;

    final result = await db.query(
      'challenge_days',
      where: '''
        activity_id = ?
        AND challenge_date = ?
      ''',
      whereArgs: [
        activityId,
        date,
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ============================================================
  // GET TODAY'S CHALLENGE DAYS
  // ============================================================

  Future<List<Map<String, dynamic>>> getTodayChallengeDays() async {
    final db = await database;

    final today = _dateOnlyString(
      DateTime.now(),
    );

    return await db.query(
      'challenge_days',
      where: 'challenge_date = ?',
      whereArgs: [today],
      orderBy: 'activity_id ASC',
    );
  }

  // ============================================================
  // UPDATE NORMAL ACTIVITY COMPLETION
  // ============================================================

  Future<int> updateActivityCompletion(
    int activityId,
    bool completed,
  ) async {
    final db = await database;

    return await db.update(
      'activities',
      {
        'is_completed': completed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  // ============================================================
  // UPDATE CHALLENGE DAY COMPLETION
  // ============================================================

  Future<int> updateChallengeDayCompletion(
    int challengeDayId,
    bool completed,
  ) async {
    final db = await database;

    return await db.update(
      'challenge_days',
      {
        'is_completed': completed ? 1 : 0,
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [challengeDayId],
    );
  }

  // ============================================================
  // TOGGLE CHALLENGE DAY
  // ============================================================

  Future<void> toggleChallengeDay(
    int challengeDayId,
    bool completed,
  ) async {
    await updateChallengeDayCompletion(
      challengeDayId,
      completed,
    );
  }

  // ============================================================
  // GET CHALLENGE PROGRESS
  // ============================================================

  Future<Map<String, int>> getChallengeProgress(
    int activityId,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total,
        SUM(
          CASE
            WHEN is_completed = 1 THEN 1
            ELSE 0
          END
        ) AS completed
      FROM challenge_days
      WHERE activity_id = ?
      ''',
      [activityId],
    );

    final row = result.first;

    return {
      'total': (row['total'] as int?) ?? 0,
      'completed': (row['completed'] as int?) ?? 0,
    };
  }

  // ============================================================
  // UPDATE ACTIVITY + CHALLENGE DAYS
  // ============================================================

  Future<void> updateActivityWithChallengeDays(
    int activityId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;

    await db.transaction(
      (txn) async {
        await txn.update(
          'activities',
          data,
          where: 'id = ?',
          whereArgs: [activityId],
        );

        // If activity is no longer a challenge,
        // remove all challenge days.
        if (data['is_challenge'] != 1) {
          await txn.delete(
            'challenge_days',
            where: 'activity_id = ?',
            whereArgs: [activityId],
          );

          return;
        }

        final startString = data['challenge_start_date']?.toString();

        final endString = data['challenge_end_date']?.toString();

        if (startString == null || endString == null) {
          return;
        }

        final start = DateTime.tryParse(startString);
        final end = DateTime.tryParse(endString);

        if (start == null || end == null) {
          return;
        }

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

        DateTime current = startOnly;

        while (!current.isAfter(endOnly)) {
          final dateString = _dateOnlyString(current);

          await txn.insert(
            'challenge_days',
            {
              'activity_id': activityId,
              'challenge_date': dateString,
              'is_completed': 0,
              'completed_at': null,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          current = current.add(
            const Duration(days: 1),
          );
        }

        // Remove days outside updated range.
        await txn.delete(
          'challenge_days',
          where: '''
            activity_id = ?
            AND (
              challenge_date < ?
              OR challenge_date > ?
            )
          ''',
          whereArgs: [
            activityId,
            _dateOnlyString(startOnly),
            _dateOnlyString(endOnly),
          ],
        );
      },
    );
  }

  // ============================================================
  // DELETE ACTIVITY
  // ============================================================

  Future<void> deleteActivity(
    int activityId,
  ) async {
    final db = await database;

    await db.transaction(
      (txn) async {
        await txn.delete(
          'challenge_days',
          where: 'activity_id = ?',
          whereArgs: [activityId],
        );

        await txn.delete(
          'activities',
          where: 'id = ?',
          whereArgs: [activityId],
        );
      },
    );
  }

  // ============================================================
  // CLOSE DATABASE
  // ============================================================

  Future<void> close() async {
    final db = _database;

    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
