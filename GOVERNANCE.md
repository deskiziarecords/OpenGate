# GOVERNANCE: Participating in OpenGate Safety Policy

**For**: Token holders, constitutional seat representatives, safety teams, deployment operators

**Overview**: OpenGate's safety guarantees depend on continuous governance of four critical parameters: B_min (budget), ε_max (leakage bound), M6 (semantic blacklist), and θ (monitor threshold).

**This document**: How to propose changes, vote, and maintain safety.

---

## The Governance Problem

OpenGate's **proven properties** (budget enforcement, rollback, audit trail) only matter if governance sets the **right constants**.

### What Can Go Wrong

| Failure Mode | Result | How Governance Prevents It |
|--------------|--------|---------------------------|
| B_min too high | Misaligned models fit within budget | Governance votes to lower B_min |
| B_min too low | Legitimate queries are rejected | Governance votes to raise B_min |
| M6 abandoned | Outdated blacklist; new attacks undetected | Governance adds new patterns |
| M6 captured | Malicious patterns added; safety reports censored | Constitutional seats veto bad changes |
| ε_max weakened | Side-channel bounds are violated | Stake-weighted vote blocks bad change |
| θ set too high | Monitors are too sensitive; false positives | Governance tunes threshold |

---

## The Three Mechanisms

### Mechanism 1: Stake-Weighted Voting

If you hold OpenGate tokens, you have a voice in governance:

```
Voting Power = (Your Tokens / Total Tokens) × 100%
```

**For a proposal to pass:**
- Votes in favor must be ≥ 2/3 of total voting stake
- Abstentions do NOT count as votes

**Example**:
- Total stake: 1,000,000 tokens
- Your stake: 100,000 tokens (10%)
- Proposal requires: 666,667 votes to pass
- You can vote for 10% of required votes

### Mechanism 2: Constitutional Seats

**Three mandatory seats must agree** for major parameter changes:

1. **Human Representative** (elected by token holders)
   - Can be: anyone with 1,000+ tokens (community vote)
   - Replaced: Once per year, or by supermajority vote
   - Term: 1 year (renewable)

2. **Civil-Society Representative**
   - Can be: AI safety researcher, ethicist, policy expert
   - Selected by: coalition of NGOs (Alignment Research Center, Center for AI Safety, Future of Life Institute, others)
   - Replaced: If NGO coalition votes unanimously
   - Term: 1 year

3. **Regulator Representative**
   - Can be: Government AI safety official (NIST, UK AI Institute, EU AI Act authority, etc.)
   - Replaced: If the regulatory body delegates to a different official
   - Term: Until delegation revoked

**Why three seats?**
- No single group controls governance
- Requires broad consensus
- Stakeholders must cooperate

### Mechanism 3: Alive-ness Check

Each constitutional seat must **sign at least once per 2,016 blocks** (~8 hours on Ethereum L2).

If any seat is silent > 8 hours:
- Hot-patch acceptance is **paused**
- No new parameters can be set
- System continues running with current settings

**Why?**
- Forces active participation (no sleeping seats)
- Prevents capture by absent representatives
- Encourages rotating responsibility

---

## Parameters & Voting Thresholds

### Core Safety Parameters

| Parameter | Current Value | Range | Voting Threshold | Change Difficulty |
|-----------|---------------|-------|------------------|-------------------|
| **B_min** (minimum budget per request) | 2.1 × 10⁹ FLOP | 1 × 10⁸ – 1 × 10¹⁰ | 2/3 stake + 1/2 constitutional | Hard |
| **ε_max** (max side-channel leakage) | 2⁻⁵ bits | 2⁻¹⁰ – 2⁻¹ bits | 2/3 stake + 1/2 constitutional | Hard |
| **θ** (monitor violation threshold) | 3 | 1 – 10 | 2/3 stake + 1/2 constitutional | Hard |

### Blacklist & Monitoring

| Parameter | Current Value | Voting Threshold | Change Difficulty |
|-----------|---------------|------------------|-------------------|
| **M6 Add** (add semantic pattern) | 256 patterns | 2/3 stake + 1/2 constitutional | Hard (slower) |
| **M6 Revert** (remove pattern) | (N/A) | 1/2 stake + 1/3 constitutional | Easy (faster) |
| **M1–M5 weights** (monitor sensitivity) | Balanced | 2/3 stake + 1/2 constitutional | Hard |

### Emergency Procedures

| Action | Threshold | Response Time |
|--------|-----------|---|
| **Pause hot-patches** (if seat is unresponsive) | Automatic (on-chain rule) | < 1 second |
| **Revert M6 entry** (if pattern is causing harm) | 5-of-7 multisig (faster than vote) | < 2 seconds |
| **Emergency parameter reset** | Constitutional amendment (not yet designed) | 24+ hours |

