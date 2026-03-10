# CopyTrade EA — Task Analysis & Gap List

## 1. Task requirements (summary)

| # | Requirement | Priority |
|---|-------------|----------|
| ① | **No duplicate trades on receiver** — 1 sender entry must never become 2+ receiver entries. Strengthen control/monitoring. | Must |
| ② | **Invert trade** — Sender BUY → Receiver SELL; Sender SELL → Receiver BUY. | Must |
| ③ | **Multiple senders, one receiver** — Many sender accounts → one receiver account. | Must |
| ④ | **Lot multiplier on receiver** — Receiver can change lot size vs sender. | Must |
| - | Sync only **new** and **close**; no need to sync SL/TP or partial close. | OK as-is |
| - | **Symbol delimiter** — Param for symbol+suffix (e.g. `XAUUSD-cd` → delimiter `-`). Sender/Receiver each have param. | Must (spec note) |
| - | **Symbol mapping** — Cross-broker symbol (e.g. `GOLD=XAUUSD`). Set on **one side only**. | Must (spec note) |
| - | Receiver comment shows which sender entry (e.g. `SRC:login|T:ticket`). | Must |

**Optional (separate estimate):**

- Sender: auto-close at specified profit
- Sender: no multiple entries (no averaging)
- Sender: limit entry count
- Sender: alert when EA stopped
- Receiver: alert when sender EA stopped
- Receiver: comment in terminal for sender entry (already done)

**Scope for current delivery:** Gold only, invert only is acceptable. Per-symbol / per-sender options can be later.

---

## 2. What is already implemented

| Item | Status |
|------|--------|
| Sender: scan open trades, write OPEN event to queue | ✅ |
| Sender: detect closed trades, write CLOSE event | ✅ |
| Receiver: read queue, execute OPEN/CLOSE | ✅ |
| Ledger (eventId) to avoid reprocessing same event | ✅ |
| Map (senderLogin, senderTicket) → receiverTicket for CLOSE | ✅ |
| Fallback: find receiver order by comment if map missing | ✅ |
| Orphan CLOSE consumed (no infinite retry) | ✅ |
| Multiple senders (event has senderLogin/senderServer; map keyed by them) | ✅ |
| Lot multiplier on receiver | ✅ |
| Receiver comment `SRC:login|T:ticket` | ✅ |
| Filter sender’s own copied trades (magic + "SRC:" comment) | ✅ |

---

## 3. What is missing (must-do)

### ① Invert trade (critical)

- **Current:** Receiver uses same direction as sender (`ev.cmd` → OP_BUY/OP_SELL).
- **Required:** Sender BUY → Receiver SELL; Sender SELL → Receiver BUY.
- **Where:** Receiver `ExecuteOpen()`: invert `ev.cmd` before `OrderSend` (e.g. OP_BUY→OP_SELL, OP_SELL→OP_BUY). CLOSE side already closes by ticket, so no change.

### ② No duplicate on receiver (strengthen)

- **Current:** Ledger prevents same **event file** from being applied twice. If sender (or file duplication) creates two OPEN events for the same (senderLogin, senderTicket), receiver could open twice.
- **Required:** One logical sender entry → at most one receiver position. Before executing OPEN, check: “Do we already have an open position for this (senderLogin, senderTicket)?” (map or comment). If yes → do **not** open again; mark event as done (ledger + delete file) and return.

### ③ Symbol delimiter (spec note)

- **Sender:** Input `SymbolDelimiter` (e.g. `-`, `.`, or empty). When building event, normalize symbol: if delimiter set, strip suffix (e.g. `XAUUSD-cd` → `XAUUSD`). Write normalized symbol in event.
- **Receiver:** Input `SymbolDelimiter`. If receiver’s chart symbol has suffix, build symbol as `base + delimiter + suffix` when sending order; if no suffix, use symbol from event as-is. (Often receiver has no suffix → use event symbol as-is.)

### ④ Symbol mapping (spec note)

