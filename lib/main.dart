import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/constants/colors.dart';
import 'core/network/websocket_realtime_client.dart';
import 'core/storage/local_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/state/auth_state.dart';
import 'features/couple_pairing/data/couple_repository.dart';
import 'features/auth_pairing/domain/couple_model.dart';
import 'features/auth_pairing/presentation/pairing_screen.dart';
import 'features/auth_pairing/state/couple_state.dart';
import 'features/location/data/location_repository.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/home/state/presence_state.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/presentation/chat_screen.dart';
import 'features/chat/state/chat_state.dart';
import 'features/music/data/music_repository.dart';
import 'features/music/presentation/music_room_screen.dart';
import 'features/music/presentation/widgets/persistent_mini_player.dart';
import 'features/music/state/music_state.dart';
import 'features/memories/data/memories_repository.dart';
import 'features/memories/presentation/memories_screen.dart';
import 'features/memories/state/memories_state.dart';
import 'features/moments/service/moments_engine.dart';
import 'features/settings/presentation/settings_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM Background] Handling remote message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Storage
  await LocalStorageService().init();

  // Initialize Firebase with platform-specific options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[Firebase Init] Warning: Running in offline/development mode: $e');
  }

  final authRepo = FirebaseAuthRepository();
  final coupleRepo = FirebaseCoupleRepository();
  final realtimeClient = WebSocketRealtimeClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState(authRepository: authRepo)),
        ChangeNotifierProvider(
          create: (_) => CoupleState(
            realtimeClient: realtimeClient,
            coupleRepository: coupleRepo,
          ),
        ),
      ],
      child: const BetweenUsApp(),
    ),
  );
}

class BetweenUsApp extends StatelessWidget {
  const BetweenUsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Between Us',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RootAppCoordinator(),
    );
  }
}

class RootAppCoordinator extends StatefulWidget {
  const RootAppCoordinator({super.key});

  @override
  State<RootAppCoordinator> createState() => _RootAppCoordinatorState();
}

class _RootAppCoordinatorState extends State<RootAppCoordinator> {
  String? _initializedUserId;
  String? _initializedCoupleId;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    // Step 0: Initial Booting / Session Verification
    if (authState.isChecking) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.ambientGlow),
          child: const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primaryRose,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      );
    }

    // Step 1: User Authentication
    if (!authState.isAuthenticated) {
      _initializedUserId = null;
      _initializedCoupleId = null;
      return const AuthScreen();
    }

    final user = authState.user!;
    final coupleState = context.watch<CoupleState>();

    // Initialize couple state for authenticated user if needed
    if (_initializedUserId != user.uid || _initializedCoupleId != user.coupleId) {
      _initializedUserId = user.uid;
      _initializedCoupleId = user.coupleId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CoupleState>().initForUser(
          myUserId: user.uid,
          myDisplayName: user.displayName,
          coupleId: user.coupleId,
        );
      });
    }

    // If user has a known coupleId and couple data is still loading from Firestore, show loading
    if ((user.coupleId != null && user.coupleId!.isNotEmpty && coupleState.couple == null) ||
        (coupleState.isLoading && coupleState.couple == null)) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.ambientGlow),
          child: const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primaryRose,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      );
    }

    // Step 2: Couple Space Pairing
    if (!coupleState.isConnected) {
      return PairingScreen(
        userName: user.displayName,
        userId: user.uid,
        isCreating: coupleState.couple?.status != CoupleStatus.connected,
      );
    }

    // Step 3: Main Intimate Couple Dashboard with real repositories & WebSocket sync
    final couple = coupleState.couple!;
    final locationRepo = FirebaseLocationRepository();
    final musicRepo = FirebaseMusicRepository();
    final chatRepo = FirebaseChatRepository();
    final memoriesRepo = FirebaseMemoriesRepository();
    final realtimeClient = WebSocketRealtimeClient();

    // Connect realtime WebSocket if not already connected (background non-blocking)
    if (!realtimeClient.isConnected && realtimeClient.coupleId != couple.id) {
      realtimeClient.connect(
        coupleId: couple.id,
        userId: user.uid,
      );
    }

    return MultiProvider(
      key: ValueKey(couple.id),
      providers: [
        ChangeNotifierProvider(
          create: (_) => PresenceState(
            locationRepository: locationRepo,
            myUserId: user.uid,
            coupleId: couple.id,
            partnerId: couple.partner?.id ?? '',
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MomentsEngine(
            coupleId: couple.id,
            myUserId: user.uid,
            myName: user.displayName,
            partnerId: couple.partner?.id ?? '',
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatState(
            realtimeClient: realtimeClient,
            chatRepository: chatRepo,
            coupleId: couple.id,
            myUserId: user.uid,
            myName: user.displayName,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MusicState(
            musicRepository: musicRepo,
            coupleId: couple.id,
            myUserId: user.uid,
            myName: user.displayName,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoriesState(
            realtimeClient: realtimeClient,
            memoriesRepository: memoriesRepo,
            coupleId: couple.id,
            myUserId: user.uid,
            myName: user.displayName,
          ),
        ),
      ],
      child: const MainTabScaffold(),
    );
  }
}

class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key});

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final musicState = context.watch<MusicState>();
    final isMusicActive = musicState.currentSession != null;

    final screens = [
      HomeScreen(
        onOpenChat: () => setState(() => _currentIndex = 1),
        onOpenTogether: () => setState(() => _currentIndex = 2),
        onOpenMemories: () => setState(() => _currentIndex = 3),
      ),
      const ChatScreen(),
      const MusicRoomScreen(),
      const MemoriesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: screens,
          ),

          if (isMusicActive && _currentIndex != 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: PersistentMiniPlayer(
                  musicState: musicState,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border_rounded), activeIcon: Icon(Icons.favorite_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note_outlined), activeIcon: Icon(Icons.music_note_rounded), label: 'Together'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_stories_outlined), activeIcon: Icon(Icons.auto_stories_rounded), label: 'Memories'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Us'),
        ],
      ),
    );
  }
}
