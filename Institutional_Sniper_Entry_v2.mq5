//+------------------------------------------------------------------+
//| Institutional Sniper Entry v2.mq5 |
//| Copyright 2025, Expert Advisor |
//| Institutional Logic & SMC - Enhanced Version |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Institutional Sniper"
#property link      ""
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot Settings for Entry Signals
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

#property indicator_label3  "Swing High"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrOrange
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "Swing Low"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//+------------------------------------------------------------------+
//| INPUT PARAMETERS |
//+------------------------------------------------------------------+
input group "=== Institutional Settings ==="
input int      InpSwingLength       = 5;           // Swing Lookback (Fractal Depth)
input double   InpDisplacementATR   = 1.2;         // Min Impulse Size (x ATR)
input int      InpATRPeriod         = 14;          // ATR Period
input bool     InpFilterByHTF       = false;       // Filter by HTF Trend?
input ENUM_TIMEFRAMES InpHTF        = PERIOD_H4;   // HTF for Trend Alignment

input group "=== Order Blocks (OB) ==="
input bool     InpDrawOB            = true;        // Draw Order Blocks?
input color    InpColorBullishOB    = clrDarkGreen;    // Color Bullish OB
input color    InpColorBearishOB    = clrDarkRed;      // Color Bearish OB
input bool     InpRemoveMitigated   = false;       // Remove OB after Mitigation?

input group "=== Liquidity & Entry ==="
input bool     InpShowSweeps        = true;        // Show Liquidity Sweeps
input bool     InpShowSwingPoints   = true;        // Show Swing High/Low
input double   InpMinCandleSize     = 0.3;         // Min Candle Size (x ATR)
input bool     InpRequireEngulfing  = false;       // Require Engulfing Pattern?

input group "=== Performance ==="
input int      InpMaxBarsBack       = 500;         // Max Bars to Calculate

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES |
//+------------------------------------------------------------------+
// Indicator Buffers
double BuyBuffer[];
double SellBuffer[];
double SwingHighBuffer[];
double SwingLowBuffer[];

// Handles
int atrHandle;
int maHandle;

