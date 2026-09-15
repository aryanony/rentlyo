import 'package:flutter_test/flutter_test.dart';
import 'package:rentlyo_admin/models/unit_model.dart';

void main() {
  group('Unit Type Separation Tests', () {
    test('Commercial unit with default category becomes shop', () {
      final unit = UnitModel(
        id: 'u1',
        propertyId: 'p1',
        label: 'G6',
        type: 'commercial',
        floor: 'Ground',
        status: 'vacant',
      );

      expect(unit.type, equals('commercial'));
      expect(unit.category, equals('shop'));
    });

    test('Residential unit with default category becomes flat', () {
      final unit = UnitModel(
        id: 'u2',
        propertyId: 'p1',
        label: 'R101',
        type: 'residential',
        floor: '1st',
        status: 'vacant',
      );

      expect(unit.type, equals('residential'));
      expect(unit.category, equals('flat'));
    });

    test('UnitModel.fromMap corrects legacy misconfigured commercial flat unit', () {
      final map = {
        'propertyId': 'p1',
        'label': 'G6',
        'type': 'commercial',
        'category': 'flat',
        'floor': 'Ground',
        'status': 'vacant',
      };

      final unit = UnitModel.fromMap(map, 'u3');
      expect(unit.type, equals('commercial'));
      expect(unit.category, equals('shop'));
    });

    test('UnitModel.fromMap corrects legacy misconfigured residential shop unit', () {
      final map = {
        'propertyId': 'p1',
        'label': 'Res 1',
        'type': 'residential',
        'category': 'shop',
        'floor': '1st',
        'status': 'vacant',
      };

      final unit = UnitModel.fromMap(map, 'u4');
      expect(unit.type, equals('residential'));
      expect(unit.category, equals('flat'));
    });
  });
}
