# 🍔 BalSipariş - Premium Yemek Siparişi ve Yönetim Uygulaması

BalSipariş, modern yemek siparişi süreçlerini, gelişmiş restoran şube yönetimini, canlı destek personeli atama sistemini ve kupon yönetimini tek bir çatı altında toplayan; hem **Canlı Firebase (Firestore + Auth)** veritabanı altyapısıyla hem de tamamen **Çevrimdışı Mock (Demo) Modu** ile kesintisiz çalışabilen üst seviye bir Flutter uygulamasıdır.

---

## ✨ Uygulama Özellikleri

### 1. 🏪 Restoran Odaklı Keşif ve Özel Menü Sayfaları (Yeni!)
*   **Restoran-Öncelikli Listeleme**: Kategorilerde veya arama çubuğunda artık doğrudan yemekler yerine **Aktif Restoranlar** listelenir. Böylece kullanıcılar öncelikle yakınlarındaki restoran şubelerini keşfederler.
*   **Ayrıntılı Restoran Menü Ekranı (`RestaurantDetailScreen`)**: Her restoranın kendine ait, göz alıcı bir menü sayfası bulunur. Bu ekran içerisinde o restorana ait yemekler aranabilir, alt kategorilere göre filtrelenebilir ve sepet işlemleri yönetilebilir.
*   **Akıllı Mesafe ve Teslimat Hesaplama**: Kullanıcı adresi ile restoran adresi arasındaki WGS84 koordinat mesafesi hesaplanarak teslimat uygunluğu anlık denetlenir.

### 2. 📍 Gel-Al (Takeaway) Siparişlerinde Google Maps Yol Tarifi
*   **Entegre Harita Paneli**: Gel-Al (Takeaway) siparişlerin detaylarında, restoranın fiziksel adresi ve adı şık bir harita kartı şeklinde listelenir.
*   **Canlı Google Haritalar Yönlendirmesi**: "Yol Tarifi" butonuna basıldığında, `url_launcher` vasıtasıyla yerel cihazdaki **Google Haritalar (Google Maps)** uygulaması otomatik açılarak restorana giden en hızlı rota çizilir.

### 3. 🛍️ Tek Restorandan Sipariş (Sepet Kısıtlaması)
*   **Sepet Güvenliği Algoritması**: Kullanıcının aynı anda yalnızca tek bir restorandan sipariş vermesi garanti altına alınır.
*   **Şık Boşaltma Uyarısı**: Sepette ürün varken farklı bir restorandan ürün eklenmek istendiğinde, kullanıcıyı karşılayan estetik bir uyarı penceresi yardımıyla sepet tek tuşla boşaltılarak yeni sipariş akışı başlatılabilir.

### 4. 🔔 Çift Kanallı Sipariş ve Canlı Destek Bildirimleri
*   **Anlık Yerel Bildirimler (`flutter_local_notifications`)**: Siparişlerin durum güncellemeleri (Hazırlanıyor 🍳, Yolda 🛵, Teslim Edildi 🎉 vb.) hem uygulama içi cam efektli kayar bildirim panelleriyle hem de cihaz kapalıyken bile çalışan **Sistem Bildirimleri** ile kullanıcıya ulaştırılır.
*   **Canlı Destek Arka Plan Servisi (`workmanager`)**: Canlı destek personelleri için arka planda çalışan iş parçacığı yönetimi ile uygulama kapalıyken dahi yeni biletler sorgulanır ve bildirim tetiklenir.

### 5. 🔄 Tüm Sayfalarda Dokunmatik Yenileme (Pull-to-Refresh)
*   **Tüm Sayfalarda Canlı Veri Yenileme**: Kullanıcı panelindeki tüm kritik sayfalar (Keşif/Restoran Listesi, Siparişlerim Geçmişi ve Profil Bilgileri) `RefreshIndicator` ile donatılmıştır. Sayfayı aşağı çekmek verileri anında tazeleyerek pürüzsüz bir deneyim sağlar.

### 6. 🏪 Restoran Paneli ve Ciro Yönetimi
*   **Restoran Sahiplerine Özel Erişim**: Restoran sahipleri kendilerine ait şık **Restoran Şube Paneline** erişerek menülerini, kuponlarını ve şubelerini yönetirler.
*   **%80 Ciro Hesaplaması**: Restoran sahiplerinin panelinde gösterilen toplam ciro, sipariş tutarlarının net **%80'i** olacak şekilde hesaplanır. Kalan %20 platform işletim bedeli olarak ayrılır.
*   **Logo Yükleme**: Restoran sahipleri galeriden veya kameradan restoran logolarını fotoğraf olarak yükleyebilirler.

### 7. 👥 Şube Yetkilisi Davet Sistemi
*   **E-Posta ile Davet**: Restoran sahipleri, normal müşterileri restoranlarına "Şube Yetkilisi" olarak atamak için sadece e-posta adreslerini girerek davet gönderebilir.
*   **Onay ve Rol Güncellemesi**: Müşteri daveti kabul ettiğinde rolü anında `'restaurant_owner'` olarak güncellenir ve davet eden restoranın tüm verilerine ortak erişim kazanır.

### 8. 👑 Gelişmiş Kullanıcı ve Yönetici Rolleri (Admin & Support Manager)
*   **Sistem Yöneticisi (Admin)**: Kullanıcıları destek personeli olarak atayabilir, geçmiş sohbetleri kalıcı olarak silebilir ve tüm sistemi yönetebilir.
*   **Destek Yöneticisi (Support Manager)**: Canlı destek personellerini atayabilir ve bekleyen yeni restoran onay başvurularını denetleyebilir.

