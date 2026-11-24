/**
 * Bloem's internal build of Tracearr (APP_VARIANT=bloem).
 *
 * Not for release: it is sideloaded onto Bloem devices. It gets its own app ids and app
 * group so it never collides with the store app, Bloem's Apple team, and no OTA updates,
 * because upstream's update channel would replace this build's JavaScript with theirs.
 */

const BUNDLE_ID = 'com.bloemstudios.tracearr';
const APP_GROUP = `group.${BUNDLE_ID}`;
const APPLE_TEAM_ID = 'B223X6CJP8';

function pluginName(plugin) {
  return Array.isArray(plugin) ? plugin[0] : plugin;
}

function withPluginOptions(plugins, name, options) {
  return plugins.map((plugin) =>
    pluginName(plugin) === name ? [name, { ...plugin[1], ...options }] : plugin
  );
}

function applyBloemVariant(config) {
  let plugins = config.plugins ?? [];
  plugins = withPluginOptions(plugins, 'expo-widgets', {
    bundleIdentifier: `${BUNDLE_ID}.widgets`,
    groupIdentifier: APP_GROUP,
  });
  plugins = withPluginOptions(plugins, './plugins/withNotificationService', {
    bundleIdentifier: `${BUNDLE_ID}.NotificationService`,
  });

  return {
    ...config,
    ios: { ...config.ios, bundleIdentifier: BUNDLE_ID, appleTeamId: APPLE_TEAM_ID },
    android: { ...config.android, package: BUNDLE_ID },
    plugins,
    // The JS keychain calls must use the same app group as the widget (src/lib/authStateStore.ts)
    extra: { ...config.extra, appGroup: APP_GROUP },
    updates: { enabled: false },
  };
}

module.exports = { applyBloemVariant, BUNDLE_ID, APP_GROUP, APPLE_TEAM_ID };
