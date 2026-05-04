
import 'dart:io';
void main() {
  final file = File('lib/screens/checkin_screen.dart');
  String text = file.readAsStringSync();
  // fix the missing tags
  text = text.replaceAll('          const SizedBox(height: 24),', '              ),\n            ),\n          ),\n          const SizedBox(height: 24),');
  file.writeAsStringSync(text);
}

