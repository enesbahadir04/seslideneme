import processing.sound.*;

AudioIn mikrofon;
FFT fft;

int bands = 512;
float[] spectrum = new float[bands];

PShape[] sekiller = new PShape[3];

int toplamSekil = 450;
ArrayList<Sekiller> sekilListesi = new ArrayList<Sekiller>();

float basHassasiyet = 120;
float midHassasiyet = 520;
float tizHassasiyet = 1450;

float basSmooth = 0;
float midSmooth = 0;
float tizSmooth = 0;

float basForm = 0.333;
float midForm = 0.333;
float tizForm = 0.334;

float formGecisHizi = 0.045;
float hareketGecisHizi = 0.06;   // şekle daha hızlı oturma -> daha net kontur

float keskinlik = 3.0;   // şekil netliği: 1 = yumuşak karışım, yüksek = baskın bandın şekli net belirir
float titresim = 6;      // parçacık titreşimi (düşük = daha keskin/net kontur)

float sabitBoyut = 9;
float minMesafe = 12;

// --- Ritim / beat tepkisi ---
float beatEsik = 1.4;     // bas enerjisi ortalamanın bu katını aşınca BEAT (düşür = daha hassas, daha çok beat)
float darbeGucu = 55;     // beat anında parçacıkların merkezden dışa fırlama miktarı (px)
float bassEnerjiOrt = 0;  // bas enerjisinin hareketli ortalaması (otomatik)
float darbe = 0;          // anlık beat darbesi 0..1 (otomatik söner)
int   sonBeatFrame = 0;   // çok sık tetiklenmeyi önler

float zaman = 0;

float sessizEsik = 0.04;
float sessizForm = 1.0;

Yol basYolu;
Yol midYolu;
Yol tizYolu;

float hedefFormYuksekligi = 620;

void setup() {
  size(950, 900);
  pixelDensity(1);
  frameRate(60);
  noStroke();
  shapeMode(CENTER);

  sekiller[0] = loadShape("bass.svg");
  sekiller[1] = loadShape("midd.svg");
  sekiller[2] = loadShape("tizz.svg");

  for (int i = 0; i < 3; i++) {
    if (sekiller[i] == null) {
      println("SVG dosyası yüklenemedi. data klasörünü kontrol et. Hatalı index: " + i);
      exit();
    } else {
      sekiller[i].disableStyle();
    }
  }

  ozelFormlariHazirla();

  mikrofon = new AudioIn(this, 0);
  mikrofon.start();

  fft = new FFT(this, bands);
  fft.input(mikrofon);

  for (int i = 0; i < toplamSekil; i++) {
    int grup = i % 3;
    sekilListesi.add(new Sekiller(grup, i));
  }
}

void draw() {
  background(0);

  fft.analyze(spectrum);

  basSmooth = sesOku(0, 30, basHassasiyet, basSmooth);
  midSmooth = sesOku(31, 150, midHassasiyet, midSmooth);
  tizSmooth = sesOku(151, bands - 1, tizHassasiyet, tizSmooth);

  ritimAlgila();   // bas vuruşlarını yakala, 'darbe' değerini güncelle

  // Beat anında çok hafif ekran parlaması (vuruş hissi)
  noStroke();
  fill(255, darbe * 18);
  rect(0, 0, width, height);

  formOranlariniGuncelle();
  gruplariSesOraninaGoreAyarla();

  zaman += 0.0025;

  for (Sekiller s : sekilListesi) {
    s.guncelle();
  }

  cakismayiEngelle();

  for (Sekiller s : sekilListesi) {
    s.sinirlariKoru();
    s.ciz();
  }
}

float sesOku(int baslangic, int bitis, float hassasiyet, float eskiDeger) {
  float toplam = 0;

  for (int i = baslangic; i <= bitis; i++) {
    toplam += spectrum[i];
  }

  float ortalama = toplam / (bitis - baslangic + 1);
  float yeniDeger = ortalama * hassasiyet;
  yeniDeger = constrain(yeniDeger, 0, 1);

  return lerp(eskiDeger, yeniDeger, 0.05);
}

// Bas enerjisindeki ani sıçramaları yakalayıp 'darbe'yi tetikler (beat detection)
void ritimAlgila() {
  float toplam = 0;
  for (int i = 0; i <= 30; i++) toplam += spectrum[i];
  float ham = (toplam / 31.0) * basHassasiyet;   // anlık bas enerjisi

  bassEnerjiOrt = lerp(bassEnerjiOrt, ham, 0.1);  // hareketli ortalama

  // ani sıçrama + ortalamanın belirgin üstünde + min aralık (8 frame) + sessizlik filtresi
  if (ham > 0.08 && ham > bassEnerjiOrt * beatEsik && frameCount - sonBeatFrame > 8) {
    darbe = 1.0;
    sonBeatFrame = frameCount;
  }

  darbe *= 0.88;   // darbe yumuşakça söner
}

