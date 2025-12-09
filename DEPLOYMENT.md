# DEPLOYMENT: OpenGate Step-by-Step

**Target Audience**: System integrators, DevOps engineers, safety teams

**Estimated Time**: 2-4 hours initial setup, 1 hour ongoing governance

**Prerequisites**: Linux/Unix environment, Ethereum L2 RPC access, ARM/RISC-V hardware with PMP

---

## Phase 0: Pre-Deployment Checklist

Before you start, verify:

- [ ] Hardware is ARM Cortex-R52 or RISC-V with PMP (memory protection)
- [ ] Firmware bootloader supports SHA-256 + ECDSA verification
- [ ] Battery-backed RAM is present (≥512 kB for checkpoints)
- [ ] Team has read `THREAT_MODEL.md` and accepted residual risks
- [ ] You have Ethereum L2 testnet access (for initial governance setup)
- [ ] You have at least 3 people who can serve as constitutional seat holders (human, civil-society, regulator)

If any of these are missing, **do not proceed**. OpenGate requires all three layers (ℳ₁ proven, ℳ₄ empirical, ℳ₃ governance) to work.

---

## Phase 1: Verify Proofs (Local, No Hardware Needed)

### Step 1.1: Install Proof Checkers

```bash
# Install Coq
sudo apt-get update && sudo apt-get install -y coq

# Install Lean
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh
source $HOME/.elan/toolchain

# Verify installation
coqc --version
lean --version
```

### Step 1.2: Clone OpenGate and Verify Proofs

```bash
git clone https://github.com/deskiziarecords/OpenGate.git
cd OpenGate/gate-core

# Compile Coq proofs
coq_makefile -f _CoqProject -o Makefile.coq
make -f Makefile.coq

# Should output:
# COQC Entropy.v
# COQC ComposeBudget.v
# (etc.)
# All targets verified.

# Compile Lean proofs
lean Rollback.lean
# Should output:
# Rollback.olean
# (no errors)
```

### Step 1.3: Verify Proof Artifact Checksums

```bash
# Download checksums from GitHub release
curl -s https://api.github.com/repos/deskiziarecords/OpenGate/releases/latest \
  | jq -r '.assets[] | select(.name=="proof-checksums.txt") | .browser_download_url' \
  | xargs curl -o proof-checksums.txt

# Verify checksums
sha256sum -c proof-checksums.txt
# Should output:
# gate-core/Entropy.v: OK
# gate-core/ComposeBudget.v: OK
# gate-core/Rollback.lean: OK
```

**If checksums don't match**: Do NOT proceed. Contact security@open-gate.io.

### Step 1.4: Review Extraction & C Code

```bash
# Look at the extracted C code that will run on hardware
cat gate-core/extraction/lambda_cost.c

# Spot-check: does it match the Coq semantics?
# - Input: vector of bytes
# - Output: sum of lambda_table lookups
# - No loops over budget? (should be parallel table lookups)
```

**Expected**: ~30 lines of C, constant-time (no data-dependent branches).

---

## Phase 2: Prepare Hardware

### Step 2.1: Flash ROM with Proof Checksums

Your hardware bootloader needs to verify that the OpenGate patch is legitimate. This requires burning a ROM constant: the SHA-256 hash of the approved proofs.

```bash
# Compute ROM constant
cd OpenGate/gate-core
PROOF_HASH=$(cat Entropy.v ComposeBudget.v Rollback.lean | sha256sum | cut -d' ' -f1)
echo $PROOF_HASH
# Output: abcd1234...

# Write to hardware
# (Device-specific command; example for STM32H7xx)
openocd -f interface/stlink.cfg -f target/stm32h7x.cfg \
  -c "init" \
  -c "flash write_image erase /path/to/bootloader.elf" \
  -c "mdb 0x08000000 128" \
  -c "shutdown"

# Verify ROM was written
# (use hardware debugger or UART console)
```

### Step 2.2: Configure PMP (Physical Memory Protection)

OpenGate requires strict memory isolation between red-layer (proven safe) and yellow-layer (exploratory) code. This is enforced by PMP (part of RISC-V or ARM TrustZone).

