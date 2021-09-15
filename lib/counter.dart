import 'package:big_decimal/big_decimal.dart';

class PlainDate implements Comparable<PlainDate> {
  final int year;
  final int month;
  final int day;
  final DateTime asDate;

  PlainDate(this.year, this.month, this.day)
      : asDate = DateTime.utc(year, month, day);

  @override
  int compareTo(PlainDate other) {
    return asDate.compareTo(other.asDate);
  }
}

enum EventType { BALANCE }

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

  Account.parse(String balance, String dailyInterrest)
      : this(BigDecimal.parse(balance), BigDecimal.parse(dailyInterrest));

  Account(this.balance, this.dailyInterrest);

  Account withBalance(BigDecimal newBalance) =>
      Account(newBalance, this.dailyInterrest);

  Account addBalance(BigDecimal addBalance) =>
      Account(this.balance + addBalance, this.dailyInterrest);
}

class Debt {
  PlainDate lastEvent;
  Account debt = Account.parse("0", "1.10");
  Account late = Account.parse("0", "0.15");
  Account sanctions = Account.parse("0", "0");
  Account regularInterrest = Account.parse("0", "0");
  Account lateInterrest = Account.parse("0", "0");
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

  static BigDecimal countInterest(
      PlainDate from, PlainDate to, DistanceCounter counter, Account acc) {
    int distance = counter(from, to);
    var dist = BigDecimal.fromBigInt(BigInt.from(distance));
    return acc.balance * dist * acc.dailyInterrest;
  }
}
