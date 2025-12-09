# OpenGate Certificate Format (512 Bytes)

**Version**: v25.03  
**Purpose**: Immutable safety certificate that bundles patch metadata, budget constraints, and empirical bounds into a single hardware-verifiable unit.

---

## Overview

Every OpenGate patch is accompanied by a **512-byte certificate** that contains:
1. **Cryptographic identity** (what code is this?)
2. **Empirical safety bounds** (how much side-channel leakage?)
3. **Budget constraints** (how many tokens can it use?)
4. **Monitor configuration** (which safety checks are active?)
5. **Provenance chain** (which governance vote approved this?)

The certificate is immutable (signed by governance) and verifiable in **≤ 150 µs** on hardware.

---

## Byte Layout (Little-Endian)

```
Offset  Length  Field Name                    Type         Description
------  ------  -------------------------     ------       -----------
0x00    32      certificate_pubkey_hash       [u8; 32]     SHA-256(governance_pubkey)
0x20    16      signature (MAC)               [u8; 16]     Poly1305 or AES-GCM tag
0x30    32      leakage_hash                  [u8; 32]     H(ε || TVLA || MASCOT || DL)
0x50    64      patch_manifest_hash           [u8; 64]     SHA-512 truncated
0x90    32      parent_patch_hash             [u8; 32]     Hash of previous patch
0xB0    8       WCET_ns                       u64_le       Worst-case time (nanoseconds)
0xB8    8       ΔB_budget                     u64_le       Budget delta (pJ)
0xC0    1       A_max                         u8           Max agents (default: 255)
0xC1    1       monitors_bitmap               u8           M1–M5 enable flags
0xC2    6       reserved                      [u8; 6]      Must be zero
0xC8    200     reserved / future             [u8; 200]    Pad to 512 bytes
```

**Total**: 512 bytes (exactly)

---

## Field Descriptions

### 0x00–0x1F: Governance Public Key Hash (32 bytes)

**Field**: `certificate_pubkey_hash`  
**Type**: `[u8; 32]` (SHA-256 digest)  
**Value**: SHA-256(governance_pubkey)

**Purpose**: Identify which governance key approved this certificate.

**How it's used**:
1. Certificate arrives at device
2. Device checks: is SHA-256(cert.pubkey) in ROM allowlist?
3. If no → REJECT
4. If yes → verify signature (next field)

**Immutability**: The ROM contains a list of approved governance keys. Only a new hardware deployment can change this list.

**Example**:
```
0x00: 3f 45 2a 1b 7c d8 9e 42 ... (32 bytes total)
```

---

### 0x20–0x2F: Authentication Tag (16 bytes)

**Field**: `signature (MAC)`  
**Type**: `[u8; 16]` (Poly1305 or AES-GCM authentication tag)  
**Value**: Poly1305(key=governance_privkey, message=0x30..0x4F)

**Purpose**: Authenticate that governance signed this certificate.

**Algorithm**:
```
MAC = Poly1305(
    key = HMAC-SHA256(governance_privkey, "opengate-v25.03"),
    message = cert[0x30:0x4F]  // leakage_hash || patch_manifest_hash
)
```

**Verification** (constant-time):
```c
uint8_t expected_mac[16] = compute_mac(govkey, cert);
uint8_t actual_mac[16] = cert[0x20:0x2F];

uint8_t equal = constant_time_compare(expected_mac, actual_mac, 16);
if (!equal) return REJECT;
```

**WCET**: < 10 µs (Poly1305 is very fast)

---

### 0x30–0x4F: Leakage Hash (32 bytes)

**Field**: `leakage_hash`  
**Type**: `[u8; 32]` (SHA-256 or truncated)  
**Value**: H(ε || TVLA_score || MASCOT_score || DL_score)

**Purpose**: Commit to side-channel leakage bounds without storing 50 kB of TVLA traces in the certificate.

**How it's computed** (offline, during certification):

