#!/bin/bash
exec java -Xms1G \
-Xmx1G \
-Djna.library.path=".:/usr/local/lib" \
-classpath "/usr/share/CIEID/cieid.jar" \
it.ipzs.cieid.MainApplication

