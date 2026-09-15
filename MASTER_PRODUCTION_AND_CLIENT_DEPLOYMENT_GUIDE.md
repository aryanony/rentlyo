# 🏢 Rentlyo Suite — Master Client Deployment Guide
### Fast, 1-Click, Step-by-Step Operations Manual (v3.0 Production)

> **What is this?** Two complete, production-grade white-label mobile apps:  
> 1. 🛡️ **Admin Console** (for property owners & managers)  
> 2. 📱 **Tenant Companion** (for renters & tenants)  
>
> **Server Cost**: **₹0/month forever** using Google Firebase Spark Tier (no credit card needed).  
> **Skill Required**: None. If you can edit a text file and double-click a file, you can deploy a client in under 3 minutes.

---

# 📑 Table of Contents

* [**PART 1: The 1-Minute Concept**](#part-1-the-1-minute-concept)
* [**PART 2: What to Copy for a New Client**](#part-2-what-to-copy-for-a-new-client)
* [**PART 3: The 3-Step Setup (Zero to Live in 3 Minutes)**](#part-3-the-3-step-setup-zero-to-live-in-3-minutes)
  * [Step 1: Create Firebase Backend (5 Clicks)](#step-1-create-firebase-backend-5-clicks)
  * [Step 2: Drop Assets in `client_assets/`](#step-2-drop-assets-in-client_assets)
  * [Step 3: Edit `client_config.json`](#step-3-edit-client_configjson)
  * [Step 4: Double-Click `setup_new_client.bat`](#step-4-double-click-setup_new_clientbat)
  * [Step 5: Build Installable Release APKs](#step-5-build-installable-release-apks)
* [**PART 4: Daily App Operations**](#part-4-daily-app-operations)
  * [4.1 Owner First Login & Quick PIN](#41-owner-first-login--quick-pin)
  * [4.2 Add Units & Onboard Tenants](#42-add-units--onboard-tenants)
  * [4.3 Tenant App Features](#43-tenant-app-features)
  * [4.4 Multi-Property Management](#44-multi-property-management)
* [**PART 5: Built-In Smart Engines**](#part-5-built-in-smart-engines)
  * [5.1 Rent & Advance Auto-Calculation Engine](#51-rent--advance-auto-calculation-engine)
  * [5.2 Electricity & Water Sub-Meter Billing](#52-electricity--water-sub-meter-billing)
  * [5.3 Live Cloud Re-Branding (No Recompiling)](#53-live-cloud-re-branding-no-recompiling)
  * [5.4 In-App Over-The-Air (OTA) Updates](#54-in-app-over-the-air-ota-updates)
* [**PART 6: Troubleshooting & Reference**](#part-6-troubleshooting--reference)

---

# PART 1: The 1-Minute Concept

The architecture consists of **2 apps connected to 1 free Google Firebase backend**:

```
                       ┌───────────────────────────────┐
                       │     Google Firebase Cloud     │
                       │   (Free Database & Security)  │
                       └───────────────┬───────────────┘
                                       │
                 ┌─────────────────────┴─────────────────────┐
                 │                                           │
        ┌────────┴────────┐                         ┌────────┴────────┐
        │  ADMIN CONSOLE  │                         │ TENANT COMPANION│
        │  (Owner App)    │                         │  (Tenant App)   │
        └─────────────────┘                         └─────────────────┘
        • Full control over building                • Dedicated tenant portal
        • Track rents, dues & expenses              • 1-Click UPI rent payment
        • Onboard tenants in 30s                    • Instant WhatsApp receipts
        • Utility sub-meter calculator              • Gate pass & visitor logs
```

### The $0 Secret (Why it never costs a rupee):
* Traditional apps charge recurring fees for SMS OTP gateways.
* This suite converts the user's 10-digit mobile number into an internal pseudo-email behind the scenes:
  $$\text{Mobile: } \mathbf{9876543210} \longrightarrow \mathbf{9876543210@client-lease.local}$$
* Users only type their mobile number and password; Firebase processes it through its unlimited free Email/Password tier. **Lifetime cost: ₹0.**

---

# PART 2: What to Copy for a New Client

When preparing a clean folder for a **new client**, create a folder (e.g. `C:\Users\...\Documents\ClientName`) and copy **these 7 items**:

```
📁 Your-New-Client-Folder/
├── 📁 Rentlyo/              (Tenant App - you can rename it to 'ClientApp' if you want)
├── 📁 Rentlyo Admin/        (Admin App - you can rename it to 'ClientApp Admin' if you want)
├── 📁 scripts/                 (REQUIRED: 1-Click automation engine)
├── 📁 client_assets/           (Drop logo.png & google-services.json here)
├── 📄 client_config.json       (Client configuration settings)
├── 📄 setup_new_client.bat     (1-Click launcher - double click to run)
└── 📄 firestore.rules          (Security rules to paste in Firebase)
```

> [!IMPORTANT]
> **Folder Names Are Flexible!** The smart engine auto-detects your app folders whether they are named `Rentlyo` / `Rentlyo Admin`, or `Rentlyo` / `Rentlyo Admin`, or anything with `admin` and non-admin.  
> **Always copy the `scripts/` folder!** It contains the pure-Dart engine that powers the 1-click launcher.

### ❌ Do NOT Copy (Delete before copying to save 4 GB):
* `build/` folders inside the apps.
* `.dart_tool/` folders inside the apps.
* `.git/` folder.

---

# PART 3: The 3-Step Setup (Zero to Live in 3 Minutes)

---

### Step 1: Create Firebase Backend (5 Clicks)

Go to [Firebase Console](https://console.firebase.google.com/):

1. **Click 1 — Create Project**:
   * Click **+ Add Project** $\rightarrow$ Name it (e.g. `client-lease`).
   * Turn **Google Analytics OFF** $\rightarrow$ Click **Create Project**.
2. **Click 2 — Enable Authentication**:
   * Left menu: **Build** $\rightarrow$ **Authentication** $\rightarrow$ **Get Started**.
   * Under *Sign-in method*, choose **Email/Password** $\rightarrow$ Enable the first toggle **ON** $\rightarrow$ **Save**.
3. **Click 3 — Create Firestore Database**:
   * Left menu: **Build** $\rightarrow$ **Firestore Database** $\rightarrow$ **Create Database**.
   * Pick **Production Mode** $\rightarrow$ Select your region (e.g. `asia-south1` or closest) $\rightarrow$ **Create**.
   * Click the **Rules** tab $\rightarrow$ Replace all contents with [`firestore.rules`](file:///c:/Users/aryn1/Documents/Rentlyo/firestore.rules) $\rightarrow$ Click **Publish**.
4. **Click 4 — Register Both Android Apps**:
   * Click the **Gear icon (Project Settings)** at top left $\rightarrow$ Scroll down to **Your apps** $\rightarrow$ Click the **Android** icon:
     * **App 1 (Admin)**: Package name = `com.client.admin` $\rightarrow$ Nickname = `Admin` $\rightarrow$ **Register app**.
     * **App 2 (Tenant)**: Click **+ Add app** $\rightarrow$ Android icon $\rightarrow$ Package name = `com.client.renter` $\rightarrow$ Nickname = `Tenant` $\rightarrow$ **Register app**.
5. **Click 5 — Download Configuration**:
   * Under **Your apps**, click on either registered app $\rightarrow$ Click **Download google-services.json**.

---

### Step 2: Drop Assets in `client_assets/`

Open the `client_assets/` folder in File Explorer and paste:
1. **`google-services.json`** *(the downloaded Firebase file)*
2. **`logo.png`** *(the client's app logo, square PNG)*
3. *(Optional)* **`banner.png`** *(horizontal property photo or banner)*

---

### Step 3: Edit `client_config.json`

Open `client_config.json` in Notepad and update the client's information:

```json
{
  "clientName": "Royal Complex",
  "brandName": "Royal Complex",
  "address": "Civil Lines, Jaipur, Rajasthan 302001",

  "renterAppName": "Rentlyo",
  "adminAppName": "Rentlyo Admin",

  "phone": "+91 93084 89230",
  "whatsapp": "+91 93084 89230",
  "supportEmail": "support@rentlyo.com",
  "ownerUpiId": "rentlyo@upi",

  "primaryColorHex": "044040",
  "accentColorHex": "C58B2B",

  "defaultPropertyId": "royal_complex",
  "ownerPhone": "9308489230",
  "ownerInitialPassword": "OwnerPassword@2026"
}
```

> [!TIP]
> You do **NOT** need to fill `firebaseProjectId` or `firebaseApiKey`! The 1-click setup engine auto-detects them directly from `client_assets/google-services.json` automatically!

---

### Step 4: Double-Click `setup_new_client.bat`

Double-click **`setup_new_client.bat`** in your project folder:

```text
============================================================
  Rentlyo Suite -- 1-Click Client Setup & Deployment
============================================================

  [1] 1-Click Complete Client Setup (Recommended)
      - Syncs client_config.json & distributes assets
      - Compiles launcher icons & native splash screens
      - Bootstraps Firebase Owner login & Firestore database

  [2] 1-Click Complete Setup & Build Release APKs
      - Runs Complete Setup + Compiles release APKs for both apps

  [3] Pre-Flight Diagnostics & Health Check
  [4] Interactive Terminal Questionnaire
  [5] Clean / Reset Database
  [6] Exit
============================================================
```

* **Press `1` and hit Enter**:
  In **15 seconds**, the engine automatically:
  - Distributes `google-services.json` to both apps
  - Copies and configures `logo.png` and `banner.png`
  - Rewrites `lib/core/app_config.dart` with brand values & colors
  - Updates package names and app labels in `AndroidManifest.xml` & `build.gradle`
  - Generates adaptive launcher icons and native splash screens
  - Creates the Owner account in Firebase Auth and seeds the Firestore database
  - Prints a full summary with green checkmarks!

---

### Step 5: Build Installable Release APKs

Either choose **`[2]`** in `setup_new_client.bat`, or build directly in terminal:

```powershell
# In Tenant App directory:
flutter build apk --release

# In Admin App directory:
flutter build apk --release
```

### Where to Find the Output APKs:
* 🛡️ **Admin App APK** (for Owner / Manager):  
  `[AdminFolder]/build/app/outputs/flutter-apk/app-release.apk`
* 📱 **Tenant App APK** (for Tenants / Renters):  
  `[TenantFolder]/build/app/outputs/flutter-apk/app-release.apk`

Both APKs will have the client's custom logo, splash screen, brand colors, app title, and will connect to their private Firebase backend!

---

# PART 4: Daily App Operations

### 4.1 Owner First Login & Quick PIN
1. Install the **Admin APK** on the owner's phone.
2. Log in using the **10-digit mobile number** and the **initial password** set in `client_config.json`.
3. Set a personal **6-digit unlock PIN** (e.g. `123456`).
4. On future opens, the app unlocks in 1 second via PIN or fingerprint!

---

### 4.2 Add Units & Onboard Tenants

Inside the **Admin App**:
1. **Add Rooms / Shops / Flats**:
   - Tap **"+"** on dashboard $\rightarrow$ **Add Unit**.
   - Specify unit name (e.g. `Shop 101`), floor, and type (`Commercial` or `Residential`).
2. **Add Lease Deal & Tenant**:
   - Tap **"+"** $\rightarrow$ **Add New Lease Deal**.
   - Enter tenant's 10-digit phone number, monthly rent, and security deposit.
   - Choose deposit mode:
     - *Adjust Against Rent*: Rent is automatically deducted from deposit each month.
     - *Refundable Security*: Deposit remains safe until move-out.
   - Tap **Create Contract**. The tenant account is live immediately!

---

### 4.3 Tenant App Features
1. Tenant downloads the **Tenant APK**.
2. Logs in with their **10-digit mobile number** and the password given by the owner.
3. Sets their personal 6-digit PIN.
4. **Features**:
   - Live rent balance and monthly billing statements.
   - **1-Click UPI Payment**: Tapping *"Pay Rent"* opens PhonePe, Google Pay, or Paytm with the owner's UPI and exact amount pre-filled!
   - Instant WhatsApp payment receipt generator.
   - Utility meter history and digital gate passes.

---

### 4.4 Multi-Property Management
If an owner operates multiple buildings (e.g. `Royal Complex` and `Royal Residency`):
1. In the top AppBar of the Admin app, tap the **Property Title**.
2. A dropdown of all owned properties appears.
3. Tap any property to switch context instantly.

---

# PART 5: Built-In Smart Engines

### 5.1 Rent & Advance Auto-Calculation Engine
* **Automatic Carryover**: Partial payments roll forward into overdue balance with 0 manual math.
* **Advance Adjustment**: If configured, monthly dues consume the advance balance before cash payments are requested.

### 5.2 Electricity & Water Sub-Meter Billing
* Enter Previous Reading and Current Reading $\rightarrow$ The engine multiplies units consumed by the rate per unit and adds the charge to the monthly statement automatically.

### 5.3 Live Cloud Re-Branding (No Recompiling)
* Go to Admin App $\rightarrow$ **Settings** $\rightarrow$ **Property Complex Details**.
* Change phone numbers, colors, or UPI ID $\rightarrow$ Save.
* All tenant apps reflect the new details in real time via Firestore cloud sync without installing an update!

### 5.4 In-App Over-The-Air (OTA) Updates
* Bump the version number in `pubspec.yaml` (e.g. `1.0.1+2`), build the APK, and run:
  ```powershell
  dart scripts/update_version.dart renter 1.0.1 2 1.0.0 "https://yourdownloadlink.com/app.apk" "New features added"
  ```
* All tenant phones will display a 1-tap update popup on next launch!

---

# PART 6: Troubleshooting & Reference

| Issue | Quick Solution |
| :--- | :--- |
| **"scripts folder not found"** | Make sure you copied the `scripts/` folder into your client workspace alongside `setup_new_client.bat`. |
| **"Blocked by Play Protect"** | Tap "More details" $\rightarrow$ "Install anyway" (standard for any direct APK install outside Play Store). |
| **"Owner login says User Not Found"** | Run `setup_new_client.bat` and press `1` to bootstrap the owner account in Firebase. |
| **"Need to change phone or logo"** | Update `client_config.json` (or replace `client_assets/logo.png`) and run `setup_new_client.bat` option `1`. |
| **"Screen shows 0 units"** | Tap the property title in the top AppBar of the Admin app to switch to the active property. |

---

<div align="center">

### 🚀 **Engineered for 1000% Production Reliability**
*Rentlyo • Universal White-Label Deployment Engine*

</div>
