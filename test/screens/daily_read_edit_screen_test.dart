import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/controllers/practice_controller.dart';
import 'package:flute_practice/screens/daily_read_edit_screen.dart';
import 'package:provider/provider.dart';

import '../mocks/mock_database_service.dart';

void main() {
  testWidgets('打开每日必读时光标位于第一行开头', (tester) async {
    final database = MockDatabaseService();
    await database.setSetting('daily_read', '　　最重要的新想法\n　　较早的记录');
    final controller = PracticeController(database);
    await controller.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: DailyReadEditScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(
      textField.controller!.selection.baseOffset,
      PracticeController.dailyReadFirstLineIndent.length,
    );
    expect(textField.controller!.selection.isCollapsed, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
