//+------------------------------------------------------------------+
//|                                                  flyingGlass.mq5 |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- input parameters
input int      LevelDelta=200;
input int      SL=15;
input int      TPX=2;
input bool     BuyEnable=true;
input bool     SellEnable=true;
input int      Capacitor=2000;
input uchar    TimeDelta=2;
input int      LotsVolume=1;
input int MaxOrdersCount=2;
input double FreeMargin=100;
input int OrderExpirationMinute=10;
MqlBookInfo priceArray[];

#define SLIPPAGE 3
double High[],Low[];
#define ASK SymbolInfoDouble(Symbol(),SYMBOL_ASK) 
#define BID SymbolInfoDouble(Symbol(),SYMBOL_BID) 
#define SPRED SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*_Point
#define ACCURACY 2*_Point
#define MAGIC 777
#define TIMEDELAY 180 
#define MINTP 7*_Point
#define MAXDELTA 10*_Point
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(TimeDelta);
   if(!MarketBookAdd(_Symbol))
     {
      Alert("Error open book. "+IntegerToString(GetLastError()));
      return INIT_FAILED;
     }
//   WR();
//--- Obtain the value of the property that describes allowed expiration modes 
//   int expiration=(int)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
//   Print("Expiration="+IntegerToString(expiration));
//TestExpir();
//return INIT_FAILED;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   MarketBookRelease(_Symbol);
   RemoveAll();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
//if (MarketBookGet(NULL,priceArray))
//   TestOrder();
/*   Start();
    ExpertRemove();
return; 
*/

//   MqlBookInfo priceArray[];
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      return;
     }
   CheckOrders();
   bool getBook=MarketBookGet(_Symbol,priceArray);
   if(getBook)
     {
      BuyStopOrder();
      SellStopOrder();
      ModifyOrder();

      //      Print(DoubleToString(BuyPrice(priceArray),0));
/*
      int size=ArraySize(priceArray); 
      Print("MarketBookInfo for ",_Symbol); 
      for(int i=0;i<size;i++) 
        { 
         Print(i+":",priceArray[i].price 
               +"    Volume = "+priceArray[i].volume, 
               " type = ",priceArray[i].type); 
        } 
*/
     }
   else
     {
      Print("Could not get contents of the symbol DOM ",Symbol());
     }

  }
//+------------------------------------------------------------------+

double SellPrice()
  {
   long vol=0;
   int size=ArraySize(priceArray);

   for(int i=size/2;i<size;i++)
     {
      if(priceArray[i].type==BOOK_TYPE_BUY)
         vol+=priceArray[i].volume;
      if(vol>=Capacitor)
        {
         return priceArray[i].price-_Point;
        }

     }
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double BuyPrice()
  {
   long vol=0;
   int size=ArraySize(priceArray);

   for(int i=size/2-1;i>=0;i--)
     {
      if(priceArray[i].type==BOOK_TYPE_SELL)
         vol+=priceArray[i].volume;
      if(vol>=Capacitor)
        {
         return priceArray[i].price+_Point;
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+
void ModifyOrder()
  {
   int total;
   MqlTradeRequest request={0};
   MqlTradeResult  result={0};

   total=OrdersTotal();
   double Price;
   for(int i=0;i<total;i++)
     {
      if(OrderGetTicket(i)==0) continue;
      //Только сделки робота
      if(IsItMyOrder())
         //Тут мы должны выбрать только не сработавшие ордера.      
         if(OrderGetInteger(ORDER_STATE)==ORDER_STATE_PLACED)
           {

            if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_STOP)
              {
               Price=BuyPrice();//Bid+LevelDelta*Point;
               if(!(Price>0)) Price=ASK+LevelDelta*_Point;
               if ((Price - ASK)>MAXDELTA) Price=ASK+LevelDelta*_Point;

               if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-(Price+SPRED))>ACCURACY)
                 {
                  PredefineRequest(request,TRADE_ACTION_MODIFY);
                  ZeroMemory(result);

                  request.order=OrderGetInteger(ORDER_TICKET);
                  DefineBuyRequest(request,Price);

                  if(!OrderSend(request,result))
                     PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
                  //--- information about the operation   
                  if(result.retcode!=10009)
                     PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
                  //--- zeroing the request and result values
                 }
              }
            if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP)
              {
               Price=SellPrice();
               if(!(Price>0)) Price=BID-LevelDelta*_Point;
               if ((BID - Price) > MAXDELTA) Price=BID-LevelDelta*_Point;

               if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-Price)>ACCURACY)
                 {
                  PredefineRequest(request,TRADE_ACTION_MODIFY);
                  ZeroMemory(result);

                  request.order=OrderGetInteger(ORDER_TICKET);
                  DefineSellRequest(request,Price);

                  if(!OrderSend(request,result))
                     PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
                  //--- information about the operation   
                  if(result.retcode!=10009)
                     PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
                  //--- zeroing the request and result values
                 }

              }
           }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
