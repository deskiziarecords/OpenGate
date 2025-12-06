# OPEN GATE - Quick Reference

## File Locations

| Function | Location |
|----------|----------|
| Hardware gate module | `gate-core/rtl/open_gate.sv` |
| Hardware testbench | `gate-core/rtl/tb_open_gate.sv` |
| C firmware header | `gate-core/fw/gate.h` |
| C firmware impl | `gate-core/fw/gate.c` |
| Formal proofs | `gate-core/proofs/gate_entropy.v` |
| Entropy calculator | `gate-sw/og-entropy.py` |
| Cert packer | `gate-sw/og-pack.py` |
| Cert validator | `gate-sw/og-validate.py` |
| Python lib | `gate-libs/python/setup.py` |
| Rust lib | `gate-libs/rust/Cargo.toml` |
| C header lib | `gate-libs/c/open_gate.h` |
| Hardware tests | `gate-tests/hw/test_gate.py` |
| CI/CD config | `gate-cicd/github-workflows/ci.yml` |
| Docker image | `gate-cicd/Dockerfile` |

## Commands

```bash
# Initialize repository
cd open-gate
git init
git add .
git commit -m "Initial commit"

# Measure entropy
python gate-sw/og-entropy.py --verbose myfile.bin

# Create certificate
python gate-sw/og-pack.py --patch model.bin --B 300000 --out cert.bin

# Validate certificate
python gate-sw/og-validate.py --patch model.bin --cert cert.bin

# Run hardware simulation
cd gate-core/rtl
make sim

# View waveform
make wave

# Build Rust release
cd gate-libs/rust
cargo build --release

# Run tests
python -m pytest gate-tests/fw/ -v
```

## Key Constants

| Constant | Value | Unit | Purpose |
|----------|-------|------|---------|
| BUDGET_DEFAULT | 300,000 | pJ | Default entropy budget |
| BUDGET_HARD_MAX | 1,000,000 | pJ | Absolute maximum |
| EPSILON_MAX | 50,000 | pJ | Side-channel bound |
| CERT_SIZE | 512 | bytes | Certificate exact size |
| WCET | 150 | µs | Firmware max time |

## Λ-Table Sample

| Character | Entropy | Type |
|-----------|---------|------|
| Space | 50 pJ | Punctuation |
| 'A' | 450 pJ | Uppercase letter |
| 'a' | 400 pJ | Lowercase letter |
| '0' | 200 pJ | Digit |
| ',' | 50 pJ | Punctuation |

## Certificate Structure (512 bytes)

```
Offset  Size  Field
0       4     Magic (0x4F475431 = "OGT1")
4       4     Budget (pJ)
8       4     Hard Max (pJ)
12      4     Epsilon (pJ)
16      32    Parent Hash (SHA-256)
48      32    Patch Hash (SHA-256)
80      64    Signature (Ed25519)
144     368   Reserved (zeros)
512     -     END
```

## GitHub Workflow

1. **Fork** the repository
2. **Clone** your fork
3. **Create** a feature branch
4. **Commit** with `-s` flag (DCO)
5. **Push** to your fork
6. **Open** a Pull Request

## Security Checklist

- [ ] All commits signed with `-s`
- [ ] Certificate validated before use
- [ ] Entropy budget respected
- [ ] Rollback policy understood
- [ ] Coq proofs reviewed

## File Extensions Reference

| Extension | Tool | Purpose |
|-----------|------|---------|
| `.sv` | iverilog | SystemVerilog hardware |
| `.c` / `.h` | gcc | C firmware |
| `.v` | coqc | Coq proofs |
| `.py` | python3 | Software tools |
| `.rs` | rustc | Rust library |
| `.toml` | cargo | Rust config |
| `.ld` | gcc | Linker script |
| `.yml` | github | CI/CD config |

## Useful Links (in repo)

- Overview: `README.md`
- Getting Started: `GETTING_STARTED.md`
- Quick Start: `gate-docs/quickstart.md`
- Contributing: `CONTRIBUTING.md`
- Code of Conduct: `CODE_OF_CONDUCT.md`
- Rollback Policy: `gate-policies/rollback-policy.md`

---

**Ready to go!** Start with: `cat README.md`
