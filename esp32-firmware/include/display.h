#pragma once

#include <Arduino.h>
#include <control_engine.h>

// Initialize the ST7789 display
void displayInit();

// Redraw the status screen.
// `connected` = receiving data from tablet recently.
// `valvePct` = the actual valve output (external override or engine command).
// `gpm` = flow to display (tablet's value when no local flow meter).
void displayUpdate(const SprayerTelemetry& tel, bool connected, float valvePct, float gpm);
