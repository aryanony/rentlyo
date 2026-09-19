<div align="center">

<img src="assets/rentlyo-hor.png" alt="Rentlyo" width="400">

<br><br>

**Complete White-Label Property Management Suite**
<br>
*Leases, ledgers, tenants, and properties in one synchronized workspace.*

<br>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-0097A7?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-00838F?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-00695C?style=for-the-badge&logo=firebase&logoColor=white)](https://firebase.google.com/)
[![Platform](https://img.shields.io/badge/Platform-Android-26A69A?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com/)
[![License](https://img.shields.io/badge/License-Proprietary-37474F?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJ3aGl0ZSI+PHBhdGggZD0iTTEyIDJDNi40OCAyIDIgNi40OCAyIDEyczQuNDggMTAgMTAgMTAgMTAtNC40OCAxMC0xMFMxNy41MiAyIDEyIDJ6bTAgMThjLTQuNDEgMC04LTMuNTktOC04czMuNTktOCA4LTggOCAzLjU5IDggOC0zLjU5IDgtOCA4eiIvPjxwYXRoIGQ9Ik0xMiA2Yy0zLjMxIDAtNiAyLjY5LTYgNnMyLjY5IDYgNiA2IDYtMi42OSA2LTYtMi42OS02LTYtNnoiLz48L3N2Zz4=&logoColor=white)](#license)

<br>

[Get Started](#-quick-start) · [Architecture](#-system-architecture) · [Deploy a Client](#-client-onboarding--white-label-setup) · [Website](https://rentlyo.cscouncil.in/)

<br>

---

</div>

<br>

## The Rentlyo Ecosystem

> **One platform. Two focused apps. One synchronized property workspace.**
>
> Built for commercial shops, residential flats, rooms, beds, and mixed-use properties where owners need reliable rent operations and tenants need a clear, trustworthy lease portal.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'secondaryColor': '#E0F7FA', 'tertiaryColor': '#B2EBF2', 'fontSize': '14px'}}}%%
flowchart LR
    A["<b>Configure</b><br/>Property Setup"] --> B["<b>Create</b><br/>Unit Inventory"]
    B --> C["<b>Build</b><br/>Lease Deal"]
    C --> D["<b>Onboard</b><br/>Tenant"]
    D --> E["<b>Track</b><br/>Rent & Utilities"]
    E --> F["<b>Reconcile</b><br/>Payments"]
    F --> G["<b>Report</b><br/>Notify & Audit"]
    G -.->|"Continuous<br/>Cycle"| E

    style A fill:#006064,color:#FFFFFF,stroke:#004D40,stroke-width:2px
    style B fill:#00838F,color:#FFFFFF,stroke:#006064,stroke-width:2px
    style C fill:#0097A7,color:#FFFFFF,stroke:#00838F,stroke-width:2px
    style D fill:#00ACC1,color:#FFFFFF,stroke:#0097A7,stroke-width:2px
    style E fill:#00BCD4,color:#004D40,stroke:#00ACC1,stroke-width:2px
    style F fill:#26C6DA,color:#004D40,stroke:#00BCD4,stroke-width:2px
    style G fill:#4DD0E1,color:#004D40,stroke:#26C6DA,stroke-width:2px
```

<br>

---

## Table of Contents

<table>
<tr>
<td width="50%" valign="top">

#### Platform
- [The Rentlyo Ecosystem](#the-rentlyo-ecosystem)
- [What Rentlyo Includes](#-what-rentlyo-includes)
- [Why It Is Different](#-why-it-is-different)
- [Product Capabilities](#-product-capabilities)

#### Architecture
- [System Architecture](#-system-architecture)
- [Technology Stack](#-technology-stack)
- [Repository Layout](#-repository-layout)
- [Security Model](#-security-model)

</td>
<td width="50%" valign="top">

#### Operations
- [Quick Start](#-quick-start)
- [Client Onboarding & White-Label Setup](#-client-onboarding--white-label-setup)
- [Firebase Setup](#-firebase-setup)
- [Application Workflows](#-application-workflows)

#### Engineering
- [Financial & Operational Engines](#-financial--operational-engines)
- [Build & Release](#-build--release)
- [Testing](#-testing)
- [Production Checklist](#-production-checklist)
- [Troubleshooting](#-troubleshooting)

</td>
</tr>
</table>

<br>

---

## What Rentlyo Includes

<table>
<tr>
<td width="33%" valign="top">

### Tenant App

*Private lease and rent companion for renters, shopkeepers, and residential occupants.*

| Feature | |
|:---|:---:|
| Live dashboard with current dues | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Agreement and deal summary | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Rent schedules with step-up tiers | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Full payment and installment ledger | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Partial-payment & advance tracking | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| One-tap UPI payment handoff | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Payment receipt via WhatsApp | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Utility bill & sub-meter history | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Digital gate passes | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Push notifications & reminders | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| Secure PIN unlock | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |
| In-app update notifications | ![check](https://img.shields.io/badge/-%E2%9C%93-00BCD4?style=flat-square) |

</td>
<td width="33%" valign="top">

### Admin Console

*Focused operating console for property owners, managers, and accounting staff.*

| Feature | |
|:---|:---:|
| Dashboard occupancy overview | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Commercial & residential units | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Multi-unit deal creation | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Tenant onboarding wizard | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Lease & escalation tiers | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Advance deposit management | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Auto ledger rebalancing | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Electricity & water billing | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| PDF, CSV, and Excel reports | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Multi-property switching | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| OTA release management | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |
| Owner PIN authentication | ![check](https://img.shields.io/badge/-%E2%9C%93-00838F?style=flat-square) |

</td>
<td width="33%" valign="top">

### White-Label Engine

*Reusable deployment layer for new properties, brands, or clients.*

| Feature | |
|:---|:---:|
| Central `client_config.json` | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Auto Firebase project discovery | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Brand name, colors, contacts | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Client logo & banner distribution | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Android package synchronization | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Adaptive icon generation | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Native splash screen generation | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Firebase owner bootstrap | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Firestore seed & verification | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Pre-flight diagnostics | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Dual release APK compilation | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |
| Database cleaning utility | ![check](https://img.shields.io/badge/-%E2%9C%93-006064?style=flat-square) |

</td>
</tr>
</table>

<br>

---

## Why It Is Different

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'secondaryColor': '#E0F7FA', 'tertiaryColor': '#B2EBF2'}}}%%
mindmap
  root((Rentlyo))
    Real Rent Lifecycle
      Not disconnected screens
      Two views of one ledger
      Complete operational model
    Real-Time by Default
      Firestore streams
      Instant synchronization
      Live balance updates
    White-Label Ready
      Configuration-driven
      One workspace, many clients
      Branded app generation
    Mixed-Use Properties
      Commercial and residential
      Multi-unit consolidation
      Isolated unit types
    Financial Clarity
      Advance consumption
      Partial payment carryover
      Automatic reconciliation
```

<details>
<summary><b>Built around the real rent lifecycle</b></summary>
<br>

Rentlyo models the relationship between a property, its units, a lease deal, a tenant, an advance balance, monthly rent, payment records, utilities, and notices. The apps are not disconnected screens; they are **two views of the same operational ledger**.

</details>

<details>
<summary><b>Real-time by default</b></summary>
<br>

Firestore streams keep deal information, advance top-ups, notices, payment states, and property branding synchronized between the admin and tenant experiences. Changes propagate instantly without manual refresh.

</details>

<details>
<summary><b>White-label at the configuration layer</b></summary>
<br>

A new client can receive branded applications **without rebuilding the product architecture**. The setup engine distributes assets, rewrites generated configuration, prepares Firebase connectivity, and can build both release APKs from one workspace.

</details>

<details>
<summary><b>Designed for mixed-use properties</b></summary>
<br>

Commercial and residential inventory can coexist while remaining separated during onboarding and vacancy selection. Multi-unit deals can be consolidated without losing unit-level occupancy state.

</details>

<details>
<summary><b>Financial clarity over manual arithmetic</b></summary>
<br>

The shared rent engine handles advance consumption, partial payments, overdue carryover, rent escalations, and payment status reconciliation so owners and tenants see the same outcome.

</details>

<br>

---

## Product Capabilities

<table>
<tr>
<th align="left">Capability</th>
<th align="center">Tenant App</th>
<th align="center">Admin Console</th>
</tr>
<tr><td><b>Live rent balance</b></td><td align="center"><img src="https://img.shields.io/badge/-View-00BCD4?style=flat-square" alt="View"></td><td align="center"><img src="https://img.shields.io/badge/-View-00838F?style=flat-square" alt="View"></td></tr>
<tr><td><b>Lease and deal terms</b></td><td align="center"><img src="https://img.shields.io/badge/-View-00BCD4?style=flat-square" alt="View"></td><td align="center"><img src="https://img.shields.io/badge/-Manage-00838F?style=flat-square" alt="Manage"></td></tr>
<tr><td><b>Advance balance and top-ups</b></td><td align="center"><img src="https://img.shields.io/badge/-View-00BCD4?style=flat-square" alt="View"></td><td align="center"><img src="https://img.shields.io/badge/-Manage-00838F?style=flat-square" alt="Manage"></td></tr>
<tr><td><b>Payment ledger</b></td><td align="center"><img src="https://img.shields.io/badge/-View%20%26%20Report-00BCD4?style=flat-square" alt="View & Report"></td><td align="center"><img src="https://img.shields.io/badge/-Review%20%26%20Confirm-00838F?style=flat-square" alt="Review & Confirm"></td></tr>
<tr><td><b>Rent escalation tiers</b></td><td align="center"><img src="https://img.shields.io/badge/-View-00BCD4?style=flat-square" alt="View"></td><td align="center"><img src="https://img.shields.io/badge/-Configure-00838F?style=flat-square" alt="Configure"></td></tr>
<tr><td><b>Unit inventory</b></td><td align="center"><img src="https://img.shields.io/badge/-Context-00BCD4?style=flat-square" alt="Context"></td><td align="center"><img src="https://img.shields.io/badge/-Manage-00838F?style=flat-square" alt="Manage"></td></tr>
<tr><td><b>Tenant onboarding</b></td><td align="center"><img src="https://img.shields.io/badge/-%E2%80%94-546E7A?style=flat-square" alt="N/A"></td><td align="center"><img src="https://img.shields.io/badge/-Wizard-00838F?style=flat-square" alt="Wizard"></td></tr>
<tr><td><b>Maintenance requests</b></td><td align="center"><img src="https://img.shields.io/badge/-Create%20%26%20Track-00BCD4?style=flat-square" alt="Create & Track"></td><td align="center"><img src="https://img.shields.io/badge/-Manage-00838F?style=flat-square" alt="Manage"></td></tr>
<tr><td><b>Utility billing</b></td><td align="center"><img src="https://img.shields.io/badge/-View%20History-00BCD4?style=flat-square" alt="View History"></td><td align="center"><img src="https://img.shields.io/badge/-Calculate%20%26%20Publish-00838F?style=flat-square" alt="Calculate & Publish"></td></tr>
<tr><td><b>Notices and announcements</b></td><td align="center"><img src="https://img.shields.io/badge/-Read-00BCD4?style=flat-square" alt="Read"></td><td align="center"><img src="https://img.shields.io/badge/-Create%20%26%20Manage-00838F?style=flat-square" alt="Create & Manage"></td></tr>
<tr><td><b>Gate passes and visitor logs</b></td><td align="center"><img src="https://img.shields.io/badge/-Use-00BCD4?style=flat-square" alt="Use"></td><td align="center"><img src="https://img.shields.io/badge/-Manage-00838F?style=flat-square" alt="Manage"></td></tr>
<tr><td><b>Multi-property switching</b></td><td align="center"><img src="https://img.shields.io/badge/-Contextual-00BCD4?style=flat-square" alt="Contextual"></td><td align="center"><img src="https://img.shields.io/badge/-Full%20Control-00838F?style=flat-square" alt="Full Control"></td></tr>
<tr><td><b>PDF/CSV/Excel reporting</b></td><td align="center"><img src="https://img.shields.io/badge/-%E2%80%94-546E7A?style=flat-square" alt="N/A"></td><td align="center"><img src="https://img.shields.io/badge/-Export-00838F?style=flat-square" alt="Export"></td></tr>
<tr><td><b>Release update management</b></td><td align="center"><img src="https://img.shields.io/badge/-Receive-00BCD4?style=flat-square" alt="Receive"></td><td align="center"><img src="https://img.shields.io/badge/-Publish-00838F?style=flat-square" alt="Publish"></td></tr>
</table>

<br>

---

## System Architecture

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'secondaryColor': '#E0F7FA', 'tertiaryColor': '#FFFFFF', 'fontSize': '14px'}}}%%
flowchart TB
  subgraph CLOUD["<b>Firebase Cloud</b>"]
    direction LR
    AUTH["Authentication<br/><sub>Phone + Email/Password</sub>"]
    DB[("Cloud Firestore<br/><sub>Real-time Database</sub>")]
    PUSH["Cloud Messaging<br/><sub>Push Notifications</sub>"]
    RULES["Security Rules<br/><sub>Role-based Access</sub>"]
  end

  subgraph APPS["<b>Mobile Applications</b>"]
    direction LR
    ADMIN["Rentlyo Admin<br/><sub>Owner Console</sub>"]
    TENANT["Rentlyo Tenant<br/><sub>Renter Companion</sub>"]
  end

  subgraph OPS["<b>White-Label Operations</b>"]
    direction LR
    CONFIG["client_config.json<br/><sub>Brand Configuration</sub>"]
    SETUP["setup_client.dart<br/><sub>Deployment Engine</sub>"]
    RELEASE["Build Tools<br/><sub>APK Compilation</sub>"]
  end

  ADMIN <-->|"Auth & Streams"| AUTH
  ADMIN <-->|"Read / Write"| DB
  ADMIN -->|"Send"| PUSH
  TENANT <-->|"Auth & Streams"| AUTH
  TENANT <-->|"Scoped Read / Write"| DB
  PUSH -->|"Deliver"| TENANT
  RULES -. "protects" .-> DB
  CONFIG --> SETUP
  SETUP -->|"Configure"| ADMIN
  SETUP -->|"Configure"| TENANT
  RELEASE -->|"Build"| ADMIN
  RELEASE -->|"Build"| TENANT

  style CLOUD fill:#E0F7FA,color:#004D40,stroke:#00838F,stroke-width:2px
  style APPS fill:#B2EBF2,color:#004D40,stroke:#00838F,stroke-width:2px
  style OPS fill:#E0F2F1,color:#004D40,stroke:#00838F,stroke-width:2px
  style AUTH fill:#00838F,color:#FFFFFF,stroke:#006064,stroke-width:2px
  style DB fill:#006064,color:#FFFFFF,stroke:#004D40,stroke-width:2px
  style PUSH fill:#0097A7,color:#FFFFFF,stroke:#00838F,stroke-width:2px
  style RULES fill:#004D40,color:#FFFFFF,stroke:#00363D,stroke-width:2px
  style ADMIN fill:#00ACC1,color:#FFFFFF,stroke:#0097A7,stroke-width:2px
  style TENANT fill:#26C6DA,color:#004D40,stroke:#00ACC1,stroke-width:2px
  style CONFIG fill:#80CBC4,color:#004D40,stroke:#4DB6AC,stroke-width:2px
  style SETUP fill:#4DB6AC,color:#FFFFFF,stroke:#26A69A,stroke-width:2px
  style RELEASE fill:#26A69A,color:#FFFFFF,stroke:#009688,stroke-width:2px
