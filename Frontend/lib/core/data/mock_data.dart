import 'package:google_maps_flutter/google_maps_flutter.dart';

/// LiftOff — Authentic P2P Community Shared Mobility Mock Data

// ─── Verification Status ───
class VerificationStatus {
  final bool aadhaarVerified;
  final bool dlVerified;
  final bool vehicleRcVerified;
  final bool femaleVerified;

  const VerificationStatus({
    this.aadhaarVerified = true,
    this.dlVerified = true,
    this.vehicleRcVerified = true,
    this.femaleVerified = false,
  });

  String get summaryBadgeText {
    if (aadhaarVerified && dlVerified && vehicleRcVerified) {
      return 'Govt ID & Vehicle Verified ✅';
    }
    if (aadhaarVerified && dlVerified) {
      return 'Aadhaar & DL Verified ✅';
    }
    return 'Identity Verified ✅';
  }
}

// ─── Host / Commuter Profile ───
class CommuterProfile {
  final String id;
  final String name;
  final String avatarUrl;
  final double rating;
  final int sharedTripsCount;
  final int co2SavedKg;
  final VerificationStatus verification;
  final String workPlace;

  const CommuterProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.sharedTripsCount,
    required this.co2SavedKg,
    required this.verification,
    required this.workPlace,
  });
}

// ─── Community Shared Ride (Offered by a Host) ───
class CommunityRide {
  final String id;
  final CommuterProfile host;
  final String origin;
  final String destination;
  final String departureTime;
  final String vehicleModel;
  final String vehicleNumber;
  final int totalSeats;
  final int availableSeats;
  final int routeMatchPercentage;
  final String meetingNodeName;
  final String meetingNodeDistance;
  final double fuelSharePerSeat;
  final bool isWomenOnly;
  final bool strictPassengerConsent;
  final List<String> preferences; // e.g., ["AC", "Luggage Allowed", "No Smoking"]

  const CommunityRide({
    required this.id,
    required this.host,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.vehicleModel,
    required this.vehicleNumber,
    required this.totalSeats,
    required this.availableSeats,
    required this.routeMatchPercentage,
    required this.meetingNodeName,
    required this.meetingNodeDistance,
    required this.fuelSharePerSeat,
    this.isWomenOnly = false,
    this.strictPassengerConsent = true,
    this.preferences = const ['AC', 'Luggage Allowed', 'No Smoking'],
  });
}

// ─── Safe Smart Meeting Node ───
class SafeMeetingNode {
  final String id;
  final String name;
  final String landmark;
  final String walkingTime;
  final LatLng location;

  const SafeMeetingNode({
    required this.id,
    required this.name,
    required this.landmark,
    required this.walkingTime,
    required this.location,
  });
}

// ─── Democratic Voting Applicant ───
class DemocraticVotingApplicant {
  final String name;
  final double rating;
  final String pickupPoint;
  final String dropPoint;
  final int routeOverlapPercent;
  final VerificationStatus verification;
  final int remainingSeconds;

  const DemocraticVotingApplicant({
    required this.name,
    required this.rating,
    required this.pickupPoint,
    required this.dropPoint,
    required this.routeOverlapPercent,
    required this.verification,
    this.remainingSeconds = 112,
  });
}

// ─── Static Mock Repository ───
class MockData {
  MockData._();

  // Current User (Harsh Patel)
  static const CommuterProfile currentUser = CommuterProfile(
    id: 'user_001',
    name: 'Harsh Patel',
    avatarUrl: '',
    rating: 4.9,
    sharedTripsCount: 28,
    co2SavedKg: 142,
    verification: VerificationStatus(
      aadhaarVerified: true,
      dlVerified: true,
      vehicleRcVerified: true,
    ),
    workPlace: 'Cyber City, Gurgaon',
  );

  // Community Hosts
  static const CommuterProfile hostRahul = CommuterProfile(
    id: 'host_001',
    name: 'Rahul Sharma',
    avatarUrl: '',
    rating: 4.9,
    sharedTripsCount: 46,
    co2SavedKg: 210,
    verification: VerificationStatus(
      aadhaarVerified: true,
      dlVerified: true,
      vehicleRcVerified: true,
    ),
    workPlace: 'Google India, Cyber Hub',
  );

  static const CommuterProfile hostAnanya = CommuterProfile(
    id: 'host_002',
    name: 'Ananya Deshmukh',
    avatarUrl: '',
    rating: 5.0,
    sharedTripsCount: 32,
    co2SavedKg: 180,
    verification: VerificationStatus(
      aadhaarVerified: true,
      dlVerified: true,
      vehicleRcVerified: true,
      femaleVerified: true,
    ),
    workPlace: 'Deloitte, Gurgaon Phase 2',
  );

