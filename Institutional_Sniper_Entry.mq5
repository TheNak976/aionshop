//+------------------------------------------------------------------+
//| Institutional Sniper Entry.mq5 |
//| Copyright 2025, Expert Advisor |
//| Institutional Logic & SMC |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Institutional Sniper"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot Settings for Entry Signals
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//+------------------------------------------------------------------+
//| INPUT PARAMETERS |
//+------------------------------------------------------------------+
input group "--- Institutional Settings ---"
input int      InpSwingLength       = 10;          // Swing Lookback (Fractal Depth)
input double   InpDisplacementATR   = 1.5;         // Min Impulse Size (x ATR) to confirm Moves
input ENUM_TIMEFRAMES InpHTF        = PERIOD_H4;   // HTF for Trend Alignment (Filter)

input group "--- Order Blocks (OB) ---"
input bool     InpDrawOB            = true;        // Draw Order Blocks?
input color    InpColorBullishOB    = clrGreen;    // Color Bullish OB (Demand)
input color    InpColorBearishOB    = clrCrimson;  // Color Bearish OB (Supply)
input int      InpOBTransparency    = 180;         // Transparency (0-255)
input bool     InpRemoveMitigated   = true;        // Remove OB after Mitigation?

input group "--- Liquidity & Entry ---"
input bool     InpShowSweeps        = true;        // Show Liquidity Sweeps (Stop Hunts)
input bool     InpFilterByHTF       = true;        // Filter entries by HTF Trend?

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES |
//+------------------------------------------------------------------+
// Indicator Buffers
double BuyBuffer[];
double SellBuffer[];

// Handles
int atrHandle;
int maHandle;

// Structure for Order Block Management
struct OrderBlock {
   string   name;
   datetime time;
   double   top;
   double   bottom;
   int      type; // 1 = Bullish, -1 = Bearish
   bool     mitigated;
};
OrderBlock ob_list[];

//+------------------------------------------------------------------+
//| Custom Indicator Initialization Function |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Indicator Buffers Mapping
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down Arrow
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

   // 2. Initialize Indicators
   atrHandle = iATR(_Symbol, _Period, 14);
   if(atrHandle == INVALID_HANDLE) {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }
   
   // Initialize MA handle for HTF trend
   int ratio = PeriodSeconds(InpHTF) / PeriodSeconds();
   if(ratio < 1) ratio = 1;
   int maPeriod = 50 * ratio;
   maHandle = iMA(_Symbol, _Period, maPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE) {
      Print("Failed to create MA handle");
      return(INIT_FAILED);
   }

   // 3. Name
   IndicatorSetString(INDICATOR_SHORTNAME, "Inst. Sniper Entry");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization Function |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup Objects
   ObjectsDeleteAll(0, "InstOB_");
   ObjectsDeleteAll(0, "InstSweep_");
   IndicatorRelease(atrHandle);
   IndicatorRelease(maHandle);
}

