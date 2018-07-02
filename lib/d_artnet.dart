library d_artnet;

import 'dart:typed_data';
import 'dart:math';

//globals
const protVer = 14;
const opCodeIndex = 8;

void copyIdtoBuffer(ByteData buffer, int opCode){
  const List<int> id = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00];
  for(var i = 0; i < id.length; i++){
    buffer.setUint8(i, id[i]);
  }
  buffer.setUint16(opCodeIndex, opCode, Endian.little);
}

bool checkArtnetPacket(List<int> packet){
  const List<int> id = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00];
  for(var i = 0; i < id.length; i++){
    if(packet[i] != id[i]){
      return false;
    }
  } 

  return true;
}

int getOpCode(List<int> packet){
  if(packet.length <= opCodeIndex + 1) return -1;
  return packet[opCodeIndex + 1] << 8 | packet[opCodeIndex];
}

abstract class ArtnetPacket {
  static var type;
  static var size;
  static var opCode;

  List<int> get udpPacket;

  String toHexString();
}

int generateUUID32(int seed){
  var rnJesus = new Random(seed);
  int uuid = (rnJesus.nextInt(0xFF) << 24) & 0xFF000000;
  uuid |= (rnJesus.nextInt(0xFF) << 16) & 0x00FF0000;
  uuid |= (rnJesus.nextInt(0xFF) << 8) & 0x0000FF00;
  uuid |= (rnJesus.nextInt(0xFF)) & 0x000000FF;

  return uuid;
}

