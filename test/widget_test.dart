import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsound/main.dart';

void main() {
  testWidgets('WhatSound presenta búsqueda web y biblioteca', (tester) async {
    await tester.pumpWidget(const WhatSoundApp());
    expect(find.text('WhatSound'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Resultados de Internet'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.byTooltip('Buscar en Internet'), findsOneWidget);
  });

  testWidgets('La búsqueda permite ingresar frases', (tester) async {
    await tester.pumpWidget(const WhatSoundApp());
    await tester.enterText(find.byType(TextField), 'Gallo Claudio');
    await tester.pump();
    expect(find.text('Gallo Claudio'), findsOneWidget);
  });
  testWidgets('La interfaz no desborda en horizontal', (tester) async {
    tester.view.physicalSize = const Size(960, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const WhatSoundApp());
    await tester.tap(find.text('Biblioteca'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Enlaces comprobados'), findsOneWidget);
  });}
