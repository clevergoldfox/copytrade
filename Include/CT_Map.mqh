#include <CT_Config.mqh>

string CT_MAP_FILE = "ct_map\\ticket_map.csv";

bool CT_MapFind(int senderLogin,int senderTicket,int &receiverTicket)
{
   string path = (g_CT_BasePath != "") ? (g_CT_BasePath + "\\" + CT_MAP_FILE) : CT_MAP_FILE;
   int flags = FILE_READ|FILE_CSV;
   if(g_CT_BasePath == "") flags |= FILE_COMMON;
   int h = FileOpen(path, flags);

   if(h==INVALID_HANDLE)
      return false;

   while(!FileIsEnding(h))
   {
      int login=(int)FileReadNumber(h);
      int st=(int)FileReadNumber(h);
      int rt=(int)FileReadNumber(h);

      FileReadString(h);
      FileReadNumber(h);

      if(login==senderLogin && st==senderTicket)
      {
         receiverTicket=rt;
         FileClose(h);
         return true;
      }
   }

   FileClose(h);
   return false;
}

bool CT_MapAdd(int senderLogin,int senderTicket,int receiverTicket,string symbol)
{
   string path = (g_CT_BasePath != "") ? (g_CT_BasePath + "\\" + CT_MAP_FILE) : CT_MAP_FILE;
   int flagsRw = FILE_READ|FILE_WRITE|FILE_CSV;
   int flagsW = FILE_WRITE|FILE_CSV;
   if(g_CT_BasePath == "") { flagsRw |= FILE_COMMON; flagsW |= FILE_COMMON; }
   else FolderCreate(g_CT_BasePath + "\\ct_map", 0);

   int h = FileOpen(path, flagsRw);

   if(h==INVALID_HANDLE)
      h = FileOpen(path, flagsW);
   else
      FileSeek(h,0,SEEK_END);

   FileWrite(h,senderLogin,senderTicket,receiverTicket,symbol,(int)TimeCurrent());

   FileClose(h);

   return true;
}

bool CT_MapRemove(int senderLogin,int senderTicket)
{
   string path = (g_CT_BasePath != "") ? (g_CT_BasePath + "\\" + CT_MAP_FILE) : CT_MAP_FILE;
   string tmpPath = (g_CT_BasePath != "") ? (g_CT_BasePath + "\\ct_map\\tmp.csv") : "ct_map\\tmp.csv";
   int flagsR = FILE_READ|FILE_CSV;
   int flagsW = FILE_WRITE|FILE_CSV;
   if(g_CT_BasePath == "") { flagsR |= FILE_COMMON; flagsW |= FILE_COMMON; }

   int in = FileOpen(path, flagsR);

   if(in==INVALID_HANDLE)
      return false;

   int out = FileOpen(tmpPath, flagsW);

   bool removed=false;

   while(!FileIsEnding(in))
   {
      int login=(int)FileReadNumber(in);
      int st=(int)FileReadNumber(in);
      int rt=(int)FileReadNumber(in);
      string sym=FileReadString(in);
      int ts=(int)FileReadNumber(in);

      if(login==senderLogin && st==senderTicket)
      {
         removed=true;
         continue;
      }

      FileWrite(out,login,st,rt,sym,ts);
   }

   FileClose(in);
   FileClose(out);

   if(g_CT_BasePath != "")
   {
      FileDelete(path, 0);
      FileMove(tmpPath, 0, path, 0);
   }
   else
   {
      FileDelete(CT_MAP_FILE, FILE_COMMON);
      FileMove("ct_map\\tmp.csv", FILE_COMMON, CT_MAP_FILE, FILE_COMMON);
   }

   return removed;
}