import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

const String appName = 'Apex';
const int schemaVersion = 2;
const String storageKey = 'apex.workout_clip_planner.v1';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(ApexApp(store: store));
}

String nowIso() => DateTime.now().toIso8601String();

int _idCounter = 0;

String newId() {
  _idCounter += 1;
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'id_${now}_$_idCounter';
}

String dateOnly(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

String timeCode(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = safe ~/ 60;
  final remaining = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
}

DateTime parseDate(Object? value) {
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final direct = double.tryParse(value);
    if (direct != null) return direct;
    return _firstNumber(value) ?? fallback;
  }
  return fallback;
}

List<String> asStringList(Object? value) {
  if (value is List) return value.map((item) => '$item').toList();
  return <String>[];
}

double? _firstNumber(String value) {
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(value);
  if (match == null) return null;
  return double.tryParse(match.group(0)!);
}

int calculateAge(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;
  final birthdayPassed =
      now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!birthdayPassed) age -= 1;
  return age;
}

int feetInchesToCm(int feet, int inches) {
  return ((feet * 12 + inches) * 2.54).round();
}

({int feet, int inches}) cmToFeetInches(int cm) {
  final totalInches = (cm / 2.54).round();
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

double poundsToKg(double pounds) => pounds / 2.2046226218;

double kgToPounds(double kg) => kg * 2.2046226218;

double calculateBmi({required int heightCm, required double weightKg}) {
  final meters = heightCm / 100;
  if (meters <= 0) return 0;
  return weightKg / pow(meters, 2);
}

String bmiCategory(double bmi) {
  if (bmi <= 0) return 'Profile marker';
  if (bmi < 18.5) return 'Underweight range';
  if (bmi < 25) return 'Healthy range';
  if (bmi < 30) return 'Overweight range';
  return 'Higher range';
}

int _migratedBirthYear(int age, DateTime now) {
  final safeAge = age <= 0 ? 30 : age.clamp(5, 120);
  return now.year - safeAge;
}

DateTime _parseBirthDate(Map<String, dynamic> json) {
  final direct = json['birthDate'];
  if (direct is String) {
    final parsed = DateTime.tryParse(direct);
    if (parsed != null) return parsed;
  }
  final now = DateTime.now();
  return DateTime(_migratedBirthYear(asInt(json['age'], 30), now), 1, 1);
}

int _parseHeightCm(Map<String, dynamic> json) {
  final direct = json['heightCm'];
  if (direct != null) return asInt(direct, 175).clamp(80, 260);
  final text = '${json['height'] ?? ''}'.toLowerCase();
  if (text.contains('ft')) {
    final numbers = RegExp(r'\d+').allMatches(text).map((m) => m.group(0)!);
    final parts = numbers.map(int.parse).toList();
    if (parts.isNotEmpty) {
      return feetInchesToCm(parts.first, parts.length > 1 ? parts[1] : 0);
    }
  }
  return (asDouble(text, 175)).round().clamp(80, 260);
}

double _parseWeightKg(Map<String, dynamic> json) {
  final direct = json['weightKg'];
  if (direct != null) return asDouble(direct, 75).clamp(25, 350).toDouble();
  final text = '${json['weight'] ?? ''}'.toLowerCase();
  final weight = asDouble(text, 75);
  if (text.contains('lb')) return poundsToKg(weight).clamp(25, 350).toDouble();
  return weight.clamp(25, 350).toDouble();
}

bool shouldShowWeightPrompt(UserProfile profile, DateTime now) {
  final last = profile.lastWeightPromptAt;
  if (last == null) return true;
  return now.difference(last).inDays >= 30;
}

const videoExtensions = {'.mp4', '.mov', '.mkv', '.webm', '.avi'};

abstract class VideoPickerService {
  Future<String?> pickVideoPath();
}

class WindowsDialogVideoPicker implements VideoPickerService {
  const WindowsDialogVideoPicker();

  @override
  Future<String?> pickVideoPath() async {
    if (!Platform.isWindows) return null;
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Choose exercise video'
$dialog.Filter = 'Video files (*.mp4;*.mov;*.mkv;*.webm;*.avi)|*.mp4;*.mov;*.mkv;*.webm;*.avi'
$dialog.Multiselect = $false
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::Out.WriteLine($dialog.FileName)
}
''';
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-STA',
      '-Command',
      script,
    ]);
    if (result.exitCode != 0) {
      throw StateError(result.stderr.toString().trim());
    }
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }
}

VideoPickerService videoPickerService = const WindowsDialogVideoPicker();

String fileExtension(String path) {
  final name = path.split(RegExp(r'[\\/]')).last.toLowerCase();
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot);
}

bool isSupportedVideoPath(String path) {
  return videoExtensions.contains(fileExtension(path));
}

String? trimValidationError(int start, int end) {
  if (start < 0) return 'Start cannot be negative.';
  if (end <= start) return 'End must be after Start.';
  if (end - start < 1) return 'Clip must be at least 1 second.';
  return null;
}

String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return cleaned.isEmpty ? 'video.mp4' : cleaned;
}

Directory apexDataDirectory() {
  return Directory(
    '${Directory.current.path}${Platform.pathSeparator}.apex_data',
  );
}

Directory apexVideoDirectory(String bucket) {
  return Directory(
    '${apexDataDirectory().path}${Platform.pathSeparator}videos${Platform.pathSeparator}$bucket',
  );
}

Future<VideoUploadDraft> copyVideoToTemp(String sourcePath) async {
  final source = File(sourcePath);
  final name = source.uri.pathSegments.isEmpty
      ? sourcePath.split(RegExp(r'[\\/]')).last
      : source.uri.pathSegments.last;
  if (!isSupportedVideoPath(name)) {
    throw const VideoUploadException('Unsupported video format.');
  }
  if (!await source.exists()) {
    throw const VideoUploadException('Video file not found.');
  }
  final tempDir = apexVideoDirectory('temp');
  await tempDir.create(recursive: true);
  await apexVideoDirectory('clips').create(recursive: true);
  final importedAt = DateTime.now();
  final storedName =
      'exercise_draft_${importedAt.microsecondsSinceEpoch}_${safeFileName(name)}';
  final tempPath = '${tempDir.path}${Platform.pathSeparator}$storedName';
  try {
    await source.copy(tempPath);
  } catch (_) {
    throw const VideoUploadException('Could not copy video into Apex storage.');
  }
  final tempFile = File(tempPath);
  return VideoUploadDraft(
    originalPath: source.path,
    tempPath: tempPath,
    name: name,
    sizeBytes: await tempFile.length(),
    importedAt: importedAt,
  );
}

Future<String> moveTempVideoToOriginals({
  required String tempPath,
  required String videoName,
  required String exerciseId,
}) async {
  final tempFile = File(tempPath);
  if (!await tempFile.exists()) {
    throw const VideoUploadException('Video file not found.');
  }
  final originals = apexVideoDirectory('originals');
  await originals.create(recursive: true);
  await apexVideoDirectory('clips').create(recursive: true);
  final storedName = '${safeFileName(exerciseId)}_${safeFileName(videoName)}';
  final destination = '${originals.path}${Platform.pathSeparator}$storedName';
  try {
    final copied = await tempFile.copy(destination);
    await tempFile.delete();
    return copied.path;
  } catch (_) {
    throw const VideoUploadException('Could not copy video into Apex storage.');
  }
}

Future<void> deleteFileIfExists(String? path) async {
  if (path == null || path.isEmpty) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}

class VideoUploadException implements Exception {
  const VideoUploadException(this.message);

  final String message;
}

class VideoUploadDraft {
  VideoUploadDraft({
    required this.originalPath,
    required this.tempPath,
    required this.name,
    required this.sizeBytes,
    required this.importedAt,
  });

  final String originalPath;
  final String tempPath;
  final String name;
  final int sizeBytes;
  final DateTime importedAt;
}

class WeightEntry {
  WeightEntry({
    required this.id,
    required this.weightKg,
    required this.date,
    required this.source,
  });

  final String id;
  final double weightKg;
  final DateTime date;
  final String source;

  Map<String, dynamic> toJson() => {
    'id': id,
    'weightKg': weightKg,
    'date': date.toIso8601String(),
    'source': source,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: '${json['id'] ?? newId()}',
    weightKg: asDouble(json['weightKg'], 75),
    date: parseDate(json['date']),
    source: '${json['source'] ?? 'manual'}',
  );
}

class UserProfile {
  UserProfile({
    required this.gender,
    required this.birthDate,
    required this.heightCm,
    required this.heightDisplayUnit,
    required this.weightKg,
    required this.weightDisplayUnit,
    required this.experienceLevel,
    required this.createdAt,
    required this.modifiedAt,
    this.lastWeightPromptAt,
    required this.weightHistory,
  });

  final String gender;
  final DateTime birthDate;
  final int heightCm;
  final String heightDisplayUnit;
  final double weightKg;
  final String weightDisplayUnit;
  final String experienceLevel;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime? lastWeightPromptAt;
  final List<WeightEntry> weightHistory;

  int get age => calculateAge(birthDate, DateTime.now());

  String get height {
    if (heightDisplayUnit == 'ft_in') {
      final parts = cmToFeetInches(heightCm);
      return '${parts.feet} ft ${parts.inches} in';
    }
    return '$heightCm cm';
  }

  String get weight {
    if (weightDisplayUnit == 'lb') return '${kgToPounds(weightKg).g} lb';
    return '${weightKg.g} kg';
  }

  UserProfile copyWith({
    String? gender,
    DateTime? birthDate,
    int? heightCm,
    String? heightDisplayUnit,
    double? weightKg,
    String? weightDisplayUnit,
    String? experienceLevel,
    DateTime? createdAt,
    DateTime? modifiedAt,
    DateTime? lastWeightPromptAt,
    List<WeightEntry>? weightHistory,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      heightDisplayUnit: heightDisplayUnit ?? this.heightDisplayUnit,
      weightKg: weightKg ?? this.weightKg,
      weightDisplayUnit: weightDisplayUnit ?? this.weightDisplayUnit,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lastWeightPromptAt: lastWeightPromptAt ?? this.lastWeightPromptAt,
      weightHistory: weightHistory ?? this.weightHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'gender': gender,
    'birthDate': birthDate.toIso8601String(),
    'heightCm': heightCm,
    'heightDisplayUnit': heightDisplayUnit,
    'weightKg': weightKg,
    'weightDisplayUnit': weightDisplayUnit,
    'experienceLevel': experienceLevel,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
    'lastWeightPromptAt': lastWeightPromptAt?.toIso8601String(),
    'weightHistory': weightHistory.map((entry) => entry.toJson()).toList(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final createdAt = parseDate(json['createdAt']);
    final weightKg = _parseWeightKg(json);
    final rawHistory = json['weightHistory'];
    final history = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map(
                (item) => WeightEntry.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <WeightEntry>[];
    if (history.isEmpty) {
      history.add(
        WeightEntry(
          id: newId(),
          weightKg: weightKg,
          date: createdAt,
          source: 'manual',
        ),
      );
    }
    return UserProfile(
      gender: '${json['gender'] ?? 'Prefer not to say'}',
      birthDate: _parseBirthDate(json),
      heightCm: _parseHeightCm(json),
      heightDisplayUnit: '${json['heightDisplayUnit'] ?? 'cm'}',
      weightKg: weightKg,
      weightDisplayUnit: '${json['weightDisplayUnit'] ?? 'kg'}',
      experienceLevel: '${json['experienceLevel'] ?? 'Beginner'}',
      createdAt: createdAt,
      modifiedAt: parseDate(json['modifiedAt']),
      lastWeightPromptAt: json['lastWeightPromptAt'] == null
          ? null
          : parseDate(json['lastWeightPromptAt']),
      weightHistory: history,
    );
  }
}

class ExerciseCard {
  ExerciseCard({
    required this.id,
    required this.title,
    required this.category,
    required this.equipment,
    required this.difficulty,
    required this.notes,
    required this.tags,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.restTimerSeconds,
    this.videoName,
    this.videoPath,
    this.videoOriginalPath,
    this.videoStoredPath,
    this.videoSizeBytes,
    this.videoImportedAt,
    this.clipStartSeconds,
    this.clipEndSeconds,
    required this.createdAt,
    required this.modifiedAt,
  });

  final String id;
  final String title;
  final String category;
  final String equipment;
  final String difficulty;
  final String notes;
  final List<String> tags;
  final int sets;
  final int reps;
  final double weight;
  final int restTimerSeconds;
  final String? videoName;
  final String? videoPath;
  final String? videoOriginalPath;
  final String? videoStoredPath;
  final int? videoSizeBytes;
  final DateTime? videoImportedAt;
  final int? clipStartSeconds;
  final int? clipEndSeconds;
  final DateTime createdAt;
  final DateTime modifiedAt;

  bool get hasVideo =>
      (videoStoredPath != null && videoStoredPath!.isNotEmpty) ||
      (videoPath != null && videoPath!.isNotEmpty);

  ExerciseCard copyWith({
    String? id,
    String? title,
    String? category,
    String? equipment,
    String? difficulty,
    String? notes,
    List<String>? tags,
    int? sets,
    int? reps,
    double? weight,
    int? restTimerSeconds,
    String? videoName,
    String? videoPath,
    String? videoOriginalPath,
    String? videoStoredPath,
    int? videoSizeBytes,
    DateTime? videoImportedAt,
    int? clipStartSeconds,
    int? clipEndSeconds,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return ExerciseCard(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      restTimerSeconds: restTimerSeconds ?? this.restTimerSeconds,
      videoName: videoName ?? this.videoName,
      videoPath: videoPath ?? this.videoPath,
      videoOriginalPath: videoOriginalPath ?? this.videoOriginalPath,
      videoStoredPath: videoStoredPath ?? this.videoStoredPath,
      videoSizeBytes: videoSizeBytes ?? this.videoSizeBytes,
      videoImportedAt: videoImportedAt ?? this.videoImportedAt,
      clipStartSeconds: clipStartSeconds ?? this.clipStartSeconds,
      clipEndSeconds: clipEndSeconds ?? this.clipEndSeconds,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'equipment': equipment,
    'difficulty': difficulty,
    'notes': notes,
    'tags': tags,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'restTimerSeconds': restTimerSeconds,
    'videoName': videoName,
    'videoPath': videoPath,
    'videoOriginalPath': videoOriginalPath,
    'videoStoredPath': videoStoredPath,
    'videoSizeBytes': videoSizeBytes,
    'videoImportedAt': videoImportedAt?.toIso8601String(),
    'clipStartSeconds': clipStartSeconds,
    'clipEndSeconds': clipEndSeconds,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory ExerciseCard.fromJson(Map<String, dynamic> json) => ExerciseCard(
    id: '${json['id'] ?? newId()}',
    title: '${json['title'] ?? ''}',
    category: '${json['category'] ?? 'Custom'}',
    equipment: '${json['equipment'] ?? 'Bodyweight'}',
    difficulty: '${json['difficulty'] ?? 'Beginner'}',
    notes: '${json['notes'] ?? ''}',
    tags: asStringList(json['tags']),
    sets: asInt(json['sets'], 3),
    reps: asInt(json['reps'], 10),
    weight: asDouble(json['weight']),
    restTimerSeconds: asInt(json['restTimerSeconds'] ?? json['restTimer'], 60),
    videoName: json['videoName'] as String?,
    videoPath: json['videoPath'] as String?,
    videoOriginalPath:
        json['videoOriginalPath'] as String? ?? json['videoPath'] as String?,
    videoStoredPath:
        json['videoStoredPath'] as String? ?? json['videoPath'] as String?,
    videoSizeBytes: json['videoSizeBytes'] == null
        ? null
        : asInt(json['videoSizeBytes']),
    videoImportedAt: json['videoImportedAt'] == null
        ? null
        : parseDate(json['videoImportedAt']),
    clipStartSeconds: json['clipStartSeconds'] == null
        ? null
        : asInt(json['clipStartSeconds']),
    clipEndSeconds: json['clipEndSeconds'] == null
        ? null
        : asInt(json['clipEndSeconds']),
    createdAt: parseDate(json['createdAt'] ?? json['createdDate']),
    modifiedAt: parseDate(json['modifiedAt'] ?? json['modifiedDate']),
  );
}

class Workout {
  Workout({
    required this.id,
    required this.name,
    required this.description,
    required this.exerciseIds,
    required this.createdAt,
    required this.modifiedAt,
  });

  final String id;
  final String name;
  final String description;
  final List<String> exerciseIds;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Workout copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? exerciseIds,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'exerciseIds': exerciseIds,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
    id: '${json['id'] ?? newId()}',
    name: '${json['name'] ?? ''}',
    description: '${json['description'] ?? ''}',
    exerciseIds: asStringList(json['exerciseIds']),
    createdAt: parseDate(json['createdAt'] ?? json['createdDate']),
    modifiedAt: parseDate(json['modifiedAt'] ?? json['modifiedDate']),
  );
}

class LoggedSet {
  LoggedSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.completed,
  });

  final int setNumber;
  final double weight;
  final int reps;
  final bool completed;

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'weight': weight,
    'reps': reps,
    'completed': completed,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    setNumber: asInt(json['setNumber'], 1),
    weight: asDouble(json['weight']),
    reps: asInt(json['reps']),
    completed: json['completed'] != false,
  );
}

class WorkoutLog {
  WorkoutLog({
    required this.id,
    this.workoutId,
    required this.exerciseId,
    required this.date,
    required this.sets,
    this.notes,
  });

  final String id;
  final String? workoutId;
  final String exerciseId;
  final DateTime date;
  final List<LoggedSet> sets;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutId': workoutId,
    'exerciseId': exerciseId,
    'date': date.toIso8601String(),
    'sets': sets.map((set) => set.toJson()).toList(),
    'notes': notes,
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: '${json['id'] ?? newId()}',
    workoutId: json['workoutId'] as String?,
    exerciseId: '${json['exerciseId'] ?? ''}',
    date: parseDate(json['date']),
    sets: (json['sets'] is List ? json['sets'] as List : <Object?>[])
        .whereType<Map>()
        .map((item) => LoggedSet.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    notes: json['notes'] as String?,
  );
}

class AppSettings {
  AppSettings({
    required this.darkMode,
    required this.fontSize,
    required this.seedDemoData,
    required this.modifiedAt,
  });

  final bool darkMode;
  final String fontSize;
  final bool seedDemoData;
  final DateTime modifiedAt;

  AppSettings copyWith({bool? darkMode, String? fontSize, bool? seedDemoData}) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      fontSize: fontSize ?? this.fontSize,
      seedDemoData: seedDemoData ?? this.seedDemoData,
      modifiedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'darkMode': darkMode,
    'fontSize': fontSize,
    'seedDemoData': seedDemoData,
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    darkMode: json['darkMode'] == true,
    fontSize: '${json['fontSize'] ?? 'comfort'}',
    seedDemoData: json['seedDemoData'] != false,
    modifiedAt: parseDate(json['modifiedAt']),
  );
}

class AppData {
  AppData({
    required this.profile,
    required this.settings,
    required this.exercises,
    required this.workouts,
    required this.logs,
  });

  UserProfile? profile;
  AppSettings settings;
  List<ExerciseCard> exercises;
  List<Workout> workouts;
  List<WorkoutLog> logs;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'profile': profile?.toJson(),
    'settings': settings.toJson(),
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    'workouts': workouts.map((workout) => workout.toJson()).toList(),
    'logs': logs.map((log) => log.toJson()).toList(),
  };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final settingsRaw = json['settings'];
    final profileRaw = json['profile'];
    return AppData(
      profile: profileRaw is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(profileRaw))
          : null,
      settings: settingsRaw is Map
          ? AppSettings.fromJson(Map<String, dynamic>.from(settingsRaw))
          : defaultSettings(),
      exercises: (json['exercises'] is List ? json['exercises'] as List : [])
          .whereType<Map>()
          .map((item) => ExerciseCard.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      workouts: (json['workouts'] is List ? json['workouts'] as List : [])
          .whereType<Map>()
          .map((item) => Workout.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      logs: (json['logs'] is List ? json['logs'] as List : [])
          .whereType<Map>()
          .map((item) => WorkoutLog.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  String encodePretty() => const JsonEncoder.withIndent('  ').convert(toJson());
}

AppSettings defaultSettings() => AppSettings(
  darkMode: false,
  fontSize: 'comfort',
  seedDemoData: true,
  modifiedAt: DateTime.now(),
);

AppData seedData({UserProfile? profile}) {
  final time = DateTime.now();
  ExerciseCard card(
    String title,
    String category,
    String equipment,
    String difficulty,
    int sets,
    int reps,
    double weight,
    int rest,
    List<String> tags,
    String notes,
  ) {
    return ExerciseCard(
      id: newId(),
      title: title,
      category: category,
      equipment: equipment,
      difficulty: difficulty,
      notes: notes,
      tags: tags,
      sets: sets,
      reps: reps,
      weight: weight,
      restTimerSeconds: rest,
      createdAt: time,
      modifiedAt: time,
    );
  }

  final c1 = card(
    'Incline Push Up',
    'Chest',
    'Bodyweight',
    'Beginner',
    3,
    10,
    0,
    60,
    ['Push', 'Home'],
    'Keep shoulders down. Lower with control.',
  );
  final c2 = card(
    'Band Row',
    'Back',
    'Band',
    'Beginner',
    4,
    12,
    0,
    60,
    ['Pull'],
    'Squeeze shoulder blades and keep ribs quiet.',
  );
  final c3 = card(
    'Goblet Squat',
    'Legs',
    'Dumbbell',
    'Intermediate',
    3,
    8,
    16,
    90,
    ['Legs', 'Compound'],
    'Chest tall. Knees track over toes.',
  );
  final c4 = card(
    'Wall Slide',
    'Rehab',
    'Bodyweight',
    'Beginner',
    2,
    12,
    0,
    45,
    ['Mobility', 'Shoulder'],
    'Slow tempo. Keep back against wall.',
  );
  return AppData(
    profile: profile,
    settings: defaultSettings(),
    exercises: [c1, c2, c3, c4],
    workouts: [
      Workout(
        id: newId(),
        name: 'Push Day',
        description: 'User-created example for chest and pressing.',
        exerciseIds: [c1.id],
        createdAt: time,
        modifiedAt: time,
      ),
      Workout(
        id: newId(),
        name: 'Upper Body',
        description: 'User-created example with push and pull cards.',
        exerciseIds: [c1.id, c2.id],
        createdAt: time,
        modifiedAt: time,
      ),
      Workout(
        id: newId(),
        name: 'Leg Day',
        description: 'User-created example for lower body.',
        exerciseIds: [c3.id],
        createdAt: time,
        modifiedAt: time,
      ),
      Workout(
        id: newId(),
        name: 'Home Workout',
        description: 'User-created example for simple home sessions.',
        exerciseIds: [c1.id, c4.id, c2.id],
        createdAt: time,
        modifiedAt: time,
      ),
    ],
    logs: [],
  );
}

class AppRoute {
  const AppRoute(this.name, {this.id, this.workoutId});

  final String name;
  final String? id;
  final String? workoutId;
}

class AppStore extends ChangeNotifier {
  AppStore(this.data, {this._storageFile});

  final File? _storageFile;
  AppData data;
  final List<AppRoute> _stack = [const AppRoute('home')];
  Map<String, dynamic> draftExercise = {};

  static Future<AppStore> load() async {
    final file = await defaultStorageFile();
    if (!await file.exists()) {
      return AppStore(seedData(), storageFile: file);
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final loaded = AppData.fromJson(decoded);
        if (loaded.exercises.isEmpty && loaded.settings.seedDemoData) {
          final seeded = seedData(profile: loaded.profile);
          seeded.settings = loaded.settings;
          return AppStore(seeded, storageFile: file);
        }
        return AppStore(loaded, storageFile: file);
      }
    } catch (_) {
      return AppStore(seedData(), storageFile: file);
    }
    return AppStore(seedData(), storageFile: file);
  }

  static Future<AppStore> forTest([AppData? initial]) async {
    return AppStore(initial ?? seedData());
  }

  AppRoute get route =>
      data.profile == null ? const AppRoute('onboarding') : _stack.last;

  Future<void> persist() async {
    if (_storageFile == null) return;
    await _storageFile.parent.create(recursive: true);
    await _storageFile.writeAsString(data.encodePretty());
  }

  Future<void> setProfile(UserProfile profile) async {
    data.profile = profile;
    _stack
      ..clear()
      ..add(const AppRoute('home'));
    await persist();
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile profile) async {
    data.profile = profile.copyWith(modifiedAt: DateTime.now());
    await persist();
    notifyListeners();
  }

  Future<void> recordWeight(double weightKg, String source) async {
    final profile = data.profile;
    if (profile == null) return;
    final now = DateTime.now();
    final entry = WeightEntry(
      id: newId(),
      weightKg: weightKg,
      date: now,
      source: source,
    );
    data.profile = profile.copyWith(
      weightKg: weightKg,
      modifiedAt: now,
      lastWeightPromptAt: source == 'monthly_prompt'
          ? now
          : profile.lastWeightPromptAt,
      weightHistory: [...profile.weightHistory, entry],
    );
    await persist();
    notifyListeners();
  }

  Future<void> skipWeightPrompt() async {
    final profile = data.profile;
    if (profile == null) return;
    data.profile = profile.copyWith(
      lastWeightPromptAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    await persist();
    notifyListeners();
  }

  void navigate(AppRoute route) {
    _stack.add(route);
    notifyListeners();
  }

  void goRoot(String name) {
    _stack
      ..clear()
      ..add(AppRoute(name));
    notifyListeners();
  }

  void back() {
    if (_stack.length > 1) {
      _stack.removeLast();
    } else {
      _stack
        ..clear()
        ..add(const AppRoute('home'));
    }
    notifyListeners();
  }

  ExerciseCard? exerciseById(String id) {
    for (final exercise in data.exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  Workout? workoutById(String id) {
    for (final workout in data.workouts) {
      if (workout.id == id) return workout;
    }
    return null;
  }

  Future<void> upsertExercise(ExerciseCard exercise) async {
    final index = data.exercises.indexWhere((item) => item.id == exercise.id);
    final saved = exercise.copyWith(modifiedAt: DateTime.now());
    if (index >= 0) {
      data.exercises[index] = saved;
    } else {
      data.exercises.insert(0, saved);
    }
    draftExercise = {};
    await persist();
    notifyListeners();
  }

  Future<ExerciseCard?> duplicateExercise(String id) async {
    final source = exerciseById(id);
    if (source == null) return null;
    final copy = source.copyWith(
      id: newId(),
      title: '${source.title} Copy',
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    data.exercises.insert(0, copy);
    await persist();
    notifyListeners();
    return copy;
  }

  Future<void> deleteExercise(String id, {bool deleteVideo = false}) async {
    final exercise = exerciseById(id);
    if (deleteVideo) {
      await deleteFileIfExists(exercise?.videoStoredPath);
    }
    data.exercises.removeWhere((item) => item.id == id);
    data.logs.removeWhere((item) => item.exerciseId == id);
    data.workouts = data.workouts
        .map(
          (workout) => workout.copyWith(
            exerciseIds: workout.exerciseIds
                .where((exerciseId) => exerciseId != id)
                .toList(),
            modifiedAt: DateTime.now(),
          ),
        )
        .toList();
    await persist();
    notifyListeners();
  }

  Future<void> upsertWorkout(Workout workout) async {
    final index = data.workouts.indexWhere((item) => item.id == workout.id);
    final saved = workout.copyWith(modifiedAt: DateTime.now());
    if (index >= 0) {
      data.workouts[index] = saved;
    } else {
      data.workouts.insert(0, saved);
    }
    await persist();
    notifyListeners();
  }

  Future<void> addLog(WorkoutLog log) async {
    data.logs.insert(0, log);
    await persist();
    notifyListeners();
  }

  Future<void> updateSettings({
    bool? darkMode,
    String? fontSize,
    bool? seedDemoData,
  }) async {
    data.settings = data.settings.copyWith(
      darkMode: darkMode,
      fontSize: fontSize,
      seedDemoData: seedDemoData,
    );
    await persist();
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    final seeded = seedData(profile: data.profile);
    seeded.settings = data.settings.copyWith(seedDemoData: true);
    data = seeded;
    await persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    data = seedData();
    data.profile = null;
    if (_storageFile != null && await _storageFile.exists()) {
      await _storageFile.delete();
    }
    _stack
      ..clear()
      ..add(const AppRoute('home'));
    notifyListeners();
  }

  Future<void> importBackup(AppData imported) async {
    data = imported;
    _stack
      ..clear()
      ..add(const AppRoute('home'));
    await persist();
    notifyListeners();
  }
}

Future<File> defaultStorageFile() async {
  final dir = Directory(
    '${Directory.current.path}${Platform.pathSeparator}.apex_data',
  );
  return File('${dir.path}${Platform.pathSeparator}apex_state.json');
}

String exportMarkdown(AppData data) {
  final buffer = StringBuffer()
    ..writeln('# Apex Export')
    ..writeln()
    ..writeln('Generated: ${dateOnly(DateTime.now())}')
    ..writeln()
    ..writeln('## Exercises')
    ..writeln();
  for (final exercise in data.exercises) {
    buffer
      ..writeln('### ${exercise.title}')
      ..writeln('- Category: ${exercise.category}')
      ..writeln('- Equipment: ${exercise.equipment}')
      ..writeln('- Difficulty: ${exercise.difficulty}')
      ..writeln('- Sets: ${exercise.sets}')
      ..writeln('- Reps: ${exercise.reps}')
      ..writeln('- Weight: ${exercise.weight.g} kg')
      ..writeln('- Rest: ${exercise.restTimerSeconds} sec')
      ..writeln('- Tags: ${exercise.tags.join(', ')}')
      ..writeln('- Notes: ${exercise.notes}');
    if (exercise.hasVideo) {
      buffer
        ..writeln('- Video file: ${exercise.videoName ?? 'Uploaded video'}')
        ..writeln('- Video stored path: ${exercise.videoStoredPath ?? ''}');
      if (exercise.clipStartSeconds != null &&
          exercise.clipEndSeconds != null) {
        buffer
          ..writeln(
            '- Clip: ${timeCode(exercise.clipStartSeconds!)} -> ${timeCode(exercise.clipEndSeconds!)}',
          )
          ..writeln(
            '- Clip length: ${timeCode(exercise.clipEndSeconds! - exercise.clipStartSeconds!)}',
          );
      }
    }
    buffer.writeln();
  }
  buffer
    ..writeln('## Workouts')
    ..writeln();
  for (final workout in data.workouts) {
    buffer
      ..writeln('### ${workout.name}')
      ..writeln('- Description: ${workout.description}')
      ..writeln('- Exercises:');
    for (var i = 0; i < workout.exerciseIds.length; i++) {
      final exercise = data.exercises
          .where((item) => item.id == workout.exerciseIds[i])
          .firstOrNull;
      buffer.writeln('  ${i + 1}. ${exercise?.title ?? 'Missing exercise'}');
    }
    buffer.writeln();
  }
  buffer
    ..writeln('## Logs')
    ..writeln();
  for (final log in data.logs) {
    final exercise = data.exercises
        .where((item) => item.id == log.exerciseId)
        .firstOrNull;
    buffer.writeln(
      '### ${dateOnly(log.date)} - ${exercise?.title ?? 'Exercise'}',
    );
    for (final set in log.sets) {
      buffer.writeln(
        '- Set ${set.setNumber}: ${set.weight.g} kg x ${set.reps}',
      );
    }
    buffer.writeln();
  }
  return buffer.toString();
}

extension NumText on double {
  String get g =>
      this == roundToDouble() ? round().toString() : toStringAsFixed(1);
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

bool isValidBackup(Map<String, dynamic> json) {
  return (json['schemaVersion'] == 1 ||
          json['schemaVersion'] == schemaVersion) &&
      json['settings'] is Map &&
      json['exercises'] is List &&
      json['workouts'] is List &&
      json['logs'] is List;
}

class ApexApp extends StatelessWidget {
  const ApexApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(false, store.data.settings.fontSize),
          darkTheme: buildTheme(true, store.data.settings.fontSize),
          themeMode: store.data.settings.darkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: StoreScope(store: store, child: const ApexRoot()),
        );
      },
    );
  }
}

ThemeData buildTheme(bool dark, String size) {
  final colors = dark ? AppColors.dark() : AppColors.light();
  final scale = switch (size) {
    'compact' => 0.92,
    'large' => 1.08,
    _ => 1.0,
  };
  final base = ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: colors.background,
    fontFamily: 'JetBrains Mono',
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: colors.text,
      onPrimary: colors.background,
      secondary: colors.surface2,
      onSecondary: colors.text,
      error: Colors.red.shade700,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.text,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'JetBrains Mono',
      bodyColor: colors.text,
      displayColor: colors.text,
      fontSizeFactor: scale,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.text),
      ),
    ),
  );
}

class AppColors {
  AppColors({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.text,
    required this.muted,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color text;
  final Color muted;
  final Color border;

  factory AppColors.light() => AppColors(
    background: const Color(0xFFF7F7F5),
    surface: const Color(0xFFFFFFFF),
    surface2: const Color(0xFFEEEEEB),
    surface3: const Color(0xFFE4E4DF),
    text: const Color(0xFF0B0B0B),
    muted: const Color(0xFF6B6B66),
    border: const Color(0xFFD8D8D2),
  );

  factory AppColors.dark() => AppColors(
    background: const Color(0xFF0B0B0B),
    surface: const Color(0xFF151515),
    surface2: const Color(0xFF202020),
    surface3: const Color(0xFF2B2B2B),
    text: const Color(0xFFF5F5F0),
    muted: const Color(0xFFA8A8A0),
    border: const Color(0xFF2F2F2F),
  );
}

AppColors c(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.dark()
    : AppColors.light();

class StoreScope extends InheritedWidget {
  const StoreScope({super.key, required this.store, required super.child});

  final AppStore store;

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.store;

  @override
  bool updateShouldNotify(StoreScope oldWidget) => true;
}

class ApexRoot extends StatelessWidget {
  const ApexRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c(context).background,
            border: Border.symmetric(
              vertical: BorderSide(color: c(context).border),
            ),
          ),
          child: Scaffold(
            body: SafeArea(child: _screenFor(context, store.route)),
            bottomNavigationBar: store.data.profile == null
                ? null
                : BottomNav(route: store.route.name),
          ),
        ),
      ),
    );
  }

  Widget _screenFor(BuildContext context, AppRoute route) {
    return switch (route.name) {
      'onboarding' => const OnboardingScreen(),
      'home' => const HomeScreen(),
      'exercises' => const ExerciseLibraryScreen(),
      'exercise-edit' => ExerciseEditorScreen(id: route.id),
      'exercise-details' => ExerciseDetailsScreen(id: route.id ?? ''),
      'workouts' => const WorkoutLibraryScreen(),
      'workout-edit' => WorkoutEditorScreen(id: route.id),
      'workout-builder' => WorkoutBuilderScreen(id: route.id ?? ''),
      'logging' => ExerciseLoggingScreen(
        id: route.id ?? '',
        workoutId: route.workoutId,
      ),
      'history' => ExerciseHistoryScreen(id: route.id),
      'export' => const ExportScreen(),
      'settings' => const SettingsScreen(),
      'profile-edit' => const ProfileEditorScreen(),
      _ => const HomeScreen(),
    };
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = [
      ('home', Icons.home_outlined, 'Home'),
      ('exercises', Icons.view_agenda_outlined, 'Cards'),
      ('workouts', Icons.playlist_add_check, 'Build'),
      ('history', Icons.history, 'History'),
      ('settings', Icons.tune, 'Settings'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c(context).surface,
        border: Border(top: BorderSide(color: c(context).border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => store.goRoot(item.$1),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: route == item.$1
                        ? c(context).surface2
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.$2, size: 20),
                      const SizedBox(height: 2),
                      Text(item.$3, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScreenPad extends StatelessWidget {
  const ScreenPad({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Back',
              onPressed: store.back,
              icon: const Icon(Icons.arrow_back),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: c(context).muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = 16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: c(context).surface,
        border: Border.all(color: c(context).border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: card,
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: secondary
          ? OutlinedButton(onPressed: onPressed, child: child)
          : FilledButton(onPressed: onPressed, child: child),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: active,
      label: Text(label),
      onSelected: (_) => onTap(),
      showCheckmark: false,
      side: BorderSide(color: c(context).border),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: 12,
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: c(context).muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlaceholder extends StatelessWidget {
  const VideoPlaceholder({
    super.key,
    this.name,
    this.start,
    this.end,
    this.uploaded = false,
    this.compact = false,
  });

  final String? name;
  final int? start;
  final int? end;
  final bool uploaded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasClip = start != null && end != null;
    final hasName = name != null && name!.isNotEmpty;
    return Container(
      height: compact ? 74 : 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: c(context).surface2,
        borderRadius: BorderRadius.circular(compact ? 12 : 18),
        border: Border.all(color: c(context).border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, size: compact ? 24 : 42),
          SizedBox(height: compact ? 4 : 10),
          Text(
            uploaded
                ? (hasClip ? 'Clip saved' : 'Video uploaded')
                : (compact ? 'No video' : 'Upload exercise video'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (!uploaded && !compact)
            Text(
              'MP4, MOV, MKV, WEBM, AVI',
              textAlign: TextAlign.center,
              style: TextStyle(color: c(context).muted, fontSize: 12),
            ),
          if (uploaded && hasName)
            Text(
              name!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c(context).muted, fontSize: 12),
            ),
          if (uploaded && !hasClip)
            Text(
              'Stored locally',
              style: TextStyle(color: c(context).muted, fontSize: 12),
            ),
          if (hasClip)
            Text(
              '${timeCode(start!)} -> ${timeCode(end!)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: c(context).muted, fontSize: 12),
            ),
          if (hasClip && !compact)
            Text(
              'Length ${timeCode(end! - start!)}',
              style: TextStyle(color: c(context).muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> confirmDeleteVideo(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete attached local video too?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Video'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete Video'),
            ),
          ],
        ),
      ) ??
      false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ProfileForm(
      title: appName,
      subtitle: 'Personal workout card library',
      submitLabel: 'Save Profile',
      onSave: store.setProfile,
    );
  }
}

enum OnboardingStep {
  welcome,
  gender,
  birthday,
  height,
  weight,
  experience,
  review,
}

class ProfileEditorScreen extends StatelessWidget {
  const ProfileEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ProfileForm(
      title: 'Edit Profile',
      subtitle: 'Keep your training basics current',
      initialProfile: store.data.profile,
      submitLabel: 'Save Changes',
      showBack: true,
      onSave: (profile) async {
        await store.updateProfile(profile);
        store.back();
        if (context.mounted) toast(context, 'Profile updated.');
      },
    );
  }
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.onSave,
    this.initialProfile,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final String submitLabel;
  final UserProfile? initialProfile;
  final bool showBack;
  final Future<void> Function(UserProfile profile) onSave;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final List<OnboardingStep> steps;
  late int stepIndex;
  late String gender;
  late String experience;
  late String heightUnit;
  late String weightUnit;
  late final TextEditingController day;
  late final TextEditingController month;
  late final TextEditingController year;
  late final TextEditingController heightCm;
  late final TextEditingController heightFeet;
  late final TextEditingController heightInches;
  late final TextEditingController weightKg;
  late final TextEditingController weightLb;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    steps = widget.initialProfile == null
        ? OnboardingStep.values
        : OnboardingStep.values
              .where((step) => step != OnboardingStep.welcome)
              .toList();
    stepIndex = 0;
    final defaultBirthDate = DateTime(DateTime.now().year - 28, 1, 1);
    final birthDate = profile?.birthDate ?? defaultBirthDate;
    final height = cmToFeetInches(profile?.heightCm ?? 175);
    final kg = profile?.weightKg ?? 75;
    gender = profile?.gender ?? '';
    experience = profile?.experienceLevel ?? '';
    heightUnit = profile?.heightDisplayUnit ?? 'cm';
    weightUnit = profile?.weightDisplayUnit ?? 'kg';
    day = TextEditingController(text: '${birthDate.day}');
    month = TextEditingController(text: '${birthDate.month}');
    year = TextEditingController(text: '${birthDate.year}');
    heightCm = TextEditingController(text: '${profile?.heightCm ?? 175}');
    heightFeet = TextEditingController(text: '${height.feet}');
    heightInches = TextEditingController(text: '${height.inches}');
    weightKg = TextEditingController(text: kg.g);
    weightLb = TextEditingController(text: kgToPounds(kg).round().toString());
  }

  @override
  void dispose() {
    day.dispose();
    month.dispose();
    year.dispose();
    heightCm.dispose();
    heightFeet.dispose();
    heightInches.dispose();
    weightKg.dispose();
    weightLb.dispose();
    super.dispose();
  }

  DateTime? _birthDate() {
    final y = int.tryParse(year.text.trim());
    final m = int.tryParse(month.text.trim());
    final d = int.tryParse(day.text.trim());
    if (y == null || m == null || d == null) return null;
    final value = DateTime(y, m, d);
    if (value.year != y || value.month != m || value.day != d) return null;
    return value;
  }

  OnboardingStep get step => steps[stepIndex];

  bool get isFirstStep => stepIndex == 0;

  bool get isLastStep => stepIndex == steps.length - 1;

  String get _flowTitle =>
      widget.initialProfile == null ? widget.title : 'Edit Profile';

  int? get _age {
    final birthDate = _birthDate();
    if (birthDate == null) return null;
    return calculateAge(birthDate, DateTime.now());
  }

  String? _birthdayError() {
    final birthDate = _birthDate();
    final age = _age;
    final now = DateTime.now();
    if (birthDate == null) return 'Enter a valid birthday.';
    if (birthDate.isAfter(now)) return 'Birthday cannot be in the future.';
    if (age == null || age < 10 || age > 100) {
      return 'Age must be between 10 and 100.';
    }
    return null;
  }

  int? _currentHeightCm() {
    if (heightUnit == 'cm') return int.tryParse(heightCm.text.trim());
    final feet = int.tryParse(heightFeet.text.trim());
    final inches = int.tryParse(heightInches.text.trim());
    if (feet == null || inches == null) return null;
    return feetInchesToCm(feet, inches);
  }

  String? _heightError() {
    if (heightUnit == 'cm') {
      final value = int.tryParse(heightCm.text.trim());
      if (value == null || value < 90 || value > 230) {
        return 'Height must be between 90 and 230 cm.';
      }
      return null;
    }
    final feet = int.tryParse(heightFeet.text.trim());
    final inches = int.tryParse(heightInches.text.trim());
    if (feet == null || inches == null || inches < 0 || inches > 11) {
      return 'Enter height in feet and inches.';
    }
    final totalInches = feet * 12 + inches;
    if (totalInches < 36 || totalInches > 95) {
      return 'Height must be between 3 ft 0 in and 7 ft 11 in.';
    }
    return null;
  }

  double? _currentWeightKg() {
    if (weightUnit == 'kg') return double.tryParse(weightKg.text.trim());
    final pounds = double.tryParse(weightLb.text.trim());
    if (pounds == null) return null;
    return poundsToKg(pounds);
  }

  String? _weightError() {
    final value = _currentWeightKg();
    if (value == null || value < 25 || value > 350) {
      return 'Weight must be between 25 and 350 kg.';
    }
    return null;
  }

  bool _canContinue() {
    return switch (step) {
      OnboardingStep.welcome => true,
      OnboardingStep.gender => gender.isNotEmpty,
      OnboardingStep.birthday => _birthdayError() == null,
      OnboardingStep.height => _heightError() == null,
      OnboardingStep.weight => _weightError() == null,
      OnboardingStep.experience => experience.isNotEmpty,
      OnboardingStep.review =>
        _birthdayError() == null &&
            _heightError() == null &&
            _weightError() == null &&
            gender.isNotEmpty &&
            experience.isNotEmpty,
    };
  }

  void _goBack() {
    if (stepIndex > 0) {
      setState(() => stepIndex -= 1);
      return;
    }
    if (widget.showBack) StoreScope.of(context).back();
  }

  Future<void> _continue() async {
    if (!_canContinue()) return;
    if (isLastStep) {
      await _submit(context);
      return;
    }
    setState(() => stepIndex += 1);
  }

  void _setHeightUnit(String unit) {
    final current = _currentHeightCm();
    if (current != null) {
      final parts = cmToFeetInches(current);
      heightCm.text = '$current';
      heightFeet.text = '${parts.feet}';
      heightInches.text = '${parts.inches}';
    }
    setState(() => heightUnit = unit);
  }

  void _setWeightUnit(String unit) {
    final current = _currentWeightKg();
    if (current != null) {
      weightKg.text = current.g;
      weightLb.text = kgToPounds(current).round().toString();
    }
    setState(() => weightUnit = unit);
  }

  UserProfile? _profileFromForm(BuildContext context) {
    final birthDate = _birthDate();
    final birthdayError = _birthdayError();
    if (birthDate == null || birthdayError != null) {
      toast(context, birthdayError ?? 'Enter a valid birthday.');
      return null;
    }
    final normalizedHeightCm = _currentHeightCm();
    final heightError = _heightError();
    if (normalizedHeightCm == null || heightError != null) {
      toast(context, heightError ?? 'Enter a valid height.');
      return null;
    }
    final normalizedWeightKg = _currentWeightKg();
    final weightError = _weightError();
    if (normalizedWeightKg == null || weightError != null) {
      toast(context, weightError ?? 'Enter a valid weight.');
      return null;
    }

    final initial = widget.initialProfile;
    final timestamp = DateTime.now();
    final history = [...?initial?.weightHistory];
    if (initial == null) {
      history.add(
        WeightEntry(
          id: newId(),
          weightKg: normalizedWeightKg,
          date: timestamp,
          source: 'onboarding',
        ),
      );
    } else if ((initial.weightKg - normalizedWeightKg).abs() > 0.01) {
      history.add(
        WeightEntry(
          id: newId(),
          weightKg: normalizedWeightKg,
          date: timestamp,
          source: 'manual',
        ),
      );
    }

    return UserProfile(
      gender: gender,
      birthDate: birthDate,
      heightCm: normalizedHeightCm,
      heightDisplayUnit: heightUnit,
      weightKg: normalizedWeightKg,
      weightDisplayUnit: weightUnit,
      experienceLevel: experience,
      createdAt: initial?.createdAt ?? timestamp,
      modifiedAt: timestamp,
      lastWeightPromptAt: initial?.lastWeightPromptAt,
      weightHistory: history,
    );
  }

  Future<void> _submit(BuildContext context) async {
    final profile = _profileFromForm(context);
    if (profile == null || saving) return;
    setState(() => saving = true);
    try {
      await widget.onSave(profile);
    } catch (_) {
      if (context.mounted) toast(context, 'Profile could not be saved.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WizardHeader(
            title: _flowTitle,
            subtitle: widget.subtitle,
            showBack: widget.showBack || stepIndex > 0,
            onBack: _goBack,
          ),
          if (steps.length > 1) ...[
            _ProgressPill(current: stepIndex + 1, total: steps.length),
            const SizedBox(height: 20),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: KeyedSubtree(key: ValueKey(step), child: _stepBody(context)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: saving
                  ? 'Saving...'
                  : isLastStep
                  ? widget.submitLabel
                  : step == OnboardingStep.welcome
                  ? 'Start Setup'
                  : 'Continue',
              icon: isLastStep ? Icons.check : Icons.arrow_forward,
              onPressed: saving || !_canContinue() ? null : _continue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    return switch (step) {
      OnboardingStep.welcome => _QuestionStep(
        eyebrow: 'Welcome',
        question: appName,
        insight:
            'Personal workout card library.\nStored on this device only.\n\nNo account. No cloud. Your data stays local.',
        child: const SizedBox.shrink(),
      ),
      OnboardingStep.gender => _QuestionStep(
        eyebrow: 'Profile',
        question: 'Introduce yourself',
        insight: 'Choose the option that should appear in your local profile.',
        child: _OptionGrid(
          values: const ['Male', 'Female', 'Other', 'Prefer not to say'],
          selected: gender,
          onSelected: (value) => setState(() => gender = value),
        ),
      ),
      OnboardingStep.birthday => _birthdayStep(),
      OnboardingStep.height => _heightStep(),
      OnboardingStep.weight => _weightStep(),
      OnboardingStep.experience => _QuestionStep(
        eyebrow: 'Training',
        question: 'Training experience?',
        insight:
            'This is a simple profile label. Apex will not generate a program from it.',
        child: _OptionGrid(
          values: const ['Beginner', 'Intermediate', 'Advanced'],
          selected: experience,
          onSelected: (value) => setState(() => experience = value),
        ),
      ),
      OnboardingStep.review => _reviewStep(),
    };
  }

  Widget _birthdayStep() {
    final error = _birthdayError();
    final age = _age;
    return _QuestionStep(
      eyebrow: 'Birthday',
      question: 'When is your birthday?',
      insight: error ?? (age == null ? 'Age: -' : 'Age: $age years'),
      error: error,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: day,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Day'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: month,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Month'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heightStep() {
    final error = _heightError();
    final value = heightUnit == 'cm'
        ? '${heightCm.text.trim()} cm'
        : '${heightFeet.text.trim()} ft ${heightInches.text.trim()} in';
    return _QuestionStep(
      eyebrow: 'Height',
      question: 'How tall are you?',
      insight: error ?? 'Stored as heightCm for consistent local data.',
      error: error,
      child: Column(
        children: [
          _BigValue(value: value),
          const SizedBox(height: 14),
          _UnitToggle(
            left: 'cm',
            right: 'ft & in',
            leftActive: heightUnit == 'cm',
            onLeft: () => _setHeightUnit('cm'),
            onRight: () => _setHeightUnit('ft_in'),
          ),
          const SizedBox(height: 14),
          if (heightUnit == 'cm')
            TextField(
              controller: heightCm,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height cm'),
              onChanged: (_) => setState(() {}),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: heightFeet,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Feet'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: heightInches,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Inches'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _weightStep() {
    final error = _weightError();
    final height = _currentHeightCm();
    final weight = _currentWeightKg();
    final bmi = height == null || weight == null
        ? null
        : calculateBmi(heightCm: height, weightKg: weight);
    return _QuestionStep(
      eyebrow: 'Weight',
      question: 'What is your weight?',
      insight: error ?? 'Stored as weightKg and added to weight history.',
      error: error,
      child: Column(
        children: [
          _BigValue(
            value: weightUnit == 'kg'
                ? '${weightKg.text.trim()} kg'
                : '${weightLb.text.trim()} lbs',
          ),
          const SizedBox(height: 14),
          _UnitToggle(
            left: 'kg',
            right: 'lbs',
            leftActive: weightUnit == 'kg',
            onLeft: () => _setWeightUnit('kg'),
            onRight: () => _setWeightUnit('lb'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: weightUnit == 'kg' ? weightKg : weightLb,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: weightUnit == 'kg' ? 'Weight kg' : 'Weight lbs',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (bmi != null && error == null) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BMI estimate: ${bmi.toStringAsFixed(1)}'),
                  const SizedBox(height: 4),
                  Text(
                    '${bmiCategory(bmi)}. Useful only as a rough profile marker.',
                    style: TextStyle(color: c(context).muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewStep() {
    final birthDate = _birthDate();
    final height = _currentHeightCm() ?? 0;
    final weight = _currentWeightKg() ?? 0;
    final heightParts = cmToFeetInches(height);
    final bmi = height > 0 && weight > 0
        ? calculateBmi(heightCm: height, weightKg: weight)
        : 0;
    return _QuestionStep(
      eyebrow: 'Review',
      question: 'Save your profile?',
      insight: 'Check the local profile details before Apex opens Home.',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow('Gender', gender),
            _SummaryRow(
              'Birthday',
              birthDate == null ? '-' : dateOnly(birthDate),
            ),
            _SummaryRow('Age', _age == null ? '-' : '${_age!}'),
            _SummaryRow(
              'Height',
              '${heightParts.feet} ft ${heightParts.inches} in / $height cm',
            ),
            _SummaryRow('Weight', '${weight.g} kg'),
            _SummaryRow('Experience', experience),
            if (bmi > 0) _SummaryRow('BMI estimate', bmi.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: c(context).muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: c(context).surface2,
            valueColor: AlwaysStoppedAnimation(c(context).text),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Step $current of $total',
          style: TextStyle(color: c(context).muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _QuestionStep extends StatelessWidget {
  const _QuestionStep({
    required this.eyebrow,
    required this.question,
    required this.child,
    this.insight,
    this.error,
  });

  final String eyebrow;
  final String question;
  final String? insight;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: c(context).muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          question,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        if (insight != null) ...[
          const SizedBox(height: 10),
          Text(
            insight!,
            style: TextStyle(
              color: error == null ? c(context).muted : Colors.red.shade700,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values
          .map(
            (value) => SizedBox(
              width: 186,
              child: AppCard(
                padding: 14,
                onTap: () => onSelected(value),
                child: Row(
                  children: [
                    Icon(
                      selected == value
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.left,
    required this.right,
    required this.leftActive,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final bool leftActive;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c(context).surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c(context).border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: left,
              active: leftActive,
              onTap: onLeft,
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: right,
              active: !leftActive,
              onTap: onRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? c(context).text : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c(context).background : c(context).text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 44,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: TextStyle(color: c(context).muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final recentExercises = store.data.exercises.take(3).toList();
    final recentWorkouts = store.data.workouts.take(3).toList();
    final profile = store.data.profile;
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(
            title: appName,
            subtitle: 'Personal workout card library',
          ),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Cards',
                  value: '${store.data.exercises.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Workouts',
                  value: '${store.data.workouts.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Logs',
                  value: '${store.data.logs.length}',
                ),
              ),
            ],
          ),
          if (profile != null &&
              shouldShowWeightPrompt(profile, DateTime.now()))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Weight Check',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current: ${profile.weight}',
                      style: TextStyle(color: c(context).muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppButton(
                          label: 'Update Weight',
                          icon: Icons.monitor_weight_outlined,
                          onPressed: () => _showWeightPrompt(context, store),
                        ),
                        AppButton(
                          label: 'Skip',
                          icon: Icons.close,
                          secondary: true,
                          onPressed: () => store.skipWeightPrompt(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              _homeAction(
                context,
                'Create Exercise',
                Icons.add,
                () => store.navigate(const AppRoute('exercise-edit')),
              ),
              _homeAction(
                context,
                'Create Workout',
                Icons.playlist_add,
                () => store.navigate(const AppRoute('workout-edit')),
              ),
              _homeAction(
                context,
                'Exercise Library',
                Icons.view_agenda_outlined,
                () => store.goRoot('exercises'),
              ),
              _homeAction(
                context,
                'Export Data',
                Icons.file_upload_outlined,
                () => store.navigate(const AppRoute('export')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section('Recent Exercises'),
          for (final exercise in recentExercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExerciseListCard(exercise: exercise),
            ),
          _section('Recent Workouts'),
          for (final workout in recentWorkouts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WorkoutListCard(workout: workout),
            ),
        ],
      ),
    );
  }

  Future<void> _showWeightPrompt(BuildContext context, AppStore store) async {
    final profile = store.data.profile;
    if (profile == null) return;
    final controller = TextEditingController(text: profile.weightKg.g);
    try {
      final value = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Weight'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight kg'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                Navigator.pop(context, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (value == null) return;
      if (value < 25 || value > 350) {
        if (context.mounted) toast(context, 'Enter a valid weight.');
        return;
      }
      await store.recordWeight(value, 'monthly_prompt');
    } finally {
      controller.dispose();
    }
  }

  Widget _homeAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

Widget _section(String text) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 10),
  child: Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  ),
);

const categories = [
  'Chest',
  'Back',
  'Legs',
  'Mobility',
  'Rehab',
  'Powerlifting',
  'Custom',
];
const equipment = [
  'Bodyweight',
  'Dumbbell',
  'Barbell',
  'Band',
  'Machine',
  'Kettlebell',
  'Custom',
];
const difficulties = ['Beginner', 'Intermediate', 'Advanced'];
const restOptions = [30, 45, 60, 90, 120, 180, 240];

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String query = '';
  String? category;
  bool grid = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final userCategories = {
      ...categories,
      ...store.data.exercises.map((e) => e.category),
    }.toList();
    final filtered = store.data.exercises.where((exercise) {
      final searchable =
          '${exercise.title} ${exercise.tags.join(' ')} ${exercise.equipment}'
              .toLowerCase();
      return (category == null || exercise.category == category) &&
          (query.isEmpty || searchable.contains(query.toLowerCase()));
    }).toList();
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Exercise Library',
            subtitle: '${store.data.exercises.length} cards',
            trailing: IconButton.filled(
              tooltip: 'Create exercise',
              onPressed: () => store.navigate(const AppRoute('exercise-edit')),
              icon: const Icon(Icons.add),
            ),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search title, tag, equipment',
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppChip(
                        label: 'All',
                        active: category == null,
                        onTap: () => setState(() => category = null),
                      ),
                      const SizedBox(width: 8),
                      for (final item in userCategories) ...[
                        AppChip(
                          label: item,
                          active: category == item,
                          onTap: () => setState(() => category = item),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Toggle layout',
                onPressed: () => setState(() => grid = !grid),
                icon: Icon(grid ? Icons.view_list : Icons.grid_view),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const AppCard(
              child: Center(child: Text('No exercises match your filters.')),
            ),
          if (grid)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.78,
              children: [
                for (final exercise in filtered)
                  ExerciseGridCard(exercise: exercise),
              ],
            )
          else
            for (final exercise in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExerciseListCard(exercise: exercise),
              ),
        ],
      ),
    );
  }
}

class ExerciseListCard extends StatelessWidget {
  const ExerciseListCard({super.key, required this.exercise});

  final ExerciseCard exercise;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppCard(
      onTap: () =>
          store.navigate(AppRoute('exercise-details', id: exercise.id)),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: VideoPlaceholder(
              name: exercise.videoName,
              start: exercise.clipStartSeconds,
              end: exercise.clipEndSeconds,
              uploaded: exercise.hasVideo,
              compact: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${exercise.category} / ${exercise.equipment} / ${exercise.difficulty}',
                  style: TextStyle(color: c(context).muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.sets} x ${exercise.reps} / ${exercise.weight.g}kg / rest ${exercise.restTimerSeconds}s',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                ),
                if (exercise.hasVideo)
                  Text(
                    exercise.clipStartSeconds != null &&
                            exercise.clipEndSeconds != null
                        ? 'Video uploaded / Clip ${timeCode(exercise.clipStartSeconds!)} -> ${timeCode(exercise.clipEndSeconds!)}'
                        : 'Video uploaded',
                    style: TextStyle(color: c(context).muted, fontSize: 11),
                  ),
                if (exercise.notes.isNotEmpty)
                  Text(
                    exercise.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c(context).muted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ExerciseGridCard extends StatelessWidget {
  const ExerciseGridCard({super.key, required this.exercise});

  final ExerciseCard exercise;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppCard(
      onTap: () =>
          store.navigate(AppRoute('exercise-details', id: exercise.id)),
      padding: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoPlaceholder(
            name: exercise.videoName,
            start: exercise.clipStartSeconds,
            end: exercise.clipEndSeconds,
            uploaded: exercise.hasVideo,
          ),
          const SizedBox(height: 8),
          Text(
            exercise.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${exercise.category} / ${exercise.equipment}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c(context).muted, fontSize: 10),
          ),
          Text(
            '${exercise.sets} x ${exercise.reps} / ${exercise.weight.g}kg',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11),
          ),
          if (exercise.hasVideo)
            Text(
              exercise.clipStartSeconds != null &&
                      exercise.clipEndSeconds != null
                  ? 'Video / Clip ${timeCode(exercise.clipStartSeconds!)} -> ${timeCode(exercise.clipEndSeconds!)}'
                  : 'Video / Uploaded',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c(context).muted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class ExerciseEditorScreen extends StatefulWidget {
  const ExerciseEditorScreen({super.key, this.id});

  final String? id;

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  final title = TextEditingController();
  final notes = TextEditingController();
  final tags = TextEditingController();
  final weight = TextEditingController(text: '0');
  String category = 'Chest';
  String selectedEquipment = 'Bodyweight';
  String difficulty = 'Beginner';
  int sets = 3;
  int reps = 10;
  int rest = 60;
  String? videoName;
  String? videoPath;
  String? videoOriginalPath;
  String? videoStoredPath;
  String? draftVideoTempPath;
  int? videoSizeBytes;
  DateTime? videoImportedAt;
  int? clipStart;
  int? clipEnd;
  ExerciseCard? original;
  bool ready = false;
  bool saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    final store = StoreScope.of(context);
    original = widget.id == null ? null : store.exerciseById(widget.id!);
    final draft = store.draftExercise;
    final source = original;
    title.text = '${draft['title'] ?? source?.title ?? ''}';
    notes.text = '${draft['notes'] ?? source?.notes ?? ''}';
    tags.text =
        (draft['tags'] is List
            ? (draft['tags'] as List).join(', ')
            : source?.tags.join(', ')) ??
        '';
    category = '${draft['category'] ?? source?.category ?? 'Chest'}';
    selectedEquipment =
        '${draft['equipment'] ?? source?.equipment ?? 'Bodyweight'}';
    difficulty = '${draft['difficulty'] ?? source?.difficulty ?? 'Beginner'}';
    sets = asInt(draft['sets'] ?? source?.sets, 3);
    reps = asInt(draft['reps'] ?? source?.reps, 10);
    weight.text = '${draft['weight'] ?? source?.weight ?? 0}';
    rest = asInt(draft['restTimerSeconds'] ?? source?.restTimerSeconds, 60);
    videoName = draft['draftVideoName'] as String? ?? source?.videoName;
    videoPath = draft['draftVideoOriginalPath'] as String? ?? source?.videoPath;
    videoOriginalPath =
        draft['draftVideoOriginalPath'] as String? ?? source?.videoOriginalPath;
    videoStoredPath =
        draft['videoStoredPath'] as String? ?? source?.videoStoredPath;
    draftVideoTempPath = draft['draftVideoTempPath'] as String?;
    videoSizeBytes =
        draft['draftVideoSizeBytes'] as int? ?? source?.videoSizeBytes;
    videoImportedAt =
        draft['draftVideoImportedAt'] as DateTime? ?? source?.videoImportedAt;
    clipStart = draft['clipStartSeconds'] as int? ?? source?.clipStartSeconds;
    clipEnd = draft['clipEndSeconds'] as int? ?? source?.clipEndSeconds;
    ready = true;
  }

  @override
  void dispose() {
    if (!saved) {
      deleteFileIfExists(draftVideoTempPath);
    }
    title.dispose();
    notes.dispose();
    tags.dispose();
    weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: widget.id == null ? 'Create Exercise' : 'Edit Exercise',
            showBack: true,
          ),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Exercise Name'),
          ),
          const SizedBox(height: 12),
          VideoPlaceholder(
            name: videoName,
            start: clipStart,
            end: clipEnd,
            uploaded: _hasUploadedVideo,
          ),
          const SizedBox(height: 8),
          if (!_hasUploadedVideo)
            AppButton(
              label: 'Upload Video',
              icon: Icons.video_file_outlined,
              onPressed: () => _uploadVideo(context),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: 'Trim Video',
                  icon: Icons.content_cut,
                  onPressed: () => _trimVideo(context),
                ),
                AppButton(
                  label: 'Change Video',
                  icon: Icons.swap_horiz,
                  secondary: true,
                  onPressed: () => _uploadVideo(context),
                ),
                AppButton(
                  label: 'Remove Video',
                  icon: Icons.delete_outline,
                  secondary: true,
                  onPressed: _removeDraftVideo,
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _hasUploadedVideo ? 'Video uploaded' : 'No video uploaded yet',
              style: TextStyle(color: c(context).muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          _choice(
            'Category',
            categories,
            category,
            (value) => setState(() => category = value),
          ),
          _choice(
            'Equipment',
            equipment,
            selectedEquipment,
            (value) => setState(() => selectedEquipment = value),
          ),
          _choice(
            'Difficulty',
            difficulties,
            difficulty,
            (value) => setState(() => difficulty = value),
          ),
          _stepper(
            'Sets',
            sets,
            (value) => setState(() => sets = value.clamp(1, 20)),
          ),
          _stepper(
            'Reps',
            reps,
            (value) => setState(() => reps = value.clamp(1, 100)),
          ),
          TextField(
            controller: weight,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
          const SizedBox(height: 12),
          _choice(
            'Rest Timer',
            restOptions.map((item) => '$item sec').toList(),
            '$rest sec',
            (value) => setState(() => rest = int.parse(value.split(' ').first)),
          ),
          TextField(
            controller: notes,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tags,
            decoration: const InputDecoration(
              labelText: 'Tags, comma separated',
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Save Exercise Card',
            icon: Icons.save_outlined,
            onPressed: () async {
              if (title.text.trim().isEmpty) {
                toast(context, 'Exercise name is required.');
                return;
              }
              final time = DateTime.now();
              final exerciseId = original?.id ?? newId();
              var permanentStoredPath = videoStoredPath;
              if (draftVideoTempPath != null) {
                try {
                  permanentStoredPath = await moveTempVideoToOriginals(
                    tempPath: draftVideoTempPath!,
                    videoName: videoName ?? 'video.mp4',
                    exerciseId: exerciseId,
                  );
                } on VideoUploadException catch (error) {
                  if (context.mounted) toast(context, error.message);
                  return;
                }
              }
              final exercise = ExerciseCard(
                id: exerciseId,
                title: title.text.trim(),
                category: category,
                equipment: selectedEquipment,
                difficulty: difficulty,
                notes: notes.text.trim(),
                tags: tags.text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList(),
                sets: sets,
                reps: reps,
                weight: double.tryParse(weight.text.trim()) ?? 0,
                restTimerSeconds: rest,
                videoName: videoName,
                videoPath: videoPath,
                videoOriginalPath: videoOriginalPath,
                videoStoredPath: permanentStoredPath,
                videoSizeBytes: videoSizeBytes,
                videoImportedAt: videoImportedAt,
                clipStartSeconds: clipStart,
                clipEndSeconds: clipEnd,
                createdAt: original?.createdAt ?? time,
                modifiedAt: time,
              );
              saved = true;
              draftVideoTempPath = null;
              await store.upsertExercise(exercise);
              if (!context.mounted) return;
              store.navigate(AppRoute('exercise-details', id: exercise.id));
            },
          ),
        ],
      ),
    );
  }

  Widget _choice(
    String label,
    List<String> values,
    String active,
    ValueChanged<String> onPick,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                AppChip(
                  label: value,
                  active: active == value,
                  onTap: () => onPick(value),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onChange(value - 1),
              icon: const Icon(Icons.remove),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              onPressed: () => onChange(value + 1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasUploadedVideo =>
      (draftVideoTempPath != null && draftVideoTempPath!.isNotEmpty) ||
      (videoStoredPath != null && videoStoredPath!.isNotEmpty);

  void _syncDraft(AppStore store) {
    store.draftExercise = {
      'draftVideoOriginalPath': videoOriginalPath,
      'draftVideoTempPath': draftVideoTempPath,
      'draftVideoName': videoName,
      'draftVideoSizeBytes': videoSizeBytes,
      'draftVideoImportedAt': videoImportedAt,
      'videoStoredPath': videoStoredPath,
      'clipStartSeconds': clipStart,
      'clipEndSeconds': clipEnd,
    };
  }

  Future<void> _uploadVideo(BuildContext context) async {
    final store = StoreScope.of(context);
    final sourcePath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VideoPlaceholder(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Upload exercise video',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a local workout video. Apex copies it into local storage before trimming.',
              style: TextStyle(color: c(context).muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final path = await videoPickerService.pickVideoPath();
                if (context.mounted) Navigator.pop(context, path ?? '');
              } catch (_) {
                if (context.mounted) Navigator.pop(context, '__picker_error__');
              }
            },
            child: const Text('Choose Video'),
          ),
        ],
      ),
    );
    if (!context.mounted || sourcePath == null) return;
    if (sourcePath == '__picker_error__') {
      toast(context, 'Could not open video picker.');
      return;
    }
    if (sourcePath.isEmpty) {
      toast(context, 'No video selected.');
      return;
    }
    try {
      final draft = await copyVideoToTemp(sourcePath);
      if (!mounted) return;
      await deleteFileIfExists(draftVideoTempPath);
      setState(() {
        videoName = draft.name;
        videoPath = draft.originalPath;
        videoOriginalPath = draft.originalPath;
        draftVideoTempPath = draft.tempPath;
        videoStoredPath = null;
        videoSizeBytes = draft.sizeBytes;
        videoImportedAt = draft.importedAt;
        clipStart = null;
        clipEnd = null;
      });
      _syncDraft(store);
      if (context.mounted) await _trimVideo(context);
    } on VideoUploadException catch (error) {
      if (mounted) toast(this.context, error.message);
    }
  }

  Future<void> _trimVideo(BuildContext context) async {
    if (!_hasUploadedVideo) {
      toast(context, 'Upload a video first.');
      return;
    }
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) {
        var start = clipStart ?? 0;
        var end = clipEnd ?? 15;
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Trim Video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (videoName != null) ...[
                  Text(
                    videoName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                ],
                VideoPlaceholder(
                  name: videoName,
                  start: start,
                  end: end,
                  uploaded: true,
                ),
                const SizedBox(height: 12),
                _trimStepper(
                  'Start',
                  start,
                  (value) => setDialogState(() {
                    start = value < 0 ? 0 : value;
                    error = null;
                  }),
                ),
                _trimStepper(
                  'End',
                  end,
                  (value) => setDialogState(() {
                    end = value < 0 ? 0 : value;
                    error = null;
                  }),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: end <= 0 ? 0 : (start / end).clamp(0, 1),
                  minHeight: 8,
                ),
                const SizedBox(height: 10),
                Text('Clip Length ${timeCode(end - start)}'),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final validation = trimValidationError(start, end);
                  if (validation != null) {
                    setDialogState(() => error = validation);
                    return;
                  }
                  Navigator.pop(context, (start, end));
                },
                child: const Text('Save Clip'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || !context.mounted) return;
    final store = StoreScope.of(context);
    setState(() {
      clipStart = result.$1;
      clipEnd = result.$2;
    });
    _syncDraft(store);
  }

  Widget _trimStepper(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(timeCode(value), style: const TextStyle(fontFamily: 'Inter')),
          const Spacer(),
          OutlinedButton(
            onPressed: () => onChanged(value - 1),
            child: const Text('-1s'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => onChanged(value + 1),
            child: const Text('+1s'),
          ),
        ],
      ),
    );
  }

  void _removeDraftVideo() {
    deleteFileIfExists(draftVideoTempPath);
    setState(() {
      videoName = null;
      videoPath = null;
      videoOriginalPath = null;
      videoStoredPath = null;
      draftVideoTempPath = null;
      videoSizeBytes = null;
      videoImportedAt = null;
      clipStart = null;
      clipEnd = null;
    });
    final store = StoreScope.of(context);
    _syncDraft(store);
  }
}

class ExerciseDetailsScreen extends StatelessWidget {
  const ExerciseDetailsScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final exercise = store.exerciseById(id);
    if (exercise == null) {
      return const ScreenPad(
        child: ScreenHeader(title: 'Exercise Missing', showBack: true),
      );
    }
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(title: exercise.title, showBack: true),
          VideoPlaceholder(
            name: exercise.videoName,
            start: exercise.clipStartSeconds,
            end: exercise.clipEndSeconds,
            uploaded: exercise.hasVideo,
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video file:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(exercise.hasVideo ? 'Uploaded' : 'No video'),
                if (exercise.videoName != null) Text(exercise.videoName!),
                if (exercise.videoStoredPath != null)
                  Text(
                    'Stored: ${exercise.videoStoredPath}',
                    style: TextStyle(color: c(context).muted, fontSize: 11),
                  ),
                if (exercise.clipStartSeconds != null &&
                    exercise.clipEndSeconds != null) ...[
                  Text(
                    'Clip ${timeCode(exercise.clipStartSeconds!)} -> ${timeCode(exercise.clipEndSeconds!)}',
                  ),
                  Text(
                    'Length ${timeCode(exercise.clipEndSeconds! - exercise.clipStartSeconds!)}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricTile(label: 'Sets', value: '${exercise.sets}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(label: 'Reps', value: '${exercise.reps}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(label: 'Weight', value: exercise.weight.g),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Rest',
                  value: '${exercise.restTimerSeconds}s',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exercise.category} / ${exercise.equipment} / ${exercise.difficulty}',
                ),
                const SizedBox(height: 8),
                Text(exercise.notes.isEmpty ? 'No notes yet.' : exercise.notes),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in exercise.tags) Chip(label: Text(tag)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Created ${dateOnly(exercise.createdAt)} / Modified ${dateOnly(exercise.modifiedAt)}',
                  style: TextStyle(color: c(context).muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'Edit',
                icon: Icons.edit,
                secondary: true,
                onPressed: () =>
                    store.navigate(AppRoute('exercise-edit', id: id)),
              ),
              AppButton(
                label: 'Duplicate',
                icon: Icons.copy,
                secondary: true,
                onPressed: () async {
                  final copy = await store.duplicateExercise(id);
                  if (copy != null) {
                    store.navigate(AppRoute('exercise-details', id: copy.id));
                  }
                },
              ),
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                secondary: true,
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Delete "${exercise.title}" and related logs?',
                  )) {
                    var deleteVideo = false;
                    if (context.mounted && exercise.hasVideo) {
                      deleteVideo = await confirmDeleteVideo(context);
                    }
                    await store.deleteExercise(id, deleteVideo: deleteVideo);
                    if (context.mounted) store.back();
                  }
                },
              ),
              AppButton(
                label: 'Start Logging',
                icon: Icons.fitness_center,
                onPressed: () => store.navigate(AppRoute('logging', id: id)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WorkoutLibraryScreen extends StatelessWidget {
  const WorkoutLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Workout Library',
            subtitle: 'User-created example workouts',
            trailing: IconButton.filled(
              tooltip: 'Create workout',
              onPressed: () => store.navigate(const AppRoute('workout-edit')),
              icon: const Icon(Icons.add),
            ),
          ),
          if (store.data.workouts.isEmpty)
            const AppCard(child: Text('No workouts yet.')),
          for (final workout in store.data.workouts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WorkoutListCard(workout: workout),
            ),
        ],
      ),
    );
  }
}

class WorkoutListCard extends StatelessWidget {
  const WorkoutListCard({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppCard(
      onTap: () => store.navigate(AppRoute('workout-builder', id: workout.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workout.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(workout.description, style: TextStyle(color: c(context).muted)),
          const SizedBox(height: 8),
          Text(
            '${workout.exerciseIds.length} exercises / Modified ${dateOnly(workout.modifiedAt)}',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key, this.id});

  final String? id;

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final name = TextEditingController();
  final description = TextEditingController();
  Workout? original;
  bool ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    original = widget.id == null
        ? null
        : StoreScope.of(context).workoutById(widget.id!);
    name.text = original?.name ?? '';
    description.text = original?.description ?? '';
    ready = true;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: widget.id == null ? 'Create Workout' : 'Edit Workout',
            showBack: true,
          ),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Workout Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Save Workout',
            icon: Icons.save_outlined,
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                toast(context, 'Workout name is required.');
                return;
              }
              final time = DateTime.now();
              final workout = Workout(
                id: original?.id ?? newId(),
                name: name.text.trim(),
                description: description.text.trim(),
                exerciseIds: original?.exerciseIds ?? [],
                createdAt: original?.createdAt ?? time,
                modifiedAt: time,
              );
              await store.upsertWorkout(workout);
              if (context.mounted) {
                store.navigate(AppRoute('workout-builder', id: workout.id));
              }
            },
          ),
        ],
      ),
    );
  }
}

class WorkoutBuilderScreen extends StatelessWidget {
  const WorkoutBuilderScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final workout = store.workoutById(id);
    if (workout == null) {
      return const ScreenPad(
        child: ScreenHeader(title: 'Workout Missing', showBack: true),
      );
    }
    final exercises = workout.exerciseIds
        .map(store.exerciseById)
        .whereType<ExerciseCard>()
        .toList();
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: workout.name,
            subtitle: 'Workout Builder',
            showBack: true,
          ),
          AppCard(
            child: Text(
              workout.description.isEmpty
                  ? 'Blank workout container.'
                  : workout.description,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Add Exercises',
            icon: Icons.add,
            secondary: true,
            onPressed: () => _addExercise(context, workout),
          ),
          const SizedBox(height: 12),
          if (exercises.isEmpty)
            const AppCard(child: Text('No exercises in this workout yet.')),
          for (var i = 0; i < workout.exerciseIds.length; i++)
            _WorkoutExerciseRow(workout: workout, index: i),
          const SizedBox(height: 12),
          AppButton(
            label: 'Start Workout',
            icon: Icons.play_arrow,
            onPressed: exercises.isEmpty
                ? null
                : () => store.navigate(
                    AppRoute(
                      'logging',
                      id: exercises.first.id,
                      workoutId: workout.id,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise(BuildContext context, Workout workout) async {
    final store = StoreScope.of(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Exercise'),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final exercise in store.data.exercises)
                ListTile(
                  title: Text(exercise.title),
                  subtitle: Text(exercise.category),
                  onTap: () => Navigator.pop(context, exercise.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await store.upsertWorkout(
      workout.copyWith(exerciseIds: [...workout.exerciseIds, picked]),
    );
  }
}

class _WorkoutExerciseRow extends StatelessWidget {
  const _WorkoutExerciseRow({required this.workout, required this.index});

  final Workout workout;
  final int index;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final id = workout.exerciseIds[index];
    final exercise = store.exerciseById(id);
    final title = exercise?.title ?? 'Missing exercise';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${index + 1}. $title',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Move up',
              onPressed: index == 0
                  ? null
                  : () => _move(store, index, index - 1),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: index == workout.exerciseIds.length - 1
                  ? null
                  : () => _move(store, index, index + 1),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'Duplicate in workout',
              onPressed: () {
                final ids = [...workout.exerciseIds]..insert(index + 1, id);
                store.upsertWorkout(workout.copyWith(exerciseIds: ids));
              },
              icon: const Icon(Icons.copy),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: () {
                final ids = [...workout.exerciseIds]..removeAt(index);
                store.upsertWorkout(workout.copyWith(exerciseIds: ids));
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  void _move(AppStore store, int from, int to) {
    final ids = [...workout.exerciseIds];
    final item = ids.removeAt(from);
    ids.insert(to, item);
    store.upsertWorkout(workout.copyWith(exerciseIds: ids));
  }
}

class ExerciseLoggingScreen extends StatefulWidget {
  const ExerciseLoggingScreen({super.key, required this.id, this.workoutId});

  final String id;
  final String? workoutId;

  @override
  State<ExerciseLoggingScreen> createState() => _ExerciseLoggingScreenState();
}

class _ExerciseLoggingScreenState extends State<ExerciseLoggingScreen> {
  final weight = TextEditingController();
  final reps = TextEditingController();
  final notes = TextEditingController();
  final sets = <LoggedSet>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final exercise = StoreScope.of(context).exerciseById(widget.id);
    weight.text = weight.text.isEmpty
        ? '${exercise?.weight ?? 0}'
        : weight.text;
    reps.text = reps.text.isEmpty ? '${exercise?.reps ?? 10}' : reps.text;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final exercise = store.exerciseById(widget.id);
    if (exercise == null) {
      return const ScreenPad(
        child: ScreenHeader(title: 'Exercise Missing', showBack: true),
      );
    }
    final nextSet = sets.length + 1;
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: exercise.title,
            subtitle: 'Exercise Logging',
            showBack: true,
          ),
          VideoPlaceholder(
            name: exercise.videoName,
            start: exercise.clipStartSeconds,
            end: exercise.clipEndSeconds,
            uploaded: exercise.hasVideo,
          ),
          const SizedBox(height: 16),
          Text(
            'Set $nextSet',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: weight,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Add Set',
            icon: Icons.add,
            secondary: true,
            onPressed: () {
              setState(() {
                sets.add(
                  LoggedSet(
                    setNumber: nextSet,
                    weight: double.tryParse(weight.text.trim()) ?? 0,
                    reps: int.tryParse(reps.text.trim()) ?? 0,
                    completed: true,
                  ),
                );
              });
            },
          ),
          const SizedBox(height: 12),
          for (final set in sets)
            Text(
              'Set ${set.setNumber}: ${set.weight.g} kg x ${set.reps}',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Done',
            icon: Icons.check,
            onPressed: () async {
              final finalSets = sets.isEmpty
                  ? [
                      LoggedSet(
                        setNumber: 1,
                        weight: double.tryParse(weight.text.trim()) ?? 0,
                        reps: int.tryParse(reps.text.trim()) ?? 0,
                        completed: true,
                      ),
                    ]
                  : sets;
              await store.addLog(
                WorkoutLog(
                  id: newId(),
                  workoutId: widget.workoutId,
                  exerciseId: widget.id,
                  date: DateTime.now(),
                  sets: finalSets,
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                ),
              );
              if (context.mounted) {
                store.navigate(AppRoute('history', id: widget.id));
              }
            },
          ),
        ],
      ),
    );
  }
}

class ExerciseHistoryScreen extends StatelessWidget {
  const ExerciseHistoryScreen({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final logs = store.data.logs
        .where((log) => id == null || log.exerciseId == id)
        .toList();
    final pb = personalBest(logs);
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Exercise History',
            subtitle: pb == null
                ? 'No personal best yet'
                : 'PB ${pb.weight.g} kg x ${pb.reps}',
            showBack: id != null,
          ),
          if (logs.isEmpty) const AppCard(child: Text('No logs yet.')),
          for (final log in logs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store.exerciseById(log.exerciseId)?.title ?? 'Deleted exercise'} / ${dateOnly(log.date)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    for (final set in log.sets)
                      Text(
                        'Set ${set.setNumber}: ${set.weight.g} kg x ${set.reps}',
                        style: const TextStyle(fontFamily: 'Inter'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

LoggedSet? personalBest(List<WorkoutLog> logs) {
  LoggedSet? best;
  for (final log in logs) {
    for (final set in log.sets) {
      if (best == null ||
          set.weight > best.weight ||
          (set.weight == best.weight && set.reps > best.reps)) {
        best = set;
      }
    }
  }
  return best;
}

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(title: 'Export / Import', showBack: true),
          AppButton(
            label: 'Export JSON',
            icon: Icons.data_object,
            onPressed: () =>
                _write(context, 'apex_export.json', store.data.encodePretty()),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Export Markdown',
            icon: Icons.description_outlined,
            onPressed: () =>
                _write(context, 'apex_export.md', exportMarkdown(store.data)),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Export Backup',
            icon: Icons.backup_outlined,
            onPressed: () =>
                _write(context, 'apex_backup.json', store.data.encodePretty()),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Import Backup',
            icon: Icons.file_download_outlined,
            secondary: true,
            onPressed: () => _import(context, store),
          ),
        ],
      ),
    );
  }

  Future<void> _write(
    BuildContext context,
    String fileName,
    String content,
  ) async {
    final target = await _fallbackPath(fileName);
    await File(target).writeAsString(content);
    if (context.mounted) toast(context, 'Saved $target');
  }

  Future<String> _fallbackPath(String fileName) async {
    final dir = Directory(
      '${Directory.current.path}${Platform.pathSeparator}.apex_data${Platform.pathSeparator}exports',
    );
    await dir.create(recursive: true);
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  Future<void> _import(BuildContext context, AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Backup JSON path'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (picked == null || picked.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Import cancelled.')),
      );
      return;
    }
    try {
      final raw = await File(picked).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || !isValidBackup(decoded)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Backup file is not valid Apex data.')),
        );
        return;
      }
      await store.importBackup(AppData.fromJson(decoded));
      messenger.showSnackBar(const SnackBar(content: Text('Backup imported.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup import failed.')),
      );
    }
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final bytes = utf8.encode(store.data.encodePretty()).length;
    final profile = store.data.profile;
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeader(title: 'Settings'),
          if (profile != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('Gender: ${profile.gender}'),
                  Text('Birthday: ${dateOnly(profile.birthDate)}'),
                  Text('Age: ${profile.age}'),
                  Text('Height: ${profile.height}'),
                  Text('Current Weight: ${profile.weight}'),
                  Text('Experience: ${profile.experienceLevel}'),
                  Text(
                    'Weight History: ${profile.weightHistory.length} entries',
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Edit Profile',
                    icon: Icons.person_outline,
                    secondary: true,
                    onPressed: () =>
                        store.navigate(const AppRoute('profile-edit')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: store.data.settings.darkMode,
            onChanged: (value) => store.updateSettings(darkMode: value),
          ),
          _label('Font Size'),
          Wrap(
            spacing: 8,
            children: ['compact', 'comfort', 'large']
                .map(
                  (item) => AppChip(
                    label: item,
                    active: store.data.settings.fontSize == item,
                    onTap: () => store.updateSettings(fontSize: item),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Text(
              'Storage Usage: ${(bytes / 1024).toStringAsFixed(1)} KB',
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              'Backup Settings: JSON backup includes profile, settings, cards, workouts, and logs.',
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Reset Demo Data',
            icon: Icons.refresh,
            secondary: true,
            onPressed: () async {
              if (await confirm(
                context,
                'Reset seeded examples and keep profile?',
              )) {
                await store.resetDemoData();
              }
            },
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Clear All Local Data',
            icon: Icons.delete_forever,
            secondary: true,
            onPressed: () async {
              if (await confirm(
                context,
                'Clear all local data and return to onboarding?',
              )) {
                await store.clearAll();
              }
            },
          ),
        ],
      ),
    );
  }
}
