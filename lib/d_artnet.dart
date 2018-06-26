library d_artnet;

import 'dart:typed_data';

const protVer = 14;
const opCodeIndex = 8;

void copyIdtoBuffer(ByteData buffer, int opCode){
  final List<int> id = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00];
  for(var i = 0; i < id.length; i++){
    buffer.setUint8(i, id[i]);
  }
  buffer.setUint16(opCodeIndex, opCode);
}

bool checkArtnetPacket(List<int> packet){
  final List<int> id = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00];
  for(var i = 0; i < id.length; i++){
    if(packet[i] != id[i]){
      return false;
    }
  } 

  return true;
}

int getOpcode(List<int> packet){
  if(packet.length <= opCodeIndex) return -1;

  return packet[opCodeIndex];
}

class ArtnetDataPacket {
  static const size = 18;
  static const opCode = 0x5000;
  static const defaultDataLength = 512;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const sequenceIndex = protVerLoIndex + 1;
  static const physicalIndex = sequenceIndex + 1;
  static const subUniIndex = physicalIndex + 1;
  static const netIndex = subUniIndex + 1;
  static const lengthHiIndex = netIndex + 1;
  static const lengthIndex = lengthHiIndex + 1;
  static const dataIndex = lengthIndex + 1;

  ByteData packet;
  Uint8List data;

  ArtnetDataPacket([List<int> packet, int dmxLength = defaultDataLength]){
    this.packet = new ByteData(size + defaultDataLength);
    if(packet != null){
      for(var i = 0; i < size + defaultDataLength; i++){
        this.packet.setUint8(i, packet[i]);
      }
      return;
    }

    //set id
    copyIdtoBuffer(this.packet, opCode);

    //set protocol version
    this.protVersion = protVer;

    //set length
    this.dmxLength = dmxLength;
    
  }

  int get protVerHi => this.packet.getUint8(protVerHiIndex);
  set protVerHi(int value) => this.packet.setUint8(protVerHiIndex, value);

  int get protVerLo => this.packet.getUint8(protVerLoIndex);
  set protVerLo(int value) => this.packet.setUint8(protVerLoIndex, value);

  int get protVersion => this.packet.getUint16(protVerHiIndex);
  set protVersion(int value) => this.packet.setUint16(protVerHiIndex, value);

  int get sequence => this.packet.getUint8(sequenceIndex);
  set sequence(int value) => this.packet.setUint8(sequenceIndex, value);

  int get physical => this.packet.getUint8(physicalIndex);
  set physical(int value) => this.packet.setUint8(physicalIndex, value);

  int get subUni => this.packet.getUint8(subUniIndex);
  set subUni(int value) => this.packet.setUint8(subUniIndex, value);

  int get net => this.packet.getUint8(netIndex);
  set net(int value) => this.packet.setUint8(netIndex, value);

  int get universe => ((this.net << 8) & 0x7F00) | this.subUni & 0xFF;
  set universe(int value){
    this.subUni = value & 0xFF;
    this.net = (value >> 8) & 0x7F;
  }

  int get lengthHi => this.packet.getUint8(lengthHiIndex);
  set lengthHi(int value) => this.packet.setUint8(lengthHiIndex, value);

  int get lengthLo => this.packet.getUint8(lengthIndex);
  set lengthLo(int value) => this.packet.setUint8(lengthIndex, value);

  int get dmxLength => this.packet.getUint16(lengthHiIndex);
  set dmxLength(int value){
    if(value > defaultDataLength || value < 0){
      return;
    }

    this.packet.setUint16(lengthHiIndex, value);
  }

  void blackout() {
    for(var i = 0; i < defaultDataLength; i++){
      this.packet.setUint8(dataIndex + i, 0x00);
    }
  }

  void whiteout() {
    for(var i = 0; i < defaultDataLength; i++){
      this.packet.setUint8(dataIndex + i, 0xFF);
    }
  }

  void copyDmxToPacket(ByteData data) {
    for(var i = 0; i < defaultDataLength; i++){
      this.packet.setUint8(dataIndex + i, data.getUint8(i));
    }
  }

  void copyDmxFromPacket(ByteData data) {
    for(var i = 0; i < defaultDataLength; i++){
      data.setUint8(i, this.packet.getUint8(dataIndex + i));
    }
  }

  void setDmxvalueue(int address, int valueue){
    if(address > defaultDataLength || address < 1){
      return;
    }

    this.packet.setUint8(dataIndex + address - 1, valueue);
  }

