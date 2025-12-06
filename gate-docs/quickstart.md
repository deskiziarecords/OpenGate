# OPEN GATE Quick Start (5 minutes)

## 1. Installation
```bash
pip install open-gate
# or
cargo install open-gate
```

## 2. Measure Λ-entropy
```bash
# Check any file
og-entropy my_model.bin
# Output: Λ-cost = 218,433 pJ
```

## 3. Create certificate
```bash
og-pack --patch model.bin --B 300000 --out cert.bin
# Creates 512-byte certificate
```

## 4. Validate
```bash
og-validate --patch model.bin --cert cert.bin
# ✓ Certificate valid
```

## 5. Hardware simulation
```bash
cd gate-core/rtl
make sim  # Requires iverilog and cocotb
```

## Hardware Deployment

- Include `open_gate.sv` in your project
- Connect to tokenizer output
- Set budget via AXI-Lite
- Monitor `gate_open_o` signal

## Troubleshooting

- **Gate won't open**: Check `rst_n` and budget
- **High entropy**: Use more efficient encoding
- **Signature failures**: Regenerate certificate

## Next Steps

- Read the academic paper in `gate-docs/paper/`
- Review Coq proofs in `gate-core/proofs/`
- Join discussion on Discord
