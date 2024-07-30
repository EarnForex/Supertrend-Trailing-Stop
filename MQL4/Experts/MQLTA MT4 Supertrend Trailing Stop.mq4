#property link          "https://www.earnforex.com/metatrader-expert-advisors/supertrend-trailing-stop/"
#property version       "1.04"
#property strict
#property copyright     "EarnForex.com - 2019-2024"
#property description   "This expert advisor will trail the stop-loss following the Supertrend line."
#property description   ""
#property description   "WARNING: There is no guarantee that this expert advisor will work as intended. Use at your own risk."
#property description   ""
#property description   "Find more on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#include <MQLTA ErrorHandling.mqh>
#include <MQLTA Utils.mqh>

enum ENUM_CONSIDER
{
    All = -1,       // ALL ORDERS
    Buy = OP_BUY,   // BUY ONLY
    Sell = OP_SELL, // SELL ONLY
};

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0, // CURRENT CANDLE
    CLOSED_CANDLE = 1   // PREVIOUS CANDLE
};

input string Comment_1 = "====================";  // Expert Advisor Settings
input string SupertrendFileName = "MQLTA MT4 Supertrend Line"; // Supertrend Indicator's File Name
input double ATRMultiplier = 2.0;                 // ATR Multiplier
input int ATRPeriod = 100;                        // ATR Period
input ENUM_TIMEFRAMES StopATRTimeframe = PERIOD_CURRENT; // ATR Supertrend Timeframe Calculation
input ENUM_CANDLE_TO_CHECK CandleToCheck = CURRENT_CANDLE; // Candle To Use For Supertrend Value
input int ProfitPoints = 0;                       // Profit Points to Start Trailing (0 = ignore profit)
input string Comment_2 = "====================";         // Orders Filtering Options
input bool OnlyCurrentSymbol = true;                     // Apply To Current Symbol Only
input ENUM_CONSIDER OnlyType = All;                      // Apply To
input bool UseMagic = false;                             // Filter By Magic Number
input int MagicNumber = 0;                               // Magic Number (if above is true)
input bool UseComment = false;                           // Filter By Comment
input string CommentFilter = "";                         // Comment (if above is true)
input bool EnableTrailingParam = false;           // Enable Trailing Stop
input string Comment_3 = "====================";  // Notification Options
input bool EnableNotify = false;                  // Enable Notifications feature
input bool SendAlert = true;                      // Send Alert Notification
input bool SendApp = true;                        // Send Notification to Mobile
input bool SendEmail = true;                      // Send Notification via Email
input string Comment_3a = "===================="; // Graphical Window
input bool ShowPanel = true;                      // Show Graphical Panel
input string ExpertName = "MQLTA-STTS";           // Expert Name (to name the objects)
input int Xoff = 20;                              // Horizontal spacing for the control panel
input int Yoff = 20;                              // Vertical spacing for the control panel
input ENUM_BASE_CORNER ChartCorner = CORNER_LEFT_UPPER; // Chart Corner
input int FontSize = 10;                         // Font Size
input string Comment_3b = "===================="; // TS Price Label
input bool ShowLabel = true;                      // Show TS Price Label
input color PriceLabelColor = clrRed;             // Price Label Color
input int PriceLabelSize = 3;                     // Price Label Size

int OrderModRetry = 5;
double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovY, PanelLabX, PanelLabY, PanelRecX;
bool EnableTrailing = EnableTrailingParam;
bool TS_Label_Should_Be_Deleted;

int OnInit()
{
    CleanPanel();
    EnableTrailing = EnableTrailingParam;

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (int)MathRound(150 * DPIScale);
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    if (ShowPanel) DrawPanel();
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    CleanPanel();
}

void OnTick()
{
    TS_Label_Should_Be_Deleted = true;
    if (EnableTrailing) TrailingStop();
    if (ShowPanel) DrawPanel();
    if (TS_Label_Should_Be_Deleted)
    {
        if ((ShowLabel) && (ObjectFind(0, ExpertName + "-PRICELABEL") >= 0))
        {
            ObjectDelete(0, ExpertName + "-PRICELABEL");
        }
    }
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        if (sparam == PanelEnableDisable)
        {
            ChangeTrailingEnabled();
        }
    }
    else if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27)
        {
            if (MessageBox("Are you sure you want to close the EA?", "EXIT ?", MB_YESNO) == IDYES)
            {
                ExpertRemove();
            }
        }
    }
}

