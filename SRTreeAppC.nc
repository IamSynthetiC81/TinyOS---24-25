#include "SimpleRoutingTree.h"
#include "MicroPulse.h"

configuration SRTreeAppC @safe() { }
implementation {
    components SRTreeC;

    #if defined(DELUGE)
        components DelugeC;
    #endif

    #ifdef PRINTFDBG_MODE
        components PrintfC;
    #endif

    components MainC, ActiveMessageC;
    
    components new TimerMilliC() as EpochTimerC;
    
    components new AMSenderC(AM_ROUTINGMSG) as RoutingSenderC;
    components new AMReceiverC(AM_ROUTINGMSG) as RoutingReceiverC;
    components new PacketQueueC(SENDER_QUEUE_SIZE) as RoutingSendQueueC;
    components new PacketQueueC(RECEIVER_QUEUE_SIZE) as RoutingReceiveQueueC;

    components new AMSenderC(AM_MAXMSG) as DataMaxSenderC;
    components new AMReceiverC(AM_MAXMSG) as DataMaxReceiverC;
    components new PacketQueueC(SENDER_QUEUE_SIZE) as DataMaxSenderQueueC;
    components new PacketQueueC(RECEIVER_QUEUE_SIZE) as DataMaxReceiverQueueC;

    components new AMSenderC(AM_AVGMSG) as DataAvgSenderC;
    components new AMReceiverC(AM_AVGMSG) as DataAvgReceiverC;
    components new PacketQueueC(SENDER_QUEUE_SIZE) as DataAvgSenderQueueC;
    components new PacketQueueC(RECEIVER_QUEUE_SIZE) as DataAvgReceiverQueueC;

    components new AMSenderC(AM_MICROPULSEMSG) as uPSenderC;
    components new AMReceiverC(AM_MICROPULSEMSG) as uPReceiverC;
    components new PacketQueueC(SENDER_QUEUE_SIZE) as uPSenderQueueC;
    components new PacketQueueC(RECEIVER_QUEUE_SIZE) as uPReceiverQueueC;

    components RandomMlcgC as RandomNumberGeneratorC;

    SRTreeC.Boot -> MainC.Boot;
    SRTreeC.RadioControl -> ActiveMessageC;
    SRTreeC.EpochTimer -> EpochTimerC;

    // Routing
    SRTreeC.RoutingPacket -> RoutingSenderC.Packet;
    SRTreeC.RoutingAMPacket -> RoutingSenderC.AMPacket;
    SRTreeC.RoutingAMSend -> RoutingSenderC.AMSend;
    SRTreeC.RoutingReceive -> RoutingReceiverC.Receive;
    SRTreeC.RoutingReceiveQueue -> RoutingReceiveQueueC;
    SRTreeC.RoutingSendQueue -> RoutingSendQueueC;

    // Max Data packet
    SRTreeC.DataMaxPacket -> DataMaxSenderC.Packet;
    SRTreeC.DataMaxAMPacket -> DataMaxSenderC.AMPacket;
    SRTreeC.DataMaxAMSend -> DataMaxSenderC.AMSend;
    SRTreeC.DataMaxReceive -> DataMaxReceiverC.Receive;
    SRTreeC.DataMaxSendQueue -> DataMaxSenderQueueC;    
    SRTreeC.DataMaxReceiveQueue -> DataMaxReceiverQueueC;

    // Avg Data packet
    SRTreeC.DataAvgPacket -> DataAvgSenderC.Packet;
    SRTreeC.DataAvgAMPacket -> DataAvgSenderC.AMPacket;
    SRTreeC.DataAvgAMSend -> DataAvgSenderC.AMSend;
    SRTreeC.DataAvgReceive -> DataAvgReceiverC.Receive;
    SRTreeC.DataAvgSendQueue -> DataAvgSenderQueueC;    
    SRTreeC.DataAvgReceiveQueue -> DataAvgReceiverQueueC;

    // MicroPulse packet
    SRTreeC.uPPacket -> uPSenderC.Packet;
    SRTreeC.uPAMPacket -> uPSenderC.AMPacket;
    SRTreeC.uPAMSend -> uPSenderC.AMSend;
    SRTreeC.uPReceive -> uPReceiverC.Receive;
    SRTreeC.uPSendQueue -> uPSenderQueueC;    
    SRTreeC.uPReceiveQueue -> uPReceiverQueueC;

    SRTreeC.RandomGenerator -> RandomNumberGeneratorC;
    SRTreeC.GeneratorSeed -> RandomNumberGeneratorC.SeedInit;

	#if defined(DELUGE)
		SRTreeC.Deluge -> DelugeC;
	#endif

	#ifdef PRINTFDBG_MODE
		SRTreeC.Printf -> PrintfC;
	#endif
}
