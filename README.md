# Ses Görselleştirme (seslideneme)

Mikrofondan gelen sesi gerçek zamanlı analiz edip, sesin **bas / mid / tiz** dengesine göre
yüzlerce küçük SVG parçacığını farklı formlara dönüştüren etkileşimli bir Processing eskizi.

**Yazan:** İbrahim Enes Bahadır — Mimar Sinan Güzel Sanatlar Üniversitesi

---

## Nasıl çalışır?

- Mikrofon girişi `AudioIn` ile alınır, `FFT` ile frekans spektrumuna ayrılır.
- Spektrum üç banda bölünür:
  - **Bas** (kırmızı) — düşük frekanslar
  - **Mid** (beyaz) — orta frekanslar
  - **Tiz** (mavi) — yüksek frekanslar
- Hangi bant baskınsa, 450 adet parçacık o bandın SVG formuna (`bass.svg`, `midd.svg`, `tizz.svg`)
  doğru akar. Sessizlikte parçacıklar dikey bir forma toplanır.
- Parçacıklar birbirine girmemesi için itme (çakışma engelleme) algoritmasıyla yayılır ve
  `noise()` ile hafifçe titreşir.

## Gereksinimler

- [Processing 4](https://processing.org/download)
- **Sound** kütüphanesi
  Processing içinde: `Sketch → Import Library → Add Library...` → arama kutusuna **Sound** yazıp kur.
- Çalışan bir mikrofon (sistem mikrofon izni verilmiş olmalı).

## Çalıştırma

1. Bu klasörü Processing'in sketch klasöründe tut: `Documents/Processing/seslideneme`
2. `seslideneme.pde` dosyasını Processing ile aç.
3. Sağ üstteki **Play (▶)** tuşuna bas.
4. Mikrofona konuş / müzik çal — parçacıkların forma göre değiştiğini gör.

> İlk açılışta macOS mikrofon izni isteyebilir. İzin vermezsen ses okunmaz.

## Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `seslideneme.pde` | Ana eskiz (tüm kod) |
| `bass.svg` | Bas formu |
| `midd.svg` | Mid formu |
| `tizz.svg` | Tiz formu |

## Ayarlanabilir parametreler

Kodun başındaki değişkenlerle görseli kişiselleştirebilirsin:

- `toplamSekil` — parçacık sayısı (varsayılan 450)
- `basHassasiyet`, `midHassasiyet`, `tizHassasiyet` — her bandın ses hassasiyeti
- `formGecisHizi`, `hareketGecisHizi` — geçiş yumuşaklığı
- `sabitBoyut`, `minMesafe` — parçacık boyutu ve aralarındaki minimum mesafe
- `sessizEsik` — sessizlik eşiği
