import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Verify REST select on bookings and rooms', () async {
    final client = SupabaseClient(
      'https://ygtkveocvunfemoznrqx.supabase.co',
      'sb_publishable_lcNZrPe8jt-q8wLa5z_5MQ_R-cqZ8ml',
    );

    final bookings = await client.from('bookings').select();
    expect(bookings, isA<List>());

    final rooms = await client.from('rooms').select();
    expect(rooms, isA<List>());
  });
}
