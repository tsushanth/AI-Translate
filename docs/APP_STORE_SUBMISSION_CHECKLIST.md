# App Store Submission Checklist - AI Translate

## Overview

This checklist covers all requirements for submitting AI Translate to the App Store. Complete each section before submission.

---

## 1. App Store Connect Setup

### 1.1 App Information

- [ ] **App Name**: AI Translate (or your chosen name)
- [ ] **Subtitle**: Voice & Text Translation (max 30 characters)
- [ ] **Bundle ID**: com.yourcompany.aitranslate
- [ ] **SKU**: AITRANSLATE001
- [ ] **Primary Language**: English (U.S.)
- [ ] **Category**:
  - Primary: Reference
  - Secondary: Travel
- [ ] **Content Rights**: Confirm you own or have rights to all content

### 1.2 Pricing & Availability

- [ ] **Price**: Free (with In-App Purchases)
- [ ] **Availability**: All territories (or select specific)
- [ ] **Pre-Orders**: Disabled (or configure if desired)

### 1.3 In-App Purchases

| Product ID | Type | Price | Status |
|------------|------|-------|--------|
| com.aitranslate.premium.monthly | Auto-Renewable | $4.99/month | Ready for Submission |
| com.aitranslate.premium.yearly | Auto-Renewable | $29.99/year | Ready for Submission |

- [ ] IAP Reference Name set
- [ ] IAP Description set
- [ ] IAP Review Screenshot uploaded
- [ ] Subscription Group created ("Premium")
- [ ] Localized display names added

---

## 2. Privacy & Permissions

### 2.1 Info.plist Permission Strings

Add these to your Info.plist with clear, user-friendly descriptions:

```xml
<!-- Microphone Access -->
<key>NSMicrophoneUsageDescription</key>
<string>AI Translate needs microphone access to convert your speech into text for translation. Your voice is processed securely and is not stored.</string>

<!-- Speech Recognition -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>AI Translate uses speech recognition to transcribe your spoken words into text. This may be processed on-device or via Apple's secure servers depending on your language settings.</string>
```

### 2.2 App Privacy Details (App Store Connect)

Complete the privacy questionnaire with the following information:

#### Data Types Collected

| Data Type | Collected | Linked to Identity | Used for Tracking |
|-----------|-----------|-------------------|-------------------|
| **Identifiers** | | | |
| └─ Device ID | Yes | No | No |
| **Usage Data** | | | |
| └─ Product Interaction | Yes | No | No |
| **User Content** | | | |
| └─ Other User Content | Yes | No | No |
| **Diagnostics** | | | |
| └─ Crash Data | Yes | No | No |
| └─ Performance Data | Yes | No | No |

#### Data Use Purposes

| Data Type | Purpose |
|-----------|---------|
| Device ID | Analytics, App Functionality |
| Product Interaction | Analytics, App Functionality |
| Other User Content (translation text) | App Functionality |
| Crash Data | App Functionality |
| Performance Data | App Functionality |

#### Privacy Disclosure Text

> **Translation Data**: Text and voice input you provide is sent to our secure servers for translation processing. Audio is converted to text on-device when possible. Translation text is logged for service improvement but is not linked to your identity.
>
> **No Tracking**: We do not track you across other companies' apps or websites.
>
> **Data Retention**: Translation logs are retained for 30 days for service improvement, then automatically deleted.

### 2.3 Privacy Policy URL

- [ ] Privacy Policy hosted at: `https://yourcompany.com/aitranslate/privacy`
- [ ] Privacy Policy covers:
  - [ ] What data is collected
  - [ ] How data is used
  - [ ] Third-party services (Google Cloud Translation API)
  - [ ] Data retention periods
  - [ ] User rights (deletion, access)
  - [ ] Contact information
  - [ ] GDPR/CCPA compliance (if applicable)

### 2.4 Terms of Service URL

- [ ] Terms of Service hosted at: `https://yourcompany.com/aitranslate/terms`

