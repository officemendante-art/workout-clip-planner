# Apex Data Schema

## Schema Version

Current schema version: `2`

## UserProfile

Profile data remains local and JSON-backed.

- `gender`: string
- `birthDate`: ISO date string
- `heightCm`: canonical integer height in centimeters
- `heightDisplayUnit`: `cm` or `ft_in`
- `weightKg`: canonical double weight in kilograms
- `weightDisplayUnit`: `kg` or `lb`
- `experienceLevel`: `Beginner`, `Intermediate`, or `Advanced`
- `createdAt`: ISO timestamp
- `modifiedAt`: ISO timestamp
- `lastWeightPromptAt`: optional ISO timestamp
- `weightHistory`: list of `WeightEntry`

## WeightEntry

- `id`: string
- `weightKg`: canonical double kilograms
- `date`: ISO timestamp
- `source`: `onboarding`, `manual`, or `monthly_prompt`

## Migration Notes

Older profile data with manual `age`, text height, or text weight is still migrated into schema v2 fields. Legacy weight history gaps are backfilled with a single manual entry so current weight is not lost.

## Derived Values

- Age is derived from `birthDate` and the local device date.
- BMI is derived at runtime from `heightCm` and `weightKg`.
- Height and weight unit displays are preferences only; canonical storage remains cm/kg.
