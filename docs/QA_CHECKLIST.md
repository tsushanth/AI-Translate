# QA Checklist - AI Translate iOS App

## Overview

This document provides comprehensive test cases for the AI Translate iOS app. All tests should be performed on:
- Physical device (iPhone) - Required for speech recognition
- iOS Simulator - Limited functionality
- Multiple iOS versions (17.0, 17.4, 18.0+)

---

## 1. Translation Feature Tests

### 1.1 Basic Translation

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| T-001 | Simple text translation | 1. Enter "Hello" in source field<br>2. Select English → Spanish<br>3. Tap Translate | Displays "Hola" in translation field | |
| T-002 | Long text translation | 1. Enter 500+ character text<br>2. Tap Translate | Text translates without truncation | |
| T-003 | Maximum length (5000 chars) | 1. Enter exactly 5000 characters<br>2. Tap Translate | Translation succeeds | |
| T-004 | Exceed maximum length | 1. Enter 5001+ characters<br>2. Tap Translate | Shows validation error | |
| T-005 | Empty text translation | 1. Leave source empty<br>2. Tap Translate | Button disabled or shows error | |
| T-006 | Whitespace-only text | 1. Enter only spaces/newlines<br>2. Tap Translate | Treated as empty, no translation | |
| T-007 | Special characters | 1. Enter "Hello! @#$% 123"<br>2. Translate | Special chars preserved in output | |
| T-008 | Emoji translation | 1. Enter "I love pizza 🍕"<br>2. Translate | Emoji preserved, text translated | |
| T-009 | RTL language (Arabic) | 1. Translate to Arabic<br>2. View result | Text displays right-to-left | |
| T-010 | RTL language (Hebrew) | 1. Translate to Hebrew<br>2. View result | Text displays right-to-left | |

### 1.2 Language Detection

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| T-011 | Auto-detect English | 1. Set source to "Detect"<br>2. Enter English text<br>3. Translate | Detects "English", translates correctly | |
| T-012 | Auto-detect Spanish | 1. Set source to "Detect"<br>2. Enter "Hola mundo"<br>3. Translate | Detects "Spanish" | |
| T-013 | Auto-detect Chinese | 1. Set source to "Detect"<br>2. Enter "你好"<br>3. Translate | Detects "Chinese" | |
| T-014 | Mixed language text | 1. Enter "Hello 你好 Bonjour"<br>2. Translate with auto-detect | Detects primary language | |

### 1.3 Language Selection

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| T-015 | Change source language | 1. Tap source language picker<br>2. Select French | Picker updates, shows French | |
| T-016 | Change target language | 1. Tap target language picker<br>2. Select German | Picker updates, shows German | |
| T-017 | Swap languages | 1. Select EN → ES<br>2. Translate "Hello"<br>3. Tap swap button | Languages swap, text swaps | |
| T-018 | Swap with auto-detect | 1. Use auto-detect for source<br>2. Get translation<br>3. Tap swap | Uses detected language for swap | |
| T-019 | Search languages | 1. Open language picker<br>2. Type "Span" | Filters to show Spanish | |
| T-020 | Same source/target | 1. Select Spanish → Spanish<br>2. Translate | Returns same text or shows warning | |

### 1.4 Translation State

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| T-021 | Loading indicator | 1. Enter text<br>2. Tap Translate<br>3. Observe UI | Shows loading spinner | |
| T-022 | Cancel in-flight translation | 1. Start translation<br>2. Clear text immediately | Previous request cancelled | |
| T-023 | Rapid successive translations | 1. Translate "A"<br>2. Immediately translate "B" | Only shows result for "B" | |
| T-024 | Clear button | 1. Enter text and translate<br>2. Tap Clear | Both fields cleared | |

---

## 2. Text-to-Speech (TTS) Tests

