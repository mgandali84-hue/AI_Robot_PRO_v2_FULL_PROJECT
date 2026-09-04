# AI Robot PRO v2 - Turn-by-turn navigation

Added:
- OSRM routing.
- Route geometry on the interactive map.
- Turn-by-turn maneuver steps.
- Voice guidance through TTS.
- Live GPS tracking.
- Automatic rerouting when the device is more than ~80m from the route.
- Arabic/English instruction generation.

OSRM's route service supports `steps=true` for route steps; its RouteStep objects provide distance,
duration and maneuver data suitable for turn-by-turn guidance.

Production:
- The public OSRM demo endpoint is intended for testing and has usage/rate limits. For a production app,
  use your own OSRM/Valhalla server or a commercial routing provider.
- This implementation uses destination latitude/longitude. A place-name search/geocoding UI can be added
  separately.
- This is navigation guidance, not a licensed/guaranteed emergency navigation service.
