// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sauh/main.dart';

void main() {
  testWidgets('Shows SAUH login screen', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const SAUHApp());

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == sauhLogoAsset,
      ),
      findsOneWidget,
    );
    expect(find.text('Entrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
