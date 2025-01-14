import re
import os
import errno

import matplotlib.pyplot as plt
# in a headless environment, use the following
plt.switch_backend('agg')
import numpy as np

_plotDir='Analysis/plots/'

def parse_logfile(logfile):
    node_data = {}
    pattern = re.compile(r'(\d+:\d+:\d+\.\d+) DEBUG \((\d+)\): Epoch: (\d+)')
    
    try :
        file = open(logfile, 'r')
    except FileNotFoundError:
        print('File not found')
        return

    lines = file.readlines()
    file.close()

    for line in lines:
        if 'Epoch' in line:
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
        ms = [x[0]*10**-(9+6) for x in node_data[node]]
        # ms*10**-(9+6) to convert to ms

        plt.plot(epochs, ms, label="Node " + str(node))

    plt.xlabel("Epoch")
    plt.ylabel("Time (ms)")
    plt.title("Time vs Epoch")
    plt.legend()
    plt.grid()
    plt.savefig(_plotDir + "Time_vs_Epoch.png")

    plt.clf()

def plot_epoch_start(node_data):
    '''plot for each epoch when each node starts'''
    # each epoch is 40s. Plot the start time of each node for each epoch
    epochs = []
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
        time = [x['time']*10**-(9+3) for x in timesets[node]]
        epoch = [x['epoch'] for x in timesets[node]]
        plt.plot(epoch, time, 'o', label="Node " + str(node), color=colours[i])

    # have ytics in scientific notation
    plt.ticklabel_format(style='sci', axis='y', scilimits=(0,0))
    plt.xlabel("Epoch")
    plt.ylabel("Time (ms)")
    plt.title("Time vs Node")
    plt.legend(loc='center left', bbox_to_anchor=(0.9, 0.5))
    plt.grid()
    plt.savefig(_plotDir + "Node Timings.png")
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
    plt.savefig(_plotDir + "Node Timings Zoomed.png")
    plt.clf()
    
def plot_radio_usage(logfile):
    epoch = 1
    radio_open = []
    radio_close = []

    # read the logfile
    try :
        logfile = open(logfile, 'r')
    except FileNotFoundError:
        print('File not found')
        return

    for line in logfile:
        if 'Epoch' in line:
            epoch = int(line.split(' ')[-1])
        if 'Radio is now open' in line:
            # 0:5:19.800781270 DEBUG (4): RadioControl.startDone(): Radio is now open
            node = int(line.split(' ')[2].split(')')[0].split('(')[1])
            # print('Node ' + str(node) + ' opened radio at epoch ' + str(epoch))

            time = line.split(' ')[0].split(':')

            if len(radio_open)-1 == epoch:
                print 'Epoch ' + str(epoch) + ' not in radio_open'
                # i get IndexError: list index out of range
                # radio_open[epoch] = []
                radio_open.append([])
            # print(radio_open)
            # radio_open[epoch-1].append((node, int(time[0])*3600*1e9 + int(time[1])*60*1e9 + float(time[2])*1e9))

        if 'Radio is now closed' in line:
            # 0:5:19.800781270 DEBUG (4): RadioControl.stopDone(): Radio is now closed
            node = int(line.split(' ')[-2][1:-1])
            print('Node ' + str(node) + ' closed radio at epoch ' + str(epoch))

            time = line.split(' ')[0].split(':')

            radio_close[epoch].append((node, int(time[0])*3600*1e9 + int(time[1])*60*1e9 + float(time[2])*1e9))

    # plot the data
    for i,node in enumerate(radio_open):
        time = [x[1] for x in radio_open[node]]
        node = [x[0] for x in radio_open[node]]
        plt.plot(node, time, 'o', label="Open", color='red')

        time = [x[1] for x in radio_close[node]]
        node = [x[0] for x in radio_close[node]]
        plt.plot(node, time, 'o', label="Close", color='blue')

    plt.xlabel("Node")
    plt.ylabel("Time (ns)")
    plt.title("Radio Usage")
    plt.legend()
    plt.grid()
    plt.savefig(_plotDir + "Radio Usage.png")

def runAnalysis(logfile, plotDir='Analysis/plots/'):
    if logfile == None:
        print('No logfile provided')
        return

    if plotDir != None:
        _plotDir = plotDir


    dirs = _plotDir.split('/')
    path = ''
    for dir in dirs:
        path = os.path.join(path, dir)
        try:
            os.mkdir(path)
        except OSError as e:
            if e.errno == errno.EEXIST:
                pass
            else:
                raise
    # except OSError as e:
    #     if e.errno == errno.EEXIST:
    #         pass
    #     else:
    #         raise

    node_data = parse_logfile(logfile)

    plot_timing_diagram(node_data)
    plot_epoch_start(node_data)
    # plot_radio_usage(logfile)