### 2.1 Basic TTS

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| TTS-001 | Speak English translation | 1. Translate to English<br>2. Tap speaker button | Speaks in English voice | |
| TTS-002 | Speak Spanish translation | 1. Translate to Spanish<br>2. Tap speaker button | Speaks in Spanish voice | |
| TTS-003 | Speak Chinese translation | 1. Translate to Chinese<br>2. Tap speaker button | Speaks in Chinese voice | |
| TTS-004 | Speak Arabic translation | 1. Translate to Arabic<br>2. Tap speaker button | Speaks in Arabic voice | |
| TTS-005 | Stop speaking | 1. Start TTS<br>2. Tap speaker button again | Speech stops immediately | |
| TTS-006 | Speak empty text | 1. Without translation<br>2. Try to tap speaker | Button disabled | |
| TTS-007 | Long text TTS | 1. Translate 1000+ chars<br>2. Tap speaker | Speaks entire text | |
| TTS-008 | TTS with numbers | 1. Translate "I have 123 apples"<br>2. Speak | Numbers spoken correctly | |

### 2.2 TTS Edge Cases

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| TTS-009 | TTS during recording | 1. Start voice input<br>2. Tap speaker for existing translation | Recording stops, TTS plays | |
| TTS-010 | Interrupt TTS with new | 1. Start TTS<br>2. Translate new text<br>3. Tap speaker | New text spoken | |
| TTS-011 | Background TTS | 1. Start long TTS<br>2. Press home button | Audio continues in background | |
| TTS-012 | Silent mode | 1. Enable silent mode<br>2. Try TTS | Audio plays (uses playback route) | |
| TTS-013 | Bluetooth headphones | 1. Connect Bluetooth audio<br>2. Play TTS | Audio routes to headphones | |
| TTS-014 | Unsupported language voice | 1. Translate to rare language<br>2. Tap speaker | Falls back to closest voice or shows error | |

---

## 3. Speech Recognition Tests

### 3.1 Permission Flow

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| SR-001 | First-time mic permission | 1. Fresh install<br>2. Tap mic button | Shows system permission dialog | |
| SR-002 | First-time speech permission | 1. Grant mic permission<br>2. Observe | Shows speech recognition permission | |
| SR-003 | Deny mic permission | 1. Deny mic permission<br>2. Tap mic button | Shows error with Settings link | |
| SR-004 | Deny speech permission | 1. Deny speech permission<br>2. Tap mic button | Shows error with Settings link | |
| SR-005 | Revoke permission in Settings | 1. Grant permissions<br>2. Revoke in Settings<br>3. Return to app | Detects revoked permission | |

### 3.2 Voice Input

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| SR-006 | Basic voice input | 1. Tap mic button<br>2. Say "Hello world"<br>3. Stop recording | Text appears in source field | |
| SR-007 | Streaming transcription | 1. Start recording<br>2. Speak continuously | Text updates in real-time | |
| SR-008 | Stop recording manually | 1. Start recording<br>2. Tap mic button again | Recording stops, text finalized | |
| SR-009 | Auto-stop on silence | 1. Start recording<br>2. Speak, then stay silent | Recording auto-stops after pause | |
| SR-010 | Recording indicator | 1. Start recording<br>2. Observe UI | Shows red recording indicator | |
| SR-011 | Voice in Spanish | 1. Set source to Spanish<br>2. Speak Spanish | Recognizes Spanish speech | |
| SR-012 | Voice in Chinese | 1. Set source to Chinese<br>2. Speak Chinese | Recognizes Chinese speech | |

### 3.3 Speech Recognition Edge Cases

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| SR-013 | Background noise | 1. In noisy environment<br>2. Try voice input | Best-effort transcription | |
| SR-014 | No speech detected | 1. Start recording<br>2. Stay completely silent | Shows "no speech" or times out | |
| SR-015 | Very long recording | 1. Speak for 60+ seconds | Handles gracefully (may split) | |
| SR-016 | Interrupt recording | 1. Start recording<br>2. Receive phone call | Recording stops gracefully | |
| SR-017 | Airplane mode recording | 1. Enable airplane mode<br>2. Try voice input | On-device if available, else error | |

---

## 4. Offline Behavior Tests

