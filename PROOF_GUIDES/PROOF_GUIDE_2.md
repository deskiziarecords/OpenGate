# OpenGate Proof Guide 2: Composition Budget Theorem

**Status**: Core safety property | **Confidence**: Pending review of formal proof | **Audit Priority**: High

⚠️ **DRAFT**: This guide is written from the architecture document. It will be updated once the formal Coq proof is provided.

---

## 1. What This Theorem Actually Does

### Informal Statement (What You Need to Know)

If you apply patch₁ (costing ΔB₁ entropy) and then patch₂ (costing ΔB₂ entropy), the total entropy consumed is exactly ΔB₁ + ΔB₂.

**In plain English:**
- Patch 1 uses 1000 pJ of budget
- Patch 2 uses 500 pJ of budget
- Together, they use 1500 pJ (no surprises, no hidden interactions)

This is a **compositionality** result: the budget behavior is modular. You can reason about patches independently, then add their costs.

### Why It Matters

This theorem justifies the entire patching architecture:
- You can certify patches independently
- You can compose them safely without re-computing the full budget
- The total budget of a system is the sum of its patch budgets
- There are no emergent costs from composition

Without this, you'd have to verify every combination of patches individually (exponential explosion).

---

## 2. The Formal Statement (As Expected)

```coq
Theorem compose_budget :
    forall (patch1 patch2 : Patch) (B1 B2 : Z),
    certified_budget patch1 = B1 ->
    certified_budget patch2 = B2 ->
    yellow_counter_constant_between patch1 patch2 ->  (* key assumption *)
    certified_budget (compose_sequential patch1 patch2) = B1 + B2.
```

**What each part means:**

| Part | Meaning |
|------|---------|
| `forall (patch1 patch2 : Patch)` | For any two firmware patches |
| `forall (B1 B2 : Z)` | With certified budgets (in pJ) |
| `certified_budget patch1 = B1` | Patch 1's cost is B1 (from entropy_conservation theorem) |
| `certified_budget patch2 = B2` | Patch 2's cost is B2 (from entropy_conservation theorem) |
| `yellow_counter_constant_between patch1 patch2` | **Critical assumption**: yellow-layer code did NOT run between them |
| `certified_budget (compose_sequential ...) = B1 + B2` | The composed system's budget is the sum |

---

## 3. Proof Sketch (Key Ideas)

### Why Composition Works

The proof hinges on a single fact: **the yellow counter (YC) didn't change**.

**Intuition:**

```
patch1 runs:
  initial_budget = B₀
  red-layer runs, consumes ΔB₁
  final_budget = B₀ - ΔB₁
  YC = k (unchanged)

patch2 runs:
  initial_budget = B₀ - ΔB₁
  red-layer runs, consumes ΔB₂
  final_budget = B₀ - ΔB₁ - ΔB₂
  YC = k (unchanged)

Therefore:
  compose(patch1, patch2) consumes ΔB₁ + ΔB₂
```

### The Proof Strategy

**Step 1: Decompose by layer**

Every patch is partitioned into:
- Red code (verified, budget-tracked)
- Yellow code (sandboxed, budget-independent)

```coq
forall p : Patch, p = red_part p ++ yellow_part p
```

**Step 2: Yellow-counter soundness**

By the design of the hardware (PMP region isolation), yellow code execution increments YC. The assumption `yellow_counter_constant_between patch1 patch2` means:

```coq
YC_before (compose patch1 patch2) = YC_after (compose patch1 patch2)
  <=> yellow_part patch1 = [] AND yellow_part patch2 = []
```

**Step 3: Budget conservation (red layer only)**

For red-only code, entropy_conservation applies to each patch:

```coq
certified_budget (red_part patch1) = B1
certified_budget (red_part patch2) = B2
```

**Step 4: Composition is linear**

Red-layer code has no side-effects on budget accounting (by assumption A2):

```coq
certified_budget (red_part patch1 ++ red_part patch2)
  = certified_budget (red_part patch1) + certified_budget (red_part patch2)
  = B1 + B2
```

**Step 5: Conclude**

Since yellow parts are empty (from YC assumption), the composed patch is red-only:

```coq
certified_budget (compose_sequential patch1 patch2)
  = certified_budget (red_part (patch1 ++ patch2))
  = B1 + B2
```

---

## 4. What This Theorem **Does** Prove

✅ **Modularity**: Patches can be verified independently and safely composed  
✅ **No emergent costs**: Composition doesn't create unexpected budget interactions  
✅ **Additivity**: B_total = Σ B_patch (linear accounting)  
✅ **Transitivity**: If A + B = C and C + D = E, then A + B + D = E  

---

## 5. What This Theorem **Does NOT** Prove

❌ **That no yellow code actually ran**

The theorem is conditional: `IF yellow_counter_constant_between patch1 patch2 THEN composition is safe`.

But:
- The hardware *enforces* this with PMP isolation
- However, if PMP is misconfigured, the condition fails
- If condition fails, theorem doesn't apply

**Impact**: The proof is sound, but the *assumption* can be violated.

❌ **That budget prevents misalignment**

Composition only guarantees *additive cost*. Two patches could be individually aligned but, when composed, create a new capability.

Example:
```
patch1: "I can read user preferences"    (B1 = 500 pJ)
patch2: "I can execute system commands"  (B2 = 600 pJ)
compose(patch1, patch2): "I can read preferences AND execute commands"
  cost = B1 + B2 = 1100 pJ ✓ (theorem satisfied)
  but emergent behavior may be dangerous ✗ (not addressed by theorem)
```

