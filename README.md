# 🍔 BalSipariş - Premium Yemek Siparişi ve Yönetim Uygulaması

BalSipariş, modern yemek siparişi süreçlerini, gelişmiş restoran şube yönetimini, canlı destek personeli atama sistemini ve kupon yönetimini tek bir çatı altında toplayan; hem **Canlı Firebase (Firestore + Auth)** veritabanı altyapısıyla hem de tamamen **Çevrimdışı Mock (Demo) Modu** ile kesintisiz çalışabilen üst seviye bir Flutter uygulamasıdır.

---

## ✨ Uygulama Özellikleri

### 1. 📍 Gelişmiş Adres ve Konum Yönetimi
*   **Müşteri ve Restoran Adres Girişi**: Müşteriler ve restoranlar aynı gelişmiş konum girme arayüzünü kullanır. 
*   **Harita ve Konum Entegrasyonu**: Harita üzerinden pin kaydırarak veya arama barından adres aratarak anında konum tespiti yapılır.
*   **Adres Onaylama Akışı**: Adres girilip onaylandıktan sonra ekran yenilenmeden form bilgileri korunur, böylece kullanıcılar verilerini kaybetmeden adres kaydını tamamlar.

### 2. 🏪 Restoran Paneli ve Ciro Yönetimi
*   **Restoran Sahiplerine Özel Erişim**: Restoran sahipleri doğrudan yönetim paneline değil, kendilerine özel olarak tasarlanmış **Restoran Şube Paneline** yönlendirilir.
*   **%80 Ciro Hesaplaması**: Restoran sahiplerinin panelinde gösterilen toplam ciro, sipariş tutarlarının net **%80'i** olacak şekilde hesaplanır. Kalan %20 platform işletim bedeli olarak ayrılır.
*   **Logo Yükleme**: Restoran sahipleri galeriden veya kameradan restoran logolarını fotoğraf olarak yükleyebilirler.
*   **Maksimum Sipariş Uzaklığı**: Restoranlar, şubeleri için kilometre (km) bazında maksimum sipariş teslimat uzaklığı belirleyebilirler.

### 3. 👥 Şube Yetkilisi Davet Sistemi
*   **E-Posta ile Davet**: Restoran sahipleri, normal müşterileri restoranlarına "Şube Yetkilisi" (Ortak Yönetici) olarak atamak için sadece e-posta adreslerini girerek davet gönderebilir.
*   **Canlı Profil Bildirimleri**: Davet gönderilen müşterinin Profil sayfasına anında cam efektli (glassmorphic) şık bir davet bildirimi düşer.
*   **Onay ve Rol Güncellemesi**: Müşteri daveti kabul ettiğinde rolü anında `'restaurant_owner'` olarak güncellenir ve davet eden restoranın tüm şube yönetim verilerine ortak erişim kazanır.

### 4. 💬 Canlı Destek & Kullanıcı Arama Sistemi (Admin)
*   **Destek Personeli Atama**: Sistem yöneticileri (Admin), yönetim panelinden istedikleri kullanıcıları tek dokunuşla "Canlı Destek Personeli" olarak atayabilir veya görevden alabilir.
*   **Kullanıcı Arama Barı**: Admin panelinin üst kısmında yer alan akıllı arama barı ile kullanıcılar isme veya e-postaya göre anlık olarak filtrelenir.
*   **Gerçek Zamanlı Sohbet**: Müşteriler ve atanan canlı destek personelleri arasında siparişle ilişkili veya bağımsız anlık mesajlaşma odaları bulunur.

### 5. 🏷️ Akıllı Kupon & İndirim Yönetimi
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
  "role": "String (customer | restaurant_owner | support | admin)",
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
