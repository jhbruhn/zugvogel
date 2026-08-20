/// The PocketBase connection shared by the Zugvogel apps.
///
/// Everything environment-specific arrives through `PbClientConfig`, which the
/// app overrides into `pbClientConfigProvider`. This package reads no
/// compile-time define of its own (injection boundary 3) and carries no
/// user-facing text (boundary 1) — `ServerProbeResult` is a set of cases for
/// the app to phrase, not a set of messages.
///
/// Two behaviours here are load-bearing and deliberately fail OPEN:
/// `checkServerCompatibility` (a false positive locks the user out entirely)
/// and `serverInfoProvider` (an unreachable `/info` must not block sign-in).
library;

export 'src/auth_status.dart';
export 'src/auth_token_storage.dart';
export 'src/config.dart';
export 'src/connectivity.dart';
export 'src/logging_observer.dart';
export 'src/map_config.dart';
export 'src/map_config_provider.dart';
export 'src/pocketbase_provider.dart';
export 'src/protected_files.dart';
export 'src/realtime/collection_events.dart';
export 'src/realtime/live_refresh.dart';
export 'src/server_compatibility.dart';
export 'src/server_config.dart';
export 'src/server_config_controller.dart';
export 'src/server_info.dart';
export 'src/server_info_provider.dart';
export 'src/server_probe.dart';
export 'src/server_url_storage.dart';
export 'src/session.dart';
export 'src/user_agent_client.dart';