  void setDmxvalueues(List<int> addresses, int valueue){

    addresses.forEach((address){
      if(address > defaultDataLength || address < 1){
        return;
      }
      this.packet.setUint8(dataIndex + address - 1, valueue);
    });
  }

  List<int> get dmx => this.packet.buffer.asUint8List(dataIndex, this.dmxLength);

  List<int> get udpPacket => this.packet.buffer.asUint8List(0, size + this.dmxLength);

  @override
  String toString() {
    String string = "***Artnet Data Packet***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Sequence: " + this.sequence.toString() + "\n";
    string += "Physical: " + this.physical.toString() + "\n";
    string += "Universe: " + this.universe.toString() + "\n";
    string += "*** Net: " + this.net.toString() + "\n";
    string += "*** Sub Universe: " + this.subUni.toString() + "\n";
    string += "Data Length: " + this.dmxLength.toString() + "\n";
    string += "Data:";
    for(var i = 1; i <= this.dmxLength; i++){
      if(((i-1) % 16) == 0){
        string +="\n*** ";
      }
      String tempString = " " + (i).toString() + ":" + this.dmx[i-1].toString() + " ";
      while(tempString.length < 9){
        tempString += " ";
      }
      string += tempString;
    }
    string += "\n**********************\n";

    return string;
  }

  String toHexString(){
    String string = "***Artnet Data Packet***\n";
    String tempString = "";
    for(var i = 0; i < this.udpPacket.length; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    string += "\n**********************\n";
    return string;
  }

}

class ArtnetPollPacket {
  static const size = 14;
  static const opCode = 0x2000;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const talkToMeIndex = protVerLoIndex + 1;
  static const priorityIndex = talkToMeIndex + 1;

  /* Masks */
  static const vlcTransmissionMask = 0x10;
  static const diagnosticsTransmissionMask = 0x08;
  static const diagnosticsEnableMask = 0x04;
  static const pollReplyOptionMask = 0x02;

  ByteData packet;

  ArtnetPollPacket([List<int> packet]){
    this.packet = new ByteData(size);
    if(packet != null){
      for(var i = 0; i < size; i++){
        this.packet.setUint8(i, packet[i]);
      }
      return;
    }

    //set id
    copyIdtoBuffer(this.packet, opCode);

    //set protocol version
    this.packet.setUint8(protVerLoIndex, protVer);
  }

  int get protVerHi => this.packet.getUint8(protVerHiIndex);
  set protVerHi(int value) => this.packet.setUint8(protVerHiIndex, value);

  int get protVerLo => this.packet.getUint8(protVerLoIndex);
  set protVerLo(int value) => this.packet.setUint8(protVerLoIndex, value);

  int get protVersion => this.packet.getUint16(protVerHiIndex);
  set protVersion(int value) => this.packet.setUint16(protVerHiIndex, value);

  set talkToMe(int value) => packet.setUint8(talkToMeIndex, value);
  int get talkToMe => packet.getUint8(talkToMeIndex);

  set priority(int value) => packet.setUint8(priorityIndex, value);
  int get priority => packet.getUint8(priorityIndex);

  List<int> get udpPacket => packet.buffer.asUint8List();

    @override
  String toString() {
    String string = "***Artnet Poll Packet***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Talk to me: 0x" + this.talkToMe.toRadixString(16) + "\n";
    string += "*** VLC Transmission: " + (((this.talkToMe & vlcTransmissionMask) == 0) ? "Enabled" : "Disabled" + "\n");
    string += "*** Diagnostics: " + (((this.talkToMe & diagnosticsEnableMask) == 0) ? "Enabled" : "Disabled" + "\n");
    string += "*** Diagnostics are " + (((this.talkToMe & diagnosticsTransmissionMask) == 0) ? "broadcast" : "unicast" + "\n");
    string += "*** Send Art Poll Reply: " + (((this.talkToMe & pollReplyOptionMask) == 0) ? "in response" : "on change" + "\n");
    string += "Priority: " + this.priority.toString() + "\n";

    return string;
  }

  String toHexString(){
    String string = "***Artnet Data Packet***\n";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    string += "\n**********************\n";
    return string;
  }

}

class ArtnetPollReplyPacket {
  static const size = 234;
  static const opCode = 0x2100;

  /* Sizes */
  static const ipAddressSize = 4;
  static const portSize = 2;
  static const shortNameSize = 18;
  static const longNameSize = 64;
  static const nodeReportSize = 64;
  static const portTypesSize = 4;
  static const goodInputSize = 4;
  static const goodOutpuSize = 4;
  static const swInSize = 4;
  static const swOutSize = 4;
  static const spareSize = 3;
  static const bindIpSize = 4;
  static const fillerSize = 26;

