class StockSymbol {
  final String symbol;
  final String name;
  final String market;
  final String sector;

  const StockSymbol({
    required this.symbol,
    required this.name,
    required this.market,
    required this.sector,
  });

  String get yahooSymbol {
    if (market == 'NSE') return '$symbol.NS';
    if (market == 'BSE') return '$symbol.BO';
    return symbol;
  }
}

class StockUniverse {
  static const List<StockSymbol> nse = [
    StockSymbol(symbol: 'RELIANCE', name: 'Reliance Industries', market: 'NSE', sector: 'Energy'),
    StockSymbol(symbol: 'TCS', name: 'Tata Consultancy Services', market: 'NSE', sector: 'IT'),
    StockSymbol(symbol: 'HDFCBANK', name: 'HDFC Bank', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'INFY', name: 'Infosys', market: 'NSE', sector: 'IT'),
    StockSymbol(symbol: 'ICICIBANK', name: 'ICICI Bank', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'HINDUNILVR', name: 'Hindustan Unilever', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'ITC', name: 'ITC', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'SBIN', name: 'State Bank of India', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'BAJFINANCE', name: 'Bajaj Finance', market: 'NSE', sector: 'Finance'),
    StockSymbol(symbol: 'BHARTIARTL', name: 'Bharti Airtel', market: 'NSE', sector: 'Telecom'),
    StockSymbol(symbol: 'KOTAKBANK', name: 'Kotak Mahindra Bank', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'WIPRO', name: 'Wipro', market: 'NSE', sector: 'IT'),
    StockSymbol(symbol: 'LT', name: 'Larsen & Toubro', market: 'NSE', sector: 'Infrastructure'),
    StockSymbol(symbol: 'AXISBANK', name: 'Axis Bank', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'ASIANPAINT', name: 'Asian Paints', market: 'NSE', sector: 'Consumer'),
    StockSymbol(symbol: 'MARUTI', name: 'Maruti Suzuki', market: 'NSE', sector: 'Auto'),
    StockSymbol(symbol: 'TITAN', name: 'Titan Company', market: 'NSE', sector: 'Consumer'),
    StockSymbol(symbol: 'SUNPHARMA', name: 'Sun Pharmaceutical', market: 'NSE', sector: 'Pharma'),
    StockSymbol(symbol: 'ULTRACEMCO', name: 'UltraTech Cement', market: 'NSE', sector: 'Cement'),
    StockSymbol(symbol: 'NESTLEIND', name: 'Nestle India', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'POWERGRID', name: 'Power Grid Corp', market: 'NSE', sector: 'Power'),
    StockSymbol(symbol: 'NTPC', name: 'NTPC', market: 'NSE', sector: 'Power'),
    StockSymbol(symbol: 'ONGC', name: 'ONGC', market: 'NSE', sector: 'Energy'),
    StockSymbol(symbol: 'TECHM', name: 'Tech Mahindra', market: 'NSE', sector: 'IT'),
    StockSymbol(symbol: 'HCLTECH', name: 'HCL Technologies', market: 'NSE', sector: 'IT'),
    StockSymbol(symbol: 'INDUSINDBK', name: 'IndusInd Bank', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'BAJAJFINSV', name: 'Bajaj Finserv', market: 'NSE', sector: 'Finance'),
    StockSymbol(symbol: 'DRREDDY', name: 'Dr Reddys Labs', market: 'NSE', sector: 'Pharma'),
    StockSymbol(symbol: 'CIPLA', name: 'Cipla', market: 'NSE', sector: 'Pharma'),
    StockSymbol(symbol: 'DIVISLAB', name: 'Divis Laboratories', market: 'NSE', sector: 'Pharma'),
    StockSymbol(symbol: 'EICHERMOT', name: 'Eicher Motors', market: 'NSE', sector: 'Auto'),
    StockSymbol(symbol: 'HEROMOTOCO', name: 'Hero MotoCorp', market: 'NSE', sector: 'Auto'),
    StockSymbol(symbol: 'TATACONSUM', name: 'Tata Consumer Products', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'TATASTEEL', name: 'Tata Steel', market: 'NSE', sector: 'Metals'),
    StockSymbol(symbol: 'JSWSTEEL', name: 'JSW Steel', market: 'NSE', sector: 'Metals'),
    StockSymbol(symbol: 'HINDALCO', name: 'Hindalco Industries', market: 'NSE', sector: 'Metals'),
    StockSymbol(symbol: 'ADANIENT', name: 'Adani Enterprises', market: 'NSE', sector: 'Conglomerate'),
    StockSymbol(symbol: 'ADANIPORTS', name: 'Adani Ports', market: 'NSE', sector: 'Infrastructure'),
    StockSymbol(symbol: 'COALINDIA', name: 'Coal India', market: 'NSE', sector: 'Mining'),
    StockSymbol(symbol: 'GRASIM', name: 'Grasim Industries', market: 'NSE', sector: 'Diversified'),
    StockSymbol(symbol: 'BAJAJ-AUTO', name: 'Bajaj Auto', market: 'NSE', sector: 'Auto'),
    StockSymbol(symbol: 'BRITANNIA', name: 'Britannia Industries', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'BPCL', name: 'BPCL', market: 'NSE', sector: 'Energy'),
    StockSymbol(symbol: 'TATAPOWER', name: 'Tata Power', market: 'NSE', sector: 'Power'),
    StockSymbol(symbol: 'TATAMOTORS', name: 'Tata Motors', market: 'NSE', sector: 'Auto'),
    StockSymbol(symbol: 'M&M', name: 'Mahindra & Mahindra', market: 'NSE', sector: 'Auto'),
    StockSymbol(symbol: 'SBILIFE', name: 'SBI Life Insurance', market: 'NSE', sector: 'Insurance'),
    StockSymbol(symbol: 'HDFCLIFE', name: 'HDFC Life Insurance', market: 'NSE', sector: 'Insurance'),
    StockSymbol(symbol: 'PIDILITIND', name: 'Pidilite Industries', market: 'NSE', sector: 'Chemicals'),
    StockSymbol(symbol: 'APOLLOHOSP', name: 'Apollo Hospitals', market: 'NSE', sector: 'Healthcare'),
    StockSymbol(symbol: 'DMART', name: 'Avenue Supermarts', market: 'NSE', sector: 'Retail'),
    StockSymbol(symbol: 'ZOMATO', name: 'Zomato', market: 'NSE', sector: 'Internet'),
    StockSymbol(symbol: 'NYKAA', name: 'Nykaa', market: 'NSE', sector: 'Internet'),
    StockSymbol(symbol: 'PAYTM', name: 'Paytm', market: 'NSE', sector: 'Fintech'),
    StockSymbol(symbol: 'IRCTC', name: 'IRCTC', market: 'NSE', sector: 'Travel'),
    StockSymbol(symbol: 'HAL', name: 'HAL', market: 'NSE', sector: 'Defence'),
    StockSymbol(symbol: 'BEL', name: 'Bharat Electronics', market: 'NSE', sector: 'Defence'),
    StockSymbol(symbol: 'MUTHOOTFIN', name: 'Muthoot Finance', market: 'NSE', sector: 'Finance'),
    StockSymbol(symbol: 'MARICO', name: 'Marico', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'GODREJCP', name: 'Godrej Consumer Products', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'DABUR', name: 'Dabur India', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'COLPAL', name: 'Colgate Palmolive', market: 'NSE', sector: 'FMCG'),
    StockSymbol(symbol: 'TORNTPHARM', name: 'Torrent Pharma', market: 'NSE', sector: 'Pharma'),
    StockSymbol(symbol: 'LUPIN', name: 'Lupin', market: 'NSE', sector: 'Pharma'),
    StockSymbol(symbol: 'AUROPHARMA', name: 'Aurobindo Pharma', market: 'NSE', sector: 'Pharma'),
    StockSymbol(symbol: 'PETRONET', name: 'Petronet LNG', market: 'NSE', sector: 'Energy'),
    StockSymbol(symbol: 'IOC', name: 'Indian Oil Corp', market: 'NSE', sector: 'Energy'),
    StockSymbol(symbol: 'VEDL', name: 'Vedanta', market: 'NSE', sector: 'Metals'),
    StockSymbol(symbol: 'SAIL', name: 'Steel Authority of India', market: 'NSE', sector: 'Metals'),
    StockSymbol(symbol: 'PFC', name: 'Power Finance Corp', market: 'NSE', sector: 'Finance'),
    StockSymbol(symbol: 'REC', name: 'REC', market: 'NSE', sector: 'Finance'),
    StockSymbol(symbol: 'CANBK', name: 'Canara Bank', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'BANKBARODA', name: 'Bank of Baroda', market: 'NSE', sector: 'Banking'),
    StockSymbol(symbol: 'PNB', name: 'Punjab National Bank', market: 'NSE', sector: 'Banking'),
  ];

