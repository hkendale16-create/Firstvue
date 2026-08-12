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

  static const cities = <String>[
    'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia',
    'San Antonio', 'San Diego', 'Dallas', 'San Jose', 'Austin', 'Jacksonville',
    'Fort Worth', 'Columbus', 'Charlotte', 'Indianapolis', 'San Francisco',
    'Seattle', 'Denver', 'Washington', 'Boston', 'El Paso', 'Nashville',
    'Detroit', 'Oklahoma City', 'Portland', 'Las Vegas', 'Memphis', 'Louisville',
    'Baltimore', 'Milwaukee', 'Albuquerque', 'Tucson', 'Fresno', 'Sacramento',
    'Atlanta', 'Miami', 'Oakland', 'Minneapolis', 'Tampa', 'New Orleans',
    'Cleveland', 'Honolulu', 'Anaheim', 'Orlando', 'St. Louis', 'Riverside',
    'Corpus Christi', 'Lexington', 'Pittsburgh', 'Anchorage', 'Stockton',
    'Cincinnati', 'St. Paul', 'Toledo', 'Newark', 'Greensboro', 'Plano',
    'Henderson', 'Lincoln', 'Buffalo', 'Fort Wayne', 'Jersey City', 'St. Petersburg',
    'Chula Vista', 'Norfolk', 'Orlando', 'Chandler', 'Laredo', 'Madison',
    'Durham', 'Lubbock', 'Winston-Salem', 'Garland', 'Glendale', 'Hialeah',
    'Reno', 'Baton Rouge', 'Irvine', 'Chesapeake', 'Irving', 'Scottsdale',
    'North Las Vegas', 'Fremont', 'Gilbert', 'San Bernardino', 'Boise',
    'Birmingham', 'Richmond', 'Spokane', 'Rochester', 'Des Moines', 'Modesto',
    'Fayetteville', 'Tacoma', 'Oxnard', 'Fontana', 'Columbus', 'Montgomery',
    'Moreno Valley', 'Shreveport', 'Aurora', 'Yonkers', 'Akron', 'Huntington Beach',
    'Little Rock', 'Augusta', 'Amarillo', 'Mobile', 'Grand Rapids', 'Salt Lake City',
    'Tallahassee', 'Huntsville', 'Grand Prairie', 'Knoxville', 'Worcester',
    'Newport News', 'Brownsville', 'Overland Park', 'Santa Clarita', 'Providence',
    'Garden Grove', 'Chattanooga', 'Oceanside', 'Jackson', 'Fort Lauderdale',
    'Santa Rosa', 'Rancho Cucamonga', 'Port St. Lucie', 'Tempe', 'Ontario',
    'Vancouver', 'Cape Coral', 'Sioux Falls', 'Springfield', 'Peoria', 'Pembroke Pines',
    'Elk Grove', 'Salem', 'Lancaster', 'Corona', 'Eugene', 'Palmdale', 'Salinas',
    'Springfield', 'Pasadena', 'Fort Collins', 'Hayward', 'Pomona', 'Cary',
    'Rockford', 'Alexandria', 'Escondido', 'McKinney', 'Kansas City', 'Joliet',
    'Sunnyvale', 'Torrance', 'Bridgeport', 'Lakewood', 'Hollywood', 'Paterson',
    'Naperville', 'Syracuse', 'Mesquite', 'Dayton', 'Savannah', 'Clarksville',
    'Orange', 'Pasadena', 'Fullerton', 'Killeen', 'Frisco', 'Hampton', 'McAllen',
    'Warren', 'Bellevue', 'West Valley City', 'Columbia', 'Olathe', 'Sterling Heights',
    'New Haven', 'Miramar', 'Waco', 'Thousand Oaks', 'Cedar Rapids', 'Charleston',
    'Visalia', 'Topeka', 'Elizabeth', 'Gainesville', 'Thornton', 'Roseville',
    'Carrollton', 'Coral Springs', 'Stamford', 'Simi Valley', 'Concord', 'Hartford',
    'Kent', 'Lafayette', 'Midland', 'Surprise', 'Denton', 'Victorville', 'Evansville',
    'Santa Clara', 'Abilene', 'Athens', 'Vallejo', 'Allentown', 'Norman', 'Beaumont',
    'Independence', 'Murfreesboro', 'Ann Arbor', 'Springfield', 'Berkeley', 'Peoria',
    'Provo', 'El Monte', 'Columbia', 'Lansing', 'Fargo', 'Downey', 'Costa Mesa',
    'Wilmington', 'Arvada', 'Inglewood', 'Miami Gardens', 'Carlsbad', 'Westminster',
    'Rochester', 'Odessa', 'Manchester', 'Elgin', 'West Jordan', 'Round Rock',
    'Clearwater', 'Waterbury', 'Gresham', 'Fairfield', 'Billings', 'Lowell',
    'San Buenaventura', 'Pueblo', 'High Point', 'West Covina', 'Richmond',
    'Murrieta', 'Cambridge', 'Antioch', 'Temecula', 'Norwalk', 'Centennial',
    'Everett', 'Palm Bay', 'Wichita Falls', 'Green Bay', 'Daly City', 'Burbank',
    'Richardson', 'Pompano Beach', 'North Charleston', 'Broken Arrow', 'Boulder',
    'West Palm Beach', 'Santa Maria', 'El Cajon', 'Davenport', 'Rialto', 'Las Cruces',
    'San Mateo', 'Lewisville', 'South Bend', 'Lakeland', 'Erie', 'Tyler', 'Pearland',
    'College Station', 'Kenosha', 'Sandy Springs', 'Clovis', 'Flint', 'Roanoke',
    'Albany', 'Jurupa Valley', 'Compton', 'San Angelo', 'Hillsboro', 'Lawton',
    'Renton', 'Vista', 'Davie', 'Greeley', 'Mission Viejo', 'Portsmouth',
    'Dearborn', 'South Gate', 'Tuscaloosa', 'Livonia', 'New Bedford', 'Vacaville',
  ];

  static List<String> matchingStates(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < minQueryLength) return const [];
    return states
        .where((state) => state.toLowerCase().contains(normalized))
        .take(8)
        .toList();
  }

  static List<String> matchingCities(String query, {String? stateHint}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < minQueryLength) return const [];
    return cities
        .where((city) => city.toLowerCase().contains(normalized))
        .take(8)
        .toList();
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
