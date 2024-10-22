#property link          "https://www.earnforex.com/metatrader-indicators/supertrend/"
#property version       "1.03"
#property strict
#property copyright     "EarnForex.com - 2019-2023"
#property description   "This indicator shows the trend using the ATR and an ATR multiplier."
#property description   " "
#property description   "WARNING: You use this indicator at your own risk."
#property description   "The creator of these indicator cannot be held responsible for damage or loss."
#property description   " "
#property description   "Find more on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrGreen
#property indicator_width1 2
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrRed
#property indicator_width2 2
#property indicator_type3 DRAW_NONE
#property indicator_type4 DRAW_NONE
#property indicator_type5 DRAW_NONE

double TrendUp[], TrendDown[];
double up[], dn[], trend[];

enum enum_candle_to_check
{
    Current,
    Previous
};

int AlertVariable;
int LastAlertDirection = 2; // Signal that was alerted on previous alert. "2" because "0", "1", and "-1" are taken for signals.

input string IndicatorName = "SPRTRND"; // Objects prefix (used to draw objects)
input double ATRMultiplier = 2.0;       // ATR multiplier
input int ATRPeriod = 100;              // ATR period
input int ATRMaxBars = 1000;            // Max bars
input int Shift = 0;                    // Indicator shift, positive or negative
input string Comment = "===================="; // Notification Options
input bool EnableNotify = false;               // Enable notifications feature
input bool SendAlert = false;                  // Send alert notification
input bool SendApp = false;                    // Send push-notification to mobile
input bool SendEmail = false;                  // Send notification via email
input enum_candle_to_check TriggerCandle = Previous;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    SetIndexBuffer(0, TrendUp, INDICATOR_DATA);
    SetIndexBuffer(1, TrendDown, INDICATOR_DATA);
    SetIndexBuffer(2, up, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, dn, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, trend, INDICATOR_CALCULATIONS);

    SetIndexShift(0, Shift);
    SetIndexShift(1, Shift);
    SetIndexShift(2, Shift);
    SetIndexShift(3, Shift);
    SetIndexShift(4, Shift);
    
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    ArraySetAsSeries(TrendUp, true);
    ArraySetAsSeries(TrendDown, true);
    ArraySetAsSeries(up, true);
    ArraySetAsSeries(dn, true);
    ArraySetAsSeries(trend, true);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate (const int rates_total,
                 const int prev_calculated,
                 const datetime& time[],
                 const double& open[],
                 const double& high[],
                 const double& low[],
                 const double& close[],
                 const long& tick_volume[],
                 const long& volume[],
                 const int& spread[])
{
    // int counted_bars = IndicatorCounted();
    int counted_bars = 0;
    if (prev_calculated > 0) counted_bars = prev_calculated - 1;

    if (counted_bars < 0) return -1;
    if (counted_bars > 0) counted_bars--;
    int limit = rates_total - counted_bars;
    if (limit > ATRMaxBars)
    {
        limit = ATRMaxBars;
        if (rates_total < ATRMaxBars + 2 + ATRPeriod) limit = rates_total - 2 - ATRPeriod;
        if (limit <= 0)
        {
            Print("Need more historical data to calculate Supertrend.");
            return 0;
        }
    }
    if (limit > rates_total - 2 - ATRPeriod) limit = rates_total - 2 - ATRPeriod;

    for (int i = limit; i >= 0; i--)
    {
        bool flag, flagh;
        TrendUp[i] = EMPTY_VALUE;
        TrendDown[i] = EMPTY_VALUE;
        double atr = iATR(Symbol(), Period(), ATRPeriod, i);
        double medianPrice = (High[i] + Low[i]) / 2;
        up[i] = medianPrice + ATRMultiplier * atr;
        dn[i] = medianPrice - ATRMultiplier * atr;

        trend[i] = 1;

        int changeOfTrend = 0;

        if (Close[i] > up[i + 1])
        {
            trend[i] = 1;
            if (trend[i + 1] == -1) changeOfTrend = 1;
        }
        else if (Close[i] < dn[i + 1])
        {
            trend[i] = -1;
            if (trend[i + 1] == 1) changeOfTrend = 1;
        }
        else if (trend[i + 1] == 1)
        {
            trend[i] = 1;
            changeOfTrend = 0;
        }
        else if (trend[i + 1] == -1)
        {
            trend[i] = -1;
            changeOfTrend = 0;
        }

        if ((trend[i] < 0) && (trend[i + 1] > 0))
        {
            flag = true;
        }
        else
        {
            flag = false;
        }

        if ((trend[i] > 0) && (trend[i + 1] < 0))
        {
            flagh = true;
        }
        else
        {
            flagh = false;
        }

        if ((trend[i] > 0) && (dn[i] < dn[i + 1]))
        {
            dn[i] = dn[i + 1];
        }
        else if ((trend[i] < 0) && (up[i] > up[i + 1]))
        {
            up[i] = up[i + 1];
        }

        if (flag)
        {
            up[i] = medianPrice + ATRMultiplier * atr;
        }
        else if (flagh)
        {
            dn[i] = medianPrice - ATRMultiplier * atr;
        }

        if (trend[i] == 1)
        {
            TrendUp[i] = dn[i];
            if (changeOfTrend == 1)
            {
                TrendUp[i + 1] = TrendDown[i + 1];
                changeOfTrend = 0;
            }
        }
        else if (trend[i] == -1)
        {
            TrendDown[i] = up[i];
            if (changeOfTrend == 1)
            {
                TrendDown[i + 1] = TrendUp[i + 1];
                changeOfTrend = 0;
            }
        }
    }
    Notify();
    return rates_total;
}

//+------------------------------------------------------------------+
//| Alert processing.                                                |
//+------------------------------------------------------------------+
void Notify()
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    bool UpTrend = false, DownTrend = false;
    if (trend[TriggerCandle] == 1) UpTrend = true;
    else if (trend[TriggerCandle] == -1) DownTrend = true;
    if (UpTrend) AlertVariable = 1;
    if (DownTrend) AlertVariable = -1;
    if ((!UpTrend) && (!DownTrend)) AlertVariable = 0;
    if (LastAlertDirection == 2)
    {
        LastAlertDirection = AlertVariable; // Avoid initial alert when just attaching the indicator to the chart.
        return;
    }
    if (AlertVariable == LastAlertDirection) return; // Avoid alerting about the same signal.
    LastAlertDirection = AlertVariable;
    string TrendString = "No trend";
    if (UpTrend) TrendString = "Uptrend";
    if (DownTrend) TrendString = "Downtrend";
    if (SendAlert)
    {
        string AlertText = IndicatorName + " - " + Symbol() + " Notification: ";
        if ((!UpTrend) && (!DownTrend)) AlertText += "The Pair is NOT Trending.";
        else AlertText += "The Pair is currently in a Trend - " + TrendString + ".";
        Alert(AlertText);
    }
    if (SendEmail)
    {
        string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
        string EmailBody = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\r\n\r\n" + IndicatorName + " Notification for " + Symbol() + "\r\n\r\n";
        if ((!UpTrend) && (!DownTrend)) EmailBody += "The Pair is NOT Trending.";
        else EmailBody += "The Pair is currently in a Trend - " + TrendString + ".";
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()) + ".");
    }
    if (SendApp)
    {
        string AppText = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + " - " + IndicatorName + " - " + Symbol() + " - ";
        if ((!UpTrend) && (!DownTrend)) AppText += "The Pair is NOT Trending.";
        else AppText += "The Pair is currently in a Trend - " + TrendString + ".";
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()) + ".");
    }
}
//+------------------------------------------------------------------+