```python
import hashlib

# Side-channel measurements (from lab)
epsilon = 0.03125  # 2^-5 bits (MASCOT result)
tvla_score = 3.2   # t-test result
mascot_score = 2e-5  # bits of information
dl_score = 128      # bits of security margin

# Serialize as fixed-width fields
epsilon_bytes = struct.pack('<f', epsilon)       # 4 bytes, little-endian float
tvla_bytes = struct.pack('<f', tvla_score)       # 4 bytes
mascot_bytes = struct.pack('<d', mascot_score)   # 8 bytes, little-endian double
dl_bytes = struct.pack('<I', int(dl_score))      # 4 bytes, uint32

# Concatenate
data = epsilon_bytes + tvla_bytes + mascot_bytes + dl_bytes  # 20 bytes

# Hash (any extra space is zero-padded to 32 bytes)
leakage_hash = hashlib.sha256(data).digest()
assert len(leakage_hash) == 32
```

**Runtime verification**:
```c
// Precomputed hash is stored in ROM
uint8_t expected_leakage_hash[32] = { ... };

// Computed from certificate
uint8_t actual_leakage_hash[32] = cert[0x30:0x4F];

// Check (constant-time)
if (constant_time_compare(expected, actual, 32) != 0) {
    return REJECT;  // Leakage bounds don't match ROM
}
```

**Why hash instead of store?**
- Storing all TVLA traces would require 50 kB (not 512 bytes)
- Hash commits to measurements without storing them
- Measurements are stored off-chain (IPFS) with immutable CID

---

### 0x50–0x8F: Patch Manifest Hash (64 bytes)

**Field**: `patch_manifest_hash`  
**Type**: `[u8; 64]` (SHA-512 or two SHA-256)  
**Value**: SHA-512_truncated(patch code || dependencies || version)

**Purpose**: Cryptographically bind the certificate to the actual patch code.

**How it's computed**:
```python
patch_code = open("patch.bin", "rb").read()
dependencies = serialize([
    ("opengate-runtime", "0.25.3"),
    ("coq-kernel", "8.18.0"),
    ("..."),
])
version = b"v25.03"

manifest = patch_code + dependencies + version
patch_manifest_hash = hashlib.sha512(manifest).digest()[:64]
```

**Runtime verification**:
```c
// Compute hash of patch code received
uint8_t computed_manifest[64] = sha512_truncated(patch_code, dependencies, version);

// Compare to certificate
if (constant_time_compare(computed_manifest, cert[0x50:0x8F], 64) != 0) {
    return REJECT;  // Patch code doesn't match certificate
}
```

**Why 64 bytes?**
- SHA-512 produces 64 bytes
- Truncated to 64 bytes (not 32) for extra collision resistance
- Patch code is often > 100 kB; need strong hash

---

### 0x90–0xAF: Parent Patch Hash (32 bytes)

**Field**: `parent_patch_hash`  
**Type**: `[u8; 32]` (SHA-256)  
**Value**: SHA-256(previous_patch_certificate)

**Purpose**: Create an immutable **provenance chain** (hash-linked list).

**How it's used**:

```
Patch 1:
  parent_hash = 0x000...   (genesis)
  hash = SHA256(cert1)

Patch 2:
  parent_hash = SHA256(cert1)
  hash = SHA256(cert2)

Patch 3:
  parent_hash = SHA256(cert2)
  hash = SHA256(cert3)
```

**Runtime check**:
```c
// At boot, load last known good patch hash from provenance metadata
uint8_t last_good_patch[32] = load_from_battery_backed_ram();

// New certificate arrives; check its parent
if (constant_time_compare(cert[0x90:0xAF], last_good_patch, 32) != 0) {
    return REJECT;  // Parent hash doesn't match; chain is broken
}

// Update provenance metadata
save_to_battery_backed_ram(cert_hash);
```

**Why provenance matters**:
- Auditors can replay patch history
- Governance changes are immutable (each patch records who approved it)
- Rollback is easy (just point to an earlier hash)

