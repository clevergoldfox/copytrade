string CT_MAP_FILE = "ct_map\\ticket_map.csv";

bool CT_MapFind(int senderLogin,int senderTicket,int &receiverTicket)
{
   int h = FileOpen(CT_MAP_FILE,FILE_READ|FILE_CSV|FILE_COMMON);

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
   FolderCreate("ct_map",FILE_COMMON);

   int h = FileOpen(CT_MAP_FILE,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);

   if(h==INVALID_HANDLE)
      h = FileOpen(CT_MAP_FILE,FILE_WRITE|FILE_CSV|FILE_COMMON);
   else
      FileSeek(h,0,SEEK_END);

   FileWrite(h,senderLogin,senderTicket,receiverTicket,symbol,(int)TimeCurrent());

   FileClose(h);

   return true;
}

bool CT_MapRemove(int senderLogin,int senderTicket)
{
   int in = FileOpen(CT_MAP_FILE,FILE_READ|FILE_CSV|FILE_COMMON);

   if(in==INVALID_HANDLE)
      return false;

   string tmp="ct_map\\tmp.csv";
   int out = FileOpen(tmp,FILE_WRITE|FILE_CSV|FILE_COMMON);

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

   FileDelete(CT_MAP_FILE,FILE_COMMON);
   FileMove(tmp,FILE_COMMON,CT_MAP_FILE,FILE_COMMON);

   return removed;
}