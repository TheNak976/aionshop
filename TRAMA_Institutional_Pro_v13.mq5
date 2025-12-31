//+------------------------------------------------------------------+
//|                           TRAMA Institutional Pro v13.mq5         |
//|                    Institutional Grade - AI Enhanced              |
//|          Advanced Market Structure + Smart Money Concepts         |
//+------------------------------------------------------------------+
#property copyright "Institutional Pro v13 - 2025"
#property link      ""
#property version   "13.00"
#property indicator_chart_window

//--- Buffers & Plots
#property indicator_buffers 12
#property indicator_plots   5

//--- PLOT 1: TRAMA Line (Multi-Color)
#property indicator_label1  "TRAMA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGray, clrLime, clrRed, clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- PLOT 2: TRAMA Candles (Optional)
#property indicator_label2  "TRAMA Candles"
#property indicator_type2   DRAW_COLOR_CANDLES
#property indicator_color2  clrDimGray, clrLimeGreen, clrCrimson
#property indicator_width2  1

//--- PLOT 3: Buy Signals
#property indicator_label3  "Buy Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  4

//--- PLOT 4: Sell Signals
#property indicator_label4  "Sell Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  4

//--- PLOT 5: Swing Points
#property indicator_label5  "Swing Points"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrYellow
#property indicator_width5  2

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - INSTITUTIONAL GRADE                           |
//+------------------------------------------------------------------+
input group "═══ TRAMA Core Settings ═══"
input int               InpLength           = 99;           // TRAMA Period
input int               InpConfirmBars      = 2;            // Confirmation Bars
input ENUM_APPLIED_PRICE InpPrice           = PRICE_CLOSE;  // Applied Price
input bool              InpAdaptiveMode     = true;         // Adaptive TRAMA (Volatility-Based)

input group "═══ Institutional Order Blocks ═══"
input bool              InpShowOB           = true;         // Show Order Blocks
input int               InpOBLookback       = 300;          // OB History Depth
input double            InpOBMinImpulse     = 1.5;          // Min Impulse (x ATR)
input bool              InpOBRequireFVG     = true;         // Require Fair Value Gap
input bool              InpOBRequireSweep   = true;         // Require Liquidity Sweep
input bool              InpOBAutoMitigate   = true;         // Auto-Remove Mitigated OBs

input group "═══ Smart Money Concepts ═══"
input bool              InpDetectBOS        = true;         // Detect Break of Structure
input bool              InpDetectCHoCH      = true;         // Detect Change of Character
input int               InpSwingStrength    = 5;            // Swing Point Strength
input bool              InpShowLiquidity    = true;         // Show Liquidity Zones
input bool              InpShowFVG          = true;         // Show Fair Value Gaps

input group "═══ Signal Generation ═══"
input bool              InpEnableSignals    = true;         // Enable Entry Signals
input bool              InpFilterByTrend    = true;         // Filter by TRAMA Trend
input bool              InpRequireOB        = true;         // Require OB Confluence
input double            InpMinSignalATR     = 0.8;          // Min Signal Strength (x ATR)
input ENUM_TIMEFRAMES   InpHTF              = PERIOD_H4;    // HTF Trend Filter

input group "═══ Visual Settings ═══"
input color             InpBullOBColor      = C'0,100,200'; // Bullish OB Color
input color             InpBearOBColor      = C'200,50,0';  // Bearish OB Color
input color             InpFVGBullColor     = C'0,150,255'; // Bullish FVG Color
input color             InpFVGBearColor     = C'255,100,0'; // Bearish FVG Color
input bool              InpColorCandles     = true;         // Color Candles by TRAMA
input bool              InpShowSwingPoints  = true;         // Show Swing High/Low
input int               InpTransparency     = 85;           // Zone Transparency (0-100)

