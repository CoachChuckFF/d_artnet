import 'package:test/test.dart';

import 'package:d_artnet/d_artnet.dart';

void main() {
  test('creates artnet data packet', () {
    final packet1 = new ArtnetDataPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet poll packet', (){
    final packet1 = new ArtnetPollPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet poll reply packet', (){
    final packet1 = new ArtnetPollReplyPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet address packet', (){
    final packet1 = new ArtnetAddressPacket();
    print(packet1);
    print(packet1.toHexString());
  });
}