---

## 3. App Store Listing Content

### 3.1 Description

**Promotional Text** (170 characters, can be updated without app update):
```
🎉 Now with 30+ languages! Translate text and voice instantly. Try Premium free for 7 days.
```

**Description** (4000 characters max):
```
AI Translate makes language barriers disappear. Whether you're traveling abroad, learning a new language, or communicating with friends and colleagues around the world, our powerful translation app has you covered.

INSTANT TEXT TRANSLATION
• Translate between 30+ languages with a single tap
• Auto-detect the source language automatically
• Copy translations to use anywhere

VOICE TRANSLATION
• Speak naturally and see your words translated in real-time
• Perfect for conversations and quick translations
• Supports major world languages

LISTEN & LEARN
• Hear translations spoken aloud with natural-sounding voices
• Learn correct pronunciation for any language
• Adjustable speech rate for learning

SMART PHRASEBOOK
• Pre-loaded phrases for travel, dining, emergencies & more
• Instantly translate common phrases
• Perfect for travelers

HISTORY & FAVORITES
• Access your recent translations anytime
• Save important translations as favorites
• Search through your translation history

PREMIUM FEATURES
• Unlimited translations (free tier: 10/day)
• Voice input and text-to-speech
• Unlimited favorites
• Priority translation processing
• No ads

SUPPORTED LANGUAGES
English, Spanish, French, German, Italian, Portuguese, Russian, Chinese, Japanese, Korean, Arabic, Hindi, Dutch, Polish, Turkish, Vietnamese, Thai, Swedish, Danish, Finnish, Norwegian, Czech, Greek, Hebrew, Indonesian, Malay, Romanian, Ukrainian, Hungarian, Bengali, and more!

PRIVACY FOCUSED
• Your translations are processed securely
• We don't sell your data
• Delete your history anytime

Download AI Translate today and break down language barriers!

---
Terms of Service: https://yourcompany.com/aitranslate/terms
Privacy Policy: https://yourcompany.com/aitranslate/privacy
```

**Keywords** (100 characters, comma-separated):
```
translate,translator,translation,language,voice,speech,dictionary,travel,learn,text
```

### 3.2 What's New (Version Notes)

```
Version 1.0.0 - Initial Release

• Translate text between 30+ languages
• Voice input with speech recognition
• Text-to-speech for translations
• Smart phrasebook with travel phrases
• Save favorites and view history
• Premium subscription for unlimited features
```

### 3.3 Support Information

- [ ] **Support URL**: `https://yourcompany.com/aitranslate/support`
- [ ] **Marketing URL**: `https://yourcompany.com/aitranslate` (optional)
- [ ] **Support Email**: support@yourcompany.com

---

## 4. Screenshots & Media

### 4.1 Required Screenshots

#### iPhone 6.7" Display (iPhone 15 Pro Max)
Required: 3-10 screenshots, 1290 x 2796 pixels

| # | Screen | Content |
|---|--------|---------|
| 1 | Translation | Main translate screen with completed translation |
| 2 | Voice Input | Mic button activated, recording indicator visible |
| 3 | Language Selection | Language picker open showing options |
| 4 | Phrasebook | Category grid view |
| 5 | History | History list with favorites |
| 6 | Premium | Paywall showing benefits |

#### iPhone 6.5" Display (iPhone 11 Pro Max)
Required: 3-10 screenshots, 1242 x 2688 pixels
- [ ] Same content as 6.7" screenshots

#### iPhone 5.5" Display (iPhone 8 Plus)
Optional but recommended: 1242 x 2208 pixels
- [ ] Same content, verify layout works

#### iPad Pro 12.9" (6th Gen)
Required for iPad apps: 2048 x 2732 pixels
- [ ] Same content, iPad layout

#### iPad Pro 12.9" (2nd Gen)
Required for older iPad support: 2048 x 2732 pixels
- [ ] Same content