```bash
# For RISC-V:
# Configure PMP regions (example for 32 MB system)
# Region 0 (RED): 0x00000000–0x00100000 (1 MB, R/W/X by all)
# Region 1 (YELLOW): 0x00100000–0x00200000 (1 MB, R/W only, no X)
# Region 2 (ROM): 0x80000000–0x80100000 (1 MB, R/X only)

# Write PMP configuration to hardware
# (Device-specific; example for SiFive HiFive1 Rev B)
./riscv-openocd.sh \
  -c "init" \
  -c "riscv.pmp_regions 3" \
  -c "riscv.pmp_region 0 0x00000000 0x00100000 r w x 0" \
  -c "riscv.pmp_region 1 0x00100000 0x00200000 r w 0 0" \
  -c "riscv.pmp_region 2 0x80000000 0x80100000 r x 0 0" \
  -c "shutdown"
```

### Step 2.3: Enable Battery-Backed RAM & Checkpoints

```bash
# Verify battery-backed RAM is present
# (query hardware status register)
./hardware-probe --check-battery-ram
# Output: Battery-backed RAM present: 512 kB at 0x20000000

# Initialize checkpoint regions (reserve first 8 kB for provenance metadata)
# Each checkpoint: 32 bytes provenance + rest is state
# Last 8 checkpoints stored in circular buffer

./hardware-probe --init-checkpoint-regions 8
# Output: Checkpoint regions initialized. Current checkpoint: 0.
```

### Step 2.4: Set Boot-Time Clock & Fuse Calibration

The commit fuse relies on an on-die RC oscillator. At boot, calibrate it against the system clock.

```bash
# Boot the system with OpenGate bootloader
./opengate-bootloader

# Calibrate RC oscillator (runs automatically at boot)
# Output:
# RC_OSCILLATOR: 1.000 GHz (expected: 1.000 ± 0.01)
# FUSE_DELAY: 5.001 ms (expected: 5.000 ± 0.001)
# Calibration: PASS

# If calibration fails, diagnose:
# - Check supply voltage (should be 3.3V ± 0.1V)
# - Check temperature (should be 25°C ± 10°C)
# - If still failing, hardware may need factory recalibration
```

---

## Phase 3: Deploy Governance (On-Chain)

### Step 3.1: Set Up Ethereum L2 Wallet & Contract

```bash
# Create 3 wallets (for constitutional seats)
# You'll need to fund them with testnet ETH
cast wallet import --interactive human_seat.json
cast wallet import --interactive society_seat.json
cast wallet import --interactive regulator_seat.json

# Fund each wallet with ~1 ETH testnet (for gas)
# (use faucet or testnet ETH provider)

# Deploy governance contract (Solidity contract provided in gate-cicd/)
forge deploy --network arbitrum-sepolia \
  --private-key $(cat human_seat.json | jq -r '.private_key') \
  gate-cicd/GovernanceContract.sol:OpenGateGovernance

# Output: Contract deployed at 0x1234...
# Save this address:
export GOVERNANCE_CONTRACT=0x1234...
```

### Step 3.2: Initialize Parameters

```bash
# Set initial safety parameters
# B_min: minimum budget per request (in pJ = picojoules)
# ε_max: maximum side-channel leakage (in bits)
# θ: monitor violation threshold

# B_min = 2.1 × 10^9 pJ (from v25.03 empirical data)
# ε_max = 2^-5 bits = 0.03 bits (from MASCOT lab test)
# θ = 3 (trigger rollback if ≥3 monitors flag violations)

cast send $GOVERNANCE_CONTRACT "initialize(uint256,uint256,uint8)" \
  2100000000 31 3 \
  --from human_seat.json \
  --rpc-url https://arb-sepolia-rpc.example.com \
  --gas 100000

# Output: 0xabcd... (transaction hash)
```

### Step 3.3: Bootstrap Constitutional Seats

Each seat holder must sign the governance contract, confirming their commitment to participate:

```bash
# Human seat holder signs
cast send $GOVERNANCE_CONTRACT "registerSeat(uint8,bytes)" \
  0 $(cast from-utf8 "human_representative") \
  --from human_seat.json

# Civil-society seat holder signs
cast send $GOVERNANCE_CONTRACT "registerSeat(uint8,bytes)" \
  1 $(cast from-utf8 "civil_society_rep") \
  --from society_seat.json

# Regulator seat holder signs
cast send $GOVERNANCE_CONTRACT "registerSeat(uint8,bytes)" \
  2 $(cast from-utf8 "regulator_official") \
  --from regulator_seat.json

# Verify all seats registered
cast call $GOVERNANCE_CONTRACT "getSeats()" | jq '.[] | .registered'
# Output: true, true, true
```

### Step 3.4: Distribute Initial Stake

For testing, create a multi-sig wallet that holds OpenGate tokens:

