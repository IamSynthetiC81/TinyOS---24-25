#ifndef MICROPULSE_H
#define MICROPULSE_H

#define _uP_DATA_MIN_CONSTRAINT_ 20
#define _uP_DATA_MAX_CONSTRAINT_ 60

/**
* @brief Define the Active Message ID for MicroPulse messages
*/
enum {
    AM_MICROPULSEMSG = 30, 
};

typedef nx_struct MicroPulseMsg {
    nx_uint8_t data;
} MicroPulseMsg;

/**
* @brief Encode the data and phase bit into the 8th bit
* @param data the data to be encoded
* @param phase the phase bit to be encoded
* @return true if the data is within the constraints and was successfully encoded
*/
bool encode(uint8_t *data, bool phase){
    // if (*data < _uP_DATA_MIN_CONSTRAINT_ || *data > (1<<7) - 1) {
    //     return 0;
    // }

    // encode the phase bit into the 8th bit
    if (phase) {
        *data |= 0x80;
    } else {
        *data &= 0x7F;
    }

    return 1;
}

/**
* @brief Decode the data and phase bit from the 8th bit
* @param data the data to be decoded
* @param phase the phase bit to be decoded
* @return true if the data was successfully decoded
*/
bool decode(uint8_t *data, bool *phase){
    // decode the phase bit from the 8th bit
    *phase = (*data >> 7) ? 1 : 0;
    *data &= 0x7F;

    if (*data < _uP_DATA_MIN_CONSTRAINT_ || *data > (1<<7) - 1) {
        return 0;
    }

    return 1;
}

/**
* @brief Generate a random data value within the constraints
* @return the random data value
*/
uint8_t uP_randLoad(){
    return (uint8_t) (rand() % (_uP_DATA_MAX_CONSTRAINT_ - _uP_DATA_MIN_CONSTRAINT_ + 1) + _uP_DATA_MIN_CONSTRAINT_);
}

enum {
    uP_PHASE_1 = 0,
    uP_PHASE_2 = 1,
};





#endif // MICROPULSE_H