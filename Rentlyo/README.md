# 🏠 Arya Spaces — Renter & Tenant Mobile Application

> **Designed, Engineered & Maintained by [Aaryan Gupta](https://aryanony.pages.dev/)**  
> *The official tenant companion app for commercial shopkeepers and residential tenants in Arya Arcade properties.*

---

## 📖 Overview & Purpose

**Arya Spaces** provides commercial shop owners and residential tenants with complete transparency into their active lease agreements, monthly rent schedules, advance security balance calculations, payment history, and property notices.

```
                      ┌─────────────────────────────────────────┐
                      │          ARYA SPACES RENTER APP         │
                      └────────────────────┬────────────────────┘
                                           │
         ┌─────────────────────────────────┼─────────────────────────────────┐
         ▼                                 ▼                                 ▼
 ┌───────────────┐                 ┌───────────────┐                 ┌───────────────┐
 │ 📊 Dashboard  │                 │ 🧾 History    │                 │ 📜 Agreement  │
 ├───────────────┤                 ├───────────────┤                 ├───────────────┤
 │ • Current Due │                 │ • Receipts    │                 │ • Deal Terms  │
 │ • Adv Balance │                 │ • Installments│                 │ • Tiers/Rent  │
 │ • Auto-Deduct │                 │ • Status Sync │                 │ • Top-Up Log  │
 └───────────────┘                 └───────────────┘                 └───────────────┘
```

---

## 👨‍💻 Lead Software Architect

<div align="center">

### Creator & Principal Engineer
## 🚀 **[Aaryan Gupta](https://aryanony.pages.dev/)**

[![Portfolio](https://img.shields.io/badge/Portfolio-aryanony.pages.dev-0D9488?style=for-the-badge&logo=google-chrome&logoColor=white)](https://aryanony.pages.dev/)
[![Developer](https://img.shields.io/badge/Developer-Aaryan%20Gupta-1E293B?style=for-the-badge&logo=flutter&logoColor=white)](https://aryanony.pages.dev/)

</div>

---

## 💡 Key Features & Renter Workflows

### 1. Real-Time Dashboard Card (`home_screen.dart`)
- Displays exact current month due amount, or auto-deduction status.
- Shows remaining advance balance evaluated as of `DateTime.now()` alongside total advance deposited (e.g. `Adjusted against your advance (₹244000 of ₹250000 advance remaining)`).

### 2. Deal Summary & Plain Language Breakdown (`deal_summary_screen.dart`)
- **Live Streamed Agreement**: Powered by `FirestoreService().streamDealById(deal.id)`, ensuring instant reflection when property owners add advance top-ups, amenities, or step-up rent tiers.
- **Advance Top-Up Log**: Complete history of initial move-in advance deposits and subsequent top-ups with exact dates, amounts, and owner remarks.
- **Rent Schedule Step-Up Tiers**: Displays all past, present, and future rent tier escalations agreed upon in the lease contract.

### 3. Payment History & Installment Tracking (`payment_history_screen.dart`)
- Full ledger breakdown of all monthly rent records.
- Shows exact payment statuses: `confirmed-paid`, `adjusted-against-advance`, `pending-confirmation`, `confirmed-partial`, or `overdue`.
- Allows reporting payments and partial installments directly to the property manager.

### 4. Smart Notification Center (`smart_notification_service.dart`)
- Receives automated rent cycle notifications.
- Dynamically updates notification messages to reflect current settlement status (`"Rent for 2026-08 (₹6000) covered from advance balance."`).
- Automatically purges obsolete overdue warning notifications once rent is cleared.

---

## 🏛️ Technical Stack & Architecture

- **UI Framework**: Flutter (Dart 3.3+)
- **State & Data Sync**: Real-Time Firestore `StreamBuilder` architecture
- **Financial Calculation**: `RentEngine` shared ledger reconciliation core
- **Authentication**: Firebase Authentication with phone/email pseudo-login credentials
- **Local Notifications**: `flutter_local_notifications` panel integration

---

## 🛠️ Setup & Installation

```bash
# Navigate to Renter App directory
cd "Arya Spaces"

# Install dependencies
flutter pub get

# Launch on connected device or emulator
flutter run
```

---

## 📜 Credits & License

Developed with excellence by **[Aaryan Gupta](https://aryanony.pages.dev/)**.  
© 2026 Arya Arcade Ecosystem. All Rights Reserved.
