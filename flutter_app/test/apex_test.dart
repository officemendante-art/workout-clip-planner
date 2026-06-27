import 'dart:convert';
import 'dart:io';

import 'package:apex/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppStore> testStore([AppData? data]) async {
  return AppStore.forTest(data);
}

UserProfile profile() => UserProfile(
  gender: 'Prefer not to say',
  birthDate: DateTime(1996, 1, 1),
  heightCm: 175,
  heightDisplayUnit: 'cm',
  weightKg: 75,
  weightDisplayUnit: 'kg',
  experienceLevel: 'Beginner',
  createdAt: DateTime(2026, 6, 22),
  modifiedAt: DateTime(2026, 6, 22),
  lastWeightPromptAt: DateTime(2026, 6, 22),
  weightHistory: [
    WeightEntry(
      id: 'weight-1',
      weightKg: 75,
      date: DateTime(2026, 6, 22),
      source: 'onboarding',
    ),
  ],
);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> continueOnboarding(WidgetTester tester) async {
  await tapText(tester, 'Continue');
}

void main() {
  test('profile math converts units and calculates BMI', () {
    expect(feetInchesToCm(5, 8), 173);
    expect(cmToFeetInches(173).feet, 5);
    expect(cmToFeetInches(173).inches, 8);
    expect(poundsToKg(165).round(), 75);
    expect(kgToPounds(75).round(), 165);
    expect(
      calculateBmi(heightCm: 173, weightKg: 75).toStringAsFixed(1),
      '25.1',
    );
  });

  test('ExerciseCard JSON serialization round trip', () {
    final exercise = seedData().exercises.first.copyWith(
      videoName: 'push.mp4',
      videoOriginalPath: r'C:\source\push.mp4',
      videoStoredPath: r'C:\apex\push.mp4',
      videoSizeBytes: 12,
      videoImportedAt: DateTime(2026, 6, 22),
      clipStartSeconds: 5,
      clipEndSeconds: 22,
    );
    final copy = ExerciseCard.fromJson(exercise.toJson());
    expect(copy.title, exercise.title);
    expect(copy.clipStartSeconds, exercise.clipStartSeconds);
    expect(copy.restTimerSeconds, exercise.restTimerSeconds);
    expect(copy.videoStoredPath, exercise.videoStoredPath);
    expect(copy.videoSizeBytes, 12);
  });

  test('Workout, WorkoutLog, and AppSettings JSON round trip', () {
    final data = seedData(profile: profile());
    final workout = Workout.fromJson(data.workouts.first.toJson());
    final log = WorkoutLog.fromJson(
      WorkoutLog(
        id: 'log1',
        exerciseId: data.exercises.first.id,
        date: DateTime(2026, 6, 22),
        sets: [LoggedSet(setNumber: 1, weight: 60, reps: 10, completed: true)],
      ).toJson(),
    );
    final settings = AppSettings.fromJson(data.settings.toJson());
    expect(workout.name, 'Push Day');
    expect(log.sets.single.reps, 10);
    expect(settings.fontSize, 'comfort');
  });

  test('exports include required sections and personal best is calculated', () {
    final data = seedData(profile: profile());
    data.logs.add(
      WorkoutLog(
        id: 'log1',
        exerciseId: data.exercises.first.id,
        date: DateTime(2026, 6, 22),
        sets: [
          LoggedSet(setNumber: 1, weight: 40, reps: 12, completed: true),
          LoggedSet(setNumber: 2, weight: 60, reps: 8, completed: true),
        ],
      ),
    );
    final json = data.toJson();
    final markdown = exportMarkdown(data);
    expect(json['schemaVersion'], schemaVersion);
    expect(json['profile'], isA<Map<String, dynamic>>());
    expect(json['settings'], isA<Map<String, dynamic>>());
    expect(json['exercises'], isA<List<dynamic>>());
    expect(json['workouts'], isA<List<dynamic>>());
    expect(json['logs'], isA<List<dynamic>>());
    expect(markdown, contains('# Apex Export'));
    expect(markdown, contains('## Exercises'));
    expect(markdown, contains('## Workouts'));
    expect(markdown, contains('Incline Push Up'));
    expect(personalBest(data.logs)!.weight, 60);
  });

  test('delete exercise cleans workout references and logs', () async {
    final data = seedData(profile: profile());
    final exerciseId = data.exercises.first.id;
    data.logs.add(
      WorkoutLog(
        id: 'log-delete',
        exerciseId: exerciseId,
        date: DateTime(2026, 6, 22),
        sets: [LoggedSet(setNumber: 1, weight: 20, reps: 10, completed: true)],
      ),
    );
    final store = await testStore(data);
    await store.deleteExercise(exerciseId);
    expect(
      store.data.exercises.any((exercise) => exercise.id == exerciseId),
      isFalse,
    );
    expect(store.data.logs.any((log) => log.exerciseId == exerciseId), isFalse);
    expect(
      store.data.workouts.any(
        (workout) => workout.exerciseIds.contains(exerciseId),
      ),
      isFalse,
    );
  });

  test('workout reorder and import validation are stable', () async {
    final data = seedData(profile: profile());
    final workout = data.workouts[1];
    final reversedIds = workout.exerciseIds.reversed.toList();
    final store = await testStore(data);
    await store.upsertWorkout(workout.copyWith(exerciseIds: reversedIds));
    expect(store.workoutById(workout.id)!.exerciseIds, reversedIds);

    final valid = store.data.toJson();
    expect(isValidBackup(valid), isTrue);
    expect(isValidBackup({...valid, 'schemaVersion': 1}), isTrue);
    expect(isValidBackup({...valid, 'schemaVersion': 99}), isFalse);
    expect(isValidBackup({...valid, 'logs': 'bad'}), isFalse);
  });

  test('profile v2 helpers and old profile migration are stable', () {
    expect(calculateAge(DateTime(1996, 6, 23), DateTime(2026, 6, 22)), 29);
    expect(calculateAge(DateTime(1996, 6, 22), DateTime(2026, 6, 22)), 30);
    expect(feetInchesToCm(5, 9), 175);
    final parts = cmToFeetInches(175);
    expect(parts.feet, 5);
    expect(parts.inches, 9);
    expect(poundsToKg(165).round(), 75);

    final migrated = UserProfile.fromJson({
      'gender': 'Male',
      'age': 28,
      'height': '175 cm',
      'weight': '75 kg',
      'experienceLevel': 'Intermediate',
      'createdAt': '2026-06-22T00:00:00.000',
      'modifiedAt': '2026-06-22T00:00:00.000',
    });
    expect(migrated.heightCm, 175);
    expect(migrated.weightKg, 75);
    expect(migrated.weightHistory, hasLength(1));
  });

  test(
    'video upload helpers validate, copy temp, and migrate legacy path',
    () async {
      final mediaRoot = Directory(
        '${Directory.current.path}${Platform.pathSeparator}.apex_data',
      );
      if (await mediaRoot.exists()) await mediaRoot.delete(recursive: true);
      addTearDown(() async {
        if (await mediaRoot.exists()) await mediaRoot.delete(recursive: true);
      });
      final dir = await Directory.systemTemp.createTemp('apex-video-test-');
      addTearDown(() => dir.delete(recursive: true));
      final source = File('${dir.path}${Platform.pathSeparator}source.mp4');
      await source.writeAsString('fake video');

      final draft = await copyVideoToTemp(source.path);
      expect(await File(draft.tempPath).exists(), isTrue);
      expect(draft.name, 'source.mp4');
      expect(draft.sizeBytes, greaterThan(0));

      expect(
        () => copyVideoToTemp('${dir.path}${Platform.pathSeparator}bad.txt'),
        throwsA(isA<VideoUploadException>()),
      );
      expect(
        () =>
            copyVideoToTemp('${dir.path}${Platform.pathSeparator}missing.mp4'),
        throwsA(isA<VideoUploadException>()),
      );

      final stored = await moveTempVideoToOriginals(
        tempPath: draft.tempPath,
        videoName: draft.name,
        exerciseId: 'exercise-1',
      );
      expect(await File(stored).exists(), isTrue);
      expect(await File(draft.tempPath).exists(), isFalse);

      final legacy = ExerciseCard.fromJson({
        ...seedData().exercises.first.toJson(),
        'videoPath': r'C:\legacy\clip.mp4',
      });
      expect(legacy.videoOriginalPath, r'C:\legacy\clip.mp4');
      expect(legacy.videoStoredPath, r'C:\legacy\clip.mp4');
    },
  );

  test('trim validation is calm and strict', () {
    expect(trimValidationError(-1, 5), 'Start cannot be negative.');
    expect(trimValidationError(5, 5), 'End must be after Start.');
    expect(trimValidationError(5, 6), isNull);
  });

  test('settings and data persist to JSON file', () async {
    final dir = await Directory.systemTemp.createTemp('apex-store-test-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}state.json');
    final store = AppStore(seedData(profile: profile()), storageFile: file);
    await store.updateSettings(darkMode: true, fontSize: 'large');
    expect(await file.exists(), isTrue);

    final loaded = AppData.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    expect(loaded.settings.darkMode, isTrue);
    expect(loaded.settings.fontSize, 'large');
  });

  test('backup import replaces local state', () async {
    final store = await testStore(seedData(profile: profile()));
    final imported = seedData(profile: profile());
    imported.exercises = [
      imported.exercises.first.copyWith(
        id: 'only-exercise',
        title: 'Only Exercise',
      ),
    ];
    imported.workouts = [];
    imported.logs = [];
    await store.importBackup(imported);
    expect(store.data.exercises, hasLength(1));
    expect(store.data.exercises.single.title, 'Only Exercise');
    expect(store.data.workouts, isEmpty);
  });

  testWidgets('Home renders key cards', (tester) async {
    final data = seedData(profile: profile());
    await tester.pumpWidget(ApexApp(store: await testStore(data)));
    await tester.pumpAndSettle();
    expect(find.text(appName), findsOneWidget);
    expect(find.text('Create Exercise'), findsOneWidget);
    expect(find.text('Create Workout'), findsOneWidget);
  });

  testWidgets('Onboarding saves profile and opens Home', (tester) async {
    final data = seedData();
    data.profile = null;
    final store = await testStore(data);
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Start Setup'), findsOneWidget);
    expect(
      find.textContaining('Personal workout card library.'),
      findsOneWidget,
    );
    await tapText(tester, 'Start Setup');

    expect(find.text('Introduce yourself'), findsOneWidget);
    final disabledContinue = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(disabledContinue.onPressed, isNull);
    await tapText(tester, 'Male');
    final enabledContinue = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(enabledContinue.onPressed, isNotNull);
    await continueOnboarding(tester);

    expect(find.text('When is your birthday?'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Day'), '24');
    await tester.enterText(find.widgetWithText(TextField, 'Month'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Year'), '1994');
    await tester.pumpAndSettle();
    expect(find.textContaining('Age:'), findsOneWidget);
    await continueOnboarding(tester);

    expect(find.text('How tall are you?'), findsOneWidget);
    await tapText(tester, 'ft & in');
    await tester.enterText(find.widgetWithText(TextField, 'Feet'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Inches'), '8');
    await tester.pumpAndSettle();
    await continueOnboarding(tester);

    expect(find.text('What is your weight?'), findsOneWidget);
    await tapText(tester, 'lbs');
    await tester.enterText(find.widgetWithText(TextField, 'Weight lbs'), '165');
    await tester.pumpAndSettle();
    expect(find.textContaining('BMI estimate:'), findsOneWidget);
    await continueOnboarding(tester);

    expect(find.text('Training experience?'), findsOneWidget);
    await tapText(tester, 'Intermediate');
    await continueOnboarding(tester);

    expect(find.text('Save your profile?'), findsOneWidget);
    expect(find.text('Save Profile'), findsOneWidget);
    expect(find.text('Male'), findsWidgets);
    expect(find.textContaining('5 ft 8 in'), findsOneWidget);
    await tapText(tester, 'Save Profile');
    expect(store.data.profile, isNotNull);
    expect(store.route.name, 'home');
    expect(find.text('Create Exercise'), findsOneWidget);
    expect(find.text('Save Profile'), findsNothing);
    expect(store.data.profile!.gender, 'Male');
    expect(store.data.profile!.heightCm, 173);
    expect(store.data.profile!.weightKg.round(), 75);
    expect(store.data.profile!.experienceLevel, 'Intermediate');
    expect(store.data.profile!.weightHistory.single.source, 'onboarding');
  });

  testWidgets(
    'fresh app shows onboarding and saved app opens Home after reload',
    (tester) async {
      final fresh = seedData();
      fresh.profile = null;
      await tester.pumpWidget(ApexApp(store: await testStore(fresh)));
      await tester.pumpAndSettle();
      expect(find.text('Start Setup'), findsOneWidget);

      final savedData = seedData(profile: profile());
      final reloaded = AppData.fromJson(savedData.toJson());
      await tester.pumpWidget(ApexApp(store: await testStore(reloaded)));
      await tester.pumpAndSettle();
      expect(find.text('Create Exercise'), findsOneWidget);
      expect(find.text('Save Profile'), findsNothing);
    },
  );

  testWidgets('invalid birthday blocks profile save with visible error', (
    tester,
  ) async {
    final data = seedData();
    data.profile = null;
    final store = await testStore(data);
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    await tapText(tester, 'Start Setup');
    await tapText(tester, 'Male');
    await continueOnboarding(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Day'), '31');
    await tester.enterText(find.widgetWithText(TextField, 'Month'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Year'), '1994');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid birthday.'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(continueButton.onPressed, isNull);
    expect(store.data.profile, isNull);
  });

  testWidgets('profile editor updates height, weight, and weight history', (
    tester,
  ) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.navigate(const AppRoute('profile-edit'));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Introduce yourself'), findsOneWidget);
    await continueOnboarding(tester);
    await continueOnboarding(tester);
    await tapText(tester, 'ft & in');
    await tester.enterText(find.widgetWithText(TextField, 'Feet'), '6');
    await tester.enterText(find.widgetWithText(TextField, 'Inches'), '0');
    await tester.pumpAndSettle();
    await continueOnboarding(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Weight kg'), '80');
    await tester.pumpAndSettle();
    await continueOnboarding(tester);
    await continueOnboarding(tester);
    await tapText(tester, 'Save Changes');
    expect(store.data.profile!.heightCm, 183);
    expect(store.data.profile!.weightKg, 80);
    expect(store.data.profile!.weightHistory.last.source, 'manual');
  });

  testWidgets('monthly weight prompt can be skipped', (tester) async {
    final dueProfile = profile().copyWith(
      lastWeightPromptAt: DateTime(2026, 1, 1),
    );
    final store = await testStore(seedData(profile: dueProfile));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Monthly Weight Check'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(store.data.profile!.lastWeightPromptAt, isNotNull);
    expect(find.text('Monthly Weight Check'), findsNothing);
  });

  testWidgets('Exercise Library renders seeded exercises', (tester) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.goRoot('exercises');
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Incline Push Up'), findsWidgets);
    expect(find.text('Band Row'), findsWidgets);
  });

  testWidgets('Create Exercise form saves card', (tester) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.navigate(const AppRoute('exercise-edit'));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Test Press');
    await tester.ensureVisible(find.text('Save Exercise Card'));
    await tester.tap(find.text('Save Exercise Card'));
    await tester.pumpAndSettle();
    expect(store.data.exercises.first.title, 'Test Press');
  });

  testWidgets('Create Exercise empty name shows calm validation', (
    tester,
  ) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.navigate(const AppRoute('exercise-edit'));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Exercise Card'));
    await tester.tap(find.text('Save Exercise Card'));
    await tester.pump();
    expect(find.text('Exercise name is required.'), findsOneWidget);
  });

  testWidgets('Create Exercise video section uses upload wording', (
    tester,
  ) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.navigate(const AppRoute('exercise-edit'));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Upload exercise video'), findsOneWidget);
    expect(find.text('No video uploaded yet'), findsOneWidget);
    expect(find.text('Upload Video'), findsOneWidget);
    expect(find.text('Import / Trim Video'), findsNothing);
  });

  test(
    'saving exercise can store permanent video path and trim metadata',
    () async {
      final dir = await Directory.systemTemp.createTemp('apex-save-video-');
      addTearDown(() => dir.delete(recursive: true));
      final stored = File('${dir.path}${Platform.pathSeparator}stored.mp4');
      await stored.writeAsString('fake video');
      final data = seedData(profile: profile());
      final exercise = data.exercises.first.copyWith(
        videoName: 'stored.mp4',
        videoOriginalPath: r'C:\source\stored.mp4',
        videoStoredPath: stored.path,
        videoSizeBytes: await stored.length(),
        videoImportedAt: DateTime(2026, 6, 22),
        clipStartSeconds: 5,
        clipEndSeconds: 22,
      );
      final store = await testStore(data);
      await store.upsertExercise(exercise);
      expect(store.data.exercises.first.videoStoredPath, stored.path);
      expect(store.data.exercises.first.clipStartSeconds, 5);
      expect(store.data.exercises.first.clipEndSeconds, 22);
    },
  );

  test('removing draft video deletes temp file', () async {
    final dir = await Directory.systemTemp.createTemp('apex-remove-video-');
    addTearDown(() => dir.delete(recursive: true));
    final temp = File('${dir.path}${Platform.pathSeparator}temp.mp4');
    await temp.writeAsString('fake video');
    expect(await temp.exists(), isTrue);
    await deleteFileIfExists(temp.path);
    expect(await temp.exists(), isFalse);
  });

  testWidgets('Exercise details displays video filename and clip metadata', (
    tester,
  ) async {
    final data = seedData(profile: profile());
    data.exercises[0] = data.exercises.first.copyWith(
      videoName: 'details.mp4',
      videoStoredPath: r'C:\apex\details.mp4',
      clipStartSeconds: 5,
      clipEndSeconds: 22,
    );
    final store = await testStore(data);
    store.navigate(AppRoute('exercise-details', id: data.exercises.first.id));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('details.mp4'), findsWidgets);
    expect(find.text('Clip 00:05 -> 00:22'), findsOneWidget);
    expect(find.text('Length 00:17'), findsWidgets);
  });

  testWidgets('Settings toggles dark mode', (tester) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.goRoot('settings');
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(store.data.settings.darkMode, isTrue);
  });

  testWidgets('Workout Builder shows selected exercises', (tester) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.navigate(AppRoute('workout-builder', id: data.workouts[1].id));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Upper Body'), findsOneWidget);
    expect(find.textContaining('Incline Push Up'), findsOneWidget);
  });

  testWidgets('Exercise Logging adds set', (tester) async {
    final data = seedData(profile: profile());
    final store = await testStore(data);
    store.navigate(AppRoute('logging', id: data.exercises.first.id));
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Set'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Set 1:'), findsOneWidget);
  });

  testWidgets('History empty state renders', (tester) async {
    final data = seedData(profile: profile());
    data.logs = [];
    final store = await testStore(data);
    store.goRoot('history');
    await tester.pumpWidget(ApexApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('No logs yet.'), findsOneWidget);
  });
}
