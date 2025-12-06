FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    iverilog \
    gtkwave \
    python3 \
    python3-pip \
    python3-cocotb \
    coq \
    coq-theories \
    rustc \
    cargo \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /open-gate

# Copy source
COPY . .

# Build everything
RUN make -C gate-core/proofs
RUN cd gate-sw && cargo build --release
RUN pip3 install ./gate-libs/python

CMD ["/bin/bash"]
