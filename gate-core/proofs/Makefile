# Coq proofs extraction to C

COQC = coqc
COQDEP = coqdep
EXTRACT = coqtop -batch -load-vernac-source

all: gate_entropy.vo extract

gate_entropy.vo: gate_entropy.v
	$(COQC) gate_entropy.v

extract: gate_entropy.vo
	$(EXTRACT) gate_entropy.v
	cp gate_entropy_extracted.h ../fw/lambda_proof.h

clean:
	rm -f *.vo *.glob .hi gate_entropy_extracted.h

.PHONY: all extract clean
