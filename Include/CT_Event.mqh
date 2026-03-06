// ================================
// Event Types
// ================================
#define CT_OPEN 1
#define CT_CLOSE 2
#define CT_HEARTBEAT 3

// ================================
// Convert event type to string
// ================================
string CT_EventTypeToString(int type)
{
   if(type == CT_OPEN) return "OPEN";
   if(type == CT_CLOSE) return "CLOSE";
   if(type == CT_HEARTBEAT) return "HEARTBEAT";
   return "UNKNOWN";
}

// ================================
// Build Unique Event ID
// ================================
string CT_BuildEventId(
   int type,
   int senderLogin,
   string senderServer,
   int ticket,
   datetime openTime,
   string symbol
)
{
   // Keep internal ID with | (good for uniqueness & parsing)
   StringReplace(senderServer, "|", "_");
   StringReplace(symbol, "|", "_");

   string typeStr = CT_EventTypeToString(type);

   string id =
      IntegerToString(senderLogin) + "_" +
      senderServer + "_" +
      IntegerToString(ticket) + "_" +
      IntegerToString((int)openTime) + "_" +
      symbol + "_" +
      typeStr;

   return id;
}

// ================================
// Write Event File (safe filename)
// ================================
bool CT_WriteEventFile(
   string eventId,
   int type,
   int cmd,              // OP_BUY / OP_SELL
   int senderLogin,
   string senderServer,
   string symbol,
   double lots,
   double price,
   int ticket
)
{
   // Windows filename must not contain |
   string safeEventId = eventId;
   StringReplace(safeEventId, "|", "_");

   string filePath = "ct_queue\\" + safeEventId + ".evt";

   int handle = FileOpen(filePath, FILE_WRITE | FILE_TXT);
   if(handle == INVALID_HANDLE)
   {
      Print("Failed to create event file: ", filePath, " err=", GetLastError());
      return false;
   }

   // Write as "key=value" one per line (receiver reads line-by-line)
   FileWrite(handle, "type=" + CT_EventTypeToString(type));
   FileWrite(handle, "eventId=" + eventId);
   FileWrite(handle, "cmd=" + IntegerToString(cmd));
   FileWrite(handle, "senderLogin=" + IntegerToString(senderLogin));
   FileWrite(handle, "senderServer=" + senderServer);
   FileWrite(handle, "symbol=" + symbol);
   FileWrite(handle, "lots=" + DoubleToString(lots, 2));
   FileWrite(handle, "price=" + DoubleToString(price, Digits));
   FileWrite(handle, "ticket=" + IntegerToString(ticket));

   FileClose(handle);
   return true;
}