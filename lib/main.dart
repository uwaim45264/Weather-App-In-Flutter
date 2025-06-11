import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WeatherProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: TextTheme(
          bodyLarge: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
          bodyMedium: GoogleFonts.poppins(color: Colors.white70),
          headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherProvider with ChangeNotifier {
  String _city = '';
  String _temperature = '';
  String _description = '';
  String _icon = '';
  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _forecast = [];
  String _unit = 'metric'; // Celsius by default
  DateTime? _lastUpdated;

  String get city => _city;
  String get temperature => _temperature;
  String get description => _description;
  String get icon => _icon;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get forecast => _forecast;
  String get unit => _unit;
  DateTime? get lastUpdated => _lastUpdated;

  final String apiKey = 'Your API KEY Here';

  void toggleUnit() {
    _unit = _unit == 'metric' ? 'imperial' : 'metric';
    notifyListeners();
    // Refresh data with new unit
    if (_city.isNotEmpty) {
      if (_city == 'Error') {
        fetchWeatherByLocation();
      } else {
        fetchWeatherByCity(_city);
      }
    }
  }

  Future<void> fetchWeatherByLocation() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      Position position = await _determinePosition();
      await _fetchWeatherData(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=$_unit',
      );
      await _fetchForecastData(
        'https://api.openweathermap.org/data/2.5/forecast?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=$_unit',
      );
      _lastUpdated = DateTime.now();
    } catch (e) {
      _errorMessage = 'Error: $e';
      _city = 'Error';
      _temperature = 'N/A';
      _description = 'Failed to fetch weather';
      _icon = '';
      _forecast = [];
      _lastUpdated = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchWeatherByCity(String city) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _fetchWeatherData(
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=$_unit',
      );
      await _fetchForecastData(
        'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=$_unit',
      );
      _lastUpdated = DateTime.now();
    } catch (e) {
      _errorMessage = 'Error: $e';
      _city = 'Error';
      _temperature = 'N/A';
      _description = 'Failed to fetch weather';
      _icon = '';
      _forecast = [];
      _lastUpdated = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchWeatherData(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _city = data['name'];
      _temperature = data['main']['temp'].toString();
      _description = data['weather'][0]['description'];
      _icon = data['weather'][0]['icon'];
    } else {
      throw 'Failed to load weather data';
    }
  }

  Future<void> _fetchForecastData(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _forecast = [];
      for (var item in data['list']) {
        if (item['dt_txt'].contains('12:00:00')) {
          _forecast.add({
            'date': item['dt_txt'],
            'temp': item['main']['temp'].toString(),
            'icon': item['weather'][0]['icon'],
            'description': item['weather'][0]['description'],
          });
        }
      }
    } else {
      throw 'Failed to load forecast data';
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied.';
    }

    return await Geolocator.getCurrentPosition();
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Color> _getWeatherGradient(String description) {
    description = description.toLowerCase();
    if (description.contains('clear')) {
      return [Colors.orange.shade300, Colors.blue.shade700];
    } else if (description.contains('cloud')) {
      return [Colors.grey.shade600, Colors.blueGrey.shade900];
    } else if (description.contains('rain') || description.contains('drizzle')) {
      return [Colors.blue.shade800, Colors.indigo.shade900];
    } else if (description.contains('snow')) {
      return [Colors.blue.shade100, Colors.white];
    } else {
      return [Colors.blue.shade600, Colors.lightBlue.shade900];
    }
  }

  Future<void> _onRefresh(BuildContext context) async {
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    await weatherProvider.fetchWeatherByLocation();
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final TextEditingController cityController = TextEditingController();
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: weatherProvider.description.isNotEmpty
                ? _getWeatherGradient(weatherProvider.description)
                : [Colors.blue.shade600, Colors.lightBlue.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                margin: EdgeInsets.all(screenSize.width * 0.05),
              ),
              RefreshIndicator(
                onRefresh: () => _onRefresh(context),
                color: Colors.white,
                backgroundColor: Colors.black.withOpacity(0.3),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.all(screenSize.width * 0.05),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Unit Toggle Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  weatherProvider.toggleUnit();
                                  _animationController.reset();
                                  _animationController.forward();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: EdgeInsets.symmetric(
                                    vertical: screenSize.height * 0.01,
                                    horizontal: screenSize.width * 0.03,
                                  ),
                                ),
                                child: Text(
                                  weatherProvider.unit == 'metric' ? '°C' : '°F',
                                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenSize.height * 0.01),
                          // Search Bar
                          TextField(
                            controller: cityController,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.15),
                              hintText: 'Enter city name',
                              hintStyle: GoogleFonts.poppins(color: Colors.white54),
                              prefixIcon: const Icon(Icons.search, color: Colors.white70),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white70),
                                onPressed: () => cityController.clear(),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: GoogleFonts.poppins(color: Colors.white),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                weatherProvider.fetchWeatherByCity(value);
                              }
                            },
                          ),
                          SizedBox(height: screenSize.height * 0.001),
                          // Error Message
                          if (weatherProvider.errorMessage.isNotEmpty)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    weatherProvider.errorMessage,
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: screenSize.height * 0.01),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (weatherProvider.city == 'Error') {
                                        weatherProvider.fetchWeatherByLocation();
                                      } else {
                                        weatherProvider.fetchWeatherByCity(weatherProvider.city);
                                      }
                                      _animationController.reset();
                                      _animationController.forward();
                                    },
                                    icon: const Icon(Icons.refresh, color: Colors.white),
                                    label: Text(
                                      'Retry',
                                      style: GoogleFonts.poppins(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: screenSize.height * 0.03),
                          // Current Weather
                          if (weatherProvider.city.isNotEmpty && weatherProvider.errorMessage.isEmpty)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              padding: EdgeInsets.all(screenSize.width * 0.04),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    weatherProvider.city,
                                    style: Theme.of(context).textTheme.headlineMedium,
                                  ),
                                  SizedBox(height: screenSize.height * 0.01),
                                  Image.network(
                                    'http://openweathermap.org/img/wn/${weatherProvider.icon}@4x.png',
                                    width: screenSize.width * 0.3,
                                    height: screenSize.width * 0.3,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.error,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                  Text(
                                    '${weatherProvider.temperature}${weatherProvider.unit == 'metric' ? '°C' : '°F'}',
                                    style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w300, color: Colors.white),
                                  ),
                                  Text(
                                    weatherProvider.description.toUpperCase(),
                                    style: GoogleFonts.poppins(fontSize: 18, color: Colors.white70),
                                  ),
                                  if (weatherProvider.lastUpdated != null)
                                    Text(
                                      'Last updated: ${weatherProvider.lastUpdated!.toString().split('.')[0]}',
                                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                                    ),
                                ],
                              ),
                            ),
                          SizedBox(height: screenSize.height * 0.02),
                          // Forecast
                          if (weatherProvider.forecast.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    '5-Day Forecast',
                                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                SizedBox(height: screenSize.height * 0.01),
                                SizedBox(
                                  height: screenSize.height * 0.2,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: weatherProvider.forecast.length,
                                    itemBuilder: (context, index) {
                                      final forecast = weatherProvider.forecast[index];
                                      return Container(
                                        width: screenSize.width * 0.3,
                                        margin: EdgeInsets.symmetric(horizontal: screenSize.width * 0.015),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                forecast['date'].split(' ')[0],
                                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                                                textAlign: TextAlign.center,
                                              ),
                                              Image.network(
                                                'http://openweathermap.org/img/wn/${forecast['icon']}@2x.png',
                                                width: screenSize.width * 0.15,
                                                height: screenSize.width * 0.15,
                                                errorBuilder: (context, error, stackTrace) => const Icon(
                                                  Icons.error,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                              ),
                                              Text(
                                                '${forecast['temp']}${weatherProvider.unit == 'metric' ? '°C' : '°F'}',
                                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                                              ),
                                              Text(
                                                forecast['description'],
                                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: screenSize.height * 0.03),
                          // Refresh Button
                          ElevatedButton.icon(
                            onPressed: () {
                              weatherProvider.fetchWeatherByLocation();
                              _animationController.reset();
                              _animationController.forward();
                            },
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: Text(
                              'Current Location',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: EdgeInsets.symmetric(
                                vertical: screenSize.height * 0.02,
                                horizontal: screenSize.width * 0.05,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Loading Indicator
              if (weatherProvider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: SpinKitWave(
                      color: Colors.white,
                      size: 50.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
