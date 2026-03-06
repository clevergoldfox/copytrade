// Simple CSV ledger: ct_ledger\ledger.csv
// columns: eventId,status,receiverTicket,ts

string CT_LEDGER_FILE = "ct_ledger\\ledger.csv";

bool CT_LedgerHas(string eventId)
{
   int h = FileOpen(CT_LEDGER_FILE, FILE_READ|FILE_TXT);
   if(h == INVALID_HANDLE) return false;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      // FileReadString reads tokens; we want full lines.
      // So read tokens until newline is tricky; instead store eventId alone as first token.
      // We'll write ledger in a token-friendly way below.
      if(line == eventId)
      {
         FileClose(h);
         return true;
      }
      // skip rest of row tokens (status, ticket, ts) if present
      if(!FileIsEnding(h)) FileReadString(h);
      if(!FileIsEnding(h)) FileReadString(h);
      if(!FileIsEnding(h)) FileReadString(h);
   }

   FileClose(h);
   return false;
}

bool CT_LedgerAppendDone(string eventId, int receiverTicket)
{
   // Ensure folder exists (silent if already exists)
   FolderCreate("ct_ledger");

   int h = FileOpen(CT_LEDGER_FILE, FILE_READ|FILE_WRITE|FILE_TXT);
   if(h == INVALID_HANDLE)
   {
      // Create new
      h = FileOpen(CT_LEDGER_FILE, FILE_WRITE|FILE_TXT);
      if(h == INVALID_HANDLE) return false;
   }
   else
   {
      FileSeek(h, 0, SEEK_END);
   }

   // Token-friendly (space-separated tokens)
   // eventId DONE ticket timestamp
   FileWrite(h, eventId, "DONE", receiverTicket, (int)TimeCurrent());

   FileClose(h);
   return true;
}