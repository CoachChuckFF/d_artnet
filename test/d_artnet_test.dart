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

  test('creates artnet ip prog packet', (){
    final packet1 = new ArtnetIpProgPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet ip prog reply packet', (){
    final packet1 = new ArtnetIpProgReplyPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet ip prog reply packet', (){
    final packet1 = new ArtnetIpProgReplyPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet command packet', (){
    final packet1 = new ArtnetCommandPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet sync packet', (){
    final packet1 = new ArtnetSyncPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet firmware master packet', (){
    final packet1 = new ArtnetFirmwareMasterPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('creates artnet firmware reply packet', (){
    final packet1 = new ArtnetFirmwareReplyPacket();
    print(packet1);
    print(packet1.toHexString());
  });

  test('get opcode of artnet data packet', (){
    final packet1 = new ArtnetDataPacket();
    print("Opcode: 0x" + getOpCode(packet1.udpPacket).toRadixString(16));
  });
}