class ArtnetDataPacket implements ArtnetPacket{
  static const type = "Artnet Data Packet";
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
    String string = "***$type***\n";
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
    String string = "";
    String tempString = "";
    for(var i = 0; i < this.udpPacket.length; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetPollPacket implements ArtnetPacket{
  static const type = "Artnet Poll Packet";
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
    String string = "***$type***\n";
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
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetPollReplyPacket implements ArtnetPacket {
  static const type = "Artnet Poll Reply Packet";
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
  static const swRemoteIndex = swMacroIndex + 1;
  static const spareIndex = swRemoteIndex + 1;
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
  static const netSwitchMask = 0x7F;
  static const subSwitchMask = 0x0F;
  static const ioSwitchMask = 0x0F;
  static const status1IndicatorStateMask = 0xC0;
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
  static const status2IsSquawkingMask = 0x20;
  static const status2ProtocolSwitchableMask = 0x10;
  static const status215BitSupportMask = 0x08;
  static const status2DHCPCapableMask = 0x04;
  static const status2IpIsSetManuallyMask = 0x02;
  static const status2HasWebConfigurationSupportMask = 0x01;

  /* Options */
  static const status1IndicatorStateOptionUnkown = 0x00;
  static const status1IndicatorStateOptionLocate = 0x01;
  static const status1IndicatorStateOptionMute = 0x02;
  static const status1IndicatorStateOptionNormal = 0x03;
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
  set ip(List<int> value){
    for(var i = 0; i < ipAddressSize; i++){
      if(value.length <= i){
        this.packet.setUint8(ipAddressIndex + i, 0);    
      } else {
        this.packet.setUint8(ipAddressIndex + i, value[i]);
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
  set netSwitch(int value) => this.packet.setUint8(netSwitchIndex, value & netSwitchMask);

  int get subSwitch => this.packet.getUint8(subSwitchIndex);
  set subSwitch(int value) => this.packet.setUint8(subSwitchIndex, value & subSwitchMask);

  int get universe => this.netSwitch << 16 | this.subSwitch << 8 | this.swOut[0];
  set unitverse(int value){
    this.netSwitch = (value >> 16);
    this.subSwitch = (value >> 8);
    this.swOut[0] = (value >> 16);
  }

  int get oemHi => this.packet.getUint8(oemHiIndex);
  set oemHi(int value) => this.packet.setUint8(oemHiIndex, value);

  int get oemLo => this.packet.getUint8(oemIndex);
  set oemLo(int value) => this.packet.setUint8(oemIndex, value);

  int get oem => (this.oemHi << 8) & 0xFF00 | this.oemLo & 0xFF;
  set oem(int value) {
    this.oemHi = (value >> 8);  
    this.oemLo = value & 0xFF;
  }

  int get ubeaVersion => this.packet.getUint8(ubeaVersionIndex);
  set ubeaVersion(int value) => this.packet.setUint8(ubeaVersionIndex, value);

  int get status1 => this.packet.getUint8(status1Index);
  set status1(int value) => this.packet.setUint8(status1Index, value);

  int get status1IndicatorState => (this.status1 & status1IndicatorStateMask) >> 6;
  set status1IndicatorState(int value){
    //clear value
    this.status1 &= ~status1IndicatorStateMask;
    //set value
    this.status1 |= ((value << 6) & status1IndicatorStateMask);
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

  String get shortName => String.fromCharCodes(this.packet.buffer.asUint8List(shortNameIndex, shortNameSize));
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

  String get longName => String.fromCharCodes(this.packet.buffer.asUint8List(longNameIndex, longNameSize));
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

  String get nodeReport => String.fromCharCodes(packet.buffer.asUint8List(nodeReportIndex, nodeReportSize));
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

  bool getGoodOutputMergeIsLTP(int index) => (index >= goodOutputSize) ? false : ((this.goodOutput[index] & goodOutputMergeIsLTPMask) != 0x00);
  void setGoodOutputMergeIsLTP(int index, bool value){
    if(index >= goodOutputSize) return;

    (value) ? this.goodOutput[index] |= goodOutputMergeIsLTPMask : this.goodOutput[index] &= ~goodOutputMergeIsLTPMask;
  } 

  /* TODO make this an int */
  int getGoodOutputProtocol(int index) => (index >= goodOutputSize) ? 0x00 : (this.goodOutput[index] & goodOutputProtocolMask);
  void setGoodOutputProtocol(int index, int value){
    if(index >= goodOutputSize) return;

    (value == goodOutputProtocolOptionSacn) ? this.goodOutput[index] |= goodOutputProtocolMask : this.goodOutput[index] &= ~goodOutputProtocolMask;
  } 

  List<int> get swIn => this.packet.buffer.asUint8List(swInIndex, swInSize);
  void setSwIn(int index, int value){
    if(index >= swInSize || index < 0){
      return;
    }
    this.packet.setUint8(swInIndex + index, value & ioSwitchMask);
  }

  List<int> get swOut => this.packet.buffer.asUint8List(swOutIndex, swOutSize);
  void setSwOut(int index, int value){
    if(index >= swOutSize || index < 0){
      return;
    }
    this.packet.setUint8(swOutIndex + index, value & ioSwitchMask);
  }

  int get swVideo => this.packet.getUint8(swVideoIndex);
  set swVideo(int value) => this.packet.setUint8(swVideoIndex, value);

  int get swMacro => this.packet.getUint8(swMacroIndex);
  set swMacro(int value) => this.packet.setUint8(swMacroIndex, value);

  int get swRemote => this.packet.getUint8(swRemoteIndex);
  set swRemote(int value) => this.packet.setUint8(swRemoteIndex, value);

  int get style => this.packet.getUint8(styleIndex);
  set style(int value) => this.packet.setUint8(styleIndex, value);

  int get macHi => this.packet.getUint8(macHiIndex);
  set macHi(int value) => this.packet.setUint8(macHiIndex, value);

  int get mac4 => this.packet.getUint8(mac4Index);
  set mac4(int value) => this.packet.setUint8(mac4Index, value);

  int get mac3 => this.packet.getUint8(mac3Index);
  set mac3(int value) => this.packet.setUint8(mac3Index, value);

  int get mac2 => this.packet.getUint8(mac2Index);
  set mac2(int value) => this.packet.setUint8(mac2Index, value);

  int get mac1 => this.packet.getUint8(mac1Index);
  set mac1(int value) => this.packet.setUint8(mac1Index, value);

  int get macLo => this.packet.getUint8(macLoIndex);
  set macLo(int value) => this.packet.setUint8(macLoIndex, value);

  List<int> get mac => this.packet.buffer.asUint8List(macHiIndex, 6);
  set mac(List<int> value){
    for(var i = 0; i < 6; i++){
      if(value.length <= i){
        this.packet.setUint8(macHiIndex + i, 0);    
      } else {
        this.packet.setUint8(macHiIndex + i, value[i]);
      }
    }
  }

  List<int> get bindIp => this.packet.buffer.asUint8List(bindIpIndex, bindIpSize);
  set bindIp(List<int> value){
    for(var i = 0; i < bindIpSize; i++){
      if(value.length <= i){
        this.packet.setUint8(bindIpIndex + i, 0);    
      } else {
        this.packet.setUint8(bindIpIndex + i, value[i]);
      }
    }
  }

  int get bindIndex => this.packet.getUint8(bindIndexIndex);
  set bindIndex(int value) => this.packet.setUint8(bindIndexIndex, value);

  int get status2 => this.packet.getUint8(status2Index);
  set status2(int value) => this.packet.setUint8(status2Index, value);

  bool get status2IsSquawking => ((this.status2 & status2IsSquawkingMask) != 0x00);
  set status2IsSquawking(bool value) => (value) ? this.status2 |= status2IsSquawkingMask : this.status2 &= ~status2IsSquawkingMask;

  bool get status2ProtocolSwitchable => ((this.status2 & status2ProtocolSwitchableMask) != 0x00);
  set status2ProtocolSwitchable(bool value) => (value) ? this.status2 |= status2ProtocolSwitchableMask : this.status2 &= ~status2ProtocolSwitchableMask;

  bool get status215BitSupport => ((this.status2 & status215BitSupportMask) != 0x00);
  set status215BitSupport(bool value) => (value) ? this.status2 |= status215BitSupportMask : this.status2 &= ~status215BitSupportMask;

  bool get status2DHCPCapable => ((this.status2 & status2DHCPCapableMask) != 0x00);
  set status2DHCPCapable(bool value) => (value) ? this.status2 |= status2DHCPCapableMask : this.status2 &= ~status2DHCPCapableMask;

  bool get status2IpIsSetManually => ((this.status2 & status2IpIsSetManuallyMask) == 0x00);
  set status2IpIsSetManually(bool value) => (value) ? this.status2 &= ~status2IpIsSetManuallyMask : this.status2 |= status2IpIsSetManuallyMask;

  bool get status2HasWebConfigurationSupport => ((this.status2 & status2HasWebConfigurationSupportMask) != 0x00);
  set status2HasWebConfigurationSupport(bool value) => (value) ? this.status2 |= status2HasWebConfigurationSupportMask : this.status2 &= ~status2HasWebConfigurationSupportMask;

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Ip Address: " + this.ip[0].toString() + "." + this.ip[1].toString() + "." + this.ip[2].toString() + "." + this.ip[3].toString() + "\n";
    string += "Port: " + this.port.toString() + "\n";
    string += "Version: " + this.versionInfoH.toString() + "." + this.versionInfoL.toString() + "\n";
    string += "Port-Address (Universe): " + (this.netSwitch << 16 | this.subSwitch << 8 | this.swOut[0]).toString() + "\n";
    string += "*** Net Switch: " + this.netSwitch.toString() + "\n";
    string += "*** Sub Switch: " + this.subSwitch.toString() + "\n";
    string += "*** Input Switch:\n";
    string += "*** *** 0: " + this.swIn[0].toString() + "\n";
    string += "*** *** 1: " + this.swIn[1].toString() + "\n";
    string += "*** *** 2: " + this.swIn[2].toString() + "\n";
    string += "*** *** 3: " + this.swIn[3].toString() + "\n";
    string += "*** Output Switch:\n";
    string += "*** *** 0: " + this.swOut[0].toString() + "\n";
    string += "*** *** 1: " + this.swOut[1].toString() + "\n";
    string += "*** *** 2: " + this.swOut[2].toString() + "\n";
    string += "*** *** 3: " + this.swOut[3].toString() + "\n";
    string += "Oem: 0x" + this.oem.toRadixString(16) + "\n";
    string += "Ubea Version: " + this.ubeaVersion.toString() + "\n";
    string += "Status 1: 0x" + this.status1.toRadixString(16) + "\n";
    string += "*** Indicator State: ";
    switch(this.status1IndicatorState){
      case status1IndicatorStateOptionLocate: string += "Locate Mode\n"; break;
      case status1IndicatorStateOptionMute: string += "Mute Mode\n"; break;
      case status1IndicatorStateOptionNormal: string += "Normal Mode\n"; break;
      default: string += "Unkown Mode\n"; break;
    }
    string += "*** Programming Authority: ";
    switch(this.status1ProgrammingAuthority){
      case status1ProgrammingAuthorityOptionNetwork: string += "All or part of Port-Address programmed by network or web browser\n"; break;
      case status1ProgrammingAuthorityOptionPanel: string += "All Port-Address set by front panel controls.\n"; break;
      default: string += "Port-Address programming authority unknown\n"; break;
    }
    string += "*** Firmware Boot: " + ((this.status1FirmwareBoot == status1FirmwareBootOptionRom) ? "ROM boot" : "Normal boot (from flash)") + "\n";
    string += "*** RDM Capable: " + ((this.status1RdmCapable) ? "Capable" : "Not Capable") + "\n";
    string += "*** UBEA Present: " + ((this.status1UbeaPresent) ? "Present" : "Not Present or Currupt") + "\n";
    string += "ESTA Manufacturer Code: 0x" + this.estaMan.toRadixString(16) + "\n";
    string += "Short Name: " + this.shortName + "\n";
    string += "Long Name: " + this.longName + "\n";
    string += "Node Report: " + this.nodeReport + "\n";
    string += "Number of Ports: " + this.numPorts.toString() + "\n";
    string += "Port Types:\n";
    for(var i = 0; i < portTypesSize; i++){
      string += "*** " + i.toString() + ":\n";
      string += "*** *** Artnet Output: " + ((this.getPortTypesInputArtnetAble(i)) ? "Enabled" : "Disabled") + "\n";
      string += "*** *** Artnet Input: " + ((this.getPortTypesOutputArtnetAble(i)) ? "Enabled" : "Disabled") + "\n";
      string += "*** *** Protocol: ";
      switch(this.getPortTypesProtocol(i)){
        case portTypesProtocolOptionDMX: string += "DMX 512\n"; break;
        case portTypesProtocolOptionDMX: string += "MIDI\n"; break;
        case portTypesProtocolOptionDMX: string += "Avab\n"; break;
        case portTypesProtocolOptionDMX: string += "Colortran CMX\n"; break;
        case portTypesProtocolOptionDMX: string += "ADB 62.5\n"; break;
        case portTypesProtocolOptionDMX: string += "Art-Net\n"; break;
        default: string += "Unkown Protocol\n"; break;
      }
    }
    string += "Good Input:\n";
    for(var i = 0; i < goodInputSize; i++){
      string += "*** " + i.toString() + ":\n";
      string += "*** *** Data Received: " + ((this.getGoodInputDataReceived(i)) ? "True" : "False") + "\n";
      string += "*** *** Channel Includes DMX Test Packets 1: " + ((this.getGoodInputIncludesTestPackets1(i)) ? "True" : "False") + "\n";
      string += "*** *** Channel Includes DMX SIP's: " + ((this.getGoodInputIncludesSIPs(i)) ? "True" : "False") + "\n";
      string += "*** *** Channel Includes DMX Test Packets 2: " + ((this.getGoodInputIncludesTestPackets2(i)) ? "True" : "False") + "\n";
      string += "*** *** Input: " + ((this.getGoodInputInputDisable(i)) ? "Disabled" : "Enabled") + "\n";
      string += "*** *** Receive Errors: " + ((this.getGoodInputReceiveErrorDetected(i)) ? "Detected" : "Not Detected") + "\n";
    }
    string += "Good Ouput:\n";
    for(var i = 0; i < goodOutputSize; i++){
      string += "*** " + i.toString() + ":\n";
      string += "*** *** Data Transmitting: " + ((this.getGoodOutputDataTransmiting(i)) ? "True" : "False") + "\n";
      string += "*** *** Channel Includes DMX Test Packets 1: " + ((this.getGoodOutputIncludesTestPackets1(i)) ? "True" : "False") + "\n";
      string += "*** *** Channel Includes DMX SIP's: " + ((this.getGoodOutputIncludesSIPs(i)) ? "True" : "False") + "\n";
      string += "*** *** Channel Includes DMX Test Packets 2: " + ((this.getGoodOutputIncludesTestPackets2(i)) ? "True" : "False") + "\n";
      string += "*** *** Merge: " + ((this.getGoodOutputIsMerging(i)) ? "Disabled" : "Enabled") + "\n";
      string += "*** *** DMX Short: " + ((this.getGoodOutputShortDetected(i)) ? "Detected" : "Not Detected") + "\n";
      string += "*** *** Merge is LTP: " + ((this.getGoodOutputMergeIsLTP(i)) ? "True" : "False") + "\n";
      string += "*** *** Protocol: " + ((this.getGoodOutputProtocol(i) == goodOutputProtocolOptionSacn) ? "sACN" : "Art-Net") + "\n";
    }
    string += "Video Switch: 0x" + this.swVideo.toRadixString(16) + "\n";
    string += "Macro Switch: 0x" + this.swMacro.toRadixString(16) + "\n";
    string += "Remote Switch: 0x" + this.swRemote.toRadixString(16) + "\n";
    string += "Mac: ";
    string += this.macHi.toRadixString(16) + ".";
    string += this.mac4.toRadixString(16) + ".";
    string += this.mac3.toRadixString(16) + ".";
    string += this.mac2.toRadixString(16) + ".";
    string += this.mac1.toRadixString(16) + ".";
    string += this.macLo.toRadixString(16) + "\n";
    string += "Bind Ip: " + this.bindIp[0].toString() + "." + this.bindIp[1].toString() + "." + this.bindIp[2].toString() + "." + this.bindIp[3].toString() + "\n";
    string += "Bind Index: " + this.bindIndex.toString() + "\n";
    string += "Status 2: 0x" + this.status2.toRadixString(16) + "\n";
    string += "*** Node is Squawking: " + ((this.status2IsSquawking) ? "True" : "False") + "\n";
    string += "*** Node is Protocol Switchable (Art-Net - sACN): " + ((this.status2ProtocolSwitchable) ? "True" : "False") + "\n";
    string += "*** Node Supports 15 Bit Port-Address (Art-Net 3 or 4): " + ((this.status215BitSupport) ? "True" : "False") + "\n";
    string += "*** Node Supports DHCP: " + ((this.status2DHCPCapable) ? "True" : "False") + "\n";
    string += "*** Node's ip is set " + ((this.status2IpIsSetManually) ? "manually" : "by DHCP") + "\n";
    string += "*** Node Supports Web Configurations: " + ((this.status2HasWebConfigurationSupport) ? "True" : "False") + "\n";
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetAddressPacket implements ArtnetPacket{
  static const type = "Artnet Address Packet";
  static const size = 107;
  static const opCode = 0x6000;

  /* Sizes */
  static const shortNameSize = 18;
  static const longNameSize = 64;
  static const swInSize = 4;
  static const swOutSize = 4;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const netSwitchIndex = protVerLoIndex + 1;
  static const bindIndexIndex = netSwitchIndex + 1;
  static const shortNameIndex = bindIndexIndex + 1;
  static const longNameIndex = shortNameIndex + shortNameSize;
  static const swInIndex = longNameIndex + longNameSize;
  static const swOutIndex = swInIndex + swInSize;
  static const subSwitchIndex = swOutIndex + swOutSize;
  static const swVideoIndex = subSwitchIndex + 1;
  static const commandIndex = swVideoIndex + 1;

  /* Masks */
  static const programSwitchMask = 0x80;
  static const netSwitchMask = 0x7F;
  static const subSwitchMask = 0x0F;
  static const ioSwitchMask = 0x0F;

  /* Options */
  static const commandOptionNone = 0x00;
  static const commandOptionCancelMerge = 0x01;
  static const commandOptionLedNormal = 0x02;
  static const commandOptionLedMute = 0x03;
  static const commandOptionLedLocate = 0x04;
  static const commandOptionResetRxFlags = 0x05;
  static const commandOptionMergeLtp0 = 0x10;
  static const commandOptionMergeLtp1 = 0x11;
  static const commandOptionMergeLtp2 = 0x12;
  static const commandOptionMergeLtp3 = 0x13;
  static const commandOptionMergeHtp0 = 0x50;
  static const commandOptionMergeHtp1 = 0x51;
  static const commandOptionMergeHtp2 = 0x52;
  static const commandOptionMergeHtp3 = 0x53;
  static const commandOptionArtNetSel0 = 0x60;
  static const commandOptionArtNetSel1 = 0x61;
  static const commandOptionArtNetSel2 = 0x62;
  static const commandOptionArtNetSel3 = 0x63;
  static const commandOptionAcnSel0 = 0x70;
  static const commandOptionAcnSel1 = 0x71;
  static const commandOptionAcnSel2 = 0x72;
  static const commandOptionAcnSel3 = 0x73;
  static const commandOptionClearOp0 = 0x90;
  static const commandOptionClearOp1 = 0x91;
  static const commandOptionClearOp2 = 0x92;
  static const commandOptionClearOp3 = 0x93;


  ByteData packet;

  ArtnetAddressPacket([List<int> packet]){
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

  int get netSwitch => this.packet.getUint8(netSwitchIndex);
  set netSwitch(int value) => this.packet.setUint8(netSwitchIndex, value);

  bool get programNetSwitchEnable => (this.netSwitch & programSwitchMask) != 0x00;
  set programNetSwitchEnable(bool value) => (value) ? this.netSwitch |= programSwitchMask : this.netSwitch &= ~programSwitchMask; 

  int get subSwitch => this.packet.getUint8(subSwitchIndex);
  set subSwitch(int value) => this.packet.setUint8(subSwitchIndex, value);

  bool get programSubSwitchEnable => (this.subSwitch & programSwitchMask) != 0x00;
  set programSubSwitchEnable(bool value) => (value) ? this.subSwitch |= programSwitchMask : this.subSwitch &= ~programSwitchMask; 

  List<int> get swIn => this.packet.buffer.asUint8List(swInIndex, swInSize);
  void setSwIn(int index, int value){
    if(index >= swInSize || index < 0){
      return;
    }
    this.packet.setUint8(swInIndex + index, value & ioSwitchMask);
  }

  bool getProgramSwInEnable(int index){
    if(index >= swInSize || index < 0){
      return false;
    }

    return ((this.swIn[index] & programSwitchMask) != 0x00);
  }
  void setProgramSwInEnable(int index, bool value){
    if(index >= swInSize || index < 0){
      return;
    }

    (value) ? this.swIn[index] |= programSwitchMask : this.swIn[index] &= ~programSwitchMask;
  }

  List<int> get swOut => this.packet.buffer.asUint8List(swOutIndex, swOutSize);
  void setSwOut(int index, int value){
    if(index >= swInSize || index < 0){
      return;
    }
    this.packet.setUint8(swOutIndex + index, value & ioSwitchMask);
  }

  bool getProgramSwOutEnable(int index){
    if(index >= swOutSize || index < 0){
      return false;
    }

    return ((this.swOut[index] & programSwitchMask) != 0x00);
  }
  void setProgramSwOutEnable(int index, bool value){
    if(index >= swOutSize || index < 0){
      return;
    }

    (value) ? this.swOut[index] |= programSwitchMask : this.swOut[index] &= ~programSwitchMask;
  }


  int get universe => (this.netSwitch << 16 | this.subSwitch << 8 | this.swOut[0]);
  set universe(int value){
    this.netSwitch = value >> 16 & netSwitchMask;
    this.subSwitch = value >> 8 & subSwitchMask;
    this.swOut[0] = value & ioSwitchMask;
  }

  bool get programUniverseEnable => (this.programNetSwitchEnable || this.programSubSwitchEnable || this.getProgramSwOutEnable(0));
  set programUniverseEnable(bool value){
    this.programNetSwitchEnable = value;
    this.programSubSwitchEnable = value;
    this.setProgramSwOutEnable(0, value);
  }

  String get shortName => String.fromCharCodes(this.packet.buffer.asUint8List(shortNameIndex, shortNameSize));
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

  String get longName => String.fromCharCodes(this.packet.buffer.asUint8List(longNameIndex, longNameSize));
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

  int get swVideo => this.packet.getUint8(swVideoIndex);
  set swVideo(int value) => this.packet.setUint8(swVideoIndex, value);

  int get command => this.packet.getUint8(commandIndex);
  set command(int value) => this.packet.setUint8(commandIndex, value);


  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Port-Address (Universe): " + (this.netSwitch << 16 | this.subSwitch << 8 | this.swOut[0]).toString() + " " + ((this.programUniverseEnable) ? "Set to Program" : "") + "\n";
    string += "*** Net Switch: " + (this.netSwitch & netSwitchMask).toString() + " " + ((this.programNetSwitchEnable) ? "Set to Program" : "") + "\n";
    string += "*** Sub Switch: " + (this.netSwitch & subSwitchMask).toString() + " " + ((this.programSubSwitchEnable) ? "Set to Program" : "") + "\n";
    string += "*** Input Switch:\n";
    string += "*** *** 0: " + (this.swIn[0] & ioSwitchMask).toString() + " " + ((this.getProgramSwInEnable(0)) ? "Set to Program" : "") + "\n";
    string += "*** *** 1: " + (this.swIn[1] & ioSwitchMask).toString() + " " + ((this.getProgramSwInEnable(1)) ? "Set to Program" : "") + "\n";
    string += "*** *** 2: " + (this.swIn[2] & ioSwitchMask).toString() + " " + ((this.getProgramSwInEnable(2)) ? "Set to Program" : "") + "\n";
    string += "*** *** 3: " + (this.swIn[3] & ioSwitchMask).toString() + " " + ((this.getProgramSwInEnable(3)) ? "Set to Program" : "") + "\n";
    string += "*** Output Switch:\n";
    string += "*** *** 0: " + (this.swOut[0] & ioSwitchMask).toString() + " " + ((this.getProgramSwOutEnable(0)) ? "Set to Program" : "") + "\n";
    string += "*** *** 1: " + (this.swOut[0] & ioSwitchMask).toString() + " " + ((this.getProgramSwOutEnable(1)) ? "Set to Program" : "") + "\n";
    string += "*** *** 2: " + (this.swOut[0] & ioSwitchMask).toString() + " " + ((this.getProgramSwOutEnable(2)) ? "Set to Program" : "") + "\n";
    string += "*** *** 3: " + (this.swOut[0] & ioSwitchMask).toString() + " " + ((this.getProgramSwOutEnable(3)) ? "Set to Program" : "") + "\n";
    string += "Short Name: " + this.shortName + "\n";
    string += "Long Name: " + this.longName + "\n";
    string += "Video Switch: " + this.swVideo.toString() + "\n";
    string += "Command: ";
    switch(this.command){
      case commandOptionNone: string += "No Command\n"; break;
      case commandOptionCancelMerge: string += "Cancel Merge\n"; break;
      case commandOptionLedNormal: string += "Set Indicator Mode to Normal\n"; break;
      case commandOptionLedMute: string += "Set Indicator Mode to Mute\n"; break;
      case commandOptionLedLocate: string += "Set Indicator Mode to Locate\n"; break;
      case commandOptionResetRxFlags: string += "Reset Rx Flags\n"; break;
      case commandOptionMergeLtp0: string += "Set Port 0 to Merge LTP Mode\n"; break;
      case commandOptionMergeLtp1: string += "Set Port 1 to Merge LTP Mode\n"; break;
      case commandOptionMergeLtp2: string += "Set Port 2 to Merge LTP Mode\n"; break;
      case commandOptionMergeLtp3: string += "Set Port 3 to Merge LTP Mode\n"; break;
      case commandOptionMergeHtp0: string += "Set Port 0 to Merge HTP Mode\n"; break;
      case commandOptionMergeHtp1: string += "Set Port 1 to Merge HTP Mode\n"; break;
      case commandOptionMergeHtp2: string += "Set Port 2 to Merge HTP Mode\n"; break;
      case commandOptionMergeHtp3: string += "Set Port 3 to Merge HTP Mode\n"; break;
      case commandOptionArtNetSel0: string += "Set Port 0 to Output DMX and RDM from Art-Net\n"; break;
      case commandOptionArtNetSel1: string += "Set Port 1 to Output DMX and RDM from Art-Net\n"; break;
      case commandOptionArtNetSel2: string += "Set Port 2 to Output DMX and RDM from Art-Net\n"; break;
      case commandOptionArtNetSel3: string += "Set Port 3 to Output DMX and RDM from Art-Net\n"; break;
      case commandOptionAcnSel0: string += "Set Port 0 to Output DMX from sACN and RDM from Art-Net\n"; break;
      case commandOptionAcnSel1: string += "Set Port 1 to Output DMX from sACN and RDM from Art-Net\n"; break;
      case commandOptionAcnSel2: string += "Set Port 2 to Output DMX from sACN and RDM from Art-Net\n"; break;
      case commandOptionAcnSel3: string += "Set Port 3 to Output DMX from sACN and RDM from Art-Net\n"; break;
      case commandOptionClearOp0: string += "Blackout Port 0 DMX Buffer\n"; break;
      case commandOptionClearOp1: string += "Blackout Port 1 DMX Buffer\n"; break;
      case commandOptionClearOp2: string += "Blackout Port 2 DMX Buffer\n"; break;
      case commandOptionClearOp3: string += "Blackout Port 3 DMX Buffer\n"; break;
      case 0x6969: string += "SOC was here\n"; break;
      default: string += "Invalid Command\n"; break;
    }
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetIpProgPacket implements ArtnetPacket{
  static const type = "Artnet Ip Prog Packet";
  static const size = 34;
  static const opCode = 0xF800;

  /* Sizes */
  static const progIpSize = 4;
  static const progSubnetSize = 4;
  static const progPortSize = 2;
  static const spareSize = 8;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const filler1Index = protVerLoIndex + 1;
  static const filler2Index = filler1Index + 1;
  static const commandIndex = filler2Index + 1;
  static const filler4Index = commandIndex + 1; //because Art-Net 4 can't count
  static const progIpHiIndex = filler4Index + 1;
  static const progIp2Index = progIpHiIndex + 1;
  static const progIp1Index = progIp2Index + 1;
  static const progIpLoIndex = progIp1Index + 1;
  static const progSmHiIndex = progIpLoIndex + 1;
  static const progSm2Index = progSmHiIndex + 1;
  static const progSm1Index = progSm2Index + 1;
  static const progSmLoIndex = progSm1Index + 1;
  static const progPortHiIndex = progSmLoIndex + 1; //depreciated
  static const progPortLoIndex = progPortHiIndex + 1;
  static const spareIndex = progPortLoIndex + 1;

  /* Masks */
  static const commandProgrammingEnableMask = 0x80;
  static const commandDHCPEnableMask = 0x40;
  static const commandResetIpSubnetPortToDefaultMask = 0x08;
  static const commandProgramIpMask = 0x04;
  static const commandProgramSubnetMask = 0x02;
  static const commandProgramPortMask = 0x01;

  ByteData packet;

  ArtnetIpProgPacket([List<int> packet]){
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

  int get command => this.packet.getUint8(commandIndex);
  set command(int value) => this.packet.setUint8(commandIndex, value);

  bool get commandProgrammingEnable => ((this.command & commandProgrammingEnableMask) != 0x00);
  set commandProgrammingEnable(bool value) => (value) ? this.command |= commandProgrammingEnableMask : this.command &= ~commandProgrammingEnableMask;

  bool get commandDHCPEnable => ((this.command & commandDHCPEnableMask) != 0x00);
  set commandDHCPEnable(bool value) => (value) ? this.command |= commandDHCPEnableMask : this.command &= ~commandDHCPEnableMask;

  bool get commandResetIpSubnetPortToDefault => ((this.command & commandResetIpSubnetPortToDefaultMask) != 0x00);
  set commandResetIpSubnetPortToDefault(bool value) => (value) ? this.command |= commandResetIpSubnetPortToDefaultMask : this.command &= ~commandResetIpSubnetPortToDefaultMask;

  bool get commandProgramIp => ((this.command & commandProgramIpMask) != 0x00);
  set commandProgramIp(bool value) => (value) ? this.command |= commandProgramIpMask : this.command &= ~commandProgramIpMask;

  bool get commandProgramSubnet => ((this.command & commandProgramSubnetMask) != 0x00);
  set commandProgramSubnet(bool value) => (value) ? this.command |= commandProgramSubnetMask : this.command &= ~commandProgramSubnetMask;

  bool get commandProgramPort => ((this.command & commandProgramPortMask) != 0x00);
  set commandProgramPort(bool value) => (value) ? this.command |= commandProgramPortMask : this.command &= ~commandProgramPortMask;

  int get progIpHi => this.packet.getUint8(progIpHiIndex);
  set progIpHi(int value) => this.packet.setUint8(progIpHiIndex, value);

  int get progIp2 => this.packet.getUint8(progIp2Index);
  set progIp2(int value) => this.packet.setUint8(progIp2Index, value);

  int get progIp1 => this.packet.getUint8(progIp1Index);
  set progIp1(int value) => this.packet.setUint8(progIp1Index, value);

  int get progIpLo => this.packet.getUint8(progIpLoIndex);
  set progIpLo(int value) => this.packet.setUint8(progIpLoIndex, value);

  List<int> get progIp => this.packet.buffer.asUint8List(progIpHiIndex, progIpSize);
  set ip(List<int> value){
    for(var i = 0; i < progIpSize; i++){
      if(value.length <= i){
        this.packet.setUint8(progIpHiIndex + i, 0);    
      } else {
        this.packet.setUint8(progIpHiIndex + i, value[i]);
      }
    }
  }

  int get progSmHi => this.packet.getUint8(progSmHiIndex);
  set progSmHi(int value) => this.packet.setUint8(progSmHiIndex, value);

  int get progSm2 => this.packet.getUint8(progSm2Index);
  set progSm2(int value) => this.packet.setUint8(progSm2Index, value);

  int get progSm1 => this.packet.getUint8(progSm1Index);
  set progSm1(int value) => this.packet.setUint8(progSm1Index, value);

  int get progSmLo => this.packet.getUint8(progSmLoIndex);
  set progSmLo(int value) => this.packet.setUint8(progSmLoIndex, value);

  List<int> get progSm => this.packet.buffer.asUint8List(progSmHiIndex, progSubnetSize);
  set progSm(List<int> value){
    for(var i = 0; i < progSubnetSize; i++){
      if(value.length <= i){
        this.packet.setUint8(progSmHiIndex + i, 0);    
      } else {
        this.packet.setUint8(progSmHiIndex + i, value[i]);
      }
    }
  }

  int get progPortHi => this.packet.getUint8(progPortHiIndex);
  set progPortHi(int value) => this.packet.setUint8(progPortHiIndex, value);

  int get progPortLo => this.packet.getUint8(progPortLoIndex);
  set progPortLo(int value) => this.packet.setUint8(progPortLoIndex, value);

  int get progPort => this.packet.getUint16(progPortHiIndex);
  set progPort(int value) =>this.packet.setUint16(progPortHiIndex, value);

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Command: \n";
    string += "*** Programming: " + ((this.commandProgrammingEnable) ? "Enabled" : "Disabled") + "\n";
    string += "*** DHCP: " + ((this.commandDHCPEnable) ? "Enabled" : "Disabled") + "\n";
    string += "*** Node is set to " + ((this.commandResetIpSubnetPortToDefault) ? "reset " : "NOT reset ") + "ip, netmask and port back to default\n";
    string += "*** Node is set to " + ((this.commandProgramIp) ? "program " : "NOT program ") + " the ip\n";
    string += "*** Node is set to " + ((this.commandProgramSubnet) ? "program " : "NOT program ") + " the subnet\n";
    string += "*** Node is set to " + ((this.commandProgramPort) ? "program " : "NOT program ") + " the port\n";
    string += "Ip to be Programmed: " + this.progIp[0].toString() + "." + this.progIp[1].toString() + "." + this.progIp[2].toString() + "." + this.progIp[3].toString() + "\n";
    string += "Subnet to be Programmed: " + this.progSm[0].toString() + "." + this.progSm[1].toString() + "." + this.progSm[2].toString() + "." + this.progSm[3].toString() + "\n";
    string += "Port to be Programmed: " + this.progPort.toString() + "\n";
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetIpProgReplyPacket implements ArtnetPacket{
  static const type = "Artnet Ip Prog Reply Packet";
  static const size = 34;
  static const opCode = 0xF900;

  /* Sizes */
  static const progIpSize = 4;
  static const progSubnetSize = 4;
  static const progPortSize = 2;
  static const spareSize = 7;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const filler1Index = protVerLoIndex + 1;
  static const filler2Index = filler1Index + 1;
  static const filler3Index = filler2Index + 1;
  static const filler4Index = filler3Index + 1;
  static const progIpHiIndex = filler4Index + 1;
  static const progIp2Index = progIpHiIndex + 1;
  static const progIp1Index = progIp2Index + 1;
  static const progIpLoIndex = progIp1Index + 1;
  static const progSmHiIndex = progIpLoIndex + 1;
  static const progSm2Index = progSmHiIndex + 1;
  static const progSm1Index = progSm2Index + 1;
  static const progSmLoIndex = progSm1Index + 1;
  static const progPortHiIndex = progSmLoIndex + 1; //depreciated
  static const progPortLoIndex = progPortHiIndex + 1;
  static const statusIndex = progPortLoIndex + 1;

  /* Masks */
  static const statusDHCPEnabledMask = 0x40;

  ByteData packet;

  ArtnetIpProgReplyPacket([List<int> packet]){
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

  int get progIpHi => this.packet.getUint8(progIpHiIndex);
  set progIpHi(int value) => this.packet.setUint8(progIpHiIndex, value);

  int get progIp2 => this.packet.getUint8(progIp2Index);
  set progIp2(int value) => this.packet.setUint8(progIp2Index, value);

  int get progIp1 => this.packet.getUint8(progIp1Index);
  set progIp1(int value) => this.packet.setUint8(progIp1Index, value);

  int get progIpLo => this.packet.getUint8(progIpLoIndex);
  set progIpLo(int value) => this.packet.setUint8(progIpLoIndex, value);

  List<int> get progIp => this.packet.buffer.asUint8List(progIpHiIndex, progIpSize);
  set ip(List<int> value){
    for(var i = 0; i < progIpSize; i++){
      if(value.length <= i){
        this.packet.setUint8(progIpHiIndex + i, 0);    
      } else {
        this.packet.setUint8(progIpHiIndex + i, value[i]);
      }
    }
  }

  int get progSmHi => this.packet.getUint8(progSmHiIndex);
  set progSmHi(int value) => this.packet.setUint8(progSmHiIndex, value);

  int get progSm2 => this.packet.getUint8(progSm2Index);
  set progSm2(int value) => this.packet.setUint8(progSm2Index, value);

  int get progSm1 => this.packet.getUint8(progSm1Index);
  set progSm1(int value) => this.packet.setUint8(progSm1Index, value);

  int get progSmLo => this.packet.getUint8(progSmLoIndex);
  set progSmLo(int value) => this.packet.setUint8(progSmLoIndex, value);

  List<int> get progSm => this.packet.buffer.asUint8List(progSmHiIndex, progSubnetSize);
  set progSm(List<int> value){
    for(var i = 0; i < progSubnetSize; i++){
      if(value.length <= i){
        this.packet.setUint8(progSmHiIndex + i, 0);    
      } else {
        this.packet.setUint8(progSmHiIndex + i, value[i]);
      }
    }
  }

  int get progPortHi => this.packet.getUint8(progPortHiIndex);
  set progPortHi(int value) => this.packet.setUint8(progPortHiIndex, value);

  int get progPortLo => this.packet.getUint8(progPortLoIndex);
  set progPortLo(int value) => this.packet.setUint8(progPortLoIndex, value);

  int get progPort => this.packet.getUint16(progPortHiIndex);
  set progPort(int value) =>this.packet.setUint16(progPortHiIndex, value);

  int get status => this.packet.getUint8(statusIndex);
  set status(int value) => this.packet.setUint8(statusIndex, value);

  bool get dhcpEnabled => ((this.status & statusDHCPEnabledMask) != 0x00);
  set dhcpEnabled(bool value) => (value) ? this.status |= statusDHCPEnabledMask : this.status &= ~statusDHCPEnabledMask;

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Node Ip: " + this.progIp[0].toString() + "." + this.progIp[1].toString() + "." + this.progIp[2].toString() + "." + this.progIp[3].toString() + "\n";
    string += "Node Subnet: " + this.progSm[0].toString() + "." + this.progSm[1].toString() + "." + this.progSm[2].toString() + "." + this.progSm[3].toString() + "\n";
    string += "Node Port: " + this.progPort.toString() + "\n";
    string += "Node Status: 0x" + this.status.toString() + "\n";
    string += "*** DHCP Enable: " + ((this.dhcpEnabled) ? "Enabled" : "Disabled") + "\n";
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetCommandPacket implements ArtnetPacket{
  static const type = "Artnet Command Packet";
  static const size = 16;
  static const opCode = 0x2400;

  /* Sizes */
  static const defaultDataLength = 512;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const estaManHiIndex = protVerLoIndex + 1;
  static const estaManLoIndex = estaManHiIndex + 1;
  static const lengthHiIndex = estaManLoIndex + 1;
  static const lengthLoIndex = lengthHiIndex + 1;
  static const dataIndex = lengthLoIndex + 1;


  ByteData packet;

  ArtnetCommandPacket([List<int> packet, int dataLength = defaultDataLength]){
    this.packet = new ByteData(size + dataLength);
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

    //set size
    this.dataLength = dataLength;
  }

  int get protVerHi => this.packet.getUint8(protVerHiIndex);
  set protVerHi(int value) => this.packet.setUint8(protVerHiIndex, value);

  int get protVerLo => this.packet.getUint8(protVerLoIndex);
  set protVerLo(int value) => this.packet.setUint8(protVerLoIndex, value);

  int get protVersion => this.packet.getUint16(protVerHiIndex);
  set protVersion(int value) => this.packet.setUint16(protVerHiIndex, value);

  int get estaManLo => this.packet.getUint8(estaManLoIndex);
  set estaManLo(int value) => this.packet.setUint8(estaManLoIndex, value);

  int get estaManHi => this.packet.getUint8(estaManHiIndex);
  set estaManHi(int value) => this.packet.setUint8(estaManHiIndex, value);

  int get estaMan => this.estaManHi << 8 | this.estaManLo;
  set estaMan(int value){
    this.estaManHi = value >> 8;
    this.estaManLo = value & 0xFF;
  }

  int get lengthHi => this.packet.getUint8(lengthHiIndex);
  set lengthHi(int value) => this.packet.setUint8(lengthHiIndex, value);

  int get lengthLo => this.packet.getUint8(lengthLoIndex);
  set lengthLo(int value) => this.packet.setUint8(lengthLoIndex, value);

  int get dataLength => this.packet.getUint16(lengthHiIndex);
  set dataLength(int value){
    if(value > defaultDataLength || value < 0){
      return;
    }

    this.packet.setUint16(lengthHiIndex, value);
  }

  List<int> get data => this.packet.buffer.asUint8List(dataIndex, this.dataLength);
  set data(List<int> value){
    for(var i = 0; i < this.dataLength; i++){
      if(value.length <= i){
        return;
      }
      this.data[i] = value[i];
    }
  }

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "ESTA Manufacturer Code: 0x" + this.estaMan.toRadixString(16) + "\n";
    string += "Data Length: " + this.dataLength.toString() + "\n";
    string += "Data:";
    for(var i = 0; i < this.dataLength; i++){
      if((i % 16) == 0){
        string +="\n";
      }
      String tempString = this.data[i].toRadixString(16);
      if(tempString.length < 2) tempString = "0" + tempString;
      while(tempString.length < 3){
        tempString += " ";
      }
      string += tempString;
    }
    string += "\n***********************************************\n";
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size + dataLength; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetSyncPacket implements ArtnetPacket{
  static const type = "Artnet Sync Packet";
  static const size = 14;
  static const opCode = 0x5200;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const aux1Index = protVerLoIndex + 1;
  static const aux2Index = aux1Index + 1;

  ByteData packet;

  ArtnetSyncPacket([List<int> packet]){
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

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetFirmwareMasterPacket implements ArtnetPacket{
  static const type = "Artnet Firmware Master Packet";
  static const size = 552;
  static const opCode = 0xF200;

  /* Sizes */
  static const spareSize = 20;
  static const dataSize = 512;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const filler1Index = protVerLoIndex + 1;
  static const filler2Index = filler1Index + 1;
  static const blockTypeIndex = filler2Index + 1;
  static const blockIdIndex = blockTypeIndex + 1;
  static const firmwareLength3Index = blockIdIndex + 1;
  static const firmwareLength2Index = firmwareLength3Index + 1;
  static const firmwareLength1Index = firmwareLength2Index + 1;
  static const firmwareLength0Index = firmwareLength1Index + 1;
  static const spareIndex = firmwareLength0Index + 1;
  static const dataIndex = spareIndex + spareSize;

  /* Options */
  static const blockTypeOptionFirmFirst = 0x00;
  static const blockTypeOptionFirmCont = 0x01;
  static const blockTypeOptionFirmLast = 0x02;
  static const blockTypeOptionUbeaFirst = 0x03;
  static const blockTypeOptionUbeaCont = 0x04;
  static const blockTypeOptionUbeaLast = 0x05;

  ByteData packet;

  ArtnetFirmwareMasterPacket([List<int> packet]){
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

  int get blockType => this.packet.getUint8(blockTypeIndex);
  set blockType(int value) => this.packet.setUint8(blockTypeIndex, value);

  int get blockId => this.packet.getUint8(blockIdIndex);
  set blockId(int value) => this.packet.setUint8(blockIdIndex, value);

  int get firmwareLength3 => this.packet.getUint8(firmwareLength3Index);
  set firmwareLength3(int value) => this.packet.setUint8(firmwareLength3Index, value);

  int get firmwareLength2 => this.packet.getUint8(firmwareLength2Index);
  set firmwareLength2(int value) => this.packet.setUint8(firmwareLength2Index, value);

  int get firmwareLength1 => this.packet.getUint8(firmwareLength1Index);
  set firmwareLength1(int value) => this.packet.setUint8(firmwareLength1Index, value);

  int get firmwareLength0 => this.packet.getUint8(firmwareLength0Index);
  set firmwareLength0(int value) => this.packet.setUint8(firmwareLength0Index, value);

  int get firmwareLength => this.packet.getUint64(firmwareLength3Index);
  set firmwareLength(int value) => this.packet.setUint64(firmwareLength3Index, value);

  List<int> get data => this.packet.buffer.asUint8List(dataIndex, dataSize);
  set data(List<int> value){
    for(var i = 0; i < dataSize; i++){
      if(value.length <= i){
        return;
      }
      this.data[i] = value[i];
    }
  }

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Block Type: ";
    switch(this.blockType){
      case blockTypeOptionFirmFirst: string += "First Firmware Block\n"; break;
      case blockTypeOptionFirmFirst: string += "Firmware Block " + this.blockId.toString() + "\n"; break;
      case blockTypeOptionFirmFirst: string += "Last Firmware Block\n"; break;
      case blockTypeOptionFirmFirst: string += "First UBEA Block\n"; break;
      case blockTypeOptionFirmFirst: string += "UBEA Block " + this.blockId.toString() + "\n"; break;
      case blockTypeOptionFirmFirst: string += "Last UBEA Block\n"; break;
      default: string += "Unkown Type\n"; break;
    }
    string += "Block Id: " + this.blockId.toString() + "\n";
    string += "Firmware Length (words - Int16): " + this.firmwareLength.toString() + "\n";
    string += "Data:";
    for(var i = 0; i < dataSize; i++){
      if((i % 16) == 0){
        string +="\n";
      }
      String tempString = this.data[i].toRadixString(16);
      if(tempString.length < 2) tempString = "0" + tempString;
      while(tempString.length < 3){
        tempString += " ";
      }
      string += tempString;
    }
    string += "\n***********************************************\n";
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetFirmwareReplyPacket implements ArtnetPacket{
  static const type = "Artnet Firmware Reply Packet";
  static const size = 36;
  static const opCode = 0xF300;

  /* Sizes */
  static const spareSize = 21;

  /* Indexes */
  static const protVerHiIndex = opCodeIndex + 2;
  static const protVerLoIndex = protVerHiIndex + 1;
  static const filler1Index = protVerLoIndex + 1;
  static const filler2Index = filler1Index + 1;
  static const blockTypeIndex = filler2Index + 1;
  static const spareIndex = blockTypeIndex + 1;

  /* Options */
  static const blockTypeOptionFirmBlockGood = 0x00;
  static const blockTypeOptionFirmAllGood = 0x01;
  static const blockTypeOptionFirmFail = 0xFF;

  ByteData packet;

  ArtnetFirmwareReplyPacket([List<int> packet]){
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

  int get blockType => this.packet.getUint8(blockTypeIndex);
  set blockType(int value) => this.packet.setUint8(blockTypeIndex, value);

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  @override
  String toString() {
    String string = "***$type***\n";
    string += "Id: " + String.fromCharCodes(this.packet.buffer.asUint8List(0, 8)) + "\n";
    string += "Opcode: 0x" + this.packet.getUint16(opCodeIndex).toRadixString(16) + "\n";
    string += "Protocol Version: " + this.protVersion.toString() + "\n";
    string += "Block Type: ";
    switch(this.blockType){
      case blockTypeOptionFirmBlockGood: string += "Last block received successfully\n"; break;
      case blockTypeOptionFirmAllGood: string += "All firmware blocks received successfully\n"; break;
      case blockTypeOptionFirmFail: string += "Firmware block failure\n"; break;
      default: string += "Unkown Type\n"; break;
    }
    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}

class ArtnetBeepBeepPacket implements ArtnetPacket{
  static const type = "Beep Beep";
  static const size = 15;
  static const opCode = 0x6996;

  /* Indexes */
  static const uuidIndex = opCodeIndex + 3;

  ByteData packet;

  ArtnetBeepBeepPacket([int uuid, List<int> packet]){
    this.packet = new ByteData(size);
    if(packet != null){
      for(var i = 0; i < size; i++){
        this.packet.setUint8(i, packet[i]);
      }
      return;
    }

    this.uuid = (uuid == null) ? generateUUID32(3) : uuid;

    //set id
    copyIdtoBuffer(this.packet, opCode);
  }

  int get uuid => this.packet.getUint32(uuidIndex);
  set uuid(int value) => this.packet.setUint32(uuidIndex, value);

  List<int> get udpPacket => this.packet.buffer.asUint8List();

  String toString() {
    String string = "***$type***\n";
    string += "UUID: 0x" + this.uuid.toRadixString(16) + "\n";

    return string;
  }

  String toHexString(){
    String string = "";
    String tempString = "";
    for(var i = 0; i < size; i++){
      tempString = this.udpPacket[i].toRadixString(16).toUpperCase();
      if(tempString.length < 2) tempString = "0" + tempString;
      string += tempString;
    }
    return string;
  }

}