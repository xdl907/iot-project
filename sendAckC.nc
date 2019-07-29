/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response.
 *  The reply message contains a reading from the Fake Sensor.
 *
 *  @author Luca Pietro Borsani
 */

#include "sendAck.h"
#include "Timer.h"
#include <time.h>

module sendAckC {

//interface that we use
  uses {
	interface Boot; //always here and it's the starting point
    	//interfaces for communications
    interface AMPacket; 
	interface Packet;
	interface PacketAcknowledgements;
    interface AMSend;

    interface SplitControl;
    interface Receive;
    interface Random;

    interface Timer<TMilli> as TimerTruck;
    interface Timer<TMilli> as TimerTrashThrown;
  	interface Timer<TMilli> as TimerMoveTrash;
	//used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t>;
  }

} implementation {

  uint8_t counter=0;
  uint8_t rec_id;
  uint16_t rand;
  message_t packet;

  task void sendReq();
  task void sendResp();
  uint8_t i=0;
  uint8_t tempFilling=0;

  struct node_t
  {
  	uint8_t positionX;
  	uint8_t positionY;
	uint8_t trash=0;

  }mote;

  srand (time(NULL));
  
  
  //***************** Task send request ********************//
  task void sendReq() {

	//prepare a msg
	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = REQ;
	mess->msg_id = counter++;
	    
	dbg("radio_send", "Try to send a request to node 2 at time %s \n", sim_time_string());
    
	//set a flag informing the receiver that the message must be acknoledge
	call PacketAcknowledgements.requestAck( &packet );
	
	//2 is the unicast address
	if(call AMSend.send(2,&packet,sizeof(my_msg_t)) == SUCCESS){
		
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	  dbg_clear("radio_pack", "\t\t value: %hhu \n", mess->value);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");
      
      }

 }        

  //****************** Task send response *****************//
  task void sendResp() {
	call Read.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	call SplitControl.start(); //turn on the radio
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
      
    if(err == SUCCESS) {

		dbg("radio","Radio on!\n");


		mote.positionX=Random.rand8() % 100 + 1;
		mote.positionY=Random.rand8() % 100 + 1;

		if(TOS_NODE_ID==8)
			dbg("role","I'm the truck: position x %d",mote.positionX," position y %d",mote.positionY);
		else
			dbg("role","I'm node %d",TOS_NODE_ID,": position x %d",mote.positionX," position y %d",mote.positionY);

		rand=(Random.rand16() % (30000-1000)) + 1000;
		call MilliTimer.startOneshot(rand);

    }
    else{
		//dbg for error
		call SplitControl.start();
    }

  }
  
  event void SplitControl.stopDone(error_t err){}

  //***************** MilliTimer interface ********************//
  event void TimerTrashThrown.fired() {

  	tempFilling=mote.trash+Random.rand8() % 10 + 1;

  	if(tempFilling<85) {
  		//normal status
  		mote.trash=mote.trash+tempFilling;
  		dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d",mote.trash);
  	}

  	else if(tempFilling<100){
  		//TODO alert mode

  	}

  	else {
  		//TODO neighbor mode

  	}



    rand=(Random.rand16() % (30000-1000)) + 1000;
    call MilliTimer.startOneshot(rand);
  }
  
   event void TimerTruck.fired()
  {
   //TODO
  }

   event void TimerMoveTrash.fired()
  {
    //TODO
  }

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {

    if(&packet == buf && err == SUCCESS ) {
	dbg("radio_send", "Packet sent...");

	//check if ack is received
	if ( call PacketAcknowledgements.wasAcked( buf ) ) {
	  dbg_clear("radio_ack", "and ack received");
	  call MilliTimer.stop();
	} else {
	  dbg_clear("radio_ack", "but ack was not received");
	  post sendReq();
	}
	dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }

  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

	my_msg_t* mess=(my_msg_t*)payload;
	rec_id = mess->msg_id;
	
	dbg("radio_rec","Message received at time %s \n", sim_time_string());
	dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
	dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
	dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
	dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
	dbg_clear("radio_pack","\t\t Payload \n" );
	dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
	dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	dbg_clear("radio_pack", "\t\t value: %hhu \n", mess->value);
	dbg_clear("radio_rec", "\n ");
	dbg_clear("radio_pack","\n");
	
	if ( mess->msg_type == REQ ) {
		post sendResp();
	}

    return buf;

  }
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {

	my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
	mess->msg_type = RESP;
	mess->msg_id = rec_id;
	mess->value = data;
	  
	dbg("radio_send", "Try to send a response to node 1 at time %s \n", sim_time_string());
	call PacketAcknowledgements.requestAck( &packet );
	if(call AMSend.send(1,&packet,sizeof(my_msg_t)) == SUCCESS){
		
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack","\t\t Payload \n" );
	  dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
	  dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	  dbg_clear("radio_pack", "\t\t value: %hhu \n", mess->value);
	  dbg_clear("radio_send", "\n ");
	  dbg_clear("radio_pack", "\n");

        }

  }

}

