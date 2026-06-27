# Apex Windows QA Report

## Scope

Phase 1.1B onboarding UX upgrade for the Flutter Windows app only.

## Commands

```powershell
& 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\cache\dart-sdk\bin\dart.exe' format .
$env:GIT_CONFIG_GLOBAL='C:\Users\DANTE\Downloads\workout\Apex\workout-clip-planner\flutter_app\.flutter_gitconfig'; & 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat' analyze
$env:GIT_CONFIG_GLOBAL='C:\Users\DANTE\Downloads\workout\Apex\workout-clip-planner\flutter_app\.flutter_gitconfig'; & 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat' test
$env:GIT_CONFIG_GLOBAL='C:\Users\DANTE\Downloads\workout\Apex\workout-clip-planner\flutter_app\.flutter_gitconfig'; & 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat' build windows
```

## Results

- Format: passed.
- Analyze: passed, no issues found.
- Tests: passed, 28 tests.
- Windows build: passed.

## Build Artifact

`flutter_app\build\windows\x64\runner\Release\apex.exe`

The full `Release` folder should be used when running or sharing the Windows build.

## Notes

The first build attempt found a stale generated CMake cache from a previous checkout path. Only `flutter_app\build\windows` was cleared, then the build succeeded.
