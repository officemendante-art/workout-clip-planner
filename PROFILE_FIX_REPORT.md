# Apex Profile Fix Report

## Summary

The profile setup bug area was retested after replacing the flat form with the step-based onboarding flow. Save Profile now completes through the review step and navigates to visible Home UI.

## Changes

- Replaced one-screen profile setup with Welcome -> Gender -> Birthday -> Height -> Weight -> Experience -> Review.
- Removed manual age entry; age is calculated from birthday.
- Added cm and ft & in height input while storing canonical `heightCm`.
- Added kg and lbs weight input while storing canonical `weightKg`.
- Added neutral BMI estimate as a rough profile marker.
- Preserved weight history and monthly weight prompt behavior.
- Settings profile summary now shows gender, birthday, age, height, current weight, experience, Edit Profile, and Weight History count.

## Save Profile Verification

Widget test `Onboarding saves profile and opens Home` now drives the full onboarding flow, taps Save Profile on review, verifies `store.route.name == 'home'`, verifies visible `Create Exercise`, and verifies the onboarding weight entry source is `onboarding`.

## Result

Profile setup is no longer a flat form and the original Save Profile navigation path is still covered by tests.
