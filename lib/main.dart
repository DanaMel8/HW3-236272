import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthNotifier>(
            create: (ctx) => AuthNotifier(),
          ),
          ChangeNotifierProxyProvider<AuthNotifier, SavedNotifier>(
            create: (ctx) => SavedNotifier(ctx.read<AuthNotifier>()),
            update: (_, myAuthNotifier, mySavedNotifier) =>
                (mySavedNotifier?..update(myAuthNotifier)) ??
                SavedNotifier(context.read<AuthNotifier>()),
          ),
        ],
        child: MaterialApp(
          title: 'Startup Name Generator',
          theme: ThemeData(
            // Add the 5 lines from here...
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          home: const RandomWords(),
        ));
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _biggerFont = const TextStyle(fontSize: 18);

  final snackBarDelete = const SnackBar(
    content: Text('Deletion is not implemented yet'),
  );

  final logoutSB = const SnackBar(
    content: Text('Successfully logged out'),
  );

  @override
  Widget build(BuildContext context) {
    var curr_status = context.watch<AuthNotifier>().status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
          (curr_status == Status.authenticated)
              ? IconButton(
                  onPressed: () {
                    context.read<AuthNotifier>()._signOut();
                    ScaffoldMessenger.of(context).showSnackBar(logoutSB);
                  },
                  icon: const Icon(Icons.exit_to_app),
                  tooltip: 'Logout',
                )
              : IconButton(
                  onPressed: _pushLogin,
                  icon: const Icon(Icons.login),
                  tooltip: 'Login',
                ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, i) {
          if (i.isOdd) return const Divider();

          final index = i ~/ 2;

          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          final alreadySaved =
              context.watch<SavedNotifier>().contains(_suggestions[index]);

          return ListTile(
            title: Text(
              _suggestions[index].asPascalCase,
              style: _biggerFont,
            ),
            trailing: Icon(
              alreadySaved ? Icons.favorite : Icons.favorite_border,
              color: alreadySaved ? Colors.red : null,
              semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
            ),
            onTap: () {
              // NEW from here ...
              setState(() {
                if (alreadySaved) {
                  context
                      .read<SavedNotifier>()
                      .removeFromSaved(_suggestions[index]);
                } else {
                  context.read<SavedNotifier>().addToSaved(_suggestions[index]);
                }
              }); // to here.
            },
          );
        },
      ),
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      // Add lines from here...
      MaterialPageRoute<void>(
        builder: (context) {
          final tiles = context.watch<SavedNotifier>().saved.map(
            (pair) {
              return Dismissible(
                background: Container(
                  color: Colors.deepPurple,
                  child: Row(
                    children: const [
                      Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                      ),
                      Text(
                        'Delete suggestion',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                key: ValueKey(pair.hashCode),
                confirmDismiss: (direction) => _showDialog(context, pair),
                onDismissed: (_) =>
                    context.read<SavedNotifier>().removeFromSaved(pair),
                child: ListTile(
                  title: Text(
                    pair.asPascalCase,
                    style: _biggerFont,
                  ),
                ),
              );
            },
          );

          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
                  context: context,
                  tiles: tiles,
                ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ), // ...to here.
    );
  }

  void _pushLogin() {
    Navigator.of(context).push(
      // Add lines from here...
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Login'),
            ),
            body: LoginScreen(),
          );
        },
      ), // ...to here.
    );
  }

  Future<bool?> _showDialog(BuildContext context, WordPair pair) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Suggestion"),
          content: Text(
              "are you sure you want to delete ${pair.toString()} from your saved suggestions?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: TextButton.styleFrom(
                //primary: Colors.white,
                backgroundColor: Colors.deepPurple,
                //onSurface: Colors.grey,
              ),
              child: const Text('yes', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              style: TextButton.styleFrom(
                //primary: Colors.white,
                backgroundColor: Colors.deepPurple,
                //onSurface: Colors.grey,
              ),
              child: const Text('no', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController emailController = TextEditingController();

  TextEditingController passwordController = TextEditingController();

  final loginErrorSB = const SnackBar(
    content: Text('There was an error logging into the app'),
  );
  final signUpErrorSB = const SnackBar(
    content: Text('There was an error signing up'),
  );

  //var curr_status;

  final snackBar = const SnackBar(
    content: Text('Login is not implemented yet'),
  );

  @override
  Widget build(BuildContext context) {
    var curr_status = context.watch<AuthNotifier>().status;

    if (curr_status == Status.unauthenticated ||
        curr_status == Status.authenticated) {
      //regular or failed
      return Scaffold(
          body: Center(
              child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          const Text(
            'Welcome to Startup Names Generator, please log in!',
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: TextField(
              controller: emailController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Email',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: TextField(
              obscureText: true,
              controller: passwordController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Password',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          TextButton(
              onPressed: () async {
                //ScaffoldMessenger.of(context).showSnackBar(snackBar);
                //var curr_stat = context.watch<AuthNotifier>().status;
                bool success_login = await context.read<AuthNotifier>().signIn(
                    emailController.text.toString(),
                    passwordController.text.toString());

                if (success_login == true) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(loginErrorSB);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(16.0)),
                ),
                child:
                    const Text('Log in', style: TextStyle(color: Colors.white)),
              )),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          TextButton(
              onPressed: () async {
                //ScaffoldMessenger.of(context).showSnackBar(snackBar);
                //var curr_stat = context.watch<AuthNotifier>().status;
                UserCredential? success_login = await context
                    .read<AuthNotifier>()
                    .signUp(emailController.text.toString(),
                        passwordController.text.toString());

                if (success_login != null) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(signUpErrorSB);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(16.0)),
                ),
                child: const Text('Sign up',
                    style: TextStyle(color: Colors.white)),
              )),
        ],
      )));
    } else {
      //Status.authenticating
      return Scaffold(
          body: Center(
              child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          const Text(
            'Welcome to Startup Names Generator, please log in!',
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: TextField(
              controller: emailController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Email',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Password',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          const CircularProgressIndicator(),
          const Padding(
            padding: EdgeInsets.all(16.0),
          ),
          const CircularProgressIndicator(),
        ],
      )));
    }
  }