input group "═══ Performance Optimization ═══"
input int               InpMaxBarsCalc      = 500;          // Max Bars to Calculate
input bool              InpSmartRedraw      = true;         // Smart Redraw (Performance)
input int               InpATRPeriod        = 14;           // ATR Period

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES & BUFFERS                                       |
//+------------------------------------------------------------------+
// Main Buffers
double BufferTrama[];
double BufferTramaColor[];
double BufferCandleOpen[];
double BufferCandleHigh[];
double BufferCandleLow[];
double BufferCandleClose[];
double BufferCandleColor[];
double BufferBuySignal[];
double BufferSellSignal[];
double BufferSwingPoints[];

// Calculation Buffers
double BufferBreakouts[];
double BufferVolatility[];

// Indicator Handles
int handleATR;
int handleHTFMA;

// Performance Tracking
datetime lastCalculation = 0;
int totalSignals = 0;
int totalOBs = 0;

// Market Structure
struct MarketStructure {
   double lastSwingHigh;
   double lastSwingLow;
   datetime lastSwingHighTime;
   datetime lastSwingLowTime;
   int trend; // 1=Bullish, -1=Bearish, 0=Ranging
   bool bosDetected;
   bool chochDetected;
};
MarketStructure MS;

//+------------------------------------------------------------------+
//| Custom Indicator Initialization                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // Buffer Mapping
   SetIndexBuffer(0, BufferTrama, INDICATOR_DATA);
   SetIndexBuffer(1, BufferTramaColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufferCandleOpen, INDICATOR_DATA);
   SetIndexBuffer(3, BufferCandleHigh, INDICATOR_DATA);
   SetIndexBuffer(4, BufferCandleLow, INDICATOR_DATA);
   SetIndexBuffer(5, BufferCandleClose, INDICATOR_DATA);
   SetIndexBuffer(6, BufferCandleColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(7, BufferBuySignal, INDICATOR_DATA);
   SetIndexBuffer(8, BufferSellSignal, INDICATOR_DATA);
   SetIndexBuffer(9, BufferSwingPoints, INDICATOR_DATA);
   SetIndexBuffer(10, BufferBreakouts, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, BufferVolatility, INDICATOR_CALCULATIONS);

   // Plot Settings
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   if(InpColorCandles) {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
   } else {
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Buy Arrow
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // Sell Arrow
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   
   PlotIndexSetInteger(4, PLOT_ARROW, 159); // Swing Points
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);

   // Initialize Indicators
   handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(handleATR == INVALID_HANDLE) {
      Print("❌ Failed to create ATR indicator");
      return INIT_FAILED;
   }
   
   // HTF MA for trend filter
   if(InpFilterByTrend) {
      int ratio = PeriodSeconds(InpHTF) / PeriodSeconds();
      if(ratio < 1) ratio = 1;
      int maPeriod = MathMin(50 * ratio, 500);
      handleHTFMA = iMA(_Symbol, _Period, maPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(handleHTFMA == INVALID_HANDLE) {
         Print("⚠️ Failed to create HTF MA - continuing without HTF filter");
      }
   }

   // Initialize Market Structure
   MS.lastSwingHigh = 0;
   MS.lastSwingLow = 0;
   MS.trend = 0;
   MS.bosDetected = false;
   MS.chochDetected = false;

   // Set Arrays as Series
   ArraySetAsSeries(BufferTrama, true);
   ArraySetAsSeries(BufferTramaColor, true);
   ArraySetAsSeries(BufferBuySignal, true);
   ArraySetAsSeries(BufferSellSignal, true);
   ArraySetAsSeries(BufferSwingPoints, true);
   ArraySetAsSeries(BufferBreakouts, true);
   ArraySetAsSeries(BufferVolatility, true);

   // Indicator Name
   string name = StringFormat("TRAMA Institutional Pro v13 [%d]", InpLength);
   IndicatorSetString(INDICATOR_SHORTNAME, name);
   
   Print("✅ ", name, " initialized successfully");
   Print("📊 Settings: Length=", InpLength, " | ATR=", InpATRPeriod, " | Impulse=", InpOBMinImpulse);
   Print("🎯 Features: OB=", InpShowOB, " | FVG=", InpShowFVG, " | BOS=", InpDetectBOS, " | Signals=", InpEnableSignals);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup Objects
   ObjectsDeleteAll(0, "TRAMA_OB_");
   ObjectsDeleteAll(0, "TRAMA_FVG_");
   ObjectsDeleteAll(0, "TRAMA_LIQ_");
   ObjectsDeleteAll(0, "TRAMA_BOS_");
   
   // Release Handles
   if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
   if(handleHTFMA != INVALID_HANDLE) IndicatorRelease(handleHTFMA);
   
   ChartRedraw();
   
   Print("📊 TRAMA Pro v13 Statistics:");
   Print("   Total Signals Generated: ", totalSignals);
   Print("   Total Order Blocks: ", totalOBs);
   Print("🔄 Indicator removed successfully");
}

//+------------------------------------------------------------------+
//| Custom Indicator Iteration                                       |
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
   // Validation
   int minBars = InpLength + InpSwingStrength * 2 + 10;
   if(rates_total < minBars) return 0;
   
   // Set Arrays as Series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // Get ATR Data
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handleATR, 0, 0, rates_total, atr) <= 0) return prev_calculated;

   // Get HTF MA Data (if enabled)
   double htfMA[];
   if(InpFilterByTrend && handleHTFMA != INVALID_HANDLE) {
      ArraySetAsSeries(htfMA, true);
      if(CopyBuffer(handleHTFMA, 0, 0, rates_total, htfMA) <= 0) {
         ArrayResize(htfMA, 0); // Disable HTF filter on error
      }
   }

   // Calculate Limit (Optimized)
   int limit;
   if(prev_calculated == 0) {
      limit = MathMin(rates_total - minBars, InpMaxBarsCalc);
      ArrayInitialize(BufferTrama, 0);
      ArrayInitialize(BufferBreakouts, 0);
      Print("🔄 Initial calculation: ", limit, " bars");
   } else {
      limit = rates_total - prev_calculated + 1;
      if(limit > 50) limit = 50; // Cap incremental updates
   }
   
   if(limit < 1) limit = 1;

   //+------------------------------------------------------------------+
   //| MAIN CALCULATION LOOP                                            |
   //+------------------------------------------------------------------+
   for(int i = limit; i >= 0; i--)
   {
      // Safety Checks
      if(i + InpLength >= rates_total) continue;
      if(atr[i] <= 0) continue;
      
      // Reset Signals
      BufferBuySignal[i] = 0.0;
      BufferSellSignal[i] = 0.0;
      BufferSwingPoints[i] = 0.0;
      
      //--- STEP 1: TRAMA CALCULATION (Enhanced) ---
      
      // Find Highest High and Lowest Low
      int hhIdx = ArrayMaximum(high, i, InpLength);
      int llIdx = ArrayMinimum(low, i, InpLength);
      
      // Breakout Detection
      double hh = (i > 0 && high[i] > high[hhIdx]) ? 1.0 : 0.0;
      double ll = (i > 0 && low[i] < low[llIdx]) ? 1.0 : 0.0;
      BufferBreakouts[i] = (hh > 0 || ll > 0) ? 1.0 : 0.0;
      
      // Calculate Trigger Coefficient (TC)
      double sum = 0.0;
      for(int k = 0; k < InpLength && i + k < rates_total; k++) {
         sum += BufferBreakouts[i + k];
      }
      double tc = MathPow(sum / (double)InpLength, 2.0);
      
      // Adaptive Mode: Adjust TC based on volatility
      if(InpAdaptiveMode) {
         double avgATR = 0;
         for(int k = 0; k < 20 && i + k < rates_total; k++) {
            avgATR += atr[i + k];
         }
         avgATR /= 20.0;
         
         double volatilityRatio = (avgATR > 0) ? atr[i] / avgATR : 1.0;
         tc *= volatilityRatio;
         tc = MathMin(tc, 1.0); // Cap at 1.0
      }
      
      BufferVolatility[i] = tc;
      
      // TRAMA Calculation
      if(i == limit || BufferTrama[i+1] == 0) {
         BufferTrama[i] = close[i];
      } else {
         BufferTrama[i] = BufferTrama[i+1] + tc * (close[i] - BufferTrama[i+1]);
      }
      
      // TRAMA Color Logic (Enhanced)
      double tramaChange = (i < rates_total - 1) ? BufferTrama[i] - BufferTrama[i+1] : 0;
      double priceVsTrama = close[i] - BufferTrama[i];
      
      if(tramaChange > _Point * 0.5 && priceVsTrama > 0) {
         BufferTramaColor[i] = 1.0; // Strong Bullish (Lime)
      } else if(tramaChange < -_Point * 0.5 && priceVsTrama < 0) {
         BufferTramaColor[i] = 2.0; // Strong Bearish (Red)
      } else if(MathAbs(tramaChange) < _Point * 0.2) {
         BufferTramaColor[i] = 3.0; // Consolidation (Gold)
      } else {
         BufferTramaColor[i] = 0.0; // Neutral (Gray)
      }
      
      // Color Candles
      if(InpColorCandles) {
         BufferCandleOpen[i] = open[i];
         BufferCandleHigh[i] = high[i];
         BufferCandleLow[i] = low[i];
         BufferCandleClose[i] = close[i];
         BufferCandleColor[i] = (close[i] > BufferTrama[i]) ? 1.0 : 
                                (close[i] < BufferTrama[i]) ? 2.0 : 0.0;
      }
      
      //--- STEP 2: MARKET STRUCTURE ANALYSIS ---
      
      // Detect Swing Points
      bool isSwingHigh = IsSwingPoint(i, InpSwingStrength, high, true, rates_total);
      bool isSwingLow = IsSwingPoint(i, InpSwingStrength, low, false, rates_total);
      
      if(isSwingHigh) {
         if(InpShowSwingPoints) BufferSwingPoints[i] = high[i];
         
         // Update Market Structure
         if(MS.lastSwingHigh == 0 || high[i] > MS.lastSwingHigh) {
            MS.lastSwingHigh = high[i];
            MS.lastSwingHighTime = time[i];
         }
      }
      
      if(isSwingLow) {
         if(InpShowSwingPoints) BufferSwingPoints[i] = low[i];
         
         // Update Market Structure
         if(MS.lastSwingLow == 0 || low[i] < MS.lastSwingLow) {
            MS.lastSwingLow = low[i];
            MS.lastSwingLowTime = time[i];
         }
      }
      
      // Detect BOS (Break of Structure)
      if(InpDetectBOS && i <= 10) {
         DetectBOS(i, high, low, close, time);
      }
      
      //--- STEP 3: ORDER BLOCK DETECTION ---
      
      if(InpShowOB && i < rates_total - 5 && i <= InpOBLookback) {
         DetectOrderBlock(i, open, high, low, close, atr, time, rates_total);
      }
      
      //--- STEP 4: FAIR VALUE GAP DETECTION ---
      
      if(InpShowFVG && i < rates_total - 3 && i <= 100) {
         DetectFVG(i, high, low, time);
      }
      
      //--- STEP 5: LIQUIDITY ZONES ---
      
      if(InpShowLiquidity && i <= 50) {
         DetectLiquidityZones(i, high, low, time, rates_total);
      }
      
      //--- STEP 6: SIGNAL GENERATION ---
      
      if(InpEnableSignals && i <= 5 && i >= InpConfirmBars) {
         GenerateSignals(i, open, high, low, close, atr, htfMA, time);
      }
   }
   
   //--- STEP 7: OBJECT MANAGEMENT (Only on new bar) ---
   
   if(InpSmartRedraw && time[0] != lastCalculation) {
      ManageObjects(high, low, close);
      lastCalculation = time[0];
   }
   
   return rates_total;
}

