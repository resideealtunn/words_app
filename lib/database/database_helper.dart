import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '../models/package.dart';
import '../models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get application documents directory (persistent storage)
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'words_database.db');
    
    print('Database path: $path');
    print('Database exists: ${await File(path).exists()}');
    
    // Ensure directory exists
    if (!await documentsDirectory.exists()) {
      await documentsDirectory.create(recursive: true);
      print('Created documents directory');
    }
    
    // Check if database needs to be restored
    await _checkAndRestoreDatabase(path);
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _verifyDatabaseIntegrity(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Creating database with version: $version');
    
    // Packages table
    await db.execute('''
      CREATE TABLE packages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        wordCount INTEGER DEFAULT 0
      )
    ''');
    print('Packages table created');

    // Words table
    await db.execute('''
      CREATE TABLE words(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packageId INTEGER NOT NULL,
        englishWord TEXT NOT NULL,
        turkishMeaning TEXT NOT NULL,
        description TEXT,
        imagePath TEXT,
        exampleSentence TEXT,
        createdAt INTEGER NOT NULL,
        isLearned INTEGER DEFAULT 0,
        FOREIGN KEY (packageId) REFERENCES packages (id) ON DELETE CASCADE
      )
    ''');
    print('Words table created');
    
    // Initial backup after creation
    await backupToAllLocations();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE words(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          packageId INTEGER NOT NULL,
          englishWord TEXT NOT NULL,
          turkishMeaning TEXT NOT NULL,
          description TEXT,
          imagePath TEXT,
          exampleSentence TEXT,
          createdAt INTEGER NOT NULL,
          isLearned INTEGER DEFAULT 0,
          FOREIGN KEY (packageId) REFERENCES packages (id) ON DELETE CASCADE
        )
      ''');
      print('Words table created during upgrade');
    }
    
    // Backup after upgrade
    await backupToAllLocations();
  }

  // Database integrity verification
  Future<void> _verifyDatabaseIntegrity(Database db) async {
    try {
      // Check if tables exist and have proper structure
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((table) => table['name'] as String).toList();
      
      if (!tableNames.contains('packages') || !tableNames.contains('words')) {
        print('Database tables missing, attempting restore...');
        await _attemptDatabaseRestore();
      }
      
      // Test basic queries
      await db.query('packages', limit: 1);
      await db.query('words', limit: 1);
      
      print('Database integrity verified');
    } catch (e) {
      print('Database integrity check failed: $e');
      await _attemptDatabaseRestore();
    }
  }

  // Auto restore mechanism
  Future<void> _checkAndRestoreDatabase(String mainDbPath) async {
    try {
      File mainDb = File(mainDbPath);
      
      // If main database doesn't exist or is corrupted, try to restore
      if (!await mainDb.exists() || await mainDb.length() == 0) {
        print('Main database missing or empty, attempting restore...');
        await _attemptDatabaseRestore();
      }
    } catch (e) {
      print('Error checking database: $e');
      await _attemptDatabaseRestore();
    }
  }

  Future<void> _attemptDatabaseRestore() async {
    try {
      // Try to restore from various backup locations
      List<String> backupSources = await _getBackupPaths();
      
      for (String backupPath in backupSources) {
        File backupFile = File(backupPath);
        if (await backupFile.exists() && await backupFile.length() > 0) {
          Directory documentsDirectory = await getApplicationDocumentsDirectory();
          String mainDbPath = join(documentsDirectory.path, 'words_database.db');
          
          await backupFile.copy(mainDbPath);
          print('Database restored from: $backupPath');
          
          // Verify restored database
          Database testDb = await openDatabase(mainDbPath, readOnly: true);
          await testDb.query('packages', limit: 1);
          await testDb.close();
          
          print('Restored database verified successfully');
          return;
        }
      }
      
      // Try to restore from SharedPreferences backup
      await _restoreFromSharedPreferences();
      
    } catch (e) {
      print('Database restore failed: $e');
    }
  }

  Future<List<String>> _getBackupPaths() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    List<String> paths = [];
    
    // Internal backup paths
    paths.add(join(documentsDirectory.path, 'words_database_backup.db'));
    paths.add(join(documentsDirectory.path, 'words_database_backup2.db'));
    paths.add(join(documentsDirectory.path, 'words_database_backup3.db'));
    
    // Try external storage if available
    try {
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        paths.add(join(externalDir.path, 'words_backup', 'words_database.db'));
        paths.add(join(externalDir.path, 'words_backup', 'words_database_backup.db'));
      }
    } catch (e) {
      print('External storage not available: $e');
    }
    
    return paths;
  }

  // Package operations
  Future<int> insertPackage(Package package) async {
    final db = await database;
    final packageId = await db.insert('packages', package.toMap());
    
    // Auto backup after important operations
    await backupToAllLocations();
    await _backupToSharedPreferences();
    
    return packageId;
  }

  Future<List<Package>> getAllPackages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('packages');
    final packages = List.generate(maps.length, (i) => Package.fromMap(maps[i]));
    
    // Update word counts for all packages
    for (final package in packages) {
      if (package.id != null) {
        await _updatePackageWordCount(package.id!);
      }
    }
    
    // Return updated packages
    final updatedMaps = await db.query('packages');
    return List.generate(updatedMaps.length, (i) => Package.fromMap(updatedMaps[i]));
  }

  Future<Package?> getPackage(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'packages',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Package.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updatePackage(Package package) async {
    final db = await database;
    final result = await db.update(
      'packages',
      package.toMap(),
      where: 'id = ?',
      whereArgs: [package.id],
    );
    
    // Backup after update
    await backupToAllLocations();
    await _backupToSharedPreferences();
    
    return result;
  }

  Future<int> deletePackage(int id) async {
    final db = await database;
    final result = await db.delete(
      'packages',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    // Backup after deletion
    await backupToAllLocations();
    await _backupToSharedPreferences();
    
    return result;
  }

  // Word operations
  Future<int> insertWord(Word word) async {
    final db = await database;
    print('Inserting word: ${word.englishWord}');
    final wordId = await db.insert('words', word.toMap());
    print('Word inserted with ID: $wordId');
    
    // Update package word count
    await _updatePackageWordCount(word.packageId);
    
    // Auto backup after important operations
    await backupToAllLocations();
    await _backupToSharedPreferences();
    
    return wordId;
  }

  Future<List<Word>> getWordsByPackage(int packageId) async {
    final db = await database;
    print('Getting words for package ID: $packageId');
    
    // Check if words table exists
    final tables = await db.query('sqlite_master', where: 'type = ? AND name = ?', whereArgs: ['table', 'words']);
    print('Tables found: ${tables.length}');
    
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'packageId = ?',
      whereArgs: [packageId],
      orderBy: 'createdAt DESC',
    );
    print('Words found: ${maps.length}');
    
    return List.generate(maps.length, (i) => Word.fromMap(maps[i]));
  }

  Future<Word?> getWord(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Word.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateWord(Word word) async {
    final db = await database;
    final result = await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
    
    // Backup after update
    await backupToAllLocations();
    await _backupToSharedPreferences();
    
    return result;
  }

  Future<int> deleteWord(int id) async {
    final db = await database;
    final word = await getWord(id);
    final result = await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (word != null) {
      await _updatePackageWordCount(word.packageId);
    }
    
    // Backup after deletion
    await backupToAllLocations();
    await _backupToSharedPreferences();
    
    return result;
  }

  Future<int> getWordCountByPackage(int packageId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE packageId = ?',
      [packageId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> _updatePackageWordCount(int packageId) async {
    final db = await database;
    final wordCount = await getWordCountByPackage(packageId);
    await db.update(
      'packages',
      {'wordCount': wordCount},
      where: 'id = ?',
      whereArgs: [packageId],
    );
  }

  // Enhanced backup functionality with multiple locations
  Future<void> backupToAllLocations() async {
    await Future.wait([
      backupDatabase(),
      _backupToSecondaryLocation(),
      _backupToTertiaryLocation(),
      _backupToExternalStorage(),
    ]);
  }

  Future<void> backupDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, 'words_database.db');
      String backupPath = join(documentsDirectory.path, 'words_database_backup.db');
      
      File dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
        print('Database backed up successfully to primary location');
      }
    } catch (e) {
      print('Error backing up database to primary location: $e');
    }
  }

  Future<void> _backupToSecondaryLocation() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, 'words_database.db');
      String backupPath = join(documentsDirectory.path, 'words_database_backup2.db');
      
      File dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
        print('Database backed up successfully to secondary location');
      }
    } catch (e) {
      print('Error backing up database to secondary location: $e');
    }
  }

  Future<void> _backupToTertiaryLocation() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, 'words_database.db');
      String backupPath = join(documentsDirectory.path, 'words_database_backup3.db');
      
      File dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
        print('Database backed up successfully to tertiary location');
      }
    } catch (e) {
      print('Error backing up database to tertiary location: $e');
    }
  }

  Future<void> _backupToExternalStorage() async {
    try {
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return;
      
      Directory backupDir = Directory(join(externalDir.path, 'words_backup'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, 'words_database.db');
      String externalBackupPath = join(backupDir.path, 'words_database.db');
      String externalBackupPath2 = join(backupDir.path, 'words_database_backup.db');
      
      File dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.copy(externalBackupPath);
        await dbFile.copy(externalBackupPath2);
        print('Database backed up successfully to external storage');
      }
    } catch (e) {
      print('Error backing up database to external storage: $e');
    }
  }

  // SharedPreferences backup for critical data
  Future<void> _backupToSharedPreferences() async {
    try {
      final db = await database;
      final prefs = await SharedPreferences.getInstance();
      
      // Backup packages
      final packageMaps = await db.query('packages');
      final packagesJson = jsonEncode(packageMaps);
      await prefs.setString('backup_packages', packagesJson);
      
      // Backup words (limited to recent ones to avoid size issues)
      final wordMaps = await db.query('words', orderBy: 'createdAt DESC', limit: 1000);
      final wordsJson = jsonEncode(wordMaps);
      await prefs.setString('backup_words', wordsJson);
      
      // Backup timestamp
      await prefs.setInt('backup_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('Critical data backed up to SharedPreferences');
    } catch (e) {
      print('Error backing up to SharedPreferences: $e');
    }
  }

  Future<void> _restoreFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final packagesJson = prefs.getString('backup_packages');
      final wordsJson = prefs.getString('backup_words');
      
      if (packagesJson == null || wordsJson == null) {
        print('No SharedPreferences backup found');
        return;
      }
      
      final db = await database;
      
      // Restore packages
      final packageMaps = List<Map<String, dynamic>>.from(jsonDecode(packagesJson));
      for (final packageMap in packageMaps) {
        try {
          await db.insert('packages', packageMap, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          print('Error restoring package: $e');
        }
      }
      
      // Restore words
      final wordMaps = List<Map<String, dynamic>>.from(jsonDecode(wordsJson));
      for (final wordMap in wordMaps) {
        try {
          await db.insert('words', wordMap, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          print('Error restoring word: $e');
        }
      }
      
      print('Data restored from SharedPreferences backup');
      
      // Create new backups after restoration
      await backupToAllLocations();
      
    } catch (e) {
      print('Error restoring from SharedPreferences: $e');
    }
  }

  Future<void> restoreDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = join(documentsDirectory.path, 'words_database.db');
      String backupPath = join(documentsDirectory.path, 'words_database_backup.db');
      
      File backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(dbPath);
        print('Database restored successfully');
      }
    } catch (e) {
      print('Error restoring database: $e');
    }
  }

  // Manual restore from any backup location
  Future<bool> manualRestore() async {
    try {
      await _attemptDatabaseRestore();
      
      // Reinitialize database
      await _database?.close();
      _database = null;
      _database = await _initDatabase();
      
      return true;
    } catch (e) {
      print('Manual restore failed: $e');
      return false;
    }
  }

  Future<String> getDatabasePath() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, 'words_database.db');
  }

  // Get backup information
  Future<Map<String, dynamic>> getBackupInfo() async {
    Map<String, dynamic> info = {};
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupTimestamp = prefs.getInt('backup_timestamp');
      if (backupTimestamp != null) {
        info['sharedPrefsBackup'] = DateTime.fromMillisecondsSinceEpoch(backupTimestamp);
      }
      
      List<String> backupPaths = await _getBackupPaths();
      List<Map<String, dynamic>> fileBackups = [];
      
      for (String path in backupPaths) {
        File file = File(path);
        if (await file.exists()) {
          final stat = await file.stat();
          fileBackups.add({
            'path': path,
            'size': stat.size,
            'modified': stat.modified,
          });
        }
      }
      
      info['fileBackups'] = fileBackups;
      
    } catch (e) {
      print('Error getting backup info: $e');
    }
    
    return info;
  }
} 