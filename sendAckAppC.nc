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
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC;
  components SerialActiveMessageC as AM; //new
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new TimerMilliC() as Timer3;
  components new TimerMilliC() as Timer4;
  components new TimerMilliC() as Timer5;
  components RandomC;
  
  //Boot interface
  App.Boot -> MainC.Boot;

  //Send and Receive interfaces
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;

  //Radio Control
  App.SplitControl -> ActiveMessageC;
  App.SerialControl -> AM; //new
  
  //Interfaces to access package fields
  App.AMPacket -> AMSenderC;
  App.Packet -> AMSenderC;
  App.PacketAcknowledgements->ActiveMessageC;
  App.PacketSF -> AM; //new
  App.AMSendSF -> AM.AMSend[AM_SERIAL_MSG]; // new
  
  //Timer interface
  App.TimerTruck -> Timer1;
  App.TimerMoveTrash -> Timer2;
  App.TimerTrashThrown -> Timer3;
  App.TimerAlert -> Timer4;
  App.TimerListeningMoveResp -> Timer5;

  
  //Random interface
  App.Random -> RandomC;
}

