import 'package:flutter/material.dart';
import '../models/package.dart';
import '../database/database_helper.dart';
import '../services/backup_service.dart';
import '../widgets/add_package_dialog.dart';
import 'package_options_page.dart';
import 'study_later_page.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> with WidgetsBindingObserver {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final BackupService _backupService = BackupService();
  List<Package> _packages = [];
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPackages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh packages when app is resumed
      _loadPackages();
    }
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final packages = await _databaseHelper.getAllPackages();
      setState(() {
        _packages = packages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading packages: $e'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _addPackage() async {
    final result = await showDialog<Package>(
      context: context,
      builder: (context) => const AddPackageDialog(),
    );

    if (result != null) {
      try {
        await _databaseHelper.insertPackage(result);
        await _loadPackages();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Package added successfully!'),
            backgroundColor: const Color(0xFF8DC71D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding package: $e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _deletePackage(Package package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Package'),
        content: Text('Are you sure you want to delete "${package.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deletePackage(package.id!);
        await _loadPackages();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Package deleted successfully!'),
            backgroundColor: const Color(0xFF8DC71D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting package: $e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF8DC71D)),
            SizedBox(width: 16),
            Expanded(child: Text('Preparing backup file...')),
          ],
        ),
      ),
    );

    try {
      final summary = await _backupService.exportToUserLocation();
      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${summary.packageCount} packages, '
            '${summary.wordCount} words.\n'
            'Keep this .json file outside the app (e.g. Downloads).',
          ),
          backgroundColor: const Color(0xFF8DC71D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on BackupValidationException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showImportDialog() async {
    if (_isBusy) return;

    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.file_upload, color: Color(0xFF8DC71D)),
            SizedBox(width: 8),
            Text('Import Backup'),
          ],
        ),
        content: const Text(
          'Choose how to apply the backup file.\n\n'
          '• Merge: keep existing data, add missing packages/words\n'
          '• Replace all: delete current data, then import\n\n'
          'The file is checked with a checksum before writing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImportMode.merge),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImportMode.replaceAll),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Replace all'),
          ),
        ],
      ),
    );

    if (mode == null) return;

    if (mode == ImportMode.replaceAll) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Replace all data?'),
          content: const Text(
            'This permanently deletes all packages and words on this device, '
            'then loads the backup. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete & import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isBusy = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF8DC71D)),
            SizedBox(width: 16),
            Expanded(child: Text('Validating and importing...')),
          ],
        ),
      ),
    );

    try {
      final result = await _backupService.importFromUserPick(mode: mode);
      if (mounted) Navigator.of(context).pop();
      await _loadPackages();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == ImportMode.replaceAll
                ? 'Replaced: ${result.packagesCreated} packages, '
                    '${result.wordsAdded} words '
                    '(learned/study-later marks restored).'
                : 'Merged: ${result.wordsAdded} added, '
                    '${result.wordsUpdated} updated '
                    '(marks & fields kept), '
                    '${result.exportedWordCount} in file.',
          ),
          backgroundColor: const Color(0xFF8DC71D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on BackupValidationException catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      if (e.message == 'Import cancelled.') return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showRestoreDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.blue),
            SizedBox(width: 8),
            Text('Restore Data'),
          ],
        ),
        content: const Text(
          'This will attempt to restore your data from backup locations. '
          'This is useful if your data was accidentally lost.\n\n'
          'Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performRestore();
    }
  }

  Future<void> _performRestore() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF8DC71D)),
            SizedBox(width: 16),
            Text('Restoring data...'),
          ],
        ),
      ),
    );

    try {
      final success = await _databaseHelper.manualRestore();
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (success) {
        await _loadPackages(); // Refresh the packages list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Data restored successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('No backup found to restore from'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Restore failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _showBackupInfo() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF8DC71D)),
            SizedBox(width: 16),
            Text('Loading backup info...'),
          ],
        ),
      ),
    );

    try {
      final backupInfo = await _databaseHelper.getBackupInfo();
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text('Backup Information'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (backupInfo['sharedPrefsBackup'] != null) ...[
                    const Text('📱 SharedPreferences Backup:', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Last backup: ${_formatDateTime(backupInfo['sharedPrefsBackup'])}'),
                    const SizedBox(height: 16),
                  ],
                  const Text('💾 File Backups:', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (backupInfo['fileBackups'] != null && 
                      (backupInfo['fileBackups'] as List).isNotEmpty) ...[
                    ...((backupInfo['fileBackups'] as List).map((backup) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📁 ${backup['path'].split('/').last}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text('Size: ${_formatFileSize(backup['size'])}'),
                            Text('Modified: ${_formatDateTime(backup['modified'])}'),
                          ],
                        ),
                      ),
                    )),
                  ] else ...[
                    const Text('No file backups found.', 
                      style: TextStyle(color: Colors.orange)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading backup info: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Word Packages'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            tooltip: 'Study later',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StudyLaterPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPackages,
            tooltip: 'Refresh packages',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'export') {
                await _exportBackup();
              } else if (value == 'import') {
                await _showImportDialog();
              } else if (value == 'restore') {
                await _showRestoreDialog();
              } else if (value == 'backup_info') {
                await _showBackupInfo();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, color: Color(0xFF8DC71D)),
                    SizedBox(width: 8),
                    Text('Export backup'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, color: Color(0xFF8DC71D)),
                    SizedBox(width: 8),
                    Text('Import backup'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Restore Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup_info',
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Backup Info'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8DC71D),
              ),
            )
          : _packages.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8DC71D)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.folder_open,
                                    size: 64,
                                    color: Color(0xFF8DC71D),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No packages yet',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Create your first word package to start learning',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  color: Colors.grey[50],
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _packages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildOverallProgressCard();
                      }
                      final package = _packages[index - 1];
                      return _buildPackageCard(context, package);
                    },
                  ),
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8DC71D).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _addPackage,
          tooltip: 'Add Package',
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  int get _totalWords =>
      _packages.fold(0, (sum, p) => sum + p.wordCount);

  int get _totalLearned =>
      _packages.fold(0, (sum, p) => sum + p.learnedCount);

  double get _overallPercent =>
      _totalWords == 0 ? 0 : (_totalLearned / _totalWords) * 100;

  Widget _buildOverallProgressCard() {
    final completedDays =
        _packages.where((p) => p.isComplete).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Color(0xFF8DC71D)),
                const SizedBox(width: 8),
                Text(
                  'Study progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _totalWords == 0 ? 0 : _totalLearned / _totalWords,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF8DC71D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_overallPercent.toStringAsFixed(0)}% complete · '
              '$_totalLearned / $_totalWords words learned · '
              '$completedDays / ${_packages.length} days done',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(BuildContext context, Package package) {
    final percent = package.completionPercent;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PackageOptionsPage(package: package),
            ),
          );
          _loadPackages();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: package.isComplete
                      ? const Color(0xFF8DC71D)
                      : const Color(0xFF8DC71D).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: package.isComplete
                      ? const Icon(Icons.check, color: Colors.white, size: 28)
                      : Text(
                          _dayBadge(package.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            package.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deletePackage(package);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red[400]),
                                  const SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red[400])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${package.learnedCount} / ${package.wordCount} learned',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: package.wordCount == 0
                            ? 0
                            : package.learnedCount / package.wordCount,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        color: package.isComplete
                            ? Colors.green
                            : const Color(0xFF8DC71D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${percent.toStringAsFixed(0)}% complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayBadge(String name) {
    final match =
        RegExp(r'^day\s+(\d+)$', caseSensitive: false).firstMatch(name.trim());
    if (match != null) return match.group(1)!;
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
} 