#property strict

#include <CT_Ledger.mqh>

// ========= Inputs =========
input double LotMultiplier = 0.01;   // safer default for testing
input int    TimerSeconds  = 1;
input int    Slippage      = 10;
input string SymbolMap     = "";     // example: "GOLD=XAUUSD;USDJPY=USDJPY"

// ========= Utils =========
string CT_Trim(string s)
{
   while(StringLen(s) > 0 && (StringGetChar(s,0) == ' ' || StringGetChar(s,0) == '\t'))
      s = StringSubstr(s,1);

   while(StringLen(s) > 0)
   {
      int last = StringLen(s) - 1;
      int c = StringGetChar(s,last);
      if(c == ' ' || c == '\t' || c == '\r' || c == '\n')
         s = StringSubstr(s,0,last);
      else
         break;
   }
   return s;
}

bool CT_SplitKeyValue(string line, string &key, string &val)
{
   int p = StringFind(line, "=");
   if(p < 0) return false;

   key = CT_Trim(StringSubstr(line, 0, p));
   val = CT_Trim(StringSubstr(line, p + 1));
   return true;
}

string CT_MapSymbol(string s)
{
   if(SymbolMap == "") return s;

   int start = 0;
   while(true)
   {
      int semi = StringFind(SymbolMap, ";", start);
      string part = (semi < 0) ? StringSubstr(SymbolMap, start) : StringSubstr(SymbolMap, start, semi - start);
      part = CT_Trim(part);

      if(part != "")
      {
         int eq = StringFind(part, "=");
         if(eq > 0)
         {
            string from = CT_Trim(StringSubstr(part, 0, eq));
            string to   = CT_Trim(StringSubstr(part, eq + 1));

            if(from == s)
               return to;
         }
      }

      if(semi < 0) break;
      start = semi + 1;
   }

   return s;
}

double CT_NormalizeLot(string symbol, double lot)
{
   double minLot  = MarketInfo(symbol, MODE_MINLOT);
   double stepLot = MarketInfo(symbol, MODE_LOTSTEP);
   double maxLot  = MarketInfo(symbol, MODE_MAXLOT);

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   if(stepLot > 0)
      lot = MathFloor(lot / stepLot + 0.0000001) * stepLot;

   return NormalizeDouble(lot, 2);
}

int CT_ReverseCmd(int cmd)
{
   if(cmd == OP_BUY)       return OP_SELL;
   if(cmd == OP_SELL)      return OP_BUY;

   if(cmd == OP_BUYLIMIT)  return OP_SELL;
   if(cmd == OP_BUYSTOP)   return OP_SELL;

   if(cmd == OP_SELLLIMIT) return OP_BUY;
   if(cmd == OP_SELLSTOP)  return OP_BUY;

   return cmd;
}

// ========= Event model =========
struct CT_Event
{
   string eventId;
   string typeStr;
   int    cmd;
   int    senderLogin;
   string senderServer;
   string symbol;
   double lots;
   double price;
   int    ticket;
};

bool CT_ReadEventFile(string relPath, CT_Event &ev)
{
   int h = FileOpen(relPath, FILE_READ | FILE_TXT);
   if(h == INVALID_HANDLE)
      return false;

   ev.eventId      = "";
   ev.typeStr      = "";
   ev.cmd          = -1;
   ev.senderLogin  = 0;
   ev.senderServer = "";
   ev.symbol       = "";
   ev.lots         = 0;
   ev.price        = 0;
   ev.ticket       = 0;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(StringFind(line, "=") < 0)
         continue;

      string k, v;
      if(!CT_SplitKeyValue(line, k, v))
         continue;

      if(k == "type")              ev.typeStr = v;
      else if(k == "eventId")      ev.eventId = v;
      else if(k == "cmd")          ev.cmd = (int)StrToInteger(v);
      else if(k == "senderLogin")  ev.senderLogin = (int)StrToInteger(v);
      else if(k == "senderServer") ev.senderServer = v;
      else if(k == "symbol")       ev.symbol = v;
      else if(k == "lots")         ev.lots = StrToDouble(v);
      else if(k == "price")        ev.price = StrToDouble(v);
      else if(k == "ticket")       ev.ticket = (int)StrToInteger(v);
   }

   FileClose(h);

   return (ev.eventId != "" && ev.typeStr != "" && ev.symbol != "" && ev.cmd != -1);
}

void CT_MoveToFailed(string relPath, string reason)
{
   FolderCreate("ct_failed");

   string filename = relPath;
   StringReplace(filename, "ct_queue\\", "");

   string failedPath = "ct_failed\\" + filename;

   int src = FileOpen(relPath, FILE_READ | FILE_TXT);
   if(src == INVALID_HANDLE)
      return;

   int dst = FileOpen(failedPath, FILE_WRITE | FILE_TXT);
   if(dst == INVALID_HANDLE)
   {
      FileClose(src);
      return;
   }

   while(!FileIsEnding(src))
   {
      string line = FileReadString(src);
      FileWrite(dst, line);
   }

   FileWrite(dst, "failReason=" + reason);

   FileClose(src);
   FileClose(dst);

   FileDelete(relPath);
}

