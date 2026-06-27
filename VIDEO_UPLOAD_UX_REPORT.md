# Phase 1.2 - Video Upload UX Report

## Summary

The normal Create Exercise video upload surface no longer uses visible manual path entry.

## UX Changes

- Upload dialog title: `Upload Video`
- Primary action: `Choose Video`
- Cancel action: `Cancel`
- Upload card copy: `Upload exercise video`
- Supported formats shown: `MP4, MOV, MKV, WEBM, AVI`
- Empty state remains: `No video uploaded yet`
- Uploaded state remains: `Video uploaded`, filename, `Stored locally`
- Trimmed state remains: `Clip saved`, clip range, clip length

## Removed From Normal UX

- `Local video file path`
- `Paste a Windows video path`

## Verification Status

Verified by Flutter widget test:

`Create Exercise video section uses upload wording`
