string CT_LEDGER_FILE = "ct_ledger\\ledger.csv";

bool CT_LedgerHas(string eventId)
{
   int h = FileOpen(CT_LEDGER_FILE, FILE_READ | FILE_CSV | FILE_COMMON);

   if(h == INVALID_HANDLE)
      return false;

   while(!FileIsEnding(h))
   {
      string ev = FileReadString(h);
      FileReadString(h);
      FileReadNumber(h);
      FileReadNumber(h);

      if(ev == eventId)
      {
         FileClose(h);
         return true;
      }
   }

   FileClose(h);
   return false;
}

bool CT_LedgerAppendDone(string eventId,int receiverTicket)
{
   FolderCreate("ct_ledger",FILE_COMMON);

   int h = FileOpen(CT_LEDGER_FILE, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);

   if(h==INVALID_HANDLE)
      h = FileOpen(CT_LEDGER_FILE,FILE_WRITE|FILE_CSV|FILE_COMMON);
   else
      FileSeek(h,0,SEEK_END);

   FileWrite(h,eventId,"DONE",receiverTicket,(int)TimeCurrent());

   FileClose(h);

   return true;
}