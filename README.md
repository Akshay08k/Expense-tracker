# <img src="assets/icon/app_icon.png" width="40" height="40" style="vertical-align: middle; border-radius: 10px;"/> FinFlow

> **Smart Expense & Spreadsheet Tracker**  
> A modern, offline-first personal finance management application built with **Flutter**. FinFlow gives you complete ownership of your financial data by turning **Spreadsheets into your Database** — generate formatted Excel (`.xlsx`) workbooks with month-wise sheets and financial KPI dashboards, or sync seamlessly to **Google Sheets** for effortless cross-device data migration without needing Firebase!

---

## 🌟 Key Highlights

- 📊 **Spreadsheet as a Database**: Store, export, and manage your data in structured Excel workbooks (`.xlsx`) with automated monthly sheets and KPI dashboards.
- 📱 **Seamless Phone Migration**: Easily switch mobile devices without data loss by importing your Excel workbook or pulling from your Google Sheet.
- ☁️ **Serverless Google Sheets Cloud Sync**: Real-time cloud sync using a lightweight, 100% free Google Apps Script Web App — **zero Firebase setup or maintenance required**.
- ✏️ **Full Transaction Editing & Management**: Easily tap any transaction to edit amounts, categories, accounts, payment modes, or dates with automatic balance recalculation.
- 💼 **Multi-Account & Wallet Tracking**: Separate balances for Bank Accounts, Savings & Emergency Funds, and Cash in Hand with account-to-account transfers.
- 💳 **Online & Offline Payment Modes**: Tag spending with Cash, UPI (GPay, PhonePe, Paytm), Debit/Credit Cards, or Net Banking.
- 📈 **Visual Analytics**: Interactive charts and spending breakdowns by category and payment method.
- 🌓 **Adaptive Dark & Light Themes**: Beautiful, modern UI with smooth transitions and glassmorphism accents.

---

## 🚀 App Architecture & Tech Stack

