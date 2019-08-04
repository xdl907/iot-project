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

	}

} 

implementation {

	uint8_t counter=0;
	uint8_t rec_id;
	uint16_t rnd;
	message_t packet;

	task void sendTruckMsg();
	task void sendAlertMsg();
	task void sendMoveMsg();

	uint8_t i=0;
	uint8_t location=0;
	uint8_t timeT=0;
	uint8_t alertMsgSourceID;
	uint8_t moveReqMsgSourceID;
	uint8_t tempFilling=0;
	uint8_t truckDestX;
	uint8_t truckDestY;
	uint8_t moveRespCounter=0;
	uint8_t neighborDistance[4]={0, 0, 0, 0};
	uint8_t neighborID[4]={0, 0, 0, 0};
	uint8_t minimum;
	bool alertMode=FALSE;
	bool neighborMode=FALSE;
	bool busyTruck=FALSE;
	bool isListeningMoveResp=FALSE;
	bool isDeliveringExcessGarbage=FALSE;

	struct node_t {
		uint8_t positionX;
		uint8_t positionY;
		uint8_t trash=0;
		uint8_t excessTrash=0;
	} mote;

	struct neigh_t {
	uint8_t positionX;
	uint8_t positionY;
	} neighborPosition[4]; //max # of neighbors for this topo is 4 ;

	//srand (time(NULL));


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

		if(neighborMode==TRUE){

			if(isDeliveringExcessGarbage==TRUE){ //sending the excess trash to the selected neighbor (its id is excessTrashDestID)

				mess->msg_type = MOVETRASH;
				mess->msg_id = counter++;
				mess->pos_X=0;
				mess->pos_Y=0;
				mess->excess_trash=mote.excessTrash;
			
				//TODO ack per questo tipo di move msg??
				dbg("radio_send", "Delivering excess trash to node at time %s \n", sim_time_string());

				if(call AMSend.send(neighborID[location-1],&packet,sizeof(moveMsg)) == SUCCESS) {
					dbg("radio_send", "Packet passed to lower layer successfully!\n");
					dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
					dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
					dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
					dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
					dbg_clear("radio_pack","\t\t Payload \n" );
					dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
					dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
					dbg_clear("radio_pack", "\t\t excess_trash: %hhu \n", mess->excess_trash);
					dbg_clear("radio_send", "\n ");
					dbg_clear("radio_pack", "\n");
				}

			}

			else { //send move request in broadcast
				mess->msg_type = MOVEREQ;
				mess->msg_id = counter++;
				mess->pos_X=mote.positionX;
				mess->pos_Y=mote.positionY;
				mess->excess_trash=mote.excessTrash;
			
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
					dbg_clear("radio_pack", "\t\t  my positionX for neighbor nodes: %hhu \n", mess->pos_X);
					dbg_clear("radio_pack", "\t\t  my positionY for neighbor nodes: %hhu \n", mess->pos_Y);
					dbg_clear("radio_pack", "\t\t excess_trash: %hhu \n", mess->excess_trash);
					dbg_clear("radio_send", "\n ");
					dbg_clear("radio_pack", "\n");
				}
			}

		}

		else if(alertMode==FALSE){ //reply with move response if I am in normal mode
			mess->msg_type = MOVERESP;
			mess->msg_id = counter++;
			mess->pos_X=mote.positionX;
			mess->pos_Y=mote.positionY;
			mess->excess_trash=0;

			dbg("radio_send", "Send a move response to node at time %s \n", sim_time_string());

			if(call AMSend.send(moveReqMsgSourceID,&packet,sizeof(moveMsg)) == SUCCESS) {
				dbg("radio_send", "Packet passed to lower layer successfully!\n");
				dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
				dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
				dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
				dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
				dbg_clear("radio_pack","\t\t Payload \n" );
				dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
				dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
				dbg_clear("radio_pack", "\t\t  my positionX for supplicant node: %hhu \n", mess->pos_X);
				dbg_clear("radio_pack", "\t\t  my positionY for supplicant node: %hhu \n", mess->pos_Y);
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
				rnd=(Random.rand16() % (30000-1000)) + 1000;
				call TimerTrashThrown.startOneshot(rnd);
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
				mote.excessTrash=mote.excessTrash+(tempFilling-(100 - mote.trash));
				mote.trash=100; 
				dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d ",mote.trash, "(alert mode) excess trash %d", mote.excessTrash);
			}

			if (alertMode==FALSE){//considero il caso in cui, se già in alert mode, viene generata nuova spazzatura
				alertMode=TRUE;
				call TimerAlert.startPeriodic(10000); //10 secondi
			}
			
		}

		else {
			//neighbor mode
			mote.excessTrash=mote.excessTrash+tempFilling;
			dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d ",mote.trash, "(neighbor mode) excess trash %d", mote.excessTrash);
			neighborMode=TRUE;
			post sendMoveMsg();
		}

		rnd=(Random.rand16() % (30000-1000)) + 1000;
		call TimerTrashThrown.startOneshot(rnd);
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
		post sendMoveMsg(); //send a move resp
	}

	event void TimerListeningMoveResp.fired() {
		isListeningMoveResp=FALSE; //when timer fires, the listening window for move responses closes

		if(moveRespCounter != 0){ //if I have received some move responses from neighbors 

			for(i=0;i<moveRespCounter;i++) //compute distances from bin that have replied
				neighborDistance[i]=sqrt((mote.positionX-neighborPosition[i].positionX )*(mote.positionX-neighborPosition[i].positionX)+(mote.positionY-neighborPosition[i].positionY)*(mote.positionY-neighborPosition[i].positionY));
			//compute min distance
			minimum = neighborDistance[0];
			for (i = 1; i < moveRespCounter; i++)
			{
				if (array[i] < minimum){
					minimum = array[i];
					location = i+1;
				}
			}

			isDeliveringExcessGarbage=TRUE;
			post sendMoveMsg();
		}

		else{//no responses received 

			dbg("role","I'm node %d",TOS_NODE_ID,": trash quantity %d ",mote.trash, "(alert mode) no neighbor replies and excess trash %d", mote.excessTrash, "has been deleted");
			mote.excessTrash=0;
		}

		neighborMode=FALSE;
	}

	//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf,error_t err) {

		if(&packet == buf && err == SUCCESS ) {
			dbg("radio_send", "Packet sent...");

			if(neighborMode==TRUE){
				
				if (isDeliveringExcessGarbage==TRUE) //I've sent successfully the excess trash
					isDeliveringExcessGarbage=FALSE;

				else {//if I've sent successfully a broadcast move msg, I start the 2 sec timer for collecting responses
				call TimerListeningMoveResp.startOneshot(2000); //2 sec
				isListeningMoveResp=TRUE;
				}

			}

			//check if ack is received
			if ( call PacketAcknowledgements.wasAcked( buf ) ) {
				dbg_clear("radio_ack", "and ack received");

				if(busyTruck==TRUE)//busy truck false quando ricevo l'ack del truckmsg: non c'e bisogno di mettere tos==8 perche la condizione busyTruck==true ci può essere solo se sei il truck
					busyTruck=FALSE;
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

		if (len == sizeof(alertMsg) && TOS_NODE_ID==8 && busyTruck==FALSE){//I receive an alert msg I am the truck and i'm not busy
			alertMsg* mess=(alertMsg*)payload;
			busyTruck=TRUE;
			truckDestX=mess->coord_X;
			truckDestY=mess->coord_Y;
			timeT=ALFABINTRUCK*sqrt((mote.positionX-truckDestX)*(mote.positionX-truckDestX)+(mote.positionY-truckDestY)*(mote.positionY-truckDestY));//compute tTruck
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
			alertMode=FALSE;
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

		//I receive a move msg from a neighbor and I am in normal state (and I'm not the truck)
		if (len == sizeof(moveMsg) && alertMode==FALSE && neighborMode==FALSE && TOS_NODE_ID!=8) {
			moveMsg* mess=(moveMsg*)payload;

			if(mess->msg_type == MOVEREQ){

				timeT=ALFABINBIN*sqrt((mote.positionX-mess->pos_X)*(mote.positionX-mess->pos_X)+(mote.positionY-mess->pos_Y)*(mote.positionY-mess->pos_Y));//compute tBin
				call TimerMoveTrash.startOneshot(timeT); // send a move resp after tBin time
				moveReqMsgSourceID=call AMPacket.source( buf ); //store the tos id of the mote which has sent the request

				dbg("radio_rec","Message received at time %s \n", sim_time_string());
				dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
				dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
				dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
				dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
				dbg_clear("radio_pack","\t\t Payload \n" );
				dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
				dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
				dbg_clear("radio_pack", "\t\t excess_trash: %hhu \n", mess->excess_trash);
				dbg_clear("radio_pack", "\t\t positionX of the supplicant neighbor node: %hhu \n", mess->pos_X);
				dbg_clear("radio_pack", "\t\t positionY of the supplicant neighbor node: %hhu \n", mess->pos_Y);
				dbg_clear("radio_rec", "\n ");
				dbg_clear("radio_pack","\n");
			}

			if(mess->msg_type == MOVETRASH && TOS_NODE_ID==(call AMPacket.destination( buf )) ){

				mote.trash=mote.trash+mess->excess_trash;
				dbg("radio_rec","Message received at time %s \n", sim_time_string());
				dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
				dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
				dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
				dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
				dbg_clear("radio_pack","\t\t Payload \n" );
				dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
				dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
				dbg_clear("radio_pack", "\t\t excess_trash: %hhu \n", mess->excess_trash);
				dbg_clear("radio_pack", "\t\t new trash value: %hhu \n", mote.trash);
				dbg_clear("radio_rec", "\n ");
				dbg_clear("radio_pack","\n");

			}

		}


		//I receive a move msg (resp) from a neighbor and the listen interval is open (isListeningMoveResp==true)
		if (len == sizeof(moveMsg) && neighborMode==TRUE && TOS_NODE_ID!=8 && isListeningMoveResp==TRUE) {
			moveMsg* mess=(moveMsg*)payload;

			if(mess->msg_type == MOVERESP){
 
 				//store position of neighbor that has replied 
				neighborPosition[moveRespCounter].positionX=mess->pos_X; 
				neighborPosition[moveRespCounter].positionY=mess->pos_Y;
				//store MOVERESP sender tosID 
				neighborID[moveRespCounter]= (call AMPacket.source( buf )); 
				moveRespCounter++;

				dbg("radio_rec","Message received at time %s \n", sim_time_string());
				dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
				dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
				dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
				dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
				dbg_clear("radio_pack","\t\t Payload \n" );
				dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
				dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
				dbg_clear("radio_pack", "\t\t excess_trash: %hhu \n", mess->excess_trash);
				dbg_clear("radio_pack", "\t\t positionX of the available neighbor node: %hhu \n", mess->pos_X);
				dbg_clear("radio_pack", "\t\t positionY of the available neighbor node: %hhu \n", mess->pos_Y);
				dbg_clear("radio_rec", "\n ");
				dbg_clear("radio_pack","\n");
			}

		}


		return buf;

	}


}