uint BuyStopOrder()
  {

   double Price;
   MqlTradeRequest request={0};
   MqlTradeResult result={0};

   if(!BuyEnable) return 0;
   Price=BuyPrice();
   if(!(Price > 0)) return 0;
   if ((Price - ASK)>MAXDELTA) return 0;
   if(IsOrderAllowed(ORDER_TYPE_BUY_STOP))
     {
      PredefineRequest(request);
      ZeroMemory(result);
      DefineBuyRequest(request,Price);
      //--- send a trade request 
      if(!OrderSend(request,result))
        {
         //--- write the server reply to log   
         Print(__FUNCTION__,":",result.comment);
         PrintResult(false,result,request);
         Print("Message not sent. Error: ",GetLastError());
         Print("Price: "+DoubleToString(Price,Digits()));
         Print("SL: "+DoubleToString(request.sl));
         Print("Tp: "+DoubleToString(request.tp));

        }
      if(result.retcode==10008) Print(__FUNCTION__,":",result.comment,result.bid,result.ask,result.price);
      //--- return code of the trade server reply 
     }

   return result.retcode;
  }
//------------------------------------------------------------------+
bool IsOrderAllowed(ENUM_ORDER_TYPE type)
  {
   int count=0;
   int total;
   total=OrdersTotal();
   for(int i=0;i<total;i++)
     {

      if(OrderGetTicket(i)==0) continue;

      if(OrderGetInteger(ORDER_TYPE)==type)
         if(OrderGetString(ORDER_SYMBOL)==_Symbol)
           {
            count++;
            if(count >= MaxOrdersCount/2) return false;
           }

     }

   if(AccountFreeMargin()<(FreeMargin*LotsVolume))
     {
      return(false);
     }
/*   if(OrdersTotal()<MaxOrdersCount)
     {
      return true;
     }
*/
   return true;
  }
//+------------------------------------------------------------------+
uint SellStopOrder()
  {

   double Price;
   MqlTradeRequest request={0};
   MqlTradeResult result={0};

   if(!SellEnable) return 0;

   Price=SellPrice();
   if(!(Price > 0)) return 0;
   if ((BID - Price) > MAXDELTA) return 0;
   if(IsOrderAllowed(ORDER_TYPE_SELL_STOP))
     {
      PredefineRequest(request);
      ZeroMemory(result);
      DefineSellRequest(request,Price);
      //--- send a trade request 
      if(!OrderSend(request,result))
        {
         //--- write the server reply to log   
         Print(__FUNCTION__,":",result.comment);
         PrintResult(false,result,request);
         Print("Message not sent. Error: ",GetLastError());
         Print("Price: "+DoubleToString(Price,Digits()));
         Print("SL: "+DoubleToString(request.sl));
         Print("Tp: "+DoubleToString(request.tp));
        }
      if(result.retcode==10008) Print(__FUNCTION__,":",result.comment,result.bid,result.ask,result.price);
      //--- return code of the trade server reply 
     }

   return result.retcode;
  }
//------------------------------------------------------------------+

//+------------------------------------------------------------------+ 
//| Get Low for specified bar index                                  | 
//+------------------------------------------------------------------+ 
double iLow(string symbol,ENUM_TIMEFRAMES timeframe,int index)
  {
   double low=0;
   ArraySetAsSeries(Low,true);
   int copied=CopyLow(symbol,timeframe,0,Bars(symbol,timeframe),Low);
   if(copied>0 && index<copied) low=Low[index];
   return(low);
  }
//+------------------------------------------------------------------+ 
//| Get the High for specified bar index                             | 
//+------------------------------------------------------------------+ 
double iHigh(string symbol,ENUM_TIMEFRAMES timeframe,int index)
  {
   double high=0;
   ArraySetAsSeries(High,true);
   int copied=CopyHigh(symbol,timeframe,0,Bars(symbol,timeframe),High);
   if(copied>0 && index<copied) high=High[index];
   return(high);
  }
