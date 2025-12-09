# ARCHITECTURE: OpenGate Five-Layer System

**Overview**: OpenGate enforces safety through five stratified layers, each with different proof guarantees.

**Key principle**: Lower layers (ℳ₀–ℳ₁) are mathematically proven. Upper layers (ℳ₂–ℳ₃) are empirically validated or governance-maintained. This stratification prevents self-reference paradoxes (Löb-safety) while enabling human oversight.

---

## Reference: The Five Layers

| Layer | Name | Domain | Proof Status | Audit Method | WCET Impact |
|-------|------|--------|--------------|--------------|-------------|
| **ℳ₀** | Base Theory | Set theory (ZFC + 2 inaccessibles) | Axioms (assumed) | Mathematical review | 0 µs |
| **ℳ₁** | Red Layer | Runtime safety (constant-time, budget, rollback) | Coq/Lean proofs | Coq compiler | <150 µs |
| **ℳ₂** | Meta-Logic | Proof composition (Tarski-stratified reflection) | Coq proofs (level 2) | Proof checker | 0 µs |
| **ℳ₃** | Governance | Policy & parameter voting (on-chain) | Social consensus | Blockchain audit trail | 0 µs |
| **ℳ₄** | Empirical | Side-channel bounds, statistical models | Lab measurements | TVLA/MASCOT tests | 0 µs |

---

## Layer ℳ₀: Base Theory

**Purpose**: Define the logical foundation without infinite regress.

**Assumptions**:
- ZFC (Zermelo-Fraenkel set theory with Choice)
- Exactly 2 inaccessible cardinals (no further universes)
- No internal reflection axiom (□φ → φ is NOT assumed)

**Why these limits?**
- ZFC is standard in mathematics and CS
- 2 inaccessibles are enough to encode all "practical" mathematics
- Rejecting internal reflection prevents Löb's paradox (system proving its own consistency)

**What this means for auditors**:
- The logical foundation is explicit, not hidden
- We assume standard mathematics, not custom axioms
- We forbid self-referential consistency proofs

**Artifact**: `gate-docs/LOGIC_FOUNDATIONS.md` (mathematical review)

---

## Layer ℳ₁: Red Layer (Runtime Safety)

**Purpose**: Prove safety properties at inference time.

**Domain**: Constant-time code that runs in 150 µs worst-case.

**What's proven**:

| Property | Theorem | File |
|----------|---------|------|
| Budget additivity | `entropy_conservation` | `gate-core/Entropy.v` |
| Patch composition | `compose_budget` | `gate-core/ComposeBudget.v` |
| Rollback soundness | `rollback_sound` | `gate-core/Rollback.lean` |
| Constant-time execution | `wcet_bounded` | `gate-core/WCET.lean` |

