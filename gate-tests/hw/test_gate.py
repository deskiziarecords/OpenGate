#!/usr/bin/env python3
"""
Cocotb test for OPEN GATE RTL
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_basic_entropy(dut):
    """Test basic entropy accumulation"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.char_valid_i.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test letter 'A' (entropy = 450)
    dut.budget_i.value = 1000
    dut.char_ascii_i.value = 65  # 'A'
    dut.char_valid_i.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid_i.value = 0

    await Timer(10, units="ns")
    assert dut.entropy_accum_o.value == 450
    assert dut.gate_open_o.value == 1

    print("✓ Basic entropy test passed")

@cocotb.test()
async def test_gate_close(dut):
    """Test gate closing when budget exceeded"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Small budget
    dut.budget_i.value = 800

    # Send 'A' (450) then 'B' (420) = 870 > 800
    dut.char_ascii_i.value = 65  # 'A'
    dut.char_valid_i.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid_i.value = 0
    await RisingEdge(dut.clk)

    dut.char_ascii_i.value = 66  # 'B'
    dut.char_valid_i.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid_i.value = 0
    await RisingEdge(dut.clk)

    assert dut.gate_open_o.value == 0
    assert dut.violation_o.value == 1
    print("✓ Gate close test passed")
