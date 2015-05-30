// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

void main() {
  var future = Socket.connect("localhost", 6667);
  // Now register a callback:
  future.then((socket) {
    // The socket is now available.
    print("Connected");
    socket.destroy();
  });
  print("Callback has been registered, but we are not connected yet");
}
