# AI Translate - Quick Reference Card

## Info.plist Permission Strings

```xml
<!-- REQUIRED: Add to Info.plist -->

<key>NSMicrophoneUsageDescription</key>
<string>AI Translate needs microphone access to convert your speech into text for translation. Your voice is processed securely and is not stored.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>AI Translate uses speech recognition to transcribe your spoken words into text. This may be processed on-device or via Apple's secure servers depending on your language settings.</string>
```

---

## App Privacy Labels Summary

### Data Collected

| Category | Data Type | Purpose |
|----------|-----------|---------|
| Identifiers | Device ID | Analytics |
| User Content | Translation Text | App Functionality |
| Usage Data | Product Interaction | Analytics |
| Diagnostics | Crash/Performance | App Functionality |

### Key Points for Privacy Questionnaire
- ✅ Data collected
- ❌ NOT linked to identity
- ❌ NOT used for tracking
- Text sent to backend for translation (disclose this)

---

## Backend Data Processing Disclosure

> **Important**: You must disclose that user-entered text is sent to your Cloud Run backend for processing. This is considered "User Content" in Apple's privacy labels.

**What to say in App Privacy:**
- Data Type: "Other User Content"
- Purpose: "App Functionality"
- Linked to Identity: No
- Used for Tracking: No

---

## Screenshots Required

| Device | Size | Minimum |
|--------|------|---------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 | 3 |
| iPhone 6.5" (11 Pro Max) | 1242 x 2688 | 3 |
| iPhone 5.5" (8 Plus) | 1242 x 2208 | Optional |
| iPad Pro 12.9" 6th | 2048 x 2732 | 3 (if iPad) |
| iPad Pro 12.9" 2nd | 2048 x 2732 | 3 (if iPad) |

**Recommended Screenshots:**
1. Main translation screen (with result)
2. Voice input active
3. Phrasebook categories
4. History/Favorites
5. Language picker
6. Premium features

---

## Test Cases - Critical Path

### Must Pass Before Submission

| Test | Steps | Expected |
|------|-------|----------|
| Basic translation | Enter text → Translate | Shows result |
| Voice input | Tap mic → Speak → Stop | Text transcribed |
| TTS | Translate → Tap speaker | Audio plays |
| Network error | Airplane mode → Translate | Error message |
| Purchase | Tap premium → Subscribe | StoreKit flow |
| Restore | Tap Restore | Syncs entitlements |

### Device Requirements

| Feature | Simulator | Device |
|---------|-----------|--------|
| Text translation | ✅ | ✅ |
| TTS playback | ✅ | ✅ |
| Voice input | ⚠️ Uses Mac mic | ✅ Full |
| On-device speech | ❌ | ✅ |
| StoreKit real | ❌ Sandbox only | ✅ |

---

## Common Rejection Fixes

| Rejection Reason | Fix |
|------------------|-----|
| Crashes | Test on real device, check crash logs |
| Placeholder content | Remove "Lorem ipsum", test data |
| Privacy labels wrong | Update App Store Connect questionnaire |
| IAP not working | Test restore, verify products approved |
| Missing permission purpose | Add clear Info.plist strings |

---

## Subscription Setup

| Product ID | Price | Period |
|------------|-------|--------|
| com.aitranslate.premium.monthly | $4.99 | 1 month |
| com.aitranslate.premium.yearly | $29.99 | 1 year |

**Subscription Group**: Premium
**Free Trial**: 7 days (optional)

---

## URLs Required

| URL | Purpose | Status |
|-----|---------|--------|
| Privacy Policy | Required for IAP | [ ] Live |
| Terms of Service | Recommended | [ ] Live |
| Support URL | Required | [ ] Live |
| Marketing URL | Optional | [ ] Live |

---

## Review Notes Template

```
DEMO ACCOUNT:
Not required - app works without login

IN-APP PURCHASES:
Monthly: $4.99/month
Yearly: $29.99/year

TESTING VOICE FEATURES:
1. Grant microphone permission when prompted
2. Grant speech recognition permission
3. Tap microphone button to start voice input

BACKEND:
Translation uses Cloud Run + Google Cloud Translation API
All requests over HTTPS

NOTES:
- Network required for translation
- TTS works offline
- Voice input needs device (limited on simulator)
```

---

## Quick Checklist

### Before Archive
- [ ] Version/build numbers correct
- [ ] Release configuration
- [ ] No debug logs in production
- [ ] StoreKit products configured

### Before Submit
- [ ] All screenshots uploaded
- [ ] Description complete
- [ ] Privacy questionnaire done
- [ ] IAPs approved
- [ ] Build processed

### After Submit
- [ ] Monitor for review questions
- [ ] Prepare launch marketing
- [ ] Set up crash monitoring
