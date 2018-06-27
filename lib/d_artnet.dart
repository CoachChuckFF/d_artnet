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
  static const talkToMeVlcTransmissionEnableMask = 0x10;
  static const talkToMeDiagnosticsTransmissionMask = 0x08;
  static const talkToMeDiagnosticsEnableMask = 0x04;
  static const talkToMePollReplyOptionMask = 0x02;

  /* Options */
  static const talkToMeDiagnosticsTransmissionOptionBroadcast = 0;
  static const talkToMeDiagnosticsTransmissionOptionUnicast = 1;
  static const talkToMePollReplyOptionOnlyInResponse = 0;
  static const talkToMePollReplyOptionOnChange = 1;

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
    this.protVersion = protVer;
  }

  int get protVerHi => this.packet.getUint8(protVerHiIndex);
  set protVerHi(int value) => this.packet.setUint8(protVerHiIndex, value);

  int get protVerLo => this.packet.getUint8(protVerLoIndex);
  set protVerLo(int value) => this.packet.setUint8(protVerLoIndex, value);

  int get protVersion => this.packet.getUint16(protVerHiIndex);
  set protVersion(int value) => this.packet.setUint16(protVerHiIndex, value);

  int get talkToMe => this.packet.getUint8(talkToMeIndex);
  set talkToMe(int value) => this.packet.setUint8(talkToMeIndex, value);

  bool get talkToMeVlcTransmissionEnable => ((this.talkToMe & talkToMeVlcTransmissionEnableMask) == 0);
  set talkToMeVlcTransmissionEnable(bool value) => (value) ? this.talkToMe &= ~talkToMeVlcTransmissionEnableMask : this.talkToMe |= talkToMeVlcTransmissionEnableMask;

  bool get talkToMeDiagnosticsEnable => ((this.talkToMe & talkToMeDiagnosticsEnableMask) != 0);
  set talkToMeDiagnosticsEnable(bool value) => (value) ? this.talkToMe |= talkToMeDiagnosticsEnableMask : this.talkToMe &= ~talkToMeDiagnosticsEnableMask;

  int get talkToMeDiagnosticsTransmission => (this.talkToMe & talkToMeDiagnosticsTransmissionMask) >> 3;
  set talkToMeDiagnosticsTransmission(int value) => (value == talkToMeDiagnosticsTransmissionOptionUnicast) ? this.talkToMe |= talkToMeDiagnosticsTransmissionMask : this.talkToMe &= ~talkToMeDiagnosticsTransmissionMask;

  int get talkToMePollReplyOption => (this.talkToMe & talkToMePollReplyOptionMask) >> 1;
  set talkToMePollReplyOption(int value) => (value == talkToMePollReplyOptionOnChange) ? this.talkToMe |= talkToMePollReplyOptionMask : this.talkToMe &= ~talkToMePollReplyOptionMask;

  int get priority => this.packet.getUint8(priorityIndex);
  set priority(int value) => this.packet.setUint8(priorityIndex, value);


  List<int> get udpPacket => this.packet.buffer.asUint8List();

    @override
  String toString() {
    String string = "***Artnet Poll Packet***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Talk to me: 0x" + this.talkToMe.toRadixString(16) + "\n";
    string += "*** VLC Transmission: " + ((this.talkToMeVlcTransmissionEnable) ? "Enabled" : "Disabled") + "\n";
    string += "*** Diagnostics: " + ((this.talkToMeDiagnosticsEnable) ? "Enabled" : "Disabled") + "\n";
    string += "*** Diagnostics are " + ((this.talkToMeDiagnosticsTransmission == talkToMeDiagnosticsTransmissionOptionBroadcast) ? "broadcast" : "unicast") + "\n";
    string += "*** Send art poll reply " + ((this.talkToMePollReplyOption == talkToMePollReplyOptionOnChange) ? "on config change" : "in response to art poll") + "\n";
    string += "Priority: " + this.priority.toString() + "\n";

    return string;
  }

  String toHexString(){
    String string = "***Artnet Poll Packet***\n";
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
  static const goodOutputSize = 4;
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
  static const swInIndex = goodOutputIndex + goodOutputSize;
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

  /* Bitmasks */
  static const status1PollReplyOptionMask = 0xC0;
  static const status1ProgrammingAuthorityMask = 0x30;
  static const status1FirmwareBootMask = 0x04;
  static const status1RdmCapableMask = 0x02;
  static const status1UbeaPresentMask = 0x01;
  static const portTypesOutputArtnetAbleMask = 0x80;
  static const portTypesInputArtnetAbleMask = 0x40;
  static const portTypesProtocolMask = 0x3F;
  static const goodInputDataReceivedMask = 0x80;
  static const goodInputIncludesTestPackets1Mask = 0x40;
  static const goodInputIncludesSIPsMask = 0x20;
  static const goodInputIncludesTestPackets2Mask = 0x10;
  static const goodInputInputDisableMask = 0x08;
  static const goodInputReceiveErrorDetectedMask = 0x04;
  static const goodOutputDataTransmitingMask = 0x80;
  static const goodOutputIncludesTestPackets1Mask = 0x40;
  static const goodOutputIncludesSIPsMask = 0x20;
  static const goodOutputIncludesTestPackets2Mask = 0x10;
  static const goodOutputIsMergingMask = 0x08;
  static const goodOutputShortDetectedMask = 0x04;
  static const goodOutputMergeIsLTPMask = 0x04;
  static const goodOutputProtocolMask = 0x04;
  static const swMask = 0x0F;

  /* Options */
  static const status1PollReplyOptionOptionUnkown = 0x00;
  static const status1PollReplyOptionOptionLocate = 0x01;
  static const status1PollReplyOptionOptionMute = 0x02;
  static const status1PollReplyOptionOptionNormal = 0x03;
  static const status1ProgrammingAuthorityOptionUnknown = 0x00;
  static const status1ProgrammingAuthorityOptionPanel = 0x01;
  static const status1ProgrammingAuthorityOptionNetwork = 0x02;
  static const status1FirmwareBootOptionNormal = 0x00;
  static const status1FirmwareBootOptionRom = 0x01;
  static const portTypesProtocolOptionDMX = 0x00;
  static const portTypesProtocolOptionMidi = 0x01;
  static const portTypesProtocolOptionAvab = 0x02;
  static const portTypesProtocolOptionColortranCMX = 0x03;
  static const portTypesProtocolOptionADB62_5 = 0x04;
  static const portTypesProtocolOptionArtnet = 0x05;
  static const goodOutputProtocolOptionArtnet = 0x00;
  static const goodOutputProtocolOptionSacn = 0x01;

  ByteData packet;

  ArtnetPollReplyPacket([List<int> packet]){
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
      if(ip.length <= i){
        this.packet.setUint8(ipAddressIndex + i, 0);    
      } else {
        this.packet.setUint8(ipAddressIndex + i, ip[i]);
      }
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

  int get oem => (this.oemHi << 8) &0xFF00 | this.oem & 0xFF;
  set oem(int value) {
    this.oemHi = (value >> 8);  
    this.oemLo = value & 0xFF;
  }

  int get ubeaVersion => this.packet.getUint8(ubeaVersionIndex);
  set ubeaVersion(int value) => this.packet.setUint8(ubeaVersionIndex, value);

  int get status1 => this.packet.getUint8(status1Index);
  set status1(int value) => this.packet.setUint8(status1Index, value);

  int get status1PollReplyOption => (this.status1 & status1PollReplyOptionMask) >> 6;
  set status1PollReplyOption(int value){
    //clear value
    this.status1 &= ~status1PollReplyOptionMask;
    //set value
    this.status1 |= ((value << 6) & status1PollReplyOptionMask);
  }

  int get status1ProgrammingAuthority => (this.status1 & status1ProgrammingAuthorityMask) >> 4;
  set status1ProgrammingAuthority(int value){
    //clear value
    this.status1 &= ~status1ProgrammingAuthorityMask;
    //set value
    this.status1 |= ((value << 4) & status1ProgrammingAuthorityMask);
  }

  int get status1FirmwareBoot => (this.status1 & status1ProgrammingAuthorityMask) >> 2;
  set status1FirmwareBoot(int value) => (value == status1FirmwareBootOptionRom) ? this.status1 |= status1FirmwareBootMask : this.status1 &= ~status1FirmwareBootMask;

  bool get status1RdmCapable => ((this.status1 & status1RdmCapableMask) != 0);
  set status1RdmCapable(bool value) => (value) ? this.status1 |= status1RdmCapableMask : this.status1 &= ~status1RdmCapableMask;
  
  bool get status1UbeaPresent => ((this.status1 & status1UbeaPresentMask) != 0);
  set status1UbeaPresent(bool value) => (value) ? this.status1 |= status1UbeaPresentMask : this.status1 &= ~status1UbeaPresentMask;

  int get estaManLo => this.packet.getUint8(estaManLoIndex);
  set estaManLo(int value) => this.packet.setUint8(estaManLoIndex, value);

  int get estaManHi => this.packet.getUint8(estaManHiIndex);
  set estaManHi(int value) => this.packet.setUint8(estaManHiIndex, value);

  int get estaMan => this.estaManHi << 8 | this.estaManLo;
  set estaMan(int value){
    this.estaManHi = value >> 8;
    this.estaManLo = value & 0xFF;
  }

  String get shortName => this.packet.buffer.asUint8List(shortNameIndex, shortNameSize).toString();
  set shortName(String value){
    for(var i = 0; i < shortNameSize; i++){
      if(value.length <= i){
        this.packet.setUint8(shortNameIndex + i, 0);
      } else {
        this.packet.setInt8(shortNameIndex + i, value.codeUnitAt(i));
      }
    }
    this.packet.setUint8(shortNameIndex + shortNameSize - 1, 0); //Null terminate just in case
  }

  String get longName => this.packet.buffer.asUint8List(longNameIndex, longNameSize).toString();
  set longName(String value){
    for(var i = 0; i < longNameSize; i++){
      if(value.length <= i){
        this.packet.setUint8(longNameIndex + i, 0);
      } else {
        this.packet.setInt8(longNameIndex + i, value.codeUnitAt(i));
      }
    }
    this.packet.setUint8(longNameIndex + longNameSize - 1, 0); //Null terminate just in case
  }

  String get nodeReport => this.packet.buffer.asUint8List(nodeReportIndex, nodeReportSize).toString();
  set nodeReport(String value){
    for(var i = 0; i < nodeReportSize; i++){
      if(value.length <= i){
        this.packet.setUint8(nodeReportIndex + i, 0);
      } else {
        this.packet.setInt8(nodeReportIndex + i, value.codeUnitAt(i));
      }
    }
    this.packet.setUint8(nodeReportIndex + nodeReportSize - 1, 0); //Null terminate just in case
  }

  int get numPortsHi => this.packet.getUint8(numPortsHiIndex);
  set numPortsHi(int value) => this.packet.setUint8(numPortsHiIndex, value);

  int get numPortsLo => this.packet.getUint8(numPortsLoIndex);
  set numPortsLo(int value) => this.packet.setUint8(numPortsLoIndex, value);

  int get numPorts => this.packet.getUint16(numPortsHiIndex);
  set numPorts(int value) => this.packet.setUint16(numPortsHiIndex, value);

  List<int> get portTypes => this.packet.buffer.asUint8List(portTypesIndex, portTypesSize);
  void setPortType(int index, int value){
    if(index >= portTypesSize || index < 0){
      return;
    }
    this.packet.setUint8(portTypesIndex + index, value);
  }

  bool getPortTypesOutputArtnetAble(int index) => (index >= portTypesSize) ? false : ((this.portTypes[index] & portTypesOutputArtnetAbleMask) != 0x00);
  void setPortTypesOutputArtnetAble(int index, bool value){
    if(index >= portTypesSize) return;

    (value) ? this.portTypes[index] |= portTypesOutputArtnetAbleMask : this.portTypes[index] &= ~portTypesOutputArtnetAbleMask;
  } 

  bool getPortTypesInputArtnetAble(int index) => (index >= portTypesSize) ? false : ((this.portTypes[index] & portTypesInputArtnetAbleMask) != 0x00);
  void setPortTypesInputArtnetAble(int index, bool value){
    if(index >= portTypesSize) return;
    
    (value) ? this.portTypes[index] |= portTypesInputArtnetAbleMask : this.portTypes[index] &= ~portTypesInputArtnetAbleMask;
  } 

  int getPortTypesProtocol(int index) => (index >= portTypesSize) ? 0x00 : (this.portTypes[index] & portTypesProtocolMask);
  void setPortTypesProtocol(int index, int value){
    if(index >= portTypesSize) return;

    //clear value
    this.portTypes[index] &= ~portTypesProtocolMask;
    //set value
    this.portTypes[index] |= (value & portTypesProtocolMask);
  }

  List<int> get goodInput => this.packet.buffer.asUint8List(goodInputIndex, goodInputSize);
  void setGoodInput(int index, int value){
    if(index >= goodInputSize || index < 0){
      return;
    }
    this.packet.setUint8(goodInputIndex + index, value);
  }

  bool getGoodInputDataReceived(int index) => (index >= goodInputSize) ? false : ((this.goodInput[index] & goodInputDataReceivedMask) != 0x00);
  void setGoodInputDataReceived(int index, bool value){
    if(index >= goodInputSize) return;

    (value) ? this.goodInput[index] |= goodInputDataReceivedMask : this.goodInput[index] &= ~goodInputDataReceivedMask;
  } 

  bool getGoodInputIncludesTestPackets1(int index) => (index >= goodInputSize) ? false : ((this.goodInput[index] & goodInputIncludesTestPackets1Mask) != 0x00);
  void setGoodInputIncludesTestPackets1(int index, bool value){
    if(index >= goodInputSize) return;

    (value) ? this.goodInput[index] |= goodInputIncludesTestPackets1Mask : this.goodInput[index] &= ~goodInputIncludesTestPackets1Mask;
  } 

  bool getGoodInputIncludesSIPs(int index) => (index >= goodInputSize) ? false : ((this.goodInput[index] & goodInputIncludesSIPsMask) != 0x00);
  void setGoodInputIncludesSIPs(int index, bool value){
    if(index >= goodInputSize) return;

    (value) ? this.goodInput[index] |= goodInputIncludesSIPsMask : this.goodInput[index] &= ~goodInputIncludesSIPsMask;
  } 

  bool getGoodInputIncludesTestPackets2(int index) => (index >= goodInputSize) ? false : ((this.goodInput[index] & goodInputIncludesTestPackets2Mask) != 0x00);
  void setGoodInputIncludesTestPackets2(int index, bool value){
    if(index >= goodInputSize) return;

    (value) ? this.goodInput[index] |= goodInputIncludesTestPackets2Mask : this.goodInput[index] &= ~goodInputIncludesTestPackets2Mask;
  } 

  bool getGoodInputInputDisable(int index) => (index >= goodInputSize) ? false : ((this.goodInput[index] & goodInputInputDisableMask) != 0x00);
  void setGoodInputInputDisable(int index, bool value){
    if(index >= goodInputSize) return;

    (value) ? this.goodInput[index] |= goodInputInputDisableMask : this.goodInput[index] &= ~goodInputInputDisableMask;
  } 

  bool getGoodInputReceiveErrorDetected(int index) => (index >= goodInputSize) ? false : ((this.goodInput[index] & goodInputReceiveErrorDetectedMask) != 0x00);
  void setGoodInputReceiveErrorDetected(int index, bool value){
    if(index >= goodInputSize) return;

    (value) ? this.goodInput[index] |= goodInputReceiveErrorDetectedMask : this.goodInput[index] &= ~goodInputReceiveErrorDetectedMask;
  } 

  List<int> get goodOutput => this.packet.buffer.asUint8List(goodOutputIndex, goodOutputSize);
  void setGoodOutput(int index, int value){
    if(index >= goodOutputSize || index < 0){
      return;
    }
    this.packet.setUint8(goodOutputIndex + index, value);
  }

  bool getGoodOutputDataTransmiting(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputDataTransmitingMask) != 0x00);
  void setGoodOutputDataTransmiting(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputDataTransmitingMask : this.goodOutput[index] &= ~goodOutputDataTransmitingMask;
  } 

  bool getGoodOutputIncludesTestPackets1(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputIncludesTestPackets1Mask) != 0x00);
  void setGoodOutputIncludesTestPackets1(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputIncludesTestPackets1Mask : this.goodOutput[index] &= ~goodOutputIncludesTestPackets1Mask;
  } 

  bool getGoodOutputIncludesSIPs(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputIncludesSIPsMask) != 0x00);
  void setGoodOutputIncludesSIPs(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputIncludesSIPsMask : this.goodOutput[index] &= ~goodOutputIncludesSIPsMask;
  } 

  bool getGoodOutputIncludesTestPackets2(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputIncludesTestPackets2Mask) != 0x00);
  void setGoodOutputIncludesTestPackets2(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputIncludesTestPackets2Mask : this.goodOutput[index] &= ~goodOutputIncludesTestPackets2Mask;
  } 

  bool getGoodOutputIsMerging(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputIsMergingMask) != 0x00);
  void setGoodOutputIsMerging(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputIsMergingMask : this.goodOutput[index] &= ~goodOutputIsMergingMask;
  } 

  bool getGoodOutputShortDetected(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputShortDetectedMask) != 0x00);
  void setGoodOutputShortDetected(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputShortDetectedMask : this.goodOutput[index] &= ~goodOutputShortDetectedMask;
  } 

  bool getGoodOutputMergeIsLTPDetected(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputMergeIsLTPMask) != 0x00);
  void setGoodOutputMergeIsLTPDetected(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputMergeIsLTPMask : this.goodOutput[index] &= ~goodOutputMergeIsLTPMask;
  } 

  /* TODO make this an int */
  bool getGoodOutputProtocol(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputProtocolMask) != 0x00);
  void setGoodOutputProtocol(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputProtocolMask : this.goodOutput[index] &= ~goodOutputProtocolMask;
  } 

}