// Performance tracking
datetime lastOBCheck = 0;
int calculationCount = 0;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization Function |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Indicator Buffers Mapping
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SwingHighBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SwingLowBuffer, INDICATOR_DATA);
   
   // Arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down Arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 159); // Small circle
   PlotIndexSetInteger(3, PLOT_ARROW, 159); // Small circle
   
   // Empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   
   // Initialize arrays
   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);
   ArraySetAsSeries(SwingHighBuffer, true);
   ArraySetAsSeries(SwingLowBuffer, true);

   // 2. Initialize Indicators
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE) {
      Print("❌ Failed to create ATR handle");
      return(INIT_FAILED);
   }
   
   // Initialize MA handle for HTF trend (only if needed)
   if(InpFilterByHTF) {
      int ratio = PeriodSeconds(InpHTF) / PeriodSeconds();
      if(ratio < 1) ratio = 1;
      int maPeriod = MathMin(50 * ratio, 500); // Cap at 500
      maHandle = iMA(_Symbol, _Period, maPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(maHandle == INVALID_HANDLE) {
         Print("❌ Failed to create MA handle");
         return(INIT_FAILED);
      }
   }

   // 3. Indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Institutional Sniper v2.0");
   
   Print("✅ Institutional Sniper Entry v2.0 initialized successfully");
   Print("📊 Settings: SwingLength=", InpSwingLength, " ATR=", InpATRPeriod, " Displacement=", InpDisplacementATR);

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
   
   // Release handles
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
   
   Print("🔄 Indicator removed. Calculations performed: ", calculationCount);
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
   int minBars = InpSwingLength * 3 + 10;
   if(rates_total < minBars) {
      Print("⚠️ Not enough bars. Need ", minBars, ", have ", rates_total);
      return 0;
   }
   
   // --- Array Set As Series ---
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // --- ATR Buffer ---
   double atr[];
   ArraySetAsSeries(atr, true);
   int atrCopied = CopyBuffer(atrHandle, 0, 0, rates_total, atr);
   if(atrCopied <= 0) {
      Print("⚠️ Failed to copy ATR buffer");
      return prev_calculated;
   }
   
   // --- MA Buffer for HTF Trend (if enabled) ---
   double maBuf[];
   if(InpFilterByHTF) {
      ArraySetAsSeries(maBuf, true);
      int maCopied = CopyBuffer(maHandle, 0, 0, rates_total, maBuf);
      if(maCopied <= 0) {
         Print("⚠️ Failed to copy MA buffer");
         return prev_calculated;
      }
   }

   // --- Calculate Limit (Optimized) ---
   int limit;
   if(prev_calculated == 0) {
      // First calculation
      limit = MathMin(rates_total - minBars, InpMaxBarsBack);
      Print("🔄 First calculation: processing ", limit, " bars");
   } else {
      // Incremental calculation
      limit = rates_total - prev_calculated + 1;
      if(limit > 100) limit = 100; // Cap incremental updates
   }
   
   if(limit < 1) limit = 1;

   // --- Main Loop ---
   for(int i = limit; i >= 0; i--)
   {
      calculationCount++;
      
      // 0. Reset Signals
      BuyBuffer[i] = 0.0;
      SellBuffer[i] = 0.0;
      SwingHighBuffer[i] = 0.0;
      SwingLowBuffer[i] = 0.0;
      
      // Safety check
      if(i + InpSwingLength + 3 >= rates_total) continue;
      if(atr[i] <= 0) continue;
      
      // --- STEP 1: Find Swing Points ---
      double swingHigh = FindSwingHigh(i + 1, InpSwingLength, high, rates_total);
      double swingLow  = FindSwingLow(i + 1, InpSwingLength, low, rates_total);
      
      // Display swing points
      if(InpShowSwingPoints) {
         if(IsSwingHigh(i, InpSwingLength, high, rates_total)) {
            SwingHighBuffer[i] = high[i];
         }
         if(IsSwingLow(i, InpSwingLength, low, rates_total)) {
            SwingLowBuffer[i] = low[i];
         }
      }
      
      // --- STEP 2: Detect Liquidity Sweeps ---
      bool sweepBullish = false;
      bool sweepBearish = false;
      
      // Bullish Sweep: Price wicked below swing low but closed above
      if(swingLow > 0 && low[i] < swingLow && close[i] > swingLow) {
         sweepBullish = true;
         if(InpShowSweeps && i <= 2) { // Only draw recent sweeps
            DrawSweepMarker(time[i], low[i], false);
         }
      }
      
      // Bearish Sweep: Price wicked above swing high but closed below
      if(swingHigh > 0 && high[i] > swingHigh && close[i] < swingHigh) {
         sweepBearish = true;
         if(InpShowSweeps && i <= 2) {
            DrawSweepMarker(time[i], high[i], true);
         }
      }
      
      // --- STEP 3: Pattern Recognition ---
      bool isBullishCandle = close[i] > open[i];
      bool isBearishCandle = close[i] < open[i];
      double candleBody = MathAbs(close[i] - open[i]);
      
      // Check minimum candle size
      bool isSignificantCandle = candleBody > atr[i] * InpMinCandleSize;
      
      // Engulfing patterns (optional)
      bool isBullishEngulfing = false;
      bool isBearishEngulfing = false;
      
      if(InpRequireEngulfing && i + 1 < rates_total) {
         isBullishEngulfing = isBullishCandle && 
                              close[i] > high[i+1] && 
                              open[i] < low[i+1];
         
         isBearishEngulfing = isBearishCandle && 
                              close[i] < low[i+1] && 
                              open[i] > high[i+1];
      }
      
      // --- STEP 4: HTF Trend Filter ---
      int htfTrend = 0;
      if(InpFilterByHTF && ArraySize(maBuf) > i) {
         htfTrend = (close[i] > maBuf[i]) ? 1 : -1;
      }
      
      // --- STEP 5: Order Block Detection ---
      if(InpDrawOB && i < rates_total - 5 && i <= 50) { // Only recent OBs
         DetectAndDrawOB(i, open, high, low, close, atr, time);
      }
      
      // --- STEP 6: Generate Signals ---
      
      // BUY SIGNAL CONDITIONS:
      // 1. Bullish sweep detected (current or previous bar)
      // 2. Significant bullish candle
      // 3. Optional: Bullish engulfing
      // 4. Optional: HTF trend is bullish
      
      bool buyCondition = sweepBullish && isBullishCandle && isSignificantCandle;
      
      if(InpRequireEngulfing) {
         buyCondition = buyCondition && isBullishEngulfing;
      }
      
      if(InpFilterByHTF) {
         buyCondition = buyCondition && (htfTrend == 1);
      }
      
      if(buyCondition) {
         BuyBuffer[i] = low[i] - atr[i] * 0.5;
         if(i <= 2) Print("🟢 BUY Signal at bar ", i, " | Price: ", close[i], " | Time: ", TimeToString(time[i]));
      }
      
      // SELL SIGNAL CONDITIONS:
      // 1. Bearish sweep detected
      // 2. Significant bearish candle
      // 3. Optional: Bearish engulfing
      // 4. Optional: HTF trend is bearish
      
      bool sellCondition = sweepBearish && isBearishCandle && isSignificantCandle;
      
      if(InpRequireEngulfing) {
         sellCondition = sellCondition && isBearishEngulfing;
      }
      
      if(InpFilterByHTF) {
         sellCondition = sellCondition && (htfTrend == -1);
      }
      
      if(sellCondition) {
         SellBuffer[i] = high[i] + atr[i] * 0.5;
         if(i <= 2) Print("🔴 SELL Signal at bar ", i, " | Price: ", close[i], " | Time: ", TimeToString(time[i]));
      }
   }
   
   // --- Manage Order Blocks (only on new bar) ---
   if(InpDrawOB && time[0] != lastOBCheck) {
      ManageOBMitigation(0, high, low, close);
      lastOBCheck = time[0];
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| HELPER: Check if current bar is a Swing High |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index, int lookback, const double &high[], int rates_total) {
   if(index + lookback >= rates_total || index < lookback) return false;
   
   double centerHigh = high[index];
   
   // Check left side
   for(int i = 1; i <= lookback; i++) {
      if(high[index + i] >= centerHigh) return false;
   }
   
   // Check right side
   for(int i = 1; i <= lookback; i++) {
      if(index - i < 0) return false;
      if(high[index - i] >= centerHigh) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| HELPER: Check if current bar is a Swing Low |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, int lookback, const double &low[], int rates_total) {
   if(index + lookback >= rates_total || index < lookback) return false;
   
   double centerLow = low[index];
   
   // Check left side
   for(int i = 1; i <= lookback; i++) {
      if(low[index + i] <= centerLow) return false;
   }
   
   // Check right side
   for(int i = 1; i <= lookback; i++) {
      if(index - i < 0) return false;
      if(low[index - i] <= centerLow) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| HELPER: Find most recent Swing High |
//+------------------------------------------------------------------+
double FindSwingHigh(int startIndex, int lookback, const double &high[], int rates_total) {
   int searchLimit = MathMin(startIndex + 50, rates_total - lookback - 1);
   
   for(int k = startIndex; k < searchLimit; k++) {
      if(IsSwingHigh(k, lookback, high, rates_total)) {
         return high[k];
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| HELPER: Find most recent Swing Low |
//+------------------------------------------------------------------+
double FindSwingLow(int startIndex, int lookback, const double &low[], int rates_total) {
   int searchLimit = MathMin(startIndex + 50, rates_total - lookback - 1);
   
   for(int k = startIndex; k < searchLimit; k++) {
      if(IsSwingLow(k, lookback, low, rates_total)) {
         return low[k];
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| HELPER: Detect and Draw Order Blocks |
//+------------------------------------------------------------------+
void DetectAndDrawOB(int i, const double &open[], const double &high[], 
                     const double &low[], const double &close[], 
                     const double &atr[], const datetime &time[]) {
   
   if(i + 1 >= ArraySize(open)) return;
   if(atr[i] <= 0) return;
   
   double bodySize = MathAbs(close[i] - open[i]);
   bool isImpulse = bodySize > atr[i] * InpDisplacementATR;
   
   if(!isImpulse) return;
   
   // Bullish OB: Strong bullish candle after bearish candle
   if(close[i] > open[i] && close[i+1] <= open[i+1]) {
      double obTop = high[i+1];
      double obBot = low[i+1];
      
      string name = "InstOB_Buy_" + IntegerToString(time[i+1]);
      if(ObjectFind(0, name) < 0) {
         datetime endTime = time[0] + PeriodSeconds() * 50;
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], obTop, endTime, obBot);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorBullishOB);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      }
   }
   
   // Bearish OB: Strong bearish candle after bullish candle
   if(close[i] < open[i] && close[i+1] >= open[i+1]) {
      double obTop = high[i+1];
      double obBot = low[i+1];
      
      string name = "InstOB_Sell_" + IntegerToString(time[i+1]);
      if(ObjectFind(0, name) < 0) {
         datetime endTime = time[0] + PeriodSeconds() * 50;
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], obTop, endTime, obBot);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorBearishOB);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      }
   }
}

//+------------------------------------------------------------------+
//| HELPER: Manage Order Block Mitigation |
//+------------------------------------------------------------------+
void ManageOBMitigation(int i, const double &high[], const double &low[], const double &close[]) {
   if(i != 0) return; // Only check on current bar
   
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   int removed = 0;
   
   for(int k = total - 1; k >= 0; k--) {
      string name = ObjectName(0, k, 0, OBJ_RECTANGLE);
      if(StringFind(name, "InstOB_") < 0) continue;
      
      double price1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double price2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      
      double obTop = MathMax(price1, price2);
      double obBot = MathMin(price1, price2);
      
      // Check if price has touched the OB
      bool mitigated = (high[i] >= obBot && low[i] <= obTop);
      
      if(mitigated) {
         if(InpRemoveMitigated) {
            ObjectDelete(0, name);
            removed++;
         } else {
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
         }
      } else {
         // Extend OB to current time
         datetime endTime = TimeCurrent() + PeriodSeconds() * 50;
         ObjectSetInteger(0, name, OBJPROP_TIME, 1, endTime);
      }
   }
   
   if(removed > 0) {
      Print("🗑️ Removed ", removed, " mitigated order blocks");
   }
}

//+------------------------------------------------------------------+
//| HELPER: Draw Liquidity Sweep Marker |
//+------------------------------------------------------------------+
void DrawSweepMarker(datetime t, double price, bool isHigh) {
   string name = "InstSweep_" + IntegerToString(t) + "_" + DoubleToString(price, 5);
   if(ObjectFind(0, name) >= 0) return;
   
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isHigh ? 234 : 233);
   ObjectSetInteger(0, name, OBJPROP_COLOR, isHigh ? clrOrangeRed : clrLimeGreen);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, isHigh ? ANCHOR_TOP : ANCHOR_BOTTOM);
}
