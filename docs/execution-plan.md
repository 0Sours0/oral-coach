# Execution Plan

## Phase 0: Environment Check ✅
- macOS, Xcode, Node.js, npm, Git, EAS CLI verified

## Phase 1: Project Initialization ✅
- Expo SDK 54 + TypeScript + Expo Router
- Directory structure per DEV_SPEC.md §7
- All type definitions, placeholder modules
- docs/CLAUDE.md, .env, .gitignore

## Phase 2: Local Database & Settings (TODO)
- Implement storage/db.ts schema init
- sessionRepository, messageRepository, settingsRepository
- useSettings hook

## Phase 3: Conversation UI + Context Build (TODO)
- ConversationScreen with message list
- buildPromptContext, selectRecentMessages
- Stub chat flow (no real API yet)

## Phase 4: Learning Records UI (TODO)
- RecordsScreen, RecordDetailScreen
- learningRecordRepository with search
- LearningCard, SearchBar components

## Phase 5: ASR — Whisper Integration (TODO)
- Requires real device (iPhone 17 Pro Max)
- useRecorder hook with expo-av
- asrService.ts → Whisper API

## Phase 6: TTS — OpenAI TTS Integration (TODO)
- ttsService.ts → OpenAI TTS API
- useAudioPlayer hook

## Phase 7: Full End-to-End Flow (TODO)
- Wire ASR → DeepSeek → TTS
- Summary trigger (>20 messages)
- Polish & testing
