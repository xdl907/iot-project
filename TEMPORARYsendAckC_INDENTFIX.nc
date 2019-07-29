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

} 

implementation {

	uint8_t counter=0;
	uint8_t rec_id;
	uint16_t rand;
	message_t packet;

	task void sendReq();
	task void sendResp();
	uint8_t i=0;
	uint8_t tempFilling=0;

	struct node_t {
		uint8_t positionX;
		uint8_t positionY;
		uint8_t trash=0;

	} mote;

	srand (time(NULL));


	//***************** Task send alert message ********************//
	task void sendAlertMsg() {

		//prepare a msg
		alertMsg* mess=(alertMsg*)(call Packet.getPayload(&packet,sizeof(alertMsg)));
		mess->msg_type = ALERT;
		mess->coord_X=mote.positionX;
		mess->coord_Y=mote.positionY;
		mess->node_ID=TOS_NODE_ID;
		mess->msg_id = counter++;

		dbg("radio_send", "Try to send a alert message to truck at time %s \n", sim_time_string());

		//set a flag informing the receiver that the message must be acknoledge
		call PacketAcknowledgements.requestAck( &packet );

		//8 is the tos node id of the truck
		if(call AMSend.send(8,&packet,sizeof(alertMsg)) == SUCCESS) {
			//TODO check these dbg
			dbg("radio_send", "Packet passed to lower layer successfully!\n");
			dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
			dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
			dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
			dbg_clear("radio_pack", "\t\t node id: %hhu \n", mess->node_ID);
			dbg_clear("radio_pack", "\t\t node position coord x: %hhu \n", mess->coord_X);
			dbg_clear("radio_pack", "\t\t node position coord y: %hhu \n", mess->coord_Y);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");
		}
	}

	//****************** Task send truck message *****************//
	task void sendTruckMsg() {

		truckMsg* mess=(truckMsg*)(call Packet.getPayload(&packet,sizeof(truckMsg)));
		mess->msg_type = TRUCK;
		//TODO mettere a posto i vari campi ecc
		mess->msg_id = rec_id;
		mess->value = data;

		dbg("radio_send", "Try to send a response to node 1 at time %s \n", sim_time_string());
		call PacketAcknowledgements.requestAck( &packet );

		if(call AMSend.send(1,&packet,sizeof(truckMsg)) == SUCCESS) {
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

	//***************** Boot interface ********************//
	event void Boot.booted() {
		dbg("boot","Application booted.\n");
		call SplitControl.start(); //turn on the radio
	}

	//***************** SplitControl interface ********************//
	event void SplitControl.startDone(error_t err) {
		if(err == SUCCESS) {
			dbg("radio","Radio on!\n");

			mote.positionX=Random.rand8() % 100 + 1;
			mote.positionY=Random.rand8() % 100 + 1;

			if(TOS_NODE_ID==8) {
				dbg("role","I'm the truck: position x %d",mote.positionX," position y %d",mote.positionY);
			}

			else {
				dbg("role","I'm node %d",TOS_NODE_ID,": position x %d",mote.positionX," position y %d",mote.positionY);
			}	

			rand=(Random.rand16() % (30000-1000)) + 1000;
			call TimerTrashThrown.startOneshot(rand);
		}

		else {
			//dbg for error
			call SplitControl.start();
		}

	}

	event void SplitControl.stopDone(error_t err) {//do nothing}

	//***************** MilliTimer interface ********************//
	event void TimerTrashThrown.fired() {

		tempFilling=mote.trash+Random.rand8() % 10 + 1;

		if(tempFilling<85) {
			//normal status
			mote.trash=mote.trash+tempFilling;
			dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d",mote.trash);
		}

		else if(tempFilling > 85 && tempFilling<100) {
			// alert mode
			mote.trash=mote.trash+tempFilling;
			post sendAlertMsg();
		}

		else {
			//TODO neighbor mode
		}

		rand=(Random.rand16() % (30000-1000)) + 1000;
		call TimerTrashThrown.startOneshot(rand);
	}

	event void TimerTruck.fired() {
	//TODO timer non ancora impostato
	}

	event void TimerMoveTrash.fired() {
	//TODO
	}

	//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf,error_t err) {

		if(&packet == buf && err == SUCCESS ) {
			dbg("radio_send", "Packet sent...");

			//check if ack is received
			if ( call PacketAcknowledgements.wasAcked( buf ) ) {
				dbg_clear("radio_ack", "and ack received");

				if(TOS_NODE_ID==8) {//if ack is received and I am the truck
					post sendTruckMsg();
				} 

			else { //ack is not received
				dbg_clear("radio_ack", "but ack was not received");
				if(TOS_NODE_ID==8) { //non capisco questo passaggio
					post sendAlertMsg();
				}
			}

			dbg_clear("radio_send", " at time %s \n", sim_time_string()); //e neanche questo
		}
	}

	//***************************** Receive interface *****************//

	//untouched 
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

		if ( mess->msg_type == ALERT ) {
			post sendTruckMsg();
		}

		return buf;

	}

}

