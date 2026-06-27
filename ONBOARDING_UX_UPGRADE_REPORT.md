# Apex Phase 1.1B Onboarding UX Upgrade Report

## Summary

The old flat profile form has been replaced with a focused step-by-step onboarding flow:

Welcome -> Gender -> Birthday -> Height -> Weight -> Experience -> Review / Save Profile

The flow keeps Apex monochrome, local-first, and minimal. It does not start Android work, does not introduce account/cloud behavior, and does not rebuild the app from scratch.

## New Onboarding Flow

- Welcome screen: Apex, personal workout card library, local-only storage message.
- Gender step: Male, Female, Other, Prefer not to say.
- Birthday step: day/month/year inputs with calculated age preview.
- Height step: unit toggle for cm and ft & in.
- Weight step: unit toggle for kg and lbs plus a neutral BMI estimate.
- Experience step: Beginner, Intermediate, Advanced.
- Review step: gender, birthday, age, height, weight, experience, and BMI before Save Profile.

## Height System

The UI supports both cm and ft & in. Internally, Apex stores canonical `heightCm`.

Helpers:

- `feetInchesToCm(int feet, int inches)`
- `cmToFeetInches(int cm)`

Validation blocks unreasonable values before Continue.

## Weight System

The UI supports both kg and lbs. Internally, Apex stores canonical `weightKg`.

Helpers:

- `poundsToKg(double pounds)`
- `kgToPounds(double kg)`

First onboarding save creates a weight history entry with `source: "onboarding"`. Profile edits that change weight append a new history entry and do not delete old entries.

## Auto Age

Manual age entry was removed. Age now comes from birthday using the local device date. Invalid, future, and unrealistic ages are blocked with calm visible text.

## BMI Insight

The weight step shows a neutral BMI estimate when height and weight are valid:

`BMI estimate: 25.1`

The copy says it is only a rough profile marker. No medical or program-generator language was added.

## Tests

Added/updated tests cover:

- Onboarding starts at Welcome.
- Gender selection enables Continue.
- Birthday valid date calculates age preview.
- Birthday invalid date blocks Continue.
- Height ft & in saves canonical `heightCm`.
- Weight lbs saves canonical `weightKg`.
- BMI helper calculates correctly.
- Review screen displays profile summary.
- Save Profile navigates to visible Home UI.
- Restart opens Home when a profile exists.
- Edit Profile updates height and weight.
- Weight edit adds history entry.
- Monthly weight prompt still appears and skip still works.

## Commands Run

```powershell
& 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\cache\dart-sdk\bin\dart.exe' format .
$env:GIT_CONFIG_GLOBAL='C:\Users\DANTE\Downloads\workout\Apex\workout-clip-planner\flutter_app\.flutter_gitconfig'; & 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat' analyze
$env:GIT_CONFIG_GLOBAL='C:\Users\DANTE\Downloads\workout\Apex\workout-clip-planner\flutter_app\.flutter_gitconfig'; & 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat' test
$env:GIT_CONFIG_GLOBAL='C:\Users\DANTE\Downloads\workout\Apex\workout-clip-planner\flutter_app\.flutter_gitconfig'; & 'C:\Users\DANTE\Downloads\AYAXPY~1\tools\flutter\bin\flutter.bat' build windows
```

## Windows Build

Build succeeded:

`flutter_app\build\windows\x64\runner\Release\apex.exe`

The full `Release` folder is the runnable Windows artifact.

## Remaining Issues

- Android was intentionally not started.
- Deeper video polishing was intentionally not started.

## Current Status

Phase 1.1B onboarding UX upgrade is implemented, formatted, analyzed, tested, and built for Windows.
