# <img src="assets/icon/app_icon.png" width="40" height="40" style="vertical-align: middle; border-radius: 10px;"/> FinFlow

> **Smart Expense & Spreadsheet Tracker**  
> A modern, offline-first personal finance management application built with **Flutter**. FinFlow gives you complete ownership of your financial data by turning **Spreadsheets into your Living Database** — generate beautifully formatted Excel (`.xlsx`) workbooks and sync instantly in real-time to **Google Sheets** with embedded charts, category spend groupings, and executive month-wise performance matrices without needing Firebase!

---

## 🌟 Key Highlights

- ⚡ **Instant Real-Time Cloud Sync**: Automatically syncs transactions and accounts to Google Sheets in the background the moment you log, edit, or delete an entry — no manual sync button clicking needed!
- 🎯 **Dedicated Named Spreadsheet Target**: Cloud sync automatically creates and targets a dedicated spreadsheet named `FinFlow_Expense_Tracker` in your Google Drive, preventing unintended edits to other files.
- 📊 **Executive Dashboard with Embedded Charts**:
  - 🥧 Interactive Category Spend Pie/Donut Chart.
  - 📈 Monthly Cashflow Column Chart (Income vs Expense).
  - 📅 **Month-Wise Financial Performance Matrix**: Month, Total Income, Total Expense, Net Profit, Net Loss, Savings Rate %, Daily Avg Spend, Highest Spend Day, Top Spend Category, and Transaction Count.
  - 💎 High-Impact Financial KPI Hero Cards (Net Worth, Income, Expense, Net Savings, Savings Rate %).
- 📅 **Formatted Month-Ending Sheets with Grouped Spends**:
  - Grouped Category Spends Summary Table (Count, Total, % of Month).
  - Monthly Financial Overview & Burn Rate KPI strip.
  - Transaction Log with color-coded Type badges (`INCOME`, `EXPENSE`, `TRANSFER`), zebra striping, currency formatting, and frozen headers.
