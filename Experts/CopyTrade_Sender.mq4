#property strict
#include <CT_Config.mqh>
#include <CT_Event.mqh>
#include <CT_Symbol.mqh>

input int    スキャン間隔秒     = 1;
input int    受信マジック       = 900001;
input string キューフォルダ     = "ct_queue";
input string 共有フォルダパス   = "";   // 2台のMT4で使う時は、両方から見えるフォルダのフルパス（例: D:\CopyTrade）。空欄なら従来どおり同一MT4用。
input string 銘柄区切り         = "";
input string 銘柄変換           = "";

// ===== Storage =====
int    KnownTickets[5000];
int    KnownCount = 0;

int    LastTickets[5000];
string LastSymbols[5000];
int    LastCount = 0;


// ===== Check if ticket already processed =====
bool IsKnownTicket(int ticket)
{
   for(int i=0;i<KnownCount;i++)
      if(KnownTickets[i] == ticket)
         return true;

   return false;
}


// ===== Store new ticket =====
void AddKnownTicket(int ticket,string symbol)
{
   if(KnownCount < ArraySize(KnownTickets))
      KnownTickets[KnownCount++] = ticket;

   bool exists=false;

   for(int i=0;i<LastCount;i++)
      if(LastTickets[i]==ticket)
      {
         exists=true;
         break;
      }

   if(!exists && LastCount < ArraySize(LastTickets))
   {
      LastTickets[LastCount] = ticket;
      LastSymbols[LastCount] = symbol;
      LastCount++;
   }
}


// ===== Detect receiver trades to ignore =====
bool IsReceiverTrade()
{
   if(OrderMagicNumber()==受信マジック)
      return true;

   if(StringFind(OrderComment(),"SRC:")==0)
      return true;

   return false;
}


// ===== Check if trade still open =====
bool IsTradeStillOpen(int ticket)
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderTicket()==ticket)
         return true;
   }

   return false;
}


// ===== Remove closed ticket =====
void RemoveLastTicket(int index)
{
   for(int i=index;i<LastCount-1;i++)
   {
      LastTickets[i] = LastTickets[i+1];
      LastSymbols[i] = LastSymbols[i+1];
   }

   LastCount--;
}


// ===== Generate OPEN event =====
void GenerateOpenEvent()
{
   int senderLogin     = AccountNumber();
   string senderServer = AccountServer();

   int ticket          = OrderTicket();
   datetime openTime   = OrderOpenTime();
   string symbol       = CT_SymbolMapLookup(銘柄変換, CT_GetBaseSymbol(OrderSymbol(), 銘柄区切り));
   double lots         = OrderLots();
   double price        = OrderOpenPrice();
   int cmd             = OrderType();

   string eventId =
      CT_BuildEventId(
         CT_OPEN,
         senderLogin,
         senderServer,
         ticket,
         openTime,
         symbol
      );

   Print("Sender: OPEN event ", eventId);

   if(!CT_WriteEventFileCommon(
      キューフォルダ,
      eventId,
      CT_OPEN,
      cmd,
      senderLogin,
      senderServer,
      symbol,
      lots,
      price,
      ticket))
   {
      Print("Sender: OPEN event write failed");
   }
}


// ===== Generate CLOSE event =====
void GenerateCloseEvent(int ticket,string symbol)
{
   if(symbol=="")
   {
      Print("Sender: CLOSE skipped (empty symbol) ticket=",ticket);
      return;
   }

   int senderLogin     = AccountNumber();
   string senderServer = AccountServer();

   datetime closeTime  = TimeCurrent();

   string eventId =
      CT_BuildEventId(
         CT_CLOSE,
         senderLogin,
         senderServer,
         ticket,
         closeTime,
         symbol
      );

   Print("Sender: CLOSE event ",eventId);

   CT_WriteEventFileCommon(
      キューフォルダ,
      eventId,
      CT_CLOSE,
      0,
      senderLogin,
      senderServer,
      symbol,
      0,
      0,
      ticket
   );
}


// ===== Detect closed trades =====
void DetectClosedTrades()
{
   for(int i=0;i<LastCount;i++)
   {
      int ticket = LastTickets[i];

      if(!IsTradeStillOpen(ticket))
      {
         GenerateCloseEvent(ticket,LastSymbols[i]);

         RemoveLastTicket(i);
         i--;
      }
   }
}


// ===== Scan open trades =====
void ScanOpenTrades()
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      int type = OrderType();

      if(type!=OP_BUY && type!=OP_SELL)
         continue;

      if(IsReceiverTrade())
         continue;

      int ticket = OrderTicket();

      if(IsKnownTicket(ticket))
         continue;

      string baseSym = CT_GetBaseSymbol(OrderSymbol(), 銘柄区切り);
      string symbol = CT_SymbolMapLookup(銘柄変換, baseSym);

      AddKnownTicket(ticket, symbol);

      GenerateOpenEvent();
   }
}


// ===== INIT =====
int OnInit()
{
   g_CT_BasePath = 共有フォルダパス;
   Print("CopyTrade_Sender started");

   EventSetTimer(スキャン間隔秒);

   return(INIT_SUCCEEDED);
}


// ===== DEINIT =====
void OnDeinit(const int reason)
{
   EventKillTimer();
}


// ===== TIMER =====
void OnTimer()
{
   // order important for stability
   ScanOpenTrades();

   DetectClosedTrades();
}