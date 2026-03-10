#property strict

#include <CT_Config.mqh>
#include <CT_Event.mqh>
#include <CT_Ledger.mqh>
#include <CT_Map.mqh>
#include <CT_Symbol.mqh>

input int    タイマー秒     = 1;
input int    スリッページ   = 10;
input int    受信マジック   = 900001;
input double ロット倍率     = 1.0;
input string キューフォルダ = "ct_queue";
input string 共有フォルダパス = "";   // 2台のMT4で使う時は、両方から見えるフォルダのフルパス（例: D:\CopyTrade）。空欄なら従来どおり同一MT4用。
input string 銘柄変換       = "";

struct CT_Event
{
   string eventId;
   string typeStr;
   int cmd;
   int senderLogin;
   string senderServer;
   string symbol;
   double lots;
   double price;
   int ticket;
};

bool CT_ReadEventFile(string path, CT_Event &ev)
{
   Print("Receiver: reading event file -> ", path);

   int flags = FILE_READ | FILE_TXT;
   if(StringFind(path, ":") < 0) flags |= FILE_COMMON;
   int h = FileOpen(path, flags);

   if(h == INVALID_HANDLE)
   {
      Print("Receiver: FileOpen failed -> ", GetLastError());
      return false;
   }

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);

      int p = StringFind(line,"=");

      if(p < 0) continue;

      string k = StringSubstr(line,0,p);
      string v = StringSubstr(line,p+1);

      if(k=="type") ev.typeStr=v;
      if(k=="eventId") ev.eventId=v;
      if(k=="cmd") ev.cmd=(int)StrToInteger(v);
      if(k=="senderLogin") ev.senderLogin=(int)StrToInteger(v);
      if(k=="senderServer") ev.senderServer=v;
      if(k=="symbol") ev.symbol=v;
      if(k=="lots") ev.lots=StrToDouble(v);
      if(k=="price") ev.price=StrToDouble(v);
      if(k=="ticket") ev.ticket=(int)StrToInteger(v);
   }

   FileClose(h);

   Print("Receiver: parsed event -> ", ev.typeStr, " symbol=", ev.symbol, " ticket=", ev.ticket);

   return true;
}

int ExecuteOpen(const CT_Event &ev)
{
   Print("Receiver: executing OPEN trade (inverted)");

   RefreshRates();

   string symbolForOrder = CT_SymbolMapLookup(銘柄変換, ev.symbol);
   double lot = ev.lots * ロット倍率;

   // Invert: Sender BUY -> Receiver SELL, Sender SELL -> Receiver BUY
   int receiverCmd = (ev.cmd == OP_BUY) ? OP_SELL : OP_BUY;
   double price = (receiverCmd == OP_BUY) ? Ask : Bid;

   int ticket = OrderSend(
      symbolForOrder,
      receiverCmd,
      lot,
      price,
      スリッページ,
      0,
      0,
      "SRC:"+IntegerToString(ev.senderLogin)+"|T:"+IntegerToString(ev.ticket),
      受信マジック,
      0
   );

   if(ticket > 0)
   {
      Print("Receiver: trade opened ticket=", ticket);

      CT_MapAdd(ev.senderLogin, ev.ticket, ticket, symbolForOrder);
   }
   else
   {
      Print("Receiver: OrderSend failed -> ", GetLastError());
   }

   return ticket;
}

// Find receiver order by sender id in comment (fallback when map is missing)
int FindReceiverOrderByComment(int senderLogin, int senderTicket)
{
   string needComment = "SRC:" + IntegerToString(senderLogin) + "|T:" + IntegerToString(senderTicket);
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != 受信マジック)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderComment() == needComment)
         return OrderTicket();
   }
   return -1;
}

