#property strict

#include <CT_Event.mqh>

input int ScanIntervalSeconds = 1;
input int ReceiverMagic       = 900001;   // must match receiver EA


// ================================
// Storage
// ================================
int KnownTickets[2000];
int KnownCount = 0;


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
   if(KnownCount >= ArraySize(KnownTickets))
      return;

   KnownTickets[KnownCount] = ticket;
   KnownCount++;
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