double GetSupertrend(string Instrument = "", int Timeframe = 0)
{
    double Supertrend = 0;
    
    if (Instrument == "") Instrument = Symbol();
    if (Timeframe == 0) Timeframe = Period();

    double tu = iCustom(Instrument, Timeframe, SupertrendFileName, "", ATRMultiplier, ATRPeriod, 0, CandleToCheck); // EMPTY_VALUE or price.
    double td = iCustom(Instrument, Timeframe, SupertrendFileName, "", ATRMultiplier, ATRPeriod, 1, CandleToCheck); // EMPTY_VALUE or price.
    if (tu != EMPTY_VALUE) Supertrend = tu;
    else if (td != EMPTY_VALUE) Supertrend = td;

    if (Supertrend == 0)
    {
        Print("Failed to get the Supertrend value.");
        return 0;
    }
    
    return NormalizeDouble(Supertrend, (int)MarketInfo(Instrument, MODE_DIGITS));
}

void TrailingStop()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES ) == false)
        {
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - Unable to select the order - ", Error);
            Print("ERROR - ", ErrorText);
            break;
        }
        if ((OnlyCurrentSymbol) && (OrderSymbol() != Symbol())) continue;
        if ((UseMagic) && (OrderMagicNumber() != MagicNumber)) continue;
        if ((UseComment) && (StringFind(OrderComment(), CommentFilter) < 0)) continue;
        if ((OnlyType != All) && (OrderType() != OnlyType)) continue;

        string Instrument = OrderSymbol();
        double PointSymbol = MarketInfo(Instrument, MODE_POINT);
        double Supertrend = GetSupertrend(Instrument, StopATRTimeframe);

        if (Supertrend == 0) return;

        if ((ShowLabel) && (Instrument == Symbol()))
        {
            DrawPriceLabel(Supertrend);
            TS_Label_Should_Be_Deleted = false;
        }
        if (ProfitPoints > 0) // Check if there is enough profit points on this position.
        {
            if (((OrderType() == OP_BUY)  && ((OrderClosePrice() - OrderOpenPrice()) / PointSymbol < ProfitPoints)) ||
                ((OrderType() == OP_SELL) && ((OrderOpenPrice() - OrderClosePrice()) / PointSymbol < ProfitPoints))) continue;
        }

        double NewSL = 0;
        double NewTP = 0;

        int eDigits = (int)MarketInfo(Instrument, MODE_DIGITS);
        double SLPrice = NormalizeDouble(OrderStopLoss(), eDigits);
        double TPPrice = NormalizeDouble(OrderTakeProfit(), eDigits);
        double Spread = MarketInfo(Instrument, MODE_SPREAD) * MarketInfo(Instrument, MODE_POINT);
        double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);

        // Adjust for tick size granularity.
        double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
        if (TickSize > 0)
        {
            Supertrend = NormalizeDouble(MathRound(Supertrend / TickSize) * TickSize, eDigits);
        }
        if ((OrderType() == OP_BUY) && (Supertrend < MarketInfo(Instrument, MODE_BID) - StopLevel))
        {
            NewSL = NormalizeDouble(Supertrend, eDigits);
            NewTP = TPPrice;
            if (NewSL > SLPrice + StopLevel)
            {
                ModifyOrder(OrderTicket(), OrderOpenPrice(), NewSL, NewTP);
            }
        }
        else if ((OrderType() == OP_SELL) && (Supertrend > MarketInfo(Instrument, MODE_ASK) + StopLevel))
        {
            NewSL = NormalizeDouble(Supertrend, eDigits);
            NewTP = TPPrice;
            if ((NewSL < SLPrice) || (SLPrice == 0))
            {
                ModifyOrder(OrderTicket(), OrderOpenPrice(), NewSL, NewTP);
            }
        }
    }
}

