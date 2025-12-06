# Rollback Policy

## Trigger Conditions

- Λ-entropy exceeds certified budget
- Side-channel leakage > ε (50k pJ)
- Invalid certificate signature
- Hardware fault detection

## Procedure

### Immediate (within 12 clock cycles):
- Gate output forced to 0
- Current state saved to backup registers
- Interrupt raised to host CPU

### Recovery (< 2 ms):
- Load last valid state from backup
- Re-validate all pending certificates
- Resume from safe checkpoint

### Audit:
- Log violation type and timestamp
- Report to governance contract
- Require manual override for continued operation

## Safety Guarantees

- No data corruption during rollback
- Atomic state transition
- Cryptographic proof of violation
- No silent failures