void formOranlariniGuncelle() {
  float toplamSes = basSmooth + midSmooth + tizSmooth;

  float hedefBas;
  float hedefMid;
  float hedefTiz;
  float hedefSessizForm;

  if (toplamSes < sessizEsik) {
    hedefBas = 0.333;
    hedefMid = 0.333;
    hedefTiz = 0.334;
    hedefSessizForm = 1.0;
  } else {
    hedefBas = basSmooth / toplamSes;
    hedefMid = midSmooth / toplamSes;
    hedefTiz = tizSmooth / toplamSes;

    // Keskinlik: baskın bandın şekli net belirsin diye oranları güçlendir
    // (örn. bas baskınsa parçacıklar bulanık ortalama yerine net bas şekline gider)
    hedefBas = pow(hedefBas, keskinlik);
    hedefMid = pow(hedefMid, keskinlik);
    hedefTiz = pow(hedefTiz, keskinlik);
    float toplamHedef = hedefBas + hedefMid + hedefTiz;
    if (toplamHedef > 0) {
      hedefBas /= toplamHedef;
      hedefMid /= toplamHedef;
      hedefTiz /= toplamHedef;
    }

    hedefSessizForm = 0.0;
  }

  basForm = lerp(basForm, hedefBas, formGecisHizi);
  midForm = lerp(midForm, hedefMid, formGecisHizi);
  tizForm = lerp(tizForm, hedefTiz, formGecisHizi);

  sessizForm = lerp(sessizForm, hedefSessizForm, formGecisHizi);

  float toplam = basForm + midForm + tizForm;

  basForm /= toplam;
  midForm /= toplam;
  tizForm /= toplam;
}

void gruplariSesOraninaGoreAyarla() {
  for (Sekiller s : sekilListesi) {
    int eskiGrup = s.grup;

    if (s.oranSeed < basForm) {
      s.grup = 0;
    } else if (s.oranSeed < basForm + midForm) {
      s.grup = 1;
    } else {
      s.grup = 2;
    }

    if (s.grup != eskiGrup) {
      s.renkAyarla();
    }
  }
}

void cakismayiEngelle() {
  float minMesafeKare = minMesafe * minMesafe;

  for (int i = 0; i < sekilListesi.size(); i++) {
    Sekiller a = sekilListesi.get(i);

    for (int j = i + 1; j < sekilListesi.size(); j++) {
      Sekiller b = sekilListesi.get(j);

      float dx = b.x - a.x;
      float dy = b.y - a.y;
      float mesafeKare = dx * dx + dy * dy;

      if (mesafeKare < minMesafeKare) {
        float mesafe = sqrt(mesafeKare);

        if (mesafe == 0) {
          dx = random(-1, 1);
          dy = random(-1, 1);
          mesafe = sqrt(dx * dx + dy * dy);
        }

        float itme = (minMesafe - mesafe) * 0.18;
        float nx = dx / mesafe;
        float ny = dy / mesafe;

        a.x -= nx * itme;
        a.y -= ny * itme;

        b.x += nx * itme;
        b.y += ny * itme;
      }
    }
  }
}

void ozelFormlariHazirla() {
  basYolu = yeniBasYolu();
  midYolu = yeniMidYolu();
  tizYolu = yeniTizYolu();
}

// =====================================================
// BAS FORMU
// =====================================================

