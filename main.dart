// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

void handleIrcSocket(Socket socket) {

  void authenticate() {
    var nick = "myBot";  // <=== Replace with your bot name. Try to be unique.
    socket.write('NICK $nick\r\n');
    socket.write('USER username 8 * :$nick\r\n');
  }

  authenticate();
  socket.write('JOIN ##dart-irc-codelab\r\n');
  socket.write('PRIVMSG ##dart-irc-codelab :Hello world\r\n');
  socket.write('QUIT\r\n');
  socket.destroy();
}

void main() {
  Socket.connect("localhost", 6667)  // No need for the temporary variable.
      .then(handleIrcSocket);
}