//print("hey");
//print(emailController.text.toString());

}

enum Status { unauthenticated, authenticating, authenticated }

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        _status = Status.unauthenticated;
      } else {
        _user = firebaseUser;
        _status = Status.authenticated;
      }
      notifyListeners();
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  Status _status = Status.unauthenticated;
  User? _user;

  User? get user => _user;

  Status get status => _status;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print(e);
      _status = Status.unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } catch (e) {
      print(e);
      _status = Status.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  void _signOut() {
    //non wait
    try {
      _auth.signOut();
      //TODO: Do we need this?
      _status = Status.unauthenticated;
      notifyListeners();
      return;
    } catch (e) {
      print(e);
      return;
    }
    //there is no need to notify because the listen??
    //but if it happens in delay, maybe better to notify here?
  }
}

class SavedNotifier extends ChangeNotifier {
  final _saved = <WordPair>{};
  final _firestore = FirebaseFirestore.instance;

  Set<WordPair> get saved => Set.unmodifiable(_saved);
  AuthNotifier _authData;

  SavedNotifier(this._authData) {
    update(_authData);
  }

  bool addToSaved(WordPair pair) {
    if (_saved.add(pair)) {
      notifyListeners();
      exportTo();
      return true;
    } else {
      //already in the list
      return false;
    }
  }

  bool removeFromSaved(WordPair pair) {
    if (_saved.remove(pair)) {
      notifyListeners();
      exportTo();
      return true;
    } else {
      return false;
    }
  }

  bool contains(WordPair pair) {
    return (_saved.contains(pair));
  }

  Future<void> update(AuthNotifier myAuthNotifier) async {
    _authData = myAuthNotifier;
    if (_authData.status == Status.authenticated) {
      await importFrom();
      await exportTo();
    }
  }

  Future<void> importFrom() async {
    if (_authData.status != Status.authenticated) return;
    var data =
        await _firestore.collection('users').doc(_authData.user!.uid).get();

    _saved.addAll(((data.data()?["pairsArray"] ?? []) as List)
        .map((e) => (e as String).split(" "))
        .map((e) => WordPair(e[0], e[1])));

    notifyListeners();
  }

  Future<void> exportTo() async {
    if (_authData.status != Status.authenticated) return;

    var data = _saved
        .toList()
        .map((wordPair) => "${wordPair.first} ${wordPair.second}")
        .toList();

    await _firestore
        .collection("users")
        .doc(_authData.user!.uid)
        .set({'pairsArray': data}, SetOptions(merge: true));
  }
}
