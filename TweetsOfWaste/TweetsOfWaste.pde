#include <CameraC328R.h>
#include <NewSoftSerial.h>
#include <WiFly.h>
#include <Imgur.h>

#define BUTTON_PIN 4
#define LED_PIN 13
#define PAGE_SIZE 64
#define USB_BAUD 115200
#define CAMERA_BAUD 14400
#define SYNC_INTERVAL 15000

// Wifi parameters
char passphrase[] = "WIFI-PASS";
char ssid[] = "WIFI-SSID";

// Imgur image upload
char imgurAppKey[] = "IMGUR APP KEY";
Imgur imgur(imgurAppKey);
Client *wiflyClient;

// Camera              rx, tx
NewSoftSerial camSerial(2, 3);
CameraC328R camera(&camSerial);
uint16_t pictureSize = 0;
uint16_t pictureSizeCount = 0;

// twitter
// supertweet.net username:password in base64
char superTweetPass[] = "SUPERTWEET_PASS_BASE64";


void setup() {
  Serial.begin(USB_BAUD);
  camSerial.begin(CAMERA_BAUD);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  Serial.println("TweetOfWaste v0.2");
  
  WiFly.begin();
  Serial.println("waiting ...");
  delay(10000);
  Serial.println("joining wifi ...");
  if (!WiFly.join(ssid, passphrase)) {
    Serial.println("Association failed.");
    while (1) { }
  } 
  Serial.println("joined, ready!"); 
}


void getImgurJPEGPicture_callback(
  uint16_t pictureSize, uint16_t packageSize, uint16_t packageCount, byte* package) {
  
  if (pictureSizeCount == 0) {
    Serial.print("size:");
    Serial.println(pictureSize);
  }
  
  // packageSize is the size of the picture part of the package
  pictureSizeCount += packageSize;
  wiflyClient->write(package, packageSize);

  if( pictureSizeCount >= pictureSize ) {
    digitalWrite(LED_PIN, LOW);
    Serial.flush();
  }
}


void imgurImageTransfer(Client *client) {
  Serial.println("imgur image transfer ...");
  wiflyClient = client;
  pictureSizeCount = 0;
  if (!camera.getJPEGPictureData(&getImgurJPEGPicture_callback)) {
    Serial.println("Get JPEG failed.");
  }
  Serial.print("size:");
  Serial.println(pictureSizeCount);
  Serial.println("imgurImageTransfer done");
}


void tweet(char *message) {
  Client twitter("api.supertweet.net", 80);
  Serial.println("connecting to supertweet ...");
  
  if (twitter.connect()) {
    twitter.println("POST /1/statuses/update.xml HTTP/1.0");
    twitter.println("Host: api.supertweet.net");
    twitter.print("Authorization: Basic ");
    twitter.println(superTweetPass);
    twitter.println("Content-Type: application/x-www-form-urlencoded");
    twitter.print("Content-Length: ");
    twitter.println(strlen(message)+9);
    twitter.println();
    twitter.print("status=");
    twitter.println(message);
    twitter.flush();
    Serial.println("waiting for response ...");
    while (twitter.connected()) {
      if (twitter.available()) {
        char c = twitter.read();
        Serial.print(c);
      }
    }
    Serial.println("done, closing connection.");
    twitter.stop();
  }
  else {
    Serial.println("failed");
  }
}


boolean uploadPic() {
  Serial.println("start uploading ...");

  long start = millis();
  if (!camera.initial(CameraC328R::CT_JPEG, CameraC328R::PR_160x120, CameraC328R::JR_640x480)) {
    Serial.println("Initial failed.");
    return false;
  }
  Serial.print("initial: "); Serial.println(millis() - start);
  if (!camera.setPackageSize(64)) {
    Serial.println("Package size failed.");
    return false;
  }
  Serial.print("setSize: "); Serial.println(millis() - start);
  if (!camera.setLightFrequency(CameraC328R::FT_50Hz)) {
    Serial.println( "Light frequency failed." );
    return false;
  }
  Serial.print("setFreq: "); Serial.println(millis() - start);
  if (!camera.snapshot(CameraC328R::ST_COMPRESSED, 0)) {
    Serial.println("Snapshot failed.");
    return false;
  }
  Serial.print("snapShot: "); Serial.println(millis() - start);
    
  // first get the size, then data
  if (!camera.getJPEGPictureSize( CameraC328R::PT_SNAPSHOT, PROCESS_DELAY, pictureSize)) {
    Serial.println("getSize failed");
    return false;
  }
  Serial.print("size:");
  Serial.println(pictureSize);

  // start image upload    
  int ret = imgur.upload(pictureSize, &imgurImageTransfer);
     
  Serial.print("status: ");
  Serial.print(ret);
  Serial.print(", ");
  Serial.println(imgur.getStatus());
  Serial.print("url: ");
  Serial.println(imgur.getImgURL());

  char buf[100];
  strcpy(buf, "Testing ... ");
  strcat(buf, imgur.getImgURL());
  Serial.print("message: ");
  Serial.println(buf);

  tweet(buf);
  Serial.println("done!");  
  
  return true;
}



int i;
long nextSync;

void loop() {
  
  long now = millis();
  if (nextSync < now) {
    Serial.print("syncing ...");
    if (!camera.sync()) { 
      Serial.println("Sync failed.");
      return;
    }
    Serial.println("done");
    nextSync = now + SYNC_INTERVAL;  
  }
  
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("starting snapshot");
    delay(100);    
    digitalWrite(LED_PIN, HIGH);
    if (!uploadPic()) {
      Serial.println("failed");
      return;
    }
  }
}

