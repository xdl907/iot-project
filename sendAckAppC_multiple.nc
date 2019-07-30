/**
 *  Configuration file for wiring of sendAckC module to other common 
 *  components needed for proper functioning
 *
 *  @author Luca Pietro Borsani
 */

#include "sendAck.h"

configuration sendAckAppC {}

implementation {

  components MainC, sendAckC as App;
  components new AMSenderC(ALERTMSG) as AlertMsgSender;
  components new AMSenderC(TRUCKMSG) as TruckMsgSender;
  components new AMSenderC(MOVEMSG) as MoveMsgSender;
  components new AMReceiverC(ALERTMSG) as AlertMsgReceiver;
  components new AMReceiverC(TRUCKMSG) as TruckMsgReceiver;
  components new AMReceiverC(MOVEMSG) as MoveMsgReceiver;
  components ActiveMessageC;
  components new TimerMilliC();
  components new FakeSensorC();
  components RandomC;

  //Boot interface
  App.Boot -> MainC.Boot;

  //Send and Receive interfaces
  App.ReceiveAlert -> AlertMsgReceiver;
  App.ReceiveTruck -> TruckMsgReceiver;
  App.ReceiveMove -> MoveMsgReceiver;
  App.SendAlert -> AlertMsgSender;
  App.SendTruck -> TruckMsgSender;
  App.SendMove -> MoveMsgSender;
  //App.AMSend -> AMSenderC;

  //Radio Control
  App.SplitControl -> ActiveMessageC;

  //Interfaces to access package fields
  App.AMPacket -> AMSenderC;
  App.Packet -> AMSenderC;
  App.PacketAcknowledgements->ActiveMessageC;

  //Timer interface
  App.TimerTruck -> TimerMilliC;
  App.TimerMoveTrash -> TimerMilliC;
  App.TimerTrashThrown -> TimerMilliC;

  //Fake Sensor read
  App.Read -> FakeSensorC;
  
  //Random interface
  App.Random -> RandomC;
}

