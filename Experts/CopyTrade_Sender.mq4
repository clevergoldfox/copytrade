#property strict

#include <CT_Event.mqh>

input int ScanIntervalSeconds = 1;
input int ReceiverMagic       = 900001;   // must match receiver EA


// ================================
// Storage
// ================================
int KnownTickets[2000];
int KnownCount = 0;
int LastTickets[2000];
int LastCount = 0;

// ================================
bool IsKnownTicket(int ticket)
{
   for(int i = 0; i < KnownCount; i++)
   {
      if(KnownTickets[i] == ticket)
         return true;
   }

   return false;
}


// ================================
void AddKnownTicket(int ticket)
{
   if(KnownCount < ArraySize(KnownTickets))
   {
      KnownTickets[KnownCount] = ticket;
      KnownCount++;
   }

   if(LastCount < ArraySize(LastTickets))
   {
      LastTickets[LastCount] = ticket;
      LastCount++;
   }
}


// ================================
// Ignore receiver copied trades
// ================================
bool IsReceiverTrade()
{
   // skip receiver magic trades
   if(OrderMagicNumber() == ReceiverMagic)
      return true;

   // skip copied trades by comment
   if(StringFind(OrderComment(), "SRC:") == 0)
      return true;

   return false;
}


// ================================
int OnInit()
{
   Print("CopyTrade Sender Started");

   EventSetTimer(ScanIntervalSeconds);

   return(INIT_SUCCEEDED);
}


// ================================
void OnDeinit(const int reason)
{
   EventKillTimer();
}


// ================================
void OnTimer()
{
   DetectClosedTrades();
   ScanOpenTrades();
}


// ================================
void ScanOpenTrades()
{
   int total = OrdersTotal();

   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // only market orders
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      // skip receiver trades
      if(IsReceiverTrade())
         continue;

      int ticket = OrderTicket();

      if(IsKnownTicket(ticket))
         continue;

      AddKnownTicket(ticket);

      GenerateOpenEvent();
   }
}


// ================================
void GenerateOpenEvent()
{
   int senderLogin = AccountNumber();
   string senderServer = AccountServer();

   int ticket = OrderTicket();
   datetime openTime = OrderOpenTime();
   string symbol = OrderSymbol();
   double lots = OrderLots();
   double price = OrderOpenPrice();
   int cmd = OrderType(); // OP_BUY / OP_SELL

   string eventId =
      CT_BuildEventId(
         CT_OPEN,
         senderLogin,
         senderServer,
         ticket,
         openTime,
         symbol
      );

   Print("New OPEN Event: ", eventId);

   bool ok =
      CT_WriteEventFile(
         eventId,
         CT_OPEN,
         cmd,
         senderLogin,
         senderServer,
         symbol,
         lots,
         price,
         ticket
      );

   if(!ok)
      Print("Sender: Failed to write event file: ", eventId);
}

void DetectClosedTrades()
{
   for(int i=0;i<LastCount;i++)
   {
      int ticket = LastTickets[i];

      if(!IsTradeStillOpen(ticket))
      {
         GenerateCloseEvent(ticket);

         RemoveLastTicket(i);
         i--;
      }
   }
}

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

void RemoveLastTicket(int index)
{
   for(int i=index;i<LastCount-1;i++)
      LastTickets[i] = LastTickets[i+1];

   LastCount--;
}

void GenerateCloseEvent(int ticket)
{
   int senderLogin = AccountNumber();
   string senderServer = AccountServer();

   string symbol = "";
   datetime closeTime = TimeCurrent();

   string eventId =
      CT_BuildEventId(
         CT_CLOSE,
         senderLogin,
         senderServer,
         ticket,
         closeTime,
         symbol
      );

   Print("New CLOSE Event: ", eventId);

   CT_WriteEventFile(
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