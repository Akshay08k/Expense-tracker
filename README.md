<div align="center">

  <img src="assets/icon/app_icon.png" width="88" height="88" alt="FinFlow Logo" style="border-radius: 20px;" />

  # FinFlow

  **Smart Personal Finance Tracker with Living Spreadsheet Database Engine**

  An offline-first Flutter application that turns Google Sheets and Excel workbooks into an automated, zero-cost personal finance backend.

  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" /></a>
    <a href="#author--license"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square" alt="License: MIT" /></a>
    <a href="#"><img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=flat-square" alt="Platform" /></a>
    <a href="#"><img src="https://img.shields.io/badge/Version-v1.3.0-emerald?style=flat-square&color=059669" alt="Version v1.3.0" /></a>
  </p>

  <p>
    <a href="#overview">Overview</a> •
    <a href="#key-features">Key Features</a> •
    <a href="#architecture--tech-stack">Tech Stack</a> •
    <a href="#project-structure">Project Structure</a> •
    <a href="#getting-started">Getting Started</a> •
    <a href="#spreadsheet-database-setup">Spreadsheet Setup</a> •
    <a href="#changelog">Changelog</a>
  </p>

</div>

---

## Overview

**FinFlow** bridges the gap between lightweight mobile expense managers and robust spreadsheet workflows. Instead of locking your data inside proprietary cloud databases with recurring subscription fees, FinFlow treats spreadsheets as a **living, real-time database**.

Every entry, edit, or balance adjustment syncs seamlessly in the background to a dedicated Google Sheet via serverless Google Apps Script, complete with native charts, grouped monthly spend summaries, and executive KPI performance matrices. When offline, your data remains fully cached locally and safely backed up to `.xlsx` workbooks.

---

## Key Features

### Spreadsheets as a Living Database
- **Instant Background Sync**: Automatically updates Google Sheets in real-time when transactions or accounts are added, modified, or deleted without UI lag.
- **Dedicated Target Spreadsheet**: Automatically detects or initializes a dedicated file named `FinFlow_Expense_Tracker` in your Google Drive, preventing unintended overwrites.
- **Serverless Backend**: Powered by a 100% free Google Apps Script Web App — zero Firebase configuration, database hosting, or recurring API charges.
- **Excel (.xlsx) Generation**: Export and share fully formatted Excel workbooks containing summary dashboards, month-by-month sheets, and raw data tables.

### Executive Financial Intelligence
- **Embedded Visual Charts**:
  - Category Spend Donut / Pie Chart for immediate visual breakdown of major expenses.
  - Monthly Cashflow Column Chart tracking Income versus Expense over time.
- **Month-Wise Performance Matrix**: Automatically aggregates Total Income, Total Expense, Net Profit/Loss, Savings Rate %, Daily Average Spend, Peak Spend Day, and Top Expense Category.
- **Formatted Month-Ending Reports**: Monthly sheets feature grouped category spending tables (`Count`, `Total`, `% of Month`), burn rate KPI strips, color-coded badges (`INCOME`, `EXPENSE`, `TRANSFER`), zebra-striped rows, and frozen header rows.

### Personal Finance Management
- **Instant Payment Auto-Detection (Android)**: Captures payments in real-time from Google Pay, PhonePe, Paytm, CRED, BHIM, and bank push notifications. Pops up a prefilled sheet with Amount, Payee, and predicted Category so you can review and save in 1 tap.
- **Battery-Friendly & 100% Private**: Event-driven native Android listener that sleeps until a payment arrives (<0.1% daily battery). Never accesses or reads your SMS inbox, OTPs, or private chats.
- **Multi-Account & Wallet Support**: Manage distinct balances across Bank Accounts, Cash in Hand, and Savings or Emergency Funds with account-to-account transfer tracking.
- **Payment Mode Classification**: Tag payments by Cash, UPI (GPay, PhonePe, Paytm), Debit/Credit Cards, or Net Banking.
- **Complete Transaction Lifecycle**: Tap any record to edit amounts, dates, accounts, or categories with automatic account balance recalculation, or swipe to delete with instant balance restoration.
- **Cross-Device Data Migration**: Switch mobile devices effortlessly by pulling directly from your Google Sheet or importing an `.xlsx` backup in one tap.
- **Adaptive UI**: High-contrast, clean typography powered by Google Fonts with smooth dark and light mode transitions.

---

