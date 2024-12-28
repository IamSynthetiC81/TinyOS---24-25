#!/usr/bin/python

from TOSSIM import *
import sys ,os
import random

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
f=sys.stdout
# f = open("logfile.txt", "w")
SIM_END_TIME= 640 * t.ticksPerSecond()

print "TicksPerSecond : ", t.ticksPerSecond(),"\n"

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
        print " ", s[0], " ", s[1], " ", s[2]
        r.add(int(s[0]), int(s[1]), float(s[2]))

        if int(s[0]) not in Nodes:
			Nodes.append(int(s[0]))
        if int(s[1]) not in Nodes:
			Nodes.append(int(s[1]))

numberOfNodes = len(Nodes)

for node in range(0,max(Nodes)+1):
	m=t.getNode(node)
	m.bootAtTime(10*t.ticksPerSecond() + node)

mTosdir = os.getenv("TINYOS_ROOT_DIR")
noiseF=open(mTosdir+"/tos/lib/tossim/noise/meyer-heavy.txt","r")
lines= noiseF.readlines()

for line in  lines:
	str1=line.strip()
	if str1:
		val=int(str1)
		for i in range(0,max(Nodes)+1):
			t.getNode(i).addNoiseTraceReading(val)
noiseF.close()
for i in range(0,max(Nodes)+1):
	t.getNode(i).createNoiseModel()
	
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
#		e.print_stack_trace()

	if (t.time()>= SIM_END_TIME):
		h=False
	if(h<=0):
		ok=False


for i,node in enumerate(Nodes):
	connections = []
	for j,altNode in enumerate(Nodes):
		if i!=j and r.connected(node,altNode) and r.connected(altNode,node):
			connections.append(altNode)
	# connections contains integers of nodes connected to node. print them in the format "Node %d" is connected to Node %d, Node %d, Node %d
	print "Node ",node," is connected to ",connections