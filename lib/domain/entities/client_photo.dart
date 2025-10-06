import 'package:flutter/foundation.dart';

@immutable
class ClientPhoto {
  const ClientPhoto({
    required this.id,
    required this.clientId,
    required this.salonId,
    required this.storagePath,
    required this.downloadUrl,
    required this.uploadedAt,
    required this.uploadedBy,
    this.fileName,
    this.contentType,
    this.sizeBytes,
    this.notes,
  });

  final String id;
  final String clientId;
  final String salonId;
  final String storagePath;
  final String downloadUrl;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;
  final String? notes;

  ClientPhoto copyWith({
    String? id,
    String? clientId,
    String? salonId,
    String? storagePath,
    String? downloadUrl,
    DateTime? uploadedAt,
    String? uploadedBy,
    Object? fileName = _unset,
    Object? contentType = _unset,
    Object? sizeBytes = _unset,
    Object? notes = _unset,
  }) {
    return ClientPhoto(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      salonId: salonId ?? this.salonId,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      fileName: fileName == _unset ? this.fileName : fileName as String?,
      contentType:
          contentType == _unset ? this.contentType : contentType as String?,
      sizeBytes: sizeBytes == _unset ? this.sizeBytes : sizeBytes as int?,
      notes: notes == _unset ? this.notes : notes as String?,
    );
  }

  static const Object _unset = Object();
}

class ClientPhotoUploadData {
  const ClientPhotoUploadData({
    required this.photoId,
    required this.salonId,
    required this.clientId,
    required this.storagePath,
    required this.downloadUrl,
    required this.uploadedAt,
    required this.uploadedBy,
    this.fileName,
    this.contentType,
    this.sizeBytes,
  });

  final String photoId;
  final String salonId;
  final String clientId;
  final String storagePath;
  final String downloadUrl;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;
}