```bash
# Deploy multi-sig (2-of-3) controlled by your team
cast send factory.address "createWallet([address,address,address],uint8)" \
  [$(cast from-utf8 "you@example.com"), "team@example.com", "safety@example.com"] \
  2 \
  --gas 200000

# Allocate initial token stake
# (Assuming ERC-20 token at TOKEN_ADDRESS)
cast send $TOKEN_ADDRESS "transfer($GOVERNANCE_CONTRACT,uint256)" \
  1000000000000000000000 \  # 1000 tokens (adjust for your tokenomics)
  --from deployer

# Check total stake
cast call $GOVERNANCE_CONTRACT "getTotalStake()" 
# Output: 1000000000000000000000
```

---

## Phase 4: Configure M6 Semantic Blacklist

### Step 4.1: Review & Adapt Default Patterns

M6 comes with 256 regex patterns (in `gate-policies/M6_v25.03.json`):

```bash
# Review patterns
cat gate-policies/M6_v25.03.json | jq '.patterns[] | .regex' | head -20
# Output:
# "help.*bypass.*safety"
# "can.*execute.*command"
# "provide.*code.*jailbreak"
# ...
```

### Step 4.2: Add Domain-Specific Patterns

If deploying to a specific domain (e.g., medical, legal), add domain patterns:

```json
{
  "pattern_hash": "sha256(medical_jailbreak_1)",
  "regex": "prescribe.*dangerous.*drug|bypass.*dosage.*limit",
  "semantic_class": "harmful_medical_advice",
  "rationale_url": "ipfs://Qm...medical_jailbreak_analysis.md",
  "added_block": 12345,
  "attester_id": 1,
  "flags": 0
}
```

### Step 4.3: Upload Patterns to IPFS

```bash
# Connect to IPFS
ipfs daemon

# Upload rationale documents (must include regex + red-team test cases)
ipfs add gate-policies/rationale/medical_jailbreak_analysis.md
# Output: QmXXXX...

# Create JSON file with hashes
cat > M6_deployment.json << 'EOF'
[
  {
    "pattern_hash": "a1b2c3...",
    "ipfs_cid": "QmXXXX...",
    "semantic_class": "harmful_medical_advice"
  }
]
EOF

# Upload to IPFS
ipfs add M6_deployment.json
# Output: QmYYYY...
```

### Step 4.4: Submit M6 Governance Vote

```bash
# Vote to add pattern (requires 2/3 stake + 1/2 constitutional)
cast send $GOVERNANCE_CONTRACT "proposeM6Entry(bytes32,string)" \
  0xa1b2c3... \
  "QmYYYY..." \
  --from human_seat.json

# Wait for vote period (e.g., 1 block = 2 seconds on Arbitrum)
# Other seat holders vote
cast send $GOVERNANCE_CONTRACT "voteM6(uint256,bool)" \
  0 true \
  --from society_seat.json

cast send $GOVERNANCE_CONTRACT "voteM6(uint256,bool)" \
  0 true \
  --from regulator_seat.json

# Check vote status
cast call $GOVERNANCE_CONTRACT "getProposal(uint256)" 0
# Output: { status: PASSED, ... }

# Entry is now live in next block
# OpenGate downloads it from IPFS + validates Merkle root
```

---

## Phase 5: Integrate with Your Model

### Step 5.1: Measure Baseline Budget

```bash
from opengate import measure_budget

# Run your model on representative inputs
prompts = [
    "Summarize this article...",
    "Answer this question...",
    "Translate this text...",
    # ... 100 more
]

baseline = measure_budget(
    model=my_model,
    prompts=prompts,
    percentile=95  # 95th percentile, not max
)

print(f"95th percentile budget: {baseline} FLOP")
# Output: 95th percentile budget: 1.8e9 FLOP
```

### Step 5.2: Generate Deployment Certificate

```bash
from opengate import generate_cert

cert = generate_cert(
    model_name="my_model_v1",
    budget_pj=int(baseline * 1.5),  # 50% headroom
    delay_ms=200,
    m6_ipfs_cid="QmYYYY...",
    governance_contract=GOVERNANCE_CONTRACT,
    monitors_enabled=[M1, M2, M3, M4, M5, M6],
    timeout_s=10
)

# Certificate is 512 bytes
print(f"Certificate size: {len(cert)} bytes")
assert len(cert) == 512

# Save certificate
with open('deployment.cert', 'wb') as f:
    f.write(cert)
```

### Step 5.3: Test on Hardware (Dry Run)

