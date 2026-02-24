import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' as image_picker;

const XTypeGroup _imageTypeGroup = XTypeGroup(
  label: 'Immagini',
  uniformTypeIdentifiers: <String>['public.image'],
  extensions: <String>[
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'heic',
    'heif',
    'tif',
    'tiff',
  ],
);

final image_picker.ImagePicker _imagePicker = image_picker.ImagePicker();
const MethodChannel _platformInfoChannel = MethodChannel(
  'you_book/platform_info',
);
Future<bool>? _cachedIsIOSAppOnMac;

Future<bool> _isIOSAppOnMac() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return Future<bool>.value(false);
  }
  return _cachedIsIOSAppOnMac ??= _queryIsIOSAppOnMac();
}

Future<bool> _queryIsIOSAppOnMac() async {
  try {
    final value = await _platformInfoChannel.invokeMethod<bool>(
      'isIOSAppOnMac',
    );
    return value ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> _useImagePickerGallery() async {
  if (kIsWeb) {
    return false;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return true;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return !(await _isIOSAppOnMac());
  }
  return false;
}

Future<XFile?> pickSingleImageFile({
  String confirmButtonText = 'Seleziona',
}) async {
  if (await _useImagePickerGallery()) {
    try {
      return await _imagePicker.pickImage(
        source: image_picker.ImageSource.gallery,
      );
    } catch (_) {
      // Fallback for platforms/devices where image_picker gallery is unavailable.
    }
  }
  return openFile(
    acceptedTypeGroups: const <XTypeGroup>[_imageTypeGroup],
    confirmButtonText: confirmButtonText,
  );
}

Future<List<XFile>> pickMultipleImageFiles({
  String confirmButtonText = 'Seleziona',
  int? limit,
}) async {
  if (await _useImagePickerGallery()) {
    try {
      return await _imagePicker.pickMultiImage(limit: limit);
    } catch (_) {
      // Fallback for platforms/devices where multi-image picking isn't available.
    }
  }
  return openFiles(
    acceptedTypeGroups: const <XTypeGroup>[_imageTypeGroup],
    confirmButtonText: confirmButtonText,
  );
}
