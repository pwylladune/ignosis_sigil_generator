------------------------------ MODULE RiteBurn ------------------------------
(* One rite, retried: backend/src/services/riteBurn.ts, RiteBurnService.fulfil.

   A burn is signed (a signature with a last valid block height), recorded,
   then sent. A signed burn can land only while the chain's height is at most
   its last valid height. A retry reads the chain and either finishes, resends
   the same burn, or builds a new one. The property: at most one burn lands.

   Fixed = FALSE is the code before 2026-11-09: the retry reads the status,
   then the height, and rebuilds a row marked failed without waiting for the
   old burn to expire. Fixed = TRUE reads the height first and rebuilds only
   when that height is past the old burn's last valid height.

   The chain may reject a resend although the burn landed or still can
   ("already processed", or a node that has not seen the blockhash): Reject.

   Run (TLC, tla2tools.jar; -deadlock because the bounded chain just stops):
     java -cp tla2tools.jar tlc2.TLC -deadlock -config RiteBurnAfter.cfg RiteBurn.tla
       -> no error
     java -cp tla2tools.jar tlc2.TLC -deadlock -config RiteBurnBefore.cfg RiteBurn.tla
       -> AtMostOneBurn violated; the traces are tests in src/test-burn-race.ts *)
EXTENDS Naturals, FiniteSets

CONSTANTS Fixed, MaxHeight, MaxSigs, Life

VARIABLES height,   \* the chain's block height
          expiry,   \* signature -> last valid block height
          sent,     \* signatures broadcast at least once
          landed,   \* signatures whose burn took effect
          row,      \* the ledger row: [sig, state]
          pc, seenStatus, seenHeight   \* one retry in progress

vars == <<height, expiry, sent, landed, row, pc, seenStatus, seenHeight>>

Sigs == 1..MaxSigs

Init == /\ height = 0
        /\ expiry = [s \in Sigs |-> IF s = 1 THEN Life ELSE 0]
        /\ sent = {1}
        /\ landed = {}
        /\ row = [sig |-> 1, state |-> "pending"]
        /\ pc = "idle"
        /\ seenStatus = "unknown"
        /\ seenHeight = 0

\* The chain.
Tick == /\ height < MaxHeight
        /\ height' = height + 1
        /\ UNCHANGED <<expiry, sent, landed, row, pc, seenStatus, seenHeight>>

Land(s) == /\ s \in sent
           /\ s \notin landed
           /\ height <= expiry[s]
           /\ landed' = landed \cup {s}
           /\ UNCHANGED <<height, expiry, sent, row, pc, seenStatus, seenHeight>>

\* A send is refused at preflight: the row is marked failed, rightly or not.
Reject == /\ row.state = "pending"
          /\ row' = [row EXCEPT !.state = "failed"]
          /\ UNCHANGED <<height, expiry, sent, landed, pc, seenStatus, seenHeight>>

StatusOf(s) == IF s \in landed THEN "confirmed" ELSE "unknown"

\* The retry. Its two reads are separate steps: the chain moves in between.
Start == /\ pc = "idle"
         /\ row.state # "done"
         /\ pc' = IF Fixed THEN "readHeight" ELSE "readStatus"
         /\ UNCHANGED <<height, expiry, sent, landed, row, seenStatus, seenHeight>>

ReadStatus == /\ pc = "readStatus"
              /\ seenStatus' = StatusOf(row.sig)
              /\ pc' = IF Fixed THEN "decide" ELSE "readHeight"
              /\ UNCHANGED <<height, expiry, sent, landed, row, seenHeight>>

ReadHeight == /\ pc = "readHeight"
              /\ seenHeight' = height
              /\ pc' = IF Fixed THEN "readStatus" ELSE "decide"
              /\ UNCHANGED <<height, expiry, sent, landed, row, seenStatus>>

CanStillLand == seenHeight <= expiry[row.sig]

Resend == IF Fixed THEN CanStillLand
                   ELSE row.state = "pending" /\ CanStillLand

Decide ==
  /\ pc = "decide"
  /\ pc' = "idle"
  /\ IF seenStatus = "confirmed"
       THEN /\ row' = [row EXCEPT !.state = "done"]
            /\ UNCHANGED <<expiry, sent>>
     ELSE IF Resend
       THEN /\ row' = [row EXCEPT !.state = "pending"]
            /\ UNCHANGED <<expiry, sent>>
     ELSE IF row.sig < MaxSigs
       THEN LET n == row.sig + 1 IN
            /\ expiry' = [expiry EXCEPT ![n] = height + Life]
            /\ sent' = sent \cup {n}
            /\ row' = [sig |-> n, state |-> "pending"]
     ELSE UNCHANGED <<expiry, sent, row>>
  /\ UNCHANGED <<height, landed, seenStatus, seenHeight>>

Next == Tick \/ (\E s \in Sigs : Land(s)) \/ Reject
        \/ Start \/ ReadStatus \/ ReadHeight \/ Decide

Spec == Init /\ [][Next]_vars

AtMostOneBurn == Cardinality(landed) <= 1
=============================================================================
