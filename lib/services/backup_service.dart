import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/package.dart';
import '../models/word.dart';

enum ImportMode { merge, replaceAll }

class BackupValidationException implements Exception {
  final String message;
  BackupValidationException(this.message);

  @override
  String toString() => message;
}

class BackupSummary {
  final int packageCount;
  final int wordCount;
  final DateTime exportedAt;
  final String? filePath;

  const BackupSummary({
    required this.packageCount,
    required this.wordCount,
    required this.exportedAt,
    this.filePath,
  });
}

class ImportResult {
  final int packagesCreated;
  final int packagesMerged;
  final int wordsAdded;
  final int wordsUpdated;
  final int wordsSkipped;
  final ImportMode mode;
  final int exportedWordCount;

  const ImportResult({
    required this.packagesCreated,
    required this.packagesMerged,
    required this.wordsAdded,
    required this.wordsUpdated,
    required this.wordsSkipped,
    required this.mode,
    required this.exportedWordCount,
  });
}

class _ParsedBackup {
  final DateTime exportedAt;
  final List<_ParsedPackage> packages;
  final String checksum;

  const _ParsedBackup({
    required this.exportedAt,
    required this.packages,
    required this.checksum,
  });

  int get wordCount =>
      packages.fold(0, (sum, package) => sum + package.words.length);
}

class _ParsedPackage {
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;
  final List<_ParsedWord> words;

  const _ParsedPackage({
    required this.name,
    required this.description,
    required this.createdAt,
    this.lastOpenedAt,
    required this.words,
  });
}

class _ParsedWord {
  final String englishWord;
  final String turkishMeaning;
  final String? partOfSpeech;
  final String? description;
  final String? exampleSentence;
  final String? exampleSentenceTr;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> otherForms;
  final DateTime createdAt;
  final bool isLearned;
  final bool studyLater;

  const _ParsedWord({
    required this.englishWord,
    required this.turkishMeaning,
    this.partOfSpeech,
    this.description,
    this.exampleSentence,
    this.exampleSentenceTr,
    this.synonyms = const [],
    this.antonyms = const [],
    this.otherForms = const [],
    required this.createdAt,
    required this.isLearned,
    this.studyLater = false,
  });
}

/// Offline backup: versioned JSON + checksum, saved via SAF / share sheet.
class BackupService {
  static const String formatId = 'words_backup';
  static const int formatVersion = 2;

  final DatabaseHelper _db;

  BackupService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<BackupSummary> exportToUserLocation() async {
    final liveCount = await _countAllWordsInDb();
    final payload = await _buildPayload();
    final wordCount = _countWordsInPayload(payload);
    final packageCount =
        ((payload['data'] as Map)['packages'] as List).length;

    if (wordCount != liveCount) {
      throw BackupValidationException(
        'Export aborted: DB has $liveCount words but payload has $wordCount.',
      );
    }

    // Round-trip validate so flags/fields survive encode → decode.
    _parseAndValidate(const JsonEncoder.withIndent('  ').convert(payload));

    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = utf8.encode(jsonText);
    final fileName = _defaultFileName();

    // Prefer system save dialog (SAF on Android) — file lives outside app sandbox.
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save words backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );

