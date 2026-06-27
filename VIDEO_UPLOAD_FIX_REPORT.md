# Phase 1.2 - Video Upload Fix Report

## Bug

Create Exercise -> Upload Video showed a manual path form:

- `Local video file path`
- `Paste a Windows video path`

That did not behave like a real user upload flow.

## Cause

The app already had temp/originals copy helpers and trim metadata, but `_uploadVideo` still used a text field dialog instead of opening a Windows picker.

## Fix

- Replaced visible manual path input with a clean `Upload Video` dialog.
- `Choose Video` now calls a testable `VideoPickerService`.
- Production picker uses a hardcoded Windows PowerShell/.NET `OpenFileDialog`.
- Successful selection copies the file into Apex temp storage.
- Trimmer opens automatically after upload.
- Removed normal-user manual path UX.
- Markdown export now includes video file, stored path, clip range, and clip length.

## File Picker Package Used

None.

`file_selector` was considered first, but dependency resolution was initially blocked by the environment. The final implementation avoids plugin/symlink/Developer Mode risk by using the local Windows `.NET OpenFileDialog` through a hardcoded PowerShell command.

## Storage Path

`flutter_app\.apex_data\videos\`

## Temp File Behavior

Selected files copy to:

`flutter_app\.apex_data\videos\temp\exercise_draft_<timestamp>_<original_name>`

## Permanent File Behavior

Saved exercises move/copy the temp file into:

`flutter_app\.apex_data\videos\originals\`

The app also ensures:

`flutter_app\.apex_data\videos\clips\`

exists for future physical clip cutting.

## Trimmer Behavior

After upload, the trim dialog opens automatically with default clip range:

`00:00 -> 00:15`

The trimmer validates negative start, end before start, and minimum one-second clip length.

## Remaining Limitations

- Real physical video cutting is still deferred; Apex stores clip metadata for now.
- Full native GUI click-through of the file picker was not automated. Verified by picker-service widget test, real-video service workflow test, and Windows app launch.
