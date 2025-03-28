import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async{
  await Supabase.initialize(
    url: 'https://bybzlijicrlrkbqajkus.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5YnpsaWppY3JscmticWFqa3VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI0MDA2MjksImV4cCI6MjA1Nzk3NjYyOX0.QrsWPMU3G8OCwK4ck-UlbnLgDn9G00Gcxm-Y69X2OF4',
  );
}

final supabase = Supabase.instance.client;