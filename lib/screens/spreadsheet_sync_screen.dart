import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/excel_service.dart';
import '../services/google_sheets_service.dart';
import '../state/tracker_provider.dart';
import '../theme/app_colors.dart';

class SpreadsheetSyncScreen extends StatefulWidget {
  const SpreadsheetSyncScreen({super.key});

  @override
  State<SpreadsheetSyncScreen> createState() => _SpreadsheetSyncScreenState();
}

class _SpreadsheetSyncScreenState extends State<SpreadsheetSyncScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isPushing = false;
  bool _isPulling = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TrackerProvider>();
    if (provider.googleSheetsUrl != null) {
      _urlController.text = provider.googleSheetsUrl!;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String _formatSyncTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Never synced';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 'Never synced';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Future<void> _handleExportExcel() async {
    setState(() => _isExporting = true);
    final provider = context.read<TrackerProvider>();

    try {
      final result = await ExcelService.exportAndShare(
        transactions: provider.transactions,
        accounts: provider.accounts,
        currency: provider.currency,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Generated Excel workbook with ${result.monthCount} monthly sheets and ${result.transactionCount} transactions!',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel file: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImportExcel() async {
    setState(() => _isImporting = true);
    final provider = context.read<TrackerProvider>();

    try {
      final importResult = await ExcelService.pickAndImportExcel();

      if (importResult == null) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      if (importResult.transactions.isEmpty && importResult.accounts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No transactions or accounts found in the selected Excel file.'),
              backgroundColor: AppColors.expense,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore from Excel?'),
          content: Text(
            'Found ${importResult.transactions.length} transactions and ${importResult.accounts.length} accounts in "${importResult.fileName}".\n\nThis will restore this data to your device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore Data', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        await provider.restoreData(
          transactions: importResult.transactions,
          accounts: importResult.accounts.isNotEmpty ? importResult.accounts : null,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully restored ${importResult.transactions.length} transactions and ${importResult.accounts.length} accounts!',
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing Excel: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _handleSaveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      await context.read<TrackerProvider>().clearGoogleSheetsUrl();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sheets URL cleared')),
        );
      }
      return;
    }

    if (!url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL starting with https://')),
      );
      return;
    }

    await context.read<TrackerProvider>().setGoogleSheetsUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sheets URL saved successfully'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _handlePushGoogleSheets() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Google Apps Script Web App URL')),
      );
      return;
    }

    setState(() => _isPushing = true);
    final provider = context.read<TrackerProvider>();

    try {
      await provider.setGoogleSheetsUrl(url);
      final result = await provider.pushToGoogleSheets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppColors.income : AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPushing = false);
    }
  }

  Future<void> _handlePullGoogleSheets() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Google Apps Script Web App URL to pull data')),
      );
      return;
    }

    setState(() => _isPulling = true);
    final provider = context.read<TrackerProvider>();

    try {
      await provider.setGoogleSheetsUrl(url);
      final result = await provider.pullFromGoogleSheets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppColors.income : AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPulling = false);
    }
  }

  void _showSetupGuideModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Google Sheets Setup Guide',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStep(
                        '1',
                        'Create a Google Spreadsheet',
                        'Go to sheets.new in your browser to create a new spreadsheet. Name it "Expense Tracker".',
                      ),
                      _buildStep(
                        '2',
                        'Open Apps Script',
                        'In Google Sheets top menu, click Extensions > Apps Script.',
                      ),
                      _buildStep(
                        '3',
                        'Paste Backend Code',
                        'Delete any code in the editor, and click "Copy Apps Script Code" below, then paste it in Code.gs.',
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: GoogleSheetsService.appsScriptCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Apps Script copied to clipboard! Also saved in google_apps_script.js'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Google Apps Script Code'),
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        '4',
                        'Deploy as Web App',
                        'Click Deploy (blue button top right) > New deployment > Select type "Web app". Set Execute as "Me", and Who has access to "Anyone". Click Deploy.',
                      ),
                      _buildStep(
                        '5',
                        'Paste URL in App',
                        'Copy the Web App URL that Google gives you, paste it here, and tap "Push Data to Google Sheets".',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.income.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.income.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_android_rounded, color: AppColors.income, size: 28),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'When switching to a new phone, simply install this app, paste your Web App URL, and tap "Pull Data" to restore everything!',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(
              number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = provider.isGoogleSheetsConnected;
    final lastSyncStr = _formatSyncTime(provider.lastSheetsSync);

    // Calculate unique months
    final monthSet = provider.transactions
        .map((t) => DateFormat('MMM yyyy').format(t.dateTime))
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Spreadsheet & Cloud DB',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF047857).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spreadsheet as Database',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'No Firebase needed • Full data ownership',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Export to formatted Excel (.xlsx) with month-wise sheets & dashboard KPIs, or sync live to Google Sheets for seamless multi-device access.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // SECTION 1: EXCEL (.XLSX) DATABASE
            Row(
              children: [
                const Icon(Icons.description_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Excel (.xlsx) Workbook DB',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${provider.transactions.length} txs • ${monthSet.length} months',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Workbook Architecture:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureBullet('📊 1. Dashboard Tab', 'Overall financial KPIs, Category expense breakdown table, and payment modes.'),
                  _buildFeatureBullet('📅 2. Month-Wise Tabs', 'Dedicated tab for every month (${monthSet.take(3).join(", ")}...) with headers & formulas.'),
                  _buildFeatureBullet('💾 3. Lossless Restore Sheet', 'All transactions master log with UUIDs and Accounts structure.'),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Export Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isExporting ? null : _handleExportExcel,
                          icon: _isExporting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.share_rounded, size: 18),
                          label: Text(
                            _isExporting ? 'Exporting...' : 'Export & Share',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Import Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isImporting ? null : _handleImportExcel,
                          icon: _isImporting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.file_open_rounded, size: 18, color: Color(0xFF10B981)),
                          label: Text(
                            _isImporting ? 'Importing...' : 'Import & Restore',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // SECTION 2: GOOGLE SHEETS CLOUD SYNC
            Row(
              children: [
                const Icon(Icons.cloud_sync_rounded, size: 22, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                const Text(
                  'Live Google Sheets Sync',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showSetupGuideModal(context),
                  icon: const Icon(Icons.help_outline_rounded, size: 16),
                  label: const Text('Setup Guide', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? AppColors.income : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isConnected ? 'Connected to Google Sheets' : 'Not Connected',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isConnected ? AppColors.income : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Last sync: $lastSyncStr',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // URL Input Field
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'https://script.google.com/macros/s/.../exec',
                      labelText: 'Google Apps Script Web App URL',
                      labelStyle: const TextStyle(fontSize: 12.5),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.primary),
                        tooltip: 'Save URL',
                        onPressed: _handleSaveUrl,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Push and Pull buttons
                  Row(
                    children: [
                      // Push to Cloud
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isPushing ? null : _handlePushGoogleSheets,
                          icon: _isPushing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: Text(
                            _isPushing ? 'Pushing...' : 'Push to Cloud',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Pull from Cloud (Restore on new phone!)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isPulling ? null : _handlePullGoogleSheets,
                          icon: _isPulling
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_download_rounded, size: 18, color: Color(0xFF0284C7)),
                          label: Text(
                            _isPulling ? 'Pulling...' : 'Pull (New Phone)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
