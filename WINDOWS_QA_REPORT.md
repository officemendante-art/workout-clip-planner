# Apex Windows QA Report

## Phase 1.2 Scope

Real video upload and workflow testing for the Flutter Windows app only.

## Commands Run

```powershell
& $Flutter pub get
& $Dart format lib\main.dart test\apex_test.dart
$env:LOCALAPPDATA='...\workout-clip-planner\.localappdata'; & $Dart analyze lib\main.dart test\apex_test.dart
& $Flutter analyze
& $Flutter test --no-pub
& $Flutter build windows --no-pub
& $Flutter run -d windows --no-pub
```

## Results

- Format: passed.
- Pub get: passed.
- Partial Dart analyze: passed, no issues found.
- Flutter analyze: passed, no issues found.
- Flutter tests: passed, 29 tests.
- Windows build: passed.
- Flutter run: launched and `apex.exe` process was observed; stopped cleanly after timeout.

## Build Artifact

`flutter_app\build\windows\x64\runner\Release\apex.exe`

Use the full `Release` folder as the runnable Windows artifact.

## Current QA Status

Accepted with one caveat: native file picker GUI click-through was not automated. The picker service was tested with a fake picker, real video copy/workout/log/export was tested with actual local files, and the Windows app launch was confirmed.
