import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:you_book/data/mock_data.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: false);

  final dryRun = args.contains('--dry-run');

  stdout.writeln('--- Aggiornamento saloni ---');
  for (final sample in MockData.salons) {
    await _updateSalon(firestore, sample, dryRun: dryRun);
  }

  stdout.writeln('--- Aggiornamento servizi ---');
  for (final service in MockData.services) {
    await _updateService(firestore, service, dryRun: dryRun);
  }

  stdout.writeln(
    dryRun
        ? 'Dry-run completato. Nessuna modifica applicata.'
        : 'Aggiornamento completato con successo.',
  );
}

Future<void> _updateSalon(
  FirebaseFirestore firestore,
  Salon sample, {
  required bool dryRun,
}) async {
  final docRef = firestore.collection('salons').doc(sample.id);
  final snapshot = await docRef.get();
  if (!snapshot.exists) {
    stdout.writeln('• Salone ${sample.id} non trovato. Ignorato.');
    return;
  }

  final current = snapshot.data() ?? <String, dynamic>{};
  final update = _buildSalonUpdate(current, sample);
  if (update.isEmpty) {
    stdout.writeln('• Salone ${sample.id}: nessun aggiornamento necessario.');
    return;
  }

  if (dryRun) {
    stdout.writeln(
      '• Salone ${sample.id} → aggiornamenti: ${update.keys.join(', ')}',
    );
    return;
  }

  await docRef.set(update, SetOptions(merge: true));
  stdout.writeln('• Salone ${sample.id} aggiornato.');
}

Future<void> _updateService(
  FirebaseFirestore firestore,
  Service service, {
  required bool dryRun,
}) async {
  if (service.requiredEquipmentIds.isEmpty) {
    return;
  }
  final docRef = firestore.collection('services').doc(service.id);
  final snapshot = await docRef.get();
  if (!snapshot.exists) {
    stdout.writeln('• Servizio ${service.id} non trovato. Ignorato.');
    return;
  }

  final data = snapshot.data() ?? <String, dynamic>{};
  final existing =
      (data['requiredEquipmentIds'] as List?)
          ?.map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList();
  if (existing != null && existing.isNotEmpty) {
    stdout.writeln(
      '• Servizio ${service.id}: requiredEquipmentIds già presenti.',
    );
    return;
  }

  final update = <String, dynamic>{
    'requiredEquipmentIds': service.requiredEquipmentIds,
  };

  if (dryRun) {
    stdout.writeln(
      '• Servizio ${service.id} → aggiunta requiredEquipmentIds ${service.requiredEquipmentIds}',
    );
    return;
  }

  await docRef.set(update, SetOptions(merge: true));
  stdout.writeln('• Servizio ${service.id} aggiornato.');
}

Map<String, dynamic> _buildSalonUpdate(
  Map<String, dynamic> current,
  Salon sample,
) {
  final update = <String, dynamic>{};

  void setIfMissing(String key, Object? value) {
    if (value == null) {
      return;
    }
    final existing = current[key];
    if (existing == null) {
      update[key] = value;
    } else if (existing is String && existing.trim().isEmpty) {
      update[key] = value;
    }
  }

  setIfMissing('postalCode', sample.postalCode);
  setIfMissing('bookingLink', sample.bookingLink);
  setIfMissing('latitude', sample.latitude);
  setIfMissing('longitude', sample.longitude);

  if (!current.containsKey('status')) {
    update['status'] = sample.status.name;
  }

  final equipment = current['equipment'];
  if (equipment == null || (equipment is List && equipment.isEmpty)) {
    update['equipment'] =
        sample.equipment
            .map(
              (item) => {
                'id': item.id,
                'name': item.name,
                'quantity': item.quantity,
                'status': item.status.name,
                'notes': item.notes,
              },
            )
            .toList();
  }

  final closures = current['closures'];
  if (closures == null && sample.closures.isNotEmpty) {
    update['closures'] =
        sample.closures
            .map(
              (closure) => {
                'id': closure.id,
                'start': Timestamp.fromDate(closure.start),
                'end': Timestamp.fromDate(closure.end),
                'reason': closure.reason,
              },
            )
            .toList();
  }

  final currentRooms = current['rooms'];
  if (currentRooms is List) {
    var roomsUpdated = false;
    final updatedRooms =
        currentRooms.map((room) {
          final roomMap = Map<String, dynamic>.from(
            room as Map<String, dynamic>,
          );
          if (roomMap['category'] == null) {
            final sampleRoom = sample.rooms.firstWhereOrNull(
              (item) => item.id == roomMap['id'],
            );
            if (sampleRoom?.category != null) {
              roomMap['category'] = sampleRoom!.category;
              roomsUpdated = true;
            }
          }
          return roomMap;
        }).toList();
    if (roomsUpdated) {
      update['rooms'] = updatedRooms;
    }
  } else if (sample.rooms.isNotEmpty) {
    update['rooms'] =
        sample.rooms
            .map(
              (room) => {
                'id': room.id,
                'name': room.name,
                'capacity': room.capacity,
                'category': room.category,
                'services': room.services,
              },
            )
            .toList();
  }

  return update;
}
