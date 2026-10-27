import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/sync_provider.dart';

/// Manual file-based provider exporting and importing encrypted sync snapshots
/// via local file storage, system share sheets, and platform file pickers.
class ManualEncryptedFileProvider implements ISyncProvider {
  @override
  SyncProviderType get type => SyncProviderType.manualEncryptedFile;

  @override
  bool get isAuthenticated => true; // Always available locally

  @override
  Future<void> authenticate() async {
    // No-op for manual file system
  }

  Future<Directory> _getSyncDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final syncDir = Directory(p.join(docs.path, 'pip_cloud_sync'));
    if (!await syncDir.exists()) {
      await syncDir.create(recursive: true);
    }
    return syncDir;
  }

  @override
  Future<List<CloudSyncFile>> listFiles() async {
    final dir = await _getSyncDir();
    final entities = dir.listSync();
    final files = <CloudSyncFile>[];

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.enc')) {
        final stat = entity.statSync();
        files.add(CloudSyncFile(
          id: entity.path,
          name: p.basename(entity.path),
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ));
      }
    }

    files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }

  @override
  Future<String> pull(String fileId) async {
    final file = File(fileId);
    if (!await file.exists()) {
      throw Exception('File not found at $fileId');
    }
    return await file.readAsString();
  }

  @override
  Future<void> push(String fileName, String encryptedContent) async {
    final dir = await _getSyncDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(encryptedContent);
  }

  /// Exports an encrypted snapshot file to the system share sheet
  Future<void> exportViaShareSheet(String fileName) async {
    final dir = await _getSyncDir();
    final file = File(p.join(dir.path, fileName));
    if (await file.exists()) {
      // Share the encrypted file itself so it can be saved and re-imported.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          subject: 'Pip Encrypted Backup ($fileName)',
        ),
      );
    }
  }

  /// Imports an encrypted snapshot file from user selection via FilePicker
  Future<String?> importViaFilePicker() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['enc', 'json'],
    );
    if (files.isNotEmpty && files.first.path != null) {
      final file = File(files.first.path!);
      final content = await file.readAsString();
      final dir = await _getSyncDir();
      final destination = File(p.join(dir.path, p.basename(file.path)));
      await destination.writeAsString(content);
      return destination.path;
    }
    return null;
  }
}
