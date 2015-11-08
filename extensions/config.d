module extensions.config;

import extensions;
mixin registerCommands;

void configReloadKeyBindings(Application app)
{
	app.loadKeyMappings();
}
