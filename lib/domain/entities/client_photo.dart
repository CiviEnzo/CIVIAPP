import 'package:flutter/foundation.dart';

enum ClientPhotoSetType {
  front,
  back,
  left,
  right,
}

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
    this.setType,
    this.setVersionIndex,
    this.isSetActiveVersion = true,
    this.archivedAt,
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
  final ClientPhotoSetType? setType;
  final int? setVersionIndex;
  final bool isSetActiveVersion;
  final DateTime? archivedAt;

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
    Object? setType = _unset,
    Object? setVersionIndex = _unset,
    bool? isSetActiveVersion,
    Object? archivedAt = _unset,
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
      setType:
          setType == _unset ? this.setType : setType as ClientPhotoSetType?,
      setVersionIndex: setVersionIndex == _unset
          ? this.setVersionIndex
          : setVersionIndex as int?,
      isSetActiveVersion: isSetActiveVersion ?? this.isSetActiveVersion,
      archivedAt:
          archivedAt == _unset ? this.archivedAt : archivedAt as DateTime?,
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