void ModifyOrder(int Ticket, double OpenPrice, double SLPrice, double TPPrice)
{
    if (OrderSelect(Ticket, SELECT_BY_TICKET) == false)
    {
        int Error = GetLastError();
        string ErrorText = GetLastErrorText(Error);
        Print("ERROR - SELECT TICKET - error selecting order ", Ticket, " return error: ", Error);
        return;
    }
    int eDigits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
    SLPrice = NormalizeDouble(SLPrice, eDigits);
    TPPrice = NormalizeDouble(TPPrice, eDigits);
    for (int i = 1; i <= OrderModRetry; i++)
    {
        bool res = OrderModify(Ticket, OpenPrice, SLPrice, TPPrice, 0, clrBlue);
        if (res)
        {
            Print("TRADE - UPDATE SUCCESS - Order ", Ticket, " new stop-loss ", SLPrice, " new take-profit ", TPPrice);
            NotifyStopLossUpdate(Ticket, SLPrice, OrderSymbol());
            break;
        }
        else
        {
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - UPDATE FAILED - error modifying order ", Ticket, " in ", OrderSymbol(), " return error: ", Error, " Open=", OpenPrice,
                  " Old SL=", OrderStopLoss(), " Old TP=", OrderTakeProfit(),
                  " New SL=", SLPrice, " New TP=", TPPrice, " Bid=", MarketInfo(OrderSymbol(), MODE_BID), " Ask=", MarketInfo(OrderSymbol(), MODE_ASK));
            Print("ERROR - ", ErrorText);
        }
    }
}

void NotifyStopLossUpdate(int OrderNumber, double SLPrice, string symbol)
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    string EmailSubject = ExpertName + " " + symbol + " Notification ";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + ExpertName + " Notification for " + symbol + "\r\n";
    EmailBody += "Stop-loss for order " + IntegerToString(OrderNumber) + " moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS));
    string AlertText = ExpertName + " - " + symbol + " - stop-loss for order " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS));
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + ExpertName + " - " + symbol + " - ";
    AppText += "stop-loss for order: " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS)) + "";
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
}

string PanelBase = ExpertName + "-P-BAS";
string PanelLabel = ExpertName + "-P-LAB";
string PanelEnableDisable = ExpertName + "-P-ENADIS";
void DrawPanel()
{
    int SignX = 1;
    if ((ChartCorner == CORNER_RIGHT_UPPER) || (ChartCorner == CORNER_RIGHT_LOWER))
    {
        SignX = -1; // Correction for right-side panel position.
    }
    string PanelText = "MQLTA STTS";
    string PanelToolTip = "Supertrend Trailing Stop-Loss by EarnForex.com";
    int Rows = 1;
    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_CORNER, ChartCorner);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, FontSize);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2 * SignX,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             PanelToolTip,
             ALIGN_CENTER,
             "Consolas",
             PanelText,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);

    string EnableDisabledText = "";
    color EnableDisabledColor = clrNavy;
    color EnableDisabledBack = clrKhaki;
    if (EnableTrailing)
    {
        EnableDisabledText = "TRAILING ENABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkGreen;
    }
    else
    {
        EnableDisabledText = "TRAILING DISABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkRed;
    }

    DrawEdit(PanelEnableDisable,
             Xoff + 2,
             Yoff + (PanelMovY + 1)*Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             8,
             "Click to Enable or Disable the Trailing Stop Feature",
             ALIGN_CENTER,
             "Consolas",
             EnableDisabledText,
             false,
             EnableDisabledColor,
             EnableDisabledBack,
             clrBlack);

    Rows++;

    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
}

void CleanPanel()
{
    ObjectsDeleteAll(0, ExpertName + "-");
}

void ChangeTrailingEnabled()
{
    if (EnableTrailing == false)
    {
        if ((!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) && (!MQLInfoInteger(MQL_TRADE_ALLOWED)))
        {
            MessageBox("Please enable Live Trading in the EA's options and Automated Trading in the platform's options.", "WARNING", MB_OK);
        }
        else if (!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
            MessageBox("Please enable Live Trading in the EA's options.", "WARNING", MB_OK);
        }
        else if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
            MessageBox("Please enable Automated Trading in the platform's options.", "WARNING", MB_OK);
        }
        else EnableTrailing = true;
    }
    else EnableTrailing = false;
    DrawPanel();
}

void DrawPriceLabel(double supertrend_price)
{
    string PriceLabel = ExpertName + "-PRICELABEL";
    if (ObjectFind(0, PriceLabel) < 0)
    {
        ObjectCreate(0, PriceLabel, OBJ_ARROW_LEFT_PRICE, 0, iTime(Symbol(), Period(), CandleToCheck), supertrend_price);
        ObjectSetInteger(0, PriceLabel, OBJPROP_COLOR, PriceLabelColor);
        ObjectSetInteger(0, PriceLabel, OBJPROP_WIDTH, PriceLabelSize);
        ObjectSetInteger(0, PriceLabel, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, PriceLabel, OBJPROP_HIDDEN, true);
    }
    else
    {
        ObjectMove(0, PriceLabel, 0, iTime(Symbol(), Period(), CandleToCheck), supertrend_price);
    }
}
//+------------------------------------------------------------------+