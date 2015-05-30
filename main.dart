// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';

void handleIrcSocket(Socket socket) {

  /// Sends a message to the IRC server.
  ///
  /// The message is automatically terminated with a `\r\n`.
  void writeln(String message) {
    socket.write('$message\r\n');
  }

  void authenticate() {
    var nick = "myBot";  // <=== Replace with your bot name. Try to be unique.
    writeln('NICK $nick');
    writeln('USER username 8 * :$nick');
  }

  void handleServerLine(String line) {
    print("from server: $line");
    if (line.startsWith("PING")) {
      writeln("PONG ${line.substring("PING ".length)}");
    }
  }

  socket
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen(handleServerLine,
              onDone: socket.close);

  authenticate();
  writeln('JOIN ##dart-irc-codelab');
  writeln('PRIVMSG ##dart-irc-codelab :Hello world');
  writeln('QUIT');
}

void main() {
  Socket.connect("localhost", 6667)
      .then(handleIrcSocket);
}
