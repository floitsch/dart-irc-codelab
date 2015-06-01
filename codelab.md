Talk-to-me
==========

In this code lab, you build an IRC bot that produces random sentences based on
knowledge it learned from "reading" existing documents.

Step 0
------
Install Dart and a decent editor. For exploration an IDE with code completion
is recommended. IntelliJ is a good choice.

Since we build an IRC bot, you will need an IRC client. Also,
a local IRC server is great for debugging. While not
strictly necessary it makes debugging much easier. There are lots of options,
but a Google search seems to recommend ngircd. It's most likely total overkill
for this code lab, but works fine. Make sure to compile and run it with
debugging support:

```bash
./configure --prefix=$PWD/out --enable-sniffer --enable-debug
make && make install
out/sbin/ngircd -n -s
```

If you have a smaller option that doesn't require any compilation feel free to
reach out to me so I can update this step.

Optionally clone `https://github.com/floitsch/dart-irc-codelab.git` to get the
complete sources of this code lab. The git repository has different branches
for every step.

Step 1 - Hello world
------

In this step, we create an skeleton app of Dart. We will keep this project
really simple, and only work with one file. This means that we don't need to go
through any project wizard. Just open a new file `main.dart` (or any other
name you prefer) and open it.

Add the following lines to it:

```dart
main() {
  print("Hello world");
}
```

Congratulations: you just wrote a complete Dart application. Run it either
through your IDE or with `dart --checked main.dart`. The `--checked` flag is not
necessary but strongly recommended when developing. It dynamically checks the
types in the program. Currently your program doesn't have any yet, so let's
change that:

```dart
void main() {
  print("Hello world");
}
```

So far the dynamic checker doesn't need to work hard, but over time we will add
more functions and types. As you can see, types are _optional_ in Dart. You can
write them, but don't need to. We recommend to write types on function
boundaries (but you can write them more frequently or not at all).

Step 2 - Connect to the server
------

