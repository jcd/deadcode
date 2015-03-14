module extensions.config;

import extensions;
mixin registerCommands;

void configReloadKeyBindings(GUIApplication app)
{
	app.loadKeyMappings();
}
