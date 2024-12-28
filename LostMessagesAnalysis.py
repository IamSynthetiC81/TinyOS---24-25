

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
            #0:0:10.007614141 DEBUG (1): receiveRoutingTask():senderID= 0 , depth= 0 
            line = line.split()
            node = line[2].replace("(", "").replace(")", "").replace(":", "")
            parent = line[4]
            depth = line[7]

            # print(line)

            # map[node] = [parent, depth]
            # if the node is not in the map, add it
            if node not in map:
                map[node] = {"parent": parent, "depth": depth}

        elif line.startswith('Node'):
            line = line.split()
            node = line[1]
            neighbors = []

            # iterate through the neighbors of the node (from the 5th element to the last element)
            for nodes in line[5:]:
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

def nodeChildren(tree, map, missingNodes):
    # the map is a dictionary with the node as the key and the parent and depth as the value. This come from the simulatins
    # the tree is a dictionary with the node as the key and the neighbors as the value. This is as it should be
    # missingNodes is a list of nodes that are missing in the map
    # node 0 is the root node

    children = []

    # get the childred of each node as depicted in the simulation
    for node in tree:
        if node in missingNodes:
            continue

        if node == '0':
            children.append({'node':node,'parent': 'None', 'children': tree.get(node)})
            continue

        # get the parent of the node
        parent = map[node]['parent']

        childrenList = tree.get(node)
        childrenList.remove(parent)

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

                



lines = importFile('log.log')
tree, map = mapTree(lines)

children = nodeChildren(tree, map, NodesMissing(tree, map))
children = sorted(children, key = lambda i: i['node'])

MessagesLost(lines, children , NodesMissing(tree, map))



