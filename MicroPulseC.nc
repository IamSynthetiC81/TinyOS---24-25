#include "MicroPulse.h"

module MicroPulseC
{
    uses interface Packet as uPPacket;
	uses interface AMPacket as uPAMPacket;
	uses interface AMSend as uPAMSend;
	uses interface Receive as uPReceive;
	uses interface PacketQueue as uPSendQueue;
	uses interface PacketQueue as uPReceiveQueue;

    uses interface NodeInformation as NodeInformation;

    uses interface Timer<TMilli> as originalTimer;
} implementation {
    task void uPsendTask();
	task void uPStart();
    task void uP_TimerTune();

    message_t radio_uP_SendPkt;

    uint16_t uP_node_load 	= 0;
    uint16_t uP_parrent_load = 0;
    uint16_t uP_child_load 	= 0;
    bool 	uP_Phase 		= uP_PHASE_1;

    uint8_t curdepth;
    uint8_t parentID;

    uint8_t epochCounter = 0;

    bool uP_Tasking = TRUE;

    event void originalTimer.fired(){
        epochCounter++;
        dbg("SRTreeC", "originalTimer.fired(): epochCounter = %d at %d\n", epochCounter, call originalTimer.getNow());
        if (epochCounter == START_AT_EPOCH){
            dbg("SRTreeC", "MicroPulseC booted!!!\n");
            parentID = call NodeInformation.getParent();
            curdepth = call NodeInformation.getDepth();
            post uPStart();
        }
    }

    event message_t* uPReceive.receive( message_t * msg , void * payload, uint8_t len){
		error_t enqueueDone;
		message_t tmp;
		MicroPulseMsg* mpkt;
		uint16_t msource, data;


		// Reject message if it hasn't the appropriate size
		if(len!=sizeof(MicroPulseMsg)){
			dbg("SRTreeC","\t\tUnknown message received!!!\n");
			return msg;
		}

        mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(msg, len));
		msource = call uPAMPacket.source(msg);
        data = mpkt->data;
        decode(&data, &uP_Phase);

        

        if(!uP_Tasking && uP_Phase == uP_PHASE_1){
            dbg("SRTreeC", "uPReceive.receive(): Denied uPkt from %u\n", msource);
            return msg;
        }

        dbg("SRTreeC", "uPReceive.receive(): uPulse packet received from %d\n", msource);

		if (uP_Phase == uP_PHASE_2){
			/*
				1. tune window
				2. send data to children
			*/

			if (msource != call NodeInformation.getParent()){
                dbg("SRTreeC", "uPulse packet rejected!!!  from %u \n", msource);
				return msg;
			}

			dbg("SRTreeC", "uPulse phase 2 packet containing [%d] received!!!  from %u \n", data, msource);

			uP_parrent_load = data;
			
			mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));

			data = uP_parrent_load + uP_node_load;
			encode(&data, 1);
			atomic {
				mpkt->data = data; 
			}
			
			call uPAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
			call uPPacket.setPayloadLength(&tmp, sizeof(MicroPulseMsg));

			enqueueDone = call uPSendQueue.enqueue(tmp);
			if (enqueueDone == SUCCESS) {
				dbg("SRTreeC", "uPReceive.receive(): uPMsg enqueued in uPSendQueue successfully!!!\n");
                post uPsendTask();
			} else {
				dbg("SRTreeC", "uPReceive.receive(): uPMsg failed to be enqueued in uPSendQueue!!!\n");
			}
		} else {
			dbg("SRTreeC", "uP phase 1 packet containing [%d] received!!!  from %u \n", data, msource);

            atomic{
				memcpy(&tmp,msg,sizeof(message_t));
				enqueueDone=call uPReceiveQueue.enqueue(tmp);
			}

			// Check if the enqueue operation was successful 
			if (enqueueDone == SUCCESS) {
				dbg("SRTreeC", "uPReceive.receive(): uPMsg enqueued in uPReceiveQueue successfully!!!\n");
                // post uPsendTask();
			} else {
				dbg("SRTreeC", "uPReceive.receive(): uPMsg failed to be enqueued in uPReceiveQueue!!!\n");
			}	
		}
		return msg;
	}

	event void uPAMSend.sendDone(message_t * msg , error_t err){
		uP_Tasking = FALSE;
	}

    task void uPsendTask(){
        uint8_t mlen;
        uint16_t mdest;
        error_t sent;

        if (call uPSendQueue.empty()) {
            dbg("SRTreeC","post uPsendTask(): Q is empty!\n");
            return;
        }

        // Dequeue from uPSendQueue
        radio_uP_SendPkt = call uPSendQueue.dequeue();

        // Get the info needed to send the message with uPAMSend
        mlen = call uPPacket.payloadLength(&radio_uP_SendPkt);
        mdest = call uPAMPacket.destination(&radio_uP_SendPkt);

        // Check if the message has the appropriate size
        if (mlen != sizeof(MicroPulseMsg)) {
            dbg("SRTreeC","\t\tpost uPsendTask(): Unknown message!!!\n");
            return;
        }

        // Send the message with uPAMSend
        sent = call uPAMSend.send(mdest, &radio_uP_SendPkt, mlen);

        // Check if the message was sent successfully and set the flag Busy to true
        if (sent == SUCCESS) {
            dbg("SRTreeC","post uPsendTask(): Send returned success!!!\n");
            if(uP_Phase == uP_PHASE_2){
                post uP_TimerTune();
            }
        } else {
            dbg("SRTreeC","send failed!!!\n");
        }
        uP_Tasking = TRUE;
    }

    task void uP_RootHandler(){
        // send data to children
        uint16_t pkt, bare_data;
        message_t tmp;
        MicroPulseMsg* mpkt;
        error_t err;

        mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));
        // pkt = uP_node_load + uP_parrent_load;
        pkt = uP_node_load + uP_child_load;
        bare_data = pkt;

        uP_Phase = uP_PHASE_2;
        dbg("SRTreeC", "Encoded data = %d, %d\n", pkt, uP_PHASE_2);
        encode(&pkt,uP_PHASE_2);
        dbg("SRTreeC", "Encoded data = %d\n", pkt);

        atomic {
            mpkt->data = pkt;
        }

        call uPAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
        call uPPacket.setPayloadLength(&tmp, sizeof(MicroPulseMsg));

        dbg("SRTreeC", "uP_RootHandler(): Sending data to children: %d\n", bare_data);

        if (call uPSendQueue.enqueue(tmp) == SUCCESS) {
            dbg("SRTreeC", "uP_RootHandler(): MicroPulseMsg enqueued in SendingQueue successfully!!!\n");
            post uPsendTask();
        } else {
            dbg("SRTreeC", "uP_RootHandler(): MicroPulseMsg failed to be enqueued in SendingQueue!!!\n");
        }
    }

    task void uPStart(){
        uint16_t data = 0, max = 0;
        uint16_t window_lower_lim = -1;
        uint16_t window_upper_lim = -1;
        uint16_t epoch6_start = -1;
        uint16_t msource = -1;
        uint8_t len = -1;
        message_t tmp;
        error_t err;
        MicroPulseMsg *mpkt;

        // Read any incoming data from the uPReceiveQueue
        while(!call uPReceiveQueue.empty()){
            atomic{
                radio_uP_SendPkt = call uPReceiveQueue.dequeue();
            }
            
            len = call uPPacket.payloadLength(&radio_uP_SendPkt);
            msource = call uPAMPacket.source(&radio_uP_SendPkt);

            //@TODO : Program enters this block, and the message is not received
            if (len != sizeof(MicroPulseMsg)) {
            	dbg("SRTreeC", "uPStart(): Unknown message received!!!\n");
            	continue;
            }

            mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&radio_uP_SendPkt, len));

            atomic {
                data = mpkt->data;
            }

            decode(&data, &uP_Phase);

            if (uP_Phase == 0 && data > max) {
                max = data;
            }

            dbg("SRTreeC", "uPStart(): uPulse packet received from %d with data = %d and phase %d\n", msource, data, uP_Phase);
        }

        uP_Tasking = FALSE;

        if (uP_Phase == uP_PHASE_1){
            /*
                2. Generate a random uP_node_load value
                3. Encode the data value and phase bit
                4. Send the encoded data value to the parent node
            */

            uP_child_load = data;

            mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));

            // @TODO : Question --> Does the root node need a random uP_node_load value or as SINK it has 0 load ?
            uP_node_load =  uP_randLoad();
            data = uP_node_load + max;

            dbg("SRTreeC", "uPStart(): uP_node_load = %d and uP_child_load = %d\n", uP_node_load, uP_child_load);

            if (TOS_NODE_ID == 0) {
                dbg("SRTreeC", "uPStart(): Phase 1 complete. CriticalPath is %d\n", data);
                uP_Phase = uP_PHASE_2;
                post uP_RootHandler();
            }else {
                encode(&data, 0);
                atomic {
                    mpkt->data = data;
                }

                call uPAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
                call uPPacket.setPayloadLength(&tmp, sizeof(MicroPulseMsg));

                // enqueue the message
                if (call uPSendQueue.enqueue(tmp) == SUCCESS) {
                    dbg("SRTreeC", "uPStart(): MicroPulseMsg enqueued in SendingQueue successfully!!!\n");
                    post uPsendTask();
                } else {
                    dbg("SRTreeC", "uPStart(): MicroPulseMsg failed to be enqueued in SendingQueue!!!\n");
                }

                
            }
        } else if (uP_Phase == uP_PHASE_2){
            /*
                1. tune window
                2. send data to children
            */

            uP_parrent_load = data;
            mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));

            atomic{
                mpkt->data = uP_parrent_load + uP_node_load;
            }

            call uPAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
            call uPPacket.setPayloadLength(&tmp, sizeof(MicroPulseMsg));

            if (call uPSendQueue.enqueue(tmp) == SUCCESS) {
                dbg("SRTreeC", "uP_Phase(): MicroPulseMsg enqueued in SendingQueue successfully!!!\n");
                post uPsendTask();
            } else {
                dbg("SRTreeC", "uP_Phase(): MicroPulseMsg failed to be enqueued in SendingQueue!!!\n");
            }

        }
    }	

    task void uP_TimerTune(){
        uint32_t epoch5_start = ((START_AT_EPOCH)*EPOCH_PERIOD_MILLI - sim_time()/10000000000);
        uint32_t window_lower_lim;
        dbg("SRTreeC", "uP_TimerTune(): getNow() = %d\n",call originalTimer.getNow());
        dbg("SRTreeC", "uP_TimerTune(): epoch5_start = %d\nNode load = %d, Parrent load = %d, Child load = %d\n", epoch5_start, uP_node_load, uP_parrent_load, uP_child_load);

        window_lower_lim = epoch5_start - uP_parrent_load - uP_node_load;
        
        call originalTimer.startPeriodicAt(window_lower_lim, EPOCH_PERIOD_MILLI);
    }	
}