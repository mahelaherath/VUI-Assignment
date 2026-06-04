import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dialogue_engine.dart';

class VuiStateManager extends ChangeNotifier {
  final DialogueEngine _engine = DialogueEngine();
  
  // State variables
  VuiState _state = VuiState.idle;
  VuiModule _currentModule = VuiModule.mood;
  late DialogueNode _currentNode;
  final List<Map<String, String>> _chatHistory = [];
  
  bool _isMuted = false;
  String _speechText = "";
  
  // Mood Detection Metadata
  String _detectedEmotion = "";
  String _detectedIntensity = "";
  
  // Guided Breathing Metadata
  String _breathingPhase = "Inhale";
  int _breathingCycle = 1;
  final int _maxCycles = 4;
  bool _isBreathingActive = false;
  Timer? _breathingTimer;

  // External APIs / Service wrappers
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _sttInitialized = false;
  bool _simulatedMode = false; // Fallback if physical mic/library fails

  // Getters
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

  VuiStateManager() {
    _currentNode = _engine.getNode('mood_start');
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initVoiceServices();
  }

  Future<void> _initVoiceServices() async {
    try {
      // Setup Text to Speech
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() {
        if (_state == VuiState.speaking) {
          // If we finished speaking a normal prompt, go to listening automatically
          if (_currentNode.chips.isNotEmpty) {
            startListening();
          } else {
            _setState(VuiState.idle);
          }
        }
      });

      // Setup Speech to Text
      _sttInitialized = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (_state == VuiState.listening) {
              _onSpeechFinished();
            }
          }
        },
        onError: (val) {
          debugPrint("STT Error: $val");
        },
      );

      if (!_sttInitialized) {
        debugPrint("Speech-to-text initialization failed. Falling back to Simulated Mode.");
        _simulatedMode = true;
      }
    } catch (e) {
      debugPrint("Voice services failed to init. Running in mock simulator mode: $e");
      _simulatedMode = true;
    }

    // Trigger initial greeting
    triggerGreeting();
  }

  void _setState(VuiState newState) {
    _state = newState;
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _tts.setVolume(_isMuted ? 0.0 : 1.0);
    notifyListeners();
  }

  /// Start the conversational greeting
  void triggerGreeting() {
    _chatHistory.clear();
    _currentModule = VuiModule.mood;
    _currentNode = _engine.getNode('mood_start');
    _speakSera(_currentNode.text);
  }

  /// Change active modules (e.g. from direct navigation actions)
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

  /// Intercept transcripts in real time for crisis keywords
  void _checkCrisisInterception(String text) {
    if (DialogueEngine.checkCrisis(text)) {
      debugPrint("CRITICAL: Crisis keyword detected in transcript: '$text'");
      triggerCrisisBreakout(text);
    }
  }

  /// Override dialogue flows and route immediately to Help page
  void triggerCrisisBreakout(String userTriggerPhrase) {
    _cancelBreathing();
    _tts.stop();
    _speech.stop();
    
    _currentModule = VuiModule.crisis;
    _currentNode = _engine.getNode('crisis_start');
    _setState(VuiState.distress);

    // Record user distress phrase
    _chatHistory.add({"sender": "You", "text": userTriggerPhrase});
    
    // Sera responds immediately with emergency script
    _speakSera(_currentNode.text);
  }

  /// Voice outputs
  Future<void> _speakSera(String text) async {
    _setState(VuiState.speaking);
    _chatHistory.add({"sender": "Sera", "text": text});
    notifyListeners();

    if (!_isMuted) {
      await _tts.speak(text);
    } else {
      // In mute mode, simulate speaking wait times
      Future.delayed(const Duration(seconds: 3), () {
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

  /// Voice inputs
  Future<void> startListening() async {
    if (_state == VuiState.guiding) return;
    
    _speechText = "";
    _setState(VuiState.listening);

    if (!_simulatedMode && _sttInitialized) {
      await _speech.listen(
        onResult: (val) {
          _speechText = val.recognizedWords;
          _checkCrisisInterception(_speechText);
          notifyListeners();
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      // Mock simulator typing mode for testing
      debugPrint("Simulating speech input... Type in fallback interface");
    }
  }

  Future<void> stopListening() async {
    if (_state != VuiState.listening) return;

    if (!_simulatedMode) {
      await _speech.stop();
    }
    _onSpeechFinished();
  }

  void submitSimulatedSpeech(String text) {
    _speechText = text;
    _checkCrisisInterception(text);
    _onSpeechFinished();
  }

  void _onSpeechFinished() {
    if (_speechText.isEmpty) {
      _setState(VuiState.idle);
      return;
    }

    _setState(VuiState.processing);
    _chatHistory.add({"sender": "You", "text": _speechText});
    notifyListeners();

    // Small delay to simulate processing state
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (DialogueEngine.checkCrisis(_speechText)) {
        // Crisis is handled instantly by real-time hook, double check here
        return;
      }

      // Process sleep voice quick commands on distress screen
      if (_currentNode.id == 'crisis_contacts') {
        if (_speechText.toLowerCase().contains("call")) {
          dialEmergencyHotline();
          _setState(VuiState.idle);
          return;
        } else if (_speechText.toLowerCase().contains("text")) {
          textEmergencyLine();
          _setState(VuiState.idle);
          return;
        } else if (_speechText.toLowerCase().contains("breathe")) {
          transitionToModule(VuiModule.breathing);
          return;
        }
      }

      // Check-in specific features: NLP outputs
      if (_currentNode.id == 'mood_start') {
        final lower = _speechText.toLowerCase();
        if (lower.contains('anxious') || lower.contains('exam') || lower.contains('stress')) {
          _detectedEmotion = "Anxious";
          _detectedIntensity = "Medium";
        } else if (lower.contains('sad') || lower.contains('depressed')) {
          _detectedEmotion = "Sad";
          _detectedIntensity = "High";
        } else {
          _detectedEmotion = "Neutral";
          _detectedIntensity = "Low";
        }
      }

      // Determine next dialogue step
      if (_currentNode.next != null) {
        final nextId = _currentNode.next!(_speechText);
        
        if (nextId == 'breathing_intro') {
          _currentModule = VuiModule.breathing;
        }
        
        _currentNode = _engine.getNode(nextId);
        
        if (_currentNode.id == 'breathing_intro') {
          // Launch breathing transition
          _currentModule = VuiModule.breathing;
          _currentNode = _engine.getNode('breathing_intro');
        }
        
        _speakSera(_currentNode.text);
      } else {
        _setState(VuiState.idle);
      }
    });
  }

  // --- BREATHING ENGINE (4-7-8 Timing Loop) ---
  void startBreathingExercise() {
    _cancelBreathing();
    _setState(VuiState.guiding);
    _isBreathingActive = true;
    _breathingCycle = 1;
    _breathingPhase = "Inhale";
    notifyListeners();

    _runBreathingCycle();
  }

  void _runBreathingCycle() {
    if (!_isBreathingActive || _breathingCycle > _maxCycles) {
      _completeBreathingExercise();
      return;
    }

    // Phase 1: Inhale (4 seconds)
    _breathingPhase = "Inhale";
    notifyListeners();
    _speakVoiceGuidance("Inhale slowly through your nose... 1... 2... 3... 4...");

    _breathingTimer = Timer(const Duration(seconds: 4), () {
      if (!_isBreathingActive) return;

      // Phase 2: Hold (7 seconds)
      _breathingPhase = "Hold";
      notifyListeners();
      _speakVoiceGuidance("Hold... 1... 2... 3... 4... 5... 6... 7... Well done.");

      _breathingTimer = Timer(const Duration(seconds: 7), () {
        if (!_isBreathingActive) return;

        // Phase 3: Exhale (8 seconds)
        _breathingPhase = "Exhale";
        notifyListeners();
        _speakVoiceGuidance("Exhale... 1... 2... 3... 4... 5... 6... 7... 8...");

        _breathingTimer = Timer(const Duration(seconds: 8), () {
          if (!_isBreathingActive) return;

          // Increment and repeat
          _breathingCycle++;
          _runBreathingCycle();
        });
      });
    });
  }

  void _speakVoiceGuidance(String guidance) async {
    _chatHistory.add({"sender": "Sera", "text": guidance});
    notifyListeners();
    if (!_isMuted) {
      await _tts.speak(guidance);
    }
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
    transitionToModule(VuiModule.mood);
  }

  void _cancelBreathing() {
    _isBreathingActive = false;
    _breathingTimer?.cancel();
    _breathingCycle = 1;
    _breathingPhase = "Inhale";
  }

  void _completeBreathingExercise() {
    _cancelBreathing();
    _setState(VuiState.idle);
    _currentNode = DialogueNode(
      id: 'breathing_complete',
      text: "All 4 cycles complete. How do you feel now?",
      chips: ["Better", "Still anxious", "Tired"],
    );
    _speakSera(_currentNode.text);
  }

  // --- EMERGENCY TELEPHONY TRIPPERS ---
  Future<void> dialEmergencyHotline() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '116123');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        debugPrint("Could not launch dialer for 116123");
      }
    } catch (e) {
      debugPrint("Hotline dialer fail: $e");
    }
  }

  Future<void> textEmergencyLine() async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: '85258',
      queryParameters: <String, String>{
        'body': 'HOME',
      },
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        debugPrint("Could not launch SMS for 85258");
      }
    } catch (e) {
      debugPrint("SMS client fail: $e");
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
