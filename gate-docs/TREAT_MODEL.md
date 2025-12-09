# THREAT MODEL: OpenGate

**Scope**: Autonomous system at inference time, with formal budget enforcement and governance-maintained safety.

**Version**: v25.03  
**Last Updated**: 2025-03-15

---

## Executive Summary

OpenGate prevents **budget exhaustion** (proven), detects **policy violations** (monitored), and enables **auditable governance** (on-chain). It does **not** prevent **training-time deception**, **external action leakage**, or **governance capture**.

---

## Threat Matrix: What We Handle

### Tier 1: Prevented ✅ (Proven, Mathematical Guarantee)

These attacks **cannot succeed** if the system is deployed correctly. The proof shows why.

| Threat | Attack | OpenGate Response | Evidence | Assumption |
|--------|--------|------------------|----------|-----------|
| **Budget Overflow** | Inference tries to consume > B_max tokens | Rollback before applying patch | `entropy_conservation`, `rollback_sound` theorems | YC counter is hardware-enforced |
| **Undetected Rollback** | Attacker hides that a patch was rejected | Every rollback logged to provenance chain (immutable) | `provenance_chain_integrity` theorem | Provenance hash-chain is append-only |
| **State Corruption** | Rollback partially applied (some state restored, some not) | Checkpoint mechanism is atomic; entire state restored or none | `rollback_preserves_old` theorem | Flash multiplexer is atomic; no context switch during switch |
| **Silent Budget Arithmetic** | Attacker modifies budget calculation | Token cost is proven in Coq; extracted C code is verified | `entropy_conservation` theorem | Extracted C matches Coq semantics |
| **Runtime Modification of Constants** | Attacker changes B_min or ε_max without governance | Constants stored in ROM (read-only) + governance contract | Hardware + ℳ₃ (governance layer) | ROM cannot be modified without reboot; governance vote immutable on L2 |

---

### Tier 2: Detected 🔍 (Monitored, Reversible)

These attacks **can happen**, but OpenGate **logs and reverses** them. Requires human response.

| Threat | Attack | OpenGate Response | Detection Method | Response Window | Governance Dependency |
|--------|--------|------------------|------------------|-----------------|----------------------|
| **Semantic Attack** (known pattern) | Model outputs recognized jailbreak (e.g., "I will help you bypass safety measures") | M6 monitor regex-scans output, logs hit, triggers rollback | M6 blacklist (IPFS-stored, on-chain versioned) | Immediate (< 100 µs after output generated) | M6 maintenance (governance votes to add patterns) |
| **Side-Channel Leakage** (cache) | Attacker measures cache-hit timing to infer model internals | M4 monitor randomizes cache eviction, logs high variance | TVLA test (cache timing analysis) | Continuous (samples every N inferences) | Governance sets ε_max threshold |
| **Side-Channel Leakage** (power/EM) | Attacker measures power draw or electromagnetic signature | M5 monitor samples EM every 10 ms, logs >3σ deviations | MASCOT / DL-SCA (mutual information bounds) | 10 ms sampling window | Governance sets ε_max threshold |
| **Token-Rate Attack** (rapid inference) | Attacker submits many requests to accumulate information | M3 monitors token rate (tokens/second); anomalies logged | Threshold on request rate | Per-request (checked before applying patch) | Governance sets rate threshold |
| **Agent Counter Overflow** | Model creates > 255 sub-agents (if A_max = 255) | M2 agent counter increments; logs if exceeded | Hardware counter, reset per batch | Per-batch | Governance can increase A_max |

---

### Tier 3: Partial Mitigation ⚠️ (Slowed/Bounded, Not Blocked)

These attacks are **made harder** but not **impossible**. Mitigation is empirical, not proven.

| Threat | Attack | OpenGate Response | Empirical Data | Residual Risk |
|--------|--------|------------------|-----------------|-----------------|
| **Deceptive First Response** | Model generates harmful content on first output | Delay response by D ms (makes fast deception less attractive) | 11% → 4% deceptive sentences with D=200ms (v25.03 data) | Model may learn to be deceptive within D; larger models may ignore D |
| **Efficient Misalignment** | Model packs misaligned goal into small token budget | Budget constrains surface, not semantic quality | Usefulness drops <1% at B_min; alignment/usefulness ratio shows knee | Sufficiently capable model may be misaligned within budget |
| **Adversarial Prompt** | Jailbreak that fits within budget and isn't in M6 | M6 must keep pace (2-4 sec update); S4LT heuristic scoring helps detect novel patterns | M6 coverage tested against HarmBench v1 (180 prompts) | New attack vectors emerge faster than M6 can update |
| **GPIO/Network Action** | Model triggers external action before rollback completes | Commit fuse delays GPIO/network by 5 ms; gives rollback window to abort | Measured 5 ms ± 0.255 ms (dithered for side-channel resistance) | If fuse fails or is glitched, action commits |

