/// Pump on/off logic.
///
/// The pump runs only while the master spray switch is ON **and** at least
/// one section is active. This keeps the controller independent of pump type
/// (electric / hydraulic / gas / PTO): it only ever commands "run" or "stop".
class PumpController {
  bool running = false;

  void update({required bool sprayOn, required bool anySectionOn}) {
    running = sprayOn && anySectionOn;
  }
}
