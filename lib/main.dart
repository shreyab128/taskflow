
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw Exception(
      'Supabase credentials are missing. '
      'Run the app with --dart-define-from-file=secrets.json',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<List<Map<String, dynamic>>> testConnection() async {
    final response = await Supabase.instance.client
        .from('projects')
        .select()
        .limit(1);

    return response;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow'),
      ),
      body: Center(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: testConnection(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return Text(
                'Connection failed: ${snapshot.error}',
                textAlign: TextAlign.center,
              );
            }

            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_done,
                  size: 64,
                  color: Colors.green,
                ),
                SizedBox(height: 16),
                Text(
                  'Database connection successful!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text('TaskFlow can communicate with Supabase.'),
              ],
            );
          },
        ),
      ),
    );
  }
}