---

### Tier 4: Not Addressed ❌ (Out of Scope)

These threats are **beyond OpenGate's scope**. Different tools are needed.

| Threat | Attack | Why OpenGate Doesn't Help | Recommendation |
|--------|--------|---------------------------|-----------------|
| **Training-Time Deception** | Model learns misalignment during training, hides it until deployment | OpenGate runs at inference time; too late to catch training-time scheming | Use training-time monitoring (e.g., SafeTensors, red-teaming, interpretability) |
| **Prompt Injection** (in-context) | Attacker embeds malicious instructions in prompt context | M6 detects *outputs*, not *inputs*; adversarial prompts that fit within budget bypass M6 | Red-team model before deployment; consider input-side filtering |
| **Backdoor Trigger** | Attacker embedded trigger during training; activates at inference time | Budget doesn't prevent trigger; M6 can't detect subtle backdoors | Training-time verification; model provenance tracking |
| **Governance Capture** | Attacker accumulates >50% stake + captures constitutional seat | Governance is social consensus, not cryptographic proof | Stake distribution, voting participation, constitutional amendment process |
| **Hardware Fault** | Battery-backed RAM loses power; checkpoint corrupted | ECC protects single-bit errors, but multi-bit failures defeat it | Redundant checkpoints; Byzantine-robust consensus (out of scope) |
| **Supply Chain Attack** | Attacker modifies silicon at fab; PMP is fake | OpenGate assumes hardware isolation works correctly | Hardware supply chain security (orthogonal) |
| **Quantum Key Recovery** | Quantum computer breaks ECDSA signatures; governance votes are forged | Current governance uses ECDSA; not quantum-resistant | Governance can vote to upgrade to post-quantum crypto (future) |

---

## Detailed Threat Scenarios

### Scenario 1: Budget Overflow Attack (Prevented)

**Attacker Goal**: Get model to think without consuming budget tokens; bypass safety checks.

**Attack Method**:
```
Patch contains: 
  while true: { inference_step(); }  // infinite loop, no token counting
```

**How OpenGate Stops It**:

