#include "SimpleRoutingTree.h"
#include "MicroPulse.h"

module SRTreeC
{
	uses interface Boot;
	uses interface SplitControl as RadioControl;

	uses interface Packet as RoutingPacket;
	uses interface AMSend as RoutingAMSend;
	uses interface AMPacket as RoutingAMPacket;
	
	uses interface Packet as DataMaxPacket;
	uses interface AMSend as DataMaxAMSend;
	uses interface AMPacket as DataMaxAMPacket;
	uses interface PacketQueue as DataMaxSendQueue;
	uses interface PacketQueue as DataMaxReceiveQueue;

	uses interface Packet as DataAvgPacket;
	uses interface AMPacket as DataAvgAMPacket;
	uses interface AMSend as DataAvgAMSend;
	uses interface Receive as DataAvgReceive;
	uses interface PacketQueue as DataAvgSendQueue;
	uses interface PacketQueue as DataAvgReceiveQueue;

	uses interface Timer<TMilli> as SlotTimer;
	uses interface Timer<TMilli> as uP_TransmitTimer;
	
	uses interface Receive as RoutingReceive;
	uses interface Receive as DataMaxReceive;
	
	uses interface PacketQueue as RoutingSendQueue;
	uses interface PacketQueue as RoutingReceiveQueue;

	uses interface Random as RandomGenerator;
	uses interface ParameterInit<uint16_t> as GeneratorSeed;

