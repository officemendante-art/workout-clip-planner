# Phase 1.2 - Video Storage Report

## Summary

Video storage remains local-first under `flutter_app\.apex_data\videos`.

## Temp Storage

Selected files copy to:

`videos\temp\exercise_draft_<timestamp>_<original_name>`

## Originals Storage

Saved exercise cards move/copy draft files to:

`videos\originals\`

## Clips Storage

The app ensures this folder exists for later physical clip export:

`videos\clips\`

## Cleanup

- Unsaved draft temp videos are deleted on editor dispose.
- Remove Video deletes draft temp video.
- Save Exercise clears the temp draft path after moving to originals.
- Delete Exercise keeps the existing `Delete attached local video too?` prompt.

## Verification Status

Verified by Flutter tests:

- `video upload helpers validate, copy temp, and migrate legacy path`
- `real material videos can become cards, workout, logs, and exports`
- `removing draft video deletes temp file`
