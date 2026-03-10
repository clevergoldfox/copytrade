#include <CT_Config.mqh>

string CT_LEDGER_FILE = "ct_ledger\\ledger.csv";

bool CT_LedgerHas(string eventId)
{
   string path = (g_CT_BasePath != "") ? (g_CT_BasePath + "\\" + CT_LEDGER_FILE) : CT_LEDGER_FILE;
   int flags = FILE_READ | FILE_CSV;
   if(g_CT_BasePath == "") flags |= FILE_COMMON;
   int h = FileOpen(path, flags);

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
   string path = (g_CT_BasePath != "") ? (g_CT_BasePath + "\\" + CT_LEDGER_FILE) : CT_LEDGER_FILE;
   int flagsRw = FILE_READ|FILE_WRITE|FILE_CSV;
   int flagsW = FILE_WRITE|FILE_CSV;
   if(g_CT_BasePath == "") { flagsRw |= FILE_COMMON; flagsW |= FILE_COMMON; }
   else FolderCreate(g_CT_BasePath + "\\ct_ledger", 0);

   int h = FileOpen(path, flagsRw);

   if(h==INVALID_HANDLE)
      h = FileOpen(path, flagsW);
   else
      FileSeek(h,0,SEEK_END);

   FileWrite(h,eventId,"DONE",receiverTicket,(int)TimeCurrent());

   FileClose(h);

   return true;
}