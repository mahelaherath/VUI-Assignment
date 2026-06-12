import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:vui_mental_health/vui/vui_state_manager.dart';
import 'package:vui_mental_health/vui/dialogue_engine.dart';
import 'package:vui_mental_health/vui/navigation_notifier.dart';
import 'package:vui_mental_health/db/database_helper.dart';
import 'mock_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupMockChannels();
  });

  group('VuiStateManager Bedtime Routine Tests', () {
    late VuiStateManager stateManager;
    late NavigationNotifier navigationNotifier;

    setUp(() async {
      await DatabaseHelper.instance.resetDatabase();
      stateManager = VuiStateManager();
      navigationNotifier = NavigationNotifier();
      stateManager.setNavigationNotifier(navigationNotifier);
    });

    test('Initial Bedtime and Checklist values are correct', () {
      expect(stateManager.bedtimeRoutine, equals('10:30 PM'));
      expect(stateManager.routineChecklist, equals([false, false, false]));
    });

    test('updateBedtimeRoutine updates routine time correctly', () {
      stateManager.updateBedtimeRoutine('11:00 PM');
      expect(stateManager.bedtimeRoutine, equals('11:00 PM'));
    });

    test('toggleChecklistItem toggles checklist values correctly', () {
      stateManager.toggleChecklistItem(0, value: true);
      expect(stateManager.routineChecklist[0], isTrue);

      stateManager.toggleChecklistItem(0, value: false);
      expect(stateManager.routineChecklist[0], isFalse);

      stateManager.toggleChecklistItem(1); // toggles to true
      expect(stateManager.routineChecklist[1], isTrue);
    });

    test('Voice command updates bedtime correctly', () {
      fakeAsync((async) {
        // Transition to sleep module first
        stateManager.transitionToModule(VuiModule.sleep);

        // Submit voice/text command to change bedtime
        stateManager.submitSimulatedSpeech('set bedtime to 11 PM');

        // Advance fake time by 1.5 seconds
        async.elapse(const Duration(milliseconds: 1500));

        // Check if bedtime routine has updated
        expect(stateManager.bedtimeRoutine, equals('11 PM'));
      });
    });

    test('Voice command check/uncheck checklist items correctly', () {
      fakeAsync((async) {
        stateManager.transitionToModule(VuiModule.sleep);

        // Check screens
        stateManager.submitSimulatedSpeech('i turned off my screens');
        async.elapse(const Duration(milliseconds: 1500));
        expect(stateManager.routineChecklist[0], isTrue);

        // Check room temp
        stateManager.submitSimulatedSpeech('kept the room cool');
        async.elapse(const Duration(milliseconds: 1500));
        expect(stateManager.routineChecklist[1], isTrue);

        // Uncheck screens
        stateManager.submitSimulatedSpeech('uncheck screens');
        async.elapse(const Duration(milliseconds: 1500));
        expect(stateManager.routineChecklist[0], isFalse);

        // Reset checklist
        stateManager.submitSimulatedSpeech('reset checklist');
        async.elapse(const Duration(milliseconds: 1500));
        expect(stateManager.routineChecklist, equals([false, false, false]));
      });
    });

    group('VuiStateManager Bedtime Routine Case-Insensitive and Time Format Tests', () {
      test('Voice command updates bedtime with various formats', () {
        fakeAsync((async) {
          stateManager.transitionToModule(VuiModule.sleep);

          // AM format
          stateManager.submitSimulatedSpeech('bedtime is at 10 am');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.bedtimeRoutine, equals('10 AM'));

          // No meridian format (defaults to PM)
          stateManager.submitSimulatedSpeech('change bedtime to 11:30');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.bedtimeRoutine, equals('11:30 PM'));

          // Hour and minute format with pm
          stateManager.submitSimulatedSpeech('set bedtime to 9:15 pm');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.bedtimeRoutine, equals('9:15 PM'));
        });
      });

      test('Voice command matches checklist case-insensitively and with phone/temp keywords', () {
        fakeAsync((async) {
          stateManager.transitionToModule(VuiModule.sleep);

          // "phone" matches screens checklist
          stateManager.submitSimulatedSpeech('NO PHONE BEFORE BED');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.routineChecklist[0], isTrue);

          // "temp" matches room cool checklist
          stateManager.submitSimulatedSpeech('check temp');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.routineChecklist[1], isTrue);

          // "consistent" matches consistent wake time checklist
          stateManager.submitSimulatedSpeech('consistent schedule');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.routineChecklist[2], isTrue);
        });
      });

      test('processVoiceCommand navigates and processes bedtime routine changes correctly', () {
        fakeAsync((async) {
          // Set to home initially (tab 0)
          navigationNotifier.navigateTo(0);
          expect(navigationNotifier.currentIndex, equals(0));

          // Speak sleep command to update bedtime from Home Screen
          stateManager.processVoiceCommand('set bedtime to 11:15 PM', navigationNotifier);

          // Verify it triggered transition to Sleep Screen (tab 3)
          expect(navigationNotifier.currentIndex, equals(3));

          // Wait for dialogue processing delay
          async.elapse(const Duration(milliseconds: 1500));

          // Verify bedtime is updated successfully
          expect(stateManager.bedtimeRoutine, equals('11:15 PM'));
        });
      });
    });

    group('VuiStateManager Mood Tracking Tests', () {
      test('Initial pre-populated mood history is loaded correctly', () async {
        // Wait for the async database initialization and pre-population in constructor
        await Future.delayed(const Duration(milliseconds: 100));

        // The week values should load the pre-populated values from DB grouped by calendar day:
        // Sad (0.35), Calm (0.80), Anxious (0.40), Happy (0.95), Angry (0.55), Calm (0.80), Today (0.0)
        expect(stateManager.weekValues, equals([0.35, 0.80, 0.40, 0.95, 0.55, 0.80, 0.0]));
        // Weekly Mood Score is the average of pre-populated scores: (0.35+0.80+0.40+0.95+0.55+0.80)/6 = 0.64166...
        expect(stateManager.latestMoodScore, closeTo(0.6416, 0.001));
        expect(stateManager.selectedEmojiIndex, equals(1)); // Calm emoji is at index 1

        // Verify weekly mood counts
        expect(stateManager.weeklyMoodCounts['Happy'], equals(1));
        expect(stateManager.weeklyMoodCounts['Calm'], equals(2));
        expect(stateManager.weeklyMoodCounts['Sad'], equals(1));
        expect(stateManager.weeklyMoodCounts['Angry'], equals(1));
        expect(stateManager.weeklyMoodCounts['Distressed'], equals(0));
      });

      test('Voice command "Happy" updates mood score and saves to DB', () async {
        // Transition to mood module
        stateManager.transitionToModule(VuiModule.mood);

        // Submit "happy" keyword
        stateManager.submitSimulatedSpeech('I feel very happy today');

        // Wait for the dialogue processing (1.2s delay) and DB operations to complete
        await Future.delayed(const Duration(seconds: 2));

        // Weekly average with the new Happy entry today: (3.85 + 0.95) / 7 = 0.685714...
        expect(stateManager.latestMoodScore, closeTo(0.6857, 0.001));
        expect(stateManager.selectedEmojiIndex, equals(0)); // Happy emoji is at index 0
        expect(stateManager.weekValues.last, equals(0.95)); // Today's average score is now 0.95

        // Verify Happy count is updated to 2
        expect(stateManager.weeklyMoodCounts['Happy'], equals(2));

        // Verify database records
        final dbMoods = await DatabaseHelper.instance.getLatestMoods(10);
        expect(dbMoods.last['mood'], equals('Happy'));
        expect(dbMoods.last['score'], equals(0.95));
      });

      test('Voice command "Angry" updates mood score and saves to DB', () async {
        stateManager.transitionToModule(VuiModule.mood);
        stateManager.submitSimulatedSpeech('I am angry');
        
        await Future.delayed(const Duration(seconds: 2));

        // Weekly average with the new Angry entry today: (3.85 + 0.55) / 7 = 0.628571...
        expect(stateManager.latestMoodScore, closeTo(0.6285, 0.001));
        expect(stateManager.selectedEmojiIndex, equals(3)); // Angry emoji is at index 3
        expect(stateManager.weekValues.last, equals(0.55)); // Today's average score is now 0.55

        // Verify Angry count is updated to 2
        expect(stateManager.weeklyMoodCounts['Angry'], equals(2));

        final dbMoods = await DatabaseHelper.instance.getLatestMoods(10);
        expect(dbMoods.last['mood'], equals('Angry'));
        expect(dbMoods.last['score'], equals(0.55));
      });

      test('resetWeeklyData clears all mood data and statistics', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        // Ensure database has pre-populated data initially
        expect(stateManager.weeklyMoodCounts['Happy'], equals(1));
        expect(stateManager.latestMoodScore, closeTo(0.6416, 0.001));

        // Call reset
        await stateManager.resetWeeklyData();

        // Verify values are reset/cleared
        expect(stateManager.latestMoodScore, equals(0.0));
        expect(stateManager.weeklyMoodCounts['Happy'], equals(0));
        expect(stateManager.weeklyMoodCounts['Calm'], equals(0));
        expect(stateManager.weeklyMoodCounts['Sad'], equals(0));
        expect(stateManager.weeklyMoodCounts['Angry'], equals(0));
        expect(stateManager.weeklyMoodCounts['Distressed'], equals(0));

        // Verify database is completely empty
        final db = await DatabaseHelper.instance.database;
        final List<Map<String, dynamic>> dbMoods = await db.query('moods');
        expect(dbMoods, isEmpty);
      });
    });

    group('VuiStateManager Breathing Exercise Tests', () {
      test('Initial breathing technique is 4-7-8', () {
        expect(stateManager.breathingTechnique, equals('4-7-8'));
      });

      test('updateBreathingTechnique updates correctly', () {
        stateManager.updateBreathingTechnique('Box');
        expect(stateManager.breathingTechnique, equals('Box'));

        stateManager.updateBreathingTechnique('Belly');
        expect(stateManager.breathingTechnique, equals('Belly'));
      });

      test('Voice commands select breathing techniques correctly', () {
        fakeAsync((async) {
          stateManager.transitionToModule(VuiModule.breathing);

          stateManager.submitSimulatedSpeech('change to belly breathing');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.breathingTechnique, equals('Belly'));

          stateManager.submitSimulatedSpeech('select box breathing');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.breathingTechnique, equals('Box'));

          stateManager.submitSimulatedSpeech('4-7-8 breathing technique');
          async.elapse(const Duration(milliseconds: 1500));
          expect(stateManager.breathingTechnique, equals('4-7-8'));
        });
      });
    });
  });
}