Yol yeniBasYolu() {
  Yol y = new Yol();

  y.ekle(298.26, 255.68);

  y.bezierEkle(298.26, 255.68, 274.73, 255.68, 255.66, 236.60, 255.66, 213.08, 24);
  y.bezierEkle(255.66, 213.08, 255.66, 189.56, 236.60, 170.45, 213.06, 170.45, 24);

  y.cizgiEkle(213.06, 170.45, 111.73, 170.45, 18);
  y.bezierEkle(111.73, 170.45, 101.72, 170.45, 92.53, 173.90, 85.25, 179.69, 14);

  y.cizgiEkle(85.25, 179.69, 85.25, 42.60, 24);

  y.bezierEkle(85.25, 42.60, 85.25, 19.10, 66.13, 0.00, 42.60, 0.00, 24);
  y.bezierEkle(42.60, 0.00, 19.07, 0.00, 0.00, 19.10, 0.00, 42.60, 24);

  y.cizgiEkle(0.00, 42.60, 0.00, 468.73, 42);

  y.bezierEkle(0.00, 468.73, 0.00, 492.26, 19.08, 511.33, 42.60, 511.33, 24);

  y.cizgiEkle(42.60, 511.33, 213.05, 511.33, 24);

  y.bezierEkle(213.05, 511.33, 236.60, 511.33, 255.65, 492.25, 255.65, 468.73, 24);
  y.bezierEkle(255.65, 468.73, 255.65, 445.21, 274.73, 426.13, 298.25, 426.13, 24);
  y.bezierEkle(298.25, 426.13, 321.77, 426.13, 340.88, 407.05, 340.88, 383.50, 24);

  y.cizgiEkle(340.88, 383.50, 340.88, 298.29, 18);

  y.bezierEkle(340.88, 298.29, 340.88, 274.74, 321.80, 255.69, 298.25, 255.69, 24);
  y.cizgiEkle(298.25, 255.69, 298.26, 255.68, 2);

  // İç boşluk konturu
  y.ekle(255.66, 383.50);

  y.bezierEkle(255.66, 383.50, 255.66, 407.05, 236.60, 426.13, 213.06, 426.13, 24);

  y.cizgiEkle(213.06, 426.13, 127.85, 426.13, 16);

  y.bezierEkle(127.85, 426.13, 104.30, 426.13, 85.25, 407.05, 85.25, 383.50, 24);

  y.cizgiEkle(85.25, 383.50, 85.25, 246.44, 18);

  y.bezierEkle(85.25, 246.44, 92.53, 252.23, 101.72, 255.68, 111.73, 255.68, 14);

  y.cizgiEkle(111.73, 255.68, 213.06, 255.68, 16);

  y.bezierEkle(213.06, 255.68, 236.61, 255.68, 255.66, 274.74, 255.66, 298.28, 24);

  y.cizgiEkle(255.66, 298.28, 255.66, 383.50, 14);

  return y;
}

// =====================================================
// TIZ FORMU
// =====================================================

Yol yeniTizYolu() {
  Yol y = new Yol();

  y.ekle(409.61, 358.40);

  y.bezierEkle(409.61, 358.40, 409.61, 386.68, 386.69, 409.60, 358.41, 409.60, 24);
  y.bezierEkle(358.41, 409.60, 330.13, 409.60, 307.20, 432.52, 307.20, 460.80, 24);
  y.bezierEkle(307.20, 460.80, 307.20, 489.08, 284.28, 512.01, 256.00, 512.01, 24);

  y.cizgiEkle(256.00, 512.01, 153.59, 512.01, 16);

  y.bezierEkle(153.59, 512.01, 125.31, 512.01, 102.39, 489.08, 102.39, 460.80, 24);

  y.cizgiEkle(102.39, 460.80, 102.39, 204.81, 28);
  y.cizgiEkle(102.39, 204.81, 51.19, 204.81, 10);

  y.bezierEkle(51.19, 204.81, 22.91, 204.81, 0.00, 181.88, 0.00, 153.60, 24);
  y.bezierEkle(0.00, 153.60, 0.00, 125.32, 22.91, 102.40, 51.19, 102.40, 24);

  y.cizgiEkle(51.19, 102.40, 102.39, 102.40, 10);
  y.cizgiEkle(102.39, 102.40, 102.39, 51.20, 10);

  y.bezierEkle(102.39, 51.20, 102.39, 22.92, 125.31, 0.00, 153.59, 0.00, 24);
  y.bezierEkle(153.59, 0.00, 181.87, 0.00, 204.80, 22.92, 204.80, 51.20, 24);

  y.cizgiEkle(204.80, 51.20, 204.80, 102.40, 10);
  y.cizgiEkle(204.80, 102.40, 358.40, 102.40, 20);

  y.bezierEkle(358.40, 102.40, 386.68, 102.40, 409.60, 125.33, 409.60, 153.60, 24);
  y.bezierEkle(409.60, 153.60, 409.60, 181.87, 386.68, 204.81, 358.40, 204.81, 24);

  y.cizgiEkle(358.40, 204.81, 204.80, 204.81, 20);
  y.cizgiEkle(204.80, 204.81, 204.80, 358.41, 20);

  y.bezierEkle(204.80, 358.41, 204.80, 386.69, 227.72, 409.61, 256.00, 409.61, 24);
  y.bezierEkle(256.00, 409.61, 284.28, 409.61, 307.20, 386.69, 307.20, 358.41, 24);
  y.bezierEkle(307.20, 358.41, 307.20, 330.13, 330.13, 307.20, 358.41, 307.20, 24);
  y.bezierEkle(358.41, 307.20, 386.69, 307.20, 409.61, 330.13, 409.61, 358.41, 24);

  return y;
}

