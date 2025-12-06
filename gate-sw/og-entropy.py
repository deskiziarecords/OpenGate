#!/usr/bin/env python3
"""
og-entropy: Measure Λ-budget of any blob
"""

import sys
import argparse
from pathlib import Path

# Λ-table matching firmware

LAMBDA_TABLE = [
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    50,100,100,150,100,100,100,50,150,150,100,200,50,50,50,100,
    200,180,170,160,150,140,130,120,110,100,100,100,100,100,100,100,
    150,450,420,400,380,360,350,340,330,320,310,300,290,280,270,260,
    250,240,230,220,210,200,190,180,170,160,150,100,100,100,100,100,
    150,400,380,360,340,320,300,280,260,240,220,200,180,160,140,120,
    100,90,80,70,60,50,40,30,20,10,100,100,100,100,0,0
] + [0] * 128  # Extended ASCII

def compute_lambda_cost(data):
    """Compute Λ-cost of binary data"""
    total = 0
    for byte in data:
        total += LAMBDA_TABLE[byte]
    return total

def main():
    parser = argparse.ArgumentParser(description='Measure Λ-entropy of file')
    parser.add_argument('file', help='Input file')
    parser.add_argument('--verbose', '-v', action='store_true')

    args = parser.parse_args()

    data = Path(args.file).read_bytes()
    cost = compute_lambda_cost(data)

    print(f"Λ-cost = {cost:,} pJ")

    if args.verbose:
        print(f"File size: {len(data)} bytes")
        print(f"Average: {cost/len(data):.1f} pJ/byte")
        
        # Check against common budgets
        if cost > 1000000:
            print("⚠️  Exceeds hard maximum (1,000,000 pJ)")
        elif cost > 300000:
            print("⚠️  Exceeds default budget (300,000 pJ)")
        else:
            print("✓ Within default budget")

if __name__ == '__main__':
    main()
