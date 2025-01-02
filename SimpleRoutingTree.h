#ifndef SIMPLEROUTINGTREE_H
#define SIMPLEROUTINGTREE_H


enum{
	SENDER_QUEUE_SIZE=100,
	RECEIVER_QUEUE_SIZE=100,
	AM_SIMPLEROUTINGTREEMSG=22,
	AM_ROUTINGMSG=22,
	AM_MAXMSG=24,
	AM_AVGMSG=25,
	AM_ACKMSG=26,
	MAX_DEPTH=200,
	EPOCH_PERIOD_MILLI= 40*1024,
	MAX_STEP= 130,
	AVG_STEP= 180,
	TIMER_FAST_PERIOD=20,
	OFFSET_FIX = 700,
	OperationWindow = 1000,
	JITTER = 400
};

typedef nx_struct RoutingMsg{
	nx_uint8_t depth;
	nx_uint8_t cmd;
} RoutingMsg;

typedef nx_struct DataAvgMsg{
	nx_uint16_t Sum;
	nx_uint8_t Count;
} DataAvgMsg;

typedef nx_struct DataMaxMsg{
	nx_uint8_t data;
} DataMaxMsg;

#endif