### 4.1 Network Conditions

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| OFF-001 | No network - translation | 1. Enable airplane mode<br>2. Try to translate | Shows network error message | |
| OFF-002 | No network - TTS | 1. Enable airplane mode<br>2. Try TTS on existing translation | TTS works (offline capable) | |
| OFF-003 | No network - voice input | 1. Enable airplane mode<br>2. Try voice input | May work on-device or show error | |
| OFF-004 | Slow network | 1. Use Network Link Conditioner (3G)<br>2. Translate | Shows loading, completes eventually | |
| OFF-005 | Network timeout | 1. Set very slow network<br>2. Translate | Shows timeout error after ~30s | |
| OFF-006 | Network recovery | 1. Start offline<br>2. Enable network<br>3. Retry translation | Succeeds after network restored | |
| OFF-007 | Intermittent connection | 1. Toggle airplane mode during translation | Shows appropriate error | |

### 4.2 Cached Data

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| OFF-008 | View history offline | 1. Go offline<br>2. Open History tab | Shows cached history | |
| OFF-009 | View favorites offline | 1. Go offline<br>2. View Favorites | Shows saved favorites | |
| OFF-010 | View phrasebook offline | 1. Go offline<br>2. Browse phrasebook | Categories and phrases visible | |
| OFF-011 | Speak history item offline | 1. Go offline<br>2. Tap speak on history item | TTS works | |

---

## 5. Error Handling Tests

### 5.1 API Errors

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| ERR-001 | Server 500 error | 1. Backend returns 500<br>2. Observe UI | Shows "Server error" message | |
| ERR-002 | Server 503 (maintenance) | 1. Backend returns 503<br>2. Observe UI | Shows "temporarily unavailable" | |
| ERR-003 | Rate limiting (429) | 1. Backend returns 429<br>2. Observe UI | Shows "too many requests" message | |
| ERR-004 | Invalid API response | 1. Backend returns malformed JSON | Shows generic error, doesn't crash | |
| ERR-005 | Request timeout | 1. Backend takes >60s | Shows timeout error | |

### 5.2 Input Validation Errors

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| ERR-006 | Text too long | 1. Enter 5001+ characters<br>2. Translate | Shows "text too long" error | |
| ERR-007 | Invalid language code | 1. Programmatically send bad code | Graceful error handling | |

### 5.3 Error Recovery

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| ERR-008 | Dismiss error alert | 1. Trigger error<br>2. Tap OK | Alert dismisses, app usable | |
| ERR-009 | Retry after error | 1. Get network error<br>2. Fix network<br>3. Translate again | Succeeds on retry | |
| ERR-010 | Error doesn't persist | 1. Get error<br>2. Navigate away and back | Error cleared | |

---

## 6. History & Favorites Tests

### 6.1 History

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| H-001 | Save to history | 1. Translate text<br>2. Open History tab | Entry appears at top | |
| H-002 | History ordering | 1. Translate A, B, C<br>2. View history | Shows C, B, A (newest first) | |
| H-003 | History deduplication | 1. Translate "Hello" twice<br>2. View history | Only one entry, updated timestamp | |
| H-004 | Delete history item | 1. Swipe left on item<br>2. Tap Delete | Item removed | |
| H-005 | Clear all history | 1. Tap menu → Clear<br>2. Confirm | All history cleared | |
| H-006 | Search history | 1. Enter search query<br>2. View results | Filters matching entries | |
| H-007 | History persistence | 1. Add history<br>2. Kill app<br>3. Relaunch | History preserved | |
| H-008 | History limit (100) | 1. Add 101 translations<br>2. View history | Oldest non-favorite removed | |

### 6.2 Favorites

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| F-001 | Add to favorites | 1. Translate text<br>2. Tap star | Star fills, entry marked | |
| F-002 | Remove from favorites | 1. Tap filled star | Star unfills | |
| F-003 | View favorites only | 1. Tap Favorites segment<br>2. View list | Shows only starred items | |
| F-004 | Favorites persist | 1. Favorite item<br>2. Kill app<br>3. Relaunch | Favorite status preserved | |
| F-005 | Clear keeps favorites | 1. Clear history (keep favorites)<br>2. View | Favorites remain | |

### 6.3 History Actions

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| HA-001 | Open in translator | 1. Tap history item<br>2. Observe | Opens in Translate tab with data | |
| HA-002 | Speak from history | 1. Tap speaker on history item | TTS plays translation | |
| HA-003 | Copy from history | 1. Long press → Copy | Translation copied to clipboard | |

---