//+------------------------------------------------------------------+
//| Detect Swing Points (Fractal Logic)                             |
//+------------------------------------------------------------------+
bool IsSwingPoint(int index, int strength, const double &price[], bool isHigh, int rates_total)
{
   if(index + strength >= rates_total || index < strength) return false;
   
   double centerPrice = price[index];
   
   // Check left side
   for(int i = 1; i <= strength; i++) {
      if(isHigh) {
         if(price[index + i] >= centerPrice) return false;
      } else {
         if(price[index + i] <= centerPrice) return false;
      }
   }
   
   // Check right side
   for(int i = 1; i <= strength; i++) {
      if(index - i < 0) return false;
      if(isHigh) {
         if(price[index - i] >= centerPrice) return false;
      } else {
         if(price[index - i] <= centerPrice) return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS)                                 |
//+------------------------------------------------------------------+
void DetectBOS(int i, const double &high[], const double &low[], 
               const double &close[], const datetime &time[])
{
   if(MS.lastSwingHigh == 0 || MS.lastSwingLow == 0) return;
   
   // Bullish BOS: Price breaks above last swing high
   if(close[i] > MS.lastSwingHigh && !MS.bosDetected) {
      string name = "TRAMA_BOS_Bull_" + IntegerToString(time[i]);
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_TREND, 0, MS.lastSwingHighTime, MS.lastSwingHigh, time[i], MS.lastSwingHigh);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         MS.bosDetected = true;
         MS.trend = 1;
      }
   }
   
   // Bearish BOS: Price breaks below last swing low
   if(close[i] < MS.lastSwingLow && !MS.bosDetected) {
      string name = "TRAMA_BOS_Bear_" + IntegerToString(time[i]);
      if(ObjectFind(0, name) < 0) {
         ObjectCreate(0, name, OBJ_TREND, 0, MS.lastSwingLowTime, MS.lastSwingLow, time[i], MS.lastSwingLow);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         MS.bosDetected = true;
         MS.trend = -1;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Order Blocks (Institutional Grade)                       |
//+------------------------------------------------------------------+
void DetectOrderBlock(int i, const double &open[], const double &high[], 
                      const double &low[], const double &close[], 
                      const double &atr[], const datetime &time[], int rates_total)
{
   if(i + 3 >= rates_total) return;
   if(atr[i] <= 0) return;
   
   double bodySize = MathAbs(close[i] - open[i]);
   bool isImpulseCandle = bodySize > atr[i] * InpOBMinImpulse;
   
   if(!isImpulseCandle) return;
   
   //--- BULLISH ORDER BLOCK ---
   // Strong bullish candle after bearish/consolidation
   if(close[i] > open[i] && close[i+1] <= open[i+1]) {
      
      // Check for FVG (if required)
      bool hasFVG = true;
      if(InpOBRequireFVG) {
         hasFVG = (i + 2 < rates_total) && (low[i] > high[i+2]);
      }
      
      // Check for Liquidity Sweep (if required)
      bool hasSweep = true;
      if(InpOBRequireSweep) {
         hasSweep = (i + 2 < rates_total) && (low[i+1] < low[i+2]);
      }
      
      if(hasFVG && hasSweep) {
         double obTop = high[i+1];
         double obBot = low[i+1];
         
         string name = "TRAMA_OB_Bull_" + IntegerToString(time[i+1]);
         if(ObjectFind(0, name) < 0) {
            datetime endTime = time[0] + PeriodSeconds() * 100;
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], obTop, endTime, obBot);
            ObjectSetInteger(0, name, OBJPROP_COLOR, InpBullOBColor);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
            totalOBs++;
         }
      }
   }
   
   //--- BEARISH ORDER BLOCK ---
   // Strong bearish candle after bullish/consolidation
   if(close[i] < open[i] && close[i+1] >= open[i+1]) {
      
      // Check for FVG (if required)
      bool hasFVG = true;
      if(InpOBRequireFVG) {
         hasFVG = (i + 2 < rates_total) && (high[i] < low[i+2]);
      }
      
      // Check for Liquidity Sweep (if required)
      bool hasSweep = true;
      if(InpOBRequireSweep) {
         hasSweep = (i + 2 < rates_total) && (high[i+1] > high[i+2]);
      }
      
      if(hasFVG && hasSweep) {
         double obTop = high[i+1];
         double obBot = low[i+1];
         
         string name = "TRAMA_OB_Bear_" + IntegerToString(time[i+1]);
         if(ObjectFind(0, name) < 0) {
            datetime endTime = time[0] + PeriodSeconds() * 100;
            ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], obTop, endTime, obBot);
            ObjectSetInteger(0, name, OBJPROP_COLOR, InpBearOBColor);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
            totalOBs++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps (FVG)                                    |
//+------------------------------------------------------------------+
void DetectFVG(int i, const double &high[], const double &low[], const datetime &time[])
{
   if(i + 2 >= ArraySize(high)) return;
   
   // Bullish FVG: Gap between candle[i+2] high and candle[i] low
   if(low[i] > high[i+2]) {
      double gapSize = low[i] - high[i+2];
      double gapTop = low[i];
      double gapBot = high[i+2];
      
      string name = "TRAMA_FVG_Bull_" + IntegerToString(time[i+1]);
      if(ObjectFind(0, name) < 0) {
         datetime endTime = time[0] + PeriodSeconds() * 50;
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], gapTop, endTime, gapBot);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpFVGBullColor);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      }
   }
   
   // Bearish FVG: Gap between candle[i+2] low and candle[i] high
   if(high[i] < low[i+2]) {
      double gapSize = low[i+2] - high[i];
      double gapTop = low[i+2];
      double gapBot = high[i];
      
      string name = "TRAMA_FVG_Bear_" + IntegerToString(time[i+1]);
      if(ObjectFind(0, name) < 0) {
         datetime endTime = time[0] + PeriodSeconds() * 50;
         ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i+1], gapTop, endTime, gapBot);
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpFVGBearColor);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Liquidity Zones (Equal Highs/Lows)                       |
//+------------------------------------------------------------------+
void DetectLiquidityZones(int i, const double &high[], const double &low[], 
                          const datetime &time[], int rates_total)
{
   if(i + 10 >= rates_total) return;
   
   double tolerance = _Point * 10; // 10 pips tolerance
   
   // Look for equal highs (liquidity above)
   for(int k = i + 1; k < i + 10 && k < rates_total; k++) {
      if(MathAbs(high[i] - high[k]) < tolerance) {
         string name = "TRAMA_LIQ_High_" + IntegerToString(time[i]);
         if(ObjectFind(0, name) < 0) {
            ObjectCreate(0, name, OBJ_TREND, 0, time[k], high[k], time[i], high[i]);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
         }
         break;
      }
   }
   
   // Look for equal lows (liquidity below)
   for(int k = i + 1; k < i + 10 && k < rates_total; k++) {
      if(MathAbs(low[i] - low[k]) < tolerance) {
         string name = "TRAMA_LIQ_Low_" + IntegerToString(time[i]);
         if(ObjectFind(0, name) < 0) {
            ObjectCreate(0, name, OBJ_TREND, 0, time[k], low[k], time[i], low[i]);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Generate Entry Signals (Institutional Logic)                    |
//+------------------------------------------------------------------+
void GenerateSignals(int i, const double &open[], const double &high[], 
                     const double &low[], const double &close[], 
                     const double &atr[], const double &htfMA[], 
                     const datetime &time[])
{
   if(i + InpConfirmBars >= ArraySize(close)) return;
   if(atr[i] <= 0) return;
   
   // Get TRAMA trend
   int tramaTrend = 0;
   if(BufferTramaColor[i] == 1.0) tramaTrend = 1;  // Bullish
   else if(BufferTramaColor[i] == 2.0) tramaTrend = -1; // Bearish
   
   // HTF Trend Filter
   int htfTrend = 0;
   if(InpFilterByTrend && ArraySize(htfMA) > i) {
      htfTrend = (close[i] > htfMA[i]) ? 1 : -1;
   }
   
   // Check for OB confluence (if required)
   bool nearBullOB = false;
   bool nearBearOB = false;
   
   if(InpRequireOB) {
      nearBullOB = IsNearOrderBlock(i, true, high, low);
      nearBearOB = IsNearOrderBlock(i, false, high, low);
   } else {
      nearBullOB = true;
      nearBearOB = true;
   }
   
   // Check candle strength
   double candleBody = MathAbs(close[i] - open[i]);
   bool isStrongCandle = candleBody > atr[i] * InpMinSignalATR;
   
   //--- BUY SIGNAL ---
   // Conditions:
   // 1. Strong bullish candle
   // 2. TRAMA is bullish (or neutral)
   // 3. HTF trend is bullish (if enabled)
   // 4. Near bullish OB (if required)
   // 5. Price above TRAMA
   
   bool buyCondition = (close[i] > open[i]) && 
                       isStrongCandle &&
                       (tramaTrend >= 0 || !InpFilterByTrend) &&
                       (htfTrend >= 0 || !InpFilterByTrend || ArraySize(htfMA) == 0) &&
                       nearBullOB &&
                       (close[i] > BufferTrama[i]);
   
   if(buyCondition) {
      BufferBuySignal[i] = low[i] - atr[i] * 0.5;
      totalSignals++;
      if(i <= 1) {
         Print("🟢 BUY SIGNAL | Bar: ", i, " | Price: ", close[i], " | TRAMA: ", BufferTrama[i], " | Time: ", TimeToString(time[i]));
      }
   }
   
   //--- SELL SIGNAL ---
   // Conditions:
   // 1. Strong bearish candle
   // 2. TRAMA is bearish (or neutral)
   // 3. HTF trend is bearish (if enabled)
   // 4. Near bearish OB (if required)
   // 5. Price below TRAMA
   
   bool sellCondition = (close[i] < open[i]) && 
                        isStrongCandle &&
                        (tramaTrend <= 0 || !InpFilterByTrend) &&
                        (htfTrend <= 0 || !InpFilterByTrend || ArraySize(htfMA) == 0) &&
                        nearBearOB &&
                        (close[i] < BufferTrama[i]);
   
   if(sellCondition) {
      BufferSellSignal[i] = high[i] + atr[i] * 0.5;
      totalSignals++;
      if(i <= 1) {
         Print("🔴 SELL SIGNAL | Bar: ", i, " | Price: ", close[i], " | TRAMA: ", BufferTrama[i], " | Time: ", TimeToString(time[i]));
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price is near an Order Block                           |
//+------------------------------------------------------------------+
bool IsNearOrderBlock(int i, bool isBullish, const double &high[], const double &low[])
{
   string prefix = isBullish ? "TRAMA_OB_Bull_" : "TRAMA_OB_Bear_";
   double currentPrice = isBullish ? low[i] : high[i];
   double tolerance = _Point * 50; // 50 pips tolerance
   
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   for(int k = 0; k < total; k++) {
      string name = ObjectName(0, k, 0, OBJ_RECTANGLE);
      if(StringFind(name, prefix) < 0) continue;
      
      double price1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double price2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      double obTop = MathMax(price1, price2);
      double obBot = MathMin(price1, price2);
      
      // Check if current price is within or near the OB
      if(currentPrice >= obBot - tolerance && currentPrice <= obTop + tolerance) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Manage Objects (Mitigation, Extension, Cleanup)                 |
//+------------------------------------------------------------------+
void ManageObjects(const double &high[], const double &low[], const double &close[])
{
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   int mitigated = 0;
   
   for(int k = total - 1; k >= 0; k--) {
      string name = ObjectName(0, k, 0, OBJ_RECTANGLE);
      
      // Only manage TRAMA objects
      if(StringFind(name, "TRAMA_OB_") < 0 && StringFind(name, "TRAMA_FVG_") < 0) continue;
      
      double price1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double price2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      double obTop = MathMax(price1, price2);
      double obBot = MathMin(price1, price2);
      
      // Check mitigation (price touched the zone)
      bool isMitigated = (high[0] >= obBot && low[0] <= obTop);
      
      if(isMitigated) {
         if(InpOBAutoMitigate && StringFind(name, "TRAMA_OB_") >= 0) {
            ObjectDelete(0, name);
            mitigated++;
         } else {
            // Visual indication of mitigation
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         }
      } else {
         // Extend active zones
         datetime endTime = TimeCurrent() + PeriodSeconds() * 100;
         ObjectSetInteger(0, name, OBJPROP_TIME, 1, endTime);
      }
   }
   
   if(mitigated > 0) {
      Print("🗑️ Removed ", mitigated, " mitigated zones");
   }
}