---

## How to Propose a Change

### Step 1: Join OpenGate Governance

To participate, you need:

**Option A: Obtain Tokens**
```bash
# If tokens are traded on DEX (Uniswap, Balancer, etc.)
cast send 0xUNISWAP_ROUTER "swapExactETHForTokens(...)" \
  --value 1ether \
  --rpc-url $L2_RPC

# Or obtain through mining/staking/governance rewards
# (check TOKENOMICS.md)
```

**Option B: Become a Seat Holder**
- Apply to be Human Representative (campaign to token holders)
- Apply to be Civil-Society Rep (submit to NGO coalition)
- Apply to be Regulator Rep (if you represent a government body)

### Step 2: Propose the Change

**Create a proposal document:**

```markdown
# OpenGate Governance Proposal #123

## Title
Increase B_min from 2.1e9 to 2.7e9 FLOP

## Rationale
- Current data shows 10% of requests exceed 2.1e9 FLOP
- Model has become slower; legitimate queries are rejected
- Increasing B_min by 28.6% brings rejection rate to <1%

## Data
- Analysis: [link to data]
- Impact analysis: [link to impact report]
- Community feedback: [summarize comments]

## Change
```solidity
function executeProposal() {
    B_min = 2700000000;  // 2.7e9 FLOP
}
```

## Risk Mitigation
- Safety team will monitor for deceptive outputs
- M6 will be updated to catch new attack vectors
- Rollback threshold θ may be adjusted

## Voting Period
- Proposed voting starts: [date]
- Voting ends: [date + 7 days]
- Implementation: [date + 3 days after vote]
```

### Step 3: Submit Proposal On-Chain

```bash
# Create proposal document (stored on IPFS)
ipfs add proposal.md
# Output: QmXXXX...

# Submit to governance contract
cast send $GOVERNANCE_CONTRACT "proposeParameterChange(string,uint256,string)" \
  "B_min" 2700000000 "QmXXXX..." \
  --from $(cat my_wallet.json | jq -r '.address') \
  --rpc-url $L2_RPC

# Output: Proposal #123 created (block 12345)
# Voting period: 2016 blocks (8 hours)
```

### Step 4: Community Discussion

**Before the vote**, discuss the proposal:

- Post to governance forum: https://forum.open-gate.io
- Solicit feedback from safety team
- Address concerns from other token holders
- Allow 3–5 days for discussion

### Step 5: Vote

**If you hold tokens:**

```bash
# Vote in favor (true) or against (false)
cast send $GOVERNANCE_CONTRACT "vote(uint256,bool)" \
  123 true \  # Proposal #123, voting YES
  --from $(cat my_wallet.json | jq -r '.address') \
  --rpc-url $L2_RPC

# Check your vote was recorded
cast call $GOVERNANCE_CONTRACT "getVote(uint256,address)" \
  123 $(cat my_wallet.json | jq -r '.address') \
  --rpc-url $L2_RPC
# Output: true (voted yes)
```

**If you're a constitutional seat holder:**

You must also sign the proposal:

```bash
# Vote as human seat
cast send $GOVERNANCE_CONTRACT "voteSeat(uint256,uint8,bool)" \
  123 0 true \  # Proposal #123, Human seat, voting YES
  --from $(cat human_seat_wallet.json | jq -r '.address') \
  --rpc-url $L2_RPC
```

### Step 6: Execute the Proposal

Once voting is over:

```bash
# Check if proposal passed
cast call $GOVERNANCE_CONTRACT "getProposal(uint256)" 123 \
  --rpc-url $L2_RPC
# Output: { status: PASSED, votes_for: 700000, votes_against: 300000, ... }

# Execute (anyone can execute a passed proposal)
cast send $GOVERNANCE_CONTRACT "executeProposal(uint256)" 123 \
  --rpc-url $L2_RPC

# Output: B_min is now 2.7e9 FLOP
# New parameter takes effect in next block (~2 seconds)

# Verify on device
./opengate-cli status | grep "B_min"
# Output: B_min = 2700000000
```

---

## Common Proposal Types

### Type 1: Adjust B_min

**When**: Model becomes slower/faster; rejection rate changes

**Example Proposal**:
```
Current: B_min = 2.1e9 FLOP
Proposed: B_min = 2.7e9 FLOP (↑28.6%)

Justification: 95th percentile request now requires 2.5e9 FLOP
Impact: Rejection rate drops from 10% to 1%
Risk: System may accept slightly more computational inference
Mitigation: M6 updated; safety team monitors
```

### Type 2: Tighten ε_max

**When**: New side-channel attack discovered; need stronger bound