In this step, we connect to an IRC server. Our client will be really dumb and
only support a tiny subset of IRC commands. The complete spec is in
[RFC 2812](https://tools.ietf.org/html/rfc2812); a summary can be found
[here](http://blog.initprogram.com/2010/10/14/a-quick-basic-primer-on-the-irc-protocol/).

Let's start with connecting a socket to the server. If possible connect to a
local server first, before you connect to a public external server.

[Sockets](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:io.Socket)
are part of the IO-library. As such, we have to import them first. Add the
following import clause to the beginning of your file:

```dart
import 'dart:io';
```

This imports all IO classes and functions into the namespace of this library. We
can use the static `connect` method of `Socket` to connect to a server:
`Socket.connect(host, port)`. In Dart, IO operations are asynchronous, which
means that this call won't block, but yields immediately. Instead, it returns a
[Future](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:async.Future)
of the result. Futures (aka "promise" or "eventual") are objects that represent
values that haven't been computed yet. Once the value is available, the future
invokes callbacks that have been waiting for the value. Let's give it a try:

```dart
void main() {
  var future = Socket.connect("localhost", 6667);
  // Now register a callback:
  future.then((socket) {
    // The socket is now available.
    print("Connected");
    socket.destroy();  // Shuts down the socket in both directions.
  });
  print("Callback has been registered, but we are not connected yet");
}
```

Here, we have our first closure of the program: the argument to `then` is a
one-argument closure. Contrary to static functions, closures can not declare
their return type (but can have type arguments for their arguments). They
cannot be named, either.

Before running this program, make sure that you have some server running on
localhost 6667. You can, for example, start a local IRC server, or run
netcat (`nc -l 6667`), otherwise you will see the following error message:

    Unhandled exception:
    Uncaught Error: SocketException: OS Error: Connection refused, errno = 111, address = localhost, port = 52933

This is a good opportunity to point out that, throughout this code lab, we will
ignore errors. A real-world program would need to be much more careful where
and when it needs to catch uncaught exceptions.

Assuming that everything went well we should be connected now. Let's
authenticate and say "hello":

```dart
/// Given a connected [socket] runs the IRC bot.
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
```

Lot's of things are happening here:

* We moved the IRC code into a `handleIrcSocket` function which we give as
  argument to the `then` of the future. Note that we don't need to create an
  anonymous closure, and can just reference the static function.

* The `handleIrcSocket` function has a nested function `authenticate`. This is
  just to make the code easier to read. We could just inline the function body.

* Inside `authenticate` we send the IRC `NICK` and `USER` commands. For this, we
  need a nick and a username. For simplicity we use the same name here. The
  variable `nick` holds that string, and is spliced into the command strings
  using string interpolation. String interpolation is just a simple nice way of
  concatenating strings.

* Once we are authenticated, we join the `##dart-irc-codelab` channel and
  send a message to it. Note that, in theory, joining the channel is not
  always necessary. However, many servers (including freenode) disable messages
  from the outside by default.

* So far, we don't listen to anything from the server. This is clearly not a
  good idea and something we need to fix. This will also fix another issue with
  the code: shutting down the socket (in both directions) after having sent our
  messages is very aggressive. Don't be surprised if your message doesn't make
  it to the IRC channel.
  
* Messages to IRC servers must be terminated with `\r\n`. This is something that
  is extremely easy to forget, so we will create a helper function for it.

Step 3 - Handle Server messages
------

The most important server-message we have to handle to is the `PING` message. As
expected, the client has to respond with a `PONG`. Let's add this functionality:

```dart
import 'dart:convert';    

...

/// Sends a message to the IRC server.
///
/// The message is automatically terminated with a `\r\n`.
void writeln(String message) {
  socket.write('$message\r\n');
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
```

Listening to a socket can be done with the `listen` function. However, this
would give us the bytes that are received by the socket. We want to have the
UTF8 lines that are sent by the server. Sockets implement the
[Stream](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:async.Stream)
interface and support lots of methods that help to deal with the incoming data.
One of them is `transform` which takes the input and transforms it to a
different representation. This is a more powerful version of the well known
`map` functionality.
 
Dart's core libraries already come with convenient conversion transformers. They
are located in the `dart:convert` library. After transforming the incoming data,
first to UTF8, then to individual lines, we listen to the data.
Normal data (the lines) is sent to the
`handleServerMessage` closure, and we pass in a named argument `onDone` which
is invoked when the server shut down the connection. At that moment we simply
invoke the torn-off closure `socket.close`. The closure `socket.close` is bound
to the socket it came from, and will correctly close the sending part of the
socket.

If you feel (slightly) adventurous, you can try your bot in the wild now.
Use your IRC client to connect to chat.freenode.net and join the
`##dart-irc-codelab` channel. Make sure, you have picked a unique name and
change the `localhost` line to `chat.freenode.net`. Then run your program again.
You should see a hello-world message (hopefully from your bot) on the public
channel. If not, you should see an indication of why the server rejected your
requests.

So far the bot only handles the `PING` line from the server. We are only
interested in one other type of messages: `PRIVMSG`s from other clients. The
easiest way to deal with them is to use a regular expression.

```dart
final RegExp ircMessageRegExp =
    new RegExp(r":([^!]+)!([^ ]+) PRIVMSG ([^ ]+) :(.*)");

...

void handleMessage(String msgNick,
                   String server,
                   String channel,
                   String msg) {
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
```

In order to test the receipt of these messages we have to disable the `QUIT`
command we send to the server. Otherwise the bot won't have the time to
receive interesting messages. You can just delete that line now. We will
deal with quitting in the next step.

Step 4 - Respond to IRC messages
------

In this step we make the IRC bot interactive. Now, that the bot understands
messages that are sent to a channel we can make it respond to them. For
now we just want to be able to ask our bot to quit.

```dart
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
```

This also requires to move the `nick` variable out of the `authenticate`
function:

```dart
void handleIrcSocket(Socket socket) {
  final nick = "myBot";  // <=== Replace with your bot name. Try to be unique.
  ...
```

With this addition we can properly leave the server by simply sending a nice irc
message to the bot: `myBot: please leave`.

At this point in the code lab we will switch to generating random sentences. We
will come back to the irc-bot once we have something interesting to say. If you
are interested you can however experiment with a few other commands. Some easy
ones are "echo <msg>", "what's the time?", or "how long till dinner?".

Step 5 - Trigrams
------

In this step we start the logic to generate random sentences. It is based on
simplified Markov chains. This approach has been inspired by
[a similar implementation in Python]
(https://charlesleifer.com/blog/building-markov-chain-irc-bot-python-and-redis/).
The idea is to create a set of all word-trigrams that exist in some given
real-world documents. A sentence-generator uses these trigrams to build random
sentences. Given two words the sentence-generator finds a random
trigram that starts with these two words and adds the third word to the
sentence. It then repeats the process with the new last two words, until it
encounters a terminating ".".

Let's start with extracting all trigrams from a document. For the next steps
we don't need to run the irc bot, so let's just rename the old `main` to
`runIrcBot`. We will invoke that function later, when we have the sentence
generator ready.

This time we want to handle command-line arguments, so let's add a new
main that accepts them as argument.

```dart
void runIrcBot() {
  Socket.connect("localhost", 6667)
      .then(handleIrcSocket);
}

void main(List<String> arguments) {
  print(arguments);
}
```

We want to analyze existing documents to farm them for trigrams.
[Gutenberg](http://gutenberg.org) is a good resource for out-of-copyright work
that is perfect for this task. I used
[Alice in Wonderland](http://www.gutenberg.org/cache/epub/11/pg11.txt), and
[The US constitution](http://www.gutenberg.org/cache/epub/5/pg5.txt) in this
code lab, but there are many other interesting documents.

Download these (or other books) and change your setup so that your program is
invoked with these books as arguments. You should have an output similar to
this one:

    $ dart --checked main.dart constitution.txt alice.txt
    [constitution.txt, alice.txt]

For simplicity, we store the trigrams in a table that maps 2-word strings to
all possible third words. Since there is lots of associated code with this
collection we encapsulate it in a class.

```dart
class SentenceGenerator {
  final _db = new Map<String, Set<String>>();
  
  void addBook(String fileName) {
    print("TODO: add book $fileName");
  }
}

void main(arguments) {
  var generator = new SentenceGenerator();
  arguments.forEach(generator.addBook);
}
```

Note the "\_" in `_db` field name. It means that this field is only visible
within the same library. The same mechanism also works for classes, methods or
static functions. The moment an identifier starts with an "\_" it is private to
the current library.

Since our code lab is small and privacy protection is completely unnecessary we
will not create any other private symbols.

We use a very crude way of updating the database when we get a new book:

```dart
void addBook(String fileName) {
  var content = new File(fileName).readAsStringSync();

  // Make sure the content terminates with a ".".
  if (!content.endsWith(".")) content += ".";

  var words = content
      .replaceAll("\n", " ") // Treat new lines as if they were spaces.
      .replaceAll("\r", "")  // Discard "\r".
      .replaceAll(".", " .") // Add space before ".", to simplify splitting.
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
```

This code simply runs through all words and adds them as trigrams to the
database. For example the sentence "My hovercraft is full of eels." will add the
following trigrams to the database:

    "My hovercraft" -> "is"
    "hovercraft is" -> "full"
    "is full" -> "of"
    "full of" -> "eels"
    "of eels" -> "."

The values (on the right) are sets. This becomes important when seeing new
trigrams that have the same first two words. For example adding the
sentence "A hovercraft is an aircraft." to the database would yield:

    "My hovercraft" -> "is"
    "hovercraft is" -> "full", "an"    // <= two trigrams with the same first words.
    "is full" -> "of"
    "full of" -> "eels"
    "of eels" -> "."
    "A hovercraft" -> "is"
    "is an" -> "aircraft"
    "an aircraft" -> "."

A markov chain would count the occurrences to provide better guesses, but here
we simply collect a set of possible trigrams.

Step 6 - Random sentences
------

In this step we add support for generating random sentences. As a starting point
we select a random pair of words from the database and use it as the beginning
of the sentence. We then follow possible sequences until we reach a ".".

For this step we need a random number generator. Dart provides an implementation
in the `dart:math` library. Import that library and store a final generator
as final field in the `SentenceGenerator` class:

```dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';
...
class SentenceGenerator {
  final _db = new Map<String, Set<String>>();
  final rng = new Random();
...
```

We also add a few helper functions to make the sentence generation easier:

```dart
int get keyCount => _db.length;

String pickRandomPair() => _db.keys.elementAt(rng.nextInt(keyCount));

String pickRandomThirdWord(String firstWord, String secondWord) {
  var key = "$firstWord $secondWord";
  var possibleSequences = _db[key];
  return possibleSequences.elementAt(rng.nextInt(possibleSequences.length));
}
```

The first function `keyCount` is in fact a getter. That is, it is used as if it
was a field. This can be seen in the second function `pickRandomPair` where the
`keyCount` getter is used to provide a range to the random number generator.

Since these functions are very small and fit on one line we use the "`=>`"
notation for them. This notation is just syntactic sugar for a function that
returns one expression. We could write these two helpers as follows without
any semantic difference:

```dart
int get keyCount { return _db.length; }

String pickRandomPair() { return _db.keys.elementAt(rng.nextInt(keyCount)); }
```

Given these helper functions we can generate a full sentence quite easily:

```dart
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

...

void main(arguments) {
  var generator = new SentenceGenerator();
  arguments.forEach(generator.addBook);
  print(generator.generateRandomSentence());
}
```

Give it a try. You should get some reasonable sentences. For example:

    $ dart --checked main.dart constitution.txt alice.txt
    dreadfully puzzled by the first question, you know I'm mad?' said Alice .

    $ dart --checked main.dart constitution.txt alice.txt
    jury had a bone in his confusion he bit a large arm-chair at one corner of
    it: for she could not make out what she was saying, and the Acceptance of
    Congress, lay any Duty of Tonnage, keep Troops, or Ships of War in time of life .
    
    $ dart --checked main.dart constitution.txt alice.txt
    an announcement goes out in a confused way, 'Prizes! Prizes!' Alice had no
    very clear notion how delightful it will be When they take us up and rubbed
    its eyes: then it chuckled .

Step 7 - Chat bot
------

In this step, we combine the sentence generator with the IRC bot. Whenever we
ask the bot to "talk to me" it should generate a new random sentence and
display it.

At this point we need to launch the IRC bot again (with a generator as
argument). Furthermore, we need to add support for a new command in
`handleMessage`. These changes touch lots of different parts of the program, but
are all relatively minor.

```dart
void handleIrcSocket(Socket socket, SentenceGenerator sentenceGenerator) {

...

void say(String message) {
  if (message.length > 120) {
    // IRC doesn't like it when lines are too long.
    message = message.substring(0, 120);
  }
  writeln('PRIVMSG ##dart-irc-codelab :$message');
}

void handleMessage(...) {
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

...

void runIrcBot(SentenceGenerator generator) {
  Socket.connect("localhost", 6667)
      .then((socket) => handleIrcSocket(socket, generator));
}

...

void main(arguments) {
  var generator = new SentenceGenerator();
  arguments.forEach(generator.addBook);
  runIrcBot(generator);
}
```

The hardest part here is to pass the generator from the main function to the
irc bot. We could have simplified our live by setting a static variable, but
in general avoiding static state is a good idea.

Step 8 - Completing Sentences
------

In this step, we modify the generator to accept a few words as starting
suggestions. We want to start a sentence and let the generator finish it.

Handling the command from IRC happens easily in the `handleMessage` function:

```dart
void handleMessage(...) {
    if (msg.startsWith("$nick:")) {
      // Direct message to us.
      var text = msg.substring(msg.indexOf(":") + 1).trim();
      switch (text) {
        ...
        default:
          if (text.startsWith("finish: ")) {
            var start = text.substring("finish: ".length);
            var sentence = sentenceGenerator.finishSentence(start);
            say(sentence == null ? "Unable to comply." : sentence);
            return;
          }
      }
      ...
```

This will currently crash dynamically, because we haven't implemented the
`finishSentence` method yet. Note, that the VM still runs the code, and only
fails dynamically when it encounters the line that contains the method call.
However, the editor (or `dartanalyzer`) warns you statically that there is a
likely problem at this location.

In order to implement the missing `finishSentence` function we first split the
`generateRandomSentence` function so that it accepts a beginning of a sentence:

```dart
String generateRandomSentence() {
  var start = pickRandomPair();
  var startingWords = start.split(" ");
  return generateSentenceStartingWith(startingWords[0], startingWords[1]);
}

String generateSentenceStartingWith(String preprevious, String previous) {
  var sentence = [preprevious, previous];
  var current;
  ...
}
```

Now let's add the `finishSentence` function. Since our database is not very big
we can't assume that we can continue from the last two words. The
`finishSentence` function therefore iteratively drops the last word until it
can finish a sentence, or until too few words are left. In the latter case it
returns null.

```dart
String finishSentence(String start) {
  // This function has local types, to show the differences between List and
  // Iterable.

  List words = start.split(" ");
  // By reversing the list we don't need to deal with the length that much.
  // It also allows to show a few more Iterable functions.
  Iterable reversedRemaining = words.reversed;
  while (reversedRemaining.length >= 2) {
    String secondToLast = reversedRemaining.elementAt(1);
    String last = reversedRemaining.first;
    String leadPair = "$secondToLast $last";
    if (_db.containsKey(leadPair)) {
      // If the leadPair is in the database, it means that we have data to
      // continue from these two words.
      String beginning = reversedRemaining
          .skip(2)    // 'last' and 'secondToLast' are already handled.
          .toList()   // Iterable does not have `reversed`.
          .reversed   // These are the remaining words.
          .join(" "); // Join them to have the beginning of the sentence.
      String end = generateSentenceStartingWith(secondToLast, last);
      return "$beginning $end";
    }
    // We weren't able to continue from the last two words. Drop one, and try
    // again.
    reversedRemaining = reversedRemaining.skip(1);
  }
  return null;
}
```

This function makes heavy use of
[Iterables](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:core.Iterable).
Iterables are one of the most important and powerful data-types in Dart. They
represent a (potentially infinite) sequence of values. Since they are so
important, they have lots of methods to work with their data. For example, it
features ways to filter the data (`where`, `skip`, `take`), to transform it
(`map`, `reduce`, `fold`), or to aggregate it (`toList`, `toSet`, `any`,
`every`).

It is important to note that Iterables are _lazy_ in that all methods that
return themselves an Iterable don't do any work until something iterates over
the returned Iterable. Even then, they only do the work on the items that are
requested. One the one hand, this makes it possible to apply these methods on
infinite Iterables, and to chain methods without fear of allocating intermediate
storage. On the other hand, one can accidentally execute the same
transforming or filtering function multiple times.

```dart
var list = [1, 2, 3];
list.map((x) => print(x));  // Doesn't do anything.
var mappedIterable = list.map((x) { print(x); return x + 1; });
mappedIterable.forEach((x) { /* ignore */ });  // prints 1, 2, 3
mappedIterable.forEach((x) { /* ignore */ });  // prints 1, 2, 3 again.
```

If one wants to use an Iterable multiple times, but doesn't want to execute the
filtering or mapping functions multiple times, one should use `toList` to store
the result in a List (which implements Iterable).



Step 9 - Iterables of Sentences
------

We just discovered the powerful and omnipresent Iterables of Dart. In this
step, we add a method to the sentence-generator that returns an Iterable of
sentences.

Creating an Iterable is surprisingly easy:

```dart
/// Returns an Iterable of sentences.
/// 
/// If the optional named argument [startingWith] is not provided or `null`,
/// the Iterable contains random sentences. Otherwise it contains sentences
/// starting with the given prefix (as if produced by [finishSentence]).
Iterable<String> generateSentences({String startingWith}) sync* {
  while (true) {
    if (startingWith == null) {
      // No optional argument given, or it was null.
      yield generateRandomSentence();
    } else {
      yield finishSentence(startingWith);
    }
  }
}
```

Note: this implementation is inefficient, since it calls `finishSentence`
with the same prefix over and over again. A more efficient solution would do the
prefix computation once, end then call `generateSentenceStartingWith` directly.

This function has a named argument `startingWith`. This allows us to
call the function either with or without the desired prefix. Just after the
named argument we have a crucial token: the `sync*` modifier of the function.

Function bodies that have this modifier are rewritten in such a way that they
return an Iterable, and can provide values at `yield` points. Internally, the
VM creates a state machine that keeps track of where it is. Whenever the
returned Iterable requests a new item, the VM advances in the state machine
until it encounters another `yield`.

To illustrate how the resulting Iterable can be used, let's modify the `finish`
command to filter sentences that are longer than 120 characters.

```dart
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
```

Make sure to test your implementation and have some fun. Here are some
results I got out of my bot:

    <floitsch> myBot: finish: Alice was very
    <myBot> Alice was very fond of pretending to be treated with respect .
    
    <floitsch> myBot: finish: The Congress shall have
    <myBot> The Congress shall have somebody to talk about wasting IT .
    <floitsch> myBot: finish: The Congress shall have
    <myBot> The Congress shall have somebody to talk nonsense .
    <floitsch> myBot: finish: The Congress shall have
    <myBot> The Congress shall have Power, by and with almost no restrictions whatsoever .
    <floitsch> myBot: finish: The Congress may
    <myBot> The Congress may from time to be treated with respect .

Step 10 - Restructuring (optional)
-------

Over time, programs grow, and even our toy example starts to get to a point
where a little bit more structure would help. One of Dart's strengths is to
grow nicely from small to bigger applications. An important and necessary
feature for bigger application is to be able to create independent libraries.
Dart has a public package-management system ([pub](http://pub.dartlang.org)),
but in this code lab we will only split the program into libraries and part
files.

Our bot can be nicely split into two parts: the sentence-generator, and the
IRC protocol handler. Let's start by creating a separate library for the
sentence generator. Take the `SentenceGenerator` class and move it into a new
file `sentence_generator.dart`. On the top of the file add your copyright
header, a library declarative, and the imports that are required for the
generator.

```dart
// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartlang.codelab.irc.sentence_generator;

import 'dart:io' show File;
import 'dart:math' show Random;

class SentenceGenerator {
  ...
}
```

While not necessary, we also used the opportunity to restrict the symbols that
are shown by the imported libraries.

To illustrate the use of part-files we move the IRC code into it's own part
file `irc.dart`.

```dart
// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dartlang.codelab.irc;

final RegExp ircMessageRegExp =
    new RegExp(r":([^!]+)!([^ ]+) PRIVMSG ([^ ]+) :(.*)");

...

void runIrcBot(SentenceGenerator generator) {
  Socket.connect("localhost", 6667)
      .then((socket) => handleIrcSocket(socket, generator));
}
```


In the `main.dart` file we now need to import the `sentence_generator.dart`
library and include the part file:

```dart
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
```

Step 11 - What next?
-------

There are still lots of fun opportunities to improve this code, but if you want
give IRC bots a break, here are some suggestions:

* Read some of the [articles](http://dartlang.org/articles) on `dartlang.org`.
* Do another code lab, for example
 [darrrt badge](https://www.dartlang.org/codelabs/darrrt/), or
 [server side code lab](https://www.dartlang.org/codelabs/server/).
* Learn more about Dart from the
  [Dart tutorials](https://www.dartlang.org/docs/tutorials/)
* Check out some of the [samples](https://www.dartlang.org/samples/)