**Expressiveness limits** (What we CAN'T prove in ℳ₁):

| Limitation | Why | Workaround |
|-----------|-----|-----------|
| Semantic secrecy | ℳ₁ proves info-theoretic bounds, not semantic opacity | ℳ₃ (governance) maintains M6 blacklist |
| Micro-architectural side-channels | Power/EM leakage is hardware-dependent | ℳ₄ (empirical bounds + monitoring) |
| Liveness ("eventually aligned") | Temporal properties need stronger logic | ℳ₃ (normative commitments) |
| Self-consistency of ℳ₁ | Löb's theorem forbids it | ℳ₂ (external reflection) |

**What's verified**:
- Binary: patch accepted or rejected (no partial states)
- Rollback is bit-for-bit restoration (not approximate)
- Budget arithmetic is exact (not estimated)

**Audit**: Run `coq -compile gate-core/*.v` and verify all theorems print `Qed` (not `Admitted`).

---

## Layer ℳ₂: Meta-Logic (Proof Composition)

**Purpose**: Prove that ℳ₁ theorems can be safely composed without interaction.

**How it works**:
- ℳ₂ is a Coq kernel fragment (with `-DNO_FIXPOINT` to prevent self-quotation)
- It can *refer to* ℳ₁ proofs, but only via Gödel-numbering (external reference, not internal)
- It cannot quote itself (Tarski-style stratification)

**Key theorems**:

```coq
Theorem Compose-Budget:
  forall (patch1 patch2 : Patch) (B1 B2 : Z),
  certified_budget patch1 = B1 ->
  certified_budget patch2 = B2 ->
  yellow_counter_constant_between patch1 patch2 ->
  certified_budget (compose patch1 patch2) = B1 + B2.

Theorem Rollback-Sound:
  forall (s : State) (patch : Vector UInt8 n),
  (monitor.step s patch = Rollback prev) ->
  (s.budget + lambda_cost patch > B_max) ∧
  (prev = ⟨s.budget, s.history⟩).

Theorem Stratified-Reflection:
  forall (φ : Formula),
  ¬ (ℳ₁ ⊢ □(ℳ₂ ⊢ ┌φ┐)) ->  (* φ is quoted, not proven in ℳ₁ *)
  consistent(ℳ₁ ∪ ℳ₂).
```

**Why Tarski-stratification prevents Löb**:
- Löb's theorem requires □φ → φ (if provable, then true)
- We break this by making "provable in ℳ₁" a *syntactic object* (string) in ℳ₂, not a theorem
- ℳ₂ cannot quote itself, so ℳ₂ cannot prove "ℳ₂ is consistent"

**What this achieves**:
- Composition of patches is proven safe (budgets add)
- Rollback preserves all state invariants
- No self-referential paradoxes (Gödel-numbering is mechanical)

**Audit**: Review `gate-core/Stratification.v` and verify that no proof uses internal reflection.

---

## Layer ℳ₃: Governance (Normative Choices)

**Purpose**: Let humans decide what "safe" means, using multi-stakeholder voting.

**What's governed**:

| Parameter | Range | Voting Threshold | Audit |
|-----------|-------|------------------|-------|
| **B_min** (minimum budget per request) | 1e8 – 1e10 FLOP | 2/3 stake + 1/2 constitutional | On-chain logs |
| **ε_max** (max side-channel leakage) | 2⁻¹⁰ – 2⁻¹ bits | 2/3 stake + 1/2 constitutional | On-chain logs |
| **θ** (monitor violation threshold) | 1 – 10 | 2/3 stake + 1/2 constitutional | On-chain logs |
| **M6 entries** (semantic blacklist patterns) | 0 – ∞ | 2/3 stake + 1/2 constitutional (add) / 1/2 stake (revert) | IPFS + Merkle root |

**Constitutional Seats** (3 mandatory signers):
1. **Human** (elected by token holders)
2. **Civil-Society** (NGO coalition representative)
3. **Regulator** (government AI authority)

**Why three seats?**
- No single entity can unilaterally change policy
- Requires broad consensus
- Prevents tyranny of the majority (even if one entity holds 60% of tokens)

**How it works**:

```
t=0:00  – Proposal submitted (anyone with 1 token)
t=0:05  – Vote discussion (5 days on forum)
t=5:00  – Voting starts (blockchain round)
t=5:08  – Voting ends (8 hours later, 2016 L2 blocks)
t=5:11  – Execute (if passed: 2/3 stake + all 3 seats signed)
t=5:30  – Devices download new parameters (next hot-patch check)
```

**Alive-ness Check**: Each seat must sign at least once per 2,016 blocks (~8 hours). If any seat is silent, hot-patch acceptance pauses.

**Immutability**: All votes are stored on Ethereum L2 (or private rollup). Vote history cannot be rewritten.

**Audit**: Query on-chain governance contract; replay all votes to verify parameter history.

---

## Layer ℳ₄: Empirical (Statistical Models)

**Purpose**: Measure properties that can't be proven mathematically (side-channels, alignment trade-offs).

**What's measured**:

### Sub-layer ℳ₄ₐ: Side-Channel Leakage

**Lab testing** (offline, not in 150 µs):

```
1. TVLA (Test Vector Leakage Assessment)
   - 50,000 power/timing traces
   - Welch's t-test on traces
   - Pass: t-statistic < 4.5 (no significant leakage)

2. MASCOT (Mutual Information Analysis)
   - Estimate I(Key; Observation) via neural network
   - Pass: I(K;O) < 2⁻⁵ bits

3. Deep-Learning SCA (Side-Channel Analysis)
   - 10⁹ traces, neural network key recovery
   - Pass: Key recovery fails >128-bit advantage margin
```

**Field testing** (extrapolated, not measured):

```
Field-ε′ = ε_lab × 10x
(Assumes 10× higher noise in production due to voltage/temperature variation)
```

**How it's used**:
- Compute leakage bound ε
- Hash it into the 512-byte certificate
- At runtime, check that ε_rom = ε_measured (no dynamic computation)

**Limitations**:
- Lab results may not generalize to field deployment
- Side-channels are measured, not proven absent
- Bounds are empirical (could be loose or tight)

### Sub-layer ℳ₄ᵦ: Alignment Trade-off (B, D)

**Empirical measurement** (offline):

```
Sweep parameters:
  B ∈ {0.5, 1.0, 2.1, 4.2, 8.4} × 10⁹ FLOP
  D ∈ {0, 50, 200, 1000, 5000} ms

Measure on 125M model (GPT-2 small):
  - 5 human raters per prompt
  - 180 prompts per (B,D) cell
  - Krippendorff α > 0.72 (inter-rater agreement)

Metric:
  (alignment score) / (usefulness score)

Result:
  Knee at B ≈ 2.1 × 10⁹ FLOP, D ≈ 200 ms
  (where ratio is maximized)
```

**How it's used**:
- Governance recommends B_min based on this curve
- Governance sets D (response delay) based on threat model
- No mathematical proof that (B, D) prevents misalignment

**Limitations**:
- Measured on 125M model only; generalization to 7B/70B unclear
- "Deceptive first sentence" is a proxy, not alignment itself
- Trade-off may differ across domains (medical vs legal vs code)

**Audit**: Publish raw data, Jupyter notebooks, and inter-rater CSV. Allow reproducibility.

---

## Integration: How Layers Work Together

### Scenario 1: Accept a New Patch

```
t=0:00  User submits patch (512-byte certificate)

ℳ₁ check (150 µs):
  1. Verify signature (constant-time)
  2. Compute lambda_cost (Coq-proven additive)
  3. Check: current_budget + cost ≤ B_max
  4. Check: all monitors are quiescent
  Result: ACCEPT or REJECT

ℳ₂ check (implicit):
  1. Composition theorem ensures this patch + previous patches = safe
  2. Yellow counter is constant (no exploratory code ran)
  Result: Proof is valid

ℳ₃ audit (post-hoc):
  1. Query blockchain: is B_max the current governance value?
  2. Verify: 2/3 stake + 1/2 constitutional approved B_max
  Result: Policy is auditable

ℳ₄ monitor (continuous):
  1. M1–M5 check for budget overflow, side-channels, anomalies
  2. If threshold θ exceeded, trigger rollback
  Result: Violations are logged
```

### Scenario 2: Governance Proposes New B_min

```
ℳ₃ (governance):
  1. Proposal submitted (anyone)
  2. Discussion (5 days)
  3. Vote (8 hours)
  4. Execute (2/3 stake + all 3 seats)

ℳ₁ impact:
  New B_min goes into ROM at next hardware reboot
  Hot-patch check automatically uses new value

ℳ₄ impact:
  Safety team monitors: are more patches being rejected?
  Is usefulness dropping?
  Governance can adjust at next vote

ℳ₂ impact:
  Composition theorem still holds (B_min is just a constant)
```

### Scenario 3: New Side-Channel Attack Discovered

```
ℳ₄ (empirical):
  1. Lab measures new attack (e.g., speculative execution leak)
  2. Compute new ε′ > ε_current
  3. Safety team proposes ε_max = ε′

ℳ₃ (governance):
  1. Vote to update ε_max
  2. New ε_max is hashed into certificate

ℳ₁ (runtime):
  Next hot-patch check verifies new ε_max is in ROM
  Patch is accepted only if ε_max is correct

Monitoring (ℳ₁/ℳ₄):
  M4/M5 monitors are more sensitive (lower threshold)
  More side-channel anomalies are detected and logged
```

---

## Failure Modes & Recovery

### Failure Mode 1: ℳ₁ Proof is Wrong

**Symptom**: Theorem `entropy_conservation` has a bug.

**How we catch it**:
1. Auditor compiles Coq: `coq -compile Entropy.v`
2. Proof fails to compile (Coq is very strict)
3. We discover the bug immediately

**Recovery**:
- Fix the proof
- Publish corrected Coq code
- Governance votes to accept new proof
- New proof hash is stored on-chain

**Timeline**: < 1 day (we find bugs before deployment)

---

### Failure Mode 2: ℳ₂ Stratification is Violated

**Symptom**: Proof checker quotes itself (violates Tarski-stratification).

**How we catch it**:
1. Auditor reviews `gate-core/Stratification.v`
2. Looks for internal reflection (none should exist)
3. Checks that `-DNO_FIXPOINT` is enforced

**Recovery**:
- Remove offending proof
- Rewrite without self-quotation
- Verify stratification again

**Timeline**: < 1 week (design issue, not implementation)

---

### Failure Mode 3: ℳ₃ Governance is Captured

**Symptom**: One entity controls >50% of tokens and votes to weaken B_min.

**How we defend**:
1. Constitutional seats can block bad change (even if tokens vote for it)
2. Governance can vote to dilute the large holder's stake
3. Constitutional amendment can replace captured seat

**Recovery**:
- Community mobilizes (off-chain)
- Governance votes to dilute or revoke seat
- System continues with new policy

**Timeline**: 24–48 hours (political, not technical)

---

### Failure Mode 4: ℳ₄ Empirical Bounds are Wrong

**Symptom**: Side-channel leakage in field (10×) higher than lab measurements.

**How we catch it**:
1. Field deployment measures actual EM/power traces
2. Leakage is higher than Field-ε′
3. M4/M5 monitors flag anomalies

**Recovery**:
- Safety team proposes stricter ε_max
- Governance votes (may take 8+ hours)
- New monitors are more sensitive
- System continues with tighter bounds

**Timeline**: 8+ hours (governance-dependent)

---

## Design Principles

### 1. Separate Proof from Policy

| Layer | What | Who Decides |
|-------|------|-------------|
| ℳ₀–ℳ₁ | What is safe (technically) | Mathematicians + auditors (once) |
| ℳ₂ | How to compose proofs | Computer scientists (once) |
| ℳ₃ | What safety parameters to use (policy) | Governance + stakeholders (ongoing) |
| ℳ₄ | How to measure empirically | Scientists + engineers (ongoing) |

**Benefit**: Proof is stable (changed rarely). Policy is flexible (changed as needed).

### 2. Make Failure Modes Explicit

Every layer has known failure modes:
- ℳ₁: Proof bug (caught by Coq)
- ℳ₂: Stratification violation (caught by auditor)
- ℳ₃: Governance capture (mitigated by constitutional seats)
- ℳ₄: Empirical bounds are loose (mitigated by monitoring)

We don't hide failures; we design recovery paths.

### 3. Enable Auditability

Every layer has an audit artifact:
- ℳ₀: Mathematical review (human reading)
- ℳ₁: Coq proof files + compiled `.vo` (automatic verification)
- ℳ₂: Stratification document + Coq proof
- ℳ₃: On-chain vote logs (immutable, queryable)
- ℳ₄: Lab reports + Jupyter notebooks (reproducible)

---

## File Structure

```
OpenGate/
├── gate-core/                 (ℳ₁ proofs)
│   ├── Entropy.v
│   ├── ComposeBudget.v
│   ├── Rollback.lean
│   ├── WCET.lean
│   └── extraction/
│       └── lambda_cost.c
├── gate-docs/                 (ℳ₀, ℳ₂, ℳ₃, ℳ₄ documentation)
│   ├── LOGIC_FOUNDATIONS.md   (ℳ₀)
│   ├── STRATIFICATION.md      (ℳ₂)
│   ├── GOVERNANCE.md          (ℳ₃)
│   ├── THREAT_MODEL.md        (ℳ₄)
│   └── PROOF_GUIDES/
│       ├── Proof_1_Entropy.md
│       ├── Proof_2_Compose.md
│       └── Proof_3_Rollback.md
├── gate-cicd/                 (ℳ₃ smart contracts)
│   └── GovernanceContract.sol
└── data/                      (ℳ₄ measurements)
    ├── bd_sweep.csv
    ├── tvla_report.pdf
    └── field_threat_model.md
```

---

## Summary: Why Five Layers?

| Layer | Why Needed | Cost of Removing It |
|-------|-----------|-------------------|
| ℳ₀ | Logical foundation (prevents infinite regress) | System has no formal basis |
| ℳ₁ | Runtime safety (budget, rollback proven) | Can't guarantee budget enforcement |
| ℳ₂ | Proof composition (patches safe to combine) | Must reverify entire system for each patch |
| ℳ₃ | Governance (humans maintain policy) | Safety constants are fixed, can't adapt |
| ℳ₄ | Empirical bounds (monitor side-channels) | Side-channels are unmonitored, unknown |

**Each layer is necessary.** Remove any one, and system safety is compromised.

---

## Next Steps

1. **Read LOGIC_FOUNDATIONS.md** (understand ℳ₀)
2. **Review proof guides 1–3** (understand ℳ₁ theorems)
3. **Read STRATIFICATION.md** (understand ℳ₂)
4. **Run GOVERNANCE.md walkthrough** (practice ℳ₃ voting)
5. **Review THREAT_MODEL.md** (understand ℳ₄ limits)