## Architecture & Tech Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (Dart 3.x) | Cross-platform mobile application framework |
| **State Management** | [Provider](https://pub.dev/packages/provider) | Centralized state container with debounced auto-sync |
| **Local Storage** | [shared_preferences](https://pub.dev/packages/shared_preferences) | Offline-first key-value persistence layer |
| **Excel Engine** | [excel](https://pub.dev/packages/excel) (v4.x) | Formatted `.xlsx` workbook generation and parsing |
| **File Handling** | [file_picker](https://pub.dev/packages/file_picker), [share_plus](https://pub.dev/packages/share_plus) | Document import, restore, and native share intents |
| **Cloud Integration** | Google Apps Script & [http](https://pub.dev/packages/http) | Serverless REST webhook synchronization |
| **Visualizations** | [fl_chart](https://pub.dev/packages/fl_chart) & Sheets API | In-app visual charts and native Sheets chart generation |
| **Typography** | [google_fonts](https://pub.dev/packages/google_fonts) | Clean, modern typography across platforms |

---

## Project Structure

```text
ExpenseTracker/
├── android/                        # Android native build files and manifests
├── ios/                            # iOS native build files and manifests
├── assets/                         # Application icons and branding assets
├── lib/
│   ├── models/                     # Data schemas (Account, Category, Transaction)
│   │   ├── account.dart
│   │   ├── category.dart
│   │   └── transaction.dart
│   ├── screens/                    # Core view screens
│   │   ├── accounts_screen.dart
│   │   ├── analytics_screen.dart
│   │   ├── home_screen.dart
│   │   ├── main_navigation.dart
│   │   ├── spreadsheet_sync_screen.dart # Cloud sync and backup control hub
│   │   └── transactions_screen.dart
│   ├── services/                   # Storage, export, and networking engines
│   │   ├── excel_service.dart      # .xlsx report generator and data parser
│   │   ├── google_sheets_service.dart # Real-time cloud sync client
│   │   ├── sample_data.dart
│   │   └── storage_service.dart
│   ├── state/
│   │   └── tracker_provider.dart   # App state and debounced sync controller
│   ├── theme/
│   │   └── app_colors.dart
│   ├── widgets/                    # Reusable modular UI components
│   │   ├── account_card.dart
│   │   ├── animated_summary_card.dart
│   │   ├── quick_add_sheet.dart    # Transaction creation and editing modal
│   │   ├── spending_chart.dart
│   │   └── transaction_tile.dart
│   └── main.dart                   # Application entrypoint
├── google_apps_script.js           # Production Google Apps Script backend engine
├── pubspec.yaml                    # Dependencies and package metadata
└── README.md
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.13.0`)
- Dart SDK (`>= 3.13.4`)
- Android Studio / VS Code with Flutter and Dart extensions
- An Android or iOS device / emulator

### Installation & Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Akshay08k/Expense-tracker.git
   cd Expense-tracker
   ```

2. **Fetch dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run automated test suite**:
   ```bash
   flutter test
   ```

4. **Launch application**:
   ```bash
   flutter run
   ```

---

## Spreadsheet Database Setup

FinFlow supports two flexible database options: **Live Google Sheets Cloud Sync** and **Offline Excel Backups**.

### Option A: Google Sheets Live Cloud Sync

Connect your app to a dedicated, automated Google Sheet stored safely in your own Google Drive.

#### 1. Deploy the Google Apps Script Web App
1. Navigate to [sheets.new](https://sheets.new) in your browser.
2. In the top toolbar, select **Extensions** > **Apps Script**.
3. Clear any existing code in `Code.gs`, then paste the entire contents of [`google_apps_script.js`](google_apps_script.js) (or tap **Copy Script** inside the app's Sync screen).
4. Click **Deploy** (top right) > **New deployment**.
5. Click the gear icon next to *Select type* and choose **Web app**.
6. Configure the deployment settings:
   - **Execute as**: `Me (your Google account)`
   - **Who has access**: `Anyone` *(Required for the mobile client to communicate with the endpoint)*
7. Click **Deploy**, complete the authorization prompt, and copy the generated **Web app URL** (`https://script.google.com/macros/s/.../exec`).

#### 2. Link with FinFlow
1. Open FinFlow and navigate to **Spreadsheet & Cloud DB** from the top bar.
2. Paste your Web app URL into the input field and tap the checkmark (`✔`) to save.
3. The app will immediately verify the connection and establish real-time background sync.

> [!NOTE]
> FinFlow automatically creates and isolates all data inside a dedicated spreadsheet file named `FinFlow_Expense_Tracker` in your Google Drive. Your other documents are never accessed or altered.

#### Operating Modes
- **Instant Auto-Sync**: Background sync triggers automatically when you create, edit, or delete a transaction.
- **Push to Cloud**: Manually force a full database refresh at any time.
- **Pull (New Phone)**: When installing on a new device, paste your Web app URL and tap **Pull (New Phone)** to instantly restore your entire transaction history and account balances.

---

### Option B: Local Excel (.xlsx) Backup & Restore

If you prefer keeping your data strictly local or sharing via external channels:

1. Tap the **Spreadsheet** icon in the top navigation bar.
2. Under **Excel (.xlsx) Workbook DB**, select **Export & Share**:
   - Generates an executive workbook containing the **Dashboard** (KPI cards, charts, performance matrix), **Month-Wise Sheets** (e.g., `Jan 2026`), and raw **All_Transactions** / **Accounts** data tables.
   - Use the native share sheet to save to local storage, Google Drive, or transfer via messaging apps.
3. **Restoring Data**: Select **Import & Restore**, choose your existing `.xlsx` file, and confirm to restore.

---

## Managing Transactions

- **Editing**: Tap any transaction tile in the **Home** or **All Transactions** view. A bottom sheet appears pre-populated with transaction details. Update amounts, categories, accounts, or dates, then tap **Update Transaction**. Account balances recalculate automatically.
- **Deleting**:
  - Swipe left on any transaction card in the list, or
  - Open the transaction editor and select the trash icon in the upper-right corner.

---

## Changelog

### v1.3.0
- **Instant Payment Auto-Detection (Android)**: Real-time background detection of UPI and card payment alerts (Google Pay, PhonePe, Paytm, CRED, BHIM, Amazon Pay, and banking apps) via native Android `NotificationListenerService`.
- **Pre-filled Transaction Prompt**: Automatically extracts Amount, Payee/Merchant name, and Timestamp, displaying an interactive heads-up notification that opens directly into a pre-filled entry sheet.
- **Smart Category Prediction**: Contextual keyword engine that automatically pre-selects the appropriate category (Food & Dining, Groceries, Transport, Bills, Shopping, Health, Entertainment) based on merchant names.
- **Privacy-First & Zero Battery Drain**: Operates on native OS event callbacks (<0.1% daily battery impact) and completely eliminates the security risks of SMS scraping (no SMS/OTP access required).
- **Payment Detection & Simulator Hub**: Dedicated management screen with live permission status, one-tap access to Android Notification Access settings, and built-in transaction simulators for testing.

### v1.2.0
- **Instant Cloud Auto-Sync Engine**: Non-blocking background sync to Google Sheets on every record creation, edit, or deletion with offline fallback.
- **Dedicated Target Spreadsheet**: Apps Script engine automatically binds to `FinFlow_Expense_Tracker` in Google Drive to eliminate container ambiguity.
- **Executive Dashboard with Visual Analytics**: Automated generation of native Google Sheets category distribution donut charts and monthly cashflow bar charts.
- **Month-Wise Performance Matrix**: Dynamic calculations for Profit, Loss, Savings Rate %, Daily Average Spend, Peak Spend Days, and Top Categories.
- **Grouped Category Spends**: Formatted monthly sheets featuring grouped spend tables, burn rate indicators, color-coded badges, and frozen header rows.

### v1.1.0
- **Transaction Editing**: In-place editing modal with automatic account balance recalculation.
- **Excel (.xlsx) Generator**: Multi-sheet workbook engine featuring dashboard summaries, month-by-month tabs, and master tables.
- **Two-Way Cloud Sync**: Initial release of Google Apps Script Web App sync and cross-device restoration.
- **Spreadsheet Hub**: Dedicated screen for managing local and cloud spreadsheet storage.

### v1.0.0
- Core income and expense logging.
- Multi-account management (Bank, Savings, Cash).
- Payment method classification (Cash, UPI, Cards, Net Banking).
- In-app visual charts and monthly analytics via `fl_chart`.
- Offline-first local persistence via `SharedPreferences`.
- Adaptive Dark and Light UI themes.

---

## Contributing

Contributions, feature suggestions, and bug reports are welcome.

1. Fork the repository (`https://github.com/Akshay08k/Expense-tracker/fork`)
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## Author & License

Developed by **Akshay Komade**  
- GitHub: [@Akshay08k](https://github.com/Akshay08k)  
- Email: [akshaykomade012345@gmail.com](mailto:akshaykomade012345@gmail.com)

Distributed under the **MIT License**.
