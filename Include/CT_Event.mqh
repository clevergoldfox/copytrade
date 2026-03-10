#define CT_OPEN 1
#define CT_CLOSE 2

string CT_EventTypeToString(int type)
{
   if(type == CT_OPEN)  return "OPEN";
   if(type == CT_CLOSE) return "CLOSE";
   return "UNKNOWN";
}

string CT_BuildEventId(
   int type,
   int senderLogin,
   string senderServer,
   int ticket,
   datetime baseTime,
   string symbol
)
{
   return IntegerToString(senderLogin) + "|" +
          senderServer + "|" +
          IntegerToString(ticket) + "|" +
          IntegerToString((int)baseTime) + "|" +
          symbol + "|" +
          CT_EventTypeToString(type);
}

string CT_SafeFileName(string s)
{
   StringReplace(s, "|", "_");
   StringReplace(s, "\\", "_");
   StringReplace(s, "/", "_");
   StringReplace(s, ":", "_");
   StringReplace(s, "*", "_");
   StringReplace(s, "?", "_");
   StringReplace(s, "\"", "_");
   StringReplace(s, "<", "_");
   StringReplace(s, ">", "_");
   return s;
}

bool CT_WriteEventFileCommon(
   string queueFolder,
   string eventId,
   int type,
   int cmd,
   int senderLogin,
   string senderServer,
   string symbol,
   double lots,
   double price,
   int ticket
)
{
   FolderCreate(queueFolder, FILE_COMMON);

   string safeId = CT_SafeFileName(eventId);
   string path   = queueFolder + "\\" + safeId + ".evt";

   int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_COMMON);

   if(h == INVALID_HANDLE)
   {
      Print("cannot create event file ", path, " err=", GetLastError());
      return false;
   }

   FileWrite(h, "type=" + CT_EventTypeToString(type));
   FileWrite(h, "eventId=" + eventId);
   FileWrite(h, "cmd=" + IntegerToString(cmd));
   FileWrite(h, "senderLogin=" + IntegerToString(senderLogin));
   FileWrite(h, "senderServer=" + senderServer);
   FileWrite(h, "symbol=" + symbol);
   FileWrite(h, "lots=" + DoubleToString(lots, 2));
   FileWrite(h, "price=" + DoubleToString(price, 8));
   FileWrite(h, "ticket=" + IntegerToString(ticket));

   FileClose(h);

   return true;
}