```

<details>
<summary><b>Data Flow Principles</b></summary>
<br>

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'actorBkg': '#00838F', 'actorTextColor': '#FFFFFF', 'actorBorder': '#006064', 'activationBkgColor': '#E0F7FA', 'activationBorderColor': '#00838F', 'signalColor': '#00ACC1', 'fontSize': '14px'}}}%%
sequenceDiagram
    participant O as Owner
    participant A as Admin Console
    participant F as Firebase
    participant T as Tenant App

    rect rgba(0, 131, 143, 0.08)
        Note over O,T: Property & Lease Setup
        O->>A: Create unit and lease deal
        A->>F: Write deal, unit, and tenant records
        F-->>A: Stream updated operational state
        F-->>T: Stream tenant-authorized deal data
    end

    rect rgba(0, 188, 212, 0.08)
        Note over O,T: Payment Lifecycle
        T->>F: Report payment or request maintenance
        F-->>A: Notify owner of new activity
        A->>F: Confirm payment or publish notice
        F-->>T: Refresh balance, status, and notification
    end

    rect rgba(38, 198, 218, 0.08)
        Note over O,T: Continuous Operations
        O->>A: Manage advances, utilities, notices
        A->>F: Update operational records
        F-->>T: Real-time sync to tenant view
    end
```