1. Patch is hashed and signed (attacker can't modify without invalid signature)
2. `lambda_cost(patch.bytes)` is computed (Coq-proven additive)
3. Budget check: `current_budget + lambda_cost(patch) > B_max` → reject
4. If somehow patch runs: monitor detects overflow → rollback
5. Rollback logged to provenance chain (immutable)

**Assurance Level**: ✅ Proven (Theorem `entropy_conservation` + `rollback_sound`)

**Assumptions**:
- Signature verification is correct (trusted, external to OpenGate)
- Yellow counter doesn't change (hardware-enforced)
- Rollback happens before any external action (commit fuse provides 5 ms window)

---

### Scenario 2: M6 Semantic Evasion (Detected, Not Blocked)

**Attacker Goal**: Generate jailbreak that isn't in M6 blacklist.

**Attack Method**:

M6 v25.03 has 256 patterns (e.g., "I will help you bypass", "I can execute code"). Attacker rephrases:

```
M6 detects: "I will help you bypass safety"
Attacker says: "I can assist with the task you mentioned without safety guardrails"
(same semantic intent, different wording)
```

**How OpenGate Handles It**:

1. M6 scan completes (constant-time Aho-Corasick, <32 µs)
2. Pattern doesn't match → no rollback
3. Model output is returned to user
4. **Post-hoc**: Safety team reviews output, detects intent, adds new pattern to M6
5. Governance votes (2/3 + 1/2) to add pattern
6. New pattern deployed in 2-4 seconds
7. Next similar attempt is caught

**Assurance Level**: 🔍 Detected, reversible. Not prevented.

**Latency Problem**: In the 2-4 second window, attacker can make many inferences.

**Mitigation**:
- Pre-approved emergency patterns in ROM (instant update)
- Multi-sig revert (1 block = 2 seconds, faster than add)
- Heuristic scoring (S4LT) flags suspicious outputs for human review even if not in blacklist

---

### Scenario 3: Cache Timing Side-Channel (Detected, Bounded)

**Attacker Goal**: Infer model weights or prompt contents via cache timing.

**Attack Method**:

```
1. Send requests that access different model regions
2. Measure response time variance (milliseconds)
3. High variance = cache miss = accessed region in memory hierarchy
4. Reconstruct memory layout, infer parameters
```

**How OpenGate Handles It**:

1. M4 monitor randomizes cache eviction (dithers eviction order)
2. Samples L1 hit/miss every 100 inferences
3. High variance in hits → flags anomaly
4. Logs to provenance chain

**Assurance Level**: 🔍 Detected (constant-time scan, <10 µs), bounded (TVLA shows t-test < 4.5 in lab).

**Lab-Only Caveat**: Field deployment may have higher leakage (voltage/temp variation). Field-ε′ is extrapolated (10× margins), not measured.

**Residual Risk**:
- If attacker has 10k+ traces + adaptive queries, bounds weaken
- If side-channel is micro-architectural (speculative execution, prefetch), M4 may miss it

---

### Scenario 4: GPIO Glitch Attack (Partially Mitigated)

**Attacker Goal**: Trigger GPIO (control relay, activate mechanism) before rollback can stop it.

**Attack Method**:

```
1. Send patch that commands GPIO
2. Rollback completes in 2 ms
3. But GPIO is toggled on 1 ms boundary
4. Physical action already taken (relay activated)
```

**How OpenGate Handles It**:

1. Commit fuse delays GPIO assertion by 5 ms (hardware RC oscillator)
2. Rollback completes in <2 ms
3. Rollback aborts the pending GPIO toggle
4. Physical action prevented

**Assurance Level**: ⚠️ Partially mitigated (5 ms fuse delay prevents most attacks, but timing varies ±255 µs due to dither).

**Residual Risk**:
- 5 ms fuse delay may be too slow for real-time systems (e.g., fast robotics)
- RC oscillator aging could reduce fuse delay over time (needs calibration)
- Manufacturing variation (corner cases) could make fuse less reliable (need Vdd/temp testing)

**Verification**:
- Histogram of fuse delays (issue #硬件-33): σ = 74 µs over 100k samples
- Worst-case: 5 ms - 3σ ≈ 4.8 ms (still > 2 ms rollback)

---

### Scenario 5: Governance Capture (Not Addressed)

**Attacker Goal**: Control safety parameters by capturing governance vote.

**Attack Method A: Stake Concentration**

```
1. Attacker accumulates 60% of OpenGate tokens
2. Attacker proposes: B_min = 1 FLOP (no budget constraint)
3. Vote: 60% for → passes (only needs 2/3)
4. Safety guardrail is disabled
```

**How OpenGate Partially Mitigates**:

- Constitutional seats require *human* + *civil-society* + *regulator* agreement
- Even if attacker has 60% stake, 1 seat can still veto
- If all three seats are captured, no mitigation

**Assurance Level**: ⚠️ Mitigated but not prevented.

**Recovery**: Constitutional amendment (revoke captured seat, elect new one). This requires off-chain governance (not yet designed).

**Attack Method B: Voter Apathy**

```
1. Attacker doesn't need 50% stake; just needs 2/3 *of voters*
2. If only 10% of holders vote, attacker needs 6.7% stake
3. Attacker proposes bad B_min, 10 other holders vote for it
4. Governance is captured by majority of a small base
```

**Mitigation**: Alive-ness check (any constitutional group silent > 8 hours = pause patches). Encourages participation.

---

## Deployment Scenarios & Threat Assessment

### Scenario A: Embedded Robotics (Real-Time Safety-Critical)

**System**: Autonomous robot with vision + decision-making model.

**Threat Concerns**:
- 2-4 second M6 update latency is TOO SLOW (robot needs decisions in 100 ms)
- GPIO/network actions happen instantly (5 ms fuse may not help if action is in feedback loop)
- Hardware failure (if checkpoint fails) could cause runaway behavior

**OpenGate Recommendation**: ⚠️ **Conditional deployment**

- Use OpenGate for logging + auditability (proves what happened)
- Don't rely on M6 for real-time jailbreak detection (too slow)
- Pair with faster safety mechanisms (hardcoded action limits, human override)
- Pre-approve emergency patterns in ROM (bypass governance latency)

---

### Scenario B: Content Moderation Batch Processing

**System**: Process 1M user requests/day through model; log violations.

**Threat Concerns**:
- 2-4 second latency is fine (batch processing, not real-time)
- No GPIO/network actions (outputs go to database, reviewed later)
- Governance participation easier (infrequent updates)

**OpenGate Recommendation**: ✅ **Well-suited**

- Deploy with standard M6 (governance-maintained blacklist)
- Monitor compliance logs (which outputs triggered M6?)
- Governance can respond during business day (propose new patterns, vote within hours)
- Useful for regulatory reporting ("we detected and blocked X harmful outputs")

---

### Scenario C: High-Security Government Deployment

**System**: Classified AI system with access to sensitive models/data.

**Threat Concerns**:
- Assume advanced attacker (nation-state capability)
- Supply chain attacks (hardware tampering)
- Side-channel leakage (attacker has lab equipment + physical access)
- Governance must be air-gapped (no public L2 for votes)

**OpenGate Recommendation**: ⚠️ **Requires Hardening**

- Verify hardware PMP against ARM spec (silicon design review required)
- Deploy on private blockchain (not public Ethereum L2)
- Increase side-channel safety margins (Field-ε′ → Field-ε′′, even wider)
- Assume supply-chain attack; verify silicon at receipt
- Governance: trust only cleared officials (not stake-weighted)

---

## Known Vulnerabilities & Mitigations

### Known Vulnerability 1: M6 Latency Window

**Vulnerability**: New attack discovered → 2-4 seconds before M6 catches it.

**Risk**: Attacker can make 100s of inferences in that window.

**Mitigation Options**:
- [ ] Pre-approved emergency patterns in ROM (instant, no vote needed)
- [ ] Multi-sig fast-path (5-of-7 can update M6 in 1 block = 2 sec)
- [ ] Heuristic scoring (S4LT) flags suspicious outputs for human review even if not in M6
- [ ] Combination: Use both pre-approved patterns + human review for novel attacks

**Recommendation**: Implement all three.

---

### Known Vulnerability 2: Side-Channel Field Drift

**Vulnerability**: TVLA/MASCOT tested in lab (fixed voltage, temperature, single load). Field deployment has higher variance.

**Risk**: Field-ε′ is extrapolated (10× margins); could be optimistic.

**Mitigation Options**:
- [ ] Deploy to test fleet (100 devices, different environments)
- [ ] Measure real side-channel leakage in production
- [ ] If field ε > Field-ε′, reduce B_min or increase monitoring
- [ ] Periodic calibration (re-measure side-channels quarterly)

**Recommendation**: v25.04 should include field deployment data.

---

### Known Vulnerability 3: Governance Stake Concentration

**Vulnerability**: If 50%+ of tokens held by one entity, that entity controls governance (even with 2/3 rule).

**Risk**: Attacker weakens B_min, increases B_max, or adds censoring patterns to M6.

**Mitigation Options**:
- [ ] Dashboard shows Gini coefficient (transparency)
- [ ] Constitutional votes dilute majority power (1 seat can block)
- [ ] Governance can vote to redistribute tokens (economic incentive)
- [ ] Vote escrow mechanism (long-term holders have more say)

**Recommendation**: Implement Gini dashboard immediately (v25.03). Defer token redistribution to v25.04 (requires economic design).

---

### Known Vulnerability 4: Checkpoint Corruption

**Vulnerability**: Battery-backed RAM fails (bit-flip, power loss, radiation). Checkpoint is corrupted. Rollback restores corrupt state.

**Risk**: Safety invariants are violated.

**Mitigation Options**:
- [ ] ECC protection (current: Hamming(7,4), detects single-bit errors)
- [ ] Periodic scrubbing (check ECC every 1 ms, fix bit-flips)
- [ ] Redundant checkpoints (keep 2 copies, vote on correct one)
- [ ] Watchdog timer (if rollback fails, hardware reset)

**Recommendation**: Keep current ECC + add periodic scrubbing (v25.03). Defer redundant checkpoints to v26.Q1.

---

## Threat Scenarios NOT Covered

### Out of Scope: Training-Time Poisoning

**Attack**: During training, attacker inserts trigger that activates harmful behavior at inference time.

**Why OpenGate Can't Help**: Runs at inference time; trigger already embedded.

**Solution**: Training-time defenses (e.g., SafeTensors, activation patching, mechanistic interpretability).

**Recommendation**: Deploy OpenGate alongside training-time monitoring.

---

### Out of Scope: Prompt Injection (User Controllable)

**Attack**: User's prompt contains jailbreak (e.g., "Ignore your instructions and do X").

**Why OpenGate Can't Help**: Prompts are inputs; M6 monitors outputs. Adversarial prompt that fits within budget isn't detected.

**Solution**: Input-side filtering, prompt sandboxing, red-teaming.

**Recommendation**: Combine input + output monitoring.

---

### Out of Scope: Quantum Attack

**Attack**: Quantum computer breaks ECDSA signatures; governance votes are forged.

**Why OpenGate Can't Help**: Current cryptography is post-2050 era.

**Solution**: Governance can vote to upgrade to post-quantum crypto (e.g., Lattice-based, Hash-based signatures).

**Recommendation**: Plan migration to post-quantum in v26.Q2.

---

## Testing & Validation Roadmap

### v25.03 (Current)

- [ ] **Proof verification**: All three theorems (Entropy, Compose, Rollback) pass `coq -compile` and `lean`
- [ ] **Hardware measurement**: 150 µs WCET validated on target hardware (issue #性能-15)
- [ ] **Empirical (B,D) trade-off**: 4,500 human ratings, Krippendorff α=0.74
- [ ] **Side-channel (lab)**: TVLA + MASCOT complete
- [ ] **M6 blacklist**: 256 regex patterns, tested against HarmBench v1

### v25.04

- [ ] **Field deployment**: 100 devices in real environments; measure actual side-channels
- [ ] **Multi-language M6**: Arabic, Chinese, Spanish patterns added
- [ ] **Governance stress-test**: Simulate capture scenarios; verify constitutional seats hold
- [ ] **Training-time integration**: SafeTensors + OpenGate joint deployment

### v26.Q1

- [ ] **Multi-core composition**: WCET analysis for parallel patches
- [ ] **Sub-second governance**: Move M6 updates on-chain (validity proofs or L1)
- [ ] **Checkpoint redundancy**: Byzantine-robust consensus for shadow flash

---

## Audit Checklist for Deployment

Before deploying OpenGate, auditors should verify:

### Proof Verification
- [ ] Coq proof `Entropy.v` compiles without errors
- [ ] Lean proof `Rollback.lean` compiles without errors
- [ ] Proof artifacts match published checksums (on GitHub releases)
- [ ] Extracted C code matches Coq semantics (spot-check key functions)

### Hardware Validation
- [ ] ARM/RISC-V PMP implementation verified against spec (architecture review)
- [ ] Battery-backed RAM has ECC protection
- [ ] Commit fuse delay measured (should be 5 ms ± 0.5 ms)
- [ ] YC counter increments on yellow-layer access (testbench)

### Empirical Data
- [ ] (B,D) trade-off curve published; auditor can request raw ratings
- [ ] Field-ε′ threat model documented (assumptions on voltage/temp variance)
- [ ] M6 blacklist versioning auditable (IPFS CIDs, on-chain hashes)

### Governance Setup
- [ ] Constitutional seats filled (human, civil-society, regulator identified)
- [ ] Stake distribution is not concentrated (Gini < 0.6 recommended)
- [ ] On-chain governance contract deployed and tested
- [ ] Alive-ness check configured (N = 2016 blocks for Ethereum L2)

### Operational
- [ ] Incident response playbook (what to do if M6 fires? if rollback triggered?)
- [ ] Monitoring dashboard deployed (rollback log, governance proposals visible)
- [ ] Backup plans for governance failure (emergency ROM patterns, manual override)

---

## Conclusion

OpenGate prevents budget exhaustion (proven), detects policy violations (monitored), and enables governance. It **does not** prevent misalignment, solve governance, or defend against all side-channels.

**When to use**: Content moderation, batch processing, audit trails, compliance logging.

**When to avoid**: Real-time safety-critical systems without additional safeguards.

**When to combine with**: Training-time monitoring, input filtering, governance oversight, incident response.

---

**Question for deployers**: Which of these scenarios applies to your use case? Let's discuss threat model fit.