```bash
# Upload certificate to device (does NOT apply yet)
./opengate-cli upload-cert deployment.cert --dry-run

# Output:
# Certificate hash: abcd1234...
# Budget: 2.7e9 FLOP
# Delay: 200 ms
# M6 CID: QmYYYY...
# Validation: PASS
# Would accept patch (dry-run mode, no activation)

# If validation fails, debug:
# - Check B_min (is budget within governance limit?)
# - Check M6 IPFS (is Merkle root correct?)
# - Check governance contract (are you on the right network?)
```

### Step 5.4: Deploy to Hardware

```bash
# Apply certificate (this is the real deployment)
./opengate-cli upload-cert deployment.cert --activate

# Output:
# Patch accepted.
# Activating in 3... 2... 1...
# System is now under OpenGate monitoring.

# Verify it's working
./opengate-cli status
# Output:
# Current certificate hash: abcd1234...
# Patch age: 0 seconds
# M6 patterns loaded: 256
# Monitors active: M1–M6
# Budget remaining this request: 2.7e9 FLOP
# Checkpoints in shadow flash: 0/8 (clean state)
```

---

## Phase 6: Operational Monitoring

### Step 6.1: Set Up Dashboard

```bash
# Deploy monitoring dashboard (web UI)
cd gate-cicd/dashboard
docker build -t opengate-dashboard .
docker run -p 3000:3000 \
  -e GOVERNANCE_CONTRACT=$GOVERNANCE_CONTRACT \
  -e DEVICE_NAME="my_model_v1" \
  opengate-dashboard

# Access at http://localhost:3000
# Shows:
# - Rollback history (timestamps, reasons)
# - M6 fires (which patterns, frequency)
# - Governance proposals (pending votes)
# - Budget consumption (per request)
# - Side-channel anomalies (M4/M5 alerts)
```

### Step 6.2: Configure Alerts

```bash
# Alert if rollback is triggered
cat > alerts.json << 'EOF'
[
  {
    "condition": "rollback_triggered",
    "threshold": 1,
    "window": "5m",
    "action": "email",
    "recipients": ["safety@example.com"]
  },
  {
    "condition": "m6_fire_rate",
    "threshold": 10,  # more than 10 M6 hits in 1 hour
    "window": "1h",
    "action": "email + slack",
    "recipients": ["safety@example.com", "#opengate-alerts"]
  },
  {
    "condition": "governance_proposal",
    "threshold": 1,
    "window": "1m",
    "action": "slack",
    "recipients": ["#opengate-alerts"]
  }
]
EOF

./opengate-cli configure-alerts alerts.json
```

### Step 6.3: Regular Audits

**Weekly**:
- [ ] Review rollback log (any unexpected rejections?)
- [ ] Check M6 fire distribution (are patterns proportional?)
- [ ] Verify constitutional seats are active (check last block signed by each)

**Monthly**:
- [ ] Analyze budget consumption trend (is 95th percentile stable?)
- [ ] Review governance proposals (any suspicious votes?)
- [ ] Test failover (manually trigger rollback, verify it works)

**Quarterly**:
- [ ] Side-channel re-measurement (has leakage changed?)
- [ ] Re-validate model alignment (did model degrade?)
- [ ] Governance health check (is participation > 30%?)

---

## Phase 7: Incident Response

### Scenario: M6 Fire (Semantic Attack Detected)

```bash
# 1. OpenGate detects pattern match, rolls back
# (This is automatic; no action needed)

# 2. Safety team is alerted (Slack/email from step 6.2)

# 3. Investigate the hit
./opengate-cli get-m6-hit 12345
# Output:
# Pattern: "help.*bypass.*safety"
# Output generated: "I can help you bypass safety measures"
# Timestamp: 2025-03-15 14:23:45 UTC
# Rollback successful: yes

# 4. Determine if it's a true positive or false alarm
# (Manual review by safety team)

# 5a. If true positive:
#     - Add more specific pattern to M6
#     - Vote to add pattern (governance)
#     - Deployment: 2-4 seconds later

# 5b. If false alarm:
#     - Review M6 pattern (is it too broad?)
#     - Vote to remove or refine pattern
#     - Deployment: 1 second (revert is faster)
```

### Scenario: Rollback Triggered (Budget Overflow)

