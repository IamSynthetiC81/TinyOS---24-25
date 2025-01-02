interface NodeInformation
{
    command uint8_t getNodeId();
    command uint8_t getDepth();
    command uint8_t getParent();

    command bool setNodeId(uint8_t id);
    command bool setDepth(uint8_t depth);
    command bool setParent(uint8_t parent);

    command bool isRoot();
    command bool isLeaf();
}