| Component | Technology |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (Dart 3.x) |
| **State Management** | [Provider](https://pub.dev/packages/provider) |
| **Local Storage** | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| **Excel Workbook Engine** | [excel](https://pub.dev/packages/excel) (v4.x) |
| **File Picker & Sharing** | [file_picker](https://pub.dev/packages/file_picker), [share_plus](https://pub.dev/packages/share_plus) |
| **Cloud Sync** | Google Apps Script Web App & [http](https://pub.dev/packages/http) |
| **Charts & Visualizations** | [fl_chart](https://pub.dev/packages/fl_chart) |
| **Typography** | [google_fonts](https://pub.dev/packages/google_fonts) |

---

## 📂 Project Directory Structure

```text
ExpenseTracker/
├── android/                    # Android native configuration
├── ios/                        # iOS native configuration
├── lib/
│   ├── models/                 # Account, Category, and Transaction models
│   │   ├── account.dart
│   │   ├── category.dart
│   │   └── transaction.dart
│   ├── screens/                # Main UI screens
│   │   ├── accounts_screen.dart
│   │   ├── analytics_screen.dart
│   │   ├── home_screen.dart
│   │   ├── main_navigation.dart
│   │   ├── spreadsheet_sync_screen.dart  # 📊 Spreadsheet & Cloud DB Hub
│   │   └── transactions_screen.dart
│   ├── services/               # Data & storage engines
│   │   ├── excel_service.dart            # 📑 .xlsx generator & parser
│   │   ├── google_sheets_service.dart    # ☁️ Cloud sync service
│   │   ├── sample_data.dart
│   │   └── storage_service.dart
│   ├── state/
│   │   └── tracker_provider.dart         # Global state & business logic
│   ├── theme/
│   │   └── app_colors.dart
│   ├── widgets/                # Modular UI widgets
│   │   ├── account_card.dart
│   │   ├── animated_summary_card.dart
│   │   ├── quick_add_sheet.dart          # ✏️ Add / Edit Transaction modal
│   │   ├── spending_chart.dart
│   │   └── transaction_tile.dart
│   └── main.dart               # App entrypoint
├── google_apps_script.js       # Ready-to-deploy Google Sheets backend script
├── pubspec.yaml                # Dependencies and metadata
└── README.md
```

---

## 🛠️ Getting Started

### Prerequisites

- Flutter SDK (v3.13.0 or later): [Install Flutter](https://docs.flutter.dev/get-started/install)
- Android Studio / VS Code with Flutter extension
- An Android or iOS device / emulator

### Installation & Launch

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Akshay08k/Expense-tracker.git
   cd Expense-tracker
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run tests**:
   ```bash
   flutter test
   ```

4. **Launch the application**:
   ```bash
   flutter run
   ```

---

## 📊 How to Use Spreadsheet as Database

### Option A: Local Excel (.xlsx) Database & File Backup

1. Open the app and tap the **Spreadsheet** icon (<kbd>📊</kbd>) in the top AppBar.
2. Under **Excel (.xlsx) Workbook DB**, tap **"Export & Share"**:
   - The app generates a formatted workbook containing:
     - **`📊 Dashboard`**: Summary KPI cards, category expense breakdown table, and payment mode distribution.
     - **Month-wise sheets** (e.g. `Sep 2026`, `Aug 2026`): Clean, chronological tables of that month's transactions with subtotals.
     - **`All_Transactions` & `Accounts`**: Master raw data for 100% lossless restoration.
   - The native share dialog opens — save directly to **Google Drive**, **WhatsApp**, or your local device storage.
3. **Restoring on a new phone**:
   - On your new mobile phone, tap **"Import & Restore"**, pick your exported `.xlsx` file, and tap **"Restore Data"**. All transactions and accounts are instantly restored!

---

### Option B: Google Sheets Live Cloud Sync (No Firebase!)

You can connect your app to a personal Google Sheet stored in your Google Drive:

#### 2-Minute Google Sheets Setup:
1. Open [sheets.new](https://sheets.new) in your browser to create a new Google Sheet.
2. In the top menu, go to **Extensions > Apps Script**.
3. Delete any default code in `Code.gs`, and paste the entire content of [`google_apps_script.js`](file:///d:/Projects/ExpenseTracker/google_apps_script.js).
4. Click the blue **Deploy** button (top right) > **New deployment**.
5. Click the gear icon next to "Select type" and select **Web app**.
6. Set:
   - **Execute as**: `Me (your google account)`
   - **Who has access**: `Anyone` *(Crucial for the mobile app to sync)*
7. Click **Deploy**, authorize permissions when prompted, and copy the **Web app URL** (`https://script.google.com/macros/s/.../exec`).
8. In the ExpenseTracker app, open the **Spreadsheet & Cloud DB** screen, paste the URL, and tap the checkmark (<kbd>✔</kbd>) to save.

#### How to Sync:
- **Push to Cloud**: Syncs all your transactions and accounts to your Google Sheet in real time.
- **Pull (New Phone)**: When you switch to a new mobile device, simply install the app, paste your Web App URL, and tap **"Pull (New Phone)"** to restore all your data!

---

## ✏️ How to Edit or Delete Transactions

- **To Edit**: Tap directly on any transaction tile in the **Home** or **All Transactions** screen. A sheet will slide up pre-filled with all details. Make your edits and tap **"Update Transaction"**. Account balances adjust automatically!
- **To Delete**: 
  - Swipe left on any transaction card in the list to delete with balance restoration, OR
  - Tap the transaction to open the editor and tap the trash icon (<kbd>🗑️</kbd>) at the top right.

---

## 📝 Changelog

### [v1.1.0] - 2026-09-27
#### Added
- **Transaction Editing**: Complete support for editing existing transactions (amount, category, source/destination accounts, payment modes, notes, date/time) with automatic balance recalculation.
- **Excel (.xlsx) Database Generator**:
  - `📊 Dashboard` tab with financial KPIs and category/payment breakdown.
  - Automatic **Month-Wise Sheets** (e.g. `Sep 2026`, `Aug 2026`).
  - Master data sheets for lossless backup.
  - Native file sharing (save to Google Drive, WhatsApp, Files).
  - Excel file importer for 1-tap data restoration.
- **Live Google Sheets Cloud Backend**:
  - Two-way sync via Google Apps Script Web App.
  - Cross-device data recovery ("Pull on New Phone") without Firebase.
  - Included `google_apps_script.js` template in workspace with in-app setup guide.
- **Spreadsheet & Cloud DB Screen**: Dedicated hub for managing Excel backups and cloud sync status.

#### Improved
- Added direct edit button and tap interaction to `TransactionTile`.
- Added visual spreadsheet access shortcut in `HomeScreen` and `TransactionsScreen` AppBars.
- Cleaned up analyzer warnings and verified test coverage.

---

### [v1.0.0] - Initial Release
- Core expense and income tracking.
- Multi-account management (Bank, Savings, Cash).
- Online UPI vs Offline Cash payment mode classification.
- Visual charts and monthly spending analytics.
- Offline-first local storage via SharedPreferences.
- Dark and Light theme toggle.

---

## 🏷️ Release Notes (v1.1.0)

> **Release**: ExpenseTracker v1.1.0  
> **Status**: Production Ready  
> **Highlight**: *Spreadsheet as Database & Full Transaction Editing*

This release addresses the two most requested features for ExpenseTracker:
1. **Full Transaction Editing**: You can now edit any logged transaction by simply tapping it. Changing the amount, account, or type automatically corrects account balances.
2. **Device Independence via Spreadsheets**: You no longer need to worry about losing data when switching phones! Use formatted `.xlsx` Excel exports with monthly sheets and dashboards, or connect directly to Google Sheets for instantaneous cloud sync without Firebase fees or setup complexities.

---

## 👤 Author & Contribution

Developed with ❤️ by **Akshay Komade**  
- **GitHub**: [@Akshay08k](https://github.com/Akshay08k)  
- **Email**: akshaykomade012345@gmail.com  

### Contributions
Contributions, issues, and feature requests are always welcome!
1. Fork the Project (`https://github.com/Akshay08k/Expense-tracker/fork`)
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