### 9. 🏷️ Akıllı Kupon & İndirim Yönetimi
*   Restoranlar; kupon kodu, indirim türü (yüzde veya sabit tutar), minimum sepet tutarı, maksimum kullanım limiti ve aktiflik durumunu belirleyerek gelişmiş indirim kuponları tanımlayabilirler.

---

## 🚀 Mock (Demo) Verilerle Çalıştırma

Uygulama, Firebase bağlantısına ihtiyaç duymadan **çevrimdışı ve tam fonksiyonel** olarak çalışabilmesi için zengin bir mock veri setiyle donatılmıştır.

### Demo Modu Nasıl Aktif Edilir?
`lib/services/firebase_service.dart` dosyasındaki şu değişkeni `true` olarak ayarlamanız yeterlidir:
```dart
static bool useDemoMode = true;
```
*Not: Firebase ilklendirilemezse uygulama otomatik olarak Demo Moduna geri düşer (fallback).*

### 🔑 Test Kullanıcı Hesapları (Şifre: `password`)
Uygulamayı farklı rollerle test etmek için aşağıdaki hazır e-posta adreslerini kullanabilirsiniz:

| Rol | E-Posta | Şifre | Açıklama |
| :--- | :--- | :--- | :--- |
| **Sistem Yöneticisi (Admin)** | `admin@yemek.com` | `password` | Kullanıcıları destek personeli atayabilir, tüm sistemi yönetebilir. |
| **Destek Yöneticisi (Support Manager)** | `yonetici@yemek.com` | `password` | Canlı destek personellerini ve restoran onaylarını yönetebilir. |
| **Restoran Sahibi** | `mahmut@yemek.com` | `password` | Şube yönetimi, kupon tanımlama, yetkili davet etme ve ciro takibi yapabilir. |
| **Destek Personeli** | `destek@yemek.com` | `password` | Canlı destek taleplerini yanıtlayabilir, sohbetleri yönetebilir. |
| **Normal Müşteri** | `musteri@yemek.com` | `password` | Sipariş verebilir, destek talebi açabilir, yetkililik davetlerini kabul edebilir. |

---

## 🔥 Firebase ile Entegrasyon ve Kurulum

Uygulamayı canlı ortama taşımak ve gerçek zamanlı veritabanı ile çalıştırmak için aşağıdaki adımları takip edin.

### 1. Firebase Projesi Oluşturma
1. [Firebase Console](https://console.firebase.google.com/) adresine gidin.
2. Yeni bir proje oluşturun.
3. Projenizde **Authentication** (E-posta/Şifre yöntemi aktif) ve **Cloud Firestore** servislerini etkinleştirin.

### 2. FlutterFire CLI Yapılandırması
1. Bilgisayarınızda Firebase CLI'ın kurulu olduğundan emin olun.
2. Proje ana dizininde terminali açarak şu komutu çalıştırın:
   ```bash
   flutterfire configure
   ```
3. İlgili Firebase projenizi seçin. Bu komut, projenize otomatik olarak `lib/firebase_options.dart` dosyasını ekleyecektir.

### 3. Canlı Veritabanı Moduna Geçiş
`lib/services/firebase_service.dart` dosyasındaki `useDemoMode` değişkenini `false` yapın:
```dart
static bool useDemoMode = false;
```

### 📂 Firestore Koleksiyon Yapısı (Koleksiyon Şemaları)

Uygulamanın canlı modda kullandığı koleksiyonlar ve alanları aşağıda belirtilmiştir:

#### 1. `users` (Kullanıcılar)
```json
{
  "uid": "String",
  "email": "String",
  "fullName": "String",
  "phone": "String",
  "address": "String",
  "role": "String (customer | restaurant_owner | support | support_manager | admin)",
  "restaurantName": "String",
  "restaurantAddress": "String"
}
```

#### 2. `orders` (Siparişler)
```json
{
  "id": "String",
  "customerId": "String",
  "customerName": "String",
  "items": [
    {
      "foodItem": "Map",
      "quantity": "Int"
    }
  ],
  "totalAmount": "Double",
  "status": "String (pending | preparing | on_the_way | delivered | ready_for_pickup)",
  "createdAt": "String (ISO8601)",
  "isTakeaway": "Boolean",
  "note": "String",
  "rating": "Int"
}
```

#### 3. `branches` (Restoran Şubeleri)
```json
{
  "id": "String",
  "restaurantOwnerId": "String",
  "name": "String",
  "address": "String",
  "phone": "String",
  "latitude": "Double",
  "longitude": "Double",
  "maxDeliveryDistance": "Double"
}
```

#### 4. `branch_invitations` (Şube Yetkilisi Davetleri)
```json
{
  "id": "String",
  "restaurantOwnerId": "String",
  "restaurantName": "String",
  "inviteeEmail": "String",
  "inviteeUid": "String",
  "status": "String (pending | accepted | declined)",
  "createdAt": "String (ISO8601)"
}
```

#### 5. `support_chats` (Canlı Destek Sohbetleri)
```json
{
  "id": "String",
  "customerId": "String",
  "customerName": "String",
  "assignedAgentId": "String (Null/Value)",
  "assignedAgentName": "String",
  "status": "String (waiting | active | closed)",
  "createdAt": "String (ISO8601)",
  "updatedAt": "String (ISO8601)",
  "lastMessage": "String",
  "messages": [
    {
      "senderId": "String",
      "senderName": "String",
      "message": "String",
      "timestamp": "String (ISO8601)"
    }
  ],
  "orderId": "String",
  "rating": "Int"
}
```

---

## 🛠️ Kurulum ve Çalıştırma

Projenin yerel makinenizde çalıştırılması:

1. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
2. Uygulamayı başlatın:
   ```bash
   flutter run
   ```

BalSipariş ile lezzetli kodlamalar! 🚀🍔
