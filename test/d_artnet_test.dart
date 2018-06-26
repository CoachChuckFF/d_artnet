import 'package:test/test.dart';

import 'package:d_artnet/d_artnet.dart';

void main() {
  test('creates artnet data packet', () {
    final packet1 = new ArtnetDataPacket();
    print(packet1);
    print(packet1.toHexString());
    final packet2 = new ArtnetDataPacket(null, 257);
    packet2.whiteout();
    print(packet2);
    print(packet2.toHexString());

  });

  test('creates artnet poll packet', (){
    final packet1 = new ArtnetPollPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet poll reply packet', (){
    print("TODO");
  });
}
