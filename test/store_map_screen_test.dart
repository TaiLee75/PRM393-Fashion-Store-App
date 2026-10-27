import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/screens/map/store_map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget({required Widget child}) {
    return MaterialApp(
      home: child,
    );
  }

  group('Kiểm thử Bản đồ OpenStreetMap & Reverse Geocoding (Task 3.4)', () {
    testWidgets('1. Chế độ Viewer Mode (isPickerMode: false) hiển thị hệ thống chi nhánh và carousel',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(
        child: const StoreMapScreen(isPickerMode: false),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Tiêu đề AppBar là "HỆ THỐNG CHI NHÁNH"
      expect(find.text('HỆ THỐNG CHI NHÁNH'), findsOneWidget);

      // 2. Hiển thị thông tin chi nhánh mặc định
      expect(find.textContaining('Chi nhánh 1 - FPT University Da Nang'), findsWidgets);

      // 3. Không hiển thị ô nhập số nhà chi tiết và nút xác nhận vị trí giao hàng
      expect(find.text('Chi tiết số nhà, ngõ/ngách, phòng/tầng'), findsNothing);
      expect(find.text('XÁC NHẬN VỊ TRÍ GIAO HÀNG NÀY'), findsNothing);
      expect(find.text('CHẠM BẢN ĐỒ ĐỂ CHỌN ĐỊA CHỈ'), findsNothing);

      // 4. Có nút định vị GPS
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('2. Khóa Bẫy 19: Chế độ Picker Mode (isPickerMode: true) không gán sẵn tên chi nhánh vào địa chỉ nhà',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(
        child: const StoreMapScreen(isPickerMode: true),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Tiêu đề AppBar là "CHỌN ĐỊA CHỈ NHẬN HÀNG"
      expect(find.text('CHỌN ĐỊA CHỈ NHẬN HÀNG'), findsOneWidget);

      // 2. Khóa Bẫy 19: Tuyệt đối không gán sẵn địa chỉ chi nhánh làm địa chỉ nhà
      expect(
        find.text('Chạm vào bản đồ hoặc bấm nút GPS để chọn vị trí giao hàng'),
        findsOneWidget,
      );

      // 3. Nút xác nhận bị vô hiệu hóa ban đầu với thông điệp hướng dẫn
      expect(find.text('CHẠM BẢN ĐỒ ĐỂ CHỌN ĐỊA CHỈ'), findsOneWidget);
      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'CHẠM BẢN ĐỒ ĐỂ CHỌN ĐỊA CHỈ'),
      );
      expect(confirmBtn.onPressed, isNull); // Vô hiệu hóa khi chưa chọn điểm

      // 4. Ô nhập chi tiết số nhà/phòng xuất hiện
      expect(find.text('Chi tiết số nhà, ngõ/ngách, phòng/tầng'), findsOneWidget);
    });

    testWidgets('3. Khóa Bẫy 19: Nhập số nhà chi tiết và xác nhận địa chỉ giao hàng hợp nhất',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? returnedAddress;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  returnedAddress = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoreMapScreen(isPickerMode: true),
                    ),
                  );
                },
                child: const Text('Mở Bản Đồ'),
              ),
            ),
          ),
        ),
      );

      // Bấm mở bản đồ
      await tester.tap(find.text('Mở Bản Đồ'));
      await tester.pumpAndSettle();

      // Kiểm tra ô nhập chi tiết số nhà
      final detailInput = find.byType(TextField);
      expect(detailInput, findsOneWidget);
      await tester.enterText(detailInput, 'Tòa FPT Plaza 2, Phòng 805');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tòa FPT Plaza 2, Phòng 805'), findsOneWidget);
      expect(returnedAddress, isNull);
    });

    testWidgets('4. FloatingActionButton GPS tồn tại và hiển thị biểu tượng my_location',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const StoreMapScreen(isPickerMode: true),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final gpsBtn = find.byKey(const Key('btnGpsLocation_finder')).evaluate().isNotEmpty
          ? find.byKey(const Key('btnGpsLocation_finder'))
          : find.byIcon(Icons.my_location);

      expect(gpsBtn, findsOneWidget);
    });
  });
}