  static const CommuterProfile hostVikram = CommuterProfile(
    id: 'host_003',
    name: 'Vikram Sethi',
    avatarUrl: '',
    rating: 4.8,
    sharedTripsCount: 19,
    co2SavedKg: 95,
    verification: VerificationStatus(
      aadhaarVerified: true,
      dlVerified: true,
      vehicleRcVerified: true,
    ),
    workPlace: 'MakeMyTrip, DLF Square',
  );

  // Available Community Rides
  static const List<CommunityRide> communityRides = [
    CommunityRide(
      id: 'ride_101',
      host: hostRahul,
      origin: 'Connaught Place, New Delhi',
      destination: 'DLF Cyber City, Gurgaon',
      departureTime: 'Today • 5:45 PM',
      vehicleModel: 'Honda City • White',
      vehicleNumber: 'DL 3C XX 1234',
      totalSeats: 3,
      availableSeats: 2,
      routeMatchPercentage: 96,
      meetingNodeName: 'Rajiv Chowk Metro Gate 2',
      meetingNodeDistance: '150m walk',
      fuelSharePerSeat: 140,
      isWomenOnly: false,
      strictPassengerConsent: true,
      preferences: ['AC Sedan', 'No Smoking', 'Backpack Allowed'],
    ),
    CommunityRide(
      id: 'ride_102',
      host: hostAnanya,
      origin: 'Mandi House, Central Delhi',
      destination: 'Golf Course Road, Gurgaon',
      departureTime: 'Today • 6:15 PM',
      vehicleModel: 'Hyundai Creta • Grey',
      vehicleNumber: 'HR 26 BG 7890',
      totalSeats: 3,
      availableSeats: 1,
      routeMatchPercentage: 92,
      meetingNodeName: 'Barakhamba Road Petrol Pump',
      meetingNodeDistance: '280m walk',
      fuelSharePerSeat: 160,
      isWomenOnly: true,
      strictPassengerConsent: true,
      preferences: ['Women Only 👩', 'AC SUV', 'Strict Co-Consent'],
    ),
    CommunityRide(
      id: 'ride_103',
      host: hostVikram,
      origin: 'Karol Bagh, New Delhi',
      destination: 'Udyog Vihar, Gurgaon',
      departureTime: 'Today • 6:30 PM',
      vehicleModel: 'Maruti Brezza • Silver',
      vehicleNumber: 'DL 8C AA 4421',
      totalSeats: 4,
      availableSeats: 3,
      routeMatchPercentage: 88,
      meetingNodeName: 'Jhandewalan Metro Station',
      meetingNodeDistance: '400m walk',
      fuelSharePerSeat: 120,
      isWomenOnly: false,
      strictPassengerConsent: false,
      preferences: ['AC Mini SUV', 'Luggage Ok', 'Fast Approver'],
    ),
  ];

  // Smart Meeting Nodes
  static const List<SafeMeetingNode> safeMeetingNodes = [
    SafeMeetingNode(
      id: 'node_1',
      name: 'Rajiv Chowk Metro Gate 2',
      landmark: 'Near Outer Circle Post Office',
      walkingTime: '2 mins walk',
      location: LatLng(28.6328, 77.2195),
    ),
    SafeMeetingNode(
      id: 'node_2',
      name: 'Barakhamba Road Shell Pump',
      landmark: 'Opposite Tolstoy Marg',
      walkingTime: '4 mins walk',
      location: LatLng(28.6295, 77.2270),
    ),
    SafeMeetingNode(
      id: 'node_3',
      name: 'Janpath Metro Station Gate 1',
      landmark: 'Janpath Market Entry',
      walkingTime: '5 mins walk',
      location: LatLng(28.6250, 77.2180),
    ),
  ];

  // Democratic Polling Applicant
  static const DemocraticVotingApplicant activeApplicant =
      DemocraticVotingApplicant(
    name: 'Priya Verma',
    rating: 4.9,
    pickupPoint: 'Rajiv Chowk Gate 2',
    dropPoint: 'Cyber Hub Building 10',
    routeOverlapPercent: 94,
    verification: VerificationStatus(
      aadhaarVerified: true,
      dlVerified: true,
      vehicleRcVerified: false,
      femaleVerified: true,
    ),
    remainingSeconds: 98,
  );

  // Map Coordinates
  static final LatLng userLocation = LatLng(28.6315, 77.2167);
  static final LatLng destinationLocation = LatLng(28.4595, 77.0266);

  // Active Corridor Route
  static final List<LatLng> activeCorridor = [
    LatLng(28.6315, 77.2167),
    LatLng(28.6200, 77.2100),
    LatLng(28.6050, 77.2000),
    LatLng(28.5800, 77.1800),
    LatLng(28.5500, 77.1500),
    LatLng(28.5200, 77.1200),
    LatLng(28.4900, 77.0900),
    LatLng(28.4700, 77.0600),
    LatLng(28.4595, 77.0266),
  ];
}
