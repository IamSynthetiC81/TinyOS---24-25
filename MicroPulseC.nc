#include "MicroPulse.h"

module MicroPulseC
{
    uses interface Boot;
    uses interface Packet as uPPacket;
	uses interface AMPacket as uPAMPacket;
	uses interface AMSend as uPAMSend;
	uses interface Receive as uPReceive;
	uses interface PacketQueue as uPSendQueue;
	uses interface PacketQueue as uPReceiveQueue;

    uses interface NodeInformation as NodeInformation;

	uses interface Timer<TMilli> as uP_TransmiterTimer;
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

    bool FLAG = FALSE;
    bool uP_ACTIVE = FALSE;

    event void Boot.booted(){
       dbg("SRTreeC", "MicroPulseC booted!!!\n");
       call uP_TransmiterTimer.startPeriodicAt(-sim_time()/10000000000, (START_AT_EPOCH-1) * EPOCH_PERIOD_MILLI);
    }


    event void originalTimer.fired(){
        if (FLAG){
            post uPStart();
            FLAG = FALSE;
        }
    }

    event message_t* uPReceive.receive( message_t * msg , void * payload, uint8_t len){
		error_t enqueueDone;
		message_t tmp;
		MicroPulseMsg* mpkt;
		uint16_t msource;
		uint16_t data;

		// Reject message if it hasn't the appropriate size
		if(len!=sizeof(MicroPulseMsg)){
			dbg("SRTreeC","\t\tUnknown message received!!!\n");
			return msg;
		}

		msource = call uPAMPacket.source(msg);

		// Get the data from the message
		mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(msg, len));
        data = mpkt->data;
		
        // dbg("SRTreeC", "uPReceive.receive(): Received data = %x\n", data);
		decode(&data, &uP_Phase);
        // dbg("SRTreeC", "uPReceive.receive(): Decoded data = %x with %d phase\n", data, uP_Phase);