  /* Indexes */
  static const ipAddressIndex = opCodeIndex + 2;
  static const portIndex = ipAddressIndex + ipAddressSize;
  static const versInfoHIndex = portIndex + portSize;
  static const versInfoLIndex = versInfoHIndex + 1;
  static const netSwitchIndex = versInfoLIndex + 1;
  static const subSwitchIndex = netSwitchIndex + 1;
  static const oemHiIndex = subSwitchIndex + 1;
  static const oemIndex = oemHiIndex + 1;
  static const ubeaVersionIndex = oemIndex + 1;
  static const status1Index = ubeaVersionIndex + 1;
  static const estaManLoIndex = status1Index + 1;
  static const estaManHiIndex = estaManLoIndex + 1;
  static const shortNameIndex = estaManHiIndex + 1;
  static const longNameIndex = shortNameIndex + shortNameSize;
  static const nodeReportIndex = longNameIndex + longNameSize;
  static const numPortsHiIndex = nodeReportIndex + nodeReportSize;
  static const numPortsLoIndex = numPortsHiIndex + 1;
  static const portTypesIndex = numPortsLoIndex + 1;
  static const goodInputIndex = portTypesIndex + portTypesSize;
  static const goodOutputIndex = goodInputIndex + goodInputSize;
  static const swInIndex = goodOutputIndex + goodOutpuSize;
  static const swOutIndex = swInIndex + swInSize;
  static const swVideoIndex = swOutIndex + swOutSize;
  static const swMacroIndex = swVideoIndex + 1;
  static const swRemote = swMacroIndex + 1;
  static const spareIndex = swRemote + 1;
  static const styleIndex = spareIndex + spareSize;
  static const macHiIndex = styleIndex + 1;
  static const mac4Index = macHiIndex + 1;
  static const mac3Index = mac4Index + 1;
  static const mac2Index = mac3Index + 1;
  static const mac1Index = mac2Index + 1;
  static const macLoIndex = mac1Index + 1;
  static const bindIpIndex = macLoIndex + 1;
  static const bindIndexIndex = bindIpIndex + bindIpSize;
  static const status2Index = bindIndexIndex + 1;
  static const fillerIndex = status2Index + 1;

  ByteData packet;

  ArtnetPollReplyPacket(List<int> packet){
    this.packet = new ByteData(size);
    if(packet != null){
      for(var i = 0; i < size; i++){
        this.packet.setUint8(i, packet[i]);
      }
      return;
    }

    //set id
    copyIdtoBuffer(this.packet, opCode);
  }

  List<int> get ip => this.packet.buffer.asUint8List(ipAddressIndex, ipAddressSize);
  set ip(List<int> ip){
    for(var i = 0; i < ipAddressSize; i++){
      this.packet.setUint8(ipAddressIndex + i, ip[i]);
    }
  }

  int get port => this.packet.getUint16(portIndex);
  set port(int value) => this.packet.setUint16(portIndex, value);

  int get versionInfoH => this.packet.getUint8(versInfoHIndex);
  set versionInfoH(int value) => this.packet.setUint8(versInfoHIndex, value);

  int get versionInfoL => this.packet.getUint8(versInfoLIndex);
  set versionInfoL(int value) => this.packet.setUint8(versInfoLIndex, value);

  int get netSwitch => this.packet.getUint8(netSwitchIndex);
  set netSwitch(int value) => this.packet.setUint8(netSwitchIndex, value);

  int get subSwitch => this.packet.getUint8(subSwitchIndex);
  set subSwitch(int value) => this.packet.setUint8(subSwitchIndex, value);

  int get oemHi => this.packet.getUint8(oemHiIndex);
  set oemHi(int value) => this.packet.setUint8(oemHiIndex, value);

  int get oemLo => this.packet.getUint8(oemIndex);
  set oemLo(int value) => this.packet.setUint8(oemIndex, value);

  int get oem => this.packet.getUint8(oemHiIndex) << 8 | this.packet.getUint8(oemIndex);
  set oem(int value) {
    this.packet.setUint8(oemHiIndex, (value >> 8) & 0xFF);
    this.packet.setUint8(oemIndex, value & 0xFF);
  }

  int get ubeaVersion => this.packet.getUint8(ubeaVersionIndex);
  set ubeaVersion(int value) => this.packet.setUint8(ubeaVersionIndex, value);

  int get status1 => this.packet.getUint8(status1Index);
  set status1(int value) => this.packet.setUint8(status1Index, value);



}