//+------------------------------------------------------------------+
double AccountFreeMargin()
  {
   return AccountInfoDouble(ACCOUNT_FREEMARGIN);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PrintResult(bool success,MqlTradeResult &result,MqlTradeRequest &request)
  {
   if(!success)
     {
      uint answer=result.retcode;
      Print("TradeLog: Trade request failed. Error = ",GetLastError());
      switch(answer)
        {
         //--- requote 
         case 10004:
           {
            Print("TRADE_RETCODE_REQUOTE");
            Print("request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- order is not accepted by the server 
         case 10006:
           {
            Print("TRADE_RETCODE_REJECT");
            Print("request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid price 
         case 10015:
           {
            Print("TRADE_RETCODE_INVALID_PRICE");
            Print("request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid SL and/or TP 
         case 10016:
           {
            Print("TRADE_RETCODE_INVALID_STOPS");
            Print("request.sl = ",request.sl," request.tp = ",request.tp);
            Print("result.ask = ",result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid volume 
         case 10014:
           {
            Print("TRADE_RETCODE_INVALID_VOLUME");
            Print("request.volume = ",request.volume,"   result.volume = ",
                  result.volume);
            break;
           }
         //--- not enough money for a trade operation  
         case 10019:
           {
            Print("TRADE_RETCODE_NO_MONEY");
            Print("request.volume = ",request.volume,"   result.volume = ",
                  result.volume,"   result.comment = ",result.comment);
            break;
           }
         //--- some other reason, output the server response code  
         default:
           {
            Print("Other answer = ",answer);
            Print("Expiration="+TimeToString(request.expiration));
            Print("request.volume = ",request.volume);
            Print("result.comment = ",result.comment);
            Print("request.sl = ",request.sl," request.tp = ",request.tp);
            Print("result.ask = ",result.ask," result.bid = ",result.bid);
            Print("request.price = ",request.price);
           }
        }
     }
  }
//+------------------------------------------------------------------+
/*

datetime GetOrderExpirationTime()
  {
   datetime tC;

   tC=TimeCurrent()+60*OrderExpirationMinute;
   Print(TimeToString(tC));
   return tC;
  }
//+------------------------------------------------------------------+
datetime TimeToDayTime(datetime time)
  {
   MqlDateTime  stime;
   TimeToStruct(time,stime);
   stime.min=59;
   stime.hour=21;
   stime.sec=59;
   return(StructToTime(stime));
  }
//+------------------------------------------------------------------+

void TestExpir()
  {
   long j;
   datetime t1=0;
   int total= OrdersTotal();
   for(int i=0;i<total;i++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(OrderGetTicket(i)==0) continue;
      j=OrderGetInteger(ORDER_TIME_EXPIRATION);
      t1=(datetime)j;
      Print(OrderGetInteger(ORDER_TYPE_TIME));  //1
      Print(TimeToString(t1));  //2017.03.27 00:00
      MqlDateTime  stime;
      TimeToStruct(t1,stime);
      Print(stime.sec);

     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TestOrder()
  {

   MqlTradeRequest request={0};
   MqlTradeResult result={0};
   double    Price;

   Price=BuyPrice();
   Print(DoubleToString(Price));

   if(!(Price > 0)) return;

   request.type_time=ORDER_TIME_DAY;

   request.expiration=TimeToDayTime(TimeCurrent());//(datetime)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_TIME));
   request.action=TRADE_ACTION_PENDING;         // setting a pending order 
   request.magic=1;                  // ORDER_MAGIC 
   request.symbol=_Symbol;                      // symbol 
   request.volume=LotsVolume;                          // volume in 0.1 lots 
                                                       //   request.sl=Price-SL*_Point-SPRED;                                // Stop Loss is not specified 
//   request.tp=Price+TPX*SL*_Point+SPRED;                                // Take Profit is not specified      
//--- form the order type 
   request.type=ORDER_TYPE_BUY_STOP;                // order type 
//--- form the price for the pending order 
   request.price=Price;  // open price 
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//      request.type_time=ORDER_TIME_SPECIFIED_DAY;//ORDER_TIME_GTC;//ORDER_TIME_DAY;//ORDER_TIME_SPECIFIED;

   if(!OrderSend(request,result))
     {
      PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
      //--- information about the operation   
      PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
      //--- zeroing the request and result values
      PrintResult(false,result,request);
     }

  }
//+------------------------------------------------------------------+

void Start()
  {
//   Start2(); return;
//--- declare and initialize the trade request and result of trade request
   MqlTradeRequest request={0};
   MqlTradeResult  result={0};
   
   ZeroMemory(request);
   ZeroMemory(result);
   double price;
//--- parameters to place a pending order
   request.action   =TRADE_ACTION_PENDING;                             // type of trade operation
   request.symbol   =_Symbol;                                         // symbol
   request.volume   =1;                                              // volume of 0.1 lot

   request.type_filling = ORDER_FILLING_RETURN;
   request.type_time = ORDER_TIME_DAY;//ORDER_TIME_SPECIFIED_DAY;//ORDER_TIME_SPECIFIED;//ORDER_TIME_DAY;//
   request.type =ORDER_TYPE_BUY_STOP;    
//   request.expiration = 0;//StringToTime("2017.11.27 23:59:00");
   request.deviation =10;
//   TimeToDayTime(TimeCurrent());
   price=ASK + 300*_Point;
   request.price=price;
   request.sl=price - 20*_Point - SPRED;
   request.tp=price + 20*_Point - SPRED;
                               // order type
//   price         =;// SymbolInfoDouble(Symbol(),SYMBOL_ASK)+offset*point; // price for opening 
   //NormalizeDouble(,(int)digits);                      // normalized opening price 

//--- send the request
   Print(request.action,  "           // Trade operation type ");
   Print(request.magic,  "            // Expert Advisor ID (magic number) ");
   Print(request.order,  "            // Order ticket ");
   Print(request.symbol,  "           // Trade symbol ");
   Print(request.volume,  "           // Requested volume for a deal in lots ");
   Print(request.price,  "            // Price ");
   Print(request.stoplimit,  "        // StopLimit level of the order ");
   Print(request.sl,  "               // Stop Loss level of the order ");
   Print(request.tp,  "               // Take Profit level of the order ");
   Print(request.deviation,  "        // Maximal possible deviation from the requested price ");
   Print(request.type,  "             // Order type ");
   Print(request.type_filling,  "     // Order execution type ");
   Print(request.type_time,  "        // Order expiration type ");
   Print(request.expiration,  "       // Order expiration time (for the orders of ORDER_TIME_SPECIFIED type) ");
   Print(request.comment,  "          // Order comment ");
   Print(request.position,  "         // Position ticket ");
   Print(request.position_by,  "      // The ticket of an opposite position ");

   if(!OrderSend(request,result))
      PrintFormat("OrderSend error %d",GetLastError());                 // if unable to send the request, output the error code
//--- information about the operation
   PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
   PrintResult(false, result, request);
  }

void Start2() {

   CTrade t;
   
   
   if (!t.OrderOpen(_Symbol, ORDER_TYPE_BUY_STOP, 1, 0, ASK+100*_Point, 0, 0)) {
      Print("2");
   }   else {
      Print(TimeToString(t.RequestExpiration()));
//      Print(t.
      }
}
void WR()
  {

   string terminal_data_path=TerminalInfoString(TERMINAL_DATA_PATH);
   string filename="fr.csv";
   int filehandle=FileOpen(filename,FILE_WRITE|FILE_CSV);
   if(filehandle<0)
     {
      Print("Failed to open the file by the absolute path ");
      Print("Error code ",GetLastError());
     }

//--- correct way of working in the "file sandbox" 
   ResetLastError();
   if(filehandle!=INVALID_HANDLE)
     {

      //      MqlBookInfo priceArray[];
      bool getBook=MarketBookGet(NULL,priceArray);
      if(getBook)
        {
         int size=ArraySize(priceArray);
         Print("MarketBookInfo for ",_Symbol);
         for(int i=0;i<size;i++)
           {
            FileWrite(filehandle,i,priceArray[i].price,priceArray[i].volume,priceArray[i].type);

           }
         FileClose(filehandle);
         Print("FileOpen OK");

        }
      else
        {
         Print("Could not get contents of the symbol DOM ",Symbol());
        }

     }
   else Print("Operation FileOpen failed, error ",GetLastError());

   return;
  }
//+------------------------------------------------------------------+

*/

void PredefineRequest(MqlTradeRequest &request,ENUM_TRADE_REQUEST_ACTIONS action=TRADE_ACTION_PENDING)
  {
   ZeroMemory(request);
   request.type_time=ORDER_TIME_DAY;
   request.expiration=0;
   request.action=action;
   request.magic=0;                  // ORDER_MAGIC 
   request.symbol=_Symbol;                      // symbol 
   request.volume=LotsVolume;                          // volume in lots 
//--- form the order type 
   request.type_filling=ORDER_FILLING_RETURN;
   request.deviation=SLIPPAGE;
   request.magic=MAGIC;
   request.comment="BT";

  }
//+------------------------------------------------------------------+

void DefineSellRequest(MqlTradeRequest &request,double Price)
  {
   request.sl=Price+SL*_Point+SPRED;
   request.tp=Price-TPX*SL*_Point-SPRED;
   request.price=Price;  // open price 
   request.type=ORDER_TYPE_SELL_STOP;                // order type 

  }
//+------------------------------------------------------------------+

void DefineBuyRequest(MqlTradeRequest &request,double Price)
  {
   request.type=ORDER_TYPE_BUY_STOP;                // order type 
   request.sl=Price-SL*_Point-SPRED;                                // Stop Loss is not specified 
   request.tp=Price+TPX*SL*_Point+SPRED;                                // Take Profit is not specified      
   request.price=Price;  // open price 

  }
//+------------------------------------------------------------------+
void DefineDeleteRequest(MqlTradeRequest &request,ulong tiket)
  {
   ZeroMemory(request);
   request.action=TRADE_ACTION_REMOVE;
   request.order=tiket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RemoveAll()
  {
   MqlTradeRequest request={0};
   MqlTradeResult result={0};
   ulong tiket;
   int total;
   total=OrdersTotal();
   for(int i=0;i<total;i++)
     {
      tiket=OrderGetTicket(i);
      if(tiket==0) continue;

      if(IsItMyOrder())
         if(OrderGetInteger(ORDER_STATE)==ORDER_STATE_PLACED)
           {
            DefineDeleteRequest(request,tiket);
            ZeroMemory(result);
            if(!OrderSend(request,result))
              {
               PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
               PrintResult(false,result,request);
              }
           }
     }
  }
//+------------------------------------------------------------------+
bool IsItMyOrder()
  {
   if(OrderGetInteger(ORDER_MAGIC)==MAGIC)
      if(OrderGetString(ORDER_SYMBOL)==_Symbol)
         return true;

   return false;
  }
//+------------------------------------------------------------------+

void CheckOrders()
  {
   int total;
   ulong tiket;
   double price,tp,sl;
   MqlTradeRequest request={0};
   MqlTradeResult result={0};
   bool NeedChange;
   total=PositionsTotal();

//   Print("PositionsTotal() ",PositionsTotal(),"-",total);
   for(int i=0;i<total;i++)

     {

      if(!PositionSelect(_Symbol)) continue;

      if(PositionGetInteger(POSITION_MAGIC)==MAGIC)
         if(OrderTimeExpired())
           {
            //       Print("PositionGetInteger(POSITION_MAGIC)",PositionGetInteger(POSITION_MAGIC));
            NeedChange=false;
            price=PositionGetDouble(POSITION_PRICE_OPEN);
            tp=PositionGetDouble(POSITION_TP);
            sl= PositionGetDouble(POSITION_SL);
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
              {
               if(MathAbs(tp -(price+SPRED+MINTP))>ACCURACY)
                 {
                  tp=price+SPRED+MINTP;
                  NeedChange=true;
                 }
              }
            else
              {
               if(MathAbs(tp -(price-SPRED-MINTP))>ACCURACY)
                 {
                  tp=price-SPRED-MINTP;
                  NeedChange=true;
                 }
              }
            if(NeedChange)
              {
               tiket=PositionGetInteger(POSITION_TICKET);
               PredefineRequest(request,TRADE_ACTION_SLTP);
               ZeroMemory(result);
               request.order=tiket;
               request.tp = tp;
               request.sl = sl;

               if(!OrderSend(request,result))
                 {
                  PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
                  PrintResult(false,result,request);
                 }
              }

           }

     }
  }
//+------------------------------------------------------------------+
bool OrderTimeExpired()
  {
   datetime t;

   PositionGetInteger(POSITION_TIME,t);
   if((TimeCurrent()-t)>TIMEDELAY)
      return true;

   return false;
  }
//+------------------------------------------------------------------+
