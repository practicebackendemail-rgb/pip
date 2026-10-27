import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/sync_provider.dart';

/// Manual file-based provider exporting and importing encrypted sync snapshots
/// via local file storage, share sheets, or file managers without requiring OAuth.
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
}
