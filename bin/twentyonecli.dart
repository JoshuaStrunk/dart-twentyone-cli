import 'package:twentyonecli/twentyonecli.dart';
import 'dart:io';
import 'dart:async';
import 'dart:collection';

Future<void> main(List<String> arguments) async {
  World world = World();
  print(world.getStateStr());
  print(world.getAvailableActions());
  await for (final value in stdin) {
    var str = String.fromCharCodes(value);
    str = str.trim();
    var command = str.split(' ')[0];
    if (!world.getAvailableActions().contains(command)) {
      print("invalid command");
    } else {
      Queue<WorldEvent> states = switch (command) {
        "bet" => bet(world, int.parse(str.split(' ')[1])),
        "hit" => hit(world),
        "stand" => stand(world),
        "doubledown" => double_down(world),
        "yes" => insurance_purchase(world),
        "no" => insurance_decline(world),
        "split" => split(world),
        _ => Queue<WorldEvent>()
      };

      for (var state in states) {
        print("State-> ${state.reaction}");
        print(state.snapshot.getStateStr());
        print("-----");
      }
    }

    print(world.getStateStr());
    print(world.getAvailableActions());
  }

  print('fin');

  //print('Hello world: ${twentyonecli.calculate()}!');
}