  static const List<StockSymbol> us = [
    StockSymbol(symbol: 'AAPL', name: 'Apple Inc.', market: 'US', sector: 'Technology'),
    StockSymbol(symbol: 'MSFT', name: 'Microsoft Corp.', market: 'US', sector: 'Technology'),
    StockSymbol(symbol: 'GOOGL', name: 'Alphabet Inc.', market: 'US', sector: 'Technology'),
    StockSymbol(symbol: 'AMZN', name: 'Amazon.com Inc.', market: 'US', sector: 'Consumer'),
    StockSymbol(symbol: 'NVDA', name: 'NVIDIA Corp.', market: 'US', sector: 'Technology'),
    StockSymbol(symbol: 'META', name: 'Meta Platforms', market: 'US', sector: 'Technology'),
    StockSymbol(symbol: 'TSLA', name: 'Tesla Inc.', market: 'US', sector: 'Auto'),
    StockSymbol(symbol: 'BERKB', name: 'Berkshire Hathaway', market: 'US', sector: 'Finance'),
    StockSymbol(symbol: 'LLY', name: 'Eli Lilly', market: 'US', sector: 'Pharma'),
    StockSymbol(symbol: 'V', name: 'Visa Inc.', market: 'US', sector: 'Finance'),
    StockSymbol(symbol: 'JPM', name: 'JPMorgan Chase', market: 'US', sector: 'Banking'),
    StockSymbol(symbol: 'MA', name: 'Mastercard', market: 'US', sector: 'Finance'),
    StockSymbol(symbol: 'UNH', name: 'UnitedHealth Group', market: 'US', sector: 'Healthcare'),
    StockSymbol(symbol: 'XOM', name: 'Exxon Mobil', market: 'US', sector: 'Energy'),
    StockSymbol(symbol: 'JNJ', name: 'Johnson & Johnson', market: 'US', sector: 'Healthcare'),
    StockSymbol(symbol: 'HD', name: 'Home Depot', market: 'US', sector: 'Retail'),
    StockSymbol(symbol: 'PG', name: 'Procter & Gamble', market: 'US', sector: 'Consumer'),
    StockSymbol(symbol: 'AMD', name: 'Advanced Micro Devices', market: 'US', sector: 'Technology'),
    StockSymbol(symbol: 'INTC', name: 'Intel Corp.', market: 'US', sector: 'Technology'),
    StockSymbol(symbol: 'NFLX', name: 'Netflix Inc.', market: 'US', sector: 'Entertainment'),
  ];

  static List<StockSymbol> getAll() => [...nse, ...us];

  static List<StockSymbol> getByMarket(String market) =>
      getAll().where((s) => s.market == market).toList();

  static List<String> get sectors =>
      getAll().map((s) => s.sector).toSet().toList()..sort();
}
