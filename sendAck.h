/**
 *  @author Luca Pietro Borsani
 */

#ifndef SENDACK_H
#define SENDACK_H

//payload of the msg
typedef nx_struct my_msg1 {
	nx_uint8_t msg_type; 
	nx_uint16_t msg_id;
} truckMsg;

typedef nx_struct my_msg2 {
	nx_uint8_t msg_type; 
	nx_uint16_t msg_id;
	nx_uint16_t excessTrash;
} moveMsg;

typedef nx_struct my_msg3 {
	nx_uint8_t msg_type; 
	nx_uint16_t msg_id;
	nx_uint16_t coordX;
	nx_uint16_t coordY;
	nx_uint8_t nodeID;
} alertMsg;

#define REQ 1
#define RESP 2 

enum{
AM_MY_MSG = 6,
};

#endif