- **Format:** `GOLD=XAUUSD` or `XAUUSD=GOLD`; comma for multiple: `GOLD=XAUUSD,SILVER=XAGUSD`.
- **Rule:** Set on **one side only** (sender **or** receiver), not both.
- **Sender:** Before writing event, if mapping exists and local symbol (after delimiter strip) equals left side, write right side in event; else write stripped symbol.
- **Receiver:** After reading event, if mapping exists and received symbol equals left side, use right side for `OrderSend`; else use received symbol.

### ⑤ Receiver comment (enhance optional)

- **Current:** `SRC:login|T:senderTicket`.
- **Spec:** “ターミナルで、どの発信側のエントリーか、コメントに表記” — already satisfied. Optionally add sender server or symbol if needed later.

---

## 4. Optional features (not in current scope)

- Sender: auto-close at specified profit amount  
- Sender: no multiple entries (e.g. one position per symbol)  
- Sender: max entry count  
- Sender: alert when EA is stopped  
- Receiver: alert when sender EA is stopped  
- VPS vs internet latency note (document only)

These can be estimated and implemented separately.

---

## 5. Recommended order of work

1. **Invert trade** — Change receiver OPEN to use opposite direction. Quick, high impact.
2. **Duplicate prevention** — Before OPEN, check existing open position for (senderLogin, senderTicket); if exists, treat as already done (ledger + delete file, no new order).
3. **Symbol delimiter** — Add params and normalize symbol on Sender; optionally build symbol on Receiver if suffix used.
4. **Symbol mapping** — Add param and parsing; apply on Sender or Receiver (one side only), document which side to use.
5. **Testing** — Gold, invert, multiple senders, one receiver; verify no duplicates and correct symbol/delimiter/mapping.

---

## 6. Duplicate-prevention detail (for ①)

- **On OPEN:**  
  - Check ledger by `eventId` (already done).  
  - **New:** Before `OrderSend`, check if there is already an **open** order with same (senderLogin, senderTicket): e.g. `CT_MapFind` and then check that the found receiver ticket is still open; or search open orders by comment `SRC:senderLogin|T:senderTicket`. If such order exists → do not open again; `CT_LedgerAppendDone(ev.eventId, existingTicket)` (or 0), delete event file, return.  
- **On CLOSE:** Already safe: one event file per close; ledger prevents reprocessing; map/comment used to find the single receiver order to close.

---

## 7. Symbol delimiter / mapping (implementation notes)

- **Delimiter:**  
  - Sender: `SymbolDelimiter` (string, 1 char or empty).  
  - `GetBaseSymbol(symbol, delimiter)` → if delimiter empty return symbol; else find delimiter in symbol, return substring before it (e.g. `XAUUSD-cd` + `-` → `XAUUSD`).  
  - Use base symbol when building event and when applying mapping.  
- **Mapping:**  
  - Parse `SymbolMapping` (e.g. `"GOLD=XAUUSD,SILVER=XAGUSD"`) into key→value.  
  - Sender: `outSymbol = map.Get(senderBaseSymbol) or senderBaseSymbol`.  
  - Receiver: `outSymbol = map.Get(ev.symbol) or ev.symbol`.  
  - Document: “Set mapping on sender **or** receiver only.”

---

## 8. Summary checklist

| Action | Owner | Done |
|--------|--------|------|
| Implement invert (BUY↔SELL) on receiver OPEN | Dev | ☑ |
| Before OPEN, check existing position for (senderLogin, senderTicket); if exists, skip open and consume event | Dev | ☑ |
| Add SymbolDelimiter param (Sender + Receiver); normalize symbol on send; use on receive if needed | Dev | ☐ |
| Add SymbolMapping param; apply on one side only; document | Dev | ☐ |
| Test: gold, invert, no duplicates, delimiter, mapping | Dev | ☐ |
| Optional: alerts, auto-close, no martingale, entry limit (separate estimate) | Later | ☐ |
