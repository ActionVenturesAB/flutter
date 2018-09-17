// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

import '../widgets/semantics_tester.dart';

void main() {
  testWidgets('Verify that a tap dismisses a modal BottomSheet', (WidgetTester tester) async {
    BuildContext savedContext;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          savedContext = context;
          return Container();
        }
      )
    ));

    await tester.pump();
    expect(find.text('BottomSheet'), findsNothing);

    bool showBottomSheetThenCalled = false;
    showModalBottomSheet<Null>(
      context: savedContext,
      builder: (BuildContext context) => SingleChildScrollView(primary: true, child: const Text('BottomSheet'))
    ).then<void>((Null result) {
      expectSync(result, isNull);
      showBottomSheetThenCalled = true;
    });

    await tester.pump(); // bottom sheet show animation starts
    await tester.pump(const Duration(seconds: 1)); // animation done
    expect(find.text('BottomSheet'), findsOneWidget);
    expect(showBottomSheetThenCalled, isFalse);

    // Tap on the modal barrier area dismisses
    await tester.tapAt(const Offset(100.0, 100.0));
    await tester.pump(); // bottom sheet dismiss animation starts
    expect(showBottomSheetThenCalled, isTrue);
    await tester.pump(const Duration(seconds: 1)); // last frame of animation (sheet is entirely off-screen, but still present)
    await tester.pump(const Duration(seconds: 1)); // frame after the animation (sheet has been removed)
    expect(find.text('BottomSheet'), findsNothing);

    showBottomSheetThenCalled = false;
    showModalBottomSheet<Null>(
      context: savedContext,
      builder: (BuildContext context) => SingleChildScrollView(primary: true, child: const Text('BottomSheet')),
    ).then<void>((Null result) {
      expectSync(result, isNull);
      showBottomSheetThenCalled = true;
    });
    await tester.pump(); // bottom sheet show animation starts
    await tester.pump(const Duration(seconds: 1)); // animation done
    expect(find.text('BottomSheet'), findsOneWidget);
    expect(showBottomSheetThenCalled, isFalse);

    // Tap above the bottom sheet to dismiss it
    await tester.tapAt(const Offset(20.0, 20.0));
    await tester.pump(); // bottom sheet dismiss animation starts
    expect(showBottomSheetThenCalled, isTrue);
    await tester.pump(const Duration(seconds: 1)); // animation done
    await tester.pump(const Duration(seconds: 1)); // rebuild frame
    expect(find.text('BottomSheet'), findsNothing);
  });

  testWidgets('Verify that a downwards fling dismisses a persistent BottomSheet', (WidgetTester tester) async {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    bool showBottomSheetThenCalled = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        key: scaffoldKey,
        body: const Center(child: Text('body'))
      )
    ));

    expect(showBottomSheetThenCalled, isFalse);
    expect(find.text('BottomSheet'), findsNothing);

    scaffoldKey.currentState.showBottomSheet<Null>((BuildContext context) {
      return SingleChildScrollView(
        primary: true,
        child: Container(
          margin: const EdgeInsets.all(40.0),
          child: const Text('BottomSheet')
        ),
      );
    }).closed.whenComplete(() {
      print('POPPED');
      showBottomSheetThenCalled = true;
    });

    expect(showBottomSheetThenCalled, isFalse);
    expect(find.text('BottomSheet'), findsNothing);

    await tester.pump(); // bottom sheet show animation starts

    expect(showBottomSheetThenCalled, isFalse);
    expect(find.text('BottomSheet'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1)); // animation done

    expect(showBottomSheetThenCalled, isFalse);
    expect(find.text('BottomSheet'), findsOneWidget);

    await tester.fling(find.text('BottomSheet'), const Offset(0.0, 500.0), 2000.0);
    await tester.pumpAndSettle(); // drain the microtask queue (Future completion callback)

    expect(showBottomSheetThenCalled, isTrue);
    expect(find.text('BottomSheet'), findsNothing);
  });

  testWidgets('Verify that dragging past the bottom dismisses a persistent BottomSheet', (WidgetTester tester) async {
    // This is a regression test for https://github.com/flutter/flutter/issues/5528
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        key: scaffoldKey,
        body: const Center(child: Text('body'))
      )
    ));

    scaffoldKey.currentState.showBottomSheet<Null>((BuildContext context) {
      return SingleChildScrollView(
        primary: true,
        child: Container(
          margin: const EdgeInsets.all(40.0),
          child: const Text('BottomSheet')
        ),
      );
    });

    await tester.pump(); // bottom sheet show animation starts
    await tester.pump(const Duration(seconds: 1)); // animation done
    expect(find.text('BottomSheet'), findsOneWidget);

    await tester.fling(find.text('BottomSheet'), const Offset(0.0, 400.0), 1000.0);
    await tester.pump(); // drain the microtask queue (Future completion callback)
    await tester.pump(); // bottom sheet dismiss animation starts
    await tester.pump(const Duration(seconds: 1)); // animation done

    expect(find.text('BottomSheet'), findsNothing);
  });

  testWidgets('modal BottomSheet has no top MediaQuery', (WidgetTester tester) async {
    BuildContext outerContext;
    BuildContext innerContext;

    await tester.pumpWidget(Localizations(
      locale: const Locale('en', 'US'),
      delegates: const <LocalizationsDelegate<dynamic>>[
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.all(50.0),
          ),
          child: Navigator(
            onGenerateRoute: (_) {
              return PageRouteBuilder<void>(
                pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
                  outerContext = context;
                  return Container();
                },
              );
            },
          ),
        ),
      ),
    ));

    showModalBottomSheet<void>(
      context: outerContext,
      builder: (BuildContext context) {
        innerContext = context;
        return SingleChildScrollView(primary: true, child: Container());
      },
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      MediaQuery.of(outerContext).padding,
      const EdgeInsets.all(50.0),
    );
    expect(
      MediaQuery.of(innerContext).padding,
      const EdgeInsets.only(left: 50.0, right: 50.0, bottom: 50.0),
    );
  });

  testWidgets('modal BottomSheet has semantics', (WidgetTester tester) async {
    final SemanticsTester semantics = SemanticsTester(tester);
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        key: scaffoldKey,
        body: const Center(child: Text('body'))
      )
    ));


    showModalBottomSheet<void>(context: scaffoldKey.currentContext, builder: (BuildContext context) {
      return SingleChildScrollView(
        primary: true,
        child: Container(
          child: const Text('BottomSheet')
        ),
      );
    });

    await tester.pump(); // bottom sheet show animation starts
    await tester.pump(const Duration(seconds: 1)); // animation done

    expect(semantics, hasSemantics(TestSemantics.root(
      children: <TestSemantics>[
        TestSemantics.rootChild(
          children: <TestSemantics>[
            TestSemantics(
              label: 'Dialog',
              textDirection: TextDirection.ltr,
              flags: <SemanticsFlag>[
                SemanticsFlag.scopesRoute,
                SemanticsFlag.namesRoute,
              ],
              children: <TestSemantics>[
                TestSemantics(
                  actions: <SemanticsAction>[SemanticsAction.scrollUp],
                  children: <TestSemantics>[
                    TestSemantics(
                      label: 'BottomSheet',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ), ignoreTransform: true, ignoreRect: true, ignoreId: true));
    semantics.dispose();
  });
}
