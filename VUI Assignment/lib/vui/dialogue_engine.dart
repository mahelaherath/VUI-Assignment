enum VuiModule { mood, sleep, breathing, crisis }

enum VuiState { idle, speaking, listening, processing, guiding, distress }

class DialogueNode {
  final String id;
  final String text;
  final List<String> chips;
  final Function(String input)? next;

  DialogueNode({
    required this.id,
    required this.text,
    this.chips = const [],
    this.next,
  });
}

class DialogueEngine {
  // Regex to catch severe distress and self-harm indicators
  static final RegExp crisisRegex = RegExp(
    r'\b(suicide|kill myself|hurt myself|want to die|ending my life|self-harm|self harm|hang myself|slit my wrist|overdose|can\x27t cope anymore|don\x27t want to live|end it all|jump off|poison myself|crisis)\b',
    caseSensitive: false,
  );

  /// Checks if any input text contains emergency crisis keywords.
  static bool checkCrisis(String text) {
    return crisisRegex.hasMatch(text);
  }

  // Pre-defined dialogue trees for the modules
  late final Map<String, DialogueNode> _nodes;

  DialogueEngine() {
    _nodes = {
      // --- MOOD CHECK-IN FLOW ---
      'mood_start': DialogueNode(
        id: 'mood_start',
        text: "Hey! How are you feeling today? Take your time — just speak naturally.",
        chips: ["Good", "Anxious", "Tired", "Sad"],
        next: (input) {
          final cleaned = input.toLowerCase();
          if (cleaned.contains('anxious') || cleaned.contains('stress') || cleaned.contains('nervous') || cleaned.contains('exam')) {
            return 'mood_anxious_detected';
          } else if (cleaned.contains('sad') || cleaned.contains('depressed') || cleaned.contains('down')) {
            return 'mood_sad_detected';
          } else if (cleaned.contains('good') || cleaned.contains('happy') || cleaned.contains('great') || cleaned.contains('fine')) {
            return 'mood_good_detected';
          }
          return 'mood_fallback_detected';
        },
      ),
      'mood_anxious_detected': DialogueNode(
        id: 'mood_anxious_detected',
        text: "I hear you, and it's completely understandable to feel anxious, especially with exams or responsibilities building up. Would you like to do a quick breathing exercise to ground yourself?",
        chips: ["Yes, let's breathe", "No, just talk", "Sleep support"],
        next: (input) {
          if (input.toLowerCase().contains('breathe') || input.toLowerCase().contains('yes') || input.toLowerCase().contains('exercise')) {
            return 'breathing_intro';
          }
          return 'mood_end';
        },
      ),
      'mood_sad_detected': DialogueNode(
        id: 'mood_sad_detected',
        text: "I'm really sorry to hear you're feeling down. I'm here for you. We can chat, or try some sleep hygiene tips if you are feeling exhausted.",
        chips: ["Sleep support", "Talk more", "Breathing exercise"],
        next: (input) {
          if (input.toLowerCase().contains('sleep') || input.toLowerCase().contains('hygiene')) {
            return 'sleep_start';
          }
          return 'mood_end';
        },
      ),
      'mood_good_detected': DialogueNode(
        id: 'mood_good_detected',
        text: "I'm so glad to hear you're doing well! Keeping up with healthy routines is key. Let me know if you want to practice your daily breathing or get sleep tips.",
        chips: ["Breathing exercise", "Sleep support", "Exit"],
        next: (input) {
          if (input.toLowerCase().contains('breath') || input.toLowerCase().contains('exercise')) return 'breathing_intro';
          if (input.toLowerCase().contains('sleep')) return 'sleep_start';
          return 'mood_end';
        },
      ),
      'mood_fallback_detected': DialogueNode(
        id: 'mood_fallback_detected',
        text: "Thank you for sharing that with me. I've noted down your emotional check-in. What would you like to explore next?",
        chips: ["Breathing exercise", "Sleep support", "Exit"],
      ),
      'mood_end': DialogueNode(
        id: 'mood_end',
        text: "Take care. I'm always here if you want to check in again later.",
      ),

      // --- SLEEP HYGIENE FLOW ---
      'sleep_start': DialogueNode(
        id: 'sleep_start',
        text: "It's getting late. How has your sleep been lately? Any trouble falling asleep or waking up at night?",
        chips: ["Can't fall asleep", "Wake up at night", "Sleep fine"],
        next: (input) {
          final cleaned = input.toLowerCase();
          if (cleaned.contains('scroll') || cleaned.contains('phone') || cleaned.contains('screen') || cleaned.contains('can\'t fall') || cleaned.contains('fall asleep')) {
            return 'sleep_screen_advice';
          }
          return 'sleep_general_advice';
        },
      ),
      'sleep_screen_advice': DialogueNode(
        id: 'sleep_screen_advice',
        text: "That makes sense — blue light delays your body's sleep signal. Let me walk you through a wind-down routine. Ready to try it now?",
        chips: ["Let's try it", "Maybe later"],
        next: (input) {
          if (input.toLowerCase().contains('yes') || input.toLowerCase().contains('try') || input.toLowerCase().contains('ready')) {
            return 'breathing_intro'; // Leads users into a breathing exercise to wind down
          }
          return 'sleep_end';
        },
      ),
      'sleep_general_advice': DialogueNode(
        id: 'sleep_general_advice',
        text: "Creating a cool, dark environment and keeping a consistent sleep schedule can really improve sleep quality. Try writing down your thoughts before bed to clear your mind.",
        chips: ["Try breathing", "Exit"],
      ),
      'sleep_end': DialogueNode(
        id: 'sleep_end',
        text: "Alright. Focus on relaxing your body. Sleep well when the time comes.",
      ),

      // --- BREATHING EXERCISE FLOW ---
      'breathing_intro': DialogueNode(
        id: 'breathing_intro',
        text: "Great. Let's do the 4-7-8 technique together. I'll count for you — just follow my voice. Close your eyes when you're ready.",
        chips: ["Start", "Go back"],
      ),

      // --- CRISIS OVERRIDE FLOW ---
      'crisis_start': DialogueNode(
        id: 'crisis_start',
        text: "I hear you, and I'm really glad you're talking to me. What you're feeling matters. I want to make sure you're safe — can I connect you with someone who can help right now?",
        chips: ["Yes, connect me", "Not yet"],
        next: (input) {
          if (input.toLowerCase().contains('yes') || input.toLowerCase().contains('connect') || input.toLowerCase().contains('please')) {
            return 'crisis_contacts';
          }
          return 'crisis_stay_breathing';
        },
      ),
      'crisis_contacts': DialogueNode(
        id: 'crisis_contacts',
        text: "I've found some people who can help right now. You can call the crisis line — just say \"call\" and I'll dial for you. Or I can stay here and breathe with you first.",
        chips: ["Call Hotline", "Text Line", "Breathe together"],
      ),
      'crisis_stay_breathing': DialogueNode(
        id: 'crisis_stay_breathing',
        text: "Okay, I'll stay right here. Let's focus on taking deep, slow breaths. Would you like to start a guided breathing sequence?",
        chips: ["Yes, guide me", "Show contacts"],
        next: (input) {
          if (input.toLowerCase().contains('yes') || input.toLowerCase().contains('breath') || input.toLowerCase().contains('guide')) {
            return 'breathing_intro';
          }
          return 'crisis_contacts';
        },
      )
    };
  }

  DialogueNode getNode(String id) {
    return _nodes[id] ?? _nodes['mood_start']!;
  }
}
