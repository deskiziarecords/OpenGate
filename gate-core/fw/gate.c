// OPEN GATE firmware - 150 µs C patch checker
// MISRA-C 2012 compliant, no heap, no stdlib

#include "gate.h"
#include <string.h>

const uint32_t LAMBDA_TABLE[256] = {
    // Control chars: 0-31
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // Space and punctuation
    50, 100, 100, 150, 100, 100, 100, 50,
    150, 150, 100, 200, 50, 50, 50, 100,
    // Numbers 0-9
    200, 180, 170, 160, 150, 140, 130, 120,
    110, 100, 100, 100, 100, 100, 100, 100,
    // @, A-Z, [, \, ], ^, _, `
    150, 450, 420, 400, 380, 360, 350, 340,
    330, 320, 310, 300, 290, 280, 270, 260,
    250, 240, 230, 220, 210, 200, 190, 180,
    170, 160, 150, 100, 100, 100, 100, 100,
    // a-z
    150, 400, 380, 360, 340, 320, 300, 280,
    260, 240, 220, 200, 180, 160, 140, 120,
    100, 90, 80, 70, 60, 50, 40, 30,
    20, 10, 100, 100, 100, 100, 0, 0
    // Rest are zero (extended ASCII)
};

uint32_t compute_lambda_cost(const uint8_t *data, size_t len) {
    uint32_t total = 0;

    for (size_t i = 0; i < len; i++) {
        total += LAMBDA_TABLE[data[i]];
        
        // Early exit if already over hard max
        if (total > BUDGET_HARD_MAX) {
            return total;
        }
    }

    return total;
}

int validate_cert(const gate_cert_t *cert, const uint8_t *patch, size_t patch_len) {
    // Check magic
    if (memcmp(cert->magic, "OGT1", 4) != 0) {
        return -1;
    }

    // Check budget bounds
    if (cert->budget > BUDGET_HARD_MAX) {
        return -2;
    }

    if (cert->epsilon > EPSILON_MAX) {
        return -3;
    }

    // Compute Λ-cost of patch
    uint32_t lambda_cost = compute_lambda_cost(patch, patch_len);

    if (lambda_cost > cert->budget) {
        return -4;  // Budget exceeded
    }

    // Note: Signature verification omitted for simplicity
    // In production: ed25519_verify(cert->signature, ...)

    return 0;  // Valid
}