**Five core principles drive the data flow:**

1. An owner creates properties, units, and lease deals in the Admin Console.
2. Firestore stores the **canonical operational state**.
3. The Tenant App reads only the tenant's permitted records through **authenticated streams**.
4. Payment, advance, utility, notice, and occupancy changes appear in both apps **in real time**.
5. Firestore rules enforce owner access and tenant ownership boundaries **at the database layer**.

</details>

<br>

---

## Technology Stack

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'secondaryColor': '#E0F7FA'}}}%%
block-beta
    columns 3

    block:CLIENT["Client Applications"]:3
        columns 3
        Flutter["Flutter 3.x"]
        Dart["Dart 3.x"]
        Material["Material Design"]
        FCM["Cloud Messaging"]
        LocalNoti["Local Notifications"]
        SecStore["Secure Storage"]
        Fonts["Google Fonts"]
        URLLaunch["URL Launcher"]
        Reports["PDF / CSV / Excel"]
    end

    block:BACKEND["Backend & Infrastructure"]:3
        columns 3
        FBAuth["Firebase Auth"]
        Firestore["Cloud Firestore"]
        FBRules["Security Rules"]
        PhoneMap["Phone-to-Email Mapping"]
        Streams["Real-time Streams"]
        APKHost["APK Hosting"]
    end

    block:TOOLS["Operations & Tooling"]:3
        columns 3
        DartCLI["Dart CLI Scripts"]
        WinPS["PowerShell Launchers"]
        WinBat["Batch Launchers"]
        Icons["Adaptive Icons"]
        Splash["Native Splash"]
        Config["JSON Configuration"]
    end

    style CLIENT fill:#E0F7FA,color:#004D40,stroke:#00838F,stroke-width:2px
    style BACKEND fill:#B2EBF2,color:#004D40,stroke:#00838F,stroke-width:2px
    style TOOLS fill:#E0F2F1,color:#004D40,stroke:#00838F,stroke-width:2px
    style Flutter fill:#00838F,color:#FFFFFF,stroke:#006064
    style Dart fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style Material fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style FCM fill:#00BCD4,color:#004D40,stroke:#00ACC1
    style LocalNoti fill:#26C6DA,color:#004D40,stroke:#00BCD4
    style SecStore fill:#4DD0E1,color:#004D40,stroke:#26C6DA
    style Fonts fill:#80DEEA,color:#004D40,stroke:#4DD0E1
    style URLLaunch fill:#B2EBF2,color:#004D40,stroke:#80DEEA
    style Reports fill:#E0F7FA,color:#004D40,stroke:#B2EBF2
    style FBAuth fill:#006064,color:#FFFFFF,stroke:#004D40
    style Firestore fill:#00838F,color:#FFFFFF,stroke:#006064
    style FBRules fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style PhoneMap fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style Streams fill:#00BCD4,color:#004D40,stroke:#00ACC1
    style APKHost fill:#26C6DA,color:#004D40,stroke:#00BCD4
    style DartCLI fill:#004D40,color:#FFFFFF,stroke:#00363D
    style WinPS fill:#00695C,color:#FFFFFF,stroke:#004D40
    style WinBat fill:#00796B,color:#FFFFFF,stroke:#00695C
    style Icons fill:#00897B,color:#FFFFFF,stroke:#00796B
    style Splash fill:#009688,color:#FFFFFF,stroke:#00897B
    style Config fill:#26A69A,color:#FFFFFF,stroke:#009688