❌ **That composition order doesn't matter**

The theorem is about sequential composition (patch1 *then* patch2), not parallel or out-of-order. Commutativity would be a separate theorem (and likely false for stateful patches).

---

## 6. Assumptions (What Must Be True)

| Assumption | Risk | Mitigation |
|-----------|------|-----------|
| `yellow_counter_constant_between patch1 patch2` | **High** | Hardware (PMP) enforces this; YC checked in cert |
| PMP region isolation is correct | **High** | Derived from CPU spec; validated at boot (TBD v25.03) |
| Red-layer code has no side-effects on budget | Medium | Verified separately (A2 in architecture doc) |
| Entropy_conservation holds for both patches | Low | Proved independently (Theorem 1) |
| Integer addition is associative | Low | Coq standard library |

---

## 7. The Critical Assumption: Yellow-Counter Soundness

### What YC Does

YC is a 64-bit register that increments by 1 each time execution crosses into the yellow-layer PMP region. The certificate includes:

```c
struct {
    uint64_t YC_before;    // expected YC value before patch runs
    uint64_t YC_after;     // expected YC value after patch runs
} yc_record;

bool check = (YC_current == YC_before && YC_next == YC_after);
if (!check) reject_patch();
```

### Why This Matters

If YC changes, it means yellow code ran. Yellow code can:
- Corrupt red-layer state
- Modify the budget accounting
- Escape the isolation

So the theorem says: "Composition is safe *only if* both patches run with YC constant (i.e., no yellow code)."

### What Can Go Wrong

**Attack 1: PMP misconfiguration**

If a yellow-region page is mapped to red-layer memory, attacker writes to red state.

**Mitigation**: Boot-time PMP validation (v25.03).

**Attack 2: Attacker supplies false YC_before/after**

Attacker claims YC was constant but it actually changed.

**Mitigation**: YC is a monotonic counter in hardware (saturating, not wrapping). The proof is only valid if hardware *enforces* the increment. (This is a hardware assumption, not provable in Coq.)

**Attack 3: Timing side-channel on PMP check**

Time-of-check vs time-of-use: attacker triggers yellow code *after* YC check but *before* patch runs.

**Mitigation**: PMP check happens *at the very start* of the hot-patch handler, before any patch code is copied to RAM. (Check the `runtime_check.c` timing model.)

---

## 8. How This Fits Into OpenGate

### In the ℳ₁ Layer

This is the cornerstone theorem for patch composition. Every time the system applies a new patch, the composition theorem justifies why the budgets add up.

### In the ℳ₂ Layer

The composition theorem is *reused* to prove global safety:

```coq
Theorem system_budget_sound :
    forall (patches : list Patch),
    (forall p in patches, certified_budget p < B_max) ->
    (forall i j, yellow_counter_constant_between patches[i] patches[j]) ->
    sum_of_budgets patches <= global_budget_limit.
```

### In the Runtime (150 µs hot-patch check)

The `runtime_check()` function in `runtime_check.c` verifies:

```c
// Extract YC from cert
uint64_t yc_before = read_from_cert(cert512, YC_OFFSET);
uint64_t yc_current = read_hardware_register(YC_REG);
if (yc_before != yc_current) return false;  // YC changed! Composition unsafe.

// Extract B from cert
uint64_t b_delta = read_from_cert(cert512, BUDGET_OFFSET);
if (current_budget + b_delta > B_MAX) return false;  // Would exceed limit

return true;  // Safe to apply
```

---

## 9. Audit Checklist

- [ ] Read the Coq proof in `gate-core/ComposeBudget.v` and verify induction
- [ ] Verify that YC is a hardware-enforced register (check RTL in `gate-core/rtl/yc_counter.sv`)
- [ ] Confirm: YC is saturating (overflow bit sticky), not wrap-around
- [ ] Test: Can you artificially trigger YC overflow and see the flag stick?
- [ ] Measure: PMP check + YC read happens before any patch code loads (timing trace)
- [ ] Validate: Boot-time PMP configuration check (v25.03 deliverable #硬件-33)
- [ ] Review: `runtime_check.c` to ensure it matches the Coq proof's assumptions

---

## 10. For Governance (ℳ₃)

**Question 1**: Should patches be composable at all, or should each deployment be monolithic?

**Current design**: Composable (enables hot-patching and incremental safety improvements).

**Trade-off**: Composability adds complexity (YC counter, PMP validation). Monolithic patches are simpler but less flexible.

**Governance decision**: Accept the complexity if you value rapid safety updates. Reject if you prefer simplicity.

---

**Question 2**: What's the policy for yellow-layer code?

**Current design**: Yellow code is sandboxed but not restricted. It can run experiments on the model, test new compression schemes, etc.

**Risk**: A malicious yellow patch could probe the red-layer budget and construct an attack.

**Governance decision**: Require code review and attestation for yellow patches, or restrict yellow to pre-approved, sandboxed experiments.

---

## Appendix: Why YC is Monotonic

The yellow-counter increment is implemented in hardware (not firmware), so attacker cannot "undo" it:

```verilog
always @(posedge clk) begin
    if (pmp_fault || yellow_entry) begin
        if (yc != 64'hFFFFFFFFFFFFFFFF)
            yc <= yc + 1'b1;
        else
            overflow_flag <= 1'b1;  // sticky
    end
end
```

Once set, `overflow_flag` stays set until power cycle. This is *provably* irreversible at the hardware level (no firmware can clear it).

---

**Next in the Series**: Theorem Rollback-Sound (preserving invariants through rollback)
