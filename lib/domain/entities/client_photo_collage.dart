import 'package:flutter/foundation.dart';
import 'package:you_book/domain/entities/client_photo.dart';

enum ClientPhotoCollageOrientation {
  vertical,
  horizontal,
}

@immutable
class ClientPhotoCollagePlacement {
  const ClientPhotoCollagePlacement({
    required this.photoId,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
    required this.rotationDegrees,
  });

  final String photoId;
  final double offsetX;
  final double offsetY;
  final double scale;
  final double rotationDegrees;

  Map<String, dynamic> toJson() {
    return {
      'photoId': photoId,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'scale': scale,
      'rotationDegrees': rotationDegrees,
    };
  }

  factory ClientPhotoCollagePlacement.fromJson(Map<String, dynamic> json) {
    return ClientPhotoCollagePlacement(
      photoId: json['photoId'] as String? ?? '',
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
    );
  }

  ClientPhotoCollagePlacement copyWith({
    String? photoId,
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotationDegrees,
  }) {
    return ClientPhotoCollagePlacement(
      photoId: photoId ?? this.photoId,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }
}

@immutable
class ClientPhotoCollage {
  const ClientPhotoCollage({
    required this.id,
    required this.clientId,
    required this.salonId,
    required this.createdAt,
    required this.createdBy,
    required this.orientation,
    required this.primaryPlacement,
    required this.secondaryPlacement,
    this.updatedAt,
    this.storagePath,
    this.downloadUrl,
    this.thumbnailUrl,
    this.notes,
  });

  final String id;
  final String clientId;
  final String salonId;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final ClientPhotoCollageOrientation orientation;
  final ClientPhotoCollagePlacement primaryPlacement;
  final ClientPhotoCollagePlacement secondaryPlacement;
  final String? storagePath;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final String? notes;

  ClientPhotoCollage copyWith({
    String? id,
    String? clientId,
    String? salonId,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    ClientPhotoCollageOrientation? orientation,
    ClientPhotoCollagePlacement? primaryPlacement,
    ClientPhotoCollagePlacement? secondaryPlacement,
    Object? storagePath = _unset,
    Object? downloadUrl = _unset,
    Object? thumbnailUrl = _unset,
    Object? notes = _unset,
  }) {
    return ClientPhotoCollage(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      salonId: salonId ?? this.salonId,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      orientation: orientation ?? this.orientation,
      primaryPlacement: primaryPlacement ?? this.primaryPlacement,
      secondaryPlacement: secondaryPlacement ?? this.secondaryPlacement,
      storagePath:
          storagePath == _unset ? this.storagePath : storagePath as String?,
      downloadUrl:
          downloadUrl == _unset ? this.downloadUrl : downloadUrl as String?,
      thumbnailUrl:
          thumbnailUrl == _unset ? this.thumbnailUrl : thumbnailUrl as String?,
      notes: notes == _unset ? this.notes : notes as String?,
    );
  }

  static const Object _unset = Object();
}
