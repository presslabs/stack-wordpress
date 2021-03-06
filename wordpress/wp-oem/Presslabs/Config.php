<?php
namespace Presslabs;

class Config
{
    public static function loadDefaults()
    {
        static $runCount = 0;

        if ($runCount > 0) {
            return;
        }
        self::defineFromEnv("DOBJECT_CACHE_PRELOAD", false);

        self::defineFromEnv("MEMCACHED_HOST", "");
        self::defineFromEnv("MEMCACHED_DISCOVERY_HOST", "");

        self::defineFromEnv("UPLOADS_FTP_HOST", "");

        self::definePath("GIT_DIR", env("SRC_DIR") ?: "/var/run/presslabs.org/code/src");
        self::definePath("GIT_KEY_FILE", "/var/run/secrets/presslabs.org/instance/id_rsa");
        self::definePath("GIT_KEY_FILE", (rtrim(env("HOME"), '/') ?: "/var/www") . "/.ssh/id_rsa");

        $runCount++;
    }

    public static function defineFromEnv(string $name, $defaultValue, string $envName = "")
    {
        $envName = $envName ?: $name;
        $value = env($envName) ?: $defaultValue;
        self::define($name, $value);
    }

    public static function definePath(string $name, string $path, string $defaultPath = "")
    {
        if (file_exists($path)) {
            self::define($name, $path);
        } elseif (!empty($defaultPath)) {
            self::define($name, $defaultPath);
        }
    }

    public static function define(string $name, $value)
    {
        defined($name) or define($name, $value);
    }
}
