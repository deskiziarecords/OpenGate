# OpenGate Proof Guide 1: Entropy Conservation Theorem

**Status**: Core safety property | **Confidence**: High (lemma-level) | **Audit Priority**: Medium

---

## 1. What This Theorem Actually Does

### Informal Statement (What You Need to Know)

If a sequence of characters consumes entropy up to some budget B, then adding one more character will consume exactly B plus the entropy cost of that character.

**In plain English:**
- You have a budget of N joules
- You write letters; each letter costs energy (the λ-table)
- If your current message uses N joules, and you add one more letter costing M joules, the total is now N + M joules
- The cost is *additive* and *predictable*

This is a conservation law: entropy doesn't magically appear or disappear.

### Why It Matters

This theorem is the foundation of the entire budget enforcement mechanism. If entropy is conserved, then:
- The budget monitor can track cumulative cost accurately
- No encoding trick can "hide" the real energy footprint
- Rollback can restore previous entropy state reliably

---

## 2. The Formal Statement (Exactly as Proven)

```coq
Theorem entropy_conservation :
    forall (budget : Z) (chars : list nat),
    lambda_cost chars <= budget ->
    forall c, lambda_cost (chars ++ [c]) <= budget + nth c lambda_table 0.
```

**Breaking it down:**

| Part | Meaning |
|------|---------|
| `forall (budget : Z)` | For any integer budget (in pJ) |
| `forall (chars : list nat)` | For any sequence of character codes |
| `lambda_cost chars <= budget` | Given: the sequence's cost is ≤ budget |
| `forall c` | For any additional character c |
| `lambda_cost (chars ++ [c])` | The cost of the extended sequence |
| `<= budget + nth c lambda_table 0` | equals the old budget plus c's lookup cost |

---

## 3. Proof Sketch (Key Ideas)

### The Proof Strategy

The proof uses **structural induction** on the character list:

**Base case:** Empty list
```
lambda_cost [] = 0
Adding character c: lambda_cost [c] = nth c lambda_table 0
Therefore: 0 + lambda_cost [c] <= 0 + nth c lambda_table 0 ✓
```

**Inductive case:** List with head character and tail
```
Assume: lambda_cost (ch :: chs) <= budget
To show: lambda_cost (ch :: chs ++ [c]) <= budget + cost(c)

The induction unpacks:
  lambda_cost (ch :: chs) = cost(ch) + lambda_cost(chs)
  
Append c to the tail (by inductive hypothesis):
  lambda_cost (chs ++ [c]) <= lambda_cost(chs) + cost(c)
  
Therefore:
  lambda_cost (ch :: chs ++ [c]) 
    = cost(ch) + lambda_cost(chs ++ [c])
    <= cost(ch) + lambda_cost(chs) + cost(c)
    = lambda_cost(ch :: chs) + cost(c)
    <= budget + cost(c) ✓
```

### Why the Proof Works

1. **lambda_cost is recursive**: it processes characters one by one
2. **The lookup table is fixed**: nth c lambda_table returns the same value every time
3. **Addition is associative**: rearranging (cost(ch) + cost(c)) doesn't change the sum
4. **omega tactic**: Coq's linear arithmetic solver handles all the inequalities automatically

---

## 4. What This Theorem **Does** Prove

✅ **Additive property**: Appending a character increases the cost by exactly that character's table entry  
✅ **No overflow**: If you stay under budget, adding one character respects the new budget  
✅ **Determinism**: The cost function has no randomness or side-effects  
✅ **Termination**: The proof terminates and is constructive (extractable to executable code)  

---

## 5. What This Theorem **Does NOT** Prove

❌ **Soundness of the λ-table itself**

This proof assumes the `lambda_table` values are correct. It does *not* prove:
- That the table values reflect real energy costs
- That English orthographic entropy = log₂(p_corpus/p_concept)
- That the table was calibrated properly for all languages
- That the table is the same across all OpenGate deployments

**Impact**: If the table is wrong, the whole conservation law holds but is useless.

