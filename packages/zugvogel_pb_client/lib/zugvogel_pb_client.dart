/// The PocketBase connection shared by the Zugvogel apps.
///
/// The server URL and every other environment value arrive from the app — this
/// package reads no compile-time define of its own (injection boundary 3).
///
/// The version-compatibility check must keep failing OPEN: an unreachable or
/// unparseable /info is not a blocked app — see eiermann-d2a.4.
library;

// Exports land here as eiermann-d2a.4 moves the connection across.
