// OPEN GATE C bindings (single header)
#ifndef OPEN_GATE_SINGLE_HEADER
#define OPEN_GATE_SINGLE_HEADER

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Λ-table (same as firmware)
extern const uint32_t OPEN_GATE_LAMBDA_TABLE[256];

// Compute Λ-cost
uint32_t open_gate_compute_cost(const uint8_t *data, size_t len);

// Certificate structure
typedef struct {
    uint8_t magic[4];
    uint32_t budget;
    uint32_t hard_max;
    uint32_t epsilon;
    uint8_t parent_hash[32];
    uint8_t patch_hash[32];
    uint8_t signature[64];
} open_gate_cert_t;

// Validate certificate
bool open_gate_validate(const open_gate_cert_t *cert,
                       const uint8_t *patch,
                       size_t patch_len);

#ifdef __cplusplus
}
#endif

#endif // OPEN_GATE_SINGLE_HEADER
