/**
 * ESP32 + CCS811  -> Nordic UART Service
 *   TX (notify):  "eco2,etvoc\n"  every 1 s
 *   RX (write):   ignored (but required by UART apps)
 */

 #include <Arduino.h>
 #include <Wire.h>
 #include "ccs811.h"
 
 #include <BLEDevice.h>
 #include <BLEServer.h>
 #include <BLEUtils.h>
 #include <BLE2902.h>
 
 // ----------- UUIDs (standard NUS) ------------
 #define NUS_SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
 #define NUS_RX_CHAR_UUID        "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"   // central → ESP32
 #define NUS_TX_CHAR_UUID        "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"   // ESP32  → central
 
 // ----------- I2C pins ------------------------
 #define SDA_PIN 21
 #define SCL_PIN 22
 
 // ----------- Globals -------------------------
 BLECharacteristic* txChar;
 BLECharacteristic* rxChar;
 bool deviceConnected = false;
 
 class ServerCB : public BLEServerCallbacks {
   void onConnect(BLEServer*)   override { deviceConnected = true;  }
   void onDisconnect(BLEServer*)override { deviceConnected = false; }
 };
 
 class RXCB : public BLECharacteristicCallbacks {
   void onWrite(BLECharacteristic* c) override {
     std::string s = c->getValue();
     Serial.print("RX <- \""); Serial.print(s.c_str()); Serial.println("\"");
   }
 };
 
 // ----------- CCS811 --------------------------
 CCS811 gas(-1, CCS811_SLAVEADDR_1);
 
 // ----------- setup ---------------------------
 void setup() {
   Serial.begin(115200);
   Serial.println("\n-- CCS811 + Nordic UART Service --");
 
   // I2C + sensor
   Wire.begin(SDA_PIN, SCL_PIN);
   gas.set_i2cdelay(50);
   if (!gas.begin() || !gas.start(CCS811_MODE_1SEC)) {
     Serial.println("CCS811 init failed"); while (true) delay(1000);
   }
 
   // BLE
   BLEDevice::init("Air‑Quality UART");
   BLEServer* server = BLEDevice::createServer();
   server->setCallbacks(new ServerCB);
 
   BLEService* uart = server->createService(NUS_SERVICE_UUID);
 
   // RX (write)
   rxChar = uart->createCharacteristic(
              NUS_RX_CHAR_UUID,
              BLECharacteristic::PROPERTY_WRITE |
              BLECharacteristic::PROPERTY_WRITE_NR);
   rxChar->setCallbacks(new RXCB);
 
   // TX (notify + read)
   txChar = uart->createCharacteristic(
              NUS_TX_CHAR_UUID,
              BLECharacteristic::PROPERTY_NOTIFY |
              BLECharacteristic::PROPERTY_READ);
   txChar->addDescriptor(new BLE2902());     // CCCD
 
   uart->start();
   server->getAdvertising()->addServiceUUID(NUS_SERVICE_UUID);
   server->getAdvertising()->start();
   Serial.println("Advertising as \"Air‑Quality UART\"");
 }
 
 // ----------- loop ----------------------------
 void loop() {
   uint16_t eco2, tvoc, err, raw;
   gas.read(&eco2, &tvoc, &err, &raw);
 
   if (err == CCS811_ERRSTAT_OK) {
     Serial.printf("eco2=%u ppm  tvoc=%u ppb\n", eco2, tvoc);
 
     if (deviceConnected) {
       char buf[20];
       int n = snprintf(buf, sizeof buf, "%u,%u\n", eco2, tvoc);
       txChar->setValue((uint8_t*)buf, n);
       txChar->notify();
     }
   }
 
   delay(1000);
 }
 