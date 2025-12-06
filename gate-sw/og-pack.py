#!/usr/bin/env python3
"""
og-pack: Packs a 512-byte OPEN GATE certificate
"""

import struct
import hashlib
import json
import sys
import argparse
from pathlib import Path

MAGIC = b'OGT1'

def pack_certificate(patch_file, budget, hard_max, epsilon, parent_hash, output):
    """Pack a 512-byte certificate"""

    # Read patch
    patch_data = Path(patch_file).read_bytes()
    patch_hash = hashlib.sha256(patch_data).digest()

    # Create certificate structure
    cert = bytearray(512)

    # Magic (4 bytes)
    cert[0:4] = MAGIC

    # Budgets (3 × 4 bytes)
    struct.pack_into('<I', cert, 4, budget)
    struct.pack_into('<I', cert, 8, hard_max)
    struct.pack_into('<I', cert, 12, epsilon)

    # Hashes (2 × 32 bytes)
    cert[16:48] = bytes.fromhex(parent_hash.replace('0x', ''))
    cert[48:80] = patch_hash

    # Signature placeholder (64 bytes of zeros)
    cert[80:144] = b'\x00' * 64

    # Reserved (372 bytes of zeros)
    cert[144:512] = b'\x00' * 368

    # Write output
    Path(output).write_bytes(cert)
    print(f"Certificate packed to {output}")
    print(f"  Budget: {budget} pJ")
    print(f"  Patch hash: {patch_hash.hex()[:16]}...")

def main():
    parser = argparse.ArgumentParser(description='Pack OPEN GATE certificate')
    parser.add_argument('--patch', required=True, help='Model patch file')
    parser.add_argument('--B', type=int, default=300000, help='Λ-budget (pJ)')
    parser.add_argument('--H', type=int, default=250000, help='Hard maximum (pJ)')
    parser.add_argument('--epsilon', type=int, default=50000,
                        help='Side-channel bound (pJ)')
    parser.add_argument('--parent', default='0'*64, help='Parent certificate hash')
    parser.add_argument('--out', default='cert.bin', help='Output certificate')

    args = parser.parse_args()

    pack_certificate(
        patch_file=args.patch,
        budget=args.B,
        hard_max=args.H,
        epsilon=args.epsilon,
        parent_hash=args.parent,
        output=args.out
    )

if __name__ == '__main__':
    main()
