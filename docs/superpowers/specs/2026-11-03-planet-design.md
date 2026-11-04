# Planetary prototype 0.9.0

Approved scope: hybrid orbital/surface scenes with a masked transition; one planet, one freely explorable district, approach, descent, landing, takeoff, orbital return; reverse throttle to -30%. Preserve trade, cargo, cameras, orientation and old saves.

Approaches considered: explicit loading-screen teleport is simpler but breaks continuity; fully seamless planetary streaming needs substantially more terrain/precision infrastructure; approved hybrid loads a local surface scene during atmospheric descent.

Implementation choices: planet Astra, district Meridian, roughly 1.8 km across. Orbital approach point outside the decorative planet. Start expedition from station, fly to entry, request descent within 35m at <=25m/s. Short animated atmospheric transfer masks asynchronous resource loading. Local flight uses current steering/throttle plus held vertical controls. Terrain height and slope gate landing: altitude <=25m, speed <=8m/s, slope <=0.35. A short vertical landing sequence sets safe ground clearance; takeoff returns to hover. Exit to orbit above 100m, return to launch station; no reward for exploration. District edge and ground prevent leaving navigable space; hard ground impact damages hull.

Save/resume all orbital and surface stages, including transitions and landed ship; menu and overlays pause motion, release held input. Planetary map uses local XZ projection. No station services on surface. No mining rewards or installations yet.

Future approved design retained: surveyed surface deposits, automatic mining complexes with storage/upgrades, active production above offline production; preliminary offline multiplier 50%; breakdowns, pirate raids and weather; destructive offline loss permitted in particularly dangerous areas, clearly communicated before installation. Outcomes persisted; preparation influences risk. These systems are not part of 0.9.0.