//+------------------------------------------------------------------+
//| Custom Indicator Iteration Function |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // --- Data Validation ---
   if(rates_total < InpSwingLength * 2 + 10) return 0;
   
   // --- Array Set As Series (Reverse indexing: 0 is current candle) ---
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);

   // --- ATR Buffer ---
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, rates_total, atr) <= 0) return 0;
   
   // --- MA Buffer for HTF Trend ---
   double maBuf[];
   ArraySetAsSeries(maBuf, true);
   if(CopyBuffer(maHandle, 0, 0, rates_total, maBuf) <= 0) return 0;

   // --- Optimization: Calculate Limit ---
   int limit = rates_total - prev_calculated;
   if(limit > 1000 || prev_calculated == 0) limit = rates_total - InpSwingLength - 2; // Full recalc on init
   if(limit < 2) limit = 2; // Always calc last few bars

   // --- Main Loop ---
   for(int i = limit; i >= 0; i--)
   {
      // 0. Reset Signal
      BuyBuffer[i] = 0.0;
      SellBuffer[i] = 0.0;
      
      // --- LOGIC 1: HTF Trend Filter ---
      int htfTrend = GetHTFTrend(i, close, maBuf); 
      
      // --- LOGIC 2: Order Block Detection & Management ---
      if(InpDrawOB && i < rates_total - 5) {
         DetectAndDrawOB(i, open, high, low, close, atr, time);
         ManageOBMitigation(i, high, low, close);
      }
      
      // --- LOGIC 3: Liquidity Sweep + Engulfing Confirmation ---
      
      // Step A: Find closest Swing Points (Fractals) in recent history
      double swingHigh = FindSwingHigh(i + 1, InpSwingLength, high, rates_total);
      double swingLow  = FindSwingLow(i + 1, InpSwingLength, low, rates_total);
      
      bool sweepBullish = false;
      bool sweepBearish = false;
      
      // Check Bearish Sweep (Took out High but closed lower)
      if(high[i] > swingHigh && close[i] < swingHigh && swingHigh > 0) {
         if(InpShowSweeps) DrawSweepMarker(time[i], high[i], true);
         sweepBearish = true;
      }
      
      // Check Bullish Sweep (Took out Low but closed higher)
      if(low[i] < swingLow && close[i] > swingLow && swingLow > 0) {
         if(InpShowSweeps) DrawSweepMarker(time[i], low[i], false);
         sweepBullish = true;
      }
      
      // Step B: Wait for Engulfing (Confirmation)
      // Check if we have enough bars
      if(i + 1 >= rates_total) continue;
      
      // Bullish Engulfing Logic
      bool isBullishEngulfing = (close[i] > open[i]) && (close[i] > high[i+1]) && (open[i] < close[i+1]);
      // Bearish Engulfing Logic
      bool isBearishEngulfing = (close[i] < open[i]) && (close[i] < low[i+1]) && (open[i] > close[i+1]);
      
      // --- FINAL TRIGGER ---
      
      // BUY SIGNAL
      // 1. We had a Bullish Sweep (on current bar or previous bar i+1)
      bool recentBullSweep = (sweepBullish) || (i+1 < rates_total && low[i+1] < swingLow && close[i+1] > swingLow && swingLow > 0);
      
      if(isBullishEngulfing && recentBullSweep) {
         // Filter: Is volatility high enough? (Avoid noise)
         if(MathAbs(close[i]-open[i]) > atr[i] * 0.8) { 
             // HTF Filter
             if(!InpFilterByHTF || htfTrend == 1) {
                 BuyBuffer[i] = low[i] - atr[i] * 0.5;
             }
         }
      }
      
      // SELL SIGNAL
      bool recentBearSweep = (sweepBearish) || (i+1 < rates_total && high[i+1] > swingHigh && close[i+1] < swingHigh && swingHigh > 0);
      
      if(isBearishEngulfing && recentBearSweep) {
         // Filter: Is volatility high enough?
         if(MathAbs(open[i]-close[i]) > atr[i] * 0.8) {
             // HTF Filter
             if(!InpFilterByHTF || htfTrend == -1) {
                 SellBuffer[i] = high[i] + atr[i] * 0.5;
             }
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| HELPER: Detect and Draw Order Blocks |
//+------------------------------------------------------------------+
void DetectAndDrawOB(int i, const double &open[], const double &high[], const double &low[], const double &close[], const double &atr[], const datetime &time[]) {
   
   // Check bounds
   if(i + 1 >= ArraySize(open)) return;
   
   // Definition of Institutional Move: Large body relative to ATR
   double bodySize = MathAbs(close[i] - open[i]);
   bool isImpulse = bodySize > atr[i] * InpDisplacementATR;
   
   // 1. Bullish OB Creation
   // Current is strong Green candle. Previous candle (i+1) was Red (or small).
   if(isImpulse && close[i] > open[i] && close[i+1] < open[i+1]) {
      // Define OB Zone: The entire body/wick of the previous bearish candle
      double obTop = high[i+1];
      double obBot = low[i+1];
      
      // Create Object
      string name = "InstOB_Buy_" + TimeToString(time[i+1]);
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], obTop, time[i] + PeriodSeconds()*100, obBot);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorBullishOB);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true); // Background
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 0);   // No border
      }
   }
   
   // 2. Bearish OB Creation
   // Current is strong Red candle. Previous candle (i+1) was Green.
   if(isImpulse && close[i] < open[i] && close[i+1] > open[i+1]) {
      double obTop = high[i+1];
      double obBot = low[i+1];
      
      string name = "InstOB_Sell_" + TimeToString(time[i+1]);
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], obTop, time[i] + PeriodSeconds()*100, obBot);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorBearishOB);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| HELPER: Manage Mitigation (Remove/Dim touched OBs) |
//+------------------------------------------------------------------+
void ManageOBMitigation(int i, const double &high[], const double &low[], const double &close[]) {
   // Iterate over existing objects is slow in a loop, but necessary for visual mitigation logic
   // Optimisation: only run this on the LAST bar (current live candle)
   if(i > 0) return; 
   
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   for(int k = total - 1; k >= 0; k--) {
      string name = ObjectName(0, k, 0, OBJ_RECTANGLE);
      if(StringFind(name, "InstOB_") < 0) continue;
      
      double top = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double bot = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      // Ensure top is actually high
      if(bot > top) { double temp = top; top = bot; bot = temp; }
      
      datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      
      // If price touches the zone...
      // Note: We check current bar 'i' (which is 0 here)
      bool mitigated = (high[i] >= bot && low[i] <= top);
      
      if(mitigated) {
         if(InpRemoveMitigated) {
            ObjectDelete(0, name);
         } else {
             // Visual cue for mitigation (e.g. unfill)
             ObjectSetInteger(0, name, OBJPROP_FILL, false);
             ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
         }
      } else {
         // Extend Rectangle to current time + delta
         ObjectSetInteger(0, name, OBJPROP_TIME, 1, TimeCurrent() + PeriodSeconds()*10);
      }
   }
}

