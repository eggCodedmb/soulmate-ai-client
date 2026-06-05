import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soulmate_ai/app.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SoulMateApp(),
      ),
    );

    // 验证应用能正常渲染
    expect(find.byType(SoulMateApp), findsOneWidget);
  });
}
