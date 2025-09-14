#pragma once
#include <Trade/Trade.mqh>

CTrade _plTrade;

class TYP_ParentalLock
{
  double m_allowed_long;
  double m_allowed_short;
public:
  void NoteOurEntry(const string sym, double lot, int dir)
  {
    // Netting: track allowed net exposure (simplified)
    long m; AccountInfoInteger(ACCOUNT_MARGIN_MODE,m);
    if(m!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
    {
      if(dir==DIR_LONG)  m_allowed_long += lot;
      if(dir==DIR_SHORT) m_allowed_short+= lot;
    }
  }

  bool InScope(const string sym){ return true; }

  bool IsManualReason(const long reason)
  {
    return (reason==DEAL_REASON_CLIENT || reason==DEAL_REASON_MOBILE || reason==DEAL_REASON_WEB);
  }

  void Handle(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
  {
    if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
    {
      ulong  deal = trans.deal;
      long   reason = (long)HistoryDealGetInteger(deal, DEAL_REASON);
      string sym    = (string)HistoryDealGetString(deal, DEAL_SYMBOL);
      double vol    = HistoryDealGetDouble(deal, DEAL_VOLUME);
      if(IsManualReason(reason) && InScope(sym))
      {
        // Netting neutralizer
        long m; AccountInfoInteger(ACCOUNT_MARGIN_MODE,m);
        if(m!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
        {
          if(!PositionSelect(sym)) return;
          long   pos_type = (long)PositionGetInteger(POSITION_TYPE);
          double pos_vol  = PositionGetDouble(POSITION_VOLUME);
          double allowed_net = m_allowed_long - m_allowed_short;
          double delta = pos_vol * (pos_type==POSITION_TYPE_BUY? +1.0 : -1.0) - allowed_net;
          if(MathAbs(delta) > SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN)-1e-8)
          {
            double lot = MathAbs(delta);
            if(delta>0){ _plTrade.Sell(lot, sym); }
            else        { _plTrade.Buy (lot, sym); }
          }
        }
      }
    }

    if(trans.type==TRADE_TRANSACTION_ORDER_ADD || trans.type==TRADE_TRANSACTION_ORDER_UPDATE)
    {
      ulong oid = trans.order; if(!OrderSelect(oid)) return;
      long reason = (long)OrderGetInteger(ORDER_REASON);
      if(IsManualReason(reason))
      {
        ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(ot==ORDER_TYPE_BUY_LIMIT  || ot==ORDER_TYPE_SELL_LIMIT ||
           ot==ORDER_TYPE_BUY_STOP   || ot==ORDER_TYPE_SELL_STOP  ||
           ot==ORDER_TYPE_BUY_STOP_LIMIT || ot==ORDER_TYPE_SELL_STOP_LIMIT)
        {
          MqlTradeRequest r; MqlTradeResult rr; ZeroMemory(r); ZeroMemory(rr);
          r.action = TRADE_ACTION_REMOVE; r.order = oid; r.symbol = (string)OrderGetString(ORDER_SYMBOL);
          OrderSend(r, rr);
        }
      }
    }
  }
};
