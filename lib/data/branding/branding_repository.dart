import 'package:cloud_firestore/cloud_firestore.dart';
import 'branding_model.dart';

class BrandingRepository {
  BrandingRepository(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<BrandingModel> watchSalonBranding(String salonId) {
    return _firestore
        .collection('salons')
        .doc(salonId)
        .snapshots()
        .map(
          (snapshot) => BrandingModel.fromMap(
            snapshot.data()?['branding'] as Map<String, dynamic>?,
          ),
        );
  }

  Future<void> saveSalonBranding({
    required String salonId,
    required BrandingModel data,
  }) async {
    await _firestore.collection('salons').doc(salonId).set({
      'branding': data.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
