import 'package:big_decimal/big_decimal.dart';
import 'package:test/test.dart';
import 'package:debt_counter/counter.dart';

void main() {
  test('30E date distance', () {
    var dist = DebtCounter.count30E360Distance;
    expect(dist(PlainDate(2000, 1, 1), PlainDate(2000, 1, 1)), equals(0));
    expect(dist(PlainDate(2000, 1, 1), PlainDate(2000, 1, 2)), equals(1));
    expect(dist(PlainDate(2000, 1, 1), PlainDate(2000, 1, 3)), equals(2));
    expect(dist(PlainDate(2000, 1, 1), PlainDate(2000, 2, 1)), equals(30));
    expect(dist(PlainDate(2000, 1, 1), PlainDate(2000, 2, 2)), equals(31));
    expect(dist(PlainDate(2000, 1, 1), PlainDate(2001, 1, 1)), equals(360));
    expect(dist(PlainDate(2000, 2, 28), PlainDate(2000, 3, 1)), equals(3));
    expect(dist(PlainDate(2000, 2, 28), PlainDate(2001, 3, 1)), equals(363));
    expect(dist(PlainDate(2000, 1, 30), PlainDate(2000, 2, 1)), equals(1));
    expect(dist(PlainDate(2000, 1, 31), PlainDate(2000, 2, 1)), equals(1));
    expect(dist(PlainDate(2000, 12, 31), PlainDate(2001, 1, 1)), equals(1));
  });

  test('30E interrest count', () {
    var days = BigDecimal.parse("360");
    var ci = DebtCounter.countInterest;
    var dist = DebtCounter.count30E360Distance;

    pd(int a, int b, int c) => PlainDate(a, b, c);

    var inter = BigDecimal.parse("0.10")
        .divide(days, scale: 20, roundingMode: RoundingMode.HALF_UP);

    var acc = Account(BigDecimal.parse("1000"), inter);
    bigIntExpect(ci(pd(2000, 1, 1), pd(2000, 1, 1), dist, acc), 0);
    bigIntExpect(ci(pd(2000, 1, 1), pd(2000, 7, 1), dist, acc), 50);
    bigIntExpect(ci(pd(2000, 1, 1), pd(2001, 1, 1), dist, acc), 100);
  });
}

void bigIntExpect(BigDecimal res, double exp) {
  print("Test: $res vs. $exp");
  expect(res.toDouble(), closeTo(exp, 0.0001));
}
