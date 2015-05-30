// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dartlang.codelab.irc;

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
        default:
          if (text.startsWith("finish: ")) {
            var start = text.substring("finish: ".length);
            var sentence = sentenceGenerator
                .generateSentences(startingWith: start)
                .take(10000)  // Make sure we don't run forever.
                .where((sentence) => sentence != null)
                .firstWhere((sentence) => sentence.length < 120,
                            orElse: () => null);
            say(sentence == null ? "Unable to comply." : sentence);
            return;
          }
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