## 7. Phrasebook Tests

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| P-001 | View categories | 1. Open Phrasebook tab | Shows 6 categories with icons | |
| P-002 | Open category | 1. Tap "Basics" category | Shows phrase list | |
| P-003 | Translate phrase | 1. Tap phrase<br>2. View sheet | Shows translation | |
| P-004 | Change target language | 1. In phrasebook, tap language | Language picker appears | |
| P-005 | Speak phrase | 1. Tap speaker on phrase | TTS plays | |
| P-006 | Search phrases | 1. Enter search query | Filters across all categories | |
| P-007 | Open in translator | 1. Tap phrase → Open in Translator | Navigates to Translate with phrase | |
| P-008 | Copy phrase translation | 1. Translate phrase<br>2. Tap Copy | Copies to clipboard | |

---

## 8. Premium/Paywall Tests

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| PAY-001 | View paywall | 1. Tap premium feature (free user) | Paywall appears | |
| PAY-002 | Load products | 1. Open paywall<br>2. Wait | Products load with prices | |
| PAY-003 | Select product | 1. Tap yearly option | Selection indicator shows | |
| PAY-004 | Purchase flow | 1. Select product<br>2. Tap Subscribe<br>3. Authenticate | Purchase completes | |
| PAY-005 | Restore purchases | 1. Tap Restore<br>2. Wait | Restores if entitled | |
| PAY-006 | Premium unlocked | 1. After purchase<br>2. Try premium feature | Feature works | |
| PAY-007 | Free tier limits | 1. As free user<br>2. Translate 11 times | Shows upgrade prompt | |
| PAY-008 | Cancel paywall | 1. Open paywall<br>2. Tap X | Paywall dismisses | |

---

## 9. UI/UX Tests

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| UI-001 | Dark mode | 1. Enable dark mode<br>2. View all screens | Proper dark appearance | |
| UI-002 | Light mode | 1. Enable light mode<br>2. View all screens | Proper light appearance | |
| UI-003 | Dynamic type (large) | 1. Set accessibility large text<br>2. View app | Text scales, layout intact | |
| UI-004 | Dynamic type (small) | 1. Set accessibility small text<br>2. View app | Text scales appropriately | |
| UI-005 | Landscape orientation | 1. Rotate to landscape<br>2. Use app | Layout adapts | |
| UI-006 | iPad layout | 1. Run on iPad<br>2. View all screens | Appropriate sizing | |
| UI-007 | Keyboard avoidance | 1. Tap text field<br>2. Observe scroll | Content scrolls above keyboard | |
| UI-008 | Tab switching | 1. Switch between all tabs | Smooth transitions | |

---

## 10. Performance Tests

| ID | Test Case | Steps | Expected Result | Pass/Fail |
|----|-----------|-------|-----------------|-----------|
| PERF-001 | Cold launch time | 1. Force quit app<br>2. Launch | <2 seconds to usable | |
| PERF-002 | Translation latency | 1. Measure translation time | <3 seconds for short text | |
| PERF-003 | Memory usage | 1. Use app extensively<br>2. Check memory | No memory leaks | |
| PERF-004 | Battery impact | 1. Use app for 30 min<br>2. Check battery | Reasonable consumption | |
| PERF-005 | Large history scroll | 1. With 100 history items<br>2. Scroll list | Smooth 60fps scrolling | |

---

## 11. Device-Specific Tests

### Simulator Limitations (Document only - can't test):
- ❌ Speech recognition uses Mac mic
- ❌ On-device speech recognition unavailable
- ❌ Some TTS voices limited
- ❌ StoreKit testing requires configuration

### Physical Device Required:
- ✅ Full speech recognition
- ✅ On-device speech (if downloaded)
- ✅ All TTS voices
- ✅ Real StoreKit transactions (sandbox)

---

## Test Environment Checklist

- [ ] iOS 17.0 device tested
- [ ] iOS 18.0+ device tested
- [ ] iPhone SE (small screen) tested
- [ ] iPhone Pro Max (large screen) tested
- [ ] iPad tested
- [ ] Simulator tested (with noted limitations)
- [ ] Network Link Conditioner scenarios tested
- [ ] StoreKit sandbox transactions tested

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| QA Lead | | | |
| Developer | | | |
| Product Owner | | | |