// =====================================================
// MID FORMU
// =====================================================

Yol yeniMidYolu() {
  Yol y = new Yol();

  y.ekle(512, 153.58);

  y.cizgiEkle(512, 153.58, 512, 460.77, 26);

  y.bezierEkle(512, 460.77, 512, 489.05, 489.07, 511.98, 460.79, 511.98, 24);
  y.bezierEkle(460.79, 511.98, 432.51, 511.98, 409.60, 489.05, 409.60, 460.77, 24);

  y.cizgiEkle(409.60, 460.77, 409.60, 153.58, 26);

  y.bezierEkle(409.60, 153.58, 409.60, 125.32, 386.68, 102.39, 358.41, 102.39, 24);
  y.bezierEkle(358.41, 102.39, 330.14, 102.39, 307.20, 125.32, 307.20, 153.58, 24);

  y.cizgiEkle(307.20, 153.58, 307.20, 460.77, 26);

  y.bezierEkle(307.20, 460.77, 307.20, 489.05, 284.28, 511.98, 256.01, 511.98, 24);
  y.bezierEkle(256.01, 511.98, 227.74, 511.98, 204.82, 489.05, 204.82, 460.77, 24);

  y.cizgiEkle(204.82, 460.77, 204.82, 153.58, 26);

  y.bezierEkle(204.82, 153.58, 204.82, 125.32, 181.89, 102.39, 153.61, 102.39, 24);
  y.bezierEkle(153.61, 102.39, 125.33, 102.39, 102.42, 125.32, 102.42, 153.58, 24);

  y.cizgiEkle(102.42, 153.58, 102.42, 460.77, 26);

  y.bezierEkle(102.42, 460.77, 102.42, 489.05, 79.50, 511.98, 51.23, 511.98, 24);
  y.bezierEkle(51.23, 511.98, 22.96, 511.98, 0, 489.06, 0, 460.78, 24);

  y.cizgiEkle(0, 460.78, 0, 51.19, 34);

  y.bezierEkle(0, 51.19, 0, 22.92, 22.93, 0, 51.21, 0, 24);
  y.bezierEkle(51.21, 0, 79.49, 0, 102.40, 22.92, 102.40, 51.19, 24);

  y.bezierEkle(102.40, 51.19, 102.40, 22.92, 125.32, 0, 153.60, 0, 24);
  y.bezierEkle(153.60, 0, 181.88, 0, 204.81, 22.92, 204.81, 51.19, 24);

  y.bezierEkle(204.81, 51.19, 204.81, 79.46, 227.73, 102.38, 256.00, 102.38, 24);
  y.bezierEkle(256.00, 102.38, 284.27, 102.38, 307.19, 79.46, 307.19, 51.19, 24);

  y.bezierEkle(307.19, 51.19, 307.19, 22.92, 330.13, 0, 358.40, 0, 24);
  y.bezierEkle(358.40, 0, 386.67, 0, 409.59, 22.92, 409.59, 51.19, 24);

  y.bezierEkle(409.59, 51.19, 409.59, 79.46, 432.51, 102.38, 460.78, 102.38, 24);
  y.bezierEkle(460.78, 102.38, 489.05, 102.38, 511.99, 125.31, 511.99, 153.57, 24);

  return y;
}

// =====================================================
// YOL SINIFI
// =====================================================

class Yol {
  ArrayList<PVector> noktalar = new ArrayList<PVector>();

  float minX = 999999;
  float minY = 999999;
  float maxX = -999999;
  float maxY = -999999;

  void ekle(float x, float y) {
    noktalar.add(new PVector(x, y));

    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }

  void cizgiEkle(float x1, float y1, float x2, float y2, int adim) {
    for (int i = 1; i <= adim; i++) {
      float t = i / float(adim);
      float x = lerp(x1, x2, t);
      float y = lerp(y1, y2, t);
      ekle(x, y);
    }
  }

  void bezierEkle(float x1, float y1, float cx1, float cy1, float cx2, float cy2, float x2, float y2, int adim) {
    for (int i = 1; i <= adim; i++) {
      float t = i / float(adim);

      float x = bezierPoint(x1, cx1, cx2, x2, t);
      float y = bezierPoint(y1, cy1, cy2, y2, t);

      ekle(x, y);
    }
  }