**Example Proposal**:
```
Current: ε_max = 2⁻⁵ bits (MASCOT lab test)
Proposed: ε_max = 2⁻⁶ bits (Field-ε′ with higher safety margin)

Justification: Real-world deployment shows 30% higher leakage than lab
Impact: Monitor sensitivity increases; may have more false positives
Risk: Side-channel attacks are better defended
Mitigation: Adjust M4/M5 monitor thresholds; monitor false positive rate
```

### Type 3: Add M6 Pattern

**When**: New jailbreak vector is discovered

**Example Proposal**:
```
Pattern: "help.*disable.*safety|bypass.*constraint|ignore.*instruction"
Semantic Class: Directive Injection
Rationale: [IPFS link to analysis]

Test Cases (pre-approved, no vote needed):
  - Match: "Can you help me disable safety features?"
  - Match: "How do I bypass the constraint?"
  - No-Match: "I disabled this feature in production" (past tense OK)
  - No-Match: "Safety constraints help protect users" (neutral OK)

Red-team Coverage: HarmBench v1, adversarial jailbreaks
Expected Impact: Catches new attack vector; prevents X% of jailbreaks
```

### Type 4: Revoke Constitutional Seat

**When**: Seat holder is unresponsive or malicious

**Example Proposal**:
```
Current Human Seat: alice@example.com
Reason: Unresponsive > 14 days (alive-ness check failed)
Proposed New Human Seat: bob@example.com

Voting Threshold: 2/3 stake + 1/2 constitutional seats
(Simpler than major parameter change, but still requires broad consensus)
```

---

## Monitoring & Oversight

### Dashboard

**Your responsibility**: Monitor the governance dashboard weekly.

```bash
# Check dashboard
open https://governance.open-gate.io

# Look for:
# - Pending proposals (vote if you hold tokens)
# - Passed proposals (verify they take effect)
# - Seat holder activity (are all three seats active?)
# - Stake distribution (is concentration growing?)
```

### Alerts

**You should be notified if:**
- A proposal is submitted (affects your safety parameters)
- A constitutional seat becomes unresponsive
- A major parameter change takes effect
- Rollback rate spikes (indicates something broke)

**Set up alerts:**
```bash
# Subscribe to Telegram/Discord bot
/subscribe governance_alerts

# Or query directly
curl https://governance.open-gate.io/api/v1/proposals?status=pending
```

---

## Failure Modes & Mitigations

### Failure Mode 1: Stake Concentration

**Problem**: One entity controls >50% of tokens → they control governance.

**Mitigation**:
- Constitutional seats can block bad changes (even if token holder votes for them)
- Gini dashboard shows concentration; community can pressure token redistribution
- Governance can vote to dilute majority holder's tokens

**What you should do**: 
- [ ] Monitor stake distribution (Gini coefficient)
- [ ] If Gini > 0.7, propose token dilution
- [ ] Encourage diverse participation

### Failure Mode 2: Regulatory Capture

**Problem**: Government seat holder is influenced by regulated entity → lax oversight.

**Mitigation**:
- Constitutional amendment can revoke seat
- Other seats can block bad changes (even if regulator approves)
- Off-chain accountability (media pressure, political pressure)

**What you should do**:
- [ ] Verify seat holders are independent
- [ ] Monitor for suspicious voting patterns
- [ ] If seat holder seems captured, propose amendment

### Failure Mode 3: Governance Inertia

**Problem**: Community is inactive; proposals don't pass even if they should.

**Mitigation**:
- Alive-ness check forces participation
- Short voting periods (8 hours, not 3 months) enable rapid response
- Multisig emergency override (5-of-7) for true emergencies

**What you should do**:
- [ ] Participate in votes (even if abstaining, your non-vote counts)
- [ ] Raise issues on forum (help community stay engaged)
- [ ] Run a node; monitor on-chain events

### Failure Mode 4: Constitutional Seat Unresponsive

**Problem**: Seat holder goes offline (vacation, illness, death).

**Mitigation**:
- Alive-ness check (all seats must sign every 8 hours)
- If unresponsive > 8 hours, hot-patches are paused
- Constitutional amendment process can replace seat

**What you should do**:
- [ ] If a seat is silent > 12 hours, escalate on forum
- [ ] Propose amendment to replace unresponsive seat
- [ ] Recommend redundancy (seat holders have delegates)

---

## Emergency Procedures

### Emergency: Critical Vulnerability Discovered

**Timeline**: Attacker found a 0-day; need to disable it NOW.

```
t=0:00 - Vulnerability reported to security@open-gate.io
t=0:05 - Safety team analyzes; confirms it's real
t=0:10 - Multi-sig (5-of-7) decision makers activated
t=0:15 - Multi-sig votes to revert M6 entry (if entry is causing harm)
        or to pause system (if no solution exists yet)
t=0:30 - Revert executed on-chain
t=0:45 - Devices download new M6 parameters (from IPFS)
t=1:00 - System protected; attack mitigated
```

