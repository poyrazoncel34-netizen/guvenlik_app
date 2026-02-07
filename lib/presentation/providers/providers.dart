import 'package:provider/provider.dart';
import 'app_state_provider.dart';
import 'contacts_provider.dart';
import 'home_provider.dart';
import 'settings_provider.dart';

class AppProviders {
  static final providers = [
    ChangeNotifierProvider<AppStateProvider>(create: (_) => AppStateProvider()),
    ChangeNotifierProvider<ContactsProvider>(create: (_) => ContactsProvider()),
    ChangeNotifierProvider<HomeProvider>(create: (_) => HomeProvider()),
    ChangeNotifierProvider<SettingsProvider>(create: (_) => SettingsProvider()),
  ];
}
