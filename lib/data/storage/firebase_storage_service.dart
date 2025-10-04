import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  FirebaseStorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadSalonLogo({
    required String salonId,
    required Uint8List data,
    String? fileName,
  }) async {
    final extension = _resolveExtension(fileName);
    final reference = _storage.ref().child('branding/$salonId/logo.$extension');
    final metadata = SettableMetadata(
      contentType: _contentTypeForExtension(extension),
      cacheControl: 'public,max-age=604800',
    );
    await reference.putData(data, metadata);
    return reference.getDownloadURL();
  }

  String _resolveExtension(String? fileName) {
    if (fileName == null) {
      return 'png';
    }
    final segments = fileName.split('.');
    if (segments.length < 2) {
      return 'png';
    }
    final candidate = segments.last.toLowerCase();
    if (candidate.isEmpty) {
      return 'png';
    }
    return candidate;
  }

  String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'svg':
      case 'svg+xml':
        return 'image/svg+xml';
      case 'png':
      default:
        return 'image/png';
    }
  }
}
