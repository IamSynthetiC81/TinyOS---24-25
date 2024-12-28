

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

def MessagesLost(lines, children, missingNodes):
    # lines is the data from the log file
    # children is the a list of dictionaries with the node, parent and children
    # find if any messages from the children are lost

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
                print "Node ", node, " is missing messages from ", missing, " on epoch ", epoch-1
            messages[node][0] = []
            continue
        if "calculateData():" in line:
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

                if sender in messages[node][0]:
                    print 'error'
                else:
                    messages[node][0].append(sender)

from collections import OrderedDict as OD
from asciitree import LeftAligned
from asciitree.drawing import BoxStyle


    
def print_ascii_tree(node_list):

    tree = OD()
    for node in node_list:
        tree[node['node']] = OD()
        for child in node['children']:
            tree[node['node']][child] = OD()
        # next level
        for child in node['children']:
            for child2 in node_list:
                if child == child2['node']:
                    for child3 in child2['children']:
                        tree[node['node']][child][child3] = OD()
                    for child3 in child2['children']:
                        for child4 in node_list:
                            if child3 == child4['node']:
                                for child5 in child4['children']:
                                    tree[node['node']][child][child3][child5] = OD()
                                for child5 in child4['children']:
                                    for child6 in node_list:
                                        if child5 == child6['node']:
                                            for child7 in child6['children']:
                                                tree[node['node']][child][child3][child5][child7] = OD()
                                            for child7 in child6['children']:
                                                for child8 in node_list:
                                                    if child7 == child8['node']:
                                                        for child9 in child8['children']:
                                                            tree[node['node']][child][child3][child5][child7][child9] = OD()
                                                        for child9 in child8['children']:
                                                            for child10 in node_list:
                                                                if child9 == child10['node']:
                                                                    for child11 in child10['children']:
                                                                        tree[node['node']][child][child3][child5][child7][child9][child11] = OD()
                                                                    for child11 in child10['children']:
                                                                        for child12 in node_list:
                                                                            if child11 == child12['node']:
                                                                                for child13 in child12['children']:
                                                                                    tree[node['node']][child][child3][child5][child7][child9][child11][child13] = OD()
                                                                                for child13 in child12['children']:
                                                                                    for child14 in node_list:
                                                                                        if child13 == child14['node']:
                                                                                            for child15 in child14['children']:
                                                                                                tree[node['node']][child][child3][child5][child7][child9][child11][child13][child15] = OD()
                                                                                            for child15 in child14['children']:
                                                                                                for child16 in node_list:
                                                                                                    if child15 == child16['node']:
                                                                                                        for child17 in child16['children']:
                                                                                                            tree[node['node']][child][child3][child5][child7][child9][child11][child13]

    tr = LeftAligned()
    print(tr(tree))

# Example usage:
lines = importFile('log.log')
tree, map = mapTree(lines)

children = getChildren(map, NodesMissing(tree, map))
children = sorted(children, key=lambda i: i['node'])

# print("Children:", children)  # Debugging line to check children list

print_ascii_tree(children)
MessagesLost(lines, children, NodesMissing(tree, map))