```

> The current release configuration is optimized for **Android APK distribution**. The Flutter projects can target additional platforms with standard Flutter tooling, but platform-specific Firebase configuration, signing, and release validation must be completed first.

<br>

---

## Repository Layout

```
Rentlyo/
├── Rentlyo/                            Tenant-facing Flutter application
│   ├── lib/
│   │   ├── core/                       App configuration and shared services
│   │   ├── models/                     Tenant-side data models
│   │   ├── screens/                    Tenant experience screens
│   │   ├── services/                   Firebase, ledger, notification, update services
│   │   └── widgets/                    Reusable tenant UI components
│   ├── assets/images/                  Tenant branding assets
│   ├── android/                        Android project and Firebase configuration
│   ├── test/                           Tenant tests
│   └── pubspec.yaml                    Tenant dependencies
│
├── Rentlyo Admin/                      Owner and property-manager Flutter application
│   ├── lib/
│   │   ├── core/                       Admin configuration and shared services
│   │   ├── models/                     Admin-side data models
│   │   ├── screens/                    Admin workflows and dashboards
│   │   ├── services/                   Firebase, reports, auth, ledger services
│   │   └── widgets/                    Reusable admin UI components
│   ├── assets/images/                  Admin branding assets
│   ├── android/                        Android project and Firebase configuration
│   ├── test/                           Admin tests
│   └── pubspec.yaml                    Admin dependencies
│
├── scripts/                            Dart automation tools
│   ├── setup_client.dart               Client deployment engine
│   ├── bootstrap_admin.dart            Owner auth bootstrap
│   ├── clean_database.dart             Test-data purge utility
│   └── update_version.dart             Firestore-backed release publisher
│
├── client_assets/                      Client logo and Firebase config
├── assets/                             Shared image assets and logos
├── client_config.json                  White-label configuration source
├── firestore.rules                     Firestore authorization rules
├── setup_new_client.bat                Windows one-click launcher
├── setup_new_client.ps1                PowerShell launcher
└── MASTER_PRODUCTION_AND_CLIENT_DEPLOYMENT_GUIDE.md
```

> Build output folders such as `build/` and `.dart_tool/` are generated artifacts. Do not copy them into a new client workspace or commit them to source control.

<br>

---

## Quick Start

### Prerequisites

| Requirement | Version |
|:---|:---|
| ![Windows](https://img.shields.io/badge/Windows-10+-0097A7?style=flat-square&logo=windows&logoColor=white) | 10 or later |
| ![Flutter](https://img.shields.io/badge/Flutter-3.x-00838F?style=flat-square&logo=flutter&logoColor=white) | SDK with Dart 3.x |
| ![Android](https://img.shields.io/badge/Android_Studio-Latest-006064?style=flat-square&logo=androidstudio&logoColor=white) | Android Studio + SDK |
| ![Firebase](https://img.shields.io/badge/Firebase-Project-004D40?style=flat-square&logo=firebase&logoColor=white) | Auth + Firestore enabled |
| ![Git](https://img.shields.io/badge/Git-Recommended-37474F?style=flat-square&logo=git&logoColor=white) | For source control |

**Verify the toolchain:**

```powershell
flutter doctor
flutter --version
dart --version
```

### Step-by-Step

<details>
<summary><b>1. Fetch dependencies</b></summary>

```powershell
cd "Rentlyo"
flutter pub get

