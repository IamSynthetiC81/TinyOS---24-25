import sys
import re
import os
from datetime import datetime

import matplotlib.pyplot as plt
import numpy as np

plotDir = "plots/"

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
    fig, ax = plt.subplots()

    # time diagram for each node
    for node, data in node_data.items():
        data = np.array(data)
        ax.plot(data[:, 0], data[:, 1], label='Node {}'.format(node), marker='o')

    ax.set_xlabel('Time (microseconds)')
    ax.set_ylabel('Epoch')
    ax.set_ylim(0.5, 15.5)
    ax.set_yticks(range(1, 16))

    ax.set_title('Epoch vs Time per Node')
    ax.legend()
    plt.grid()
    print('Saving plot at {}'.format(plotDir + "EpochTiming"))
    plt.savefig(plotDir + "EpochTiming.png")

def plot_timing_diff_between_nodes(node_data):
    '''
    Plot the difference in timing between neighbouring nodes
    ex . node_1[epoch_1] - node_0[epoch_1], node_2[epoch_1] - node_1[epoch_1], etc.
    '''

    fig, ax = plt.subplots()

    prev_node = None

    for node in node_data.keys():
        if prev_node is not None:
            node_data_1 = np.array(node_data[prev_node])
            node_data_2 = np.array(node_data[node])

            time_diff = node_data_2[:, 0] - node_data_1[:, 0]

            ax.plot(node_data_1[:, 1], time_diff, label='Node {} - Node {}'.format(node, prev_node), marker='o')

        prev_node = node

    ax.set_xlabel('Epoch')
    ax.set_ylabel('Time Difference')
    ax.set_title('Time Difference between neighbouring nodes')
    ax.legend()
    plt.grid()
    print('Saving plot at {}'.format(plotDir + "TimeDiffBetweenNodes"))
    plt.savefig(plotDir + "TimeDiffBetweenNodes.png")



def detect_rate_change(node_data):
    min = None
    max = None

    for node, data in node_data.items():
        data = np.array(data)
        time_diff = (np.diff(data[:, 0]))
        tdd = np.diff(time_diff).astype(int)

        if max is None or np.max(time_diff) > max:
            max = int(np.max(time_diff))
        if min is None or np.min(time_diff) < min:
            min = int(np.min(time_diff))

        plt.plot(time_diff, label='Node {}'.format(node), marker='o')
        plt.xlabel('Time')
        plt.ylabel('Time Difference')
        plt.title('Time Difference vs Time')

        # print where the rate change occurs
        rate_change = np.where(tdd != 0)
        if len(rate_change[0]) > 0:
            # print('Node {}: MicroPulse effect detected at {}'.format(node, rate_change[0] + 1)) 
            # write this in green
            print('\033[92m' + 'Node {}'.format(node, rate_change[0] + 1) + '\033[0m'+ ': MicroPulse effect detected at {}')
        else:
            # print in red
            print('\033[91m' + 'Node {}'.format(node, rate_change[0] + 1) + '\033[0m' + ': No MicroPulse effect detected')

    plt.legend()
    plt.ylim(min*0.9, max*1.1)
    plt.yticks(range(min, max + 1))
    plt.grid()
    print('Saving plot at {}'.format(plotDir + "rate_change.png"))
    plt.savefig(plotDir + "rate_change.png")

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

    detect_rate_change(node_data)
    plot_timing_diagram(node_data)
    plot_timing_diff_between_nodes(node_data)