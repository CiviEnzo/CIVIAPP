import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/reminder_settings.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/screens/admin/modules/messages_module.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('birthday WhatsApp selector is hidden for push-only mode', (
    tester,
  ) async {
    await _pumpModule(
      tester,
      reminderSettings: ReminderSettings(
        salonId: _salon.id,
        birthdayDeliveryMode: ReminderDeliveryMode.push,
      ),
      messageTemplates: const <MessageTemplate>[],
    );

    expect(
      find.byKey(const ValueKey('birthday_delivery_mode_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('birthday_whatsapp_template_field')),
      findsNothing,
    );
    expect(find.text('Solo push'), findsOneWidget);
  });

  testWidgets('module stays readable on 390px phone viewport', (tester) async {
    await _pumpModule(
      tester,
      reminderSettings: ReminderSettings(
        salonId: _salon.id,
        birthdayDeliveryMode: ReminderDeliveryMode.push,
      ),
      messageTemplates: const <MessageTemplate>[],
      size: const Size(390, 844),
    );

    await tester.ensureVisible(find.text('Promemoria appuntamenti'));

    expect(find.text('Promemoria appuntamenti'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'birthday WhatsApp selector is shown when whatsapp mode is active',
    (tester) async {
      const birthdayTemplate = MessageTemplate(
        id: 'wa-birthday-1',
        salonId: _salonId,
        title: 'Compleanno premium',
        body: 'Buon compleanno {{firstName}} da {{salonName}}',
        channel: MessageChannel.whatsapp,
        usage: TemplateUsage.birthday,
        isActive: true,
        metaTemplateName: 'birthday_template_it',
        metaTemplateLanguage: 'it',
      );

      await _pumpModule(
        tester,
        reminderSettings: ReminderSettings(
          salonId: _salon.id,
          birthdayDeliveryMode: ReminderDeliveryMode.whatsapp,
          birthdayWhatsappTemplateId: birthdayTemplate.id,
          birthdayWhatsappTemplateName: birthdayTemplate.title,
        ),
        messageTemplates: const <MessageTemplate>[birthdayTemplate],
      );

      expect(
        find.byKey(const ValueKey('birthday_whatsapp_template_field')),
        findsOneWidget,
      );
      expect(find.text('Compleanno premium'), findsWidgets);
      expect(find.text('Solo WhatsApp'), findsOneWidget);
    },
  );

  testWidgets(
    'birthday whatsapp mode is rejected when no birthday templates exist',
    (tester) async {
      await _pumpModule(
        tester,
        reminderSettings: ReminderSettings(
          salonId: _salon.id,
          birthdayDeliveryMode: ReminderDeliveryMode.push,
        ),
        messageTemplates: const <MessageTemplate>[],
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('birthday_delivery_mode_field')),
      );
      await tester.tap(
        find.byKey(const ValueKey('birthday_delivery_mode_field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('WhatsApp').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text(
          'Nessun template WhatsApp (uso Compleanno) disponibile. Crea o importa prima un template compleanno.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('birthday_whatsapp_template_field')),
        findsNothing,
      );
      expect(find.text('Solo push'), findsOneWidget);
    },
  );

  testWidgets('birthday panel highlights missing configured WhatsApp template', (
    tester,
  ) async {
    const availableTemplate = MessageTemplate(
      id: 'wa-birthday-active',
      salonId: _salonId,
      title: 'Template attivo',
      body: 'Buon compleanno {{firstName}}',
      channel: MessageChannel.whatsapp,
      usage: TemplateUsage.birthday,
      isActive: true,
      metaTemplateName: 'birthday_active_it',
      metaTemplateLanguage: 'it',
    );

    await _pumpModule(
      tester,
      reminderSettings: ReminderSettings(
        salonId: _salon.id,
        birthdayDeliveryMode: ReminderDeliveryMode.whatsapp,
        birthdayWhatsappTemplateId: 'missing-template',
        birthdayWhatsappTemplateName: 'Template non piu presente',
      ),
      messageTemplates: const <MessageTemplate>[availableTemplate],
    );

    expect(
      find.text(
        'Template compleanno selezionato non disponibile o non piu attivo. Selezionane uno nuovo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'module keeps whatsapp birthday controls visible on 430px viewport',
    (tester) async {
      const birthdayTemplate = MessageTemplate(
        id: 'wa-birthday-2',
        salonId: _salonId,
        title: 'Compleanno mobile',
        body: 'Buon compleanno {{firstName}}',
        channel: MessageChannel.whatsapp,
        usage: TemplateUsage.birthday,
        isActive: true,
        metaTemplateName: 'birthday_mobile_it',
        metaTemplateLanguage: 'it',
      );

      await _pumpModule(
        tester,
        reminderSettings: ReminderSettings(
          salonId: _salon.id,
          birthdayDeliveryMode: ReminderDeliveryMode.whatsapp,
          birthdayWhatsappTemplateId: birthdayTemplate.id,
          birthdayWhatsappTemplateName: birthdayTemplate.title,
        ),
        messageTemplates: const <MessageTemplate>[birthdayTemplate],
        size: const Size(430, 932),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('birthday_whatsapp_template_field')),
      );

      expect(
        find.byKey(const ValueKey('birthday_whatsapp_template_field')),
        findsOneWidget,
      );
      expect(find.text('Solo WhatsApp'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

const String _salonId = 'salon-1';

const Salon _salon = Salon(
  id: _salonId,
  name: 'You Book Test',
  address: 'Via Roma 1',
  city: 'Roma',
  phone: '+39061234567',
  email: 'test@youbook.it',
);

Future<void> _pumpModule(
  WidgetTester tester, {
  required ReminderSettings reminderSettings,
  required List<MessageTemplate> messageTemplates,
  Size size = const Size(1440, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final state = AppDataState.initial().copyWith(
    salons: const <Salon>[_salon],
    reminderSettings: <ReminderSettings>[reminderSettings],
    messageTemplates: messageTemplates,
  );
  final sessionController =
      SessionController()..updateUser(
        const AppUser(
          uid: 'admin-1',
          role: UserRole.admin,
          salonIds: <String>[_salonId],
        ),
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDataProvider.overrideWith((ref) => _TestAppDataStore(state)),
        sessionControllerProvider.overrideWith((ref) => sessionController),
      ],
      child: AppNoticeScope(
        child: MaterialApp(
          locale: const Locale('it', 'IT'),
          supportedLocales: const [Locale('it', 'IT')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            return AppNoticeViewport(
              controller: AppNoticeScope.of(context),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const Scaffold(
            body: MessagesMarketingModule(salonId: _salonId),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState initialState) : super(currentUser: null) {
    state = initialState;
  }

  @override
  Future<void> upsertReminderSettings(ReminderSettings settings) async {
    state = state.copyWith(
      reminderSettings: <ReminderSettings>[
        settings.copyWith(updatedAt: DateTime(2026, 3, 11, 10)),
      ],
    );
  }
}
