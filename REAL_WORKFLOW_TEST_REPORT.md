# Phase 1.2 - Real Workflow Test Report

## Videos Used

The test scanned actual category folders under:

`C:\Users\DANTE\Downloads\workout\Apex\workout-clip-planner\material for test`

Verified by service-level workflow test:

- Warmup: `DO THIS Before Every Workout (5 MIN Warm Up).mp4`
- Chest: `Best Dumbbell Bench Press Tutorial Ever Made.mp4`
- Back: `Seated Cable Row - Full Video Tutorial & Exercise Guide.mp4` or the matching existing Seated Cable Row file variant in the Back folder

The test chooses real existing files by category and substring, so dash/special-character filename differences do not break the workflow.

## Exercise Cards Created

Verified by service-level test:

- `Upper Body Warm Up`
- `Incline Dumbbell Chest Press`
- `Seated Cable Row`

## Clip Ranges Selected

- Warmup: `00:05 -> 00:25`
- Chest: `00:05 -> 00:22`
- Back: `00:08 -> 00:28`

## Workout Created

`Test Workout - Video Flow`

## Logging Completed

Verified by service-level test:

- Warmup: `0 kg x 1`
- Chest: `12.5 kg x 10`, two sets
- Back: `35 kg x 12`, two sets

## History Verified

Workout logs were inserted and asserted in the service-level workflow test.

## Exports Verified

- JSON export includes `videoStoredPath`, `clipStartSeconds`, and `clipEndSeconds`.
- Markdown export includes created exercises, video stored path, and clip range.

## Bugs Found

- Manual path input was visible in normal upload UX.
- Markdown export did not explicitly include video metadata.
- Real file I/O inside `testWidgets` can hang under fake async.

## Bugs Fixed

- Replaced manual path upload UI with real Windows picker service.
- Added auto-open trimmer after video selection.
- Added Markdown video metadata.
- Moved real file workflow into safe service-level test.
- Added ignore rules for test material, runtime videos, exports, build outputs, Android scaffold, and local analyzer cache.

## Unverified Items

- Full native GUI file-picker click-through was not automated. The Windows app was launched and `apex.exe` was observed, but the picker itself was verified through service/fake test rather than GUI automation.