- 📱 **Seamless Phone Migration**: Easily switch mobile devices without data loss by importing your Excel workbook or pulling from your Google Sheet with 1 tap.
- ☁️ **Serverless Google Sheets Cloud Sync**: 100% free Google Apps Script Web App backend — **zero Firebase setup or recurring fees**.
- ✏️ **Full Transaction Editing & Management**: Tap any transaction to edit amounts, categories, accounts, payment modes, or dates with automatic balance recalculation.
- 💼 **Multi-Account & Wallet Tracking**: Separate balances for Bank Accounts, Savings & Emergency Funds, and Cash in Hand with account-to-account transfers.
- 💳 **Online & Offline Payment Modes**: Tag spending with Cash, UPI (GPay, PhonePe, Paytm), Debit/Credit Cards, or Net Banking.
- 🌓 **Adaptive Dark & Light Themes**: Modern UI with smooth transitions and glassmorphism accents.

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
| **Charts & Visualizations** | [fl_chart](https://pub.dev/packages/fl_chart) & Google Sheets Native Charts Engine |
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
│   │   ├── spreadsheet_sync_screen.dart  # 📊 Spreadsheet & Cloud DB Hub (Live Auto-Sync status)
│   │   └── transactions_screen.dart
│   ├── services/               # Data & storage engines
│   │   ├── excel_service.dart            # 📑 .xlsx generator & parser with Month-wise Matrix
│   │   ├── google_sheets_service.dart    # ☁️ Real-time Cloud sync service
│   │   ├── sample_data.dart
│   │   └── storage_service.dart
│   ├── state/
│   │   └── tracker_provider.dart         # Global state & debounced instant auto-sync logic
│   ├── theme/
│   │   └── app_colors.dart
│   ├── widgets/                # Modular UI widgets
│   │   ├── account_card.dart
│   │   ├── animated_summary_card.dart
│   │   ├── quick_add_sheet.dart          # ✏️ Add / Edit Transaction modal
│   │   ├── spending_chart.dart
│   │   └── transaction_tile.dart
│   └── main.dart               # App entrypoint
├── google_apps_script.js       # Production-ready Google Apps Script backend engine
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

### Option A: Google Sheets Live Cloud Sync (Instant & Real-Time)

You can connect your app to a dedicated Google Sheet stored in your Google Drive:

#### 2-Minute Google Sheets Setup:
1. Open [sheets.new](https://sheets.new) in your browser.
2. In the top menu, go to **Extensions > Apps Script**.
3. Delete any default code in `Code.gs`, and paste the entire content of [`google_apps_script.js`](google_apps_script.js) (or tap **"Copy Script"** in the app's Sync screen).
4. Click the blue **Deploy** button (top right) > **New deployment**.
5. Click the gear icon next to "Select type" and select **Web app**.
6. Set:
   - **Execute as**: `Me (your google account)`
   - **Who has access**: `Anyone` *(Crucial for the mobile app to sync)*
7. Click **Deploy**, authorize permissions when prompted, and copy the **Web app URL** (`https://script.google.com/macros/s/.../exec`).
8. In the ExpenseTracker app, open the **Spreadsheet & Cloud DB** screen, paste the URL, and tap the checkmark (<kbd>✔</kbd>) to save.

#### How Sync Operates:
- **⚡ Instant Auto-Sync**: Any time you log, update, or delete a transaction, or manage an account, the app automatically syncs in the background with zero lag.
- **Push to Cloud**: Manual 1-tap backup anytime you want to force an immediate refresh.
- **Pull (New Phone)**: When switching devices, install the app, paste your Web App URL, and tap **"Pull (New Phone)"** to restore your entire database in seconds!

---

### Option B: Local Excel (.xlsx) Database & File Backup

1. Open the app and tap the **Spreadsheet** icon (<kbd>📊</kbd>) in the top AppBar.
2. Under **Excel (.xlsx) Workbook DB**, tap **"Export & Share"**:
   - The app generates a formatted workbook containing:
     - **`📊 Dashboard`**: Summary KPI cards, Category Spend Breakdown, and Month-Wise Financial Performance Matrix.
     - **Month-wise sheets** (e.g. `Jan 2026`, `Feb 2026`): Grouped category spend summary and chronological transaction log.
     - **`All_Transactions` & `Accounts`**: Master raw data for 100% lossless restoration.
   - The native share dialog opens — save directly to **Google Drive**, **WhatsApp**, or local device storage.
3. **Restoring on a new phone**:
   - Tap **"Import & Restore"**, select your `.xlsx` file, and tap **"Restore Data"**.

---

## ✏️ How to Edit or Delete Transactions

- **To Edit**: Tap directly on any transaction tile in the **Home** or **All Transactions** screen. A sheet will slide up pre-filled with all details. Make your edits and tap **"Update Transaction"**. Account balances adjust automatically!
- **To Delete**: 
  - Swipe left on any transaction card in the list to delete with balance restoration, OR
  - Tap the transaction to open the editor and tap the trash icon (<kbd>🗑️</kbd>) at the top right.

---

## 📝 Changelog

### [v1.2.0] - 2026-10-02
#### Added
- **⚡ Instant Real-Time Auto-Sync Engine**:
  - Transactions and accounts now automatically sync to Google Sheets in the background whenever an item is created, edited, or deleted.
  - Implemented debounced, non-blocking synchronization so UI interaction remains ultra-responsive and works fully offline.
  - Added live `⚡ Instant Auto-Sync active` indicator banner in the Spreadsheet Sync screen.
- **🎯 Dedicated Target Spreadsheet File (`FinFlow_Expense_Tracker`)**:
  - Google Apps Script now automatically discovers or creates a dedicated spreadsheet named `FinFlow_Expense_Tracker` in Google Drive.
  - Eliminates accidental logging into random active sheets or container spreadsheets.
- **📊 Executive Dashboard with Embedded Visual Analytics**:
  - **Embedded Pie / Donut Chart**: Native Google Sheets chart visualizing expense distribution by category.
  - **Embedded Cashflow Bar Chart**: Month-by-month Income vs Expense comparison.
  - **Month-Wise Financial Performance Matrix**:
    - Month Name
    - Total Income
    - Total Expense
    - Total Profit (Net positive gain)
    - Total Loss (Net overspending deficit)
    - Savings Rate %
    - Daily Average Spend
    - Highest Spend Day (date & amount)
    - Top Spend Category (category & amount)
    - Transaction Count
- **📅 Formatted Month-Ending Sheets with Grouped Spends**:
  - Month Overview Banner & KPI strip (Income, Expense, Net, Daily Avg, Entries count).
  - **Grouped Spends by Category Summary Table**: Category name, count of transactions, total amount spent, and % share of monthly expenses.
  - Filterable Transaction Log with color-coded type badges (`INCOME`, `EXPENSE`, `TRANSFER`), currency formatting, zebra striping, and frozen headers.
- **Clean & Focused Spreadsheets**: Removed all keyboard shortcut cheatsheets and jump links for a clean, distraction-free executive financial workbook.

---

### [v1.1.0] - 2026-09-27
#### Added
- **Transaction Editing**: Complete support for editing existing transactions with automatic balance recalculation.
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

---

### [v1.0.0] - Initial Release
- Core expense and income tracking.
- Multi-account management (Bank, Savings, Cash).
- Online UPI vs Offline Cash payment mode classification.
- Visual charts and monthly spending analytics.
- Offline-first local storage via SharedPreferences.
- Dark and Light theme toggle.

---

## 🏷️ Release Notes (v1.2.0)

> **Release**: FinFlow v1.2.0  
> **Status**: Production Ready  
> **Highlight**: *Instant Cloud Auto-Sync & Executive Spreadsheet Intelligence*

This release transforms FinFlow into an autonomous, real-time financial tracking operating system:
1. **Instant Real-Time Auto-Sync**: No more manual pressing of the sync button! Any transaction added, edited, or removed immediately updates your Google Sheet in the background.
2. **Executive Financial Dashboard**: Your Google Sheet now automatically builds embedded interactive Pie and Column charts, plus a complete Month-Wise Financial Performance Matrix tracking Profit, Loss, Savings Rate, Top Spend Categories, and Highest Spend Days.
3. **Monthly Sheets with Grouped Spends**: Each month-ending sheet now includes a clean category spending summary table alongside the formatted, color-badged transaction logs.
4. **Dedicated Cloud Database Target**: All your data is cleanly isolated in `FinFlow_Expense_Tracker` in your Google Drive.

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