bool CT_IsTradeAllowedNow()
{
   if(!IsTradeAllowed())
   {
      Print("Receiver: trade not allowed");
      return false;
   }

   if(IsTradeContextBusy())
   {
      Print("Receiver: trade context busy");
      return false;
   }

   return true;
}

int CT_ExecuteOpen(const CT_Event &ev)
{
   string symbol = CT_MapSymbol(ev.symbol);

   if(!SymbolSelect(symbol, true))
   {
      Print("Receiver: SymbolSelect failed for ", symbol);
      return -1;
   }

   int revCmd = CT_ReverseCmd(ev.cmd);
   double lot = CT_NormalizeLot(symbol, ev.lots * LotMultiplier);

   // Ensure symbol is available
   if(!SymbolSelect(symbol, true))
   {
      Print("Receiver: cannot select symbol ", symbol);
      return -1;
   }
   
   // Wait for price if needed
   RefreshRates();
   
   double bid = MarketInfo(symbol, MODE_BID);
   double ask = MarketInfo(symbol, MODE_ASK);
   
   if(bid <= 0 || ask <= 0)
   {
      Print("Receiver: waiting for tick for ", symbol);
      return -1;
   }
   
   double price = (revCmd == OP_BUY) ? ask : bid;

   // Margin check
   int marginCmd = revCmd;

   if(marginCmd != OP_BUY && marginCmd != OP_SELL)
   {
      if(marginCmd == OP_BUYLIMIT || marginCmd == OP_BUYSTOP)
         marginCmd = OP_BUY;
   
      if(marginCmd == OP_SELLLIMIT || marginCmd == OP_SELLSTOP)
         marginCmd = OP_SELL;
   }
   
   double fm = AccountFreeMarginCheck(symbol, marginCmd, lot);
   if(fm <= 0 || GetLastError() == 134)
   {
      Print("Receiver: not enough margin for ", symbol, " lot=", DoubleToString(lot, 2));
      return -1;
   }

   string comment = "SRC:" + IntegerToString(ev.senderLogin) + "|T:" + IntegerToString(ev.ticket);

   ResetLastError();

   int ticket = -1;

   for(int attempt = 0; attempt < 10; attempt++)
   {
      int waitCount = 0;
   
      while(IsTradeContextBusy())
      {
         Sleep(200);
         waitCount++;
   
         if(waitCount > 25)
         {
            Print("Receiver: trade context stuck");
            return -1;
         }
      }
   
      RefreshRates();
   
      price = (revCmd == OP_BUY)
         ? MarketInfo(symbol, MODE_ASK)
         : MarketInfo(symbol, MODE_BID);
   
      ResetLastError();
   
      ticket = OrderSend(symbol, revCmd, lot, price, Slippage, 0, 0, comment, 0, 0, clrNONE);
   
      if(ticket > 0)
         return ticket;
   
      int err = GetLastError();
   
      Print("Receiver: OrderSend failed attempt=", attempt+1, " err=", err);
   
      if(err != 148)
         break;
   
      Sleep(1000);
   }
   
   return -1;
}

void CT_ProcessQueue()
{
   FolderCreate("ct_queue");
   FolderCreate("ct_ledger");
   FolderCreate("ct_failed");

   string filename;
   long found = FileFindFirst("ct_queue\\*.evt", filename);

   if(found == -1)
      return;

   // IMPORTANT:
   // process only ONE file per timer cycle
   string relPath = "ct_queue\\" + filename;

   CT_Event ev;
   if(!CT_ReadEventFile(relPath, ev))
   {
      Print("Receiver: failed to parse ", relPath);
      CT_MoveToFailed(relPath, "parse_error");
      FileFindClose(found);
      return;
   }

   // Duplicate check
   if(CT_LedgerHas(ev.eventId))
   {
      Print("Receiver: already processed, deleting ", ev.eventId);
      FileDelete(relPath);
      FileFindClose(found);
      return;
   }

   if(ev.typeStr == "OPEN")
   {
      int rticket = CT_ExecuteOpen(ev);

      if(rticket > 0)
      {
         CT_LedgerAppendDone(ev.eventId, rticket);
         FileDelete(relPath);
         Print("Receiver: OPEN done eventId=", ev.eventId, " rticket=", rticket);
      }
      else
      {
         Print("Receiver: OPEN failed eventId=", ev.eventId, " err=", GetLastError());
         // keep file for retry next timer cycle
      }
   }
   else
   {
      Print("Receiver: unsupported type=", ev.typeStr, " moving to failed");
      CT_MoveToFailed(relPath, "unsupported_type");
   }

   FileFindClose(found);
}

// ========= EA =========
int OnInit()
{
   Print("CopyTrade_Receiver started");
   EventSetTimer(TimerSeconds);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   CT_ProcessQueue();
}