		if (uP_Phase == uP_PHASE_2){
			/*
				1. tune window
				2. send data to children
			*/

			if (call uPAMPacket.source(msg) != call NodeInformation.getParent()){
                dbg("SRTreeC", "MicroPulse packet rejected!!!  from %u \n", msource);
				return msg;
			}

			dbg("SRTreeC", "MicroPulse packet containing [%d] received!!!  from %u\n", data, msource);

			uP_parrent_load = data;
			
			mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));

			data = uP_parrent_load + uP_node_load;
			encode(&data, 1);
			atomic {
				mpkt->data = data; 
			}
			
			// enque the message to uPSendQueue
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
			dbg("SRTreeC", "MicroPulse packet containing [%d] received!!!  from %u \n", data, msource);
			// Copy the received message in tmp and enqueue it to uPReceiveQueue

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
		// dbg("SRTreeC", "A MicroPulse package sent... %s \n",(err==SUCCESS)?"True":"False");
		// setLostMeasurementSendTask(err==SUCCESS);
	}

	event void uP_TransmiterTimer.fired(){
        // call originalTimer.stop();
        call uP_TransmiterTimer.stop();
        parentID = call NodeInformation.getParent();
        curdepth = call NodeInformation.getDepth();

        FLAG = TRUE;

        dbg("SRTreeC", "uP_TransmiterTimer.fired(): curdepth = %d, parentID = %d\n", curdepth, parentID);

        // post uPStart();

        // call uP_TransmiterTimer.startPeriodicAt(EPOCH_PERIOD_MILLI-(curdepth*2)*OperationWindow), EPOCH_PERIOD_MILLI);
        return;


		// message_t tmp;
		// error_t err;
		// MicroPulseMsg* mpkt;
		// uint8_t data;
		
		// // Check if the uPSendQueue is full
		// if(call uPSendQueue.empty()){
		// 	dbg("uP_TransmiterTimer", "uP_SendQueue is empty...\n");
		// 	return;
		// }

		// // Get a pointer to the payload of the temporary message
		// mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));

		// if(mpkt==NULL){
		// 	dbg("SRTreeC","uP_TransmiterTimer.fired(): No valid payload... \n");
		// 	return;
		// }
		// data = uP_node_load;
		// if (!encode(&data, uP_Phase)){
		// 	dbg("SRTreeC", "uP_TransmiterTimer.fired(): Encoding failed!!!\n");
		// 	return;
		// }

		// // Set the value of the message
		// atomic{
		// 	mpkt->data = data;
		// }

		// call uPAMPacket.setDestination(&tmp, parentID);
		// call uPPacket.setPayloadLength(&tmp, sizeof(MicroPulseMsg));

		// // send the message
		// err = call uPAMSend.send(parentID, &tmp, sizeof(MicroPulseMsg));

		// if(err == SUCCESS){
		// 	dbg("SRTreeC", "uP_TransmiterTimer.fired(): Send returned success!!!\n");
		// }else{
		// 	dbg("SRTreeC", "uP_TransmiterTimer.fired(): Send failed!!!\n");
		// }
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
    }

    task void uP_RootHandler(){
        // send data to children
        uint16_t pkt;
        message_t tmp;
        MicroPulseMsg* mpkt;
        error_t err;

        mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));
        pkt = uP_node_load + uP_parrent_load;

        encode(&pkt,uP_PHASE_2);

        atomic {
            mpkt->data = pkt;
        }

        call uPAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
        call uPPacket.setPayloadLength(&tmp, sizeof(MicroPulseMsg));

        dbg("SRTreeC", "uP_RootHandler(): Sending data to children: %d\n", pkt-(1<<7));

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
            
            // @TODO : Program enters this block, and the message is not received
            // if (len != sizeof(MicroPulseMsg)) {
            // 	dbg("SRTreeC", "uPStart(): Unknown message received!!!\n");
            // 	continue;
            // }

            len = call uPPacket.payloadLength(&radio_uP_SendPkt);
            msource = call uPAMPacket.source(&radio_uP_SendPkt);

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

        if (uP_Phase == uP_PHASE_1){
            /*
                2. Generate a random uP_node_load value
                3. Encode the data value and phase bit
                4. Send the encoded data value to the parent node
            */

            uP_child_load = data;

            mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));

            // @TODO : Question --> Does the root node need a random uP_node_load value?
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

                call uPAMPacket.setDestination(&tmp, parentID);
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

            // call EpochTimer.startPeriodicAt(sim_time()/10000000000 - bootTime - jitter-curdepth*OperationWindow,EPOCH_PERIOD_MILLI);
            // epoch6_start = (sim_time()/10000000000 - bootTime) + jitter + curdepth*OperationWindow;

            // if(TOS_NODE_ID == 0){
            //     window_lower_lim = epoch6_start + EPOCH_PERIOD_MILLI - uP_node_load;
            //     window_upper_lim = epoch6_start + EPOCH_PERIOD_MILLI;
            // } else {
            //     window_lower_lim = epoch6_start + EPOCH_PERIOD_MILLI - uP_parrent_load- uP_node_load;
            //     window_upper_lim = epoch6_start + EPOCH_PERIOD_MILLI - uP_parrent_load;
            // }
            
            // @TODO : tune the window timer so that it fires when the children finish their tasks
            // epoch must start after the children finish their tasks at the lower limit of the window
            // call EpochTimer.startPeriodicAt(window_lower_lim, EPOCH_PERIOD_MILLI);
            // call uP_TransmiterTimer.startPeriodicAt(window_upper_lim, EPOCH_PERIOD_MILLI);
            
            mpkt = (MicroPulseMsg*) (call uPPacket.getPayload(&tmp, sizeof(MicroPulseMsg)));

            // encode(&data, 1);		// redundant
            // if (TOS_NODE_ID == 0){
            //     atomic {
            //         mpkt->data = max; //max
            //     }
            // } else {
            //     atomic {
            //         mpkt->data = uP_parrent_load-uP_node_load; //parent load
            //     }
            // }
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
        uint32_t epoch6_start = ((START_AT_EPOCH+1)*EPOCH_PERIOD_MILLI - sim_time()/10000000000);
        uint32_t window_lower_lim, window_upper_lim;

        uP_ACTIVE = TRUE;

        dbg("SRTreeC", "uP_TimerTune(): epoch6_start = %d\nNode load = %d, Parrent load = %d, Child load = %d\n", epoch6_start, uP_node_load, uP_parrent_load, uP_child_load);

        window_lower_lim = epoch6_start + EPOCH_PERIOD_MILLI - uP_parrent_load- uP_node_load+50;
        window_upper_lim = epoch6_start + EPOCH_PERIOD_MILLI - uP_parrent_load;
        
        call originalTimer.startPeriodicAt(window_lower_lim, EPOCH_PERIOD_MILLI);
        // call uP_TransmiterTimer.startPeriodicAt(window_upper_lim, EPOCH_PERIOD_MILLI);

        call uP_TransmiterTimer.stop();
    }	
}