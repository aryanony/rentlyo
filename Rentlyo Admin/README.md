# 👑 AryaSpaces Admin — Owner & Property Manager Console

> **Architected, Engineered & Maintained by [Aaryan Gupta](https://aryanony.pages.dev/)**  
> *The central administrative management console for Arya Arcade property owners, managers, and accounting staff.*

---

## 📖 Overview & Purpose

**AryaSpaces Admin** is an enterprise management system engineered to control commercial shops and residential units across properties. It provides property owners with multi-unit deal creation, automated ledger rebalancing, step-up rent schedule configuration, advance security deposit top-up management, and financial reporting exports.

```
                      ┌─────────────────────────────────────────┐
                      │          ARYASPACES ADMIN CONSOLE       │
                      └────────────────────┬────────────────────┘
                                           │
         ┌─────────────────────────────────┼─────────────────────────────────┐
         ▼                                 ▼                                 ▼
 ┌───────────────┐                 ┌───────────────┐                 ┌───────────────┐
 │ 🏢 Multi-Unit │                 │ 💰 Ledger     │                 │ 📊 Reports    │
 ├───────────────┤                 ├───────────────┤                 ├───────────────┤
 │ • Single Deal │                 │ • Top-Ups     │                 │ • PDF Exports │
 │ • Res/Comm    │                 │ • Rebalance   │                 │ • Excel CSV   │
 │ • Consolidation│                │ • Step-Up Tiers│                │ • Audits      │
 └───────────────┘                 └───────────────┘                 └───────────────┘
```

---

## 👨‍💻 Lead Software Architect & Developer

<div align="center">

### System Architect & Principal Engineer
## 🚀 **[Aaryan Gupta](https://aryanony.pages.dev/)**

[![Portfolio](https://img.shields.io/badge/Portfolio-aryanony.pages.dev-0D9488?style=for-the-badge&logo=google-chrome&logoColor=white)](https://aryanony.pages.dev/)
[![Developer](https://img.shields.io/badge/Developer-Aaryan%20Gupta-1E293B?style=for-the-badge&logo=flutter&logoColor=white)](https://aryanony.pages.dev/)

</div>

---

## 🔑 Core Administrative Features

### 1. Multi-Unit Deal Onboarding Wizard (`add_renter_wizard.dart`)
- **5-Step Onboarding**:
  1. Unit Confirmation & Multi-Unit Selection
  2. Tenant Info & Credentials Setup
  3. Deal Start & Step-Up Rent Schedule
  4. Lease Agreement Document Upload
  5. Summary & Activation
- **Unit Type Isolation**: Commercial deals exclusively display Commercial vacant units (`G3`, `G6`). Residential deals exclusively display Residential vacant units (`Flats`, `Rooms`, `Beds`).

### 2. Multi-Unit Deal Consolidation & Occupancy Sync (`home_screen.dart`)
- Multi-unit deals (e.g. `G1 + G2 + G3` for *Shagun Parlour*) are consolidated under a single active deal card.
- Secondary merged units (G2, G3) are automatically updated to `occupied` status in Firestore and excluded from vacant unit lists and rental selection screens.
- Top occupancy cards accurately reflect total occupied units and remaining vacant inventory.

### 3. Advance Security Top-Up Management (`renter_detail_screen.dart`)
- **Add Top-Up Dialog**: Allows adding advance top-ups (e.g. ₹5000) with custom dates and remarks.
- Real-time Firestore document updates sync immediately across both Admin and Renter screens.

### 4. Secondary Authentication & Tenant Credential Management (`secondary_auth.dart`)
- Isolated secondary Firebase Auth instance allows admins to generate tenant accounts without logging out of the admin session.

### 5. Priority Notification Audit Sender (`smart_notification_service.dart`)
- Automatic detection of current period payment status.
- Defaults to `Gentle Rent Start` preset if current month's rent is already paid or covered from advance balance.
- Automated audit runs clean up obsolete overdue warnings.

---

## 🏛️ System Architecture & Financial Logic

- **Framework**: Flutter (Dart 3.3+)
- **Database & Sync**: Cloud Firestore real-time collection snapshots and single-doc streams
- **Export Engines**: `pdf` & `csv` package integration for generating property ledger statements
- **Security**: Local PIN authentication & Secondary FirebaseAuth management

---

## 🛠️ Setup & Run

```bash
# Navigate to Admin App directory
cd "AryaSpaces Admin"

# Install dependencies
flutter pub get

# Launch on connected device or desktop
flutter run
```

---

## 📜 Credits & License

Engineered with highest industry standards by **[Aaryan Gupta](https://aryanony.pages.dev/)**.  
© 2026 Arya Arcade Ecosystem. All Rights Reserved.
