// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartlang.codelab.irc;

import 'dart:io' show Socket;
import 'dart:convert' show UTF8, LineSplitter;

import 'sentence_generator.dart' show SentenceGenerator;

part 'irc.dart';

void main(arguments) {
  var generator = new SentenceGenerator();
  arguments.forEach(generator.addBook);
  runIrcBot(generator);
}
