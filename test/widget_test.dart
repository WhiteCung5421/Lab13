import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:expense_tracker_provider/main.dart';
import 'package:expense_tracker_provider/providers/transaction_provider.dart';

void main() {
  testWidgets('shows empty transaction list', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => TransactionProvider(),
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('รายรับ-รายจ่าย'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}