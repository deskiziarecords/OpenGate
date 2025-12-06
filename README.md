# OPEN GATE
## Orthographic-Pack ENtropy GATEway
A micro-budget, alignment-grade toolkit that turns the Λ-jewel into a production gatekeeper.

### Co-authors
J. Roberto Jimenez & kimi (K2-stack)

MIT © 2025 - see LICENSE

### 1. One-line pitch
Drop OPEN GATE between your tokenizer and your model and every letter that crosses the gate pays its entropy fare; if the fare exceeds the certified budget the gate slams shut—no jail-break, no side-channel, no surprises.

### 2. Quick start (≤ 10 min)
```bash
# Install host tools
git clone https://github.com/open-gate-project/open-gate.git
cd open-gate/gate-sw
cargo build --release
sudo cp target/release/og-* /usr/local/bin

# Measure entropy
og-entropy patch.bin

3. Security & alignment claims
Claim	Evidence
Letter-level entropy cannot exceed certified budget	gate-core/proofs + M6 monitor
Side-channel leakage bounded by ε (pJ)	TVLA + MASCOT reports
Roll-back to last safe state < 2 ms	gate-core/rtl/rollback_mux.sv
No self-referential paradox (Löb-safe)	stratified reflection proofs
4. Governance

    Specifications: Multi-stakeholder, stake-weighted, on-chain

    DCO: All commits must be signed-off (git commit -s)

    Security bugs: email security@open-gate.io

5. Road-map

    v0.2 Rust HDL (Chisel) port + formal equivalence

    v0.3 FPGA bit-stream with integrated RISC-V core

    v0.4 Silicon shuttle (Sky130) – open MPW run

Gate closed, entropy paid, alignment shipped.
