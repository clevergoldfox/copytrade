#property strict

#include <CT_Event.mqh>

input int ScanIntervalSeconds = 1;


// ================================
// Storage
// ================================
int KnownTickets[1000];
int KnownCount = 0;


// ================================
bool IsKnownTicket(int ticket)
{
   for(int i=0;i<KnownCount;i++)
   {
      if(KnownTickets[i] == ticket)
         return true;
   }
   return false;
}


// ================================
void AddKnownTicket(int ticket)
{
   KnownTickets[KnownCount] = ticket;
   KnownCount++;
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

   for(int i=0;i<total;i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
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
}