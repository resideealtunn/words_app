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
  static Future<Database>? _opening;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Prevent concurrent openDatabase / restore recursion.
    _opening ??= _initDatabase();
    try {
      _database = await _opening!;
      return _database!;
    } catch (e) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'words_database.db');

    print('Database path: $path');
    print('Database exists: ${await File(path).exists()}');

    if (!await documentsDirectory.exists()) {
      await documentsDirectory.create(recursive: true);
      print('Created documents directory');
    }

    // Only copy from backup files — never call `database` getter here.
    await _tryRestoreFromBackupFiles(path);

    final db = await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    await _verifyDatabaseIntegrity(db);
    // If DB is empty but SharedPreferences still has data, restore into this handle.
    await _restoreFromSharedPreferences(db);

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Creating database with version: $version');

    await db.execute('''
      CREATE TABLE packages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        lastOpenedAt INTEGER,
        wordCount INTEGER DEFAULT 0
      )
    ''');
    print('Packages table created');

    await db.execute('''
      CREATE TABLE words(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packageId INTEGER NOT NULL,
        englishWord TEXT NOT NULL,
        turkishMeaning TEXT NOT NULL,
        partOfSpeech TEXT,
        description TEXT,
        imagePath TEXT,
        exampleSentence TEXT,
        exampleSentenceTr TEXT,
        synonyms TEXT,
        antonyms TEXT,
        otherForms TEXT,
        createdAt INTEGER NOT NULL,
        isLearned INTEGER DEFAULT 0,
        studyLater INTEGER DEFAULT 0,
        FOREIGN KEY (packageId) REFERENCES packages (id) ON DELETE CASCADE
      )
    ''');
    print('Words table created');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS words(
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

    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'words', 'partOfSpeech', 'TEXT');
      await _addColumnIfMissing(db, 'words', 'exampleSentenceTr', 'TEXT');
      await _addColumnIfMissing(db, 'words', 'synonyms', 'TEXT');
      await _addColumnIfMissing(db, 'words', 'antonyms', 'TEXT');
      await _addColumnIfMissing(db, 'words', 'otherForms', 'TEXT');
      await _addColumnIfMissing(db, 'words', 'studyLater', 'INTEGER DEFAULT 0');
      print('Words table upgraded to rich vocabulary schema');
    }

    if (oldVersion < 4) {
      await _addColumnIfMissing(db, 'packages', 'lastOpenedAt', 'INTEGER');
      print('Packages table upgraded with lastOpenedAt');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _verifyDatabaseIntegrity(Database db) async {
    try {
      final tables =
          await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((table) => table['name'] as String).toList();

      if (!tableNames.contains('packages') || !tableNames.contains('words')) {
        print('Database tables missing — recreating schema');
        await _onCreate(db, 4);
      }

      await db.query('packages', limit: 1);
      await db.query('words', limit: 1);
      print('Database integrity verified');
    } catch (e) {
      print('Database integrity check failed: $e');
    }
  }

  /// File-only restore. Safe during init (does not touch `database` getter).
  Future<bool> _tryRestoreFromBackupFiles(String mainDbPath) async {
    try {
      final mainDb = File(mainDbPath);
      if (await mainDb.exists() && await mainDb.length() > 0) {
        return false;
      }

      print('Main database missing or empty, looking for file backups...');
      for (final backupPath in await _getBackupPaths()) {
        final backupFile = File(backupPath);
        if (await backupFile.exists() && await backupFile.length() > 0) {
          await backupFile.copy(mainDbPath);
          print('Database restored from: $backupPath');
          return true;
        }
      }
      print('No file backup found — a new database will be created');
      return false;
    } catch (e) {
      print('File restore failed: $e');
      return false;
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
    final packageId = await insertPackageWithoutBackup(package);
    await _backupToSharedPreferences();
    return packageId;
  }

  /// Bulk import helper — skips per-row local backups.
  Future<int> insertPackageWithoutBackup(Package package) async {
    final db = await database;
    final map = package.toMap()..remove('id');
    return db.insert('packages', map);
  }

  Future<List<Package>> getAllPackages() async {
    final db = await database;
    // Live word / learned counts; caller chooses sort order.
    final maps = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.description,
        p.createdAt,
        p.lastOpenedAt,
        COALESCE((SELECT COUNT(*) FROM words w WHERE w.packageId = p.id), 0) AS wordCount,
        COALESCE((SELECT COUNT(*) FROM words w WHERE w.packageId = p.id AND w.isLearned = 1), 0) AS learnedCount
      FROM packages p
    ''');
    final packages = maps.map(Package.fromMap).toList();
    packages.sort(comparePackagesByDay);
    return packages;
  }

  Future<Package?> getPackage(int id) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT
        p.id,
        p.name,
        p.description,
        p.createdAt,
        p.lastOpenedAt,
        COALESCE((SELECT COUNT(*) FROM words w WHERE w.packageId = p.id), 0) AS wordCount,
        COALESCE((SELECT COUNT(*) FROM words w WHERE w.packageId = p.id AND w.isLearned = 1), 0) AS learnedCount
      FROM packages p
      WHERE p.id = ?
      ''',
      [id],
    );
    if (maps.isEmpty) return null;
    return Package.fromMap(maps.first);
  }

  /// Marks a package as opened now (for "Recently opened" sort).
  Future<void> touchPackageOpened(int packageId) async {
    final db = await database;
    await db.update(
      'packages',
      {'lastOpenedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [packageId],
    );
  }

  Future<void> setWordLearned(int wordId, bool learned) async {
    final db = await database;
    await db.update(
      'words',
      {
        'isLearned': learned ? 1 : 0,
        if (learned) 'studyLater': 0,
      },
      where: 'id = ?',
      whereArgs: [wordId],
    );
    await _backupToSharedPreferences();
  }

  Future<int> updatePackage(Package package) async {
    final db = await database;
    final result = await db.update(
      'packages',
      package.toMap(),
      where: 'id = ?',
      whereArgs: [package.id],
    );
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
    await _backupToSharedPreferences();
    return result;
  }

  // Word operations
  Future<int> insertWord(Word word) async {
    final wordId = await insertWordWithoutBackup(word);
    await _backupToSharedPreferences();
    return wordId;
  }

  /// Bulk import helper — skips per-row local backups.
  Future<int> insertWordWithoutBackup(Word word) async {
    final db = await database;
    final map = word.toMap()..remove('id');
    final wordId = await db.insert('words', map);
    await _updatePackageWordCount(word.packageId);
    return wordId;
  }

  Future<int> updateWordWithoutBackup(Word word) async {
    final db = await database;
    final result = await db.update(
      'words',
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
    await _updatePackageWordCount(word.packageId);
    return result;
  }

  /// Wipe all packages and words (used by Replace All import).
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('words');
    await db.delete('packages');
  }

  /// Refresh counts and write local sandbox backups once after a bulk import.
  Future<void> finalizeBulkChange() async {
    final packages = await getAllPackages();
    for (final package in packages) {
      if (package.id != null) {
        await _updatePackageWordCount(package.id!);
      }
    }
    await backupToAllLocations();
    await _backupToSharedPreferences();
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
    final map = word.toMap();
    final result = await db.update(
      'words',
      map,
      where: 'id = ?',
      whereArgs: [word.id],
    );
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
    await _backupToSharedPreferences();
    return result;
  }

  Future<List<String>> getDistinctPartsOfSpeech({int? packageId}) async {
    final db = await database;
    final rows = packageId == null
        ? await db.rawQuery(
            "SELECT DISTINCT partOfSpeech FROM words WHERE partOfSpeech IS NOT NULL AND partOfSpeech != ''",
          )
        : await db.rawQuery(
            "SELECT DISTINCT partOfSpeech FROM words WHERE packageId = ? AND partOfSpeech IS NOT NULL AND partOfSpeech != ''",
            [packageId],
          );
    return rows
        .map((r) => (r['partOfSpeech'] as String?)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<int> getWordCountByPackage(int packageId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE packageId = ?',
      [packageId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Word>> getStudyLaterWords() async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'studyLater = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Word.fromMap).toList();
  }

  Future<void> setStudyLater(int wordId, bool value) async {
    final db = await database;
    await db.update(
      'words',
      {'studyLater': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [wordId],
    );
    await _backupToSharedPreferences();
  }

  /// Mark as learned and remove from the study-later list.
  Future<void> markLearnedFromStudyList(int wordId) async {
    final db = await database;
    await db.update(
      'words',
      {'isLearned': 1, 'studyLater': 0},
      where: 'id = ?',
      whereArgs: [wordId],
    );
    await _backupToSharedPreferences();
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

  Future<void> _backupToSharedPreferences() async {
    try {
      final db = _database;
      if (db == null) return;

      final prefs = await SharedPreferences.getInstance();
      final packageMaps = await db.query('packages');
      await prefs.setString('backup_packages', jsonEncode(packageMaps));

      final wordMaps = await db.query('words', orderBy: 'createdAt DESC');
      await prefs.setString('backup_words', jsonEncode(wordMaps));
      await prefs.setInt(
          'backup_timestamp', DateTime.now().millisecondsSinceEpoch);

      print('Critical data backed up to SharedPreferences');
    } catch (e) {
      print('Error backing up to SharedPreferences: $e');
    }
  }

  /// Restores into an already-open [db]. Never calls the `database` getter.
  Future<void> _restoreFromSharedPreferences(Database db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packagesJson = prefs.getString('backup_packages');
      final wordsJson = prefs.getString('backup_words');

      if (packagesJson == null || wordsJson == null) {
        print('No SharedPreferences backup found');
        return;
      }

      final existing = await db.query('packages', limit: 1);
      if (existing.isNotEmpty) {
        // Don't overwrite a working database on every launch.
        return;
      }

      final packageMaps =
          List<Map<String, dynamic>>.from(jsonDecode(packagesJson));
      for (final packageMap in packageMaps) {
        try {
          await db.insert(
            'packages',
            packageMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          print('Error restoring package: $e');
        }
      }

      final wordMaps = List<Map<String, dynamic>>.from(jsonDecode(wordsJson));
      for (final wordMap in wordMaps) {
        try {
          await db.insert(
            'words',
            wordMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          print('Error restoring word: $e');
        }
      }

      print('Data restored from SharedPreferences backup');
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

  Future<bool> manualRestore() async {
    try {
      await _database?.close();
      _database = null;
      _opening = null;

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final mainDbPath = join(documentsDirectory.path, 'words_database.db');
      await _tryRestoreFromBackupFiles(mainDbPath);

      final db = await database;
      await _restoreFromSharedPreferences(db);
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