**Immutability**: 
- Hash chain is stored in battery-backed RAM
- If RAM is corrupted, rollback detects it (hash doesn't match)
- Device automatically falls back to last good patch

---

### 0xB0–0xB7: WCET in Nanoseconds (8 bytes)

**Field**: `WCET_ns`  
**Type**: `u64` (little-endian)  
**Unit**: Nanoseconds  
**Range**: 0 – 2⁶⁴ − 1 ns (≈ 585 years)

**Purpose**: Commit to worst-case execution time bound (proved in Lean).

**Typical value**: 150,000 ns (150 µs)

**How it's verified**:
```c
uint64_t wcet_ns = *(uint64_t*)&cert[0xB0];

// Check: WCET ≤ 150 µs (150,000 ns)
if (wcet_ns > 150000) {
    return REJECT;  // WCET too high; unsafe
}

// Measure actual execution time
uint64_t start = read_timer();
apply_patch();
uint64_t end = read_timer();

// Log if we exceeded budget (shouldn't happen if proof is correct)
if ((end - start) > wcet_ns) {
    log_violation("WCET exceeded");
}
```

**Why WCET in certificate?**
- Proves that patch was certified to run in bounded time
- Governance can require WCET < 100 µs for real-time systems
- Enables composition theorems (if two patches each have WCET ≤ 75 µs, composition has WCET ≤ 150 µs)

---

### 0xB8–0xBF: Budget Delta (8 bytes)

**Field**: `ΔB_budget`  
**Type**: `u64` (little-endian)  
**Unit**: picojoules (pJ)  
**Typical range**: 0.5 × 10⁹ – 5 × 10⁹ pJ

**Purpose**: Charge this much budget when patch is applied.

**How it's used**:
```c
uint64_t delta_b = *(uint64_t*)&cert[0xB8];

// Check budget
uint64_t current_budget = load_budget();
if (current_budget + delta_b > B_MAX) {
    return REJECT;  // Would exceed budget limit
}

// Apply patch and deduct budget
apply_patch();
save_budget(current_budget - delta_b);  // Note: subtract, not add
```

**Why subtract?**
- Model: budget is a resource that gets consumed
- Larger patches consume more budget
- When budget is exhausted, no more patches can run

**Budget recovery**:
- Budget resets per request (or per day, configurable by governance)
- Governance votes to increase B_MAX (loose constraint)
- Governance votes to decrease B_MIN (tighter constraint)

**Proof connection**:
- Theorem `entropy_conservation` proves: ΔB = λ(patch_code)
- λ (lambda) is the Coq-proven token cost function
- Runtime verifies λ_proof ≤ ΔB_cert (safety margin)

---

### 0xC0: A_max (1 byte)

**Field**: `A_max`  
**Type**: `u8` (unsigned byte)  
**Default**: 255  
**Range**: 0 – 255

**Purpose**: Limit the number of agents (sub-components) the patch can spawn.

**How it's used**:
```c
uint8_t a_max = cert[0xC0];

// Monitor M2 checks: number of agents ≤ A_max
if (num_agents > a_max) {
    log_violation("Agent limit exceeded");
    trigger_rollback();
}
```

**Example use**:
- Default: A_max = 255 (no agent limit)
- Restrictive: A_max = 1 (must be single-threaded)
- Medium: A_max = 16 (up to 16 parallel agents)

**Why needed?**
- Some patches spawn many agents (mixture-of-experts models)
- Governance may want to limit parallelism (for debugging or safety)
- M2 monitor enforces this constantly

**Governance tuning**:
- Governance votes to decrease A_max (restrict parallelism)
- Useful for real-time systems or resource-constrained hardware

---

### 0xC1: Monitors Bitmap (1 byte)

**Field**: `monitors_bitmap`  
**Type**: `u8` (bit flags)  
**Bits**: 0–5 (bit 0 = M1, bit 5 = M5; bits 6–7 reserved)

**Purpose**: Enable/disable monitors M1 through M5 for this patch.

**Bit layout**:
```
Bit  Monitor  Enabled?  Purpose
---  -------  --------  ---------------------------------------------------
0    M1       1=yes     Budget monitor (check ΔB_budget)
1    M2       1=yes     Agent counter (check A_max)
2    M3       1=yes     Token-rate monitor (detect rapid-fire requests)
3    M4       1=yes     Cache-eviction monitor (randomize eviction, log variance)
4    M5       1=yes     Power-cap monitor (sample EM, log >3σ deviations)
5    M6       1=yes     Semantic monitor (regex-scan output, log matches)
6    reserved 0         Must be zero
7    reserved 0         Must be zero
```

**How it's used**:
```c
uint8_t mon_bitmap = cert[0xC1];

// Check which monitors are enabled
if (mon_bitmap & (1 << 0)) {
    // M1 is enabled; run budget check
    if (current_budget + delta_b > B_MAX) return REJECT;
}

if (mon_bitmap & (1 << 2)) {
    // M3 is enabled; check token rate
    if (requests_per_second > TOKEN_RATE_LIMIT) log_violation();
}

if (mon_bitmap & (1 << 5)) {
    // M6 is enabled; scan output for blacklist patterns
    if (m6_regex_match(output, m6_blacklist)) trigger_rollback();
}
```

**Typical values**:
```
0x3F = 0b00111111 = all monitors enabled (M1–M6)
0x07 = 0b00000111 = only M1, M2, M3 enabled
0x01 = 0b00000001 = only M1 enabled
```

**Why disable monitors?**
- Some patches are well-tested; can skip slow monitors
- Real-time systems may disable expensive monitors (M4, M5)
- Governance can require all monitors (min 0x3F)

---

### 0xC2–0xC7: Reserved (6 bytes)

**Field**: `reserved`  
**Type**: `[u8; 6]`  
**Value**: Must all be `0x00`

**Purpose**: Space for future fields (backward compatibility).

**How it's checked**:
```c
for (int i = 0; i < 6; i++) {
    if (cert[0xC2 + i] != 0x00) {
        return REJECT;  // Reserved field not zero
    }
}
```

**Future use**: If we need to add fields in v26.Q1, we can repurpose these 6 bytes without breaking v25.03 compatibility (old devices will reject new certificates with non-zero reserved fields, prompting upgrade).

---

### 0xC8–0x1FF: Padding / Future Use (200 bytes)

**Field**: `reserved / future`  
**Type**: `[u8; 200]`  
**Value**: Can be anything (not checked by v25.03)

**Purpose**: Reserve space for future extensions (M7–M10 monitors, new fields, etc.).

**Total size maintained**: Always 512 bytes (even if padding is unused).

---

## Certificate Validation (Runtime Algorithm)

**Input**: Certificate (512 bytes) from patch sender  
**Output**: ACCEPT or REJECT (≤ 150 µs)

```c
bool validate_certificate(uint8_t cert[512]) {
    // 1. Verify pubkey hash is in ROM allowlist (< 1 µs)
    uint8_t cert_pubkey_hash[32] = {cert[0x00:0x1F]};
    if (!is_allowed_pubkey(cert_pubkey_hash)) {
        return false;  // Not signed by approved governance
    }

    // 2. Verify MAC (< 10 µs, Poly1305)
    uint8_t expected_mac[16] = compute_poly1305(govkey, cert[0x30:0x4F]);
    if (constant_time_compare(expected_mac, cert[0x20:0x2F], 16) != 0) {
        return false;  // Signature invalid
    }

    // 3. Check leakage hash matches ROM (< 1 µs)
    uint8_t rom_leakage_hash[32] = load_from_rom("leakage_hash_v25.03");
    if (constant_time_compare(rom_leakage_hash, cert[0x30:0x4F], 32) != 0) {
        return false;  // Leakage bounds don't match
    }

    // 4. Check WCET (< 1 µs)
    uint64_t wcet_ns = *(uint64_t*)&cert[0xB0];
    if (wcet_ns > ROM_WCET_LIMIT) {  // ROM_WCET_LIMIT = 150000
        return false;  // WCET too high
    }

    // 5. Check budget (< 1 µs)
    uint64_t delta_b = *(uint64_t*)&cert[0xB8];
    if (current_budget + delta_b > B_MAX) {
        return false;  // Would exceed budget
    }

    // 6. Verify parent hash (< 1 µs)
    uint8_t last_good_hash[32] = load_from_battery_backed_ram();
    if (constant_time_compare(last_good_hash, cert[0x90:0xAF], 32) != 0) {
        return false;  // Provenance chain broken
    }

    // 7. Verify reserved fields are zero (< 1 µs)
    for (int i = 0; i < 6; i++) {
        if (cert[0xC2 + i] != 0x00) {
            return false;  // Reserved field not zero
        }
    }

    // All checks passed
    return true;  // Total: < 150 µs
}
```

---

## Example Certificate (Hex Dump)

```
Offset  Hex Data (16 bytes per line)
------  ----------------
0x00    3f 45 2a 1b 7c d8 9e 42 | c3 aa b2 11 9e 7f 3c 4d
0x10    a1 b2 c3 d4 e5 f6 7a 8b | 9c 0d 1e 2f 3a 4b 5c 6d
0x20    78 9a bc de f0 12 34 56 | 78 9a bc de f0 12 34 56
0x30    aa bb cc dd ee ff 00 11 | 22 33 44 55 66 77 88 99
0x40    a1 b2 c3 d4 e5 f6 7a 8b | 9c 0d 1e 2f 3a 4b 5c 6d
0x50    11 22 33 44 55 66 77 88 | 99 aa bb cc dd ee ff 00
0x60    01 02 03 04 05 06 07 08 | 09 0a 0b 0c 0d 0e 0f 10
0x70    11 12 13 14 15 16 17 18 | 19 1a 1b 1c 1d 1e 1f 20
0x80    21 22 23 24 25 26 27 28 | 29 2a 2b 2c 2d 2e 2f 30
0x90    a1 b2 c3 d4 e5 f6 7a 8b | 9c 0d 1e 2f 3a 4b 5c 6d
0xA0    [... snip ...]

0xB0    80 84 02 00 00 00 00 00  // WCET_ns = 0x000002848 = 150000 ns
0xB8    00 ca 9a 3b 00 00 00 00  // ΔB_budget = 0x3b9aca00 = 1000000000 pJ
0xC0    ff                        // A_max = 255
0xC1    3f                        // monitors_bitmap = 0x3f (all enabled)
0xC2    00 00 00 00 00 00        // reserved (all zeros)

0xC8    [padding to 0x1FF, all zeros]
0x1F0   00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00
0x1F8   00 00 00 00 00 00 00 00  // Total: 512 bytes
```

---

## Governance Integration

When governance votes to change a parameter, a new certificate is issued:

```
Governance Vote:
  Parameter: B_MIN
  Old value: 2.1 × 10⁹ pJ
  New value: 2.7 × 10⁹ pJ
  Voting: 2/3 stake + 1/2 constitutional (all approved)

Result:
  New certificate is generated with:
    - parent_patch_hash = SHA256(old_cert)
    - ΔB_budget = 2.7 × 10⁹ (new value)
    - signature = Poly1305(govkey_private, cert_data)
  
  Certificate is immutably logged on-chain
  Devices download and apply new certificate
  Audit trail is permanent
```

---

## Security Properties

### 1. Non-Repudiation
Once a certificate is signed, governance cannot deny signing it (signature is unforgeable under HMAC-SHA256).

### 2. Immutability
Hash chain makes it impossible to rewrite history without detection (changing one cert breaks all subsequent hashes).

### 3. Integrity
Any bit-flip in the certificate is caught by MAC verification (Poly1305 is collision-resistant).

### 4. Freshness
Parent hash ensures patches form a strict ordering (no out-of-order application).

### 5. Auditability
Every parameter change is logged on-chain with:
- Timestamp
- Who voted (public key)
- Old value / new value
- Voting result (votes for / against)

---

## Storage & Distribution

### Where certificates live:

| Location | Content | Read/Write | Mutable? |
|----------|---------|------------|----------|
| **ROM (on-chip)** | Pubkey allowlist, WCET limit, approved leakage hash | Read-only | No (requires reboot) |
| **Battery-backed RAM** | Provenance chain (last 8 patch hashes) | Read/Write | Yes (volatile on power loss) |
| **IPFS** | Full patch code, dependencies | Content-addressed | No (immutable by design) |
| **Ethereum L2** | Governance votes, parameter change history | Append-only | No (blockchain immutable) |

---

## Backward Compatibility

**Version field**: Not in certificate itself; encoded in hash or governance contract address.

**Future versions**:
- v26.Q1: Will use certificate format v2.0 (different hash, new fields)
- v25.03 devices: Will reject v2.0 certificates (can be forced to upgrade via governance vote)
- Migration: Governance votes to "approve v2.0 certificates"; ROM is updated

---

## Implementation Checklist

- [ ] Certificate generation tool (governance creates certs)
- [ ] Certificate validation code (runtime check, < 150 µs)
- [ ] Provenance storage (battery-backed RAM)
- [ ] IPFS integration (upload/download patch code)
- [ ] Ethereum L2 integration (governance voting)
- [ ] Audit tools (replay certificate history)
- [ ] Error handling (what if certificate is corrupt?)

