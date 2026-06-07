import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dialogue_engine.dart';
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

    // ── 2. Navigation commands ──────────────────────────────────────────────
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
      // Emotion detection on mood screen
      if (_currentNode.id == 'mood_start') {
        final lower = text.toLowerCase();
        if (lower.contains('anxious') ||
            lower.contains('exam') ||
            lower.contains('stress')) {
          _detectedEmotion = 'Anxious';
          _detectedIntensity = 'Medium';
        } else if (lower.contains('sad') || lower.contains('depressed')) {
          _detectedEmotion = 'Sad';
          _detectedIntensity = 'High';
        } else if (lower.contains('good') ||
            lower.contains('happy') ||
            lower.contains('fine')) {
          _detectedEmotion = 'Happy';
          _detectedIntensity = 'Low';
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
