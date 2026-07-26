import 'package:flutter_app/core/widgets/chart_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats Vietnamese chart axis amounts with explicit units', () {
    expect(compactVietnameseAmount(44400), '44,4 nghìn');
    expect(compactVietnameseAmount(1250000), '1,3 triệu');
    expect(compactVietnameseAmount(2500000000), '2,5 tỷ');
    expect(compactVietnameseAmount(750), '750');
  });
}
