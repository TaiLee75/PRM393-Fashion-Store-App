import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_store_app/models/branch_model.dart';

void main() {
  group('BranchModel Serialization Tests', () {
    test('fromMap and toMap serialize correctly', () {
      final now = DateTime(2026, 10, 21, 12, 0, 0);
      final branch = BranchModel(
        id: 'branch_1',
        name: 'Chi nhánh Da Nang',
        address: 'FPT City',
        latitude: 15.9689,
        longitude: 108.2608,
        phone: '0236 730 0999',
        createdAt: now,
      );

      final map = branch.toMap();
      expect(map['id'], 'branch_1');
      expect(map['name'], 'Chi nhánh Da Nang');
      expect(map['latitude'], 15.9689);
      expect(map['longitude'], 108.2608);
      expect(map['phone'], '0236 730 0999');
      expect(map['createdAt'], isA<Timestamp>());

      final restored = BranchModel.fromMap(map, 'branch_1');
      expect(restored.id, 'branch_1');
      expect(restored.name, 'Chi nhánh Da Nang');
      expect(restored.location.latitude, 15.9689);
      expect(restored.location.longitude, 108.2608);
      expect(restored.phone, '0236 730 0999');
    });

    test('copyWith works correctly', () {
      final branch = BranchModel(
        id: 'branch_1',
        name: 'Chi nhánh 1',
        address: 'Địa chỉ 1',
        latitude: 15.0,
        longitude: 108.0,
        createdAt: DateTime.now(),
      );

      final updated = branch.copyWith(name: 'Chi nhánh Mới', phone: '0901234567');
      expect(updated.name, 'Chi nhánh Mới');
      expect(updated.phone, '0901234567');
      expect(updated.id, 'branch_1');
      expect(updated.latitude, 15.0);
    });
  });
}
