# Swift Migration Team Guide

## Mission
- Replace the React Native / Expo app with a fully native iOS app implemented in Swift and SwiftUI.
- Preserve the existing product behavior:
  - one shared persona layer
  - one shared relationship-memory layer
  - `realtime_call` and `voice_message` as two modes of the same product
  - English-correction behavior as a secondary trait, not the character identity
- Move the app toward a native-first architecture under `ios/oralcoach/NativeApp`.

## Current State
- Native entry wiring exists in:
  - `ios/oralcoach/AppDelegate.swift`
  - `ios/oralcoach/NativeMigrationShell.swift`
- Native scaffold exists in:
  - `ios/oralcoach/NativeApp/Domain`
  - `ios/oralcoach/NativeApp/Persistence`
  - `ios/oralcoach/NativeApp/Views`
- Deployment target is `iOS 17.0`.
- React Native code is still the source of truth for most business logic.

## Non-Negotiable Rules
- Use Swift / SwiftUI for new product code.
- Keep edits inside owned files or directories whenever possible.
- Do not revert unrelated user changes.
- Do not touch the legacy TS app unless explicitly required for reference or parity checks.
- Keep the native data contract aligned with the current RN schema unless the migration lead changes it.
- Treat personas as primary identity. Teaching behavior is secondary.
- Shared memory and records must be global across both modes.

## Target Native Architecture
- `NativeApp/App`
  - app shell, tabs, navigation, feature flags
- `NativeApp/Domain`
  - models, enums, DTOs, schema constants
- `NativeApp/Persistence`
  - SQLite manager, repositories, seed importers, settings storage
- `NativeApp/Services`
  - DeepSeek client
  - ASR client
  - TTS client
  - realtime speech adapter
  - summary / metadata / memory update services
- `NativeApp/Prompting`
  - persona contract builder
  - context assembly
  - teacher / memory / metadata prompt builders
- `NativeApp/Features/Conversation`
  - chat thread, composer, mode switch, realtime state, voice-message state
- `NativeApp/Features/Records`
  - records list, record detail, search / filtering
- `NativeApp/Features/Settings`
  - settings form, persona picker, language policy

## Source Mapping
- `storage/*.ts` -> `NativeApp/Persistence/*`
- `services/*.ts` -> `NativeApp/Services/*`
- `constants/prompts.ts` + `context/*.ts` -> `NativeApp/Prompting/*`
- `hooks/useConversation.ts` -> `NativeApp/Features/Conversation/VoiceMessage*`
- `hooks/useRealtimeConversation.ts` -> `NativeApp/Features/Conversation/Realtime*`
- `hooks/useSettings.ts` + `storage/settingsRepository.ts` -> `NativeApp/Features/Settings/*`
- `hooks/useLearningRecords.ts` + `app/(tabs)/records.tsx` + `app/record-detail.tsx` -> `NativeApp/Features/Records/*`

## Workstream Contracts

### Workstream A: Persistence
- Owns:
  - `ios/oralcoach/NativeApp/Domain/*`
  - `ios/oralcoach/NativeApp/Persistence/*`
- Deliver:
  - real SQLite-backed persistence using `SQLite3`
  - repository implementations for sessions, messages, summaries, personas, relationship memory, learning records
  - persona seed bootstrap
  - settings storage bridge

### Workstream B: Prompting + Networking
- Owns:
  - `ios/oralcoach/NativeApp/Prompting/*`
  - `ios/oralcoach/NativeApp/Services/*`
  - shared DTOs added under `Domain` if needed
- Deliver:
  - DeepSeek request / stream client
  - prompt builders equivalent to TS behavior
  - metadata extraction and relationship-memory update services
  - summary generation service
  - TTS / ASR service interfaces and first implementations

### Workstream C: Conversation Feature
- Owns:
  - `ios/oralcoach/NativeApp/Features/Conversation/*`
  - chat-specific view-model glue currently under `Views/*`
- Deliver:
  - one native conversation thread
  - shared messages list for both modes
  - voice-message pipeline state machine
  - realtime-call state machine shell
  - integration with persistence + services

### Workstream D: Records + Settings
- Owns:
  - `ios/oralcoach/NativeApp/Features/Records/*`
  - `ios/oralcoach/NativeApp/Features/Settings/*`
  - tab shell adjustments needed to host those features
- Deliver:
  - native records list
  - record detail
  - native settings
  - persona selection and language-policy controls

## Integration Rules
- Prefer additive moves from scaffold to real modules.
- If replacing a scaffold file, keep external API stable unless there is a strong reason.
- If you add a new Swift file, note whether it must be added to `project.pbxproj`.
- Always mention the files you changed in the handoff.
- If you compile locally, report exact command and result.

## Definition Of Done
- Native tab shell is the default root, not RN.
- Conversation, records, and settings run fully natively.
- `voice_message` uses native persistence and native service orchestration.
- `realtime_call` uses native persistence and a native realtime adapter.
- Persona, memory, summary, and learning-record flows are native.
- Project builds successfully with Xcode for `iOS 17.0+`.
