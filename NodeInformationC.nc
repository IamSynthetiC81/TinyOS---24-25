generic module NodeInformationC()
{
    provides interface NodeInformation;
} implementation {
    uint8_t nodeID;
    uint8_t depth;
    uint8_t parent;
    
    command bool NodeInformation.setNodeId(uint8_t id){
        nodeID = id;
        return TRUE;
    }

    command uint8_t NodeInformation.getNodeId(){
        return nodeID;
    }
    
    command uint8_t NodeInformation.getDepth(){
        return depth;
    }
    
    command uint8_t NodeInformation.getParent(){
        return parent;
    }
    
    command bool NodeInformation.setDepth(uint8_t d){
        depth = d;
        return TRUE;
    }
    
    command bool NodeInformation.setParent(uint8_t p){
        parent = p;
        return TRUE;
    }
    
    command bool NodeInformation.isRoot(){
        return parent == 0;
    }
    
    command bool NodeInformation.isLeaf(){
        // unimplemented
        return FALSE;
    }
}