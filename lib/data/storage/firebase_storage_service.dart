import 'dart:typed_data';

import 'package:you_book/domain/entities/client_photo.dart';
import 'package:firebase_storage/firebase_storage.dart';

class QuotePdfUploadData {
  const QuotePdfUploadData({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class PromotionImageUploadData {
  const PromotionImageUploadData({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class PromotionSectionImageUploadData {
  const PromotionSectionImageUploadData({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class LastMinuteSlotImageUploadData {
  const LastMinuteSlotImageUploadData({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class StaffAvatarUploadData {
  const StaffAvatarUploadData({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class FirebaseStorageService {
  FirebaseStorageService(this._storage);

  final FirebaseStorage _storage;

  Future<ClientPhotoUploadData> uploadClientPhoto({
    required String salonId,
    required String clientId,
    required String photoId,
    required String uploaderId,
    required Uint8List data,
    String? fileName,
    DateTime? uploadedAt,
  }) async {
    final extension = _resolveExtension(fileName);
    final contentType = _contentTypeForExtension(extension);
    final sanitizedFileName =
        (fileName != null && fileName.trim().isNotEmpty)
            ? fileName.trim()
            : 'client-photo-$photoId.$extension';
    final storagePath =
        'salon_media/$salonId/clients/$clientId/photos/$photoId.$extension';
    final reference = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=86400',
      customMetadata: {
        'uploaderId': uploaderId,
        'clientId': clientId,
        'salonId': salonId,
      },
    );
    await reference.putData(data, metadata);
    final downloadUrl = await reference.getDownloadURL();
    return ClientPhotoUploadData(
      photoId: photoId,
      salonId: salonId,
      clientId: clientId,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      uploadedAt: (uploadedAt ?? DateTime.now()).toUtc(),
      uploadedBy: uploaderId,
      fileName: sanitizedFileName,
      contentType: contentType,
      sizeBytes: data.lengthInBytes,
    );
  }

  Future<void> deleteFile(String storagePath) async {
    await _storage.ref(storagePath).delete();
  }

  Future<QuotePdfUploadData> uploadQuotePdf({
    required String salonId,
    required String quoteId,
    required Uint8List data,
    String? fileName,
    String? clientId,
    String? quoteNumber,
  }) async {
    final resolvedFileName =
        (fileName != null && fileName.trim().isNotEmpty)
            ? fileName.trim()
            : 'preventivo-$quoteId.pdf';
    final storagePath =
        'salon_media/$salonId/quotes/$quoteId/$resolvedFileName';
    final reference = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: 'application/pdf',
      cacheControl: 'public,max-age=86400',
      customMetadata: {
        'quoteId': quoteId,
        'salonId': salonId,
        if (clientId != null) 'clientId': clientId,
        if (quoteNumber != null && quoteNumber.trim().isNotEmpty)
          'quoteNumber': quoteNumber,
      },
    );
    await reference.putData(data, metadata);
    final downloadUrl = await reference.getDownloadURL();
    return QuotePdfUploadData(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
    );
  }

  Future<PromotionImageUploadData> uploadPromotionImage({
    required String salonId,
    required String promotionId,
    required Uint8List data,
    String? fileName,
    String? uploaderId,
  }) async {
    final extension = _resolveExtension(fileName);
    final contentType = _contentTypeForExtension(extension);
    final sanitizedPromotionId = promotionId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '-',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'salon_media/$salonId/promotions/$sanitizedPromotionId/cover-$timestamp.$extension';
    final reference = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=86400',
      customMetadata: {
        'salonId': salonId,
        'promotionId': promotionId,
        if (uploaderId != null && uploaderId.isNotEmpty)
          'uploadedBy': uploaderId,
      },
    );
    await reference.putData(data, metadata);
    final downloadUrl = await reference.getDownloadURL();
    return PromotionImageUploadData(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
    );
  }

  Future<PromotionSectionImageUploadData> uploadPromotionSectionImage({
    required String salonId,
    required String promotionId,
    required String sectionId,
    required Uint8List data,
    String? fileName,
    String? uploaderId,
  }) async {
    final extension = _resolveExtension(fileName);
    final contentType = _contentTypeForExtension(extension);
    final sanitizedPromotionId = promotionId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '-',
    );
    final sanitizedSectionId = sectionId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '-',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'salon_media/$salonId/promotions/$sanitizedPromotionId/sections/$sanitizedSectionId-$timestamp.$extension';
    final reference = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=86400',
      customMetadata: {
        'salonId': salonId,
        'promotionId': promotionId,
        'sectionId': sectionId,
        if (uploaderId != null && uploaderId.isNotEmpty)
          'uploadedBy': uploaderId,
      },
    );
    await reference.putData(data, metadata);
    final downloadUrl = await reference.getDownloadURL();
    return PromotionSectionImageUploadData(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
    );
  }

  Future<LastMinuteSlotImageUploadData> uploadLastMinuteSlotImage({
    required String salonId,
    required String slotId,
    required Uint8List data,
    String? fileName,
    String? uploaderId,
  }) async {
    final extension = _resolveExtension(fileName);
    final contentType = _contentTypeForExtension(extension);
    final sanitizedSlotId = slotId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'salon_media/$salonId/last_minute_slots/$sanitizedSlotId/card-$timestamp.$extension';
    final reference = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=3600',
      customMetadata: {
        'salonId': salonId,
        'slotId': slotId,
        if (uploaderId != null && uploaderId.isNotEmpty)
          'uploadedBy': uploaderId,
      },
    );
    await reference.putData(data, metadata);
    final downloadUrl = await reference.getDownloadURL();
    return LastMinuteSlotImageUploadData(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
    );
  }

  Future<StaffAvatarUploadData> uploadStaffAvatar({
    required String salonId,
    required String staffId,
    required Uint8List data,
    String? fileName,
    String? uploaderId,
  }) async {
    final extension = _resolveExtension(fileName);
    final contentType = _contentTypeForExtension(extension);
    final sanitizedStaffId = staffId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '-',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath =
        'salon_media/$salonId/staff/$sanitizedStaffId/avatar-$timestamp.$extension';
    final reference = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=86400',
      customMetadata: {
        'salonId': salonId,
        'staffId': staffId,
        if (uploaderId != null && uploaderId.isNotEmpty)
          'uploadedBy': uploaderId,
      },
    );
    await reference.putData(data, metadata);
    final downloadUrl = await reference.getDownloadURL();
    return StaffAvatarUploadData(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
    );
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
