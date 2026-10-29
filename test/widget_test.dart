// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wifi_checkin_flutter/main.dart';
import 'package:wifi_checkin_flutter/widgets/checkin_bottom_sheet.dart';
import 'package:wifi_checkin_flutter/widgets/leave_request_sheet.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verify that the title MaterialApp exists
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Tarot result popup scrolls', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longText =
        'Nội dung kiểm thử đủ dài để phần giải nghĩa vượt quá chiều cao popup.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckinBottomSheet(
            checkinTask: () async => true,
            locationInfo: const {},
            isAlreadyCheckedIn: true,
            tarotCard: const {
              'name': 'Four of Swords',
              'vn': 'Bốn Kiếm',
              'family': 'Bộ Kiếm',
              'keywords': 'Nghỉ ngơi,Tĩnh tâm,Hồi sức',
              'overview': longText,
              'love': longText,
              'work': longText,
              'shadow': longText,
              'action': longText,
              'dailyMessage': longText,
              'caution': longText,
              'smallAction': longText,
              'question': longText,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(SingleChildScrollView);
    expect(scrollable, findsOneWidget);
    final before = tester.state<ScrollableState>(
      find.descendant(of: scrollable, matching: find.byType(Scrollable)),
    );
    expect(before.position.maxScrollExtent, greaterThan(0));

    final mouse = await tester.startGesture(
      tester.getCenter(scrollable),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -300));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(before.position.pixels, greaterThan(0));

    before.position.jumpTo(0);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(scrollable),
        scrollDelta: const Offset(0, 160),
      ),
    );
    await tester.pump();
    expect(before.position.pixels, greaterThan(0));
  });

  testWidgets('LeaveRequestSheet renders and accepts text input', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LeaveRequestSheet(
            user: {
              'name': 'Test User',
              'email': 'test@example.com',
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Đăng ký nghỉ'), findsOneWidget);
    expect(find.text('Gửi đăng ký'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Nghỉ ốm');
    await tester.pump();
    expect(find.text('Nghỉ ốm'), findsOneWidget);
  });
}
