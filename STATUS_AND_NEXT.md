# CopyTrade EA — Status & What To Do Now

## ✅ Done (all must-have requirements)

| Requirement | Status |
|-------------|--------|
| ① No duplicate on receiver (1 entry → 1 position) | Done — check before OPEN + consume orphan CLOSE |
| ② Invert trade (BUY↔SELL) | Done — Receiver inverts direction |
| ③ Multiple senders → one receiver | Done — event/map keyed by senderLogin |
| ④ Lot multiplier on receiver | Done — input LotMultiplier |
| Symbol delimiter (cross-broker suffix) | Done — Sender param, base symbol in events |
| Symbol mapping (e.g. GOLD=XAUUSD) | Done — Sender or Receiver, one side only |
| Receiver comment (which sender entry) | Done — `SRC:login\|T:ticket` |
| README (parameters, usage) | Done — README.md |

---

## What you should do now

### 1. Test the full flow (recommended)

- **Compile:** Build both EAs in MetaEditor (Experts + Include in place).
- **Sender:** One MT4 (or demo) with CopyTrade_Sender on a chart (e.g. XAUUSD). Set SymbolDelimiter if your symbol has a suffix; set SymbolMapping only if you need cross-broker mapping.
- **Receiver:** Another MT4 with CopyTrade_Receiver on a chart. Same QueueFolder and ReceiverMagic; set SymbolMapping only if needed (and only on one side).
- **Check:** Open a trade on Sender → Receiver opens the opposite direction. Close on Sender → Receiver closes. Run twice or replay same event → no duplicate open. Logs show OPEN/CLOSE and any errors.

### 2. Deploy for real use

- Put both terminals on the **same Common path** (same PC, or shared drive so both see the same `ct_queue`, `ct_ledger`, `ct_map`).
- Match **QueueFolder** and **ReceiverMagic** on Sender and Receiver.
- Use **SymbolMapping on one side only** (see README).

### 3. Optional later (not in current scope)

From the original task, these were “optional / separate estimate”:

- Sender: auto-close at specified profit amount  
- Sender: no multiple entries (e.g. one position per symbol)  
- Sender: limit number of entries  
- Sender: alert when EA is stopped  
- Receiver: alert when sender EA is stopped  
- Short note on VPS vs internet entry speed (document only)

You can add these in a second phase if needed.

---

## Summary

**Nothing mandatory is missing.** Next steps: test (gold, invert, no duplicates, delimiter/mapping if you use them), then deploy. Add optional features later if you want them.
