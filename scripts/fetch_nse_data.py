"""
fetch_nse_data.py
=================
Fetches OHLCV candle data for all NSE stocks via yfinance and upserts the
results into the Supabase `stock_candles` table used by the StockX Flutter app.

Usage
-----
    # Install dependencies once:
    pip install -r requirements.txt

    # Run with defaults (daily candles, 1-year history):
    python fetch_nse_data.py

    # Weekly candles:
    python fetch_nse_data.py --timeframe 1wk

    # Limit to first 100 symbols (useful for testing):
    python fetch_nse_data.py --limit 100

    # Dry-run — fetch but do NOT write to Supabase:
    python fetch_nse_data.py --dry-run

Options
-------
    --timeframe   1d | 1wk | 1mo  (default: 1d)
    --limit       N               Only process first N symbols
    --batch-size  N               Symbols per batch  (default: from config.py)
    --delay       SECS            Sleep between batches (default: from config.py)
    --dry-run                     Fetch only, skip Supabase writes
    --resume                      Skip symbols already in Supabase
"""

import argparse
import sys
import time
import traceback
from datetime import datetime, timezone

import pandas as pd
import yfinance as yf
from supabase import create_client, Client
from tqdm import tqdm

import config

# ── NSE symbol list (base symbols, .NS suffix added automatically) ────────────
NSE_SYMBOLS = [
    "20MICRONS", "21STCENMGM", "360ONE", "3IINFOLTD", "3MINDIA", "3PLAND",
    "5PAISA", "63MOONS", "A2ZINFRA", "AAATECH", "AADHARHFC", "AAKASH",
    "AAREYDRUGS", "AARON", "AARTECH", "AARTIDRUGS", "AARTIIND", "AARTIPHARM",
    "AARTISURF", "AARVI", "AAVAS", "ABAN", "ABB", "ABBOTINDIA", "ABCAPITAL",
    "ABDL", "ABFRL", "ABINFRA", "ABMINTLLTD", "ABREL", "ABSLAMC", "ACC",
    "ACCELYA", "ACCURACY", "ACE", "ACEINTEG", "ACI", "ACL", "ACMESOLAR",
    "ADANIENSOL", "ADANIENT", "ADANIGREEN", "ADANIPORTS", "ADANIPOWER",
    "ADFFOODS", "ADL", "ADOR", "ADROITINFO", "ADSL", "ADVANIHOTR",
    "ADVENZYMES", "AEGISLOG", "AEROFLEX", "AETHER", "AFCONS", "AFFLE",
    "AFFORDABLE", "AFIL", "AFSL", "AGARIND", "AGARWALEYE", "AGI", "AGIIL",
    "AGRITECH", "AGROPHOS", "AGSTRA", "AHLADA", "AHLEAST", "AHLUCONT",
    "AIAENG", "AIIL", "AIRAN", "AIROLAM", "AJANTPHARM", "AJAXENGG", "AJMERA",
    "AJOONI", "AKASH", "AKG", "AKI", "AKSHAR", "AKSHARCHEM", "AKSHOPTFBR",
    "AKUMS", "AKZOINDIA", "ALANKIT", "ALBERTDAVD", "ALEMBICLTD", "ALICON",
    "ALIVUS", "ALKALI", "ALKEM", "ALKYLAMINE", "ALLCARGO", "ALLDIGI",
    "ALMONDZ", "ALOKINDS", "ALPA", "ALPHAGEO", "ALPSINDUS", "AMBER",
    "AMBICAAGAR", "AMBIKCO", "AMBUJACEM", "AMDIND", "AMJLAND", "AMNPLST",
    "AMRUTANJAN", "ANANDRATHI", "ANANTRAJ", "ANDHRAPAP", "ANDHRSUGAR",
    "ANGELONE", "ANIKINDS", "ANMOL", "ANSALAPI", "ANTGRAPHIC", "ANUHPHR",
    "ANUP", "ANURAS", "APARINDS", "APCL", "APCOTEXIND", "APEX", "APLAPOLLO",
    "APLLTD", "APOLLO", "APOLLOHOSP", "APOLLOPIPE", "APOLLOTYRE", "APOLSINHOT",
    "APTECHT", "APTUS", "ARCHIDPLY", "ARCHIES", "ARE&M", "ARENTERP", "ARIES",
    "ARIHANTCAP", "ARIHANTSUP", "ARKADE", "ARMANFIN", "AROGRANITE",
    "ARROWGREEN", "ARSHIYA", "ARTEMISMED", "ARTNIRMAN", "ARVEE", "ARVIND",
    "ARVINDFASN", "ARVSMART", "ASAHIINDIA", "ASAHISONG", "ASAL", "ASALCBR",
    "ASHAPURMIN", "ASHIANA", "ASHIMASYN", "ASHOKA", "ASHOKAMET", "ASHOKLEY",
    "ASIANENE", "ASIANHOTNR", "ASIANPAINT", "ASIANTILES", "ASKAUTOLTD",
    "ASMS", "ASPINWALL", "ASTEC", "ASTERDM", "ASTRAL", "ASTRAMICRO",
    "ASTRAZEN", "ASTRON", "ATALREAL", "ATAM", "ATGL", "ATL", "ATLANTAA",
    "ATLASCYCLE", "ATUL", "ATULAUTO", "AUBANK", "AURIONPRO", "AUROPHARMA",
    "AURUM", "AUSOMENT", "AUTOAXLES", "AUTOIND", "AVADHSUGAR", "AVALON",
    "AVANTEL", "AVANTIFEED", "AVG", "AVL", "AVONMORE", "AVROIND", "AVTNPL",
    "AWFIS", "AWHCL", "AWL", "AXISBANK", "AXISCADES", "AXITA", "AYMSYNTEX",
    "AZAD", "BAFNAPH", "BAGFILMS", "BAIDFIN", "BAJAJ-AUTO", "BAJAJCON",
    "BAJAJELEC", "BAJAJFINSV", "BAJAJHCARE", "BAJAJHFL", "BAJAJHIND",
    "BAJAJHLDNG", "BAJAJINDEF", "BAJEL", "BAJFINANCE", "BALAJEE", "BALAJITELE",
    "BALAMINES", "BALAXI", "BALKRISHNA", "BALKRISIND", "BALMLAWRIE",
    "BALPHARMA", "BALRAMCHIN", "BALUFORGE", "BANARBEADS", "BANARISUG",
    "BANCOINDIA", "BANDHANBNK", "BANG", "BANKA", "BANKBARODA", "BANKINDIA",
    "BANSALWIRE", "BANSWRAS", "BASF", "BASML", "BATAINDIA", "BAYERCROP",
    "BBL", "BBOX", "BBTC", "BBTCL", "BCLIND", "BCONCEPTS", "BDL", "BEARDSELL",
    "BECTORFOOD", "BEDMUTHA", "BEL", "BEML", "BEPL", "BERGEPAINT", "BESTAGRO",
    "BFINVEST", "BFUTILITIE", "BGRENERGY", "BHAGCHEM", "BHAGERIA", "BHAGYANGR",
    "BHANDARI", "BHARATFORG", "BHARATGEAR", "BHARATRAS", "BHARATSE",
    "BHARATWIRE", "BHARTIARTL", "BHARTIHEXA", "BHEL", "BIGBLOC", "BIKAJI",
    "BIL", "BIOCON", "BIOFILCHEM", "BIRLACABLE", "BIRLACORPN", "BIRLAMONEY",
    "BIRLANU", "BLACKBUCK", "BLAL", "BLBLIMITED", "BLISSGVS", "BLKASHYAP",
    "BLS", "BLSE", "BLUECHIP", "BLUECOAST", "BLUEDART", "BLUEJET",
    "BLUESTARCO", "BODALCHEM", "BOHRAIND", "BOMDYEING", "BOROLTD", "BORORENEW",
    "BOROSCI", "BOSCHLTD", "BPCL", "BPL", "BRIGADE", "BRITANNIA", "BRNL",
    "BROOKS", "BSE", "BSHSL", "BSL", "BSOFT", "BTML", "BUTTERFLY", "BVCL",
    "BYKE", "CALSOFT", "CAMLINFINE", "CAMPUS", "CAMS", "CANBK", "CANFINHOME",
    "CANTABIL", "CAPACITE", "CAPITALSFB", "CAPLIPOINT", "CAPTRUST",
    "CARBORUNIV", "CARERATING", "CARRARO", "CARTRADE", "CARYSIL", "CASTROLIND",
    "CCCL", "CCHHL", "CCL", "CDSL", "CEATLTD", "CEIGALL", "CELEBRITY",
    "CELLO", "CENTENKA", "CENTEXT", "CENTRALBK", "CENTRUM", "CENTUM",
    "CENTURYPLY", "CERA", "CEREBRAINT", "CESC", "CEWATER", "CGCL", "CGPOWER",
    "CHALET", "CHAMBLFERT", "CHEMBOND", "CHEMCON", "CHEMFAB", "CHEMPLASTS",
    "CHENNPETRO", "CHEVIOT", "CHOICEIN", "CHOLAFIN", "CHOLAHLDNG", "CIEINDIA",
    "CIFL", "CIGNITITEC", "CINELINE", "CINEVISTA", "CIPLA", "CLEAN",
    "CLEDUCATE", "CLSEL", "CMSINFO", "COALINDIA", "COASTCORP", "COCHINSHIP",
    "COFFEEDAY", "COFORGE", "COLPAL", "COMPINFO", "COMPUSOFT", "COMSYN",
    "CONCOR", "CONCORDBIO", "CONFIPET", "CONSOFINVT", "CONTROLPR", "CORALFINAC",
    "CORDSCABLE", "COROMANDEL", "COSMOFIRST", "COUNCODOS", "CPCAP",
    "CRAFTSMAN", "CREATIVE", "CREATIVEYE", "CREDITACC", "CREST", "CRISIL",
    "CROMPTON", "CROWN", "CSBBANK", "CSLFINANCE", "CTE", "CUB", "CUBEXTUB",
    "CUMMINSIND", "CUPID", "CURAA", "CYBERMEDIA", "CYBERTECH", "CYIENT",
    "CYIENTDLM", "DABUR", "DALBHARAT", "DALMIASUG", "DAMCAPITAL", "DAMODARIND",
    "DANGEE", "DATAMATICS", "DATAPATTNS", "DAVANGERE", "DBCORP", "DBEIL",
    "DBL", "DBOL", "DBREALTY", "DBSTOCKBRO", "DCAL", "DCBBANK", "DCI", "DCM",
    "DCMFINSERV", "DCMNVL", "DCMSHRIRAM", "DCMSRIND", "DCW", "DCXINDIA",
    "DDEVPLSTIK", "DECCANCE", "DEEDEV", "DEEPAKFERT", "DEEPAKNTR", "DEEPINDS",
    "DELHIVERY", "DELPHIFX", "DELTACORP", "DELTAMAGNT", "DEN", "DENORA",
    "DENTA", "DEVIT", "DEVYANI", "DGCONTENT", "DHAMPURSUG", "DHANBANK",
    "DHANUKA", "DHARMAJ", "DHRUV", "DHUNINV", "DIACABS", "DIAMINESQ",
    "DIAMONDYD", "DICIND", "DIFFNKG", "DIGIDRIVE", "DIGISPICE", "DIGJAMLMTD",
    "DIL", "DISHTV", "DIVGIITTS", "DIVISLAB", "DIXON", "DJML", "DLF",
    "DLINKINDIA", "DMART", "DMCC", "DNAMEDIA", "DODLA", "DOLATALGO", "DOLLAR",
    "DOLPHIN", "DOMS", "DONEAR", "DPABHUSHAN", "DPSCLTD", "DPWIRES",
    "DRCSYSTEMS", "DREAMFOLKS", "DREDGECORP", "DRREDDY", "DSSL", "DTIL",
    "DUCON", "DVL", "DWARKESH", "DYCL", "DYNAMATECH", "DYNPRO", "E2E",
    "EASEMYTRIP", "ECLERX", "ECOSMOBLTY", "EDELWEISS", "EICHERMOT", "EIDPARRY",
    "EIEL", "EIFFL", "EIHAHOTELS", "EIHOTEL", "EIMCOELECO", "EKC", "ELDEHSG",
    "ELECON", "ELECTCAST", "ELECTHERM", "ELGIEQUIP", "ELGIRUBCO", "ELIN",
    "EMAMILTD", "EMAMIPAP", "EMAMIREAL", "EMBDL", "EMCURE", "EMIL", "EMKAY",
    "EMMBI", "EMSLIMITED", "EMUDHRA", "ENDURANCE", "ENERGYDEV", "ENGINERSIN",
    "ENIL", "ENTERO", "EPACK", "EPIGRAL", "EPL", "EQUIPPP", "EQUITASBNK",
    "ERIS", "ESABINDIA", "ESAFSFB", "ESCORTS", "ESSARSHPNG", "ESSENTIA",
    "ESTER", "ETERNAL", "ETHOSLTD", "EUREKAFORB", "EUROTEXIND", "EVEREADY",
    "EVERESTIND", "EXCEL", "EXCELINDUS", "EXICOM", "EXIDEIND", "EXPLEOSOL",
    "EXXARO", "FACT", "FAIRCHEMOR", "FAZE3Q", "FCL", "FCSSOFT", "FDC",
    "FEDERALBNK", "FEDFINA", "FEL", "FELDVR", "FIBERWEB", "FIEMIND",
    "FILATEX", "FILATFASH", "FINCABLES", "FINEORG", "FINOPB", "FINPIPE",
    "FIRSTCRY", "FIVESTAR", "FLAIR", "FLEXITUFF", "FLFL", "FLUOROCHEM",
    "FMGOETZE", "FMNL", "FOCUS", "FOODSIN", "FORCEMOT", "FORTIS", "FOSECOIND",
    "FSC", "FSL", "FUSION", "GABRIEL", "GAEL", "GAIL", "GALAPREC",
    "GALAXYSURF", "GALLANTT", "GANDHAR", "GANDHITUBE", "GANECOS", "GANESHBE",
    "GANGAFORGE", "GANGESSECU", "GARFIBRES", "GARUDA", "GATECH", "GATECHDVR",
    "GATEWAY", "GAYAHWS", "GAYAPROJ", "GEECEE", "GEEKAYWIRE", "GENCON",
    "GENESYS", "GENSOL", "GENUSPAPER", "GENUSPOWER", "GEOJITFSL", "GESHIP",
    "GFLLIMITED", "GHCL", "GHCLTEXTIL", "GICHSGFIN", "GICRE", "GILLANDERS",
    "GILLETTE", "GINNIFILA", "GIPCL", "GKWLIMITED", "GLAND", "GLAXO",
    "GLENMARK", "GLFL", "GLOBAL", "GLOBALE", "GLOBALVECT", "GLOBE",
    "GLOBUSSPR", "GLOSTERLTD", "GMBREW", "GMDCLTD", "GMMPFAUDLR", "GMRAIRPORT",
    "GNA", "GNFC", "GOACARBON", "GOCLCORP", "GOCOLORS", "GODAVARIB",
    "GODFRYPHLP", "GODIGIT", "GODREJAGRO", "GODREJCP", "GODREJIND",
    "GODREJPROP", "GOENKA", "GOKEX", "GOKUL", "GOKULAGRO", "GOLDENTOBC",
    "GOLDIAM", "GOLDTECH", "GOODLUCK", "GOPAL", "GOYALALUM", "GPIL", "GPPL",
    "GPTHEALTH", "GPTINFRA", "GRANULES", "GRAPHITE", "GRASIM", "GRAVITA",
    "GREAVESCOT", "GREENLAM", "GREENPANEL", "GREENPLY", "GREENPOWER",
    "GRINDWELL", "GRINFRA", "GRMOVER", "GROBTEA", "GRPLTD", "GRSE",
    "GRWRHITECH", "GSFC", "GSLSU", "GSPL", "GSS", "GTECJAINX", "GTL",
    "GTLINFRA", "GTPL", "GUFICBIO", "GUJALKALI", "GUJAPOLLO", "GUJGASLTD",
    "GUJRAFFIA", "GUJTHEM", "GULFOILLUB", "GULFPETRO", "GULPOLY", "GVKPIL",
    "GVPTECH", "HAL", "HAPPSTMNDS", "HAPPYFORGE", "HARDWYN", "HARIOMPIPE",
    "HARRMALAYA", "HARSHA", "HATHWAY", "HATSUN", "HAVELLS", "HAVISHA",
    "HBLENGINE", "HBSL", "HCC", "HCG", "HCLTECH", "HDFCAMC", "HDFCBANK",
    "HDFCLIFE", "HDIL", "HEADSUP", "HECPROJECT", "HEG", "HEIDELBERG",
    "HEMIPROP", "HERANBA", "HERCULES", "HERITGFOOD", "HEROMOTOCO", "HESTERBIO",
    "HEUBACHIND", "HEXATRADEX", "HEXT", "HFCL", "HGINFRA", "HGS", "HIKAL",
    "HILTON", "HIMATSEIDE", "HINDALCO", "HINDCOMPOS", "HINDCON", "HINDCOPPER",
    "HINDOILEXP", "HINDPETRO", "HINDUNILVR", "HINDWAREAP", "HINDZINC",
    "HIRECT", "HISARMETAL", "HITECH", "HITECHCORP", "HITECHGEAR", "HLEGLAS",
    "HLVLTD", "HMAAGRO", "HMT", "HMVL", "HNDFDS", "HOMEFIRST", "HONASA",
    "HONAUT", "HONDAPOWER", "HPAL", "HPIL", "HPL", "HSCL", "HTMEDIA",
    "HUBTOWN", "HUDCO", "HUHTAMAKI", "HYBRIDFIN", "HYUNDAI", "ICDSLTD",
    "ICEMAKE", "ICICIBANK", "ICICIGI", "ICICIPRULI", "ICIL", "ICRA", "IDBI",
    "IDEA", "IDEAFORGE", "IDFCFIRSTB", "IEX", "IFBAGRO", "IFBIND", "IFCI",
    "IFGLEXPOR", "IGARASHI", "IGIL", "IGL", "IGPL", "IIFL", "IIFLCAPS",
    "IITL", "IKIO", "IKS", "IMAGICAA", "IMFA", "IMPAL", "IMPEXFERRO",
    "INCREDIBLE", "INDBANK", "INDGN", "INDHOTEL", "INDIACEM", "INDIAGLYCO",
    "INDIAMART", "INDIANB", "INDIANCARD", "INDIANHUME", "INDIASHLTR", "INDIGO",
    "INDIGOPNTS", "INDNIPPON", "INDOAMIN", "INDOBORAX", "INDOCO", "INDOFARM",
    "INDORAMA", "INDOSTAR", "INDOTECH", "INDOTHAI", "INDOUS", "INDOWIND",
    "INDRAMEDCO", "INDSWFTLAB", "INDTERRAIN", "INDUSINDBK", "INDUSTOWER",
    "INFIBEAM", "INFOBEAN", "INFOMEDIA", "INFY", "INGERRAND", "INNOVACAP",
    "INNOVANA", "INOXGREEN", "INOXINDIA", "INOXWIND", "INSECTICID",
    "INSPIRISYS", "INTELLECT", "INTENTECH", "INTERARCH", "INTLCONV",
    "INVENTURE", "IOB", "IOC", "IOLCP", "IONEXCHANG", "IPCALAB", "IPL",
    "IRB", "IRCON", "IRCTC", "IREDA", "IRFC", "IRIS", "IRISDOREME",
    "IRMENERGY", "ISFT", "ISGEC", "ISHANCH", "ITC", "ITCHOTELS", "ITDC",
    "ITI", "IVC", "IVP", "IXIGO", "IZMO", "JAGRAN", "JAGSNPHARM", "JAIBALAJI",
    "JAICORPLTD", "JAIPURKURT", "JAMNAAUTO", "JASH", "JAYAGROGN", "JAYBARMARU",
    "JAYNECOIND", "JAYSREETEA", "JBCHEPHARM", "JBMA", "JCHAC", "JETFREIGHT",
    "JGCHEM", "JHS", "JINDALPHOT", "JINDALPOLY", "JINDALSAW", "JINDALSTEL",
    "JINDRILL", "JINDWORLD", "JIOFIN", "JISLDVREQS", "JISLJALEQS", "JITFINFRA",
    "JKCEMENT", "JKIL", "JKLAKSHMI", "JKPAPER", "JKTYRE", "JLHL", "JMA",
    "JMFINANCIL", "JNKINDIA", "JOCIL", "JPOLYINVST", "JPPOWER", "JSFB",
    "JSL", "JSWENERGY", "JSWHL", "JSWINFRA", "JSWSTEEL", "JTEKTINDIA",
    "JTLIND", "JUBLCPL", "JUBLFOOD", "JUBLINGREA", "JUBLPHARMA", "JUNIPER",
    "JUSTDIAL", "JWL", "JYOTHYLAB", "JYOTICNC", "JYOTISTRUC", "KABRAEXTRU",
    "KAJARIACER", "KAKATCEM", "KALAMANDIR", "KALYANI", "KALYANIFRG",
    "KALYANKJIL", "KAMATHOTEL", "KAMDHENU", "KAMOPAINTS", "KANANIIND",
    "KANORICHEM", "KANPRPLA", "KANSAINER", "KAPSTON", "KARMAENG", "KARURVYSYA",
    "KAUSHALYA", "KAYA", "KAYNES", "KCP", "KCPSUGIND", "KDDL", "KEC", "KECL",
    "KEEPLEARN", "KEI", "KELLTONTEC", "KERNEX", "KESORAMIND", "KEYFINSERV",
    "KFINTECH", "KHADIM", "KHAICHEM", "KHAITANLTD", "KHANDSE", "KICL",
    "KILITCH", "KIMS", "KINGFA", "KIOCL", "KIRIINDUS", "KIRLOSBROS",
    "KIRLOSENG", "KIRLOSIND", "KIRLPNU", "KITEX", "KKCL", "KMEW", "KMSUGAR",
    "KNRCON", "KOHINOOR", "KOKUYOCMLN", "KOLTEPATIL", "KOPRAN", "KOTAKBANK",
    "KOTARISUG", "KOTHARIPET", "KOTHARIPRO", "KPEL", "KPIGREEN", "KPIL",
    "KPITTECH", "KPRMILL", "KRBL", "KREBSBIO", "KRIDHANINF", "KRISHANA",
    "KRITI", "KRITIKA", "KRITINUT", "KRN", "KRONOX", "KROSS", "KRSNAA",
    "KRYSTAL", "KSB", "KSCL", "KSHITIJPOL", "KSL", "KSOLVES", "KTKBANK",
    "KUANTUM", "LAGNAM", "LAKPRE", "LAL", "LALPATHLAB", "LAMBODHARA",
    "LANCORHOL", "LANDMARK", "LAOPALA", "LASA", "LATENTVIEW", "LATTEYS",
    "LAURUSLABS", "LAXMICOT", "LAXMIDENTL", "LCCINFOTEC", "LEMONTREE",
    "LEXUS", "LFIC", "LGBBROSLTD", "LGHL", "LIBAS", "LIBERTSHOE", "LICHSGFIN",
    "LICI", "LIKHITHA", "LINCOLN", "LINDEINDIA", "LLOYDSENGG", "LLOYDSENT",
    "LLOYDSME", "LMW", "LODHA", "LOKESHMACH", "LORDSCHLO", "LOTUSEYE",
    "LOVABLE", "LOYALTEX", "LPDC", "LT", "LTF", "LTFOODS", "LTIM", "LTTS",
    "LUMAXIND", "LUMAXTECH", "LUPIN", "LUXIND", "LXCHEM", "LYKALABS",
    "LYPSAGEMS", "MAANALU", "MACPOWER", "MADHAV", "MADHUCON", "MADRASFERT",
    "MAGADSUGAR", "MAGNUM", "MAHABANK", "MAHAPEXLTD", "MAHASTEEL", "MAHEPC",
    "MAHESHWARI", "MAHLIFE", "MAHLOG", "MAHSCOOTER", "MAHSEAMLES",
    "MAITHANALL", "MALLCOM", "MALUPAPER", "MAMATA", "MANAKALUCO", "MANAKCOAT",
    "MANAKSIA", "MANAKSTEEL", "MANALIPETC", "MANAPPURAM", "MANBA", "MANCREDIT",
    "MANGALAM", "MANGLMCEM", "MANINDS", "MANINFRA", "MANKIND", "MANOMAY",
    "MANORAMA", "MANORG", "MANUGRAPH", "MANYAVAR", "MAPMYINDIA", "MARALOVER",
    "MARATHON", "MARICO", "MARINE", "MARKSANS", "MARSHALL", "MARUTI", "MASFIN",
    "MASKINVEST", "MASTEK", "MASTERTR", "MATRIMONY", "MAWANASUG", "MAXESTATES",
    "MAXHEALTH", "MAXIND", "MAYURUNIQ", "MAZDA", "MAZDOCK", "MBAPL",
    "MBLINFRA", "MCL", "MCLEODRUSS", "MCLOUD", "MCX", "MEDANTA", "MEDIASSIST",
    "MEDICAMEQ", "MEDICO", "MEDPLUS", "MEGASOFT", "MEGASTAR", "MENONBE",
    "MEP", "METROBRAND", "METROPOLIS", "MFML", "MFSL", "MGEL", "MGL",
    "MHLXMIRU", "MHRIL", "MICEL", "MIDHANI", "MINDACORP", "MINDTECK",
    "MIRCELECTR", "MIRZAINT", "MITCON", "MITTAL", "MKPL", "MMFL", "MMP",
    "MMTC", "MOBIKWIK", "MODIRUBBER", "MODISONLTD", "MODTHREAD", "MOHITIND",
    "MOIL", "MOKSH", "MOL", "MOLDTECH", "MOLDTKPAC", "MONARCH", "MONTECARLO",
    "MORARJEE", "MOREPENLAB", "MOSCHIP", "MOTHERSON", "MOTILALOFS", "MOTISONS",
    "MOTOGENFIN", "MPHASIS", "MPSLTD", "MRF", "MRPL", "MSPL", "MSTCLTD",
    "MSUMI", "MTARTECH", "MTEDUCARE", "MTNL", "MUFIN", "MUFTI", "MUKANDLTD",
    "MUKKA", "MUKTAARTS", "MUNJALAU", "MUNJALSHOW", "MURUDCERA", "MUTHOOTCAP",
    "MUTHOOTFIN", "MUTHOOTMF", "MVGJL", "NACLIND", "NAGAFERT", "NAGREEKCAP",
    "NAGREEKEXP", "NAHARCAP", "NAHARINDUS", "NAHARPOLY", "NAHARSPING",
    "NARMADA", "NATCAPSUQ", "NATCOPHARM", "NATHBIOGEN", "NATIONALUM", "NAUKRI",
    "NAVA", "NAVINFLUOR", "NAVKARCORP", "NAVKARURB", "NAVNETEDUL", "NAZARA",
    "NBCC", "NBIFIN", "NCC", "NCLIND", "NDGL", "NDL", "NDLVENTURE", "NDRAUTO",
    "NDTV", "NECCLTD", "NECLIFE", "NELCAST", "NELCO", "NEOGEN", "NESCO",
    "NESTLEIND", "NETWEB", "NETWORK18", "NEULANDLAB", "NEWGEN", "NEXTMEDIA",
    "NFL", "NGIL", "NGLFINE", "NH", "NHPC", "NIACL", "NIBE", "NIBL",
    "NIITLTD", "NIITMTS", "NILAINFRA", "NILASPACES", "NILKAMAL", "NINSYS",
    "NIPPOBATRY", "NIRAJ", "NIRAJISPAT", "NITCO", "NITINSPIN", "NITIRAJ",
    "NIVABUPA", "NKIND", "NLCINDIA", "NMDC", "NOCIL", "NOIDATOLL",
    "NORBTEAEXP", "NORTHARC", "NOVAAGRI", "NRAIL", "NRBBEARING", "NRL",
    "NSIL", "NSLNISP", "NTPC", "NTPCGREEN", "NUCLEUS", "NURECA", "NUVAMA",
    "NUVOCO", "NYKAA", "OAL", "OBCL", "OBEROIRLTY", "OCCLLTD", "ODIGMA",
    "OFSS", "OIL", "OILCOUNTUB", "OLAELEC", "OLECTRA", "OMAXAUTO", "OMAXE",
    "OMINFRAL", "OMKARCHEM", "ONELIFECAP", "ONEPOINT", "ONESOURCE", "ONGC",
    "ONMOBILE", "ONWARDTEC", "OPTIEMUS", "ORBTEXP", "ORCHASP", "ORCHPHARMA",
    "ORICONENT", "ORIENTALTL", "ORIENTBELL", "ORIENTCEM", "ORIENTCER",
    "ORIENTELEC", "ORIENTHOT", "ORIENTLTD", "ORIENTPPR", "ORIENTTECH",
    "ORISSAMINE", "ORTEL", "ORTINGLOBE", "OSIAHYPER", "OSWALAGRO",
    "OSWALGREEN", "OSWALSEEDS", "PAGEIND", "PAISALO", "PAKKA", "PALASHSECU",
    "PALREDTEC", "PANACEABIO", "PANACHE", "PANAMAPET", "PANSARI", "PAR",
    "PARACABLES", "PARADEEP", "PARAGMILK", "PARAS", "PARASPETRO", "PARKHOTELS",
    "PARSVNATH", "PASUPTAC", "PATANJALI", "PATELENG", "PATINTLOG", "PAVNAIND",
    "PAYTM", "PCBL", "PCJEWELLER", "PDMJEPAPER", "PDSL", "PEARLPOLY",
    "PENIND", "PENINLAND", "PERSISTENT", "PETRONET", "PFC", "PFIZER",
    "PFOCUS", "PFS", "PGEL", "PGHH", "PGHL", "PGIL", "PHOENIXLTD",
    "PIDILITIND", "PIGL", "PIIND", "PILANIINVS", "PILITA", "PIONEEREMB",
    "PITTIENG", "PIXTRANS", "PKTEA", "PLASTIBLEN", "PLATIND", "PLAZACABLE",
    "PNB", "PNBGILTS", "PNBHOUSING", "PNC", "PNCINFRA", "PNJGB", "POCL",
    "PODDARMENT", "POKARNA", "POLICYBZR", "POLYCAB", "POLYMED", "POLYPLEX",
    "PONNIERODE", "POONAWALLA", "POWERGRID", "POWERINDIA", "POWERMECH",
    "PPAP", "PPL", "PPLPHARMA", "PRABHA", "PRAENG", "PRAJIND", "PRAKASH",
    "PRAKASHSTL", "PRAXIS", "PRECAM", "PRECOT", "PRECWIRE", "PREMEXPLN",
    "PREMIER", "PREMIERENE", "PREMIERPOL", "PRESTIGE", "PRICOLLTD",
    "PRIMESECU", "PRINCEPIPE", "PRITI", "PRITIKAUTO", "PRIVISCL", "PROTEAN",
    "PROZONER", "PRSMJOHNSN", "PRUDENT", "PRUDMOULI", "PSB", "PSPPROJECT",
    "PTC", "PTCIL", "PTL", "PUNJABCHEM", "PURVA", "PVP", "PVRINOX", "PVSL",
    "PYRAMID", "QPOWER", "QUADFUTURE", "QUESS", "QUICKHEAL", "RACE",
    "RACLGEAR", "RADAAN", "RADHIKAJWE", "RADIANTCMS", "RADICO", "RADIOCITY",
    "RAILTEL", "RAIN", "RAINBOW", "RAJESHEXPO", "RAJMET", "RAJRATAN",
    "RAJRILTD", "RAJSREESUG", "RAJTV", "RALLIS", "RAMANEWS", "RAMAPHO",
    "RAMASTEEL", "RAMCOCEM", "RAMCOIND", "RAMCOSYS", "RAMKY", "RAMRAT",
    "RANASUG", "RANEHOLDIN", "RATEGAIN", "RATNAMANI", "RATNAVEER", "RAYMOND",
    "RAYMONDLSL", "RBA", "RBLBANK", "RBZJEWEL", "RCF", "RCOM", "RECLTD",
    "REDINGTON", "REDTAPE", "REFEX", "REGENCERAM", "RELAXO", "RELCHEMQ",
    "RELIABLE", "RELIANCE", "RELIGARE", "RELINFRA", "RELTD", "REMSONSIND",
    "RENUKA", "REPCOHOME", "REPL", "REPRO", "RESPONIND", "RETAIL", "RGL",
    "RHFL", "RHIM", "RHL", "RICOAUTO", "RIIL", "RISHABH", "RITCO", "RITES",
    "RKDL", "RKEC", "RKFORGE", "RKSWAMY", "RML", "ROHLTD", "ROLEXRINGS",
    "ROLLT", "ROLTA", "ROML", "ROSSARI", "ROSSELLIND", "ROSSTECH", "ROTO",
    "ROUTE", "RPEL", "RPGLIFE", "RPOWER", "RPPINFRA", "RPPL", "RPSGVENT",
    "RPTECH", "RRKABEL", "RSSOFTWARE", "RSWM", "RSYSTEMS", "RTNINDIA",
    "RTNPOWER", "RUBFILA", "RUBYMILLS", "RUCHINFRA", "RUCHIRA", "RUPA",
    "RUSHIL", "RUSTOMJEE", "RVHL", "RVNL", "RVTH", "SABEVENTS", "SABTNL",
    "SADBHAV", "SADBHIN", "SADHNANIQ", "SAFARI", "SAGARDEEP", "SAGCEM",
    "SAGILITY", "SAHYADRI", "SAIL", "SAILIFE", "SAKAR", "SAKHTISUG",
    "SAKSOFT", "SAKUMA", "SALASAR", "SALONA", "SALSTEEL", "SALZERELEC",
    "SAMBHAAV", "SAMHI", "SAMMAANCAP", "SAMPANN", "SANATHAN", "SANCO",
    "SANDESH", "SANDHAR", "SANDUMA", "SANGAMIND", "SANGHIIND", "SANGHVIMOV",
    "SANGINITA", "SANOFI", "SANOFICONR", "SANSERA", "SANSTAR", "SANWARIA",
    "SAPPHIRE", "SARDAEN", "SAREGAMA", "SARLAPOLY", "SARVESHWAR", "SASKEN",
    "SASTASUNDR", "SATIA", "SATIN", "SAURASHCEM", "SBC", "SBCL", "SBFC",
    "SBGLP", "SBICARD", "SBILIFE", "SBIN", "SCHAEFFLER", "SCHAND",
    "SCHNEIDER", "SCI", "SCILAL", "SCPL", "SDBL", "SEAMECLTD", "SECMARK",
    "SECURKLOUD", "SEJALLTD", "SELMC", "SEMAC", "SENCO", "SENORES", "SEPC",
    "SEQUENT", "SERVOTECH", "SESHAPAPER", "SETCO", "SETUINFRA", "SEYAIND",
    "SFL", "SGIL", "SGL", "SGLTL", "SHAH", "SHAHALLOYS", "SHAILY",
    "SHAKTIPUMP", "SHALBY", "SHALPAINTS", "SHANKARA", "SHANTI", "SHANTIGEAR",
    "SHARDACROP", "SHARDAMOTR", "SHAREINDIA", "SHEKHAWATI", "SHEMAROO",
    "SHILPAMED", "SHIVALIK", "SHIVAMAUTO", "SHIVAMILLS", "SHIVATEX", "SHK",
    "SHOPERSTOP", "SHRADHA", "SHREDIGCEM", "SHREECEM", "SHREEPUSHK",
    "SHREERAMA", "SHRENIK", "SHREYANIND", "SHRIPISTON", "SHRIRAMFIN",
    "SHRIRAMPPS", "SHYAMCENT", "SHYAMMETL", "SHYAMTEL", "SICALLOG",
    "SIEMENS", "SIGACHI", "SIGIND", "SIGMA", "SIGNATURE", "SIGNPOST",
    "SIKKO", "SIL", "SILGO", "SILINV", "SILLYMONKS", "SILVERTUC", "SIMBHALS",
    "SIMPLEXINF", "SINCLAIR", "SINDHUTRAD", "SINTERCOM", "SIRCA", "SIS",
    "SITINET", "SIYSIL", "SJS", "SJVN", "SKFINDIA", "SKIPPER", "SKMEGGPROD",
    "SKYGOLD", "SMARTLINK", "SMCGLOBAL", "SMLT", "SMSLIFE", "SMSPHARMA",
    "SNOWMAN", "SOBHA", "SOFTTECH", "SOLARA", "SOLARINDS", "SOMANYCERA",
    "SOMATEX", "SOMICONVEY", "SONACOMS", "SONAMLTD", "SONATSOFTW", "SOTL",
    "SOUTHBANK", "SOUTHWEST", "SPAL", "SPANDANA", "SPARC", "SPCENET",
    "SPECIALITY", "SPECTRUM", "SPENCERS", "SPIC", "SPLIL", "SPLPETRO",
    "SPMLINFRA", "SPORTKING", "SRD", "SREEL", "SRF", "SRGHFL", "SRHHYPOLTD",
    "SRM", "SRPL", "SSDL", "SSWL", "STALLION", "STANLEY", "STAR",
    "STARCEMENT", "STARHEALTH", "STARPAPER", "STARTECK", "STCINDIA",
    "STEELCAS", "STEELCITY", "STEELXIND", "STEL", "STERTOOLS", "STLTECH",
    "STOVEKRAFT", "STYLAMIND", "STYLEBAAZA", "STYRENIX", "SUBEXLTD", "SUBROS",
    "SUDARSCHEM", "SUKHJITS", "SULA", "SUMICHEM", "SUMIT", "SUMMITSEC",
    "SUNCLAY", "SUNDARAM", "SUNDARMFIN", "SUNDRMBRAK", "SUNDRMFAST", "SUNDROP",
    "SUNFLAG", "SUNPHARMA", "SUNTECK", "SUNTV", "SUPERHOUSE", "SUPERSPIN",
    "SUPRAJIT", "SUPREME", "SUPREMEENG", "SUPREMEIND", "SUPREMEINF", "SUPRIYA",
    "SURAJEST", "SURAJLTD", "SURAKSHA", "SURANASOL", "SURYALAXMI",
    "SURYAROSNI", "SURYODAY", "SUTLEJTEX", "SUULD", "SUVEN", "SUVIDHAA",
    "SUYOG", "SUZLON", "SVLL", "SVPGLOB", "SWARAJENG", "SWELECTES", "SWIGGY",
    "SWSOLAR", "SYMPHONY", "SYNCOMF", "SYNGENE", "SYRMA", "TAINWALCHM",
    "TAJGVK", "TAKE", "TALBROAUTO", "TANLA", "TARACHAND", "TARAPUR", "TARC",
    "TARIL", "TARMAT", "TARSONS", "TASTYBITE", "TATACHEM", "TATACOMM",
    "TATACONSUM", "TATAELXSI", "TATAINVEST", "TATAPOWER", "TATASTEEL",
    "TATATECH", "TATVA", "TBOTEK", "TBZ", "TCI", "TCIEXP", "TCIFINANCE",
    "TCPLPACK", "TCS", "TDPOWERSYS", "TEAMLEASE", "TECHM", "TECHNOE", "TEGA",
    "TEJASNET", "TEMBO", "TERASOFT", "TEXINFRA", "TEXMOPIPES", "TEXRAIL",
    "TFCILTD", "TFL", "TGBHOTELS", "THANGAMAYL", "THEINVEST", "THEJO",
    "THEMISMED", "THERMAX", "THOMASCOOK", "THOMASCOTT", "THYROCARE", "TI",
    "TICL", "TIIL", "TIINDIA", "TIJARIA", "TIL", "TIMETECHNO", "TIMKEN",
    "TINNARUBR", "TIPSFILMS", "TIPSMUSIC", "TIRUMALCHM", "TIRUPATIFL",
    "TITAGARH", "TITAN", "TMB", "TNPETRO", "TNPL", "TNTELE", "TOKYOPLAST",
    "TOLINS", "TORNTPHARM", "TORNTPOWER", "TOTAL", "TOUCHWOOD", "TPHQ",
    "TPLPLASTEH", "TRACXN", "TRANSRAILL", "TRANSWORLD", "TREEHOUSE",
    "TREJHARA", "TREL", "TRENT", "TRF", "TRIDENT", "TRIGYN", "TRITURBINE",
    "TRIVENI", "TRU", "TTKHLTCARE", "TTKPRESTIG", "TTL", "TTML", "TVSELECT",
    "TVSHLTD", "TVSMOTOR", "TVSSCS", "TVSSRICHAK", "TVTODAY", "TVVISION",
    "UBL", "UCAL", "UCOBANK", "UDAICEMENT", "UDS", "UEL", "UFLEX", "UFO",
    "UGARSUGAR", "UGROCAP", "UJJIVANSFB", "ULTRACEMCO", "UMAEXPORTS",
    "UMESLTD", "UNICHEMLAB", "UNIDT", "UNIECOM", "UNIENTER", "UNIINFO",
    "UNIMECH", "UNIONBANK", "UNIPARTS", "UNITDSPR", "UNITECH", "UNITEDPOLY",
    "UNITEDTEA", "UNIVASTU", "UNIVCABLES", "UNIVPHOTO", "UNOMINDA", "UPL",
    "URAVIDEF", "URJA", "USHAMART", "USK", "UTIAMC", "UTKARSHBNK",
    "UTTAMSUGAR", "UYFINCORP", "V2RETAIL", "VADILALIND", "VAIBHAVGBL",
    "VAISHALI", "VAKRANGEE", "VALIANTLAB", "VALIANTORG", "VARDHACRLC",
    "VARDMNPOLY", "VARROC", "VASCONEQ", "VASWANI", "VBL", "VCL", "VEDL",
    "VEEDOL", "VENKEYS", "VENTIVE", "VENUSPIPES", "VENUSREM", "VERANDA",
    "VERTOZ", "VESUVIUS", "VETO", "VGUARD", "VHL", "VHLTD", "VIDHIING",
    "VIJAYA", "VIJIFIN", "VIKASECO", "VIKASLIFE", "VIMTALABS", "VINATIORGA",
    "VINCOFE", "VINDHYATEL", "VINEETLAB", "VINNY", "VINYLINDIA", "VIPCLOTHNG",
    "VIPIND", "VIPULLTD", "VIRINCHI", "VISAKAIND", "VISASTEEL", "VISHNU",
    "VISHWARAJ", "VIVIDHA", "VLEGOV", "VLSFINANCE", "VMART", "VMM", "VOLTAMP",
    "VOLTAS", "VPRPL", "VRAJ", "VRLLOG", "VSSL", "VSTIND", "VSTL",
    "VSTTILLERS", "VTL", "WAAREEENER", "WAAREERTL", "WABAG", "WALCHANNAG",
    "WANBURY", "WCIL", "WEALTH", "WEBELSOLAR", "WEIZMANIND", "WEL", "WELCORP",
    "WELENT", "WELINV", "WELSPUNLIV", "WENDT", "WESTLIFE", "WEWIN", "WHEELS",
    "WHIRLPOOL", "WILLAMAGOR", "WINDLAS", "WINDMACHIN", "WINSOME", "WIPL",
    "WIPRO", "WOCKPHARMA", "WONDERLA", "WSI", "WSTCSTPAPR", "XCHANGING",
    "XELPMOC", "XPROINDIA", "XTGLOBAL", "YASHO", "YATHARTH", "YATRA",
    "YESBANK", "YUKEN", "ZAGGLE", "ZEEL", "ZEELEARN", "ZEEMEDIA",
    "ZENITHEXPO", "ZENITHSTL", "ZENSARTECH", "ZENTEC", "ZFCVINDIA", "ZIMLAB",
    "ZODIAC", "ZODIACLOTH", "ZOTA", "ZUARI", "ZUARIIND", "ZYDUSLIFE",
    "ZYDUSWELL",
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def build_supabase_client() -> Client:
    if "YOUR_PROJECT_ID" in config.SUPABASE_URL or config.SUPABASE_ANON_KEY == "YOUR_ANON_KEY":
        print("ERROR: Supabase credentials not configured.")
        print("  Open scripts/config.py and fill in SUPABASE_URL and SUPABASE_ANON_KEY.")
        sys.exit(1)
    return create_client(config.SUPABASE_URL, config.SUPABASE_ANON_KEY)


def _extract_ohlcv(df: pd.DataFrame) -> pd.DataFrame | None:
    """Normalize a DataFrame to flat Open/High/Low/Close/Volume columns.
    Handles both flat columns and MultiIndex columns from newer yfinance versions."""
    try:
        # If columns are MultiIndex, drop the ticker level to get flat field names
        if isinstance(df.columns, pd.MultiIndex):
            df = df.droplevel(1, axis=1) if df.columns.nlevels == 2 else df
        # Normalize to title-case so 'open' and 'Open' both work
        df.columns = [c.title() if isinstance(c, str) else c for c in df.columns]
        return df[["Open", "High", "Low", "Close", "Volume"]]
    except Exception:
        return None


def fetch_batch(yahoo_symbols: list[str], timeframe: str, period: str) -> dict[str, pd.DataFrame]:
    """
    Download OHLCV data for multiple tickers in ONE HTTP request via yf.download().
    Returns a dict of {yahoo_symbol: DataFrame}, omitting symbols with insufficient data.
    """
    if not yahoo_symbols:
        return {}
    try:
        raw = yf.download(
            tickers=yahoo_symbols,
            period=period,
            interval=timeframe,
            auto_adjust=True,
            actions=False,
            group_by="ticker",
            threads=True,
            progress=False,
        )
    except Exception:
        return {}

    result: dict[str, pd.DataFrame] = {}

    # Single ticker: yf.download may return flat or MultiIndex columns
    if len(yahoo_symbols) == 1:
        sym = yahoo_symbols[0]
        df = _extract_ohlcv(raw.dropna(how="all"))
        if df is not None and len(df) >= config.MIN_BARS:
            df.index = pd.to_datetime(df.index, utc=True)
            result[sym] = df
        return result

    # Multiple tickers: columns are (field, ticker) multi-level
    for sym in yahoo_symbols:
        try:
            ticker_df = raw[sym].dropna(how="all")
            df = _extract_ohlcv(ticker_df)
            if df is not None and len(df) >= config.MIN_BARS:
                df.index = pd.to_datetime(df.index, utc=True)
                result[sym] = df
        except (KeyError, Exception):
            pass

    return result


def df_to_row(symbol: str, timeframe: str, df: pd.DataFrame) -> dict:
    """Convert a DataFrame to the Supabase row format."""
    timestamps = [int(ts.timestamp() * 1000) for ts in df.index]
    return {
        "symbol":       symbol,
        "timeframe":    timeframe,
        "last_updated": datetime.now(timezone.utc).isoformat(),
        "t":            timestamps,
        "o":            [round(float(v), 4) for v in df["Open"]],
        "h":            [round(float(v), 4) for v in df["High"]],
        "l":            [round(float(v), 4) for v in df["Low"]],
        "c":            [round(float(v), 4) for v in df["Close"]],
        "v":            [float(v) for v in df["Volume"]],
    }


def upsert_batch(client: Client, rows: list[dict]) -> int:
    """Upsert a batch of rows. Returns the number successfully written."""
    if not rows:
        return 0
    try:
        client.table("stock_candles").upsert(
            rows, on_conflict="symbol,timeframe"
        ).execute()
        return len(rows)
    except Exception as e:
        print(f"\n  [WARN] Supabase upsert failed: {e}")
        return 0


def fetch_existing_symbols(client: Client, timeframe: str) -> set[str]:
    """Return the set of symbols already in Supabase for the given timeframe."""
    try:
        result = (
            client.table("stock_candles")
            .select("symbol")
            .eq("timeframe", timeframe)
            .execute()
        )
        return {row["symbol"] for row in result.data}
    except Exception:
        return set()


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Fetch NSE stock data → Supabase")
    parser.add_argument("--timeframe",  default="1d",   choices=["1d", "1wk", "1mo"])
    parser.add_argument("--limit",      type=int,       default=None,
                        help="Only process first N symbols (for testing)")
    parser.add_argument("--batch-size", type=int,       default=config.BATCH_SIZE)
    parser.add_argument("--delay",      type=float,     default=config.BATCH_DELAY)
    parser.add_argument("--dry-run",    action="store_true",
                        help="Fetch data but do NOT write to Supabase")
    parser.add_argument("--resume",     action="store_true",
                        help="Skip symbols that already exist in Supabase")
    args = parser.parse_args()

    period = config.FETCH_RANGE.get(args.timeframe, "1y")
    symbols = NSE_SYMBOLS[: args.limit] if args.limit else NSE_SYMBOLS

    print("=" * 60)
    print(f"  StockX — NSE Data Fetch")
    print(f"  Timeframe : {args.timeframe}   Period: {period}")
    print(f"  Symbols   : {len(symbols)}")
    print(f"  Batch size: {args.batch_size}   Delay: {args.delay}s")
    print(f"  Dry run   : {args.dry_run}   Resume: {args.resume}")
    print("=" * 60)

    # ── Connect to Supabase ──────────────────────────────────────────────────
    client = None
    if not args.dry_run:
        client = build_supabase_client()
        print("  Supabase connected.\n")

    # ── Skip already-fetched symbols when --resume ───────────────────────────
    if args.resume and client:
        existing = fetch_existing_symbols(client, args.timeframe)
        before = len(symbols)
        symbols = [s for s in symbols if s not in existing]
        print(f"  Resuming: skipping {before - len(symbols)} already-stored symbols.")
        print(f"  Remaining: {len(symbols)} symbols to fetch.\n")

    # ── Fetch loop ────────────────────────────────────────────────────────────
    # yf.download() fetches an entire batch in ONE HTTP request, so each loop
    # iteration is ~1 network round-trip instead of batch_size round-trips.
    total       = len(symbols)
    success     = 0
    failed      = 0
    upsert_rows = []

    with tqdm(total=total, unit="sym", dynamic_ncols=True) as pbar:
        for i in range(0, total, args.batch_size):
            batch        = symbols[i : i + args.batch_size]
            yahoo_batch  = [f"{s}.NS" for s in batch]

            # Single HTTP call for the whole batch
            fetched = fetch_batch(yahoo_batch, args.timeframe, period)

            for sym, yahoo_sym in zip(batch, yahoo_batch):
                df = fetched.get(yahoo_sym)
                if df is None:
                    failed += 1
                else:
                    if not args.dry_run:
                        upsert_rows.append(df_to_row(sym, args.timeframe, df))
                    success += 1
                pbar.update(1)

            pbar.set_postfix(ok=success, fail=failed, buf=len(upsert_rows))

            # Flush accumulated rows to Supabase after each batch
            if upsert_rows and not args.dry_run:
                upsert_batch(client, upsert_rows)
                upsert_rows.clear()

            # Brief pause between batches to avoid rate-limiting
            if i + args.batch_size < total:
                time.sleep(args.delay)

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print(f"  Done at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Fetched  : {success} / {total}")
    print(f"  Failed   : {failed}  (no data or < {config.MIN_BARS} bars)")
    if args.dry_run:
        print("  Supabase : SKIPPED (dry-run mode)")
    else:
        print(f"  Supabase : rows upserted successfully")
    print("=" * 60)


if __name__ == "__main__":
    main()
