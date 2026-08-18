class UsLocations {
  UsLocations._();

  static const minQueryLength = 3;

  static const states = <String>[
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
    'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
    'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana',
    'Maine', 'Maryland', 'Massachusetts', 'Michigan', 'Minnesota',
    'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada',
    'New Hampshire', 'New Jersey', 'New Mexico', 'New York',
    'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon',
    'Pennsylvania', 'Rhode Island', 'South Carolina', 'South Dakota',
    'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington',
    'West Virginia', 'Wisconsin', 'Wyoming', 'District of Columbia',
  ];

  static const stateAbbreviations = <String, String>{
    'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
    'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
    'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii', 'ID': 'Idaho',
    'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa', 'KS': 'Kansas',
    'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
    'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota',
    'MS': 'Mississippi', 'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska',
    'NV': 'Nevada', 'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico',
    'NY': 'New York', 'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio',
    'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island',
    'SC': 'South Carolina', 'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas',
    'UT': 'Utah', 'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington',
    'WV': 'West Virginia', 'WI': 'Wisconsin', 'WY': 'Wyoming', 'DC': 'District of Columbia',
  };

  /// Local US city catalog keyed by state. No Supabase — in-memory only.
  static const citiesByState = <String, List<String>>{
    'Alabama': ['Birmingham', 'Montgomery', 'Mobile', 'Huntsville', 'Tuscaloosa'],
    'Alaska': ['Anchorage', 'Fairbanks', 'Juneau'],
    'Arizona': ['Phoenix', 'Tucson', 'Mesa', 'Chandler', 'Gilbert', 'Glendale', 'Scottsdale', 'Tempe', 'Peoria', 'Surprise'],
    'Arkansas': ['Little Rock', 'Fayetteville', 'Fort Smith', 'Jonesboro'],
    'California': ['Los Angeles', 'San Diego', 'San Jose', 'San Francisco', 'Fresno', 'Sacramento', 'Long Beach', 'Oakland', 'Bakersfield', 'Anaheim', 'Santa Ana', 'Riverside', 'Stockton', 'Irvine', 'Chula Vista', 'Fremont', 'San Bernardino', 'Modesto', 'Fontana', 'Oxnard', 'Moreno Valley', 'Huntington Beach', 'Glendale', 'Santa Clarita', 'Garden Grove', 'Oceanside', 'Rancho Cucamonga', 'Santa Rosa', 'Ontario', 'Elk Grove', 'Corona', 'Lancaster', 'Palmdale', 'Salinas', 'Hayward', 'Pomona', 'Escondido', 'Sunnyvale', 'Torrance', 'Pasadena', 'Orange', 'Fullerton', 'Thousand Oaks', 'Visalia', 'Simi Valley', 'Concord', 'Roseville', 'Santa Clara', 'Vallejo', 'Berkeley', 'El Monte', 'Downey', 'Costa Mesa', 'Inglewood', 'Carlsbad', 'San Buenaventura', 'West Covina', 'Norwalk', 'Murrieta', 'Antioch', 'Temecula', 'Daly City', 'Burbank', 'Santa Maria', 'El Cajon', 'Rialto', 'San Mateo', 'Clovis', 'Compton', 'Jurupa Valley', 'Vista', 'Mission Viejo', 'South Gate', 'Vacaville'],
    'Colorado': ['Denver', 'Colorado Springs', 'Aurora', 'Fort Collins', 'Lakewood', 'Thornton', 'Arvada', 'Westminster', 'Pueblo', 'Centennial', 'Boulder', 'Greeley'],
    'Connecticut': ['Bridgeport', 'New Haven', 'Stamford', 'Hartford', 'Waterbury', 'Norwalk', 'Danbury'],
    'Delaware': ['Wilmington', 'Dover', 'Newark'],
    'District of Columbia': ['Washington'],
    'Florida': ['Jacksonville', 'Miami', 'Tampa', 'Orlando', 'St. Petersburg', 'Hialeah', 'Tallahassee', 'Fort Lauderdale', 'Port St. Lucie', 'Cape Coral', 'Pembroke Pines', 'Hollywood', 'Miramar', 'Gainesville', 'Coral Springs', 'Clearwater', 'Miami Gardens', 'Palm Bay', 'Pompano Beach', 'West Palm Beach', 'Lakeland', 'Davie'],
    'Georgia': ['Atlanta', 'Augusta', 'Columbus', 'Macon', 'Savannah', 'Athens', 'Sandy Springs', 'Roswell', 'Johns Creek', 'Albany', 'Decatur', 'Marietta', 'Alpharetta', 'Smyrna', 'Brookhaven', 'Dunwoody', 'East Point', 'College Park', 'Union City', 'Douglasville', 'Kennesaw', 'Acworth', 'Woodstock', 'Canton', 'Gainesville', 'Lawrenceville', 'Duluth', 'Suwanee', 'Buford', 'Snellville', 'Lilburn', 'Norcross', 'Peachtree Corners', 'Tucker', 'Stone Mountain', 'Lithonia', 'Conyers', 'Covington', 'McDonough', 'Stockbridge', 'Jonesboro', 'Fayetteville', 'Peachtree City', 'Newnan', 'Carrollton', 'Villa Rica', 'Dallas', 'Powder Springs', 'Mableton', 'Austell', 'Forest Park', 'Riverdale', 'Griffin', 'Rome', 'Dalton', 'Valdosta', 'Warner Robins', 'Hinesville', 'Statesboro', 'Chamblee', 'Doraville', 'Clarkston', 'Avondale Estates', 'Fairburn', 'Tyrone', 'Milton', 'Cumming', 'Flowery Branch', 'Braselton', 'Winder', 'Monroe', 'Loganville', 'Dacula', 'Grayson', 'Auburn', 'Hoschton', 'Jefferson', 'Commerce', 'Toccoa', 'Cornelia', 'Cleveland', 'Dahlonega', 'Blue Ridge', 'Ellijay', 'Calhoun', 'Cartersville', 'Adairsville', 'Cedartown', 'Rockmart', 'Hiram', 'Lithia Springs', 'Vinings', 'Stonecrest', 'Redan', 'Panthersville'],
    'Hawaii': ['Honolulu', 'Hilo', 'Kailua'],
    'Idaho': ['Boise', 'Meridian', 'Nampa', 'Idaho Falls'],
    'Illinois': ['Chicago', 'Aurora', 'Naperville', 'Joliet', 'Rockford', 'Elgin', 'Peoria', 'Springfield'],
    'Indiana': ['Indianapolis', 'Fort Wayne', 'Evansville', 'South Bend', 'Carmel', 'Bloomington'],
    'Iowa': ['Des Moines', 'Cedar Rapids', 'Davenport', 'Sioux City', 'Iowa City'],
    'Kansas': ['Wichita', 'Overland Park', 'Kansas City', 'Olathe', 'Topeka'],
    'Kentucky': ['Louisville', 'Lexington', 'Bowling Green', 'Owensboro'],
    'Louisiana': ['New Orleans', 'Baton Rouge', 'Shreveport', 'Lafayette', 'Lake Charles'],
    'Maine': ['Portland', 'Lewiston', 'Bangor'],
    'Maryland': ['Baltimore', 'Frederick', 'Rockville', 'Gaithersburg', 'Bowie'],
    'Massachusetts': ['Boston', 'Worcester', 'Springfield', 'Cambridge', 'Lowell', 'New Bedford', 'Brockton'],
    'Michigan': ['Detroit', 'Grand Rapids', 'Warren', 'Sterling Heights', 'Ann Arbor', 'Lansing', 'Flint', 'Dearborn', 'Livonia'],
    'Minnesota': ['Minneapolis', 'St. Paul', 'Rochester', 'Duluth', 'Bloomington'],
    'Mississippi': ['Jackson', 'Gulfport', 'Southaven', 'Hattiesburg'],
    'Missouri': ['Kansas City', 'St. Louis', 'Springfield', 'Columbia', 'Independence'],
    'Montana': ['Billings', 'Missoula', 'Great Falls', 'Bozeman'],
    'Nebraska': ['Omaha', 'Lincoln', 'Bellevue', 'Grand Island'],
    'Nevada': ['Las Vegas', 'Henderson', 'Reno', 'North Las Vegas', 'Sparks', 'Carson City'],
    'New Hampshire': ['Manchester', 'Nashua', 'Concord'],
    'New Jersey': ['Newark', 'Jersey City', 'Paterson', 'Elizabeth', 'Lakewood', 'Edison', 'Woodbridge'],
    'New Mexico': ['Albuquerque', 'Las Cruces', 'Rio Rancho', 'Santa Fe'],
    'New York': ['New York', 'Buffalo', 'Rochester', 'Yonkers', 'Syracuse', 'Albany', 'New Rochelle'],
    'North Carolina': ['Charlotte', 'Raleigh', 'Greensboro', 'Durham', 'Winston-Salem', 'Fayetteville', 'Cary', 'Wilmington', 'High Point', 'Concord', 'Asheville'],
    'North Dakota': ['Fargo', 'Bismarck', 'Grand Forks', 'Minot'],
    'Ohio': ['Columbus', 'Cleveland', 'Cincinnati', 'Toledo', 'Akron', 'Dayton'],
    'Oklahoma': ['Oklahoma City', 'Tulsa', 'Norman', 'Broken Arrow', 'Lawton', 'Edmond'],
    'Oregon': ['Portland', 'Eugene', 'Salem', 'Gresham', 'Hillsboro', 'Beaverton'],
    'Pennsylvania': ['Philadelphia', 'Pittsburgh', 'Allentown', 'Erie', 'Reading', 'Scranton'],
    'Rhode Island': ['Providence', 'Warwick', 'Cranston', 'Pawtucket'],
    'South Carolina': ['Charleston', 'Columbia', 'North Charleston', 'Mount Pleasant', 'Rock Hill', 'Greenville'],
    'South Dakota': ['Sioux Falls', 'Rapid City', 'Aberdeen'],
    'Tennessee': ['Nashville', 'Memphis', 'Knoxville', 'Chattanooga', 'Clarksville', 'Murfreesboro'],
    'Texas': ['Houston', 'San Antonio', 'Dallas', 'Austin', 'Fort Worth', 'El Paso', 'Arlington', 'Corpus Christi', 'Plano', 'Laredo', 'Lubbock', 'Garland', 'Irving', 'Amarillo', 'Grand Prairie', 'Brownsville', 'McKinney', 'Frisco', 'McAllen', 'Waco', 'Carrollton', 'Midland', 'Denton', 'Abilene', 'Beaumont', 'Round Rock', 'Odessa', 'Wichita Falls', 'Lewisville', 'Tyler', 'Pearland', 'College Station', 'San Angelo', 'Mesquite', 'Killeen'],
    'Utah': ['Salt Lake City', 'West Valley City', 'Provo', 'West Jordan', 'Orem', 'Sandy'],
    'Vermont': ['Burlington', 'South Burlington', 'Rutland'],
    'Virginia': ['Virginia Beach', 'Norfolk', 'Chesapeake', 'Richmond', 'Newport News', 'Alexandria', 'Hampton', 'Roanoke', 'Portsmouth', 'Suffolk'],
    'Washington': ['Seattle', 'Spokane', 'Tacoma', 'Vancouver', 'Bellevue', 'Kent', 'Everett', 'Renton', 'Spokane Valley', 'Federal Way'],
    'West Virginia': ['Charleston', 'Huntington', 'Morgantown', 'Parkersburg'],
    'Wisconsin': ['Milwaukee', 'Madison', 'Green Bay', 'Kenosha', 'Racine', 'Appleton'],
    'Wyoming': ['Cheyenne', 'Casper', 'Laramie', 'Gillette'],
  };

  /// Flat city list for forms without a selected state (derived once).
  static final List<String> cities = () {
    final list = <String>{
      for (final entries in citiesByState.values) ...entries,
    }.toList();
    list.sort();
    return List<String>.unmodifiable(list);
  }();

  static List<String> citiesForState(String? state) {
    if (state == null || state.trim().isEmpty) return const [];
    return citiesByState[state] ?? const [];
  }

  static List<String> matchingStates(String query) {
    final normalized = query.trim().toLowerCase();
    // Empty query returns the full list so searchable dropdowns can open.
    if (normalized.isEmpty) {
      return List<String>.from(states, growable: false);
    }
    return states
        .where((state) => state.toLowerCase().contains(normalized))
        .take(normalized.length < minQueryLength ? 20 : 12)
        .toList();
  }

  /// Title-case a typed city so custom entries look like catalog names.
  static String titleCaseCity(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((part) {
          if (part.isEmpty) return part;
          if (part.contains('-')) {
            return part.split('-').map(_capCityWord).join('-');
          }
          return _capCityWord(part);
        })
        .join(' ');
  }

  static String _capCityWord(String word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    if (lower == 'of' || lower == 'the' || lower == 'and') return lower;
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  /// When [stateHint] is set, only that state's cities are searched and the
  /// 3-character minimum is waived so the dependent city dropdown can open.
  /// Unknown typed names are appended so every US city can be saved.
  static List<String> matchingCities(String query, {String? stateHint}) {
    final pool = citiesForState(stateHint);
    final source = pool.isNotEmpty ? pool : cities;
    final normalized = query.trim().toLowerCase();
    final scoped = pool.isNotEmpty;
    if (!scoped && normalized.length < minQueryLength) return const [];
    if (scoped && normalized.isEmpty) {
      return List<String>.from(source, growable: false);
    }
    final matches = source
        .where((city) => city.toLowerCase().contains(normalized))
        .toList();
    if (normalized.length >= 2) {
      final exact = matches.any((city) => city.toLowerCase() == normalized);
      if (!exact) {
        matches.add(titleCaseCity(query));
      }
    }
    if (!scoped) {
      return matches.take(12).toList(growable: false);
    }
    return matches;
  }

  static List<String> matchingAddresses(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < minQueryLength) return const [];
    final streetTypes = [
      'St', 'Street', 'Ave', 'Avenue', 'Blvd', 'Boulevard', 'Rd', 'Road',
      'Dr', 'Drive', 'Ln', 'Lane', 'Ct', 'Court', 'Pl', 'Place', 'Way',
      'Pkwy', 'Parkway', 'Hwy', 'Highway',
    ];
    return streetTypes
        .map((type) => '${query.trim()} $type')
        .take(6)
        .toList();
  }
}

