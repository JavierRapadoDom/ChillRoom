import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://bybzlijicrlrkbqajkus.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5YnpsaWppY3JscmticWFqa3VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0MDA2MjksImV4cCI6MjA1Nzk3NjYyOX0.QrsWPMU3G8OCwK4ck-UlbnLgDn9G00Gcxm-Y69X2OF4',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
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