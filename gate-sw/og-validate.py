#!/usr/bin/env python3
"""
og-validate: Offline certificate validator
"""

import struct
import hashlib
import sys
from pathlib import Path

def validate_certificate(patch_file, cert_file):
    """Validate certificate against patch"""

    # Read files
    patch_data = Path(patch_file).read_bytes()
    cert_data = Path(cert_file).read_bytes()

    if len(cert_data) != 512:
        print(f"ERROR: Certificate must be 512 bytes (got {len(cert_data)})")
        return False

    # Parse certificate
    magic = cert_data[0:4]
    if magic != b'OGT1':
        print(f"ERROR: Invalid magic: {magic.hex()}")
        return False

    budget = struct.unpack('<I', cert_data[4:8])[0]
    hard_max = struct.unpack('<I', cert_data[8:12])[0]
    epsilon = struct.unpack('<I', cert_data[12:16])[0]
    patch_hash = cert_data[48:80]

    # Check patch hash
    computed_hash = hashlib.sha256(patch_data).digest()
    if patch_hash != computed_hash:
        print("ERROR: Patch hash mismatch")
        return False

    # Compute Λ-cost
    from og_entropy import compute_lambda_cost
    cost = compute_lambda_cost(patch_data)

    # Validate bounds
    if budget > hard_max:
        print(f"ERROR: Budget {budget} > hard max {hard_max}")
        return False

    if epsilon > 50000:
        print(f"ERROR: Epsilon {epsilon} > max 50000")
        return False

    if cost > budget:
        print(f"ERROR: Λ-cost {cost} > budget {budget}")
        return False

    print("✓ Certificate valid")
    print(f"  Budget: {budget:,} pJ")
    print(f"  Λ-cost: {cost:,} pJ")
    print(f"  Margin: {budget - cost:,} pJ")
    print(f"  Epsilon: {epsilon:,} pJ")

    return True

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Validate OPEN GATE certificate')
    parser.add_argument('--patch', required=True, help='Model patch file')
    parser.add_argument('--cert', required=True, help='Certificate file')

    args = parser.parse_args()

    if validate_certificate(args.patch, args.cert):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
