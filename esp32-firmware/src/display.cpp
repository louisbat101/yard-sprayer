#include <display.h>
#include <TFT_eSPI.h>
#include <config.h>

TFT_eSPI tft = TFT_eSPI();

void displayInit() {
  // Backlight must be enabled before init (else ESP32 logs "IO 4 not GPIO")
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, HIGH);

  tft.init();
  tft.setRotation(1);  // Landscape: 240x135
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);

  tft.setTextSize(2);
  tft.setCursor(0, 4);
  tft.print("YARD SPRAYER");

  tft.setTextSize(1);
  tft.setCursor(0, 60);
  tft.print("WiFi: ");
  tft.print(WIFI_SSID);
  tft.setCursor(0, 80);
  tft.print("IP: 192.168.4.1");
  tft.setCursor(0, 100);
  tft.print("Waiting for tablet...");
}

void displayUpdate(const SprayerTelemetry& tel, bool connected, float valvePct, float gpm) {
  tft.fillScreen(TFT_BLACK);

  // ---- Title ----
  tft.setTextSize(2);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setCursor(0, 2);
  tft.print("YARD SPRAYER");

  // ---- Connection status (top-right) ----
  tft.setTextSize(1);
  if (connected) {
    tft.setTextColor(TFT_GREEN, TFT_BLACK);
    tft.setCursor(176, 10);
    tft.print("CONNECTED");
  } else {
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.setCursor(188, 10);
    tft.print("WAITING");
  }

  tft.drawFastHLine(0, 30, 240, TFT_DARKGREY);

  // ---- Data rows ----
  int y = 38;
  tft.setTextSize(2);

  // Left column
  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.setCursor(0, y);
  tft.printf("SPD %.1f", tel.groundSpeedMph);

  tft.setCursor(0, y + 30);
  tft.printf("GPM %.2f", gpm);

  tft.setCursor(0, y + 60);
  tft.printf("VALVE %.0f%%", valvePct);

  // Right column
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.setCursor(122, y);
  tft.printf("TGT %.0f", tel.targetGpa);

  tft.setCursor(122, y + 30);
  if (tel.sprayOn) {
    tft.setTextColor(TFT_GREEN, TFT_BLACK);
    tft.print("SPRAY ON");
  } else {
    tft.setTextColor(TFT_DARKGREY, TFT_BLACK);
    tft.print("SPRAY OFF");
  }

  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setCursor(122, y + 60);
  tft.printf("SATS %d", tel.gpsSatellites);
}
