class CfgPatches {
    class grp9_stats_server_main {
        name = "Gruppe 9 Stats Server";
        author = "Gruppe 9";
        requiredVersion = 2.18;
        requiredAddons[] = {"grp9_stats_main"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgFunctions {
    class grp9_stats_server {
        class extension {
            file = "z\grp9_stats_server\addons\main\functions";
            class callExtension {};
        };
    };
};
