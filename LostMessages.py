import sys
from collections import OrderedDict as OD
from asciitree import LeftAligned
from asciitree.drawing import BoxStyle

def importFile(filename):
    with open(filename, 'r') as file:
        data = file.readlines()
    return data

def mapTree(data):
    tree = {}
    map = {}
    # parse data starting from the end
    for line in (data):
        if "receiveRoutingTask()" in line:
            line = line.split()
            node = line[2].replace("(", "").replace(")", "").replace(":", "")

            if node == '0':
                parent = '0'
                depth = '0'
            else:   
                parent = line[4]
                depth = int(line[7])+1

            # print(line)

            # if the node is not in the map, add it
            if node not in map:
                map[node] = {"node": node, "parent": parent, "depth": depth}

        elif line.startswith('Node'):
            line = line.split()
            node = line[1]
            neighbors = []

            # iterate through the neighbors of the node (from the 5th element to the last element)
            for nodes in line[5:]:
                if nodes == 'and':
                    break
                # remove brackets and commas from the string if they exist
                nodes = nodes.replace('[', '')
                nodes = nodes.replace(']', '')
                nodes = nodes.replace('\n', '')
                nodes = nodes.replace(',', '')
                # append the node to the tree
                neighbors.append(nodes)
            
            tree[node] = neighbors
            # print "Node is ", node, " and the neighbors are ", neighbors

    # sort the tree dictionary
    return tree,map

def NodesMissing(tree, map):
    # the tree is a dictionary with the node as the key and the neighbors as the value. This is as it should be
    # the map is a dictionary with the node as the key and the parent and depth as the value. This come from the simulatins
    # the two results should coincide if the simulation is correct
    missingNodes = []

    # iterate through the tree
    for node in tree:
        # if the node is not in the map, print the node
        if node not in map:
            missingNodes.append(node)

    return missingNodes

def getChildren(map, missingNodes):
    # the map is a dictionary with the node as the key and the parent and depth as the value. This come from the simulatins
    # missingNodes is a list of nodes that are missing in the map
    # node 0 is the root node

    children = []

    # get the childred of each node as depicted in the simulation
    for node in map:
        if node in missingNodes:
            continue

        # get the parent of the node
        parent = map[node]['parent']

        # get the children of the node
        childrenList = []
        for child in map:
            if map[child]['parent'] == node and child != node:
                childrenList.append(child)

        # add the children to the list of children
        children.append({'node':node, 'parent':parent, 'children': childrenList})
    return children

def MessagesLost(lines, children, missingNodes, logfile = None):
    # lines is the data from the log file
    # children is the a list of dictionaries with the node, parent and children
    # find if any messages from the children are lost

    if logfile != None:
        try :
            f = open(logfile, 'a')
            f.write("\nPrinting the messages lost :\n")
        except:
            print("Log file not opened!!! \n")
            exit()

    messages = {}

    for child in children:
        node = child['node']
        messages[node] = [[], child['children']]

    # get the messages from the log file
    for line in lines:
        if "Epoch: " in line:
            line = line.split()
            epoch = int(line[-1])

            if epoch is 1:
                messages[node][0] = messages[node][1]
                continue

            node = line[2].replace("(", "").replace(")", "").replace(":", "")
            
            if len(messages[node][0]) != len(messages[node][1]):
                # which element is missing
                missing = list(set(messages[node][1]) - set(messages[node][0]))
                if len(missing) > 0:
                    print "Node ", node, " is missing messages from ", missing, " on epoch ", epoch-1

                    if logfile != None:
                        f.write("Node %s is missing messages from %s on epoch %d\n" % (node, missing, epoch-1))
            messages[node][0] = []
            continue
        if "window():" in line:
            if 'No Data Received' in line:
                line = line.split()
                node = line[2].replace("(", "").replace(")", "").replace(":", "")

                # if children[int(node)-1]['
                #     continue

                
            elif 'Data Received from ' in line:
                # 0:0:49.748046915 DEBUG (4): calculateData(): Data Received from 5: Value = 36
                line = line.split()
                node = line[2].replace("(", "").replace(")", "").replace(":", "")
                sender = line[7].replace(":", "")
                data = line[-1]

                # f.write("Node %s received data from %s: %s\n" % (node, sender, data))

                messages[node][0].append(sender)

def build_tree(node_list, root_node):
    """
    Recursively builds a tree from a list of nodes.

    Args:
        node_list (list): List of dictionaries representing nodes and their children.
        root_node (str): The current node to process.

    Returns:
        dict: The tree structure as a nested dictionary.
    """
    tree = OD()

    for node in node_list:
        if node['node'] == root_node:
            # Add children recursively
            for child in node['children']:
                tree[child] = build_tree(node_list, child)

    return tree

def print_ascii_tree(node_list, logfile = None):
    """
    Prints an ASCII representation of the tree.

    Args:
        node_list (list): List of dictionaries representing nodes and their children.
    """

    if logfile != None:
        print("Printing the tree to the log file")
        try :
            f = open(logfile, 'a')
            f.write("\nPrinting the tree :\n")
        except:
            print "Log file not opened!!! \n"
            exit()
    tree = OD()

    # Identify root nodes (nodes that are not children of any other node)
    all_nodes = {node['node'] for node in node_list}
    child_nodes = {child for node in node_list for child in node['children']}
    root_nodes = all_nodes - child_nodes

    # Build the tree for each root node
    for root in root_nodes:
        tree[root] = build_tree(node_list, root)

    # Print the tree using asciitree
    tr = LeftAligned()
    if logfile != None:
        # tr = LeftAligned(draw=BoxStyle(gfx = BoxStyle.GFX_DOUBLE, horiz_len=1))
        f.write(tr(tree))
    f.write("\n")

    print(tr(tree))

def runAnalysis(filename):
    if filename == None:
        print("Please provide the log file as an argument")
        exit()

    try:
        lines = importFile(filename)
    except:
        print("Log file not opened!!! \n")
        exit()
    tree, map = mapTree(lines)
    

    children = getChildren(map, NodesMissing(tree, map))
    children = sorted(children, key=lambda i: i['node'])

    print_ascii_tree(children, filename)

    print("\nMessages Lost: ")
    MessagesLost(lines, children, NodesMissing(tree, map), filename)

if __name__ == "__main__":
    if sys.argv[1] == None:
        print("Please provide the log file as an argument")
        exit()

    try:
        lines = importFile(sys.argv[1])
    except:
        print("Log file not opened!!! \n")
        exit()
    tree, map = mapTree(lines)

    children = getChildren(map, NodesMissing(tree, map))
    children = sorted(children, key=lambda i: i['node'])

    print_ascii_tree(children)

    MessagesLost(lines, children, NodesMissing(tree, map))



