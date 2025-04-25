import 'package:chillroom/screens/home_screen.dart';
import 'package:chillroom/screens/login_screen.dart';
import 'package:chillroom/screens/register_screen.dart';
import 'package:chillroom/supabase_client.dart';
import 'package:flutter/material.dart';


main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'ChauPhilomeneOne',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: supabase.auth.currentUser == null
          ? HomeScreen()
          : MyHomePage(),
    );
  }

}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Supabase Flutter Demo'),
      ),
      body: Center(
        child: Text('Hello, World!'),
      ),
    );
  }
}