int ExecuteClose(const CT_Event &ev)
{
   Print("Receiver: executing CLOSE");

   int receiverTicket = 0;

   if(!CT_MapFind(ev.senderLogin, ev.ticket, receiverTicket))
   {
      receiverTicket = FindReceiverOrderByComment(ev.senderLogin, ev.ticket);
      if(receiverTicket < 0)
      {
         Print("Receiver: mapped ticket not found (senderLogin=", ev.senderLogin, " senderTicket=", ev.ticket, ")");
         return -1;
      }
      Print("Receiver: found order by comment (map was missing) ticket=", receiverTicket);
   }

   if(!OrderSelect(receiverTicket, SELECT_BY_TICKET))
   {
      Print("Receiver: OrderSelect failed");
      return -1;
   }

   RefreshRates();

   double price = (OrderType()==OP_BUY) ? Bid : Ask;

   if(OrderClose(receiverTicket, OrderLots(), price, スリッページ))
   {
      Print("Receiver: trade closed ticket=", receiverTicket);

      CT_MapRemove(ev.senderLogin, ev.ticket);

      return receiverTicket;
   }

   Print("Receiver: OrderClose failed -> ", GetLastError());

   return -1;
}

void CT_ProcessQueue()
{
   g_CT_BasePath = 共有フォルダパス;

   string queuePath;
   int findFlag;
   if(g_CT_BasePath != "")
   {
      queuePath = g_CT_BasePath + "\\" + キューフォルダ;
      FolderCreate(queuePath, 0);
      findFlag = 0;
   }
   else
   {
      queuePath = キューフォルダ;
      FolderCreate(キューフォルダ, FILE_COMMON);
      findFlag = FILE_COMMON;
   }

   string filename;

   long f = FileFindFirst(queuePath + "\\*.evt", filename, findFlag);

   if(f == -1)
      return;   // Queue empty – normal when Sender has no new events

   Print("Receiver: found event file -> ", filename);

   string path = queuePath + "\\" + filename;

   CT_Event ev;

   if(!CT_ReadEventFile(path, ev))
   {
      Print("Receiver: failed to read event");
      FileFindClose(f);
      return;
   }

   if(CT_LedgerHas(ev.eventId))
   {
      Print("Receiver: event already processed -> ", ev.eventId);

      FileDelete(path, (StringFind(path, ":") >= 0) ? 0 : FILE_COMMON);

      FileFindClose(f);
      return;
   }

   if(ev.typeStr=="OPEN")
   {
      // Duplicate prevention: already have an open position for this sender entry -> skip open, consume event
      int existingTicket = FindReceiverOrderByComment(ev.senderLogin, ev.ticket);
      if(existingTicket > 0)
      {
         Print("Receiver: OPEN skipped (already have position for this sender entry, ticket=", existingTicket, ")");
         CT_LedgerAppendDone(ev.eventId, existingTicket);
         FileDelete(path, (StringFind(path, ":") >= 0) ? 0 : FILE_COMMON);
         FileFindClose(f);
         return;
      }

      int t = ExecuteOpen(ev);

      if(t > 0)
      {
         CT_LedgerAppendDone(ev.eventId, t);

         FileDelete(path, (StringFind(path, ":") >= 0) ? 0 : FILE_COMMON);

         Print("Receiver: OPEN completed");
      }
   }

   if(ev.typeStr=="CLOSE")
   {
      int t = ExecuteClose(ev);

      if(t > 0)
      {
         CT_LedgerAppendDone(ev.eventId, t);

         FileDelete(path, (StringFind(path, ":") >= 0) ? 0 : FILE_COMMON);

         Print("Receiver: CLOSE completed");
      }
      else
      {
         // Orphan CLOSE: no mapped ticket and no order found by comment - consume event to stop infinite retry
         CT_LedgerAppendDone(ev.eventId, 0);

         FileDelete(path, (StringFind(path, ":") >= 0) ? 0 : FILE_COMMON);

         Print("Receiver: CLOSE skipped (no mapped ticket, event consumed to avoid retry loop)");
      }
   }

   FileFindClose(f);
}

int OnInit()
{
   g_CT_BasePath = 共有フォルダパス;
   Print("CopyTrade_Receiver started");

   EventSetTimer(タイマー秒);

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