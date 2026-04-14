// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/mappers/firestore_mappers.dart';
import 'package:you_book/domain/entities/reminder_settings.dart';

void main() {
  test('reminderSettingsToMap persists birthday multi-channel fields', () {
    final settings = ReminderSettings(
      salonId: 'salon-1',
      birthdayEnabled: true,
      birthdayDeliveryMode: ReminderDeliveryMode.both,
      birthdayWhatsappTemplateId: 'wa-birthday-1',
      birthdayWhatsappTemplateName: 'Compleanno premium',
      offsets: const <ReminderOffsetConfig>[
        ReminderOffsetConfig(id: 'T24H', minutesBefore: 1440),
      ],
    );

    final map = reminderSettingsToMap(settings);

    expect(map['birthdayEnabled'], isTrue);
    expect(map['birthdayDeliveryMode'], 'both');
    expect(map['birthdayWhatsappTemplateId'], 'wa-birthday-1');
    expect(map['birthdayWhatsappTemplateName'], 'Compleanno premium');
  });

  test('reminderSettingsFromDoc restores birthday multi-channel fields', () {
    final doc = _FakeDocumentSnapshot(
      id: 'salon-1',
      data: <String, dynamic>{
        'salonId': 'salon-1',
        'birthdayEnabled': true,
        'birthdayDeliveryMode': 'whatsapp',
        'birthdayWhatsappTemplateId': 'wa-birthday-1',
        'birthdayWhatsappTemplateName': 'Compleanno premium',
        'appointmentOffsetsMinutes': const <int>[60],
      },
    );

    final settings = reminderSettingsFromDoc(doc);

    expect(settings.salonId, 'salon-1');
    expect(settings.birthdayEnabled, isTrue);
    expect(settings.birthdayDeliveryMode, ReminderDeliveryMode.whatsapp);
    expect(settings.birthdayWhatsappTemplateId, 'wa-birthday-1');
    expect(settings.birthdayWhatsappTemplateName, 'Compleanno premium');
  });
}

class _FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot({required this.id, required Map<String, dynamic> data})
    : _data = data,
      reference = _FakeDocumentReference(id);

  final Map<String, dynamic> _data;

  @override
  final String id;

  @override
  final DocumentReference<Map<String, dynamic>> reference;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocumentReference
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this.id);

  @override
  final String id;

  @override
  CollectionReference<Map<String, dynamic>> get parent =>
      _FakeCollectionReference();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionReference
    implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>>? get parent => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
