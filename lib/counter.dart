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

  @override
  String toString() {
    return 'DebtEvent{type: $type, amount: $amount, date: $date}';
  }
}

class Account {
  BigDecimal balance;
  final BigDecimal dailyInterrest;

  Account.parse(String balance, String dailyInterrest) : this(BigDecimal.parse(balance), BigDecimal.parse(dailyInterrest));

  Account(this.balance, this.dailyInterrest);

  void setBalance(BigDecimal newBalance) => balance = newBalance;

  void addBalance(BigDecimal addBalance) => balance = this.balance + addBalance;
}

class DebtSnapshot {
  final PlainDate date;
  final BigDecimal principal;
  final BigDecimal principalInterest;
  final BigDecimal late;
  final BigDecimal lateInterest;
  final BigDecimal sanctions;
  final BigDecimal sanctionsInterest;
  final BigDecimal expenses;
  final BigDecimal sum;

  DebtSnapshot(this.date, this.principal, this.principalInterest, this.late, this.lateInterest, this.sanctions, this.sanctionsInterest, this.expenses)
      : sum = principal + principalInterest + lateInterest + sanctions + sanctionsInterest + expenses;

  @override
  String toString() {
    return 'DebtSnapshot{[${date}] principal: $principal, principalInterest: $principalInterest, late: $late, lateInterest: $lateInterest, sanctions: $sanctions, sanctionsInterest: $sanctionsInterest, SUM=$sum}';
  }
}

class Debt {
  PlainDate? lastEvent;

  static final BigDecimal zero = BigDecimal.parse("0");

  final Account principal;
  final Account principalInterest;
  final Account late;
  final Account lateInterest;
  final Account sanctions;
  final Account sanctionsInterest;
  final Account expenses;

  Debt(
      {required this.principal,
      required this.principalInterest,
      required this.late,
      required this.lateInterest,
      required this.sanctions,
      required this.sanctionsInterest,
      required this.expenses});

  BigDecimal get sum {
    return principal.balance + principalInterest.balance + late.balance + sanctions.balance;
  }

  void apply(DebtEvent e) {
    print("Applying: $e");
    if (lastEvent != null && lastEvent != e.date) {
      principalInterest.addBalance(DebtCounter.countInterest(lastEvent!, e.date, DebtCounter.count30E360Distance, principal));
      if (late.balance > zero) {
        lateInterest.addBalance(DebtCounter.countInterest(lastEvent!, e.date, DebtCounter.count30E360Distance, late));
      }
      sanctionsInterest.addBalance(DebtCounter.countInterest(lastEvent!, e.date, DebtCounter.count30E360Distance, sanctions));
    }
    lastEvent = e.date;
    if (e.type == EventType.BALANCE) {
      principal.addBalance(e.amount);
    }
    if (e.type == EventType.EXPECTATION) {
      if (e.amount < zero) throw Exception("Expectation cannot be negative");
      late.addBalance(e.amount);
    }
    if (e.type == EventType.PAYMENT) {
      if (e.amount < zero) throw Exception("Payment cannot be negative");
      BigDecimal payment = e.amount;
      if (payment > zero) payment = _applyPayment(expenses, payment);
      if (payment > zero) payment = _applyPayment(sanctionsInterest, payment);
      if (payment > zero) payment = _applyPayment(sanctions, payment);
      if (payment > zero) payment = _applyPayment(lateInterest, payment);
      if (payment > zero) payment = _applyPayment(principalInterest, payment);
      if (payment > zero) payment = _applyPayment(principal, payment);
      late.addBalance(-e.amount);
    }
    if (e.type == EventType.SANCTION) {
      sanctions.addBalance(e.amount);
    }
    print("Result: $snapshot");
  }

  DebtSnapshot get snapshot {
    return DebtSnapshot(
      lastEvent ?? PlainDate(1, 1, 1),
      this.principal.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
      this.principalInterest.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
      this.late.balance > zero ? this.late.balance.withScale(2, roundingMode: RoundingMode.HALF_UP) : zero,
      this.lateInterest.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
      this.sanctions.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
      this.sanctionsInterest.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
      this.expenses.balance.withScale(2, roundingMode: RoundingMode.HALF_UP),
    );
  }

  BigDecimal _applyPayment(Account a, BigDecimal payment) {
    if (payment < zero) throw Exception("Negative payment!");
    if (a.balance <= zero) return payment; // nothing to pay here
    if (a.balance > payment) {
      a.balance = a.balance - payment;
      return zero;
    } else {
      payment = payment - a.balance;
      a.balance = zero;
      return payment;
    }
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