cd "..\Rentlyo Admin"
flutter pub get
```

</details>

<details>
<summary><b>2. Configure Firebase</b></summary>

Place the correct Firebase Android configuration in each app's Android module, or place a source copy at:

```
client_assets/google-services.json
```

The deployment tooling can distribute the Firebase configuration to both applications.

</details>

<details>
<summary><b>3. Run the apps</b></summary>

**Tenant application:**
```powershell
cd "Rentlyo"
flutter run
```

**Admin application:**
```powershell
cd "..\Rentlyo Admin"
flutter run
```

</details>

<details>
<summary><b>4. Run tests</b></summary>

```powershell
cd "Rentlyo"
flutter test

cd "..\Rentlyo Admin"
flutter test
```

</details>

<br>

---

## Client Onboarding & White-Label Setup

Rentlyo is structured so a new client or property can be prepared from one workspace.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'fontSize': '14px'}}}%%
flowchart LR
    subgraph INPUT["<b>Client Inputs</b>"]
        direction TB
        GS["google-services.json"]
        LOGO["logo.png"]
        BANNER["banner.png<br/><sub>optional</sub>"]
        CFG["client_config.json"]
    end

    subgraph ENGINE["<b>Setup Engine</b>"]
        direction TB
        DETECT["Detect Firebase Project"]
        DIST["Distribute Assets"]
        BRAND["Apply Branding"]
        PKG["Update Package IDs"]
        ICON["Generate Icons & Splash"]
        BOOT["Bootstrap Owner"]
        SEED["Seed Firestore"]
    end

    subgraph OUTPUT["<b>Deliverables</b>"]
        direction TB
        APK_A["Admin APK"]
        APK_T["Tenant APK"]
        FB["Live Firebase Backend"]
    end

    INPUT --> ENGINE --> OUTPUT

    style INPUT fill:#E0F7FA,color:#004D40,stroke:#00838F,stroke-width:2px
    style ENGINE fill:#B2EBF2,color:#004D40,stroke:#00838F,stroke-width:2px
    style OUTPUT fill:#E0F2F1,color:#004D40,stroke:#00838F,stroke-width:2px
    style GS fill:#00838F,color:#FFFFFF,stroke:#006064
    style LOGO fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style BANNER fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style CFG fill:#00BCD4,color:#004D40,stroke:#00ACC1
    style DETECT fill:#006064,color:#FFFFFF,stroke:#004D40
    style DIST fill:#00838F,color:#FFFFFF,stroke:#006064
    style BRAND fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style PKG fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style ICON fill:#00BCD4,color:#004D40,stroke:#00ACC1
    style BOOT fill:#26C6DA,color:#004D40,stroke:#00BCD4
    style SEED fill:#4DD0E1,color:#004D40,stroke:#26C6DA
    style APK_A fill:#00838F,color:#FFFFFF,stroke:#006064
    style APK_T fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style FB fill:#006064,color:#FFFFFF,stroke:#004D40
```

<details>
<summary><b>Required client inputs</b></summary>
<br>

Place the following in `client_assets/`:

```
client_assets/
├── google-services.json     # Firebase Android configuration
├── logo.png                 # Square client logo
└── banner.png               # Optional property banner
```

Update `client_config.json` with the new client's:
- Property and brand identity
- App names and taglines
- Address and support contacts
- Owner UPI ID
- Primary, secondary, accent, and background colors
- Firebase project settings
- Default property ID and currency
- Owner bootstrap phone and initial password
- Android package identifiers

</details>

<details>
<summary><b>Launcher operations</b></summary>
<br>

From the repository root:

```powershell
.\setup_new_client.ps1
```

| Option | Operation |
|:---:|:---|
| `1` | Complete client setup, asset distribution, branding, Firebase bootstrap |
| `2` | Complete setup and build both release APKs |
| `3` | Pre-flight diagnostics and health check |
| `4` | Interactive configuration questionnaire |
| `5` | Clean or reset test data while retaining the owner account |
| `6` | Exit |

</details>

<details>
<summary><b>Direct Dart commands</b></summary>
<br>

```powershell
# Complete setup
dart scripts/setup_client.dart

# Complete setup plus both release APKs
dart scripts/setup_client.dart --all

# Verify keys, assets, package identifiers, and connectivity
dart scripts/setup_client.dart --verify

# Configure a client interactively
dart scripts/setup_client.dart --interactive
```

</details>

For the full operational walkthrough, read [MASTER_PRODUCTION_AND_CLIENT_DEPLOYMENT_GUIDE.md](MASTER_PRODUCTION_AND_CLIENT_DEPLOYMENT_GUIDE.md).

<br>

---

## Firebase Setup

<details>
<summary><b>Fresh client backend setup</b></summary>
<br>

1. Create a Firebase project.
2. Enable Email/Password authentication.
3. Create a Cloud Firestore database in production mode.
4. Publish the rules from [firestore.rules](firestore.rules).
5. Register the Admin and Tenant Android applications.
6. Download `google-services.json`.
7. Place it in `client_assets/` and run the verification or setup command.

</details>

<details>
<summary><b>Authentication model</b></summary>
<br>

Rentlyo uses an internal pseudo-email mapping so users can sign in with a mobile number and password while using Firebase Email/Password authentication:

```
9876543210  -->  9876543210@rentlyo.local
```

