import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';
import 'dialogue_engine.dart';
import 'vui_theme.dart';
import 'navigation_notifier.dart';

class VuiStateManager extends ChangeNotifier {
  final DialogueEngine _engine = DialogueEngine();

  // ── State ─────────────────────────────────────────────────────────────────
  VuiState _state = VuiState.idle;
  VuiModule _currentModule = VuiModule.mood;
  late DialogueNode _currentNode;
  final List<Map<String, String>> _chatHistory = [];

  bool _isMuted = false;
  String _speechText = '';

  // Navigation
  NavigationNotifier? _nav;

  // Emotion metadata
  String _detectedEmotion = '';
  String _detectedIntensity = '';

  // Mood labels and selection
  static const List<String> moodLabels = ['Happy', 'Calm', 'Sad', 'Angry', 'Distressed'];
  int _selectedEmojiIndex = 0;

  // Dynamic weekly mood values & days
  List<double> _weekValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<String> _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  int _highlightIndex = 6;
  double _latestMoodScore = 0.50;

  // Track the occurrences of each mood for analysis
  Map<String, int> _weeklyMoodCounts = {
    'Happy': 0,
    'Calm': 0,
    'Sad': 0,
    'Angry': 0,
    'Distressed': 0,
  };

  // Sleep tracking state
  int _sleepHours = 6;
  int _sleepMinutes = 40;
  String _sleepQuality = "Fair";
  Color _sleepQualityColor = VuiTheme.moodColor;

  // Bedtime routine state
  String _bedtimeRoutine = "10:30 PM";
  List<bool> _routineChecklist = [false, false, false];

  // Breathing state
  String _breathingPhase = 'Inhale';
  int _breathingCycle = 1;
  final int _maxCycles = 4;
  bool _isBreathingActive = false;
  Timer? _breathingTimer;

  // STT / TTS
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _sttInitialized = false;
  bool _simulatedMode = false;

  // Pending close flag (speak goodbye then exit)
  bool _pendingClose = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  VuiState get state => _state;
  VuiModule get currentModule => _currentModule;
  DialogueNode get currentNode => _currentNode;
  List<Map<String, String>> get chatHistory => _chatHistory;
  bool get isMuted => _isMuted;
  String get speechText => _speechText;
  String get detectedEmotion => _detectedEmotion;
  String get detectedIntensity => _detectedIntensity;
  int get selectedEmojiIndex => _selectedEmojiIndex;
  List<double> get weekValues => _weekValues;
  List<String> get weekDays => _weekDays;
  int get highlightIndex => _highlightIndex;

  void selectEmoji(int index) {
    if (index >= 0 && index < moodLabels.length) {
      _selectedEmojiIndex = index;
      submitSimulatedSpeech(moodLabels[index]);
    }
  }

  double get latestMoodScore => _latestMoodScore;
  Map<String, int> get weeklyMoodCounts => _weeklyMoodCounts;

  void _shiftWeeklyChart(double newValue) {
    // Immediate in-memory update for fluid UI feedback
    _weekValues = [..._weekValues.sublist(1), newValue];
    _weekDays = [..._weekDays.sublist(1), _getWeekdayLabel(DateTime.now().weekday)];
    _highlightIndex = 6;
    _latestMoodScore = newValue;
    notifyListeners();

    // Async persistent save to DB and complete refresh
    final moodName = _detectedEmotion.isEmpty ? 'Neutral' : _detectedEmotion;
    DatabaseHelper.instance.insertMood(moodName, newValue).then((_) {
      _loadMoodHistoryFromDb();
    }).catchError((e) {
      debugPrint("DB save failed: $e");
    });
  }

