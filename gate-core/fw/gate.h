// OPEN GATE Λ-table + budget constants
// Extracted from Coq proofs

#ifndef OPEN_GATE_H
#define OPEN_GATE_H

#include <stdint.h>

#define BUDGET_DEFAULT 300000 // pJ
#define BUDGET_HARD_MAX 1000000 // pJ
#define EPSILON_MAX 50000 // pJ side-channel bound

// Λ-table for English orthographic entropy (pJ/letter)
extern const uint32_t LAMBDA_TABLE[256];

// Certificate structure (512 bytes exactly)
typedef struct __attribute__((packed)) {
    uint8_t magic[4]; // "OGT1"
    uint32_t budget; // Λ-budget in pJ
    uint32_t hard_max; // Absolute maximum
    uint32_t epsilon; // Side-channel bound
    uint8_t parent_hash[32]; // SHA-256 of parent cert
    uint8_t patch_hash[32]; // SHA-256 of model patch
    uint8_t signature[64]; // Ed25519 signature
    uint8_t reserved[372]; // Zero-pad to 512 bytes
} gate_cert_t;

// Validate certificate
int validate_cert(const gate_cert_t *cert, const uint8_t *patch, size_t patch_len);

// Compute Λ-cost of buffer
uint32_t compute_lambda_cost(const uint8_t *data, size_t len);

#endif // OPEN_GATE_H
