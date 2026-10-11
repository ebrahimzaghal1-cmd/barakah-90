import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:barakah90/services/foreground_order_alarm_coordinator.dart';

void main() {
  late StreamController<String?> accounts;
  late Map<String, StreamController<bool>> access;
  late Map<String, StreamController<Set<String>>> orders;
  late ForegroundOrderAlarmCoordinator alarm;
  late List<String> events;
  late List<Object> errors;

  setUp(() {
    accounts = StreamController.broadcast(sync: true);
    access = {
      'admin': StreamController.broadcast(sync: true),
      'customer': StreamController.broadcast(sync: true),
    };
    orders = {
      'orders': StreamController.broadcast(sync: true),
      'taxi_orders': StreamController.broadcast(sync: true),
    };
    events = [];
    errors = [];
    alarm = ForegroundOrderAlarmCoordinator(
      accounts: accounts.stream,
      accessForAccount: (uid) => access[uid]!.stream,
      pendingOrders: (collection) => orders[collection]!.stream,
      startAlarm: () => events.add('start'),
      stopAlarm: () => events.add('stop'),
      onError: errors.add,
    );
  });

  tearDown(() async {
    await alarm.dispose();
    await accounts.close();
    for (final controller in access.values) {
      await controller.close();
    }
    for (final controller in orders.values) {
      await controller.close();
    }
  });

  void authorize() {
    alarm.initialize();
    accounts.add('admin');
    access['admin']!.add(true);
    orders['orders']!.add({});
    orders['taxi_orders']!.add({});
  }

  test(
      'rings from a live order without any push and stops after last acceptance',
      () {
    authorize();
    orders['orders']!.add({'one', 'two'});
    orders['orders']!.add({'two'});
    expect(events, ['start']);
    orders['orders']!.add({});
    expect(events, ['start', 'stop']);
  });

  test('food and taxi orders with identical IDs do not stop each other', () {
    authorize();
    orders['orders']!.add({'same-id'});
    orders['taxi_orders']!.add({'same-id'});
    orders['orders']!.add({});
    expect(events, ['start']);
    orders['taxi_orders']!.add({});
    expect(events, ['start', 'stop']);
  });

  test(
      'customers never subscribe to global orders, even after account switching',
      () {
    authorize();
    orders['orders']!.add({'pending'});
    accounts.add('customer');
    access['customer']!.add(false);
    access['admin']!.add(true);
    orders['orders']!.add({'another'});
    expect(events, ['start', 'stop']);
    expect(orders['orders']!.hasListener, isFalse);
  });

  test('background stops listening; resume reconciles orders before ringing',
      () {
    authorize();
    orders['orders']!.add({'pending'});
    alarm.setForeground(false);
    expect(events, ['start', 'stop']);
    expect(orders['orders']!.hasListener, isFalse);
    alarm.setForeground(true);
    expect(events, ['start', 'stop']);
    orders['orders']!.add({'pending'});
    orders['taxi_orders']!.add({'old-taxi'});
    expect(events, ['start', 'stop']);
    orders['taxi_orders']!.add({'old-taxi', 'pending-taxi'});
    expect(events, ['start', 'stop', 'start']);
  });

  test('signout and permission revocation immediately stop the alarm', () {
    authorize();
    orders['orders']!.add({'pending'});
    access['admin']!.add(false);
    expect(events, ['start', 'stop']);
    access['admin']!.add(true);
    orders['orders']!.add({'pending'});
    orders['orders']!.add({'pending', 'another-new-order'});
    accounts.add(null);
    expect(events, ['start', 'stop', 'start', 'stop']);
  });

  test(
      'a failed query clears its alarm without cancelling another pending order',
      () {
    authorize();
    orders['orders']!.add({'food'});
    orders['taxi_orders']!.add({'taxi'});
    orders['orders']!.addError(StateError('permission denied'));
    expect(events, ['start']);
    orders['taxi_orders']!.add({});
    expect(events, ['start', 'stop']);
    expect(errors, hasLength(1));
  });

  test('opening the app with old pending orders never starts the alarm', () {
    alarm.initialize();
    accounts.add('admin');
    access['admin']!.add(true);
    orders['orders']!.add({'old-food'});
    orders['taxi_orders']!.add({'old-taxi'});
    orders['orders']!.add({'old-food'});
    orders['taxi_orders']!.add({'old-taxi'});
    expect(events, isEmpty);
    orders['orders']!.add({'old-food', 'new-food'});
    expect(events, ['start']);
    orders['orders']!.add({'old-food'});
    expect(events, ['start', 'stop']);
  });

  testWidgets(
      'timeout silences the same order permanently until a new order arrives',
      (tester) async {
    authorize();
    orders['orders']!.add({'one'});
    await tester.pump(const Duration(seconds: 29));
    expect(events, ['start']);
    await tester.pump(const Duration(seconds: 1));
    expect(events, ['start', 'stop']);
    orders['orders']!.add({'one'});
    orders['orders']!.add({});
    orders['orders']!.add({'one'});
    expect(events, ['start', 'stop']);
    orders['orders']!.add({'one', 'two'});
    expect(events, ['start', 'stop', 'start']);
    await tester.pump(const Duration(seconds: 30));
    expect(events, ['start', 'stop', 'start', 'stop']);
  });
}
