import 'dart:collection';

Queue<WorldEvent> bet(World w, int amount) {
  //validate
  if (w._chips < amount) {
    throw Exception("Not enough chips, not implemented");
  }
  if (w._bet != 0) {
    throw Exception("Bet already placed, not implemented");
  }

  Queue<WorldEvent> queue = Queue<WorldEvent>();

  w._chips -= amount;
  w._bet = amount;
  queue.add(WorldEvent(World.from(w), WorldReaction.BetPlaced));

  queue.add(_dealCardToPlayer(w));
  queue.add(_dealCardToPlayer(w));

  queue.add(_dealCardToDealer(w, true));
  queue.add(_dealCardToDealer(w, false));

  var result = _getHandState(w);
  if (result != HandResult.unresolved) {
    queue.add(_applyHandResult(w, result));
  } else if (_calculateHandValue(w._dealersHand) == 10 ||
      _calculateHandValue(w._dealersHand) == 11) {
    w._availableActions = {"insurance_yes", "insurance_no"};
    // TODO: don't allow user to select insuranc yes if they don't have enough chips.
  } else {
    _setAvailableActionsToFirst(w);
  }

  queue.add(_awaitingUserInput(w));
  return queue;
}

void _setAvailableActionsToFirst(World w) {
  w._availableActions = {"hit", "stand"};
  if (w._chips >= w._bet) {
    w._availableActions.add("doubledown");
  }
}

Queue<WorldEvent> hit(World w) {
  Queue<WorldEvent> queue = Queue<WorldEvent>();

  queue.add(_dealCardToPlayer(w));
  //check for bust
  var result = _getHandState(w);

  if (result != HandResult.unresolved) {
    queue.add(_applyHandResult(w, result));
  }
  queue.add(_awaitingUserInput(w));

  return queue;
}

Queue<WorldEvent> stand(World w) {
  Queue<WorldEvent> queue = Queue<WorldEvent>();
  w._hasPlayerStood = true;
  w._dealersHand[1]._flip();
  //TODO: Add world event Dealer card flip.

  //Dealer hits until they shouldn't
  while (_shouldDealerHit(w._dealersHand)) {
    queue.add(_dealCardToDealer(w, true));
  }

  var result = _getHandState(w);

  queue.add(_applyHandResult(w, result));
  queue.add(_awaitingUserInput(w));

  return queue;
}

WorldEvent _awaitingUserInput(World w) {
  return WorldEvent(World.from(w), WorldReaction.AwaitingUserInput);
}

WorldEvent _applyHandResult(World w, HandResult result) {
  switch (result) {
    case HandResult.unresolved:
      throw "Unresolved Hand";
    case HandResult.dealerWins:
      //no payment just clear bet reset?
      break;
    case HandResult.playerWins:
      w._chips += w._bet * 2;
      break;
    case HandResult.tie:
      w._chips += w._bet;
      break;
    case HandResult.playerBlackjack:
      w._chips += (w._bet * 2.5).toInt();
      break;
    case HandResult.insuranceWin:
      w._chips += w._insuranceBet * 3;
      break;
  }
  var event = WorldEvent(World.from(w), WorldReaction.HandResolved);
  //Reset.
  w._bet = 0;
  w._insuranceBet = 0;
  w._hand = [];
  w._dealersHand = [];
  w._hasPlayerStood = false;
  w._availableActions = {"bet"};

  //Check for shuffle?
  return event;
}

HandResult _getHandState(World w) {
  //Resolve busts
  if (_isBust(w._hand)) {
    return HandResult.dealerWins;
  }
  if (_isBust(w._dealersHand)) {
    return HandResult.playerWins;
  }

  var dealerScore = _calculateHandValue(w._dealersHand);
  var playersScore = _calculateHandValue(w._hand);

  //Resolve Blackjacks
  if (w._hand.length == 2 && playersScore == 21) {
    return HandResult.playerBlackjack;
  }
  if (w._dealersHand.length == 2 && dealerScore == 21) {
    if (w._insuranceBet != 0) {
      return HandResult.insuranceWin;
    }
    return HandResult.dealerWins;
  }
  //todo: Handle Blackjack tie.

  if (w._hasPlayerStood == false) {
    return HandResult.unresolved;
  }

  if (dealerScore == playersScore) {
    return HandResult.tie;
  }

  return playersScore > dealerScore
      ? HandResult.playerWins
      : HandResult.dealerWins;
}

//Phase 2
Queue<WorldEvent> double_down(World w) {
  if (w._chips < w._bet) {
    throw "Not enough chips";
  }
  Queue<WorldEvent> queue = Queue<WorldEvent>();
  w._chips -= w._bet;
  w._bet *= 2;
  queue.add(WorldEvent(World.from(w), WorldReaction.BetPlaced));
  queue.add(_dealCardToPlayer(w));
  queue.addAll(stand(w));

  return queue;
}

//Phase 3
Queue<WorldEvent> insurance_purchase(World w) {
  int insuranceCost = (w._bet * .5).round();
  if (w._chips < insuranceCost) {
    throw "Not enough chips";
  }
  Queue<WorldEvent> queue = Queue<WorldEvent>();
  w._chips -= insuranceCost;
  w._insuranceBet += insuranceCost;
  queue.add(WorldEvent(World.from(w), WorldReaction.BetPlaced));
  //Resolve if the dealer has 21 or not
  queue.addAll(_resovleDealerBlackjack(w));
  return queue;
}