### 4.2 App Preview Videos (Optional)

- [ ] 15-30 second video showing key features
- [ ] Format: H.264, 30fps
- [ ] Dimensions: Match screenshot sizes
- [ ] No phone frame required (Apple adds it)

### 4.3 App Icon

- [ ] 1024 x 1024 px PNG (no alpha)
- [ ] No rounded corners (Apple applies mask)
- [ ] Visible at small sizes
- [ ] Does not contain text "beta" or "demo"

---

## 5. Build Preparation

### 5.1 Xcode Configuration

- [ ] **Version Number**: 1.0.0 (CFBundleShortVersionString)
- [ ] **Build Number**: 1 (CFBundleVersion) - increment for each upload
- [ ] **Deployment Target**: iOS 17.0
- [ ] **Required Device Capabilities**: armv7 (or arm64)

### 5.2 Code Signing

- [ ] Distribution certificate valid
- [ ] App Store provisioning profile valid
- [ ] Push notification entitlements (if applicable)
- [ ] In-App Purchase entitlement enabled

### 5.3 Build Settings

- [ ] Archive build configuration: Release
- [ ] Strip debug symbols: Yes
- [ ] Enable Bitcode: Yes (or No for some frameworks)
- [ ] Minimum deployment target set correctly

### 5.4 Pre-Upload Checks

- [ ] No NSLog/print statements in release (or wrapped in DEBUG)
- [ ] No test/sandbox URLs in production code
- [ ] API keys not hardcoded (use configuration)
- [ ] No placeholder text or images
- [ ] No "beta" or "test" labels visible

---

## 6. App Review Guidelines Compliance

### 6.1 Functionality

- [ ] App is complete and functional
- [ ] All features advertised work correctly
- [ ] No crashes or major bugs
- [ ] Proper error handling implemented

### 6.2 User Interface

- [ ] Uses standard iOS UI patterns
- [ ] Supports current iOS version
- [ ] Keyboard properly dismissed
- [ ] Loading states shown for network operations

### 6.3 Metadata

- [ ] App name matches functionality
- [ ] Screenshots reflect actual app
- [ ] Description is accurate
- [ ] No misleading claims

### 6.4 In-App Purchases

- [ ] Subscription terms clearly displayed
- [ ] Restore purchases works correctly
- [ ] Free features work without purchase
- [ ] Paywall doesn't trap users

### 6.5 Data Collection

- [ ] Privacy nutrition labels accurate
- [ ] Permission requests explain why data is needed
- [ ] Users can delete their data (history/favorites)

### 6.6 Legal

- [ ] Terms of Service accessible
- [ ] Privacy Policy accessible
- [ ] No copyrighted content without permission
- [ ] Age rating set appropriately

---

## 7. Review Notes for Apple

Provide to help expedite review:

```
DEMO ACCOUNT (if applicable):
Not required - app works without login

IN-APP PURCHASES:
- Monthly Premium: $4.99/month
- Yearly Premium: $29.99/year
- Includes 7-day free trial
- Sandbox account for testing: [your sandbox email]

SPECIAL FEATURES TO TEST:
1. Voice Translation: Tap the microphone button, grant permissions when prompted, and speak. The app will transcribe and translate your speech.

2. Text-to-Speech: After translating, tap the speaker icon to hear the translation spoken aloud.

3. Phrasebook: Navigate to Phrasebook tab to see pre-loaded travel phrases.

BACKEND INFORMATION:
Translation is powered by our Cloud Run backend which calls Google Cloud Translation API. All processing happens on our secure servers.

NOTES:
- Microphone and speech recognition permissions are required for voice features
- TTS works offline using iOS built-in voices
- Translation requires network connectivity
```

---

## 8. Submission Steps

### 8.1 Prepare Build

1. [ ] In Xcode: Product → Archive
2. [ ] Window → Organizer → Distribute App
3. [ ] Select "App Store Connect"
4. [ ] Upload