//+------------------------------------------------------------------+
//| HELPER: Find Swing High (Simple Fractal Logic) |
//+------------------------------------------------------------------+
double FindSwingHigh(int startIndex, int lookback, const double &high[], int rates_total) {
   // Searches for the highest high in [startIndex, startIndex+lookback]
   // That high must be a fractal pivot (higher than neighbors)
   for(int k = startIndex; k < startIndex + lookback; k++) {
       // Check boundary
       if(k+2 >= rates_total) break;
       // Fractal check: Middle bar (k) > 2 bars left & 2 bars right
       bool isPivot = (high[k] > high[k-1] && high[k] > high[k+1] && high[k] > high[k-2] && high[k] > high[k+2]);
       if(isPivot) return high[k];
   }
   return -1;
}

double FindSwingLow(int startIndex, int lookback, const double &low[], int rates_total) {
   for(int k = startIndex; k < startIndex + lookback; k++) {
       if(k+2 >= rates_total) break;
       bool isPivot = (low[k] < low[k-1] && low[k] < low[k+1] && low[k] < low[k-2] && low[k] < low[k+2]);
       if(isPivot) return low[k];
   }
   return -1;
}

//+------------------------------------------------------------------+
//| HELPER: Get HTF Trend Direction (1=Bull, -1=Bear, 0=Flat) |
//+------------------------------------------------------------------+
int GetHTFTrend(int i, const double &close[], const double &maBuf[]) {
   // Simple moving average check on HTF
   // Using pre-calculated MA buffer
   
   if(i >= ArraySize(close) || i >= ArraySize(maBuf)) return 0;
   
   // If current Close > MA => Bullish
   if(close[i] > maBuf[i]) return 1;
   else return -1;
}

//+------------------------------------------------------------------+
//| HELPER: Draw Sweep Marker |
//+------------------------------------------------------------------+
void DrawSweepMarker(datetime t, double price, bool isHigh) {
   string name = "InstSweep_" + TimeToString(t);
   if(ObjectFind(0, name) >= 0) return;
   
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, "x");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isHigh? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, isHigh? clrRed : clrLime);
}
