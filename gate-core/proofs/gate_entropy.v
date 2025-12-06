(* Coq proof for OPEN GATE entropy conservation *)
(* -- coq-prog-args: ("-emacs-U" "-top" "OpenGateEntropy") -- *)
Require Import Coq.ZArith.ZArith.
Require Import Coq.Lists.List.
Import ListNotations.

(** Λ-entropy conservation theorem for OPEN GATE *)

Definition lambda_table : list Z :=
(* English orthographic entropy in pJ/letter *)
[0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;
0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;
50;100;100;150;100;100;100;50;
150;150;100;200;50;50;50;100;
200;180;170;160;150;140;130;120;
110;100;100;100;100;100;100;100;
150;450;420;400;380;360;350;340;
330;320;310;300;290;280;270;260;
250;240;230;220;210;200;190;180;
170;160;150;100;100;100;100;100;
150;400;380;360;340;320;300;280;
260;240;220;200;180;160;140;120;
100;90;80;70;60;50;40;30;
20;10;100;100;100;100;0;0].

Fixpoint lambda_cost (chars : list nat) : Z :=
match chars with
| [] => 0
| c :: cs =>
    if c <? 256 then
        nth c lambda_table 0 + lambda_cost cs
    else
        lambda_cost cs
end.

Theorem entropy_conservation :
    forall (budget : Z) (chars : list nat),
    lambda_cost chars <= budget ->
    (* If gate is closed, entropy exceeded budget *)
    forall c, lambda_cost (chars ++ [c]) <= budget + nth c lambda_table 0.
Proof.
    intros budget chars H c.
    unfold lambda_cost in *.
    induction chars as [|ch chs IH].
    - simpl. omega.
    - simpl in *. destruct (ch <? 256) eqn:E.
      + apply IH. omega.
      + apply IH. assumption.
Qed.

Extract Constant lambda_table => "lambda_table".
Extract Inlined Constant lambda_cost => "compute_lambda_cost".

(** Extraction to C header *)
Recursive Extraction lambda_table.