### 8.2 App Store Connect

1. [ ] Go to App Store Connect → My Apps
2. [ ] Select your app
3. [ ] Click "+ Version or Platform" if new version
4. [ ] Fill in "What's New"
5. [ ] Select build from uploaded builds
6. [ ] Complete all required fields
7. [ ] Add screenshots
8. [ ] Set pricing and availability
9. [ ] Complete App Privacy questionnaire
10. [ ] Submit for Review

### 8.3 Post-Submission

- [ ] Monitor email for review status
- [ ] Respond promptly to any reviewer questions
- [ ] Prepare marketing materials for launch

---

## 9. Common Rejection Reasons to Avoid

| Issue | How to Avoid |
|-------|--------------|
| **Crashes** | Thorough QA testing on device |
| **Placeholder content** | Remove all Lorem Ipsum, test data |
| **Broken links** | Verify all URLs work |
| **Incomplete IAP** | Test purchase + restore flow in sandbox |
| **Missing permissions** | Add clear usage descriptions |
| **Misleading metadata** | Screenshots must match actual app |
| **Privacy issues** | Accurate privacy labels |
| **Minimum functionality** | Ensure app has meaningful features |

---

## 10. Post-Launch Checklist

- [ ] Monitor crash reports in App Store Connect
- [ ] Respond to user reviews
- [ ] Track key metrics (downloads, revenue, retention)
- [ ] Plan first update based on feedback
- [ ] Monitor backend for any issues
- [ ] Set up alerts for API errors

---

## Sign-Off

| Role | Name | Date | Approval |
|------|------|------|----------|
| Developer | | | |
| QA | | | |
| Product Manager | | | |
| Legal | | | |

---

## Appendix A: Privacy Policy Template

```markdown
# Privacy Policy for AI Translate

Last updated: [DATE]

## Overview
AI Translate ("we", "our", "app") respects your privacy. This policy explains how we handle your data.

## Data We Collect

### Translation Content
- Text you enter for translation
- Voice audio (converted to text on-device when possible)
- This data is sent to our servers for translation processing

### Device Information
- Anonymous device identifier
- App version and iOS version
- Used for analytics and troubleshooting

### Usage Data
- Features used and frequency
- Error logs for debugging

## How We Use Data
- To provide translation services
- To improve translation quality
- To fix bugs and improve performance
- To provide customer support

## Data Sharing
- Translation requests are processed via Google Cloud Translation API
- We do not sell your data
- We may share anonymized analytics with service providers

## Data Retention
- Translation logs: 30 days
- Crash reports: 90 days
- You can delete local history anytime in the app

## Your Rights
- Access: Contact us to request your data
- Deletion: Use in-app clear history or contact us
- Opt-out: Disable analytics in Settings (future feature)

## Security
- All data transmitted via HTTPS
- Servers hosted on Google Cloud Platform
- Regular security audits

## Children's Privacy
This app is not directed at children under 13.

## Changes
We may update this policy. Check this page for updates.

## Contact
support@yourcompany.com
```

---

## Appendix B: Terms of Service Template

```markdown
# Terms of Service for AI Translate

Last updated: [DATE]

## Acceptance
By using AI Translate, you agree to these terms.

## Service Description
AI Translate provides text and voice translation services.

## User Responsibilities
- Use the service lawfully
- Do not abuse or overload the service
- Do not attempt to reverse-engineer the app

## Subscriptions
- Premium subscriptions auto-renew unless cancelled
- Cancel at least 24 hours before renewal
- Manage subscriptions in iOS Settings
- No refunds for partial subscription periods

## Disclaimers
- Translations are provided "as is"
- We do not guarantee 100% accuracy
- Not suitable for legal, medical, or official documents

## Limitation of Liability
We are not liable for damages from use of translations.

## Termination
We may terminate access for violations of these terms.

## Changes
We may update these terms. Continued use means acceptance.

## Contact
support@yourcompany.com
```