    if (savedPath != null && savedPath.isNotEmpty) {
      final file = File(savedPath);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes, flush: true);
      }
      // Verify written file still validates (no truncation).
      _parseAndValidate(await file.readAsString());
      return BackupSummary(
        packageCount: packageCount,
        wordCount: wordCount,
        exportedAt: DateTime.parse(payload['exportedAt'] as String),
        filePath: savedPath,
      );
    }

    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, fileName);
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    _parseAndValidate(await tempFile.readAsString());

    await Share.shareXFiles(
      [XFile(tempPath, mimeType: 'application/json', name: fileName)],
      subject: 'Words backup',
      text: 'Words app offline backup',
    );

    return BackupSummary(
      packageCount: packageCount,
      wordCount: wordCount,
      exportedAt: DateTime.parse(payload['exportedAt'] as String),
      filePath: tempPath,
    );
  }

  Future<int> _countAllWordsInDb() async {
    final packages = await _db.getAllPackages();
    var total = 0;
    for (final package in packages) {
      if (package.id == null) continue;
      total += (await _db.getWordsByPackage(package.id!)).length;
    }
    return total;
  }

  Future<ImportResult> importFromUserPick({required ImportMode mode}) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select words backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      throw BackupValidationException('Import cancelled.');
    }

    final file = result.files.single;
    final String raw;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      raw = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    } else {
      throw BackupValidationException('Could not read the selected file.');
    }

    final parsed = _parseAndValidate(raw);
    return _applyImport(parsed, mode);
  }

  Future<ImportResult> _applyImport(_ParsedBackup parsed, ImportMode mode) async {
    var packagesCreated = 0;
    var packagesMerged = 0;
    var wordsAdded = 0;
    var wordsUpdated = 0;
    var wordsSkipped = 0;
    final expectedWords = parsed.wordCount;

    try {
      if (mode == ImportMode.replaceAll) {
        await _db.clearAllData();
      }

      final existingPackages = await _db.getAllPackages();
      final packagesByName = <String, Package>{
        for (final pkg in existingPackages) pkg.name.toLowerCase(): pkg,
      };

      for (final incoming in parsed.packages) {
        final key = incoming.name.toLowerCase();
        Package? target = packagesByName[key];

        if (target == null) {
          final newId = await _db.insertPackageWithoutBackup(
            Package(
              name: incoming.name,
              description: incoming.description,
              createdAt: incoming.createdAt,
              lastOpenedAt: incoming.lastOpenedAt,
              wordCount: 0,
            ),
          );
          target = Package(
            id: newId,
            name: incoming.name,
            description: incoming.description,
            createdAt: incoming.createdAt,
            lastOpenedAt: incoming.lastOpenedAt,
            wordCount: 0,
          );
          packagesByName[key] = target;
          packagesCreated++;
        } else {
          packagesMerged++;
        }

        final existingWords = await _db.getWordsByPackage(target.id!);
        final existingByKey = <String, Word>{
          for (final w in existingWords)
            _wordKey(w.englishWord, w.turkishMeaning): w,
        };

        for (final word in incoming.words) {
          final keyWord = _wordKey(word.englishWord, word.turkishMeaning);
          final existing = existingByKey[keyWord];

          if (existing != null) {
            // Upsert: keep id + local imagePath; restore all portable fields & marks.
            await _db.updateWordWithoutBackup(
              Word(
                id: existing.id,
                packageId: existing.packageId,
                englishWord: word.englishWord,
                turkishMeaning: word.turkishMeaning,
                partOfSpeech: word.partOfSpeech,
                description: word.description,
                imagePath: existing.imagePath,
                exampleSentence: word.exampleSentence,
                exampleSentenceTr: word.exampleSentenceTr,
                synonyms: word.synonyms,
                antonyms: word.antonyms,
                otherForms: word.otherForms,
                createdAt: word.createdAt,
                isLearned: word.isLearned,
                studyLater: word.studyLater,
              ),
            );
            wordsUpdated++;
            continue;
          }

          await _db.insertWordWithoutBackup(
            Word(
              packageId: target.id!,
              englishWord: word.englishWord,
              turkishMeaning: word.turkishMeaning,
              partOfSpeech: word.partOfSpeech,
              description: word.description,
              exampleSentence: word.exampleSentence,
              exampleSentenceTr: word.exampleSentenceTr,
              synonyms: word.synonyms,
              antonyms: word.antonyms,
              otherForms: word.otherForms,
              createdAt: word.createdAt,
              isLearned: word.isLearned,
              studyLater: word.studyLater,
            ),
          );
          existingByKey[keyWord] = Word(
            packageId: target.id!,
            englishWord: word.englishWord,
            turkishMeaning: word.turkishMeaning,
            createdAt: word.createdAt,
          );
          wordsAdded++;
        }
      }

      final applied = wordsAdded + wordsUpdated;
      if (applied != expectedWords) {
        throw BackupValidationException(
          'Import incomplete: expected $expectedWords words, applied $applied.',
        );
      }
    } finally {
      await _db.finalizeBulkChange();
    }

    return ImportResult(
      packagesCreated: packagesCreated,
      packagesMerged: mode == ImportMode.replaceAll ? 0 : packagesMerged,
      wordsAdded: wordsAdded,
      wordsUpdated: wordsUpdated,
      wordsSkipped: wordsSkipped,
      mode: mode,
      exportedWordCount: expectedWords,
    );
  }

  String _wordKey(String english, String turkish) =>
      '${english.trim().toLowerCase()}||${turkish.trim().toLowerCase()}';

  Future<Map<String, dynamic>> _buildPayload() async {
    final packages = await _db.getAllPackages();
    final nested = <Map<String, dynamic>>[];

    for (final package in packages) {
      if (package.id == null) continue;
      final words = await _db.getWordsByPackage(package.id!);
      nested.add({
        'name': package.name,
        'description': package.description,
        'createdAt': package.createdAt.toUtc().toIso8601String(),
        if (package.lastOpenedAt != null)
          'lastOpenedAt': package.lastOpenedAt!.toUtc().toIso8601String(),
        // Device-local image paths are intentionally omitted (not portable).
        'words': words.map((w) => w.toBackupMap()).toList(),
      });
    }

    final data = {'packages': nested};
    final exportedAt = DateTime.now().toUtc();
    final checksum = _checksumForData(data);

    return {
      'format': formatId,
      'version': formatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'checksum': checksum,
      'data': data,
    };
  }

  _ParsedBackup _parseAndValidate(String raw) {
    if (raw.trim().isEmpty) {
      throw BackupValidationException('Backup file is empty.');
    }

    late final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw BackupValidationException('Backup file is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw BackupValidationException('Backup root must be a JSON object.');
    }

    final map = decoded;
    if (map['format'] != formatId) {
      throw BackupValidationException(
        'Unrecognized backup format (expected "$formatId").',
      );
    }

    final version = map['version'];
    if (version is! int || version < 1 || version > formatVersion) {
      throw BackupValidationException(
        'Unsupported backup version: $version',
      );
    }

    final checksum = map['checksum'];
    if (checksum is! String || checksum.isEmpty) {
      throw BackupValidationException('Missing backup checksum.');
    }

    final data = map['data'];
    if (data is! Map<String, dynamic>) {
      throw BackupValidationException('Missing backup data section.');
    }

    final expected = _checksumForData(data);
    if (expected != checksum) {
      throw BackupValidationException(
        'Checksum mismatch — file may be corrupted or edited.',
      );
    }

    final packagesRaw = data['packages'];
    if (packagesRaw is! List) {
      throw BackupValidationException('Backup packages list is missing.');
    }

    final packages = <_ParsedPackage>[];
    for (var i = 0; i < packagesRaw.length; i++) {
      final item = packagesRaw[i];
      if (item is! Map) {
        throw BackupValidationException('Package #$i is invalid.');
      }
      final pkg = Map<String, dynamic>.from(item);

      final name = (pkg['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        throw BackupValidationException('Package #$i has an empty name.');
      }

      final description = (pkg['description'] as String?) ?? '';
      final createdAt = _parseDate(pkg['createdAt'], 'package "$name" createdAt');
      final lastOpenedRaw = pkg['lastOpenedAt'];
      final DateTime? lastOpenedAt = lastOpenedRaw == null
          ? null
          : _parseDate(lastOpenedRaw, 'package "$name" lastOpenedAt');

      final wordsRaw = pkg['words'];
      if (wordsRaw is! List) {
        throw BackupValidationException('Package "$name" has no words list.');
      }

      final words = <_ParsedWord>[];
      for (var j = 0; j < wordsRaw.length; j++) {
        final wItem = wordsRaw[j];
        if (wItem is! Map) {
          throw BackupValidationException(
            'Word #$j in package "$name" is invalid.',
          );
        }
        final w = Map<String, dynamic>.from(wItem);
        final english = (w['englishWord'] as String?)?.trim() ?? '';
        final turkish = (w['turkishMeaning'] as String?)?.trim() ?? '';
        if (english.isEmpty || turkish.isEmpty) {
          throw BackupValidationException(
            'Word #$j in package "$name" is missing english/turkish text.',
          );
        }
        words.add(
          _ParsedWord(
            englishWord: english,
            turkishMeaning: turkish,
            partOfSpeech: (w['partOfSpeech'] as String?)?.trim(),
            description: w['description'] as String?,
            exampleSentence: w['exampleSentence'] as String?,
            exampleSentenceTr: w['exampleSentenceTr'] as String?,
            synonyms: Word.decodeStringList(w['synonyms']),
            antonyms: Word.decodeStringList(w['antonyms']),
            otherForms: Word.decodeStringList(w['otherForms']),
            createdAt: _parseDate(
              w['createdAt'],
              'word "$english" createdAt',
            ),
            isLearned: w['isLearned'] == true || w['isLearned'] == 1,
            studyLater: w['studyLater'] == true || w['studyLater'] == 1,
          ),
        );
      }

      packages.add(
        _ParsedPackage(
          name: name,
          description: description,
          createdAt: createdAt,
          lastOpenedAt: lastOpenedAt,
          words: words,
        ),
      );
    }

    if (packages.isEmpty) {
      throw BackupValidationException('Backup contains no packages.');
    }

    final exportedAt = _parseDate(map['exportedAt'], 'exportedAt');
    return _ParsedBackup(
      exportedAt: exportedAt,
      packages: packages,
      checksum: checksum,
    );
  }

  String _checksumForData(Map<String, dynamic> data) {
    // Canonical JSON (no indent) so checksum is stable.
    final canonical = jsonEncode(data);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  DateTime _parseDate(dynamic value, String label) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    throw BackupValidationException('Invalid date for $label.');
  }

  int _countWordsInPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is! Map) return 0;
    final packages = data['packages'];
    if (packages is! List) return 0;
    var count = 0;
    for (final pkg in packages) {
      if (pkg is Map && pkg['words'] is List) {
        count += (pkg['words'] as List).length;
      }
    }
    return count;
  }

  String _defaultFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'words_backup_$stamp.json';
  }
}
