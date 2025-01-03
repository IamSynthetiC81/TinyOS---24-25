#!/usr/bin/python

from TOSSIM import *
import sys ,os
import random

import LostMessages
import uP_Timing

if len(sys.argv) < 2:
    print "Usage: python mySimulation.py <topology file>"
    sys.exit(1)
else:
    try:
        topo = open(sys.argv[1], "r")
    except:
        print "Topology file not opened!!! \n"
        sys.exit(1)

if topo is None:
    print "Topology file not opened!!! \n"
    sys.exit(1)

t=Tossim([])

if len(sys.argv) < 3:
    print "Usage: python mySimulation.py <topology file> <log file>"
    sys.exit(1)
else:
    try:
        f = open(sys.argv[2], "w")
    except:
        print "Log file not opened!!! \n"
        sys.exit(1)

SIM_END_TIME= 600 * t.ticksPerSecond()

# print "TicksPerSecond : ", t.ticksPerSecond(),"\n"
f.write("TicksPerSecond : %d\n" % t.ticksPerSecond())

t.addChannel("Boot",f)
t.addChannel("RoutingMsg",f)
t.addChannel("NotifyParentMsg",f)
t.addChannel("Radio",f)
#t.addChannel("Serial",f)
t.addChannel("SRTreeC",f)
#t.addChannel("PacketQueueC",f)

r = t.radio()
lines = topo.readlines()
Nodes = []

for line in lines:
    s = line.split()
    if len(s) > 0:
        # print " ", s[0], " ", s[1], " ", s[2]
        f.write(" %s %s %s\n" % (s[0], s[1], s[2]))

        r.add(int(s[0]), int(s[1]), float(s[2]))

        if int(s[0]) not in Nodes:
			Nodes.append(int(s[0]))
        if int(s[1]) not in Nodes:
			Nodes.append(int(s[1]))

Nodes.sort()

print "Creating noise model..."

mTosdir = os.getenv("TINYOS_ROOT_DIR")
noiseF=open(mTosdir+"/tos/lib/tossim/noise/meyer-heavy.txt","r")
lines= noiseF.readlines()
noiseF.close()

print "Reading noise file..."

# Limit the number of noise trace readings to reduce memory usage
max_noise_readings = 1000
noise_readings = []

for line in lines:
    str1 = line.strip()
    if str1:
        val = int(str1)
        noise_readings.append(val)
        if len(noise_readings) >= max_noise_readings:
            break

for i in Nodes:
    try:
        for val in noise_readings:
            t.getNode(i).addNoiseTraceReading(val)
        t.getNode(i).createNoiseModel()
        t.getNode(i).bootAtTime(10 * t.ticksPerSecond() + i)
    except MemoryError:
        print "MemoryError: Could not create noise model for node ", i
        f.write("MemoryError: Could not create noise model for node %d\n" % i)
        break

print "Starting simulation..."
	
ok=False
#if(t.getNode(0).isOn()==True):
#	ok=True
h=True
while(h):
	try:
		h=t.runNextEvent()
		#print h
	except:
		print sys.exc_info()
        # f.write("Exception occurred\n")
#		e.print_stack_trace()

	if (t.time()>= SIM_END_TIME):
		h=False
	if(h<=0):
		ok=False


for i,node in enumerate(Nodes):
	connections = []
	noConnections = []
	for j,altNode in enumerate(Nodes):
		if i!=j and r.connected(node,altNode) and r.connected(altNode,node):
			connections.append(altNode)
		elif i!=j:
			noConnections.append(altNode)
	f.write("Node %d is connected to %s and not connected to %s\n" % (node, connections, noConnections))
    
f.flush()
f.close()

#  wait for the file to close
while f.closed == False:
    pass
print "Running analysis"
LostMessages.runAnalysis(sys.argv[2])
uP_Timing.runAnalysis(sys.argv[2])