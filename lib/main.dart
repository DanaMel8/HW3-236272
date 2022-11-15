import 'dart:io';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  final imageErrorSB = const SnackBar(
    content: Text('No image selected'),
  );

  final snappingSheetController = SnappingSheetController();
  bool is_open = false;

  @override
  Widget build(BuildContext context) {
    var curr_status = context.watch<AuthNotifier>().status;
    var pos;
    const positionStart = SnappingPosition.factor(
            positionFactor: 0.0,
            snappingCurve: Curves.easeOutExpo,
            snappingDuration: Duration(seconds: 1),
            grabbingContentOffset: GrabbingContentOffset.top,
          );
    const positionMiddle = SnappingPosition.factor(
            snappingCurve: Curves.easeOutExpo,
            snappingDuration: Duration(seconds: 1),
            positionFactor: 0.3,
          );
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
      body: (curr_status == Status.authenticated)
          ? SnappingSheet(
              controller: snappingSheetController,
        snappingPositions: const [
          positionStart,
          positionMiddle,
        ],
              grabbing: InkWell(
                  child: Container(
                    color: Colors.grey,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          //context.watch<AuthNotifier>().auth.name
                          Text(
                              "Welcome back, ${context.read<AuthNotifier>().user?.email}"),
                          (is_open == false)
                              ? const Icon(
                                  Icons.keyboard_arrow_up,
                                )
                              : const Icon(Icons.keyboard_arrow_down)
                        ]),
                  ),
                  onTap: () {
                    if (is_open == false) {
                      pos = snappingSheetController.currentPosition;
                      snappingSheetController.snapToPosition(
                        positionMiddle
                      );
                      // setState() {
                      is_open = true;
                      // }
                    } else {
                      snappingSheetController.snapToPosition(positionStart);
                      //  setState() {
                      is_open = false;
                      // }
                    }
                  }),
              grabbingHeight: 70,
              sheetBelow: SnappingSheetContent(
                sizeBehavior: SheetSizeStatic(
                  size: MediaQuery.of(context).size.height,
                  expandOnOverflow: false,
                ),
                draggable: false,
                // TODO: Add your sheet content here
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          flex: 2,
                          child: FutureBuilder<ImageProvider>(
                            future: context.watch<AuthNotifier>().downloadFile('Avatar_images'),
                            // a previously-obtained Future<String> or null
                            builder: (BuildContext context,
                                AsyncSnapshot<ImageProvider> snapshot) {
                              if (snapshot.hasData) {
                                //image picked
                                return CircleAvatar(
                                  radius: 45,
                                    foregroundImage: snapshot.requireData);
                              }
                              return CircleAvatar();
                            },
                          ),
                        ),
                        Flexible(
                          fit: FlexFit.tight,
                          flex: 5,
                          child: Column(
                            children: [
                              Text(
                                "${context.read<AuthNotifier>().user?.email}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final ImagePicker _picker = ImagePicker();
                                  //change avatar
                                  final XFile? image = await _picker.pickImage(
                                      source: ImageSource.gallery);

                                  if (image == null) {
                                    //showing no choice
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(imageErrorSB);
                                    return;
                                  }
                                  //upload image
                                  context
                                      .read<AuthNotifier>()
                                      .uploadFile(image, 'Avatar_images');
                                },
                                style: TextButton.styleFrom(
                                  //primary: Colors.white,
                                  backgroundColor: Colors.deepPurple,
                                  //onSurface: Colors.grey,
                                ),
                                child: const Text('Change Avatar',
                                    style: TextStyle(color: Colors.white)),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemBuilder: (context, i) {
                  if (i.isOdd) return const Divider();

                  final index = i ~/ 2;

                  if (index >= _suggestions.length) {
                    _suggestions.addAll(generateWordPairs().take(10));
                  }
                  final alreadySaved = context
                      .watch<SavedNotifier>()
                      .contains(_suggestions[index]);

                  return ListTile(
                    title: Text(
                      _suggestions[index].asPascalCase,
                      style: _biggerFont,
                    ),
                    trailing: Icon(
                      alreadySaved ? Icons.favorite : Icons.favorite_border,
                      color: alreadySaved ? Colors.red : null,
                      semanticLabel:
                          alreadySaved ? 'Remove from saved' : 'Save',
                    ),
                    onTap: () {
                      // NEW from here ...
                      setState(() {
                        if (alreadySaved) {
                          context
                              .read<SavedNotifier>()
                              .removeFromSaved(_suggestions[index]);
                        } else {
                          context
                              .read<SavedNotifier>()
                              .addToSaved(_suggestions[index]);
                        }
                      }); // to here.
                    },
                  );
                },
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemBuilder: (context, i) {
                if (i.isOdd) return const Divider();

                final index = i ~/ 2;

                if (index >= _suggestions.length) {
                  _suggestions.addAll(generateWordPairs().take(10));
                }
                final alreadySaved = context
                    .watch<SavedNotifier>()
                    .contains(_suggestions[index]);

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
                        context
                            .read<SavedNotifier>()
                            .addToSaved(_suggestions[index]);
                      }
                    }); // to here.
                  },
                );
              },
            ),
    );
  }

  void _swipeUp() {}

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

  TextEditingController confirmController = TextEditingController();

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
    final _formKey = GlobalKey<FormState>();

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

                /*
                UserCredential? success_login = await context
                    .read<AuthNotifier>()
                    .signUp(emailController.text.toString(),
                        passwordController.text.toString());

                if (success_login != null) {
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(signUpErrorSB);
                }
                */
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.3 + MediaQuery.of(context).viewInsets.bottom,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24.0, left:24, top:14),
                        child: Column(
                          children: [
                            const Text("Please confirm your password below: "),
                            const Divider(
                              height: 20,
                              thickness: 1,
                              endIndent: 0,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Form(
                              key: _formKey,
                              child: TextFormField(
                                validator: (value) {
                                  if (value != passwordController.text) {
                                    return "Passwords must match";
                                  }
                                  return null;
                                },
                                controller: confirmController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  //errorText: "Passwords must match",
                                  border: OutlineInputBorder(),
                                  hintText: 'Password Confirm',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () async {
                                //sign up
                                if (_formKey.currentState!
                                    .validate()) //same password
                                {
                                  UserCredential? success_login = await context
                                      .read<AuthNotifier>()
                                      .signUp(emailController.text.toString(),
                                          passwordController.text.toString());

                                  if (success_login != null) {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                  } else {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(signUpErrorSB);
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                //primary: Colors.white,
                                backgroundColor: Colors.lightBlue,
                                //onSurface: Colors.grey,
                              ),
                              child: const Text('Confirm',
                                  style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Colors.lightBlue,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(16.0)),
                ),
                child: const Text('New user? Click to sign up',
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
        _image = null;
        _status = Status.unauthenticated;
      } else {
        _user = firebaseUser;
        _status = Status.authenticated;
      }
      notifyListeners();
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Status _status = Status.unauthenticated;
  User? _user;
  File? _image;

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

  Future<void> uploadFile(XFile image, String cloudPath) async {
    var path = '$cloudPath/${_user!.uid}';
    var fileRef = _storage.ref(path); // cloudPath = “images/profile.jpg”
    _image = File(image.path);
    notifyListeners();
    try {
      await fileRef.putFile(_image!);
    } catch (e) {
      return Future.value(null);
    }
  }

  Future<ImageProvider> downloadFile(String cloudPath) async {
    var path = '$cloudPath/${_user!.uid}';



    if (_image == null) {
      // no privious image
      try {
        return NetworkImage(await _storage.ref(path).getDownloadURL());
      } catch(e) {
        return const AssetImage('images/icon-avatar.png');
      }
    } else {
      return FileImage(_image!);
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

//מקלדת לא תקפוץ, תמונה פרופיל?
