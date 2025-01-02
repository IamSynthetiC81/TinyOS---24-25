#ifndef MICROPULSE_H
#define MICROPULSE_H

#define _uP_DATA_MIN_CONSTRAINT_ 20
#define _uP_DATA_MAX_CONSTRAINT_ 60
#define _uP_QUEUE_SIZE_ 100

#define START_AT_EPOCH 5
#if START_AT_EPOCH < 1
    #error "START_AT_EPOCH must be greater than 0"
#endif
#if START_AT_EPOCH > 15
    #error "START_AT_EPOCH must be less than 16"
#endif

enum {
    uP_PHASE_1 = FALSE,
    uP_PHASE_2 = TRUE,
};

/**
* @brief Define the Active Message ID for MicroPulse messages
*/
enum {
    AM_MICROPULSEMSG = 30, 
};

typedef nx_struct MicroPulseMsg {
    nx_uint16_t data;
} MicroPulseMsg;

/**
* @brief Encode the data and phase bit into the last` bit
* @param data the data to be encoded
* @param phase the phase bit to be encoded
* @return true if the data is within the constraints and was successfully encoded
*/
bool encode(uint16_t *data, bool phase){
    // encode the phase bit into the 8th bit
    if (phase) {
        *data |= 1 << 15;
    } else {
        *data &= ~(1 << 15);
    }

    return 1;
}

/**
* @brief Decode the data and phase bit from the last bit
* @param data the data to be decoded
* @param phase the phase bit to be decoded
* @return true if the data was successfully decoded
*/
bool decode(uint16_t *data, bool *phase){
    uint16_t _data = *data & 0x7FFF;
    bool _phase = (*data & 0x8000) >> 15;

    *data = _data;
    *phase = _phase; 

    return 1;
}

/**
* @brief Generate a random data value within the constraints
* @return the random data value
*/
uint8_t uP_randLoad(){
    return (uint8_t) (rand() % (_uP_DATA_MAX_CONSTRAINT_ - _uP_DATA_MIN_CONSTRAINT_ + 1) + _uP_DATA_MIN_CONSTRAINT_);
}

#endif // MICROPULSE_H