  Future<void> _loadMoodHistoryFromDb() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Fetch all mood check-ins sorted chronologically
      final List<Map<String, dynamic>> allMoods = await db.query(
        'moods',
        orderBy: 'timestamp ASC',
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Create lists for the last 7 calendar days (ending with today)
      final List<double> newValues = List.filled(7, 0.0);
      final List<String> newDays = List.filled(7, '');

      // Reset mood counts for analytics
      final Map<String, int> counts = {
        'Happy': 0,
        'Calm': 0,
        'Sad': 0,
        'Angry': 0,
        'Distressed': 0,
      };

      for (int i = 0; i < 7; i++) {
        final targetDate = today.subtract(Duration(days: 6 - i));
        newDays[i] = _getWeekdayLabel(targetDate.weekday);

        // Find all check-ins on this specific calendar day
        final dayMoods = allMoods.where((m) {
          final timestampStr = m['timestamp'] as String;
          final date = DateTime.tryParse(timestampStr);
          if (date == null) return false;
          return date.year == targetDate.year &&
                 date.month == targetDate.month &&
                 date.day == targetDate.day;
        }).toList();

        if (dayMoods.isNotEmpty) {
          // Average the mood scores for this day
          final sum = dayMoods.fold<double>(0.0, (prev, element) => prev + (element['score'] as double));
          newValues[i] = sum / dayMoods.length;
        } else {
          // Default to 0.0 (empty bar) if no check-in occurred on this day
          newValues[i] = 0.0;
        }
      }

      // Filter and count occurrences in the 7-day weekly window (from 6 days ago to today)
      final sevenDaysAgo = today.subtract(const Duration(days: 6));
      final weeklyMoods = allMoods.where((m) {
        final timestampStr = m['timestamp'] as String;
        final date = DateTime.tryParse(timestampStr);
        if (date == null) return false;
        return date.isAfter(sevenDaysAgo) || 
               (date.year == sevenDaysAgo.year && date.month == sevenDaysAgo.month && date.day == sevenDaysAgo.day);
      }).toList();

      for (var m in weeklyMoods) {
        final mood = m['mood'] as String;
        final matchedKey = moodLabels.firstWhere(
          (l) => l.toLowerCase() == mood.toLowerCase(),
          orElse: () => '',
        );
        if (matchedKey.isNotEmpty) {
          counts[matchedKey] = (counts[matchedKey] ?? 0) + 1;
        }
      }

      _weekValues = newValues;
      _weekDays = newDays;
      _weeklyMoodCounts = counts;

      // Calculate average score of all check-ins in the weekly window (last 7 days)
      if (weeklyMoods.isNotEmpty) {
        final sum = weeklyMoods.fold<double>(0.0, (prev, m) => prev + (m['score'] as double));
        _latestMoodScore = sum / weeklyMoods.length;
      } else {
        _latestMoodScore = 0.0;
      }

      // Update latest detected emotion from the database to reflect active mood
      final latest = await DatabaseHelper.instance.getLatestSingleMood();
      if (latest != null) {
        _detectedEmotion = latest['mood'] as String;

        final idx = moodLabels.indexWhere((l) => l.toLowerCase() == _detectedEmotion.toLowerCase());
        if (idx != -1) {
          _selectedEmojiIndex = idx;
        }
      } else {
        _detectedEmotion = '';
        _selectedEmojiIndex = 0;
      }

      _highlightIndex = 6; // Highlight today's bar
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load mood history: $e");
    }
  }

  Future<void> resetWeeklyData() async {
    try {
      await DatabaseHelper.instance.clearAllMoods();
      await _loadMoodHistoryFromDb();
    } catch (e) {
      debugPrint("Reset weekly data failed: $e");
    }
  }

  String _getWeekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'M';
      case DateTime.tuesday: return 'T';
      case DateTime.wednesday: return 'W';
      case DateTime.thursday: return 'T';
      case DateTime.friday: return 'F';
      case DateTime.saturday: return 'S';
      case DateTime.sunday: return 'S';
      default: return '';
    }
  }

  int get sleepHours => _sleepHours;
  int get sleepMinutes => _sleepMinutes;
  String get sleepQuality => _sleepQuality;
  Color get sleepQualityColor => _sleepQualityColor;

  void updateSleepTime(int hours, int minutes) {
    _sleepHours = hours;
    _sleepMinutes = minutes;
    
    final totalHours = hours + (minutes / 60.0);
    if (totalHours < 6.0) {
      _sleepQuality = "Poor";
      _sleepQualityColor = VuiTheme.crisisColor;
    } else if (totalHours <= 7.5) {
      _sleepQuality = "Fair";
      _sleepQualityColor = VuiTheme.moodColor;
    } else {
      _sleepQuality = "Good";
      _sleepQualityColor = VuiTheme.breathingColor;
    }
    notifyListeners();
  }

  bool _isReportingSleepTime(String text) {
    final lower = text.toLowerCase();
    final sleepTimeRegExp = RegExp(r'\b(sleep|slept|hours|hrs|hr|h|minutes|mins|m)\b');
    final numberRegExp = RegExp(r'\d+');
    return sleepTimeRegExp.hasMatch(lower) && numberRegExp.hasMatch(lower);
  }

  void _parseAndSetSleepTime(String text) {
    final lower = text.toLowerCase().trim();
    int hours = 0;
    int minutes = 0;
    bool matched = false;

    // Try to match decimals first: e.g. "7.5 hours", "6.5h"
    final decimalRegExp = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr|h)\b');
    final decimalMatch = decimalRegExp.firstMatch(lower);
    if (decimalMatch != null) {
      final val = double.tryParse(decimalMatch.group(1) ?? '');
      if (val != null) {
        hours = val.floor();
        minutes = ((val - hours) * 60).round();
        matched = true;
      }
    }

    if (!matched) {
      // Try to match hours and minutes: e.g. "7 hours and 30 minutes", "6h 40m"
      final hoursRegExp = RegExp(r'(\d+)\s*(?:hour|hr|h)\b');
      final minutesRegExp = RegExp(r'(\d+)\s*(?:minute|min|m)\b');
      
      final hoursMatch = hoursRegExp.firstMatch(lower);
      final minutesMatch = minutesRegExp.firstMatch(lower);

      if (hoursMatch != null) {
        hours = int.tryParse(hoursMatch.group(1) ?? '') ?? 0;
        matched = true;
      }
      if (minutesMatch != null) {
        minutes = int.tryParse(minutesMatch.group(1) ?? '') ?? 0;
        matched = true;
      }
    }

    // Fallback plain number
    if (!matched) {
      final plainNumberRegExp = RegExp(r'\b(\d+)\b');
      final plainMatch = plainNumberRegExp.firstMatch(lower);
      if (plainMatch != null) {
        final val = int.tryParse(plainMatch.group(1) ?? '');
        if (val != null && val > 0 && val <= 24) {
          hours = val;
          matched = true;
        }
      }
    }

    if (matched && (hours > 0 || minutes > 0)) {
      updateSleepTime(hours, minutes);
    }
  }

  String get bedtimeRoutine => _bedtimeRoutine;
  List<bool> get routineChecklist => _routineChecklist;

  void toggleChecklistItem(int index, {bool? value}) {
    if (index >= 0 && index < _routineChecklist.length) {
      _routineChecklist[index] = value ?? !_routineChecklist[index];
      notifyListeners();
    }
  }

  void updateBedtimeRoutine(String time) {
    _bedtimeRoutine = time;
    notifyListeners();
  }

  bool _isBedtimeRoutineCommand(String text) {
    final lower = text.toLowerCase();
    bool isSettingTime = lower.contains('bedtime') && RegExp(r'\d+').hasMatch(lower);
    bool isChecklistCommand = lower.contains('screens') ||
        lower.contains('phone') ||
        lower.contains('room') ||
        lower.contains('temp') ||
        lower.contains('cool') ||
        lower.contains('wake') ||
        lower.contains('consistent') ||
        lower.contains('checklist');
    return isSettingTime || isChecklistCommand;
  }

  String _processBedtimeRoutineCommand(String text) {
    final lower = text.toLowerCase();
    
    // 1. Time setting
    final timeRegExp = RegExp(r'(\d{1,2}(?::\d{2})?\s*(?:pm|am)?)', caseSensitive: false);
    final timeMatch = timeRegExp.firstMatch(lower);
    if (timeMatch != null && lower.contains('bedtime')) {
      final timeStr = timeMatch.group(1)?.toUpperCase() ?? '';
      String formattedTime = timeStr;
      if (!formattedTime.contains('AM') && !formattedTime.contains('PM')) {
        final parts = formattedTime.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        if (hour > 0 && hour <= 12) {
          formattedTime = "$formattedTime PM";
        }
      }
      updateBedtimeRoutine(formattedTime);
      return "Okay, I've updated tonight's bedtime routine to $formattedTime.";
    }

    // 2. Checklist items
    bool updated = false;
    if (lower.contains('screens') || lower.contains('phone')) {
      bool isDone = !lower.contains('not') && !lower.contains('uncheck');
      toggleChecklistItem(0, value: isDone);
      updated = true;
    }
    if (lower.contains('room') || lower.contains('temp') || lower.contains('cool')) {
      bool isDone = !lower.contains('not') && !lower.contains('uncheck');
      toggleChecklistItem(1, value: isDone);
      updated = true;
    }
    if (lower.contains('wake') || lower.contains('consistent')) {
      bool isDone = !lower.contains('not') && !lower.contains('uncheck');
      toggleChecklistItem(2, value: isDone);
      updated = true;
    }

    if (lower.contains('reset') && lower.contains('checklist')) {
      _routineChecklist = [false, false, false];
      notifyListeners();
      return "I've reset tonight's routine checklist.";
    }

    if (updated) {
      return "Great, I've updated tonight's routine checklist. Keep it up!";
    }

    return "Tonight's routine updated.";
  }
  String get breathingPhase => _breathingPhase;
  int get breathingCycle => _breathingCycle;
  int get maxCycles => _maxCycles;
  bool get isBreathingActive => _isBreathingActive;

  // ── Constructor ───────────────────────────────────────────────────────────
  VuiStateManager() {
    _currentNode = _engine.getNode('mood_start');
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initVoiceServices();
    _loadMoodHistoryFromDb();
  }

  void setNavigationNotifier(NavigationNotifier nav) {
    _nav = nav;
  }

  // ── Initialisation ────────────────────────────────────────────────────────
  Future<void> _initVoiceServices() async {
    try {
      // 1. Explicitly request Microphone permissions (vital for Android 11+)
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (status.isPermanentlyDenied) {
        debugPrint('Microphone permission permanently denied. Open app settings.');
      }

      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.47);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.05);

      _tts.setCompletionHandler(() {
        if (_pendingClose) {
          _pendingClose = false;
          SystemNavigator.pop();
          return;
        }
        if (_state == VuiState.speaking) {
          if (_currentNode.chips.isNotEmpty) {
            startListening();
          } else {
            _setState(VuiState.idle);
          }
        }
      });

      _sttInitialized = await _speech.initialize(
        onStatus: (val) {
          if ((val == 'done' || val == 'notListening') &&
              _state == VuiState.listening) {
            _onSpeechFinished();
          }
        },
        onError: (val) => debugPrint('STT Error: $val'),
      );

      if (!_sttInitialized) {
        debugPrint('STT init failed – simulated mode');
        _simulatedMode = true;
      }
    } catch (e) {
      debugPrint('Voice services failed: $e – simulated mode');
      _simulatedMode = true;
    }

    triggerGreeting();
  }

  void _setState(VuiState newState) {
    _state = newState;
    notifyListeners();
  }

  // ── Toggle mute ───────────────────────────────────────────────────────────
  void toggleMute() {
    _isMuted = !_isMuted;
    _tts.setVolume(_isMuted ? 0.0 : 1.0);
    notifyListeners();
  }

  // ── Greeting ──────────────────────────────────────────────────────────────
  void triggerGreeting() {
    _chatHistory.clear();
    _currentModule = VuiModule.mood;
    _currentNode = _engine.getNode('mood_start');
    _speakSera(
      "Hi! I'm Sera, your mental health companion. "
      "How are you feeling today? "
      "You can talk to me, or say commands like 'mood', 'breathe', 'sleep', or 'help'.",
    );
  }

  // ── Module transition (called from nav bar taps) ──────────────────────────
  void transitionToModule(VuiModule module) {
    _cancelBreathing();
    _tts.stop();
    _speech.stop();
    _currentModule = module;

    switch (module) {
      case VuiModule.mood:
        _currentNode = _engine.getNode('mood_start');
        break;
      case VuiModule.sleep:
        _currentNode = _engine.getNode('sleep_start');
        break;
      case VuiModule.breathing:
        _currentNode = _engine.getNode('breathing_intro');
        break;
      case VuiModule.crisis:
        _currentNode = _engine.getNode('crisis_start');
        break;
    }
    _speakSera(_currentNode.text);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VOICE COMMAND ROUTER  (main logic entry point from mic)
  // ─────────────────────────────────────────────────────────────────────────

  /// Called after STT result is ready.
  /// [nav]  — NavigationNotifier to switch tabs
  /// Returns true if a navigation/system command was handled.
  void processVoiceCommand(
    String text,
    NavigationNotifier nav,
  ) {
    if (text.trim().isEmpty) {
      _setState(VuiState.idle);
      return;
    }

    final lower = text.toLowerCase().trim();

    // ── 1. Wake word check ──────────────────────────────────────────────────
    if (lower == 'sera' || lower.startsWith('hey sera') || lower.startsWith('hi sera')) {
      _speakSera("Yes, I am hearing you. Tell me what you want.");
      return;
    }

    // ── 2. Crisis check (highest priority) ─────────────────────────────────
    if (DialogueEngine.checkCrisis(lower)) {
      nav.navigateTo(4); // Help tab
      triggerCrisisBreakout(text);
      return;
    }

    // ── 2. Sleep/Bedtime Routine Updates (intercept before navigation checks) ──
    final isSleepUpdate = _isReportingSleepTime(lower) || _isBedtimeRoutineCommand(lower);
    if (isSleepUpdate) {
      if (nav.currentIndex != 3) {
        nav.navigateTo(3);
        _currentModule = VuiModule.sleep;
      }
      _processDialogue(text);
      return;
    }

    // ── 3. Navigation commands ──────────────────────────────────────────────
    if (_matchesNav(lower, ['home', 'go home', 'main screen', 'main'])) {
      nav.navigateTo(0);
      _speakSera("Going to Home.");
      return;
    }
    if (_matchesNav(lower,
        ['mood', 'check mood', 'how i feel', 'feelings', 'emotional check'])) {
      nav.navigateTo(1);
      transitionToModule(VuiModule.mood);
      return;
    }
    if (_matchesNav(lower, [
      'breathe',
      'breathing',
      'meditation',
      'meditate',
      'relax',
      'calm',
      'exercise',
      'breath',
    ])) {
      nav.navigateTo(2);
      transitionToModule(VuiModule.breathing);
      return;
    }
    if (_matchesNav(lower,
        ['sleep', 'bedtime', 'tired', 'rest', 'sleep tips', 'insomnia'])) {
      nav.navigateTo(3);
      transitionToModule(VuiModule.sleep);
      return;
    }
    if (_matchesNav(lower,
        ['help', 'emergency', 'crisis', 'sos', 'call', 'hotline', 'contacts'])) {
      nav.navigateTo(4);
      _currentModule = VuiModule.crisis;
      _currentNode = _engine.getNode('crisis_start');
      _speakSera("I've opened the emergency contacts page. Say 'call' to dial the hotline.");
      return;
    }

    // ── 3. Breathing exercise controls ─────────────────────────────────────
    if (_matchesNav(lower, ['start', 'begin', 'start breathing', 'begin breathing'])) {
      startBreathingExercise();
      return;
    }
    if (_matchesNav(lower, ['stop', 'pause', 'stop breathing', 'pause breathing'])) {
      pauseBreathing();
      _speakSera("Exercise paused. Tap the orb or say 'start' to continue.");
      return;
    }

    // ── 4. Close app ────────────────────────────────────────────────────────
    if (_matchesNav(lower,
        ['close', 'exit', 'quit', 'close app', 'exit app', 'bye', 'goodbye'])) {
      _pendingClose = true;
      _speakSera("Take care! Goodbye.");
      // SystemNavigator.pop() fires automatically in TTS completion handler
      return;
    }

    // ── 5. Dial hotline from Help screen ────────────────────────────────────
    if (_currentModule == VuiModule.crisis &&
        lower.contains('call')) {
      dialEmergencyHotline();
      return;
    }

    // ── 6. Otherwise → feed into DialogueEngine ─────────────────────────────
    _processDialogue(text);
  }

  // Helper: checks if input contains any of the given phrases
  bool _matchesNav(String lower, List<String> phrases) {
    return phrases.any((p) => lower.contains(p));
  }

  // ── Crisis breakout ───────────────────────────────────────────────────────
  void _checkCrisisInterception(String text) {
    if (DialogueEngine.checkCrisis(text)) {
      debugPrint('CRITICAL: Crisis keyword: $text');
    }
  }

  void triggerCrisisBreakout(String userTriggerPhrase) {
    _cancelBreathing();
    _tts.stop();
    _speech.stop();

    _currentModule = VuiModule.crisis;
    _currentNode = _engine.getNode('crisis_start');
    _setState(VuiState.distress);

    _chatHistory.add({'sender': 'You', 'text': userTriggerPhrase});
    _speakSera(_currentNode.text);
  }

  // ── Dialogue engine path ──────────────────────────────────────────────────
  void _processDialogue(String text) {
    if (text.isEmpty) {
      _setState(VuiState.idle);
      return;
    }

    _setState(VuiState.processing);
    _chatHistory.add({'sender': 'You', 'text': text});
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1200), () {
      final lower = text.toLowerCase();
      bool isDirectMoodKeyword = lower.contains('happy') ||
          lower.contains('calm') ||
          lower.contains('sad') ||
          lower.contains('angry') ||
          lower.contains('distressed') ||
          lower.contains('good') ||
          lower.contains('fine') ||
          lower.contains('great') ||
          lower.contains('anxious') ||
          lower.contains('exam') ||
          lower.contains('stress') ||
          lower.contains('nervous');

      if (_currentModule == VuiModule.mood && isDirectMoodKeyword) {
        String targetNodeId = 'mood_fallback_detected';
        if (lower.contains('happy')) {
          _detectedEmotion = 'Happy';
          _detectedIntensity = 'Low';
          _selectedEmojiIndex = 0;
          _shiftWeeklyChart(0.95);
          targetNodeId = 'mood_happy_detected';
        } else if (lower.contains('calm')) {
          _detectedEmotion = 'Calm';
          _detectedIntensity = 'Low';
          _selectedEmojiIndex = 1;
          _shiftWeeklyChart(0.80);
          targetNodeId = 'mood_calm_detected';
        } else if (lower.contains('sad')) {
          _detectedEmotion = 'Sad';
          _detectedIntensity = 'Medium';
          _selectedEmojiIndex = 2;
          _shiftWeeklyChart(0.35);
          targetNodeId = 'mood_sad_detected';
        } else if (lower.contains('angry')) {
          _detectedEmotion = 'Angry';
          _detectedIntensity = 'High';
          _selectedEmojiIndex = 3;
          _shiftWeeklyChart(0.55);
          targetNodeId = 'mood_angry_detected';
        } else if (lower.contains('distressed')) {
          _detectedEmotion = 'Distressed';
          _detectedIntensity = 'High';
          _selectedEmojiIndex = 4;
          _shiftWeeklyChart(0.15);
          targetNodeId = 'mood_distressed_detected';
        } else if (lower.contains('anxious') ||
            lower.contains('exam') ||
            lower.contains('stress') ||
            lower.contains('nervous')) {
          _detectedEmotion = 'Anxious';
          _detectedIntensity = 'Medium';
          _shiftWeeklyChart(0.40);
          targetNodeId = 'mood_anxious_detected';
        } else if (lower.contains('good') ||
            lower.contains('fine') ||
            lower.contains('great')) {
          _detectedEmotion = 'Happy';
          _detectedIntensity = 'Low';
          _selectedEmojiIndex = 0;
          _shiftWeeklyChart(0.95);
          targetNodeId = 'mood_happy_detected';
        }

        _currentNode = _engine.getNode(targetNodeId);
        _speakSera(_currentNode.text);
        return;
      }

      if (_currentModule == VuiModule.sleep && _isReportingSleepTime(text)) {
        _parseAndSetSleepTime(text);
        final String timeStr = "${_sleepHours}h ${_sleepMinutes}m";
        String responseText = "I've logged your sleep duration of $timeStr. ";
        if (_sleepQuality == "Good") {
          responseText += "That's a great sleep duration! Keep maintaining this healthy routine.";
        } else if (_sleepQuality == "Fair") {
          responseText += "That's a fair amount of sleep, but aiming for a bit more can help you feel fully refreshed.";
        } else {
          responseText += "That's a bit low for optimal recovery. Try avoiding screens and practicing breathing exercises before bed to sleep longer.";
        }

        _currentNode = DialogueNode(
          id: 'sleep_time_logged',
          text: responseText,
          chips: ["Breathing exercise", "Sleep tips", "Exit"],
          next: (input) {
            if (input.toLowerCase().contains('breath') || input.toLowerCase().contains('exercise')) {
              return 'breathing_intro';
            }
            if (input.toLowerCase().contains('tip') || input.toLowerCase().contains('hygiene') || input.toLowerCase().contains('sleep')) {
              return 'sleep_general_advice';
            }
            return 'sleep_end';
          }
        );
        _speakSera(_currentNode.text);
        return;
      }

      if (_currentModule == VuiModule.sleep && _isBedtimeRoutineCommand(text)) {
        final String responseText = _processBedtimeRoutineCommand(text);

        _currentNode = DialogueNode(
          id: 'bedtime_routine_updated',
          text: responseText,
          chips: ["Breathing exercise", "Sleep tips", "Exit"],
          next: (input) {
            if (input.toLowerCase().contains('breath') || input.toLowerCase().contains('exercise')) {
              return 'breathing_intro';
            }
            if (input.toLowerCase().contains('tip') || input.toLowerCase().contains('hygiene') || input.toLowerCase().contains('sleep')) {
              return 'sleep_general_advice';
            }
            return 'sleep_end';
          }
        );
        _speakSera(_currentNode.text);
        return;
      }

      // Emotion detection on mood screen (standard path fallback)
      if (_currentNode.id == 'mood_start') {
        if (lower.contains('happy')) {
          _detectedEmotion = 'Happy';
          _detectedIntensity = 'Low';
          _selectedEmojiIndex = 0;
          _shiftWeeklyChart(0.95);
        } else if (lower.contains('calm')) {
          _detectedEmotion = 'Calm';
          _detectedIntensity = 'Low';
          _selectedEmojiIndex = 1;
          _shiftWeeklyChart(0.80);
        } else if (lower.contains('sad')) {
          _detectedEmotion = 'Sad';
          _detectedIntensity = 'Medium';
          _selectedEmojiIndex = 2;
          _shiftWeeklyChart(0.35);
        } else if (lower.contains('angry')) {
          _detectedEmotion = 'Angry';
          _detectedIntensity = 'High';
          _selectedEmojiIndex = 3;
          _shiftWeeklyChart(0.55);
        } else if (lower.contains('distressed')) {
          _detectedEmotion = 'Distressed';
          _detectedIntensity = 'High';
          _selectedEmojiIndex = 4;
          _shiftWeeklyChart(0.15);
        } else if (lower.contains('anxious') ||
            lower.contains('exam') ||
            lower.contains('stress') ||
            lower.contains('nervous')) {
          _detectedEmotion = 'Anxious';
          _detectedIntensity = 'Medium';
          _shiftWeeklyChart(0.40);
        } else if (lower.contains('good') ||
            lower.contains('fine') ||
            lower.contains('great')) {
          _detectedEmotion = 'Happy';
          _detectedIntensity = 'Low';
          _selectedEmojiIndex = 0;
          _shiftWeeklyChart(0.95);
        } else {
          _detectedEmotion = 'Neutral';
          _detectedIntensity = 'Low';
        }
      }

      if (_currentNode.next != null) {
        final nextId = _currentNode.next!(text);

        if (nextId == 'breathing_intro') {
          _currentModule = VuiModule.breathing;
        }

        _currentNode = _engine.getNode(nextId);
        _speakSera(_currentNode.text);
      } else {
        _setState(VuiState.idle);
      }
    });
  }

  // ── STT control ───────────────────────────────────────────────────────────
  Future<void> startListening() async {
    if (_state == VuiState.guiding) return;
    _speechText = '';
    _setState(VuiState.listening);

    if (!_simulatedMode && _sttInitialized) {
      await _speech.listen(
        onResult: (val) {
          _speechText = val.recognizedWords;
          notifyListeners();
          
          // Check for wake word instantly
          if (_speechText.toLowerCase().trim() == 'sera') {
            stopListening();
          }
          
          _checkCrisisInterception(_speechText);
        },
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> stopListening() async {
    if (_state != VuiState.listening) return;
    if (!_simulatedMode && _sttInitialized) {
      await _speech.stop();
    }
    _onSpeechFinished();
  }

  /// Called when STT automatically finishes (timeout / silence)
  void _onSpeechFinished() {
    if (_speechText.isEmpty) {
      _setState(VuiState.idle);
      return;
    }
    
    if (_nav != null) {
      processVoiceCommand(_speechText, _nav!);
    } else {
      _processDialogue(_speechText);
    }
  }

  /// Simulated text input (for emoji taps / chip taps)
  void submitSimulatedSpeech(String text) {
    _speechText = text;
    _checkCrisisInterception(text);
    _processDialogue(text);
  }

  // ── TTS ───────────────────────────────────────────────────────────────────
  Future<void> _speakSera(String text) async {
    _setState(VuiState.speaking);
    _chatHistory.add({'sender': 'Sera', 'text': text});
    notifyListeners();

    if (!_isMuted) {
      await _tts.speak(text);
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (_state == VuiState.speaking) {
          if (_currentNode.chips.isNotEmpty) {
            startListening();
          } else {
            _setState(VuiState.idle);
          }
        }
      });
    }
  }

  // ── Breathing engine ──────────────────────────────────────────────────────
  void startBreathingExercise() {
    _cancelBreathing();
    _setState(VuiState.guiding);
    _isBreathingActive = true;
    _breathingCycle = 1;
    _breathingPhase = 'Inhale';
    notifyListeners();
    _runBreathingCycle();
  }

  void _runBreathingCycle() {
    if (!_isBreathingActive || _breathingCycle > _maxCycles) {
      _completeBreathingExercise();
      return;
    }

    _breathingPhase = 'Inhale';
    notifyListeners();
    _speakVoiceGuidance('Inhale slowly through your nose… 1… 2… 3… 4…');

    _breathingTimer = Timer(const Duration(seconds: 4), () {
      if (!_isBreathingActive) return;
      _breathingPhase = 'Hold';
      notifyListeners();
      _speakVoiceGuidance('Hold… 1… 2… 3… 4… 5… 6… 7…');

      _breathingTimer = Timer(const Duration(seconds: 7), () {
        if (!_isBreathingActive) return;
        _breathingPhase = 'Exhale';
        notifyListeners();
        _speakVoiceGuidance('Exhale slowly… 1… 2… 3… 4… 5… 6… 7… 8…');

        _breathingTimer = Timer(const Duration(seconds: 8), () {
          if (!_isBreathingActive) return;
          _breathingCycle++;
          _runBreathingCycle();
        });
      });
    });
  }

  void _speakVoiceGuidance(String text) async {
    _chatHistory.add({'sender': 'Sera', 'text': text});
    notifyListeners();
    if (!_isMuted) await _tts.speak(text);
  }

  void pauseBreathing() {
    _isBreathingActive = false;
    _breathingTimer?.cancel();
    _tts.stop();
    _setState(VuiState.idle);
  }

  void stopBreathing() {
    _cancelBreathing();
    _setState(VuiState.idle);
  }

  void _cancelBreathing() {
    _isBreathingActive = false;
    _breathingTimer?.cancel();
    _breathingCycle = 1;
    _breathingPhase = 'Inhale';
  }

  void _completeBreathingExercise() {
    _cancelBreathing();
    _setState(VuiState.idle);
    _currentNode = DialogueNode(
      id: 'breathing_complete',
      text: 'All cycles complete. How do you feel now?',
      chips: ['Better', 'Still anxious', 'Tired'],
    );
    _speakSera(_currentNode.text);
  }

  // ── Emergency helpers ─────────────────────────────────────────────────────
  Future<void> dialEmergencyHotline() async {
    final uri = Uri(scheme: 'tel', path: '1926');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      debugPrint('Hotline dial fail: $e');
    }
  }

  Future<void> textEmergencyLine() async {
    final uri = Uri(
      scheme: 'sms',
      path: '85258',
      queryParameters: {'body': 'HOME'},
    );
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      debugPrint('SMS fail: $e');
    }
  }

  @override
  void dispose() {
    _breathingTimer?.cancel();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }
}
