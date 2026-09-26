import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../database/DatabaseHelper.dart';

class AddActivityPage extends StatefulWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? activityToEdit;

  const AddActivityPage({
    super.key,
    this.onBack,
    this.activityToEdit,
  });

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // ============================================================
  // VARIABLES
  // ============================================================

  String _selectedEmoji = '🔥';

  TimeOfDay _selectedTime = const TimeOfDay(
    hour: 8,
    minute: 30,
  );

  DateTime _activityDate = DateTime.now();

  bool _isChallenge = false;

  DateTime _challengeStartDate = DateTime.now();

  DateTime _challengeEndDate = DateTime.now().add(
    const Duration(days: 6),
  );

  int _challengeDays = 7;

  bool _showEmojiPicker = false;
  bool _isSaving = false;

  int? _editingActivityId;

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

    _durationController.text = '7';

    _loadEditingActivity();
  }

  // ============================================================
  // LOAD EDITING ACTIVITY
  // ============================================================

  void _loadEditingActivity() {
    final activity = widget.activityToEdit;

    if (activity == null) {
      return;
    }

    _editingActivityId = activity['id'] as int?;

    _nameController.text = activity['name']?.toString() ?? '';

    _selectedEmoji = activity['emoji']?.toString() ?? '🔥';

    // ----------------------------------------------------------
    // ACTIVITY DATE
    // ----------------------------------------------------------

    final activityDateString = activity['activity_date']?.toString();

    if (activityDateString != null) {
      try {
        _activityDate = DateTime.parse(activityDateString);
      } catch (_) {}
    }

    // ----------------------------------------------------------
    // START TIME
    // ----------------------------------------------------------

    final startTime = activity['start_time']?.toString();

    if (startTime != null) {
      final parts = startTime.split(':');

      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);

        if (hour != null && minute != null) {
          _selectedTime = TimeOfDay(
            hour: hour,
            minute: minute,
          );
        }
      }
    }

    // ----------------------------------------------------------
    // CHALLENGE
    // ----------------------------------------------------------

    _isChallenge = activity['is_challenge'] == 1;

    final startString = activity['challenge_start_date']?.toString();

    final endString = activity['challenge_end_date']?.toString();

    if (startString != null) {
      try {
        _challengeStartDate = DateTime.parse(startString);
      } catch (_) {}
    }

    if (endString != null) {
      try {
        _challengeEndDate = DateTime.parse(endString);
      } catch (_) {}
    }

    _challengeDays = _calculateInclusiveDays(
      _challengeStartDate,
      _challengeEndDate,
    );

    _durationController.text = _challengeDays.toString();
  }

  // ============================================================
  // CALCULATE DAYS
  // ============================================================

  int _calculateInclusiveDays(
    DateTime start,
    DateTime end,
  ) {
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

    return endOnly.difference(startOnly).inDays + 1;
  }

  // ============================================================
  // UPDATE CHALLENGE END DATE
  // ============================================================

  void _updateChallengeEndDate() {
    final days = int.tryParse(_durationController.text.trim()) ?? 1;

    final safeDays = days < 1 ? 1 : days;

    final start = DateTime(
      _challengeStartDate.year,
      _challengeStartDate.month,
      _challengeStartDate.day,
    );

    setState(() {
      _challengeDays = safeDays;

      _challengeEndDate = start.add(
        Duration(
          days: safeDays - 1,
        ),
      );
    });
  }

  // ============================================================
  // EMOJI
  // ============================================================

  void _selectEmoji(
    Category? category,
    Emoji emoji,
  ) {
    setState(() {
      _selectedEmoji = emoji.emoji;
      _showEmojiPicker = false;
    });
  }

  // ============================================================
  // PICK TIME
  // ============================================================

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accent,
              surface: cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedTime = picked;
    });
  }

  // ============================================================
  // PICK ACTIVITY DATE
  // ============================================================

  Future<void> _pickActivityDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _activityDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accent,
              surface: cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _activityDate = picked;
    });
  }

  // ============================================================
  // PICK CHALLENGE START DATE
  // ============================================================

  Future<void> _pickChallengeStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _challengeStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accent,
              surface: cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    final start = DateTime(
      picked.year,
      picked.month,
      picked.day,
    );

    setState(() {
      _challengeStartDate = start;

      _challengeEndDate = start.add(
        Duration(
          days: _challengeDays - 1,
        ),
      );

      _activityDate = start;
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveActivity() async {
    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter an activity name.');
      return;
    }

    if (_isChallenge) {
      final days = int.tryParse(_durationController.text.trim()) ?? 0;

      if (days < 1) {
        _showMessage(
          'Challenge duration must be at least 1 day.',
        );
        return;
      }

      _challengeDays = days;

      final start = DateTime(
        _challengeStartDate.year,
        _challengeStartDate.month,
        _challengeStartDate.day,
      );

      _challengeStartDate = start;

      _challengeEndDate = start.add(
        Duration(
          days: days - 1,
        ),
      );

      _activityDate = start;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // --------------------------------------------------------
      // START TIME
      // --------------------------------------------------------

      final String startTime =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:'
          '${_selectedTime.minute.toString().padLeft(2, '0')}';

      // --------------------------------------------------------
      // DATA
      // --------------------------------------------------------

      final Map<String, dynamic> data = {
        'emoji': _selectedEmoji,
        'name': name,
        'start_time': startTime,
        'activity_date': _dateTimeOnly(_activityDate),
        'is_challenge': _isChallenge ? 1 : 0,
        'challenge_start_date':
            _isChallenge ? _dateTimeOnly(_challengeStartDate) : null,
        'challenge_end_date':
            _isChallenge ? _dateTimeOnly(_challengeEndDate) : null,
        'is_completed': 0,
      };

      // --------------------------------------------------------
      // INSERT
      // --------------------------------------------------------

      if (_editingActivityId == null) {
        data['created_at'] = DateTime.now().toIso8601String();

        await DatabaseHelper.instance.insertActivityWithChallengeDays(data);
      }

      // --------------------------------------------------------
      // UPDATE
      // --------------------------------------------------------

      else {
        await DatabaseHelper.instance.updateActivityWithChallengeDays(
          _editingActivityId!,
          data,
        );
      }

      if (!mounted) {
        return;
      }

      final bool wasEditing = _editingActivityId != null;

      final bool wasChallenge = _isChallenge;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardColor2,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            wasEditing
                ? 'Activity updated successfully.'
                : wasChallenge
                    ? 'Challenge created successfully.'
                    : 'Activity created successfully.',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );

      // --------------------------------------------------------
      // SEPARATE ROUTE
      // --------------------------------------------------------

      if (widget.onBack == null) {
        Navigator.pop(
          context,
          true,
        );

        return;
      }

      // --------------------------------------------------------
      // EMBEDDED TAB
      // --------------------------------------------------------

      _clearForm();
    } catch (e) {
      debugPrint(
        'Error saving activity: $e',
      );

      if (mounted) {
        _showMessage(
          'Could not save activity.\n$e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    setState(() {
      _nameController.clear();

      _selectedEmoji = '🔥';

      _selectedTime = const TimeOfDay(
        hour: 8,
        minute: 30,
      );

      _activityDate = DateTime.now();

      _isChallenge = false;

      _challengeDays = 7;

      _durationController.text = '7';

      _challengeStartDate = DateTime.now();

      _challengeEndDate = DateTime.now().add(
        const Duration(days: 6),
      );

      _editingActivityId = null;

      _showEmojiPicker = false;
    });
  }

  // ============================================================
  // BACK
  // ============================================================

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ============================================================
  // DATE ONLY
  // ============================================================

  String _dateTimeOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cardColor2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool editing = _editingActivityId != null;

    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          onPressed: _goBack,
        ),
        title: Text(
          editing ? 'Edit Activity' : 'Create Activity',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER CARD
              // ==================================================

              _buildIntroCard(editing),

              const SizedBox(height: 22),

              // ==================================================
              // EMOJI
              // ==================================================

              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                    });
                  },
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cardColor2,
                          cardColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: accent.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.07),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _selectedEmoji,
                        style: const TextStyle(
                          fontSize: 46,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 9),

              const Center(
                child: Text(
                  'Tap to select emoji',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ),

              // ==================================================
              // EMOJI PICKER
              // ==================================================

              if (_showEmojiPicker)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: EmojiPicker(
                    onEmojiSelected: _selectEmoji,
                    config: const Config(
                      height: 300,
                    ),
                  ),
                ),

              const SizedBox(height: 27),

              // ==================================================
              // NAME
              // ==================================================

              _buildLabel(
                'ACTIVITY NAME',
                Icons.edit_rounded,
              ),

              const SizedBox(height: 9),

              TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: _inputDecoration(
                  'e.g. Exercise',
                  Icons.title_rounded,
                ),
              ),

              const SizedBox(height: 21),

              // ==================================================
              // TIME
              // ==================================================

              _buildLabel(
                'START TIME',
                Icons.access_time_rounded,
              ),

              const SizedBox(height: 9),

              _buildSelectionCard(
                icon: Icons.access_time_rounded,
                text: _selectedTime.format(context),
                onTap: _pickTime,
              ),

              const SizedBox(height: 21),

              // ==================================================
              // DATE
              // ==================================================

              _buildLabel(
                'ACTIVITY DATE',
                Icons.calendar_today_rounded,
              ),

              const SizedBox(height: 9),

              _buildSelectionCard(
                icon: Icons.calendar_today_rounded,
                text: '${_activityDate.day}/'
                    '${_activityDate.month}/'
                    '${_activityDate.year}',
                onTap: _pickActivityDate,
              ),

              const SizedBox(height: 24),

              // ==================================================
              // CHALLENGE SWITCH
              // ==================================================

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cardColor2,
                      cardColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isChallenge ? accent.withOpacity(0.25) : border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isChallenge
                          ? accent.withOpacity(0.05)
                          : Colors.transparent,
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 7,
                  ),
                  title: const Text(
                    'Make this a Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Track completion day by day',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  secondary: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: accent,
                      size: 21,
                    ),
                  ),
                  value: _isChallenge,
                  activeColor: accent,
                  onChanged: (value) {
                    setState(() {
                      _isChallenge = value;

                      if (value) {
                        _challengeStartDate = DateTime(
                          _activityDate.year,
                          _activityDate.month,
                          _activityDate.day,
                        );

                        _challengeEndDate = _challengeStartDate.add(
                          Duration(
                            days: _challengeDays - 1,
                          ),
                        );
                      }
                    });
                  },
                ),
              ),

              // ==================================================
              // CHALLENGE SETTINGS
              // ==================================================

              if (_isChallenge) ...[
                const SizedBox(height: 22),
                _buildLabel(
                  'CHALLENGE START DATE',
                  Icons.calendar_month_rounded,
                ),
                const SizedBox(height: 9),
                _buildSelectionCard(
                  icon: Icons.calendar_month_rounded,
                  text: '${_challengeStartDate.day}/'
                      '${_challengeStartDate.month}/'
                      '${_challengeStartDate.year}',
                  onTap: _pickChallengeStartDate,
                ),
                const SizedBox(height: 21),
                _buildLabel(
                  'CHALLENGE DURATION',
                  Icons.timelapse_rounded,
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  onChanged: (_) {
                    _updateChallengeEndDate();
                  },
                  decoration: _inputDecoration(
                    'Enter number of days',
                    Icons.timelapse_rounded,
                  ).copyWith(
                    suffixText: 'days',
                    suffixStyle: const TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentDark.withOpacity(0.12),
                        cyan.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: accent.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: cyan,
                        size: 20,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Challenge ends on '
                          '${_challengeEndDate.day}/'
                          '${_challengeEndDate.month}/'
                          '${_challengeEndDate.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '$_challengeDays day challenge',
                  style: const TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Each day is tracked separately. '
                  'You can complete the days individually.',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              _buildSaveButton(),

              const SizedBox(height: 10),

              if (editing)
                Center(
                  child: TextButton(
                    onPressed: _goBack,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INTRO CARD
  // ============================================================

  Widget _buildIntroCard(bool editing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentDark.withOpacity(0.12),
            cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              editing ? Icons.edit_note_rounded : Icons.add_task_rounded,
              color: accent,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'UPDATE YOUR ACTIVITY' : 'CREATE NEW ACTIVITY',
                  style: TextStyle(
                    color: accent.withOpacity(0.75),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  editing
                      ? 'Make changes to your routine.'
                      : 'Build a routine that moves you forward.',
                  style: const TextStyle(
                    color: Colors.white,
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

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: accent,
          size: 15,
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SELECTION CARD
  // ============================================================

  Widget _buildSelectionCard({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white24,
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent,
              accentDark,
            ],
          ),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.20),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveActivity,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: background,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _editingActivityId == null
                          ? Icons.check_rounded
                          : Icons.save_rounded,
                      size: 21,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _editingActivityId == null
                          ? (_isChallenge
                              ? 'Create Challenge'
                              : 'Create Activity')
                          : 'Update Activity',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration(
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white30,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: accent.withOpacity(0.7),
        size: 20,
      ),
      filled: true,
      fillColor: cardColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: accent,
        ),
      ),
    );
  }
}