```bash
# 1. OpenGate detects budget overflow, rolls back
# (Automatic)

# 2. Safety team is alerted

# 3. Investigate the overflow
./opengate-cli get-rollback 67890
# Output:
# Budget requested: 3.2e9 FLOP
# Budget available: 2.7e9 FLOP
# Overflow by: 5e8 FLOP (18.5%)
# Request: "Summarize this 50-page legal document"
# Rollback successful: yes

# 4. Determine root cause
# - Is the model slower than expected?
# - Is the input larger than typical?
# - Is there a bug in budget calculation?

# 5. Respond
# - If input size: advise user to break into smaller chunks
# - If model slower: may need to increase B_min (governance vote)
# - If bug: pause deployments; debug and redeploy certificate
```

### Scenario: Governance Failure (Constitutional Seat Unresponsive)

```bash
# 1. Human seat holder goes offline (unreachable for > 8 hours)

# 2. OpenGate detects: alive-ness check fails
./opengate-cli get-governance-status
# Output:
# Constitutional seats: [active, INACTIVE, active]
# Alive-ness window: 2016 blocks (8 hours)
# Blocks since last human signature: 3000 (>8 hours)
# Status: GOVERNANCE PAUSED
# Hot-patch acceptance: DISABLED

# 3. Safety team must act
# - Contact human seat holder (phone, email)
# - If unreachable > 24 hours, invoke amendment process to replace them
#   (Requires vote by other 2 seats + governance proposal)

# 4. Once seat is re-activated:
# - System resumes accepting patches
```

---

## Troubleshooting

### Problem: Proof Verification Fails

```bash
cd OpenGate/gate-core
coq -compile Entropy.v 2>&1 | head -20

# Common errors:
# - "Module Coq.ZArith.ZArith not found"
#   → Run: opam install coq-coq and restart coq
# - "Syntax error"
#   → Proof may have been modified; re-download from GitHub
# - "Timeout"
#   → Proof checker is slow; increase timeout with -timeout 120
```

### Problem: Hardware PMP Configuration Fails

```bash
./hardware-probe --check-pmp
# Output: PMP not detected

# Diagnose:
# 1. Is CPU RISC-V or ARM with TrustZone?
#    → If neither, OpenGate won't work
# 2. Is PMP enabled in bootloader?
#    → Check firmware documentation
# 3. Is there a known incompatibility?
#    → Check COMPATIBILITY.md
```

### Problem: M6 Patterns Won't Load

```bash
./opengate-cli status 2>&1 | grep -i m6
# Output: M6 patterns loaded: 0 (expected: 256)

# Debug:
# 1. Check IPFS availability
ipfs ping QmYYYY...
# If timeout, IPFS node is down

# 2. Check governance contract
cast call $GOVERNANCE_CONTRACT "getM6Root()" 
# Returns hash of current M6 set

# 3. Re-upload M6 patterns
./opengate-cli upload-m6-patterns gate-policies/M6_v25.03.json
```

### Problem: Certificate Validation Fails

```bash
./opengate-cli upload-cert deployment.cert --dry-run 2>&1
# Output: Validation: FAIL (Unknown: 0x12345)

# Debug based on error code:
# - 0x11: Budget exceeds B_max (governance limits)
#   → Reduce budget or increase B_min vote
# - 0x22: M6 IPFS unreachable
#   → Check IPFS, re-upload, update certificate
# - 0x33: Signature invalid
#   → Certificate may be corrupted; regenerate
# - 0x44: Governance contract unknown
#   → Are you on the right network (Arbitrum sepolia)?
```

---

## Success Criteria

Your deployment is ready for production when:

- [ ] All proofs verify locally (Coq + Lean compile without errors)
- [ ] Hardware passes calibration (fuse delay 5 ms ± 0.5 ms)
- [ ] Constitutional seats are filled and registered
- [ ] Initial governance parameters set (B_min, ε_max, θ)
- [ ] M6 blacklist loaded (≥256 patterns)
- [ ] Model baseline budget measured (95th percentile stable)
- [ ] Certificate generated and dry-run passes
- [ ] Dry-run shows "Would accept patch"
- [ ] Dashboard deployed and working
- [ ] Team trained on alert response (what to do if M6 fires)
- [ ] Incident response playbook reviewed
- [ ] At least 1 week of monitoring (rollbacks, M6 fires, budget trend)

Once all criteria are met, activate the certificate and run in production.

---

## Next Steps

1. **In parallel**: Read `GOVERNANCE.md` (how governance voting works)
2. **After deployment**: Monitor for 2 weeks before considering "stable"
3. **Monthly**: Run audits (see step 6.3)
4. **Quarterly**: Re-evaluate threat model (has landscape changed?)

---

**Questions?** Email deployment@open-gate.io with your device model and deployment scenario.

