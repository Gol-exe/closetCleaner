Author: Brimstone

addon: closetCleaner

This addon is used in conjuction with gearswap to help find unneeded gear, all the include files are copies of those from the gearswap
addon except for closetCleaner.lua and ccConfig.lua

ccConfig needs to be configured. You will need to list your jobs that you actively play and keep gear for. You can also setup ignore lists so 
things like furniture, food, ninja tools, meds, helm items etc... are not tallied. You may also specify a max item count to limit the size of the report
as well as skip entire bags when searching current gear. 

To use this addon download and create a folder called closetCleaner in your .../Windower4/addons directory. This will look for files named
either <playername>_<job>.lua or <job>.lua (also _gear.lua versions) in ../gearswap/data directory (only those specified in the ccjobs list)

It will tally up all the gear inside the get_sets() (if using Mote's)  or init_gear_sets() function which are in the 'sets' tables (will work recursively). If you have sets defined elsewhere it will not be counted, if you have
sets defined in tables which are not in the 'sets' table space it will not be recognized. It only looks for items where the table key matches a slot 
(ie head, back, waist etc...) if you have aliased augmented items make sure the variable is defined inside get_sets(). The report copies and walks your sets graph with cycle detection, so shared references (e.g. sets.A = sets.B) and cyclic tables should no longer overflow the stack; set_combine builds a new merged table and was already safe in that regard. Very unusual metatable tricks on sets are still best avoided.

Output report should be: .../Windower4/closetCleaner/report/<playername>_report.txt

To use simply type: //lua l closetCleaner
Then: //cc report

If you change the config file, you'll need to //lua r closetCleaner, if you only change your <job>.lua files you can just rerun //cc report

Known issues:
1. It reads your inventory when you load closetCleaner, it reads your gearswap files when cc report is run, if you load and change your inventory before running cc report the results won't be right
2. it uses some dummy functions, I recommand unloading after your run and reload gearswap, just to be safe. (this will also prevent wierd results from #1)
3. If a job Lua fails to load or errors in get_sets/init_gear_sets, that job is skipped for set tallies and a message is printed in chat; other jobs in ccjobs still run