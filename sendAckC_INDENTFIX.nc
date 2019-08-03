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
		interface Timer<TMilli> as TimerListeningMoveResp;
		interface Timer<TMilli> as TimerTrashThrown;
		interface Timer<TMilli> as TimerMoveTrash;
		interface Timer<TMilli> as TimerAlert;
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
	uint8_t timeT=0;
	uint8_t alertMsgSourceID;
	uint8_t moveMsgSourceID;
	uint8_t tempFilling=0;
	uint8_t truckDestX;
	uint8_t truckDestY;
	uint8_t excessTrash=0;
	bool alertMode=false;
	bool neighborMode=false;
	bool busyTruck=false;
	bool isListeningMoveResp=false;

	struct node_t {
		uint8_t positionX;
		uint8_t positionY;
		uint8_t trash=0;

	} mote;

	srand (time(NULL));


	//***************** Task send alert message ********************//
	task void sendAlertMsg() {//no ack

		//prepare a msg
		alertMsg* mess=(alertMsg*)(call Packet.getPayload(&packet,sizeof(alertMsg)));
		mess->msg_type = ALERT;
		mess->coord_X=mote.positionX;
		mess->coord_Y=mote.positionY;
		mess->node_ID=TOS_NODE_ID;
		mess->msg_id = counter++;

		dbg("radio_send", "Try to send a alert message to truck at time %s \n", sim_time_string());

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
		mess->msg_id = counter++;;

		dbg("radio_send", "Send a truck message to node at time %s \n", sim_time_string());
		call PacketAcknowledgements.requestAck( &packet );

		if(call AMSend.send(alertMsgSourceID,&packet,sizeof(truckMsg)) == SUCCESS) {
			dbg("radio_send", "Packet passed to lower layer successfully!\n");
			dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
			dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
			dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");
		}

	}

	//****************** Task send move message *****************//
	task void sendMoveMsg() {

		moveMsg* mess=(moveMsg*)(call Packet.getPayload(&packet,sizeof(moveMsg)));
		if(neighborMode==true){//send move request in broadcast
			mess->msg_type = MOVEREQ;
			mess->msg_id = counter++;
			mess->posX=mote.positionX;
			mess->posY=mote.positionY;
			mess->excess_trash=excessTrash;
		
			dbg("radio_send", "Send a move request to node at time %s \n", sim_time_string());

			if(call AMSend.send(AM_BROADCAST_ADDR,&packet,sizeof(moveMsg)) == SUCCESS) {
				dbg("radio_send", "Packet passed to lower layer successfully!\n");
				dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
				dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
				dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
				dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
				dbg_clear("radio_pack","\t\t Payload \n" );
				dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
				dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
				dbg_clear("radio_pack", "\t\t  my positionX for neighbor nodes: %hhu \n", mess->posX);
				dbg_clear("radio_pack", "\t\t  my positionY for neighbor nodes: %hhu \n", mess->posY);
				dbg_clear("radio_pack", "\t\t excess_trash: %hhu \n", mess->excess_trash);
				dbg_clear("radio_send", "\n ");
				dbg_clear("radio_pack", "\n");
			}

			call TimerTrashThrown.startOneshot(rand);

		}

		else if(alertMode==false){ //reply with move response 
			mess->msg_type = MOVERESP;
			mess->msg_id = counter++;
			mess->posX=mote.positionX;
			mess->posY=mote.positionY;
			mess->excess_trash=0;

			dbg("radio_send", "Send a move response to node at time %s \n", sim_time_string());

			if(call AMSend.send(moveMsgSourceID,&packet,sizeof(moveMsg)) == SUCCESS) {
				dbg("radio_send", "Packet passed to lower layer successfully!\n");
				dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
				dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
				dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
				dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
				dbg_clear("radio_pack","\t\t Payload \n" );
				dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
				dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
				dbg_clear("radio_pack", "\t\t  my positionX for supplicant node: %hhu \n", mess->posX);
				dbg_clear("radio_pack", "\t\t  my positionY for supplicant node: %hhu \n", mess->posY);
				dbg_clear("radio_send", "\n ");
				dbg_clear("radio_pack", "\n");
			}

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
				rand=(Random.rand16() % (30000-1000)) + 1000;
				call TimerTrashThrown.startOneshot(rand);
			}
		}

		else {
			//dbg for error
			call SplitControl.start();
		}

	}

	event void SplitControl.stopDone(error_t err) {//do nothing}

	//***************** MilliTimer interfaces ********************//
	event void TimerTrashThrown.fired() {

		tempFilling=Random.rand8() % 10 + 1;

		if(mote.trash<85) {
			//normal status
			mote.trash=mote.trash+tempFilling;
			dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d",mote.trash);
		}

		else if(mote.trash<100) {
			// alert mode
			if((100 - mote.trash) >= tempFilling ){ //spare capacity grater than new trash generated: collect it
				mote.trash=mote.trash+tempFilling;
				dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d (alert mode)",mote.trash);
			}
			else{//fill completely the bin, store in excessTrash garbage not collected
				excessTrash=excessTrash+(tempFilling-(100 - mote.trash));
				mote.trash=100; 
				dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d ",mote.trash, "(alert mode) excess trash %d", excessTrash);
			}

			if (alertMode==false){//considero il caso in cui, se già in alert mode, viene generata nuova spazzatura
				alertMode=true;
				call TimerAlert.startPeriodic(10000); //10 secondi
			}
			
		}

		else {
			//neighbor mode
			excessTrash=excessTrash+tempFilling;
			dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d ",mote.trash, "(neighbor mode) excess trash %d", excessTrash);
			neighborMode=true;
			post sendMoveMsg();
		}

		rand=(Random.rand16() % (30000-1000)) + 1000;
		call TimerTrashThrown.startOneshot(rand);
	}

	event void TimerTruck.fired() {
		post sendTruckMsg()
		mote.positionX=truckDestX;//when the garbage truck moves to a bin it acquire the coordinates of the bin itself.
		mote.positionY=truckDestY;
	}
	
	event void TimerAlert.fired() {
	    post sendAlertMsg(); // questo implementa l'invio periodico dei msg alert
	}

	event void TimerMoveTrash.fired() {
		post sendMoveMsg();
	}

	event void TimerListeningMoveResp.fired() {
		
	}

	//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf,error_t err) {

		if(&packet == buf && err == SUCCESS ) {
			dbg("radio_send", "Packet sent...");

			if(neighborMode==true)//if I've sent successfully a broadcast move msg, I start the 2 sec timer for collecting responses


			//check if ack is received
			if ( call PacketAcknowledgements.wasAcked( buf ) ) {
				dbg_clear("radio_ack", "and ack received");

				if(busyTruck==true)//busy truck false quando ricevo l'ack del truckmsg: non c'e bisogno di mettere tos==8 perche la condizione busyTruck==true ci può essere solo se sei il truck
					busyTruck=false;
				}

			else { //ack is not received
				dbg_clear("radio_ack", "but ack was not received");
				if(TOS_NODE_ID==8) { //if I don't receive the ack of truck msg and and I'm the truck, deliver it again
					post sendTruckMsg();
				}
			}

			dbg_clear("radio_send", " at time %s \n", sim_time_string()); //e neanche questo
		}
	}

	//***************************** Receive interface *****************//
	event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

		if (len == sizeof(alertMsg) && TOS_NODE_ID==8 && busyTruck==false){//I receive an alert msg I am the truck and i'm not busy
			alertMsg* mess=(alertMsg*)payload;
			busyTruck=true;
			truckDestX=mess->coord_X;
			truckDestY=mess->coord_Y;
			timeT=ALFABINTRUCK*sqrt((mote.positionX-truckDestX)*(mote.positionX-truckDestX)+(mote.positionY-truckDestY)*(mote.positionY-truckDestY));
			call TimerTruck.startOneshot(timeT);
			alertMsgSourceID=call AMPacket.source( buf );//check this, needed to store the node id of the sender bin of alert msg and used in sendTruckMsg
		
			dbg("radio_rec","Message received at time %s \n", sim_time_string());
			dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
			dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
			dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
			dbg_clear("radio_pack", "\t\t node id: %hhu \n", mess->node_ID);
			dbg_clear("radio_pack", "\t\t position coord x of full bin: %hhu \n", mess->coord_X);
			dbg_clear("radio_pack", "\t\t position coord y of full bin: %hhu \n", mess->coord_Y);
			dbg_clear("radio_rec", "\n ");
			dbg_clear("radio_pack","\n");
		}

		//check the condition on this if: if i receive a truck msg ad I am the destination of this pkt, empty the bin
		if (len == sizeof(truckMsg) && TOS_NODE_ID==(call AMPacket.destination( buf ))) {
			mote.trash=0;
			alertMode=false;
			call TimerAlert.stop(); //stop sending periodic alert msg 
			truckMsg* mess=(truckMsg*)payload;
			dbg("radio_rec","Message received at time %s \n", sim_time_string());
			dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
			dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
			dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
			dbg_clear("radio_rec", "\n ");
			dbg_clear("radio_pack","\n");
		}


		if (len == sizeof(moveMsg) && alertMode==false && neighborMode==false && TOS_NODE_ID!=8) {//I receive a move msg from a neighbor and I am in normal state (and I'm not the truck)
			moveMsg* mess=(moveMsg*)payload;
			timeT=ALFABINBIN*sqrt((mote.positionX-mess->posX)*(mote.positionX-mess->posX)+(mote.positionY-mess->posY)*(mote.positionY-mess->posY));
			call TimerMoveTrash.startOneshot(timeT);
			moveMsgSourceID=call AMPacket.source( buf );

			dbg("radio_rec","Message received at time %s \n", sim_time_string());
			dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
			dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
			dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
			dbg_clear("radio_pack", "\t\t excess_trash: %hhu \n", mess->excess_trash);
			dbg_clear("radio_pack", "\t\t positionX of the supplicant neighbor node: %hhu \n", mess->posX);
			dbg_clear("radio_pack", "\t\t positionY of the supplicant neighbor node: %hhu \n", mess->posY);
			dbg_clear("radio_rec", "\n ");
			dbg_clear("radio_pack","\n");
		}


		return buf;

	}

}

