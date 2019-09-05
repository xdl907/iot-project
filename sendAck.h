/**
 *  @author Alessandro Petocchi, Giuseppe Leone
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
	nx_uint16_t pos_X;
	nx_uint16_t pos_Y;
	nx_uint16_t excess_trash;
} moveMsg;

typedef nx_struct my_msg3 {
	nx_uint8_t msg_type; 
	nx_uint16_t msg_id;
	nx_uint16_t coord_X;
	nx_uint16_t coord_Y;
	nx_uint8_t node_ID;
} alertMsg;

typedef nx_struct my_msg4 {
    nx_uint16_t val;
} serialMsg;

#define ALERT 1
#define TRUCK 2 
#define MOVEREQ 3
#define MOVERESP 4 
#define MOVETRASH 5
#define ALFABINTRUCK 30
#define ALFABINBIN 2

enum{
    AM_MY_MSG=6,
    AM_SERIAL_MSG=0x89,
};

#endif
