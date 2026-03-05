# Privacy Policy — PaisaTrack

**Effective Date:** March 5, 2026  
**Last Updated:** March 5, 2026  
**Developer:** Jegan  
**App Name:** PaisaTrack — Smart Money Manager  
**Package:** com.jegan.money_manager_app  
**Contact:** [contactpaisatrack2026@gmail.com]

---

## 1. Introduction

PaisaTrack ("the App", "we", "our") is a personal finance management application built for Android and Web. We are committed to protecting your privacy. This Privacy Policy explains what data we collect, how we use it, and your rights over your data.

By using PaisaTrack, you agree to this Privacy Policy.

---

## 2. Data We Collect

### 2.1 Account Information
- **Email address** — used for Firebase Authentication (sign in / sign up)
- **Display name** — the name you enter when setting up your profile
- **Profile photo** — optionally uploaded by you, stored as encoded data in Firebase

### 2.2 Financial Data (You Enter)
All financial data is entered manually by you:
- Account names, types, and balances
- Transaction records (amount, category, date, note, tags)
- Budget plans and savings goals
- Loan and EMI details
- Investment portfolio entries
- Bill reminders and subscriptions
- Split expense records

**This data is stored in your personal Firebase Firestore database and is only accessible to you when logged in with your account.**

### 2.3 Device & Usage Data
- **Device tokens** — collected by Firebase Cloud Messaging (FCM) for push notifications
- **App version** — used to enforce force-update if a critical update is released
- We do **not** collect device identifiers, IMEI, or location data

### 2.4 SMS Data (Android Only — Optional)
- If you use the **Bank Sync** feature, the App requests permission to read SMS messages
- SMS reading is used **only** to detect bank transaction messages and auto-fill transaction forms
- SMS content is processed **on-device only** and is **never uploaded** to any server
- You can deny this permission — the App will continue to work fully without it

### 2.5 Camera & Gallery (Optional)
- The **Receipt Scanner** and **Profile Photo** features may request camera or photo gallery access
- Images are used only to extract transaction data (receipt scanner) or set your profile photo
- Receipt images are sent to the **Anthropic Claude API** for text extraction only — they are not stored by us

---

## 3. How We Use Your Data

| Data | Purpose |
|------|---------|
| Email | Authentication, account recovery |
| Financial records | Display your transactions, reports, budgets |
| Profile photo | Shown in your Settings profile card |
| FCM token | Send push notifications (bill reminders, budget alerts) |
| Receipt images | Auto-extract transaction data via AI |

We do **not**:
- Sell your data to third parties
- Use your data for advertising
- Share your data with anyone except the services listed below

---

## 4. Third-Party Services

PaisaTrack uses the following third-party services:

| Service | Purpose | Privacy Policy |
|---------|---------|----------------|
| Firebase Auth | User authentication | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Firebase Firestore | Store your financial data | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Firebase Cloud Messaging | Push notifications | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Anthropic Claude API | AI receipt scanning & spending insights | [anthropic.com/privacy](https://www.anthropic.com/privacy) |

All data stored in Firebase is protected by Google's enterprise-grade security infrastructure.

---

## 5. Data Storage & Security

- All your financial data is stored in **Firebase Firestore** under your unique user ID
- Data is protected by **Firebase Security Rules** — only you can read or write your own data
- Communication between the App and Firebase is encrypted via **HTTPS/TLS**
- Your password is managed entirely by **Firebase Authentication** — we never see or store it
- Profile photos are stored as encoded data in Firestore and are not publicly accessible

---

## 6. Data Retention

- Your data remains in Firebase as long as your account exists
- If you delete your account (via Settings → Logout, or by contacting us), all your data will be deleted from Firestore within 30 days
- Locally cached data on your device is cleared when you log out

---

## 7. Your Rights

You have the right to:
- **Access** your data — all your data is visible within the App
- **Export** your data — use the PDF Report export feature
- **Delete** your data — contact us to request full deletion
- **Correct** your data — edit any transaction, account, or profile information at any time
- **Withdraw consent** — you may deny SMS/camera permissions at any time in Android Settings

---

## 8. Children's Privacy

PaisaTrack is not intended for children under 13. We do not knowingly collect data from children. If you believe a child has provided personal information, please contact us.

---

## 9. Changes to This Policy

We may update this Privacy Policy from time to time. When we do, we will update the "Last Updated" date at the top of this page. Continued use of the App after changes constitutes acceptance of the updated policy.

---

## 10. Contact Us

For privacy questions, data deletion requests, or concerns:

**Email:** [contactpaisatrack2026@gmail.com]  
**GitHub:** [github.com/jegan1995/money_manager_app](https://github.com/jegan1995/money_manager_app)

---

*PaisaTrack is an independent app. It is not affiliated with any bank, financial institution, or government body.*