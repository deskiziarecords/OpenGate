// src/runtime_check.c
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// ROM constants (replace with real values in production)
static const uint8_t ROM_PUBKEY_HASH[32] = {0};  // fill with sha256(pubkey)
static const uint64_t ROM_WCET_NS = 150000;      // 150 us
static const uint8_t ROM_A_MAX = 255;
static const uint8_t ROM_ALLOWED_MON_MASK = 0x1F; // bits for M1..M5

// constant-time memcmp: use library but ensure no early return on target arch,
// or implement bytewise OR comparison to avoid branches.
static int consttime_memcmp(const void *a, const void *b, size_t n) {
  const uint8_t *x = (const uint8_t*)a;
  const uint8_t *y = (const uint8_t*)b;
  uint8_t diff = 0;
  for (size_t i = 0; i < n; i++) diff |= x[i] ^ y[i];
  return diff; // 0 => equal
}

bool runtime_check(const uint8_t *cert512) {
  // 1. Check pubkey hash (32 bytes)
  if (consttime_memcmp(cert512 + 0x00, ROM_PUBKEY_HASH, 32) != 0) return false;
  // 2. Check WCET
  uint64_t wcet = 0;
  for (int i=0;i<8;i++) wcet |= ((uint64_t)cert512[0xB0 + i]) << (8*i);
  if (wcet > ROM_WCET_NS) return false;
  // 3. A_max
  uint8_t amax = cert512[0xC0];
  if (amax > ROM_A_MAX) return false;
  // 4. monitors bitmap
  uint8_t mb = cert512[0xC1];
  if ((mb & ~ROM_ALLOWED_MON_MASK) != 0) return false;
  return true;
}

/* Simple harness to measure cycles / time - platform specific.
   On ARM, use PMU cycle counter or sys timer. Keep measurement code
   outside of hot path in testbench only. */
