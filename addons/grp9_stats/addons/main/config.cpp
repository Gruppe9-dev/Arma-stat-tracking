class CfgPatches {
    class grp9_stats_main {
        name = "Gruppe 9 Stats";
        author = "Gruppe 9";
        requiredVersion = 2.18;
        requiredAddons[] = {"cba_main"};
        units[] = {};
        weapons[] = {};
    };
};

class CfgFunctions {
    class grp9_stats {
        class operation {
            file = "z\grp9_stats\addons\main\functions";
            class initServer {
                postInit = 1;
            };
            class startOperation {};
            class finishOperation {};
            class getEligiblePlayers {};
            class buildPlayerSnapshot {};
            class buildAttendanceRecords {};
            class buildScoreboardStats {};
        };
    };
};
