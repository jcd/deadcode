module extensions.config;

import extensionapi;
mixin registerCommands;

void configReloadKeyBindings(Application app)
{
	app.reloadKeyMappings();
}
