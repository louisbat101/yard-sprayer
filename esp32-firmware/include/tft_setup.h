// tft_setup.h — TFT_eSPI configuration for LilyGO T-Display
// 1.14" ST7789, 135x240 (used in landscape = 240x135)
//
// This file is auto-included by TFT_eSPI via __has_include(<tft_setup.h>).

#define ST7789_DRIVER

#define TFT_WIDTH  135
#define TFT_HEIGHT 240

// LilyGO T-Display pinout
#define TFT_MOSI 19
#define TFT_SCLK 18
#define TFT_CS    5
#define TFT_DC    16
#define TFT_RST   23
#define TFT_BL    4   // Backlight control

// Fonts
#define LOAD_GLCD
#define LOAD_FONT2
#define LOAD_FONT4
#define LOAD_FONT6
#define LOAD_FONT7
#define LOAD_FONT8
#define LOAD_GFXFF
#define SMOOTH_FONT

// SPI
#define SPI_FREQUENCY 27000000
