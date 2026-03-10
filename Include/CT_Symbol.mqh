// Symbol delimiter and mapping helpers for cross-broker copy trade
// Delimiter: XAUUSD-cd with delimiter "-" -> base XAUUSD
// Mapping: "GOLD=XAUUSD,SILVER=XAGUSD" -> lookup by key, return value (set on one side only)

string CT_GetBaseSymbol(string symbol, string delimiter)
{
   if(delimiter == "" || StringLen(delimiter) < 1)
      return symbol;
   int pos = StringFind(symbol, delimiter);
   if(pos < 0)
      return symbol;
   return StringSubstr(symbol, 0, pos);
}

// Look up symbol in mapping string "KEY1=VAL1,KEY2=VAL2". Returns mapped value or original if not found.
string CT_SymbolMapLookup(string mapping, string symbol)
{
   if(mapping == "" || StringTrimLeft(StringTrimRight(mapping)) == "")
      return symbol;
   string s = mapping;
   int start = 0;
   while(start < StringLen(s))
   {
      int comma = StringFind(s, ",", start);
      int end = (comma >= 0) ? comma : StringLen(s);
      string part = StringSubstr(s, start, end - start);
      int eq = StringFind(part, "=");
      if(eq > 0)
      {
         string key = StringTrimRight(StringTrimLeft(StringSubstr(part, 0, eq)));
         string val = StringTrimRight(StringTrimLeft(StringSubstr(part, eq + 1)));
         if(key == symbol)
            return val;
      }
      start = end + ((comma >= 0) ? 1 : 0);
   }
   return symbol;
}