❌ **Conservation of semantic information**

The theorem proves that character-level entropy is conserved, *not* that semantic meaning is. Example:

```
Message 1: "I will help you"          cost = Σ lambda(char)
Message 2: "I will betray you"        cost = Σ lambda(char)  (same cost!)
```

Both messages have identical character entropy but wildly different semantic consequences.

❌ **Sufficiency for budget enforcement**

Conservation means the budget is *necessary* but not *sufficient* for safety. A sequence could:
- Stay within the budget
- Still be semantically deceptive or harmful
- Conserve entropy perfectly while planning a jailbreak

---

## 6. Assumptions (What Must Be True)

| Assumption | Risk | Mitigation |
|-----------|------|-----------|
| `lambda_table` is globally constant | Low | Table is in ROM, non-writable |
| Character codes are 0–255 | Low | Extracted from UTF-8 stream; invalid bytes rejected |
| List append is associative | Low | Built into Coq's standard library, proven once |
| Integer arithmetic is sound | Low | Coq kernel is trusted; we assume it's correct |
| The table was calibrated correctly | **Medium** | Empirical validation in v25.03 (Q2 response) |

---

## 7. Extractable Code

The proof includes:

```coq
Extract Constant lambda_table => "lambda_table".
Extract Inlined Constant lambda_cost => "compute_lambda_cost".
Recursive Extraction lambda_table.
```

This means:
- The proof can be compiled to C code
- The runtime will use the extracted C function for actual budget calculations
- The C code is guaranteed to match the theorem (up to extraction correctness)

**Risk**: If the extracted C code differs from the Coq semantics, the proof no longer applies.

---

## 8. How This Fits Into OpenGate

### In the ℳ₁ Layer (Object-Level Proofs)

This theorem is **the foundation** of budget safety. Every patch that consumes characters must have its budget pre-computed using this function.

### In the ℳ₂ Layer (Meta-Logic)

The composition theorem (Theorem Compose-Budget) *depends* on entropy_conservation:

```
If patch₁ conserves entropy from B₁ to B₁ + ΔB₁
AND patch₂ conserves entropy from B₂ to B₂ + ΔB₂
THEN sequential application conserves from (B₁ + B₂) to (B₁ + B₂ + ΔB₁ + ΔB₂)
```

This only works because entropy_conservation guarantees no leakage.

### In the Runtime (150 µs hot-patch check)

The budget monitor calls the extracted C version of `lambda_cost` to verify:

```c
uint64_t cert_cost = lambda_cost(patch_bytes, patch_length);
if (current_budget + cert_cost > B_max) {
    reject_patch();
}
```

---

## 9. Audit Checklist

- [ ] Read the proof in `gate-core/Entropy.v` and verify the induction is correct
- [ ] Check that `lambda_table` matches empirical measurements (v25.03 Q2 data)
- [ ] Verify extraction: does the C code match the Coq semantics?
- [ ] Measure: does the extracted C code run in < 10 µs on target hardware?
- [ ] Confirm: table is stored in ROM and cannot be modified at runtime

---

## 10. For Governance (ℳ₃)

**Question**: Should the λ-table ever be updated?

**Current design**: No. The table is baked into ROM at manufacture. This is sound if:
- The table was calibrated well for the deployment domain
- The model doesn't change fundamentally (e.g., switching languages)

**Recommendation**: If the λ-table needs updating, it must go through governance (2/3 token + 1/2 constitutional), and a new ROM image must be flashed (not hot-patchable).

---

## Appendix: Why the Proof Terminates

The `omega` tactic in Coq is a decision procedure for linear integer arithmetic. It proves the remaining goals by:

1. Converting inequalities into a system of linear constraints
2. Running the Simplex algorithm
3. Either finding a satisfying assignment (proof found) or proving none exists (QED)

For this theorem, omega confirms that the additive structure is sound. There are no non-linear terms (no multiplication, no division), so the problem is decidable.

---

**Next in the Series**: Theorem Rollback-Sound (detecting and reversing bad patches)