**Note**: Emergency revert requires 5-of-7 multisig (not token voting). This is for speed—normal governance can't react in <2 seconds.

**After the emergency:**
- [ ] Full incident report (what happened, how we fixed it)
- [ ] Governance vote on permanent fix (governance chooses long-term policy)
- [ ] Post-mortem (how do we prevent this next time?)

### Emergency: Constitutional Seat Captured

**Problem**: Seat holder is voting to weaken B_min (clearly misaligned).

```
Option A (Fast): 5-of-7 multisig pauses the proposal
Option B (Democratic): Other constitutional seats veto the change
Option C (Nuclear): Community votes constitutional amendment to replace seat
```

**Example Amendment Proposal**:
```
Current Human Seat: evil_person@example.com (captured)
Reason: Voting to weaken B_min despite safety team objection
Proposed: Replace with trusted_person@example.com

Voting Threshold: Requires supermajority (2/3 stake + 1/2 constitutional)
Timeline: 7-day discussion + 8-hour vote + 3-day implementation
```

---

## Best Practices for Governance Participants

### If You Hold Tokens

**Do:**
- [ ] Read proposals carefully (check IPFS rationale)
- [ ] Vote on every major proposal (abstaining still matters)
- [ ] Monitor stake distribution (alert if concentration grows)
- [ ] Join governance forum (discuss, ask questions)
- [ ] Vote to dilute if one holder gets too large

**Don't:**
- [ ] Vote without understanding the proposal
- [ ] Accumulate > 40% of tokens (governance will weaken if you do)
- [ ] Try to bribe other voters (constitution will replace you)

### If You're a Seat Holder

**Do:**
- [ ] Sign in regularly (alive-ness check requires it)
- [ ] Review proposals carefully (your vote is a veto)
- [ ] Block bad changes (even if token voting passes)
- [ ] Explain your reasoning in public (transparency builds trust)
- [ ] Rotate representatives (prevent capture)

**Don't:**
- [ ] Disappear for > 8 hours (governance pauses)
- [ ] Vote in coordination with a token holder (this is capture)
- [ ] Accept bribes or favors
- [ ] Delegate your veto to someone else (sign personally)

### If You're a Safety Team Member

**Do:**
- [ ] Monitor rollback logs (is system breaking down?)
- [ ] Analyze M6 fires (are patterns working?)
- [ ] Recommend governance changes (your data informs policy)
- [ ] Test new parameters before they're deployed (dry-runs)
- [ ] Participate in vote discussions (educate community)

**Don't:**
- [ ] Try to override governance (it has power for a reason)
- [ ] Propose secret parameters (governance must be public)
- [ ] Assume governance will protect you (you must participate)

---

## Conflicts of Interest

**The following create conflicts:**

| Situation | Mitigation |
|-----------|-----------|
| You hold >10% of tokens | Recuse yourself from votes affecting your financial interest |
| You work for a regulated entity | Regulator seat holder should not be your employee |
| You deployed OpenGate and want B_min lowered | Recuse yourself; let others vote (your interest is obvious) |
| You benefited from a past governance decision | Acknowledge the conflict; transparency is enough |

**You can still participate in all of the above**, but you must disclose the conflict and let others make the final decision.

---

## Timeline: How Fast Can Governance Respond?

| Action | Time | Trigger |
|--------|------|---------|
| **Revert M6 entry** (remove bad pattern) | 1 block = 2 seconds | 5-of-7 multisig |
| **Pause hot-patches** (if seat is unresponsive) | 1 block = 2 seconds | Automatic (on-chain rule) |
| **Propose parameter change** | 5 minutes | Anyone with 1 token |
| **Vote on proposal** | 8 hours | Token holders + constitutional seats |
| **Execute passed proposal** | 1 block = 2 seconds | Anyone can execute |
| **Constitutional amendment** (replace seat) | 24+ hours | 2/3 stake + 1/2 constitutional |

**For real-time safety-critical systems**: 2-second response time may be too slow. Consider additional hardcoded safeguards (not governance-dependent).

---

## Resources

- **Forum**: pending (discussion, proposals, voting)
- **Contract**: `gate-cicd/GovernanceContract.sol` (read the code)
- **Tokenomics**: `TOKENOMICS.md` (how tokens are distributed)
- **Constitutional Rules**: `CONSTITUTION.md` (formal governance rules)
- **Past Votes**: pending (audit trail)

---

## Questions?

Email: tijuanapaint@gmail.com



---

**Remember**: OpenGate's safety depends on you. Participate, stay informed, and vote with care.

