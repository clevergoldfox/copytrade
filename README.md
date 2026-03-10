# CopyTrade EA (MT4)

MT4 Expert Advisors that copy trades from one account (Sender) to another (Receiver) using a **file-based queue**. No network or broker API between terminals—both must see the same **Common** data folder (same PC or shared drive).

- **Invert:** Sender BUY → Receiver SELL; Sender SELL → Receiver BUY.
- **One receiver** can follow **multiple sender** accounts.
- **No duplicate:** One sender entry produces at most one receiver position.

---

## Structure

```
copytrade/
├── Experts/
│   ├── CopyTrade_Sender.mq4   ← Attach to chart on SOURCE account
│   └── CopyTrade_Receiver.mq4  ← Attach to chart on FOLLOWING account
├── Include/
│   ├── CT_Event.mqh
│   ├── CT_Ledger.mqh
│   ├── CT_Map.mqh
│   └── CT_Symbol.mqh
└── README.md
```

Copy `Experts/*.mq4` and `Include/*.mqh` into your MT4 `MQL4` directory so the includes resolve.

---

## Sender (CopyTrade_Sender)

Runs on the **source** account. Scans open/closed positions and writes OPEN/CLOSE events into the queue folder. Ignores orders opened by the Receiver (magic and comment `SRC:`).

| Parameter | Description |
|-----------|-------------|
| **ScanIntervalSeconds** | How often to scan (default 1). |
| **ReceiverMagic** | Must match Receiver’s magic so Sender ignores copied trades (default 900001). |
| **QueueFolder** | Folder name under Common path for event files (default `ct_queue`). |
| **SymbolDelimiter** | If the chart symbol has a suffix (e.g. `XAUUSD-cd`), set the delimiter (e.g. `-`). Base symbol is sent in events. No suffix → leave empty. |
| **SymbolMapping** | Cross-broker symbol, e.g. `GOLD=XAUUSD`. Comma for multiple: `GOLD=XAUUSD,SILVER=XAGUSD`. **Set on Sender OR Receiver, not both.** |

---

## Receiver (CopyTrade_Receiver)

Runs on the **following** account. Reads event files from the queue and opens/closes trades. Uses a ledger and map so each event is applied once and CLOSE finds the correct position.

| Parameter | Description |
|-----------|-------------|
| **TimerSeconds** | How often to check the queue (default 1). |
| **Slippage** | Max slippage for OrderSend/OrderClose (default 10). |
| **ReceiverMagic** | Magic number for copied orders (default 900001). Must match Sender’s setting. |
| **LotMultiplier** | Receiver lots = Sender lots × this (default 1.0). |
| **QueueFolder** | Same folder name as Sender (default `ct_queue`). |
| **SymbolMapping** | Map symbol from event to receiver symbol, e.g. `XAUUSD=GOLD`. Comma for multiple. **Set on Sender OR Receiver, not both.** |

Receiver order comment: `SRC:<senderLogin>|T:<senderTicket>` so you can see which sender entry it is.

---

## Symbol delimiter and mapping

### Delimiter (Sender)

Brokers may use symbols like `XAUUSD-cd` or `USDJPY.oj5k` (base + delimiter + suffix). Set **SymbolDelimiter** so the EA sends the **base** symbol in events:

- `XAUUSD-cd` → set delimiter `-` → event symbol `XAUUSD`
- `USDJPY.oj5k` → set delimiter `.` → event symbol `USDJPY`
- `XAUUSD` (no suffix) → leave SymbolDelimiter **empty**

### Mapping (one side only)

Use **SymbolMapping** on **either** Sender **or** Receiver, not both.

- **Sender:** “My symbol” → “symbol to put in event”  
  Example: Sender chart `GOLD`, receiver broker uses `XAUUSD` → set **Sender** SymbolMapping `GOLD=XAUUSD`.
- **Receiver:** “Symbol in event” → “My symbol”  
  Example: Event has `XAUUSD`, receiver chart is `GOLD` → set **Receiver** SymbolMapping `XAUUSD=GOLD`.

Format: `KEY=VALUE`; multiple: `GOLD=XAUUSD,SILVER=XAGUSD`.

If the receiver broker uses a suffixed symbol (e.g. `XAUUSD.oj5k`), set on Receiver: `XAUUSD=XAUUSD.oj5k`.

---

## Requirements

- Both terminals must use the **same Common path** for the queue (and for ledger/map). Same PC or a shared drive is typical.
- Sender and Receiver use the same **QueueFolder** and **ReceiverMagic**.
- For cross-broker copy, set **SymbolMapping** on one side and optionally **SymbolDelimiter** on Sender when the sender symbol has a suffix.

---

## Data files (Common path)

- **ct_queue/** — Event files (`.evt`). Created by Sender, read and deleted by Receiver.
- **ct_ledger/** — Processed event IDs (idempotency).
- **ct_map/** — Sender (login, ticket) → Receiver ticket for CLOSE.

Do not delete these while EAs are running if you need continuity.
