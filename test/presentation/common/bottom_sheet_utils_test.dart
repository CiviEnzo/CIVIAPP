import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppSheetHeader renders title, subtitle and close button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: AppSheetHeader(
            title: 'Titolo sheet',
            subtitle: 'Sottotitolo sheet',
          ),
        ),
      ),
    );

    expect(find.text('Titolo sheet'), findsOneWidget);
    expect(find.text('Sottotitolo sheet'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('AppSheetFooter renders divider and child content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: AppSheetFooter(child: Text('Azioni footer'))),
      ),
    );

    expect(find.byType(Divider), findsOneWidget);
    expect(find.text('Azioni footer'), findsOneWidget);
  });

  testWidgets('DialogActionLayout keeps footer stable while body scrolls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 420,
              height: 320,
              child: DialogActionLayout(
                title: 'Titolo',
                subtitle: 'Sottotitolo',
                actions: const [],
                footer: const Text('Footer CTA'),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List<Widget>.generate(
                    30,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Riga $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final footerFinder = find.text('Footer CTA');
    final scrollableFinder = find.descendant(
      of: find.byType(DialogActionLayout),
      matching: find.byType(SingleChildScrollView),
    );
    final initialFooterTop = tester.getTopLeft(footerFinder).dy;

    await tester.drag(scrollableFinder, const Offset(0, -220));
    await tester.pumpAndSettle();

    final afterFooterTop = tester.getTopLeft(footerFinder).dy;
    expect(afterFooterTop, initialFooterTop);
  });

  testWidgets('DialogActionLayout renders phone footer inline in scroll body', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 390,
            height: 520,
            child: DialogActionLayout(
              title: 'Titolo',
              subtitle: 'Sottotitolo',
              actions: const [],
              footer: const Text('Footer CTA'),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(
                  20,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Riga $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppMobileSheetPageScaffold), findsOneWidget);
    expect(find.text('Footer CTA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DialogActionLayout fits compact widths without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 320,
            height: 360,
            child: DialogActionLayout(
              title: 'Titolo molto lungo per testare il layout compatto',
              subtitle: 'Sottotitolo compatto',
              actions: [
                OutlinedButton(onPressed: () {}, child: const Text('Annulla')),
                FilledButton(onPressed: () {}, child: const Text('Salva')),
              ],
              body: const Text(
                'Contenuto di prova per validare il layout su larghezze ridotte.',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showAppModalSheet opens a full-screen route on phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed:
                          () => showAppModalSheet<void>(
                            context: context,
                            includeCloseButton: false,
                            builder:
                                (sheetContext) => AppMobileSheetPageScaffold(
                                  title: 'Titolo',
                                  body: const SizedBox.shrink(),
                                ),
                          ),
                      child: const Text('Apri sheet'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AppMobileSheetPageScaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showAppModalSheet opens a bottom sheet on phone when compact', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder:
                  (context) => FilledButton(
                    onPressed:
                        () => showAppModalSheet<void>(
                          context: context,
                          barrierDismissible: true,
                          compactWrapContent: true,
                          builder:
                              (_) => const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Azione rapida'),
                              ),
                        ),
                    child: const Text('Apri compact'),
                  ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri compact'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Azione rapida'), findsOneWidget);
    expect(find.byType(AppMobileSheetPageScaffold), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showAppModalSheet provides Material for legacy phone content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => FilledButton(
                  onPressed:
                      () => showAppModalSheet<void>(
                        context: context,
                        includeCloseButton: false,
                        builder:
                            (_) => Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: 'uno',
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'uno',
                                        child: Text('Uno'),
                                      ),
                                    ],
                                    onChanged: (_) {},
                                  ),
                                ],
                              ),
                            ),
                      ),
                  child: const Text('Apri legacy'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri legacy'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showAppSelectionSheet uses bottom sheet on phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => FilledButton(
                  onPressed:
                      () => showAppSelectionSheet<String>(
                        context: context,
                        title: 'Seleziona opzione',
                        items: const ['Uno', 'Due'],
                        labelBuilder: (item) => item,
                      ),
                  child: const Text('Apri selezione'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri selezione'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Seleziona opzione'), findsOneWidget);
    expect(find.text('Uno'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
