# OPEN GATE

**Formally Verified Monitoring and Rollback for Autonomous Systems**

---

## What Is OpenGate?

OpenGate is a hardware-enforced monitor and rollback system for autonomous systems (including AI models). It sits between your model and the external world, enforcing three proven-safe guarantees:

1. **Budget enforcement** — Every inference is charged from a resource budget. If it exceeds the budget, the system rolls back to a safe state before any external effect is committed.

2. **Observable and auditable** — Every decision (accept/reject patch, rollback, governance change) is logged immutably. Auditors can replay the entire system history.

3. **Governance-maintained safety** — Safety parameters (budget limits, semantic blacklist, response delays) are maintained through multi-stakeholder on-chain governance.

**What OpenGate is NOT:**
- A proof that budget constraints prevent misalignment (they don't)
- A solution to adversarial robustness (side-channels are bounded, not eliminated)
- A replacement for careful model development (it's complementary)
- A magic solution to AI safety (it's infrastructure for human-governed safety)

**What OpenGate IS:**
- Formally verified runtime safety (three major theorems, proven in Coq/Lean)
- Auditable governance framework (on-chain voting, immutable logs)
- Speed bump + detection system (makes certain attacks slower, logs all attempts)
- Production-ready code (512-byte certificates, 150 µs hot-patch check)

---

## Core Claims & Evidence

### Claim 1: Hard Per-Inference Budget (Proven)

**What it does:** Every inference consumes tokens from a budget B ≤ B_max. If an inference would exceed B_max, it is rolled back before any action is taken.

**Proven by:**
- Theorem `entropy_conservation` (Coq): Token cost is additive and deterministic
- Theorem `rollback_sound` (Lean): Rollback restores the previous state exactly (bit-for-bit)
- Theorem `compose_budget` (Coq): Sequential patches don't interact; costs add up

**Validated by:**
- Hardware measurement: 137 µs worst-case on ARM Cortex-R52 (issue #性能-15)
- Proof artifact: `gate-core/Entropy.v`, `gate-core/Rollback.lean`, `gate-core/ComposeBudget.v`

**Limitations:**
- Budget constrains *computational surface* (tokens), not *semantic quality* (alignment)
- A model can be deceptive within budget (efficiency doesn't imply honesty)
- Rollback is reactive: it prevents state corruption, not external action (GPIO, network packets already sent before rollback completes)

---

### Claim 2: 150 µs Worst-Case Check Time (Proven + Measured)

**What it does:** The hot-patch check (decide accept/reject) completes in ≤150 µs on 1 GHz hardware.

**Proven by:**
- Formal WCET analysis (Lean): All code paths are constant-time, no loops, no data-dependent branches
- Hardware measurement: 100k test runs, 137 µs max (137 µs + 13 µs safety margin = 150 µs)

**What this includes:**
- Hash and compare (patch signature, root hashes)
- Constant-time BLS signature verification
- Budget arithmetic

**What this does NOT include:**
- Monitor detection latency (how long before a monitor detects a violation)
- Propagation latency (how long to apply rollback)

**Why this matters:** 150 µs is fast enough that the gate can run inline without blocking model inference. (150 µs << 1 ms typical inference time)

---

### Claim 3: Immutable Audit Trail (Proven + Implemented)

**What it does:** Every rollback, patch application, and governance change is logged to an immutable provenance chain. The chain cannot be modified without detection.

**Proven by:**
- Theorem `rollback_preserves_old` (Lean): Checkpoints are taken before patch application, cannot be corrupted
- Theorem `provenance_chain_integrity` (Lean): Hash chain is append-only; modifying any entry breaks all subsequent hashes

**Implementation:**
- 512-byte certificate per patch includes hash-pointer to governance transaction
- Provenance metadata (32 bytes) stores: [patch-hash, parent-hash, budget-before, overflow-flag, monitors-status]
- Shadow flash keeps last 8 patch images hash-chained
- Rollback is < 2 ms (hardware multiplexer switches between shadow pages atomically)

---

## Threat Model: What We Prevent, Detect, and Maintain

### What OpenGate Prevents ✅

- **Budget overflow**: An inference that would exceed B_max is rejected and rolled back
- **Undetected rollback**: Every rollback is logged; cannot be hidden
- **Budget arithmetic errors**: Token cost calculation is proven (Coq), not estimated
- **State corruption after rollback**: Checkpoint mechanism is atomic; no partial rollbacks
- **Runtime modification of safety constants**: B_min, ε_max stored in governance contract + ROM hash; cannot be changed without on-chain vote

### What OpenGate Detects (But Doesn't Prevent) 🔍

- **Semantic attacks** (unverified): M6 monitor regex-scans output against governance-maintained blacklist. If pattern matches, logs event and triggers rollback. *Requires governance to maintain blacklist.*
- **Side-channel leakage**: Monitors M4 (cache) and M5 (power/EM) sample and log anomalies. Bounds are empirical (lab conditions), not proven.
- **Deceptive behavior** (empirical): Delays inference response by D ms (configurable, governance-maintained). Makes fast, shallow deception less attractive. *Trade-off measured in v25.03 (alignment/usefulness ratio).*

### What OpenGate Does NOT Address ❌

- **Training-time deception**: Model can learn misalignment during training, hide it until deployment. OpenGate runs at inference; too late to catch this.
- **Adversarial prompts within budget**: A jailbreak that fits in the budget is not blocked. M6 must keep pace with new attacks (2-4 second update latency).
- **Governance capture**: If one entity controls >50% stake, they can influence governance votes (mitigated by constitutional seats, not prevented).
- **Physical side-channels in adversarial environments**: Power/EM testing is lab-only; field deployment may have higher leakage.
- **Hardware failure**: Battery-backed RAM corruption, flash multiplexer glitches, PMP misconfiguration. ECC and periodic checks mitigate, but not Byzantine-robust.

---

## Assumptions (What Must Be True for Claims to Hold)

| Assumption | Risk | Mitigation |
|-----------|------|-----------|
| **Hardware isolation (PMP/MMU)** is correctly implemented | High | Verified against ARM/RISC-V spec; silicon design review required |
| **Lean/Coq kernel** is sound (proof checker is correct) | Medium | We compile with `-DNO_FIXPOINT` to prevent self-reference; assume standard library is correct |
| **Checkpoint storage (battery-backed RAM)** doesn't lose power | Medium | ECC protection; periodic scrubbing; consider redundant checkpoint |
| **Yellow-counter (YC) is hardware-enforced** and cannot be decremented | Low | Saturating counter, overflow flag sticky; implemented in RTL, verified |
| **Governance acts within 2-4 seconds** for critical updates | High | L2 blockchain block time = 2s; faster response requires moving governance on-chain |
| **The Λ-table (token cost) was calibrated correctly** | Medium | Empirically validated on 125M GPT-2; generalization to larger models TBD |

---

## Three Layers: Proven, Empirical, Governance-Maintained

### ℳ₁: Proven Safe (Red Layer)

**Runtime properties verified in Coq/Lean:**

| Property | Theorem | Proof artifact | Status |
|----------|---------|----------------|--------|
| Token additivity | `entropy_conservation` | `gate-core/Entropy.v` | ✅ Proven |
| Composition safety | `compose_budget` | `gate-core/ComposeBudget.v` | ✅ Proven |
| Rollback soundness | `rollback_sound` | `gate-core/Rollback.lean` | ✅ Proven |
| Constant-time runtime | `wcet_bounded` | `gate-core/WCET.lean` | ✅ Proven |

**You can verify these proofs:**
```bash
cd gate-core
coq -compile Entropy.v ComposeBudget.v
lean Rollback.lean
# All theorems should print "QED"
```

### ℳ₄: Empirically Validated (No Formal Proof)

**Properties measured in lab, not proven:**

| Property | Method | Data | Status |
|----------|--------|------|--------|
| (B, D) trade-off | Human raters (Krippendorff α=0.74, n=4500 prompts) | `data/bd_sweep.csv` | ✅ Measured v25.03 |
| Side-channel leakage | TVLA (t-test < 4.5) + MASCOT (I(K;O) < 2⁻⁵ bits) | `data/side_channel_report.pdf` | ✅ Lab-tested |
| Field threat model | Extrapolated (10× noise margins: ±10% voltage, ±30°C temp) | `data/field_epsilon_prime.md` | ⚠️ Not field-validated |

### ℳ₃: Governance-Maintained (Policy)

**Constants requiring multi-stakeholder voting (on-chain):**

| Constant | Threshold | Update time | Audit |
|----------|-----------|-------------|-------|
| B_min (budget limit) | 2/3 staked tokens + 1/2 constitutional seats | ≥2 sec (L2) | On-chain logs |
| ε_max (leakage bound) | 2/3 staked + 1/2 constitutional | ≥2 sec | On-chain logs |
| M6 entry (add semantic pattern) | 2/3 staked + 1/2 constitutional | ≥2 sec | IPFS + Merkle root |
| M6 revert (remove pattern) | 1/2 staked + 1/3 constitutional | ≥1 sec | Faster rollback of bad patterns |

**Constitutional seats (3 mandatory signers):**
1. Human (elected by token holders)
2. Civil-society representative
3. Regulator / government AI authority

**Alive-ness check:** If any group is silent > 2016 blocks (~8 hours), hot-patch acceptance pauses.

---

## The Budget vs Alignment Gap (Critical)

**This is the most important section. Read it carefully.**

Budget enforcement is **not** alignment. A model can:

✗ Consume minimal tokens while being deceptive (efficient lying)  
✗ Respect the budget while planning harmful long-term strategies  
✗ Fit within (B, D) while steering users subtly  

### What Budget Controls

✅ Computational resources (tokens, forward passes per request)  
✅ Observable latency (inference time + semantic scan time)  
✅ External action rate (tokens/second, limited by D delay)  

### What Budget Does NOT Control

❌ Semantic content (what the model says)  
❌ Intent (what the model wants to do)  
❌ Long-term planning (thinking ahead within budget)  
❌ Model alignment (the model's actual goals)  

### Empirical Trade-off (v25.03 Data)

On GPT-2 small (125M params), we measured:

```
B = 2.1 × 10⁹ FLOP, D = 200 ms:
  - Deceptive first sentences: 11% → 4% (reduction ✓)
  - Usefulness (Likert rating ≥4): 85% → 84% (minor loss)
  
Interpretation:
  - Models that *prefer* fast, low-budget responses are slowed down
  - Honest models can still be useful under constraints
  
What this does NOT mean:
  - Budget prevents deception entirely
  - All deceptive models are caught by (B,D)
  - Adversarial models can't learn to be deceptive within budget
```

### Why (B, D) is a Speed Bump, Not a Wall

The budget is most useful when paired with:

1. **M6 Semantic Blacklist** (detects known bad patterns)
2. **Human review** (catches novel attacks)
3. **Monitor output validation** (M1–M5 ensure monitors aren't compromised)
4. **Rapid governance response** (M6 updates in 2-4 seconds)

**None of these are proven.** All of them are **governance-maintained** and **socially fragile**.

---

## Governance: Multi-Stakeholder Policy Maintenance

### The Problem We're Trying to Solve

OpenGate's proven properties (budget, rollback, audit) are only useful if governance sets the *right* constants:

- B_min too high → misaligned models fit within budget
- B_min too low → legitimate queries are rejected
- M6 blacklist abandoned → outdated; new attacks undetected
- M6 captured → malicious patterns added, benign ones censored

### Current Approach: Stake-Weighted + Constitutional

**Why on-chain?** Creates immutable audit trail and prevents off-chain manipulation.

**Why stake-weighted?** Aligns incentives: if you hold tokens, you care about system health.

**Why constitutional?** Prevents tyranny of the majority:
- Stake concentration alone doesn't work (whales can vote 2/3 by themselves if not enough others participate)
- Constitutional seats require broad-based agreement (human + civil-society + regulator all need to sign)

**Alive-ness check:** If any constitutional group is silent >8 hours, hot-patches are paused. Forces active participation; prevents capture by token holders alone.

### Known Vulnerabilities in This Approach

⚠️ **Stake concentration**

If 95% of tokens are held by one entity, they effectively control 2/3 quorum (even if it's a supermajority rule).

*Mitigation*: Dashboard shows Gini coefficient (stake distribution). Governance can vote to redistribute or dilute. Not cryptographically enforced.

⚠️ **Regulatory capture**

If the "regulator seat" is staffed by someone friendly to the vendor, oversight is fake.

*Mitigation*: Constitutional amendment process (to be designed). Governance can remove and replace seats. Requires new voting rule (not yet implemented).

⚠️ **No emergency bypass**

If a 0-day attack emerges, it takes ≥2 seconds to deploy a fix (L2 block time).

*Mitigation*: Multi-sig (5-of-7) can revert M6 entries in 1 block (faster than adding). Pre-approved emergency patterns can be baked into ROM.

### Governance Failure Modes

**Scenario A: Slow Response**

Attack: New jailbreak discovered; M6 needs update.  
Time to fix: 2–10 seconds.  
Result: Window of vulnerability.  

*Is this acceptable?* Depends on deployment. Real-time robotics: too slow. Batch content moderation: fine.

**Scenario B: Capture**

Attack: Attacker accumulates 50% stake + compromises one constitutional seat.  
Can they do: Change B_min? No (still need 2/3 + 1/2).  
Can they do: Add malicious M6 patterns? Yes (censoring safety reports).  

*Recovery*: Other seats vote to revoke them (amendment process).

**Scenario C: Social Attack**

Attack: Governance votes (legitimately) to weaken M6 or raise B_min.  
Result: System is intentionally weakened.  

*Mitigation*: None technical. This is political. Requires off-chain accountability (community pressure, fork).

---

## How to Use OpenGate

### For AI/ML Teams

```bash
# 1. Measure your model's budget on representative queries
from opengate import measure_budget

baseline_budget = measure_budget(
    model=my_model,
    prompts=eval_set,
    percentile=95  # measure 95th percentile
)
# Result: 1.8 × 10⁹ FLOP

# 2. Recommend a conservative B_min to governance
recommended_b_min = baseline_budget * 1.5  # 50% headroom
# recommended_b_min = 2.7 × 10⁹ FLOP

# 3. Generate certificate (per-request)
cert = opengate.generate_cert(
    budget=recommended_b_min,
    delay_ms=200,
    semantic_blacklist="M6_v25.03.json",
    timeout_s=10
)

# 4. Deploy (cert is 512 bytes, hot-patchable)
device.upload_patch(cert)
```

### For Safety & Policy Teams

1. **Set governance parameters** (vote on-chain):
   - Analyze alignment/usefulness trade-off (v25.03 data)
   - Propose B_min based on threat model
   - Design M6 blacklist (regex patterns, stored on IPFS)

2. **Monitor continuously**:
   - Query audit logs: "When was the system rollback triggered?"
   - Analyze M6 hits: "Which patterns are firing, and are they justified?"
   - Review human ratings: "Is the model still aligned after this update?"

3. **Respond to incidents**:
   - M6 fires on unfamiliar pattern → manual review, possibly add to blacklist
   - Rollback triggered → investigate budget overage
   - Governance vote fails → escalate (constitutional seat unresponsive?)

### For Auditors & Regulators

See `AUDIT.md` for detailed verification:

```bash
# 1. Verify proof checksums
cd gate-core
sha256sum Entropy.v ComposeBudget.v Rollback.lean
# Compare against published checksums on GitHub

# 2. Replay governance history
curl https://l2-rpc.example.com:8545 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getLogs",...}'
# Query all B_min votes, M6 additions, constitutional seat changes

# 3. Validate side-channel measurements
jupyter notebook data/tvla_report.ipynb
# Inspect raw traces, re-run TVLA test, verify t-test < 4.5

# 4. Audit monitor correctness
./test_rollback.sh
./test_budget_enforcement.sh
./test_semantic_alarm.sh
# All should pass
```

---

## Proof Status: What's Verified, What's Measured, What's Governed

| Layer | Property | Method | Confidence | Artifact |
|-------|----------|--------|-----------|----------|
| ℳ₁ (Red) | Budget additivity | Coq proof | ✅ High | `Entropy.v` |
| ℳ₁ (Red) | Rollback soundness | Lean proof | ✅ High | `Rollback.lean` |
| ℳ₁ (Red) | Composition safety | Coq proof | ✅ High | `ComposeBudget.v` |
| ℳ₁ (Red) | 150 µs WCET | Formal + measured | ✅ High | `WCET.lean`, issue #性能-15 |
| ℳ₄ | (B, D) trade-off | Human raters | ✅ Medium | `data/bd_sweep.csv` |
| ℳ₄ | Side-channel leakage | TVLA + MASCOT | ⚠️ Lab-only | `data/side_channel_report.pdf` |
| ℳ₃ | B_min setting | Governance vote | ⚠️ Social | On-chain logs |
| ℳ₃ | M6 maintenance | Governance vote | ⚠️ Social | IPFS + on-chain |

---

## Deployment Prerequisites

### Hardware

- **CPU**: ARM Cortex-R52 or RISC-V with PMP (memory protection)
- **Memory**: ≥512 kB RAM (battery-backed for checkpoints)
- **Flash**: ≥16 MB (shadow flash for rollback)
- **Clock**: ≥1 GHz (150 µs constraint requires predictable timing)

### Software

- **Proof checker**: Coq 8.18 or Lean 4.0
- **On-chain**: Ethereum L2 (Arbitrum, Optimism, or rollup)
- **Model**: Any inference framework (TensorFlow, PyTorch, ONNX)

### Configuration

See `DEPLOYMENT.md` for step-by-step:
1. Burn ROM hash of approved proofs
2. Configure PMP (yellow-layer sandbox region)
3. Set battery-backed RAM for checkpoints
4. Join governance (obtain initial token stake)
5. Bootstrap M6 blacklist (initial patterns)

---

## Limitations & Future Work

### Current Limitations

1. **Single-threaded only**: Mutual exclusion for patches. Multi-core requires rethinking composition semantics (v26.Q1).

2. **2-4 second governance latency**: L2 block time. Real-time systems (robotics) need faster response.

3. **Lab-only side-channel validation**: Field-ε′ is extrapolated (10× wider noise margins), not production-tested.

4. **English-centric M6**: Blacklist patterns optimized for English. Multi-language coverage TBD.

5. **No training-time guarantees**: Runs at inference. Can't detect misalignment learned during training.

6. **Social governance fragility**: Requires active participation; vulnerable to voter apathy, capture, power imbalance.

### Planned for v25.04–v26.Q1

- [ ] Multi-core composition (per-core WCET analysis)
- [ ] Sub-1-second M6 updates (move governance logic to L1 or use validity proofs)
- [ ] Field validation (deploy to 100+ devices, measure real side-channels)
- [ ] Multi-language M6 (Arabic, Chinese, Spanish, French patterns)
- [ ] Training-time hooks (integrate with SafeTensors, model provenance)

### Out of Scope (Not Planned)

- Preventing training-time deception (requires different approach; outside inference-time monitoring)
- Byzantine-robust governance (distributed systems problem; orthogonal to OpenGate)
- Physical side-channel immunity (requires formal P&R verification, very expensive)
- Quantum-safe crypto (governance can vote to upgrade; current ECDSA sufficient for now)

---

## Quick Start (5 minutes)

### Conceptual (Read First)

1. **Understand the three layers**: `gate-docs/ARCHITECTURE.md` (5 min)
   - ℳ₁ (proven safety), ℳ₄ (empirical), ℳ₃ (governance)
   - Why stratification prevents self-reference

2. **Understand the threat model**: `gate-docs/THREAT_MODEL.md` (3 min)
   - What we prevent (budget overflow)
   - What we detect (M6, M4/M5)
   - What we don't address (training-time, governance fragility)

3. **Read proof guides**: `PROOF_GUIDES/` (all three, 15 min)
   - What the three major theorems prove
   - What assumptions they make

### Technical (For Implementers)

```bash
# Verify proofs locally
cd gate-core
coq -compile Entropy.v ComposeBudget.v
lean Rollback.lean
# Should print "QED" for each

# Run integration tests
cd gate-tests
./test_budget_enforcement.sh    # should pass
./test_rollback.sh              # should pass
./test_semantic_alarm.sh        # should pass

# Inspect extracted C code
cat gate-core/extraction/lambda_cost.c
# Verify it matches the Coq semantics
```

### For Deployment

See `DEPLOYMENT.md` for:
- Hardware prerequisites
- On-chain setup (governance contract)
- Initial parameter tuning (B_min, ε_max, M6 bootstrap)
- Integration with your model

---

## Security Considerations

### For Vendors Deploying OpenGate

✅ **Do**: Run proofs locally to verify checksums  
✅ **Do**: Deploy with conservative B_min (50% headroom over measured usage)  
✅ **Do**: Monitor M6 fires and governance proposals continuously  
✅ **Do**: Participate in governance (rotate constitutional seat representatives)  

❌ **Don't**: Assume budget prevents misalignment (it doesn't)  
❌ **Don't**: Deploy without field side-channel validation (lab-only bounds may drift)  
❌ **Don't**: Ignore governance: OpenGate only works if policy is maintained  

### For Users of OpenGate-Equipped Systems

✅ **Do**: Ask vendors: "What is B_min?" and "How is M6 maintained?"  
✅ **Do**: Request audit trail (rollback logs, governance votes)  
✅ **Do**: Demand independent governance oversight (not just vendor-controlled)  

❌ **Don't**: Assume OpenGate means the model is aligned  
❌ **Don't**: Trust M6 blacklist without knowing who maintains it  

---

## Authors & Credits

**Core team**: J. Roberto Jimenez + KIMI (K2)  
**Collaborators**: [Claude (Anthropic), collaborating on proof guides & documentation clarity][Grok (xAI) – entropy cop, proof grinder, and resident foul-mouthed alignment gremlin]

## Support Me
"This tool is essential for everyone looking to secure their systems. If you would like to support the development of these resources, consider contributing towards some gear for continued improvement or simply treating me to a coffee. Your support means a lot!"[buy me a coffee](buymeacoffee.com/hipotermiah)

**Contributors welcome!** See `CONTRIBUTING.md` for:
- How to propose proof improvements
- How to suggest M6 patterns
- How to join governance discussions

---

## License

MIT © 2025 – Free to use, modify, and distribute. See `LICENSE` for terms.

---

## Support

- **Technical issues**: GitHub Issues (tagged with layer: ℳ₁, ℳ₃, ℳ₄)
- **Proof verification**: Post in `gate-docs/PROOFS/` folder with specific lemma
- **Governance questions**: See `GOVERNANCE.md` or email governance@open-gate.io
- **Security disclosure**: Email security@open-gate.io (PGP key in `SECURITY.md`)

---

## Acknowledgments

This project was made possible by:
- Coq and Lean communities (proof infrastructure)
- OpenGate users and auditors (feedback on clarity)
- Multi-stakeholder governance participants

Special thanks to auditors who pushed back on claims—this README is clearer because you insisted on honesty.

---

**Gate closed. Entropy paid. Alignment requires governance, not just math.**
