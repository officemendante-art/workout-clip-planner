# Apex Final Windows Acceptance Report

## Summary

The Apex Phase 1.1B onboarding UX upgrade is implemented in the Flutter Windows app. The first-run profile setup now behaves like a real app flow instead of a flat form.

## Accepted Changes

- Old flat profile form replaced.
- Birthday-based automatic age added.
- Height supports cm and ft & in.
- Weight supports kg and lbs.
- BMI estimate added as a neutral rough tracking insight.
- Weight history is preserved.
- Monthly weight prompt is preserved.
- Save Profile navigation to visible Home UI is tested.
- Settings profile editor remains available and updates profile data.

## Verification

- `dart format .`: passed.
- `flutter analyze`: passed.
- `flutter test`: passed, 28 tests.
- `flutter build windows`: passed.

## Windows Build

Built artifact:

`flutter_app\build\windows\x64\runner\Release\apex.exe`

Use the complete `Release` folder as the runnable Windows deliverable.

## Not Included

- Android work was not started.
- Full UI redesign was not performed.
- Deep video polishing was not started.

## Current Status

Accepted for this Phase 1.1B Windows onboarding pass.
