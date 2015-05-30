// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';
import 'dart:math';

final RegExp ircMessageRegExp =
    new RegExp(r":([^!]+)!([^ ]+) PRIVMSG ([^ ]+) :(.*)");

void handleIrcSocket(Socket socket, SentenceGenerator sentenceGenerator) {
  final nick = "myBot";  // <=== Replace with your bot name. Try to be unique.

  /// Sends a message to the IRC server.
  ///
  /// The message is automatically terminated with a `\r\n`.
  void writeln(String message) {
    socket.write('$message\r\n');
  }

  void authenticate() {
    writeln('NICK $nick');
    writeln('USER username 8 * :$nick');
  }

  void say(String message) {
    if (message.length > 120) {
      // IRC doesn't like it when lines are too long.
      message = message.substring(0, 120);
    }
    writeln('PRIVMSG ##dart-irc-codelab :$message');
  }

  void handleMessage(String msgNick,
                     String server,
                     String channel,
                     String msg) {
    if (msg.startsWith("$nick:")) {
      // Direct message to us.
      var text = msg.substring(msg.indexOf(":") + 1).trim();
      switch (text) {
        case "please leave":
          print("Leaving by request of $msgNick");
          writeln("QUIT");
          return;
        case "talk to me":
          say(sentenceGenerator.generateRandomSentence());
          return;
      }
    }
    print("$msgNick: $msg");
  }

  void handleServerLine(String line) {
    if (line.startsWith("PING")) {
      writeln("PONG ${line.substring("PING ".length)}");
      return;
    }
    var match = ircMessageRegExp.firstMatch(line);
    if (match != null) {
      handleMessage(match[1], match[2], match[3], match[4]);
      return;
    }
    print("from server: $line");
  }

  socket
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen(handleServerLine,
              onDone: socket.close);

  authenticate();
  writeln('JOIN ##dart-irc-codelab');
  say("Hello world");
}

void runIrcBot(SentenceGenerator generator) {
  Socket.connect("localhost", 6667)
      .then((socket) => handleIrcSocket(socket, generator));
}

class SentenceGenerator {
  final _db = new Map<String, Set<String>>();
  final rng = new Random();

  void addBook(String fileName) {
    var content = new File(fileName).readAsStringSync();

    // Make sure the content terminates with a ".".
    if (!content.endsWith(".")) content += ".";

    var words = content
        .replaceAll("\n", " ") // Treat new lines as if they were spaces.
        .replaceAll("\r", "")  // Discard "\r".
        .replaceAll(".", " .") // Add space before "." to simplify splitting.
        .split(" ")
        .where((String word) => word != "");

    var preprevious = null;
    var previous = null;
    for (String current in words) {
      if (preprevious != null) {
        // We have a trigram.
        // Concatenate the first two words and use it as a key. If this key
        // doesn't have a corresponding set yet, create it. Then add the
        // third word into the set.
        _db.putIfAbsent("$preprevious $previous", () => new Set())
            .add(current);
      }

      preprevious = previous;
      previous = current;
    }
  }

  int get keyCount => _db.length;

  String pickRandomPair() => _db.keys.elementAt(rng.nextInt(keyCount));

  String pickRandomThirdWord(String firstWord, String secondWord) {
    var key = "$firstWord $secondWord";
    var possibleSequences = _db[key];
    return possibleSequences.elementAt(rng.nextInt(possibleSequences.length));
  }

  String generateRandomSentence() {
    var start = pickRandomPair();
    var startingWords = start.split(" ");
    var preprevious = startingWords[0];
    var previous = startingWords[1];
    var sentence = [preprevious, previous];
    var current;
    do {
      current = pickRandomThirdWord(preprevious, previous);
      sentence.add(current);
      preprevious = previous;
      previous = current;
    } while (current != ".");
    return sentence.join(" ");
  }
}

void main(arguments) {
  var generator = new SentenceGenerator();
  arguments.forEach(generator.addBook);
  runIrcBot(generator);
}