Queue<WorldEvent> insurance_decline(World w) {
  Queue<WorldEvent> queue = Queue<WorldEvent>();
  queue.addAll(_resovleDealerBlackjack(w));
  return queue;
}

//Phase 4
void split(World w) {
  //process Reactionary state changes.
}

WorldEvent _dealCardToPlayer(World w) {
  var drawn = w._deck.first;
  w._deck.removeAt(0);
  w._hand.add(drawn);
  drawn._flip();
  return WorldEvent(World.from(w), WorldReaction.CardDealtToPlayer);
}

WorldEvent _dealCardToDealer(World w, bool reveal) {
  var drawn = w._deck.first;
  w._deck.removeAt(0);
  w._dealersHand.add(drawn);
  if (reveal) {
    drawn._flip();
  }
  return WorldEvent(World.from(w), WorldReaction.CardDealtToDealer);
}

List<WorldEvent> _resovleDealerBlackjack(World w) {
  List<WorldEvent> events = [];
  if (_isDealerBlackjack(w._dealersHand)) {
    //Flip dealers hidden card
    w._dealersHand.where((c) => !c._isFaceup).forEach((c) => c._flip());
    //resovle hand (insurance and losses)
    var state = _getHandState(w);
    events.add(_applyHandResult(w, state));
  } else {
    _setAvailableActionsToFirst(w);
  }
  events.add(_awaitingUserInput(w));
  return events;
}

bool _isBust(List<Card> hand) => _calculateHandValue(hand) > 21;
bool _shouldDealerHit(List<Card> hand) =>
    _calculateHandValue(hand) < 17; //TODO: implment soft 17 for hit.
bool _isBlackjack(List<Card> hand) => _calculateHandValue(hand) == 21;
bool _isDealerBlackjack(List<Card> hand) =>
    _calculateHandValue(hand, peak: true) == 21;

int _calculateHandValue(List<Card> hand, {bool peak = false}) {
  var sortedHand = List<Card>.from(hand);
  sortedHand = sortedHand.where((c) => c._isFaceup || peak).toList();
  sortedHand.sort((a, b) => a._cardRank.index == b._cardRank.index
      ? 0
      : a._cardRank.index < b._cardRank.index
          ? -1
          : 1);

  int value = 0;
  for (final card in sortedHand) {
    if (value + card._cardRank._highValue > 21) {
      value += card._cardRank._lowValue;
    } else {
      value += card._cardRank._highValue;
    }
  }

  return value;
}

String _printHand(List<Card> hand) {
  String ret = "";
  for (var card in hand) {
    if (card._isFaceup) {
      ret += "${card._cardRank} ";
    } else {
      ret += "hidden ";
    }
  }
  ret += _calculateHandValue(hand).toString();
  return ret;
}

class World {
  Set<String> getAvailableActions() =>
      Set<String>.unmodifiable(_availableActions);
  String getStateStr() =>
      "Balance: $_chips\nDealer:${_printHand(_dealersHand)}\nYou:${_printHand(_hand)}\nBet:$_bet";

  List<Card> _deck;
  List<Card> _dealersHand = [];
  Set<String> _availableActions = <String>{"bet"};
  int _chips;
  int _bet = 0;
  int _insuranceBet = 0;
  List<Card> _hand = [];
  bool _hasPlayerStood = false;

  factory World.from(World source) {
    var deck = List<Card>.from(source._deck);
    var world = World._internal(source._chips, deck);
    world._dealersHand = List<Card>.from(source._dealersHand);
    world._hand = List<Card>.from(source._hand);
    world._bet = source._bet;
    world._hasPlayerStood = source._hasPlayerStood;
    world._availableActions = Set<String>.from(source._availableActions);

    return world;
  }

  World._internal(this._chips, this._deck);

  factory World() {
    List<Card> deck = [];
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        deck.add(Card(suit, rank));
      }
    }

    deck.shuffle();

    return World._internal(500, deck);
  }
}

class WorldEvent {
  World snapshot;
  WorldReaction reaction;

  WorldEvent._internal(this.snapshot, this.reaction);
  WorldEvent(World w, WorldReaction r) : this._internal(w, r);
}

enum WorldReaction {
  BetPlaced,
  CardDealtToPlayer,
  CardDealtToDealer,
  HandResolved,
  AwaitingUserInput,
}

enum HandResult {
  playerWins,
  dealerWins,
  playerBlackjack,
  insuranceWin,
  tie,
  unresolved
}

class Card {
  CardSuit _suit;
  CardRank _cardRank;
  bool _isFaceup = false;
  _flip() => _isFaceup = !_isFaceup;
  Card(this._suit, this._cardRank);
}

enum CardSuit {
  heart,
  diamond,
  club,
  spade,
}

enum CardRank {
  two.same(2),
  three.same(3),
  four.same(4),
  five.same(5),
  six.same(6),
  seven.same(7),
  eight.same(8),
  nine.same(9),
  ten.same(10),
  jack.same(10),
  queen.same(10),
  king.same(10),
  ace(1, 11);

  const CardRank(this._lowValue, this._highValue);
  const CardRank.same(int value) : this(value, value);

  final int _lowValue;
  final int _highValue;

  @override
  String toString() => name;
}