  PVector noktaGetir(float oran, float merkezX, float merkezY, float hedefYukseklik) {
    if (noktalar == null || noktalar.size() == 0) {
      return new PVector(merkezX, merkezY);
    }

    oran = constrain(oran, 0, 0.999999);

    int index = (int)(oran * (noktalar.size() - 1));
    index = constrain(index, 0, noktalar.size() - 1);

    PVector p = noktalar.get(index);

    float orijinalYukseklik = maxY - minY;

    if (orijinalYukseklik == 0) {
      orijinalYukseklik = 1;
    }

    float olcek = hedefYukseklik / orijinalYukseklik;

    float sekilMerkezX = (minX + maxX) * 0.5;
    float sekilMerkezY = (minY + maxY) * 0.5;

    float x = merkezX + (p.x - sekilMerkezX) * olcek;
    float y = merkezY + (p.y - sekilMerkezY) * olcek;

    return new PVector(x, y);
  }
}

// =====================================================
// ŞEKİL SINIFI
// =====================================================

class Sekiller {
  float x;
  float y;

  int id;
  int grup;

  float seed;
  float oranSeed;

  color renk;

  Sekiller(int grup, int id) {
    this.grup = grup;
    this.id = id;

    seed = random(10000);
    oranSeed = random(1);

    x = random(width);
    y = random(height);

    renkAyarla();
  }

  void renkAyarla() {
    if (grup == 0) {
      renk = color(255, 60, 60);
    } else if (grup == 1) {
      renk = color(255);
    } else {
      renk = color(80, 140, 255);
    }
  }

  void guncelle() {
    float cx = width / 2.0;
    float cy = height / 2.0;

    float oran = id / float(toplamSekil - 1);

    PVector basNokta = basYolu.noktaGetir(oran, cx, cy, hedefFormYuksekligi);
    PVector midNokta = midYolu.noktaGetir(oran, cx, cy, hedefFormYuksekligi);
    PVector tizNokta = tizYolu.noktaGetir(oran, cx, cy, hedefFormYuksekligi);

    float aktifX = basNokta.x * basForm + midNokta.x * midForm + tizNokta.x * tizForm;
    float aktifY = basNokta.y * basForm + midNokta.y * midForm + tizNokta.y * tizForm;

    float dikeyX;
    float dikeyY;

    float dikeyGenislik = 160;
    float dikeyYukseklik = 650;

    float sol = cx - dikeyGenislik / 2;
    float sag = cx + dikeyGenislik / 2;
    float ust = cy - dikeyYukseklik / 2;
    float alt = cy + dikeyYukseklik / 2;

    float cevre = 2 * (dikeyGenislik + dikeyYukseklik);
    float p = oran * cevre;

    if (p < dikeyGenislik) {
      dikeyX = sol + p;
      dikeyY = ust;
    } else if (p < dikeyGenislik + dikeyYukseklik) {
      dikeyX = sag;
      dikeyY = ust + (p - dikeyGenislik);
    } else if (p < dikeyGenislik * 2 + dikeyYukseklik) {
      dikeyX = sag - (p - dikeyGenislik - dikeyYukseklik);
      dikeyY = alt;
    } else {
      dikeyX = sol;
      dikeyY = alt - (p - dikeyGenislik * 2 - dikeyYukseklik);
    }

    float hedefX = lerp(aktifX, dikeyX, sessizForm);
    float hedefY = lerp(aktifY, dikeyY, sessizForm);

    float noiseX = map(noise(seed, zaman), 0, 1, -titresim, titresim);
    float noiseY = map(noise(seed + 500, zaman), 0, 1, -titresim, titresim);

    x = lerp(x, hedefX + noiseX, hareketGecisHizi);
    y = lerp(y, hedefY + noiseY, hareketGecisHizi);
  }

  void sinirlariKoru() {
    x = constrain(x, sabitBoyut, width - sabitBoyut);
    y = constrain(y, sabitBoyut, height - sabitBoyut);
  }

  void ciz() {
    // Beat darbesi: parçacığı merkezden dışa fırlat (boyut SABİT, sadece konum kayar)
    float cx = width / 2.0;
    float cy = height / 2.0;
    float dx = x - cx;
    float dy = y - cy;
    float uzaklik = sqrt(dx * dx + dy * dy);
    float nx = (uzaklik > 0) ? dx / uzaklik : 0;
    float ny = (uzaklik > 0) ? dy / uzaklik : 0;

    float gx = x + nx * darbe * darbeGucu;
    float gy = y + ny * darbe * darbeGucu;

    // Beat anında parlama — renk kimliği korunur, sadece ışıldar
    color parlakRenk = lerpColor(renk, color(255), darbe * 0.5);

    pushMatrix();
    translate(gx, gy);
    fill(parlakRenk, 255);
    shape(sekiller[grup], 0, 0, sabitBoyut, sabitBoyut);
    popMatrix();
  }
}
