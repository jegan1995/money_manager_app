# 🚀 PaisaTrack v1.4.0 — Bank Sync, Tags & Personalization

**Release Date:** March 5, 2026  
**Build:** 1.4.0+4  
**Platform:** Android (APK) + Web (PWA)

---

## 🎉 What's New

### 🏦 Bank Sync — Auto-import from SMS & CSV
Never type bank transactions manually again.
- **SMS Auto-Read** (Android): Reads bank messages from HDFC, ICICI, SBI, Kotak, Axis, Yes Bank, GPay, PhonePe, Paytm and auto-creates transactions
- **CSV Import**: Upload your net-banking statement CSV — the app auto-detects the bank format and maps columns
- Smart deduplication prevents double entries
- Preview transactions before importing — select what you want

### 🏷️ Transaction Tags
- Add `#hashtags` to any transaction — `#business`, `#travel`, `#medical`, `#tax`, and more
- 10 preset tags + create your own custom tags
- Filter your transaction list by tag with one tap
- Tags displayed as tiny chips on each transaction tile

### 📸 Profile Photo
- Upload your photo from gallery (web + Android) or camera (Android)
- Stored securely in Firebase — never shared
- Tap the avatar in Settings to change or remove

### 🎨 Account Color Picker
- Assign a custom color to any account from a palette of 12
- Account card and save button update live as you pick
- Resets to type-default if you clear the color

### 💳 Credit Card Billing Cycle
- Set **Statement Date** (e.g. 20th) and **Payment Due Date** (e.g. 5th) on credit card accounts
- Account detail view filters transactions by billing cycle, not calendar month
- Purple info bar shows your statement & due dates at a glance
- Arrow navigation moves between billing cycles

---

## 🐛 Bug Fixes
- Budget tab no longer flickers due to infinite refresh loop
- Account balance shows clean rounded numbers (no more ₹201.57999…)
- Dashboard quick actions replaced with actually useful shortcuts
- Custom category color crash on web fixed
- `HapticFeedback` missing import in transaction screen fixed

---

## 📦 Installation

### Android APK
Download `app-release.apk` from the assets below.

### Web (PWA)
Visit: **[your-firebase-app-url.web.app]**
On Android Chrome: tap menu → "Add to Home Screen" to install as app.

---

## 🔑 Permissions Required (Android)
| Permission | Used For |
|-----------|---------|
| `READ_SMS` | Bank Sync SMS auto-import (optional) |
| `CAMERA` | Receipt scanner, profile photo (optional) |
| `READ_EXTERNAL_STORAGE` | Photo gallery picker (optional) |
| `INTERNET` | Firebase sync, AI features |
| `USE_BIOMETRIC` | Fingerprint/face app lock |

---

## 📋 Full Changelog
See [CHANGELOG.md](./CHANGELOG.md) for complete version history.

## 🔒 Privacy
See [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) for full privacy details.

---

*Built with ❤️ using Flutter & Firebase by Jegan*