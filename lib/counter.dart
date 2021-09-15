import 'package:big_decimal/big_decimal.dart';

class PlainDate implements Comparable<PlainDate> {
  final int year;
  final int month;
  final int day;
  final DateTime asDate;

  PlainDate(this.year, this.month, this.day) : asDate = DateTime.utc(year, month, day);

  @override
  int compareTo(PlainDate other) {
    return asDate.compareTo(other.asDate);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PlainDate && runtimeType == other.runtimeType && year == other.year && month == other.month && day == other.day;

  @override
  int get hashCode => year.hashCode ^ month.hashCode ^ day.hashCode;

  @override
  String toString() {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}

enum EventType { BALANCE, EXPECTATION, SANCTION, PAYMENT, SNAPSHOT }

class DebtEvent implements Comparable<DebtEvent> {
  final EventType type;
  final BigDecimal amount;
  final PlainDate date;

  DebtEvent(this.type, this.amount, this.date);

  @override
  int compareTo(DebtEvent other) {
    return date.compareTo(other.date);
  }
}

class Account {
  final BigDecimal balance;
  final BigDecimal dailyInterrest;

  Account.parse(String balance, String dailyInterrest) : this(BigDecimal.parse(balance), BigDecimal.parse(dailyInterrest));

  Account(this.balance, this.dailyInterrest);

  Account withBalance(BigDecimal newBalance) => Account(newBalance, this.dailyInterrest);

  Account addBalance(BigDecimal addBalance) => Account(this.balance + addBalance, this.dailyInterrest);
}

class DebtSnapshot {
  final PlainDate date;
  final BigDecimal principal;
  final BigDecimal principalInterest;
  final BigDecimal late;
  final BigDecimal lateInterest;
  final BigDecimal sanctions;
  final BigDecimal sanctionsInterest;
  final BigDecimal sum;

  DebtSnapshot(this.date, this.principal, this.principalInterest, this.late, this.lateInterest, this.sanctions, this.sanctionsInterest)
      : sum = principal + principalInterest + lateInterest + sanctions + sanctionsInterest;

  @override
  String toString() {
    return 'DebtSnapshot{${date} principal: $principal, principalInterest: $principalInterest, late: $late, lateInterest: $lateInterest, sanctions: $sanctions, sanctionsInterest: $sanctionsInterest => $sum}';
  }
}

class Debt {
  PlainDate? lastEvent;

  BigDecimal zero = BigDecimal.parse("0");

  Account principal = Account.parse("0", (1.10 / 360).toString());
  Account principalInterest = Account.parse("0", "0");
  Account late = Account.parse("0", (0.15 / 360).toString());
  Account lateInterest = Account.parse("0", "0");
  Account sanctions = Account.parse("0", "0");
  Account sanctionsInterest = Account.parse("0", "0");

  Debt();

  BigDecimal get sum {
    return principal.balance + principalInterest.balance + late.balance + sanctions.balance;
  }

  void apply(DebtEvent e) {
    if (lastEvent != null && lastEvent != e.date) {
      principalInterest = principalInterest.addBalance(DebtCounter.countInterest(lastEvent!, e.date, DebtCounter.count30E360Distance, principal));
      lateInterest = lateInterest.addBalance(DebtCounter.countInterest(lastEvent!, e.date, DebtCounter.count30E360Distance, late));
    }
    lastEvent = e.date;
    if (e.type == EventType.BALANCE) {
      principal = principal.addBalance(e.amount);
    }
    if (e.type == EventType.EXPECTATION) {
      if (e.amount < zero) throw Exception("Expectation cannot be negative");
      late = late.addBalance(e.amount);
    }
    if (e.type == EventType.PAYMENT) {
      if (e.amount < zero) throw Exception("Payment cannot be negative");
      principal = principal.addBalance(-e.amount);
      late = late.addBalance(-e.amount);
    }
    if (e.type == EventType.SANCTION) {
      sanctions = sanctions.addBalance(e.amount);
    }
  }

  DebtSnapshot get snapshot {
    return DebtSnapshot(
        lastEvent ?? PlainDate(1, 1, 1),
        this.principal.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
        this.principalInterest.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
        this.late.balance > zero ? this.late.balance.withScale(2, roundingMode: RoundingMode.HALF_UP) : zero,
        this.lateInterest.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
        this.sanctions.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
        this.sanctionsInterest.balance.withScale(2, roundingMode: RoundingMode.HALF_UP));
  }
}

typedef int DistanceCounter(PlainDate a, PlainDate b);

class DebtCounter {
  static int count30E360Distance(PlainDate a, PlainDate b) {
    int ad = a.day;
    if (ad > 30) ad = 30;
    int bd = b.day;
    if (bd > 30) bd = 30;
    return 360 * (b.year - a.year) + 30 * (b.month - a.month) + (bd - ad);
  }

  static BigDecimal countInterest(PlainDate from, PlainDate to, DistanceCounter counter, Account acc) {
    int distance = counter(from, to);
    var dist = BigDecimal.fromBigInt(BigInt.from(distance));
    return acc.balance * dist * acc.dailyInterrest;
  }
}
