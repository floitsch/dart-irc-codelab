// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';

final RegExp ircMessageRegExp =
    new RegExp(r":([^!]+)!([^ ]+) PRIVMSG ([^ ]+) :(.*)");

void handleIrcSocket(Socket socket) {
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

  void handleMessage(String msgNick,
                     String server,
                     String channel,
                     String msg) {
    if (msg.startsWith("$nick:")) {
      // Direct message to us.
      var text = msg.substring(msg.indexOf(":") + 1).trim();
      if (text == "please leave") {
        print("Leaving by request of $msgNick");
        writeln("QUIT");
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
  writeln('PRIVMSG ##dart-irc-codelab :Hello world');
}

void runIrcBot() {
  Socket.connect("localhost", 6667)
      .then(handleIrcSocket);
}

class SentenceGenerator {
  final _db = new Map<String, Set<String>>();

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
}

void main(arguments) {
  var generator = new SentenceGenerator();
  arguments.forEach(generator.addBook);
}