	uses interface NodeInformation;
}
implementation
{
	uint16_t  epochCounter;
	
	message_t radioRoutingSendPkt;
	message_t radioMessageMaxSendPkt;
	message_t radioMessageAvgSendPkt;

	message_t serialPkt;
	message_t serialRecPkt;
	
	uint16_t bootTime = -1;
	uint32_t EpochStartTime = -1; 

	uint32_t jitter = -1;

	bool RoutingSendBusy=FALSE;
	bool NotifySendBusy=FALSE;	 
	bool MessageAvgSendBusy=FALSE;
	bool MessageMaxSendBusy=FALSE;
	
	uint8_t curdepth;
	uint16_t parentID;

	uint8_t measurement = -1;
	bool COMMAND_TO_RUN = 0;

	typedef enum command_id{
		COMMAND_AVG = 0,
		COMMAND_MAX = 1,
	} command_id_t;
	
	task void sendRoutingTask();
	task void receiveRoutingTask();
	
	task void startEpoch();
	task void windowTask();
	task void sendMaxDataTask();
	task void sendAvgDataTask();
	task void SendRoutingMessage();
	
	/**
	 * Function to generate a random value between min and max
	 * @param min The minimum value
	 * @param max The maximum value
	 * @return The generated random value
	 */
	uint16_t generateRandomValue(uint16_t min, uint16_t max) {
		return (rand() % (max - min + 1)) + min;
	}

	/**
	 * Function to initialize the sensor value
	 */
	void initializeSensorValue() {
		measurement = generateRandomValue(1, 50);
	}

	/**
	 * Function to update the sensor value
	 */
	void updateSensorValue() {
		int16_t minValue = measurement - (measurement * 30 / 100);
		int16_t maxValue = measurement + (measurement * 30 / 100);

		// Ensure the value stays within 1 and 50
		if (minValue < 1) minValue = 1;
		if (maxValue > 50) maxValue = 50;

		measurement = generateRandomValue(minValue, maxValue);

		dbg("SRTreeC", "updateSensorValue(): New Measurement = %d\n", measurement);
	}

	/**
	 * Function to print the results of the root node
	 * @param count The number of nodes
	 * @param sum The value
	 */
	void rootResults(uint8_t count, uint8_t sum) {
		if (COMMAND_TO_RUN == 1){
			dbg("SRTreeC", "\n\trootResults(): MAX = %d\n\n", sum);
		} else {

			dbg("SRTreeC", "\n\trootResults(): Root value = %d\n", measurement);
			dbg("SRTreeC", "\n\trootResults(): AVG = %f\n\n", (float)sum / count);
		}
	}

	event void Boot.booted(){
		dbg("Boot", "Booted\n");
		// Start the radio control interface to enable communication
		call RadioControl.start();
		
		epochCounter = 0;

		// Initialize the random number generator
		call GeneratorSeed.init(time(NULL)+TOS_NODE_ID*1000);
		
		// Set the node ID in the NodeInformation component
		call NodeInformation.setNodeId(TOS_NODE_ID);

		if(TOS_NODE_ID==0) {  // Root node initialization
			curdepth=0;
			parentID=0;

			dbg("Boot", "curdepth = %d  ,  parentID= %d \n", curdepth , parentID);

			// Randomly select the command to run (MAX or AVG)
			if (call RandomGenerator.rand32() % 2 + 1 == 1) {
				dbg("Boot", "Command selected is MAX\n");
				COMMAND_TO_RUN = COMMAND_MAX;
			} else {
				dbg("Boot", "Command selected is AVG\n");
				COMMAND_TO_RUN = COMMAND_AVG;
			}

		} else {  // Non-root node initialization
			curdepth=-1;
			parentID=-1;

			dbg("Boot", "curdepth = %d  ,  parentID= %d \n", curdepth , parentID);
		}

		// Set the depth and parent ID in the NodeInformation component
		call NodeInformation.setDepth(curdepth);
		call NodeInformation.setParent(parentID);
		initializeSensorValue();
	}
	
	event void RadioControl.startDone(error_t err){
		if (err == SUCCESS) {
			dbg("Radio" , "Radio initialized successfully!!!\n");		
			if (TOS_NODE_ID==0 && epochCounter==0){
				post SendRoutingMessage();
				post startEpoch();
			}
		} else {
			dbg("Radio" , "Radio initialization failed! Retrying...\n");
			call RadioControl.start();
		}
	}
	
	event void RadioControl.stopDone(error_t err){ 
		dbg("Radio", "Radio stopped!\n");
	}
	
	event void uP_TransmitTimer.fired(){
		// if (COMMAND_TO_RUN == 1) {
		// 	post sendMaxDataTask();
		// } else {
		// 	post sendAvgDataTask();
		// }
	}

	task void SendRoutingMessage(){
		message_t tmp;
		error_t enqueueDone;
		
		RoutingMsg* mrpkt;
		dbg("SRTreeC", "SendRoutingMessage: radioBusy = %s \n",(RoutingSendBusy)?"True":"False");
		if (TOS_NODE_ID==0){
			dbg("SRTreeC", "\n							              ##################################### \n");
			dbg("SRTreeC", "#######   ROUTING    ############## \n");
			dbg("SRTreeC", "#####################################\n");
		}
		
		// Check if the routing send queue is full
		if(call RoutingSendQueue.full()){
			dbg("Routing", "RoutingMsgTimer.fired():Routing Send Queue Full...\n");
			return;
		}
		
		// Get a pointer to the payload of the temporary message
		mrpkt = (RoutingMsg*) (call RoutingPacket.getPayload(&tmp, sizeof(RoutingMsg)));
		if(mrpkt==NULL){
			dbg("SRTreeC","RoutingMsgTimer.fired(): No valid payload... \n");
			return;
		}
		atomic{ // Set the current depth and command in the routing message
			mrpkt->depth = curdepth;
			mrpkt->cmd = COMMAND_TO_RUN;
		}
		dbg("SRTreeC" , "Sending RoutingMsg... \n");
	
		// Set the destination of the message to broadcast and the payload length of the message
		call RoutingAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
		call RoutingPacket.setPayloadLength(&tmp, sizeof(RoutingMsg));
		
		// Enqueue the message into the routing send queue
		enqueueDone=call RoutingSendQueue.enqueue(tmp);
		
		// Check if the message was enqueued successfully
		if( enqueueDone==SUCCESS){
			if (call RoutingSendQueue.size()==1){
				dbg("SRTreeC","RoutingMsg enqueued successfully in SendingQueue!!!\n");
				post sendRoutingTask();
			}
		} else{
			dbg("SRTreeC","RoutingMsg failed to be enqueued in SendingQueue!!!");
		}
	}

	event void SlotTimer.fired() {
		epochCounter++;
		EpochStartTime = sim_time()/10000000000;

		dbg("SRTreeC", "Epoch: %d\n", epochCounter);
		
		post windowTask();
	}

	event void DataMaxAMSend.sendDone(message_t * msg , error_t err){
		dbg("SRTreeC", "A Data Max package sent... %s \n",(err==SUCCESS)?"True":"False");
		
		// Repeat sending messages until DataMaxSendQueue is empty
		if(!(call DataMaxSendQueue.empty())){
			post sendMaxDataTask();
		}
	}

	event void DataAvgAMSend.sendDone(message_t * msg , error_t err){
		dbg("SRTreeC", "A Data Avg package sent... %s \n",(err==SUCCESS)?"True":"False");
		

		// Repeat sending messages until DataAvgSendQueue is empty
		if(!(call DataAvgSendQueue.empty())){
			post sendAvgDataTask();
		}
	}

	event void RoutingAMSend.sendDone(message_t * msg , error_t err){
		// Repeat sending messages until RoutingSendQueue is empty
		if(!(call RoutingSendQueue.empty())){
			post sendRoutingTask();
		}
	}

	event message_t* RoutingReceive.receive( message_t * msg , void * payload, uint8_t len){
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;
		
		// Reject message if it hasn't the appropriate size
		if(len!=sizeof(RoutingMsg)){
			dbg("SRTreeC","\t\tUnknown message received!!!\n");
			return msg;
		}
		
		// Copy the received message in tmp and enqueue it to RoutingReceiveQueue
		atomic{
			memcpy(&tmp,msg,sizeof(message_t));
			enqueueDone=call RoutingReceiveQueue.enqueue(tmp);
		}

		// Check if the enqueue operation was successful 
		if(enqueueDone == SUCCESS){
			post receiveRoutingTask();
		} else {
			dbg("SRTreeC","RoutingMsg enqueue failed!!! \n");
		}
		return msg;
	}
	
	event message_t* DataMaxReceive.receive( message_t * msg , void * payload, uint8_t len){
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;

		msource = call DataMaxAMPacket.source(msg);

		dbg("SRTreeC", "DataMax packet received!!!  from %u \n", msource);

		// Copy the received message in tmp and enqueue it to DataMaxReceiveQueue
		atomic{
			memcpy(&tmp,msg,sizeof(message_t));
			enqueueDone=call DataMaxReceiveQueue.enqueue(tmp);
		}

		// Check if the enqueue operation was successful 
		if(enqueueDone != SUCCESS) dbg("SRTreeC","DataMaxMsg enqueue failed!!! \n");
		return msg;
	}

	event message_t* DataAvgReceive.receive( message_t * msg , void * payload, uint8_t len){
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;

		msource = call DataAvgAMPacket.source(msg);
		
		dbg("SRTreeC", "DataAvg packet received!!!  from %u \n", msource);
		
		// Copy the received message in tmp and enqueue it to DataAvgReceiveQueue
		atomic{
			memcpy(&tmp,msg,sizeof(message_t));
			enqueueDone=call DataAvgReceiveQueue.enqueue(tmp);
		}
		
		// Check if the enqueue operation was successful 
		if(enqueueDone != SUCCESS) dbg("SRTreeC","DataAvgMsg enqueue failed!!! \n");
		
		return msg;
	}
	////////////// Tasks implementations //////////////////////////////
	
	// Start Epoch
	task void startEpoch(){
		int32_t t0;
		jitter = ((call RandomGenerator.rand32() % JITTER) + TOS_NODE_ID) * 1.024 ;

		t0 = -(sim_time()*1.024/10000000 + jitter +(curdepth+1)*OperationWindow);

		dbg("SRTreeC", "startEpoch(): Timer started at %d\n", t0);
		call SlotTimer.startPeriodicAt(t0,EPOCH_PERIOD_MILLI);
	}

	task void sendRoutingTask(){
		uint8_t mlen;
		uint16_t mdest;
		error_t sent;

		

		// Check if queue is empty
		if (call RoutingSendQueue.empty()){
			dbg("SRTreeC","sendRoutingTask(): Q is empty!\n");
			return;
		}
		
		// Dequeue from RoutingSendQueue
		radioRoutingSendPkt = call RoutingSendQueue.dequeue();
		
		// Get the info needed to send the message with RoutingAMSend
		mlen= call RoutingPacket.payloadLength(&radioRoutingSendPkt);
		mdest=call RoutingAMPacket.destination(&radioRoutingSendPkt);

		// Check if the message has the appropriate size
		if(mlen!=sizeof(RoutingMsg)) {
			dbg("SRTreeC","\t\tsendRoutingTask(): Unknown message!!!\n");
			return;
		}

		// Send the message with RoutingAMSend
		sent=call RoutingAMSend.send(mdest,&radioRoutingSendPkt,mlen);
	}

	task void receiveRoutingTask() {
		message_t tmp;
		uint8_t len;
		uint16_t SID;
		message_t radioRoutingRecPkt;
		
		// Dequeue the message from RoutingReceiveQueue
		radioRoutingRecPkt= call RoutingReceiveQueue.dequeue();
		
		// Get its length
		len= call RoutingPacket.payloadLength(&radioRoutingRecPkt);
		
		// dbg("SRTreeC","ReceiveRoutingTask(): len=%u \n",len);
		
		// Processing of radioRoutingRecPkt				
		if(len == sizeof(RoutingMsg)){
			
			// Get the payload of the message
			RoutingMsg * mpkt = (RoutingMsg*) (call RoutingPacket.getPayload(&radioRoutingRecPkt,len));

			// Get the source of the message
			SID = call RoutingAMPacket.source(&radioRoutingRecPkt);

			dbg("SRTreeC" , "receiveRoutingTask():senderID= %d , depth= %d \n", SID , mpkt->depth);
			
			// Case when the node has no parent
			if ( (parentID<0)||(parentID>=65535)) {
				
				// Set the info needed for the node
				parentID= SID;
				curdepth= mpkt->depth + 1;
				COMMAND_TO_RUN = mpkt->cmd;

				call NodeInformation.setDepth(curdepth);
				call NodeInformation.setParent(parentID);
				
				// Begin routing timer if it's a non-root node
				if (TOS_NODE_ID!=0){
					// @TODO : RoutingMsgTimer is deprecated, replace with task
					// call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD);
					post SendRoutingMessage();
				}
				post startEpoch();
			} 
			// else { //case where the node has already a parent, but found one that it's closer to
			// 	//@TODO : This functionality is not endorsed it TAG. To be removed
			// 	if (( curdepth > mpkt->depth +1)){					
			
			// 		parentID= call RoutingAMPacket.source(&radioRoutingRecPkt);//mpkt->senderID;
			// 		curdepth = mpkt->depth + 1;
					
			// 		// Begin routing timer if it's a non-root node
			// 		if (TOS_NODE_ID!=0){

			// 			call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD);
			// 		}
			// 	}
			// }
		}
		else{ // Wrong size of message
			dbg("SRTreeC","receiveRoutingTask():Empty message!!! \n");
			return;
		}
	}

	task void windowTask() {
		message_t tmp;
		
		if (COMMAND_TO_RUN == 1) {  // MAX
			DataMaxMsg* mpkt;
			uint8_t max;

			max = measurement;

			// Iterate through DataMaxReceiveQueue and dequeue every message,
			// comparing their value to current value of the node
			while (!call DataMaxReceiveQueue.empty()) {
				message_t radioDataReceivePkt = call DataMaxReceiveQueue.dequeue();
				uint8_t len = call DataMaxPacket.payloadLength(&radioDataReceivePkt);
				uint16_t msource = call DataMaxAMPacket.source(&radioDataReceivePkt);

				if (msource == parentID) {
					dbg("SRTreeC", "window(): Message Rejected from [%d]\n", msource);
					continue;
				}

				if (len != sizeof(DataMaxMsg)) {
					dbg("SRTreeC", "window(): Unknown message received!!!\n");
					continue;
				}

				mpkt = (DataMaxMsg*) (call DataMaxPacket.getPayload(&radioDataReceivePkt, len));
				if (mpkt->data > max) {
					max = mpkt->data;
				}

				dbg("SRTreeC", "window(): Data Received from %d: Value = %d\n", msource, mpkt->data);
			}
			// If root node, print the results
			if (TOS_NODE_ID == 0) {
				dbg("SRTreeC", "window(): Sending Results to PC\n");
				rootResults(0, max);
			} else { // If non-root node send data to parent
				mpkt = (DataMaxMsg*) (call DataMaxPacket.getPayload(&tmp, sizeof(DataMaxMsg)));

				atomic {
					mpkt->data = max;
				}
				call DataMaxAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
				call DataMaxPacket.setPayloadLength(&tmp, sizeof(DataMaxMsg));

				// Check if the enqueue operation was successful
				if (call DataMaxSendQueue.enqueue(tmp) == SUCCESS) {
					dbg("SRTreeC", "window(): DataMaxMsg enqueued in SendingQueue successfully!!!\n");
					post sendMaxDataTask();
				} else {
					dbg("SRTreeC", "window(): DataMaxMsg failed to be enqueued in SendingQueue!!!\n");
				}
			}
		} else {  // AVG

			// If DataAvgReceiveQueue is empty then send measurement to parent
			if (call DataAvgReceiveQueue.empty()) {

				// Create the message, we need to send

				DataAvgMsg* mpkt = (DataAvgMsg*) (call DataAvgPacket.getPayload(&tmp, sizeof(DataAvgMsg)));

				dbg("SRTreeC", "window(): No Data Received!!!\n");

				atomic {
					mpkt->Sum = measurement;
					mpkt->Count = 1;
				}

				call DataAvgAMPacket.setDestination(&tmp, parentID);
				call DataAvgPacket.setPayloadLength(&tmp, sizeof(DataAvgMsg));

				dbg("SRTreeC", "window(): Sending Measurement [%d] to Parent %d \n", measurement, parentID);

				// Check if the enqueue operation was successful
				if (call DataAvgSendQueue.enqueue(tmp) == SUCCESS) {
					dbg("SRTreeC", "window(): DataAvgMsg enqueued in SendingAvgQueue successfully!!!\n");
					post sendAvgDataTask();
				} else {
					dbg("SRTreeC", "window(): DataAvgMsg failed to be enqueued in SendingAvgQueue!!!\n");
				}
			} else { // If DataAvgReceiveQueue is not empty
				DataAvgMsg* mpkt;
				uint16_t sum;
				uint16_t ChildCount;
				uint8_t len;
				uint16_t msource;
				uint16_t encodedValue;
				uint16_t sumValue;
				uint16_t countValue;
				// dbg("SRTreeC", "window(): Calculating AVG\n");

				sum = measurement;
				ChildCount = 1;

				// Iterate through DataAvgReceiveQueue and dequeue every message,
				// adding their value to the total sum of the node, as also the
				// their children count to the children count of the node 
				while (!call DataAvgReceiveQueue.empty()) {
					atomic{
						radioMessageAvgSendPkt = call DataAvgReceiveQueue.dequeue();
					}
					len = call DataAvgPacket.payloadLength(&radioMessageAvgSendPkt);
					msource = call DataAvgAMPacket.source(&radioMessageAvgSendPkt);

					encodedValue = 0;

					sumValue=0;
					countValue=0;

					if (len != sizeof(DataAvgMsg)) {
						dbg("SRTreeC", "window(): Unknown message received!!!\n");
						continue;
					}

					mpkt = (DataAvgMsg*) (call DataAvgPacket.getPayload(&radioMessageAvgSendPkt, len));
					sumValue = mpkt->Sum;
					countValue = mpkt->Count;
					
					dbg("SRTreeC", "window(): Data Received from %d: ChildCount = %d : Sum = %d\n", msource, countValue,sumValue );
				
					sum += sumValue;
					ChildCount += countValue;
				}

				// If root node, print the results
				if (TOS_NODE_ID == 0) {
					dbg("SRTreeC", "window(): Sending Results to PC\n");
					rootResults(ChildCount, sum);
				} else { // If non-root node send data to parent
					mpkt = (DataAvgMsg*) (call DataAvgPacket.getPayload(&tmp, sizeof(DataAvgMsg)));

					atomic {
						mpkt->Sum = sum;
						mpkt->Count = ChildCount;
					}
					call DataAvgAMPacket.setDestination(&tmp, parentID);
					call DataAvgPacket.setPayloadLength(&tmp, sizeof(DataAvgMsg));

					// Check if the enqueue operation was successful
					if (call DataAvgSendQueue.enqueue(tmp) == SUCCESS) {
						dbg("SRTreeC", "window(): DataAvgMsg enqueued in SendingQueue successfully!!!\n");
						post sendAvgDataTask();
					} else {
						dbg("SRTreeC", "window(): DataAvgMsg failed to be enqueued in SendingQueue!!!\n");
					}
				}
			}
		}

		// Change the value of the node for the next epoch
		updateSensorValue();
	}

	task void sendMaxDataTask() {
		uint8_t mlenMax;
		uint16_t mdestMax;
		error_t sent;

		// If root node do nothing
		if (curdepth == 0) {
			dbg("SRTreeC", "sendMaxDataTask(): ParentID reached!!!\n");
			return;
		}

		//Check if the DataMaxSendQueue is empty
		if (call DataMaxSendQueue.empty()) {
			dbg("SRTreeC", "sendMaxDataTask(): Q is empty!\n");
			return;
		}

		// Dequeue the message from the DataMaxSendQueue
		atomic {
			radioMessageMaxSendPkt = call DataMaxSendQueue.dequeue();
		}

		// Get the info needed to send the message with the DataMaxAMSend
		mlenMax = call DataMaxPacket.payloadLength(&radioMessageMaxSendPkt);
		mdestMax = call DataMaxAMPacket.destination(&radioMessageMaxSendPkt);

		if (mlenMax != sizeof(DataMaxMsg)) {
			dbg("SRTreeC", "\t\tsendMaxDataTask(): Unknown message!!!\n");
			return;
		}

		sent = call DataMaxAMSend.send(mdestMax, &radioMessageMaxSendPkt, mlenMax);

		// How can i check if the message was received ?

		dbg("SRTreeC", "sendMaxDataTask(): %s\n", (sent == SUCCESS) ? "Send returned success!!!" : "Send failed!!!");
	}

	task void sendAvgDataTask(){
		uint8_t mlenAvg;
		uint16_t mdestAvg;
		error_t sent;

		// If root node do nothing
		if (curdepth == 0) {
			dbg("SRTreeC", "sendMaxDataTask(): ParentID reached!!!\n");
			return;
		}

		//Check if the DataAvgSendQueue is empty
		if (call DataAvgSendQueue.empty()) {
			dbg("SRTreeC", "sendAvgDataTask(): Q is empty!\n");
			return;
		}
		
		// Dequeue the message from the DataAvgSendQueue
		atomic{
			radioMessageAvgSendPkt = call DataAvgSendQueue.dequeue();
		}
		
		// Get the info needed to send the message with the DataAvgAMSend
		mlenAvg= call DataAvgPacket.payloadLength(&radioMessageAvgSendPkt);
		mdestAvg=call DataAvgAMPacket.destination(&radioMessageAvgSendPkt);

		if(mlenAvg!=sizeof(DataAvgMsg)) {
			dbg("SRTreeC","\t\tsendAvgDataTask(): Unknown message!!!\n");
			return;
		}

		sent=call DataAvgAMSend.send(mdestAvg,&radioMessageAvgSendPkt,mlenAvg);
		
		dbg("SRTreeC", "sendAvgDataTask(): %s\n", (sent == SUCCESS) ? "Send returned success!!!" : "Send failed!!!");
	}	
}