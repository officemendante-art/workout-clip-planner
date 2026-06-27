# Phase 1.2 - Video Automated Test Report

## Tests Added

- Upload modal has no manual path input.
- Upload modal shows `Choose Video`.
- Fake picker service is called when `Choose Video` is tapped.
- Cancelled picker shows `No video selected.` and leaves no selected video state.
- Valid selected video copies into temp folder through service-level helpers.
- Saved exercise stores `clipStartSeconds` and `clipEndSeconds`.
- Saving exercise moves video into originals folder.
- Removing draft video deletes temp file.
- Real material videos are selected from existing category folders.
- Real videos can become exercise cards, workout, logs, and JSON/Markdown exports.

## Commands Run

```powershell
& $Flutter pub get
& $Dart format lib\main.dart test\apex_test.dart
$env:LOCALAPPDATA='...\workout-clip-planner\.localappdata'; & $Dart analyze lib\main.dart test\apex_test.dart
& $Flutter analyze
& $Flutter test --no-pub
& $Flutter build windows --no-pub
```

## Pass/Fail

- `flutter pub get`: passed.
- `dart format`: passed.
- Partial `dart analyze`: passed.
- `flutter analyze`: passed, no issues found.
- `flutter test --no-pub`: passed, 29 tests.
- `flutter build windows --no-pub`: passed.

## Failures Fixed

- Removed package-based picker dependency to avoid plugin/symlink risk.
- Moved real file I/O out of widget tests and into service-level tests because `testWidgets` fake async can hang on direct file system awaits.

## Remaining Test Gaps

- Native Windows file picker GUI was not click-automated end to end.
- Verified picker invocation by service/fake widget test and verified real file workflow by service-level test using actual local videos.
