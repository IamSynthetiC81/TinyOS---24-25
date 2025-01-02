import sys
import re
import os
from datetime import datetime

import matplotlib.pyplot as plt
import numpy as np

# from LostMessageAnalysis import *

plotDir = "Analysis/plots/"

def parse_logfile(logfile):
    node_data = {}
    pattern = re.compile(r'(\d+:\d+:\d+\.\d+) DEBUG \((\d+)\): Epoch: (\d+)')

    with open(logfile, 'r') as file:
        for line in file:
            if 'Epoch' not in line:
                continue

            match = pattern.search(line)
            if match:
                nanoseconds = match.group(1).split(':') 
                nanoseconds = int(nanoseconds[0]) * 3600 * 1e9 + int(nanoseconds[1]) * 60 * 1e9 + float(nanoseconds[2]) * 1e9

                node = match.group(2)
                epoch = match.group(3)

                node = int(node)
                epoch = int(epoch)
                
                if node not in node_data:
                    node_data[node] = []
                node_data[node].append((nanoseconds, epoch))
    
    return node_data


def plot_timing_diagram(node_data):
    ''' Each node should start at epoch*40-window*depth
    find how much each node is off by for each epoch
    '''
    for node in node_data:
        epochs = [x[1] for x in node_data[node]]
        nanoseconds = [x[0] for x in node_data[node]]

        plt.plot(epochs, nanoseconds, label="Node " + str(node))

    plt.xlabel("Epoch")
    plt.ylabel("Time (ns)")
    plt.title("Time vs Epoch")
    plt.legend()
    plt.grid()
    plt.savefig(plotDir + "Time_vs_Epoch.png")

    plt.clf()

def plot_epoch_start(node_data):
    '''plot for each epoch when each node starts'''
    # each epoch is 40s. Plot the start time of each node for each epoch
    for node in node_data:
        epochs = [x[1] for x in node_data[node]]
        nanoseconds = [x[0] for x in node_data[node]]
    dataset = []
    maxEpoch = max(epochs) # should be 15

    # assign a colour to each node dynamicaly
    colours = plt.cm.rainbow(np.linspace(0, 1, len(node_data)))


    for epoch in range(1,maxEpoch):
        for node in node_data:
            for data in node_data[node]:
                # if data[0] > (epoch+1)*40*1e9 :
                #     print("Node " + str(node) + " started at " + str(data[0]) + " in epoch " + str(data[1]))
                #     break
                if data[1] == epoch:
                    time = data[0] - (epoch)*40*1e9
                    data = {'node': node, 'epoch': epoch, 'time': time}
                    dataset.append(data)
                    break

    
    # sort the data into timesets for each node
    timesets = {}
    for node in dataset:
        if node['node'] not in timesets:
            timesets[node['node']] = []
        timesets[node['node']].append(node)

    for node in timesets:
        timesets[node].sort(key=lambda x: x['epoch'])

    # plot the data
    for i,node in enumerate(timesets):
        time = [x['time'] for x in timesets[node]]
        epoch = [x['epoch'] for x in timesets[node]]
        plt.plot(epoch, time, 'o', label="Node " + str(node), color=colours[i])

    plt.xlabel("Epoch")
    plt.ylabel("Time (ns)")
    plt.title("Time vs Node")
    plt.legend(loc='center left', bbox_to_anchor=(0.9, 0.5))
    plt.grid()
    plt.savefig(plotDir + "Node Timings.png")
    plt.clf()

    # zoom in on the 6:end epochs
    for i,node in enumerate(timesets):
        time = [x['time'] for x in timesets[node] if x['epoch'] > 5]
        epoch = [x['epoch'] for x in timesets[node] if x['epoch'] > 5]
        plt.plot(epoch, time, 'o', label="Node " + str(node), color=colours[i])

    plt.xlabel("Epoch")
    plt.ylabel("Time (ns)")
    plt.title("Time vs Node")
    plt.legend(loc='center left', bbox_to_anchor=(0.9, 0.5))
    plt.grid()
    plt.savefig(plotDir + "Node Timings Zoomed.png")
    plt.clf()
    

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python uP_TimingAnalysis.py <logfile>")
        sys.exit(1)

    # if plotDir does not exist, create it
    try:
        os.mkdir(plotDir)
    except FileExistsError:
        pass

    logfile = sys.argv[1]
    node_data = parse_logfile(logfile)

    plot_timing_diagram(node_data)
    plot_epoch_start(node_data)