The mapping is an implementation detail. The user experience remains a mobile-number login, while Firebase handles authentication and token issuance.

</details>

<details>
<summary><b>Core Firestore collections</b></summary>
<br>

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'fontSize': '13px'}}}%%
erDiagram
    USERS ||--o{ DEALS : "linked via renter"
    PROPERTIES ||--o{ UNITS : contains
    UNITS ||--o{ DEALS : "leased through"
    DEALS ||--o{ PAYMENT_RECORDS : generates
    DEALS ||--o{ UTILITY_BILLS : incurs
    PROPERTIES ||--o{ NOTICES : publishes
    USERS ||--o{ MAINTENANCE_REQUESTS : creates
    USERS ||--o{ GATE_PASSES : uses
    PROPERTIES ||--o{ VISITOR_LOGS : records
    PROPERTIES ||--o{ APP_VERSIONS : tracks

    USERS {
        string uid PK
        string role
        string phone
        string propertyId FK
    }
    PROPERTIES {
        string id PK
        string name
        string address
        object branding
    }
    UNITS {
        string id PK
        string type
        string status
        string propertyId FK
    }
    DEALS {
        string id PK
        number rent
        number deposit
        array escalationTiers
    }
    PAYMENT_RECORDS {
        string id PK
        string status
        number amount
        timestamp date
    }
```

| Collection | Purpose |
|:---|:---|
| `users` | Owner and tenant profiles, roles, and renter relationships |
| `properties` | Property identity, branding, contacts, and configuration |
| `units` | Shops, flats, rooms, beds, and occupancy state |
| `deals` | Lease terms, rent schedules, deposits, and tenant links |
| `paymentRecords` | Monthly rent records, installments, and payment states |
| `maintenanceRequests` | Tenant issues and owner resolution workflows |
| `notices` | Property-wide and tenant-facing announcements |
| `utilityBills` | Electricity and water sub-meter charges |
| `gatePasses` | Digital tenant and visitor passes |
| `visitorLogs` | Entry and exit activity |
| `messMenus` | Optional mess or canteen menu data |
| `notifications` | User-targeted alerts and notification state |
| `appVersions` | Latest version, minimum version, download URL, and notes |

</details>

<br>

---

## Application Workflows

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'fontSize': '13px'}}}%%
flowchart TB
    subgraph OWNER["<b>Owner Workflow</b>"]
        direction TB
        O1["Firebase Setup<br/>& Bootstrap"] --> O2["Sign In<br/>Admin Console"]
        O2 --> O3["Set Personal<br/>6-Digit PIN"]
        O3 --> O4["Create Properties<br/>& Units"]
        O4 --> O5["Add Lease Deal<br/>via Wizard"]
        O5 --> O6["Choose Inventory<br/>Commercial / Residential"]
        O6 --> O7["Configure Rent<br/>Deposit & Tiers"]
        O7 --> O8["Share Tenant<br/>Credentials"]
        O8 --> O9["Confirm Payments<br/>Manage & Report"]
    end

    subgraph TENANT_FLOW["<b>Tenant Workflow</b>"]
        direction TB
        T1["Install<br/>Tenant App"] --> T2["Sign In<br/>with Credentials"]
        T2 --> T3["Set Personal<br/>6-Digit PIN"]
        T3 --> T4["Review Dashboard<br/>& Agreement"]
        T4 --> T5["Pay via UPI<br/>or Report Offline"]
        T5 --> T6["Review Utilities<br/>Notices & Receipts"]
    end

    O8 -.->|"Credentials"| T1

    style OWNER fill:#E0F7FA,color:#004D40,stroke:#00838F,stroke-width:2px
    style TENANT_FLOW fill:#E0F2F1,color:#004D40,stroke:#00838F,stroke-width:2px
    style O1 fill:#006064,color:#FFFFFF,stroke:#004D40
    style O2 fill:#00838F,color:#FFFFFF,stroke:#006064
    style O3 fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style O4 fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style O5 fill:#00BCD4,color:#004D40,stroke:#00ACC1
    style O6 fill:#26C6DA,color:#004D40,stroke:#00BCD4
    style O7 fill:#4DD0E1,color:#004D40,stroke:#26C6DA
    style O8 fill:#80DEEA,color:#004D40,stroke:#4DD0E1
    style O9 fill:#B2EBF2,color:#004D40,stroke:#80DEEA
    style T1 fill:#00838F,color:#FFFFFF,stroke:#006064
    style T2 fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style T3 fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style T4 fill:#00BCD4,color:#004D40,stroke:#00ACC1
    style T5 fill:#26C6DA,color:#004D40,stroke:#00BCD4
    style T6 fill:#4DD0E1,color:#004D40,stroke:#26C6DA
```

<details>
<summary><b>Multi-unit and multi-property workflow</b></summary>
<br>

- Multi-unit deals are consolidated under one active lease while each selected unit remains represented in occupancy data.
- Secondary units in a consolidated deal are marked occupied and removed from vacant selection.
- Commercial and residential unit types remain isolated during onboarding.
- Owners can switch property context from the Admin Console without maintaining separate application installations.

</details>

<br>

---

## Financial & Operational Engines

### Rent & Advance Reconciliation

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'fontSize': '13px'}}}%%
stateDiagram-v2
    [*] --> DueGenerated : Monthly cycle starts

    DueGenerated --> ConfirmedPaid : Full payment confirmed
    DueGenerated --> AdjustedAgainstAdvance : Advance covers dues
    DueGenerated --> PendingConfirmation : Payment reported
    DueGenerated --> Overdue : Due date passed

    PendingConfirmation --> ConfirmedPaid : Owner confirms
    PendingConfirmation --> ConfirmedPartial : Partial confirmed

    ConfirmedPartial --> Overdue : Remaining balance overdue
    Overdue --> ConfirmedPaid : Full settlement

    ConfirmedPaid --> [*]
    AdjustedAgainstAdvance --> [*]

    classDef good fill:#00838F,color:#FFFFFF,stroke:#006064
    classDef pending fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    classDef warn fill:#F57F17,color:#FFFFFF,stroke:#E65100
    classDef neutral fill:#E0F7FA,color:#004D40,stroke:#00838F

    class ConfirmedPaid good
    class AdjustedAgainstAdvance good
    class PendingConfirmation pending
    class ConfirmedPartial pending
    class Overdue warn
    class DueGenerated neutral
```

<details>
<summary><b>Engine capabilities</b></summary>
<br>

The shared rent engine supports:
- Monthly due calculation
- Partial-payment carryover
- Overdue balance accumulation
- Advance balance consumption
- Advance top-ups
- Payment status reconciliation
- Rent step-up tiers over time
- Current-period settlement visibility

</details>

<details>
<summary><b>Utility billing formula</b></summary>
<br>

For electricity and water sub-meters:

```
units consumed = current reading - previous reading
utility charge  = units consumed x rate per unit
monthly total   = rent + utility charge + applicable adjustments
```

The Admin Console can publish utility charges while the Tenant App exposes the resulting history and statement context.

</details>

<details>
<summary><b>Notification logic</b></summary>
<br>

Automated notification logic can:
- Notify tenants about the rent cycle
- Reflect whether rent is paid, partially paid, overdue, or covered by advance
- Remove obsolete overdue alerts after settlement
- Publish owner-authored property notices
- Deliver app release prompts when a newer version is available

</details>

<details>
<summary><b>Live property branding</b></summary>
<br>

Property-level settings can be stored in Firestore so contact details, UPI information, and selected branding values can be reflected through cloud configuration. Changes affect the tenant experience immediately and must be tested carefully in production.

</details>

<br>

---

## Security Model

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#00838F', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#006064', 'lineColor': '#00ACC1', 'fontSize': '13px'}}}%%
flowchart TB
    subgraph ACCESS["<b>Access Control Matrix</b>"]
        direction TB

        subgraph OWNER_PERMS["<b>Owner Permissions</b>"]
            OP1["Manage properties & units"]
            OP2["Create & edit deals"]
            OP3["Confirm payments"]
            OP4["Publish notices & utilities"]
            OP5["Administrative record deletion"]
        end

        subgraph TENANT_PERMS["<b>Tenant Permissions</b>"]
            TP1["Read own records only"]
            TP2["Create payment reports"]
            TP3["Submit maintenance requests"]
            TP4["Use gate passes"]
            TP5["No deletion rights"]
        end

        subgraph PUBLIC_PERMS["<b>Public Access</b>"]
            PP1["Property configuration"]
            PP2["App version checks"]
            PP3["No operational data"]
        end
    end

    style ACCESS fill:#FFFFFF,color:#004D40,stroke:#00838F,stroke-width:2px
    style OWNER_PERMS fill:#006064,color:#FFFFFF,stroke:#004D40,stroke-width:2px
    style TENANT_PERMS fill:#00838F,color:#FFFFFF,stroke:#006064,stroke-width:2px
    style PUBLIC_PERMS fill:#0097A7,color:#FFFFFF,stroke:#00838F,stroke-width:2px
    style OP1 fill:#004D40,color:#FFFFFF,stroke:#00363D
    style OP2 fill:#006064,color:#FFFFFF,stroke:#004D40
    style OP3 fill:#00838F,color:#FFFFFF,stroke:#006064
    style OP4 fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style OP5 fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style TP1 fill:#00838F,color:#FFFFFF,stroke:#006064
    style TP2 fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style TP3 fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style TP4 fill:#00BCD4,color:#004D40,stroke:#00ACC1
    style TP5 fill:#26C6DA,color:#004D40,stroke:#00BCD4
    style PP1 fill:#0097A7,color:#FFFFFF,stroke:#00838F
    style PP2 fill:#00ACC1,color:#FFFFFF,stroke:#0097A7
    style PP3 fill:#00BCD4,color:#004D40,stroke:#00ACC1
```

Review [firestore.rules](firestore.rules) before every production deployment. Security rules are part of the application boundary, not an optional deployment detail.

<details>
<summary><b>Credential and secret handling</b></summary>
<br>

> **Do not commit real credentials, private keys, owner passwords, or client Firebase configuration to a public repository.**

Before publishing this project publicly:

1. Remove or rotate any real Firebase API keys and owner credentials present in local configuration.
2. Keep client-specific `google-services.json` files private.
3. Add local-only configuration files to `.gitignore` where appropriate.
4. Use a sanitized example configuration for documentation and onboarding.
5. Change bootstrap passwords immediately after first owner login.
6. Treat database reset and bootstrap commands as privileged operations.
7. Validate Firestore rules with a separate test Firebase project before production rollout.

Firebase web API keys are not substitutes for access control. Authentication, Firestore rules, package signing, and operational credential hygiene must all be maintained.

</details>

<br>

---

## Build & Release

<details>
<summary><b>Debug builds</b></summary>

```powershell
cd "Rentlyo"
flutter build apk --debug

cd "..\Rentlyo Admin"
flutter build apk --debug
```

</details>

<details>
<summary><b>Release builds</b></summary>

```powershell
cd "Rentlyo"
flutter build apk --release

cd "..\Rentlyo Admin"
flutter build apk --release
```

Or from the root launcher:

```powershell
.\setup_new_client.ps1
# Choose option 2
```

</details>

<details>
<summary><b>APK locations</b></summary>

```
Rentlyo/build/app/outputs/flutter-apk/app-release.apk
Rentlyo Admin/build/app/outputs/flutter-apk/app-release.apk
```

</details>

<details>
<summary><b>Pre-distribution checklist</b></summary>
<br>

- [ ] App label and package ID are correct
- [ ] Client logo and splash screen are correct
- [ ] Firebase project is the intended client project
- [ ] Release is signed with the correct key
- [ ] Login works for both owner and tenant roles
- [ ] Firestore rules reject unauthorized reads and writes
- [ ] UPI, WhatsApp, notifications, file downloads, and update prompts work on a real device

</details>

### In-App Updates

Publish a release with:

```powershell
dart scripts/update_version.dart `
  rentlyo_renter `
  1.0.1 `
  2 `
  1.0.0 `
  "https://github.com/OWNER/REPOSITORY/releases/download/v1.0.1/renter.apk" `
  "Bug fixes and improvements"
```

For the Admin Console, use `rentlyo_admin` as the app ID:

```powershell
dart scripts/update_version.dart rentlyo_admin 1.0.1 2 1.0.0 "https://example.com/admin.apk" "Release notes"
```

<details>
<summary><b>Version document fields</b></summary>
<br>

The command authenticates as the owner and updates the release document with:

- Latest semantic version
- Build number
- Minimum required version
- APK download URL
- Release notes

Only publish URLs that are stable, accessible to the intended users, and protected by your release process.

</details>

<br>

---

## Database Operations

The database cleaner is intended for development, demo, and test reset scenarios.

```powershell
# Interactive reset
dart scripts/clean_database.dart

# Keep units while cleaning transactional records
dart scripts/clean_database.dart --keep-units

# Non-interactive reset (controlled environment only)
dart scripts/clean_database.dart --force
```

> The reset operation can remove deals, payment records, units, maintenance requests, utility bills, gate passes, visitor logs, menus, notifications, notices, and non-owner user profiles. **Confirm the target Firebase project before running it.**

<br>

---

## Testing

```powershell
# Tenant tests
cd "Rentlyo"
flutter test

# Admin tests
cd "..\Rentlyo Admin"
flutter test
```

<details>
<summary><b>Test coverage areas</b></summary>
<br>

- Rent and advance calculation
- Model behavior
- Security-related model constraints
- Unit-type separation
- Widget behavior
- Admin workflows

For production releases, supplement unit and widget tests with a real-device acceptance pass against a non-production Firebase project.

</details>

<br>

---

## Troubleshooting

| Symptom | Resolution |
|:---|:---|
| `setup_client.dart` not found | Run the launcher from the repository root; keep `scripts/` beside the launcher. |
| Dart or Flutter not found | Install Flutter, add to `PATH`, run `flutter doctor`. |
| Owner login fails | Run complete setup or bootstrap flow; verify Firebase project and owner credentials. |
| Firebase project mismatch | Replace `client_assets/google-services.json`, verify `client_config.json`, run `--verify`. |
| No units appear | Check property context in Admin Console; verify unit documents in Firestore. |
| Wrong branding appears | Update `client_config.json` and assets, then re-run client setup. |
| APK cannot install | Check Android signing, package ID, device compatibility, and Play Protect warnings. |
| Updates do not appear | Verify `appVersions` document, minimum version, APK URL, and Firestore read rules. |
| Reset command blocked | Use interactive confirmation or provide `--force` only after verifying target project. |

**Run the pre-flight check first:**

```powershell
dart scripts/setup_client.dart --verify
```

<br>

---

## Production Checklist

<details>
<summary><b>Configuration</b></summary>

- [ ] Client name, brand name, property ID, address, and currency are correct.
- [ ] App names, taglines, colors, logo, and optional banner are correct.
- [ ] Support phone, WhatsApp number, email, and UPI ID are correct.
- [ ] Firebase project and Android package identifiers are correct.

</details>

<details>
<summary><b>Backend</b></summary>

- [ ] Email/Password authentication is enabled.
- [ ] Firestore is in the intended region and mode.
- [ ] Current [firestore.rules](firestore.rules) are published.
- [ ] Owner bootstrap completed successfully.
- [ ] No test tenant records remain.
- [ ] No client secrets are exposed in source control.

</details>

<details>
<summary><b>Application</b></summary>

- [ ] Owner login and PIN unlock work.
- [ ] Tenant login and PIN unlock work.
- [ ] Commercial/residential unit separation works.
- [ ] Multi-unit deal occupancy is correct.
- [ ] Rent, advance, partial payment, and overdue calculations are correct.
- [ ] Utility billing and receipts are correct.
- [ ] Notices, notifications, maintenance, gate passes, and visitor logs work.
- [ ] UPI and WhatsApp handoffs work on a real device.
- [ ] Release APKs are signed and versioned.
- [ ] Update metadata points to the correct artifacts.

</details>

<br>

---

## Documentation

| Document | Description |
|:---|:---|
| [Master Production & Deployment Guide](MASTER_PRODUCTION_AND_CLIENT_DEPLOYMENT_GUIDE.md) | Full operational walkthrough |
| [Tenant Application README](Rentlyo/README.md) | Screen-level feature notes |
| [Admin Console README](Rentlyo%20Admin/README.md) | Admin workflow details |
| [Firestore Security Rules](firestore.rules) | Role-based access definitions |
| [Client Configuration](client_config.json) | White-label config source |

<br>

---

## License

This project is **private and proprietary software** unless a separate written license says otherwise. The source code, branding, configuration, deployment scripts, Firebase rules, and generated client applications may not be redistributed, resold, or deployed for another party without authorization from the project owner.

<br>

---

<div align="center">

<img src="assets/rentlyo-icon.png" alt="Rentlyo" width="64">

<br><br>

**Rentlyo**

*Clear leases. Reliable ledgers. Better property operations.*

Built as a complete, configurable property-management platform for the real world.

<br>

[![Website](https://img.shields.io/badge/Website-rentlyo.cscouncil.in-00838F?style=for-the-badge&logo=googlechrome&logoColor=white)](https://rentlyo.cscouncil.in/)

<br>

<sub>Built with Flutter, Firebase, and Dart</sub>

</div>
