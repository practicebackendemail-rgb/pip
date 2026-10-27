import 'package:equatable/equatable.dart';

enum SyncProviderType { googleDriveAppData, manualEncryptedFile, webDav }

class CloudSyncFile extends Equatable {
  final String id;
  final String name;
  final DateTime modifiedAt;
  final int sizeBytes;

  const CloudSyncFile({
    required this.id,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  @override
  List<Object?> get props => [id, name, modifiedAt, sizeBytes];
}

/// Abstract contract for user-owned zero-server cloud sync.
abstract class ISyncProvider {
  SyncProviderType get type;
  bool get isAuthenticated;

  Future<void> authenticate();
  Future<List<CloudSyncFile>> listFiles();
  Future<String> pull(String fileId);
  Future<void> push(String fileName, String encryptedContent);
}
