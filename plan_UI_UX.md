# 🍌 Rotten Bananas (Rotten Bananas) — Agentic AI Master Specification (`PLAN.md`)

> **INSTRUKSI UNTUK AI AGENT:**
> Dokumen ini adalah *Single Source of Truth* (SSOT) untuk membangun aplikasi mobile Flutter katalog film dan pemutar trailer **Rotten Bananas (Rotten Bananas)**. Ikuti seluruh arsitektur, skema database, endpoint API, struktur state, dan spesifikasi UI/UX di bawah ini secara presisi tanpa melewati satu fitur pun.

---

## 1. System Constraints & Aturan Eksekusi Agentic AI

1. **Framework & Bahasa:** Flutter (versi terbaru stabil) & Dart (Null-Safety ketat).
2. **Mandiri Tanpa Backend Eksternal untuk Auth/Profil:** Sistem **Login, Register, Session, Update Profil Mandiri, dan Watchlist** wajib berjalan **100% secara lokal (mandiri)** menggunakan **SQLite (`sqflite`)** + **`shared_preferences`** (untuk menyimpan sesi `active_user_id` dan `is_logged_in`) + **`image_picker`** (untuk mengganti foto profil dari galeri/kamera lokal).
3. **Sumber Data Film & Trailer:** Seluruh katalog film, kategori/genre, rating, pencarian, filter, dan kunci video trailer diambil secara *real-time* dari **TMDb API v3**.
4. **Pemutaran Video Trailer:** Menggunakan `youtube_player_flutter` atau `youtube_player_iframe` dengan mengambil nilai `key` dari endpoint `/movie/{id}/videos` (filter `site == "YouTube"`).
5. **Zero Crash Policy:**
   * Setiap nilai gambar (`poster_path`, `backdrop_path`, `profile_path`) yang bernilai `null` dari API wajib memiliki *fallback UI* lokal.
   * Jika film tidak memiliki video trailer, tampilkan state *"Trailer Tidak Tersedia"* dan jangan merender *YouTube Player* dengan `key` kosong.
   * Wajib menerapkan *Debounce (500ms)* pada kolom *Search Bar*.

---

## 2. Tech Stack & Konfigurasi `pubspec.yaml`

AI Agent wajib menginstal dan mengonfigurasi paket-paket berikut:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # State Management & Dependency Injection
  flutter_riverpod: ^2.5.1
  # Networking & Environment
  dio: ^5.4.3+1
  flutter_dotenv: ^5.1.0
  # Local Database, Session & File System (Untuk Auth, Profil Mandiri & Watchlist)
  sqflite: ^2.3.3+1
  path: ^1.9.0
  path_provider: ^2.1.3
  shared_preferences: ^2.2.3
  crypto: ^3.0.3               # Untuk hashing password lokal (SHA-256)
  image_picker: ^1.1.2         # Untuk pilih foto profil dari Galeri/Kamera
  # Media, UI & Animasi
  youtube_player_flutter: ^9.0.1
  cached_network_image: ^3.3.1
  carousel_slider: ^5.0.0
  shimmer: ^3.0.0
  google_fonts: ^6.2.1
  intl: ^0.19.0
```

---

## 3. Sistem Desain (Design System & Theme)

### 3.1 Palet Warna (*Dark Cinema & Ripe Banana Theme*)
* `backgroundPrimary`: `#0D0E12` (Latar belakang utama seluruh layar)
* `surfaceCard`: `#181A20` (Kartu film, *bottom navigation*, *text field*, *modal bottom sheet*)
* `surfaceElevated`: `#242731` (Chip genre, border kartu, *skeleton loading*)
* `accentYellow`: `#FFD600` (Tombol utama, tab aktif, *highlight*, ikon pisang segar)
* `accentAmber`: `#FFAB00` (Gradasi tombol, *badge* rating menengah)
* `statusFresh`: `#00E676` (Skor >= 75% — *Golden Ripe*)
* `statusBruised`: `#FFAB00` (Skor 55% – 74% — *Slightly Bruised*)
* `statusRotten`: `#FF5252` (Skor < 55% — *Rotten Bananas / Rotten* & pesan *error*)
* `textPrimary`: `#FFFFFF`
* `textSecondary`: `#9E9E9E`

### 3.2 Konversi Skor Rating ("Banana Meter Helper")
Nilai `vote_average` (0.0 – 10.0) dari TMDb dikonversi menjadi persentase `(vote_average * 10).round()`:
* **>= 75%:** Label `"Golden Ripe"`, Ikon `🍌`, Warna `#00E676` / `#FFD600`.
* **55% – 74%:** Label `"Bruised"`, Ikon `🍌`, Warna `#FFAB00`.
* **< 55%:** Label `"Rotten Bananas"`, Ikon `🤢`, Warna `#FF5252`.

---

## 4. Arsitektur Database Lokal (`sqflite`) & Session

Buat kelas `DatabaseHelper` (Singleton) di `lib/data/local/database_helper.dart` dengan file database bernama `Rotten Bananas_app.db` (versi 1) yang memiliki **2 Tabel Utama**:

### 4.1 Tabel 1: `users` (Untuk Login, Register & Update Profil Mandiri)
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  bio TEXT DEFAULT 'Pecinta film & pemburu trailer.',
  avatar_path TEXT,              -- Path file lokal hasil ImagePicker atau kode preset avatar
  favorite_genres TEXT,          -- String dipisah koma, misal: "28,12,878"
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```
> **Seed Account Default:** Saat database pertama kali dibuat (`onCreate`), otomatis *insert* 1 akun demo agar penguji bisa langsung login:
> * **Email:** `demo@Rotten Bananas.app` | **Username:** `bima_cinema` | **Password:** `password123` (disimpan dalam bentuk SHA-256 hash).

### 4.2 Tabel 2: `watchlist` (Relasi ke `user_id`)
```sql
CREATE TABLE watchlist (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,      -- Foreign Key ke users.id (Setiap user punya watchlist sendiri)
  movie_id INTEGER NOT NULL,     -- ID film dari TMDb
  title TEXT NOT NULL,
  poster_path TEXT,
  backdrop_path TEXT,
  vote_average REAL NOT NULL,
  release_date TEXT,
  genre_ids TEXT,                -- Disimpan sebagai JSON string / comma-separated
  added_at TEXT NOT NULL,
  UNIQUE(user_id, movie_id) ON CONFLICT REPLACE
);
```

### 4.3 Manajemen Session (`SharedPreferences`)
* `is_logged_in` (`bool`): Menentukan apakah pengguna diarahkan ke `LoginScreen` atau `MainNavigationScreen` saat aplikasi dibuka.
* `active_user_id` (`int`): Menyimpan `id` pengguna yang sedang login untuk mengambil profil dan *watchlist* miliknya.

---

## 5. Spesifikasi Pemetaan API TMDb (`TmdbApiService`)

* **Base URL:** `https://api.themoviedb.org/3`
* **Image Base URL:** `https://image.tmdb.org/t/p/` (`w500` untuk poster, `w780` untuk backdrop, `w185` untuk profil aktor).
* **Auth Header / Query Param:** Gunakan `api_key` dari `.env` (`TMDB_API_KEY`).

| Kebutuhan Fitur | Endpoint TMDb | Parameter Query Wajib |
| :--- | :--- | :--- |
| **Banner Trending (Beranda)** | `GET /trending/movie/week` | `language=id-ID` |
| **Sedang Tayang (Beranda)** | `GET /movie/now_playing` | `page={page}&region=ID` |
| **Populer (Beranda)** | `GET /movie/popular` | `page={page}` |
| **Rating Tertinggi (Beranda)**| `GET /movie/top_rated` | `page={page}` |
| **Segera Tayang (Beranda)** | `GET /movie/upcoming` | `page={page}&region=ID` |
| **Daftar Master Kategori/Genre**| `GET /genre/movie/list` | `language=id-ID` (Fallback `en-US`) |
| **Search Bar (Cari Judul)** | `GET /search/movie` | `query={keyword}&page={page}&include_adult=false` |
| **Filter List Film & Kategori**| `GET /discover/movie` | `with_genres={genreIds}&sort_by={sortBy}&primary_release_year={year}&vote_average.gte={minRating}&page={page}` |
| **Detail Film + Trailer + Cast**| `GET /movie/{movie_id}` | `append_to_response=videos,credits,recommendations,reviews` |

---

## 6. Spesifikasi Detail Layar & Fitur (UI/UX Wireframes & Logic)

### 6.1 Layar Autentikasi: Login & Register Screen
* **Alur:** Jika `is_logged_in == false`, pengguna masuk ke `LoginScreen`.
* **Komponen `LoginScreen`:**
  * Logo **Rotten Bananas 🍌** dan subjudul *"Watch Trailers. Judge the Ripeness."*
  * Input `Email / Username` (dengan validasi tidak boleh kosong).
  * Input `Password` (dengan tombol *toggle show/hide password*).
  * Tombol Utama **"Masuk (Sign In)"** berwarna `#FFD600` (teks hitam tebal).
  * Tombol Sekunder **"Isi Akun Demo Cepat"** (otomatis mengisi `demo@Rotten Bananas.app` & `password123` untuk kemudahan pengujian).
  * Tautan ke `RegisterScreen`: *"Belum punya akun? Daftar Sekarang"*.
* **Komponen `RegisterScreen`:**
  * Form pendaftaran: `Nama Lengkap`, `Username`, `Email`, `Password`, dan `Konfirmasi Password`.
  * Pilihan **Genre Favorit Awal** (minimal pilih 2 chip genre) sebelum klik **"Buat Akun"**.
  * Saat berhasil daftar, simpan ke tabel `users`, aktifkan session, dan arahkan langsung ke `MainNavigationScreen`.

---

### 6.2 Navigasi Utama (`MainNavigationScreen`)
Menggunakan `BottomNavigationBar` dengan 4 Tab Utama:
1. **🏠 Beranda (`HomeScreen`)**
2. **🧭 Eksplor & Filter (`ExploreFilterScreen`)** — Memuat Search Bar, Kategori Film, dan Filter List Film.
3. **🔖 Watchlist (`WatchlistScreen`)** — Daftar film tersimpan milik user yang sedang login.
4. **👤 Profil (`ProfileScreen`)** — Halaman Profil Mandiri & Update Data User.

---

### 6.3 Tab 1: Beranda (`HomeScreen`)
```text
+-------------------------------------------------------------------+
| 🍌 Rotten Bananas                        Halo, Bima! [Avatar] [🔍 Cari] | <- AppBar
+-------------------------------------------------------------------+
| [ 🔍 Cari film, trailer, atau genre... (Tap -> Buka Tab Eksplor)] | <- Quick Search Bar Trigger
|                                                                   |
| +---------------------------------------------------------------+ |
| |                 [ HERO CAROUSEL BANNER 16:9 ]                 | | <- 5 Film Trending Minggu Ini
| |  🍌 91% Golden Ripe  •  Sci-Fi, Action                        | |
| |  DUNE: MESSIAH (2026)                                         | |
| |  [ ▶ Tonton Trailer ]                     [ + Simpan ]        | |
| +---------------------------------------------------------------+ |
|                                                                   |
| 🗂️ Kategori / Genre Cepat                                         |
| [ Semua ] [ 🔥 Action ] [ 👻 Horror ] [ 😂 Comedy ] [ 🚀 Sci-Fi ] | <- Ketuk chip untuk memfilter
|                                                                   |
| 🎬 Sedang Tayang di Bioskop                        Lihat Semua >  |
| +------------+  +------------+  +------------+                    |
| | Poster 2:3 |  | Poster 2:3 |  | Poster 2:3 |                    | <- Kartu menampilkan Poster,
| | [🍌 84%]   |  | [🍌 68%]   |  | [🤢 42%]   |                       Skor Pisang, Judul & Tahun
| +------------+  +------------+  +------------+                    |
|                                                                   |
| 🍿 Paling Populer                                  Lihat Semua >  |
| +------------+  +------------+  +------------+                    |
|                                                                   |
| ⭐ Rating Tertinggi Sepanjang Masa                 Lihat Semua >  |
| +------------+  +------------+  +------------+                    |
|                                                                   |
| 📅 Segera Tayang (Upcoming)                        Lihat Semua >  |
| +-----------------------+  +-----------------------+              |
| | Kartu Lanskap 16:9    |  | Kartu Lanskap 16:9    |              |
+-------------------------------------------------------------------+
```
* **Interaksi Kategori Cepat di Beranda:** Mengetuk salah satu chip kategori di Beranda dapat memperbarui daftar film di bawahnya secara dinamis atau mengarahkan ke halaman Kategori dengan filter genre tersebut aktif.
* **Interaksi "Lihat Semua >":** Membuka halaman daftar penuh (`MovieListPaginationScreen`) dengan fitur *Infinite Scroll*.

---

### 6.4 Tab 2: Search Bar, Kategori Film & Filter List Film (`ExploreFilterScreen`)
Layar ini menggabungkan pencarian teks bebas, penjelajahan kategori/genre, dan penyaringan multi-parameter (*Advanced Filter*).

```text
+-------------------------------------------------------------------+
| [ 🔍 Ketik judul film...                               [X] ] [⚙️] | <- Search Bar (Debounce 500ms)
|                                                                │  |    + Tombol Buka Modal Filter
+----------------------------------------------------------------|--+
| Kategori Genre (Bisa pilih lebih dari satu / Multi-select):    │  |
| [✓ Action] [ Adventure ] [✓ Sci-Fi] [ Horror ] [ Animation ]   │  | <- Horizontal Scrollable Chips
|                                                                │  |
| Filter Aktif: [Urut: Populer ▼] [Tahun: 2026 ✕] [Skor >= 70% ✕]│  | <- Indikator Filter Aktif + Reset
+----------------------------------------------------------------|--+
| Menampilkan 142 Film                           [Grid ⊞ / List ☰] | <- Toggle Tampilan Grid / List
|                                                                   |
| +-------------------+   +-------------------+                     |
| |    Poster Film    |   |    Poster Film    |                     |
| |   [🍌 88% Ripe]   |   |  [🍌 62% Bruised] |                     |
| |        [▶]        |   |        [▶]        |                     |
| +-------------------+   +-------------------+                     |
| Judul Film A (2026)     Judul Film B (2026)                       |
| Action, Sci-Fi          Action, Drama                             |
+-------------------------------------------------------------------+
```

#### Logika Dual-Mode pada Layar Eksplor & Filter:
1. **Mode Pencarian Kata Kunci (`query` tidak kosong):**
   * Memanggil `GET /search/movie?query={keyword}`.
   * Hasil pencarian tetap dapat difilter di sisi klien (*client-side filtering*) berdasarkan chip **Genre**, **Tahun Rilis**, dan **Minimal Skor Rating** yang dipilih pengguna.
2. **Mode Penjelajahan & Filter (`query` kosong):**
   * Memanggil `GET /discover/movie` dengan parameter lengkap dari state filter.
3. **Spesifikasi Modal Bottom Sheet Filter (`FilterBottomSheet`):**
   Saat pengguna mengetuk ikon Filter `[⚙️]`, tampilkan *Bottom Sheet* berisi:
   * **Urutkan Berdasarkan (`sort_by`):**
     * Paling Populer (`popularity.desc`)
     * Rating Tertinggi (`vote_average.desc` dengan syarat `vote_count.gte=100` agar film tidak jelas dengan 1 suara tidak muncul di atas)
     * Terbaru Dirilis (`primary_release_date.desc`)
     * Pendapatan Tertinggi (`revenue.desc`)
   * **Kategori / Genre (`with_genres`):** Grid berisi seluruh genre resmi TMDb (Action, Adventure, Animation, Comedy, Crime, Documentary, Drama, Family, Fantasy, History, Horror, Music, Mystery, Romance, Sci-Fi, Thriller, War, Western).
   * **Rentang Skor Pisang (`vote_average.gte`):** Slider dari `0%` sampai `90%` (atau pilihan cepat: *Semua*, *Minimal Bruised >= 55%*, *Hanya Golden Ripe >= 75%*).
   * **Tahun Rilis (`primary_release_year`):** Dropdown atau chip tahun (`Semua`, `2026`, `2025`, `2024`, `2023`, `2020-an`, `Era Klasik`).
   * **Tombol Aksi:** Tombol **"Reset Filter"** dan **"Terapkan Filter"**.

---

### 6.5 Layar Detail Film & Pemutar Trailer (`MovieDetailScreen`)
* **Header Player Interaktif:**
  * Menampilkan gambar *Backdrop* resolusi tinggi dengan tombol **▶ Putar Trailer Resmi** di tengah.
  * Saat tombol diketuk (atau otomatis jika diaktifkan), area header berubah menjadi `YoutubePlayer` yang memutar trailer utama (`type == "Trailer"` & `site == "YouTube"`).
* **Daftar Video & Klip Tambahan:**
  * Jika sebuah film memiliki lebih dari 1 video (misal: *Official Trailer 1*, *Final Trailer*, *Teaser*, *Behind the Scenes*), tampilkan deretan kartu horizontal di bawah sinopsis. Mengetuk klip lain akan langsung mengganti video yang sedang diputar di `YoutubePlayer` atas (`controller.load(newVideoKey)`).
* **Informasi Lengkap:**
  * Judul, Tahun Rilis, Durasi (dikonversi ke format `2j 15m`), Status Rilis, dan deretan **Chip Kategori/Genre** (jika chip genre diketuk, arahkan ke halaman Filter dengan genre tersebut).
  * Kotak **Banana Meter** (Persentase kesegaran + jumlah pemilih `vote_count`).
  * Sinopsis lengkap (*expandable*), daftar **Pemeran Utama (Cast)** beserta foto, **Ulasan Pengguna**, dan **Rekomendasi Film Serupa**.
  * *Floating Action Button* atau tombol di AppBar untuk **Simpan / Hapus dari Watchlist** (tersimpan ke tabel `watchlist` sesuai `active_user_id`).

---

### 6.6 Tab 4: Halaman Profil Mandiri & Update Profil (`ProfileScreen` & `EditProfileScreen`)
Halaman ini sepenuhnya dikelola secara mandiri oleh pengguna tanpa bergantung pada server luar.

```text
+-------------------------------------------------------------------+
| 👤 Profil Saya                                     [✏️ Edit Profil]|
+-------------------------------------------------------------------+
|                        +-----------------+                        |
|                        |  [ Foto/Avatar ]|                        |
|                        |     [ 📷 ]      |                        |
|                        +-----------------+                        |
|                        Bima Prawira Dharma                        |
|                           @bima_cinema                            |
|                  "Pecinta film & pemburu trailer."                |
|                                                                   |
|  +-----------------------------+  +-----------------------------+ |
|  |       🔖 18 Film            |  |      🍌 Action, Sci-Fi      | |
|  |     Di Watchlist Saya       |  |       Genre Favorit         | |
|  +-----------------------------+  +-----------------------------+ |
|                                                                   |
|  Pengaturan Akun Mandiri                                          |
|  +-------------------------------------------------------------+  |
|  | 📝 Ubah Data Profil (Nama, Username, Bio, Genre Favorit)  > |  |
|  | 🔒 Ubah Password Akun                                     > |  |
|  | 🗑️ Bersihkan Seluruh Watchlist                            > |  |
|  +-------------------------------------------------------------+  |
|                                                                   |
|  Tentang & Lisensi Data                                           |
|  +-------------------------------------------------------------+  |
|  | [LOGO TMDB]                                                 |  |
|  | "This product uses the TMDB API but is not endorsed or      |  |
|  |  certified by TMDB."                                        |  |
|  +-------------------------------------------------------------+  |
|                                                                   |
|  [ 🚪 Keluar Akun (Logout) ]                                      |
+-------------------------------------------------------------------+
```

#### Fitur Wajib di Halaman Update Profil Mandiri (`EditProfileScreen`):
1. **Ganti Foto Profil Mandiri:**
   * Pengguna dapat memilih foto dari **Galeri HP** (`ImageSource.gallery`), **Kamera** (`ImageSource.camera`), atau memilih dari **6 Avatar Ikon Preset Sinema/Pisang** bawaan aplikasi.
   * File gambar yang dipilih disalin ke direktori dokumen aplikasi lokal (`getApplicationDocumentsDirectory()`) dan path-nya disimpan ke kolom `avatar_path` di tabel `users` SQLite agar tidak hilang saat aplikasi ditutup.
2. **Update Informasi Pribadi:**
   * Form edit `Nama Lengkap`, `Username` (cek keunikan di SQLite), `Email`, dan `Bio Singkat`.
   * Pemilih ulang **Chip Genre Favorit**.
3. **Update Password Mandiri (`ChangePasswordBottomSheet`):**
   * Memverifikasi `Password Lama` (dicocokkan dengan `password_hash` di SQLite), lalu menyimpan `Password Baru` yang sudah di-hash.
4. **Fungsi Logout:**
   * Menghapus status `is_logged_in` dan `active_user_id` di `SharedPreferences`, lalu mengarahkan pengguna kembali ke `LoginScreen` dengan menghapus riwayat navigasi (`pushAndRemoveUntil`).

---

## 7. Struktur Direktori Proyek Flutter (Clean Modular Architecture)

AI Agent wajib membuat struktur direktori dan file persis seperti di bawah ini:

```text
lib/
├── core/
│   ├── constants/
│   │   ├── api_constants.dart          # Base URL TMDb, endpoint paths, image URL builder
│   │   └── app_colors.dart             # Definisi palet warna Dark Cinema & Banana
│   ├── theme/
│   │   └── app_theme.dart              # ThemeData Dark Mode & konfigurasi Google Fonts
│   └── utils/
│       ├── banana_score_helper.dart    # Konversi vote_average ke persentase & status pisang
│       ├── debouncer.dart              # Helper debounce 500ms untuk Search Bar
│       └── password_hasher.dart        # Helper SHA-256 untuk hash password lokal
├── data/
│   ├── local/
│   │   ├── database_helper.dart        # Inisialisasi SQLite, tabel users & watchlist
│   │   └── session_manager.dart        # SharedPreferences helper untuk sesi login
│   ├── models/
│   │   ├── user_model.dart             # Model untuk tabel users (Profil Mandiri)
│   │   ├── movie_model.dart            # Model film (list & detail)
│   │   ├── genre_model.dart            # Model kategori/genre film
│   │   ├── video_model.dart            # Model trailer YouTube
│   │   ├── cast_model.dart             # Model pemeran film
│   │   └── movie_filter_state.dart     # Model state filter (genreIds, sortBy, year, minScore, query)
│   └── services/
│       ├── auth_profile_service.dart   # Operasi CRUD SQLite untuk Login, Register, Update Profil
│       ├── watchlist_service.dart      # Operasi CRUD SQLite untuk Watchlist per user_id
│       └── tmdb_api_service.dart       # Seluruh request HTTP Dio ke TMDb API
├── providers/
│   ├── auth_provider.dart              # State user aktif, fungsi login, register, update profil, logout
│   ├── home_movies_provider.dart       # State untuk Beranda (Trending, Now Playing, Popular, Top Rated, Upcoming)
│   ├── explore_filter_provider.dart    # State untuk Search Bar, Kategori, Filter Multi-Parameter & Pagination
│   ├── movie_detail_provider.dart      # State detail film, trailer aktif, cast & rekomendasi
│   └── watchlist_provider.dart         # State daftar watchlist milik user aktif
├── ui/
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── main_navigation_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── category_movies_screen.dart
│   │   ├── explore/
│   │   │   ├── explore_filter_screen.dart
│   │   │   └── widgets/
│   │   │       └── filter_bottom_sheet.dart
│   │   ├── detail/
│   │   │   └── movie_detail_screen.dart
│   │   ├── watchlist/
│   │   │   └── watchlist_screen.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       ├── edit_profile_screen.dart
│   │       └── change_password_sheet.dart
│   └── widgets/
│       ├── hero_banner_carousel.dart
│       ├── movie_poster_card.dart
│       ├── movie_list_tile_card.dart   # Tampilan mode list pada halaman Filter
│       ├── banana_rating_badge.dart
│       ├── youtube_trailer_section.dart
│       └── shimmer_loading_widgets.dart
└── main.dart
```

---

## 8. Urutan Eksekusi Pembangunan untuk Agentic AI (Step-by-Step)

AI Agent harus mengerjakan proyek ini secara berurutan (jangan melompat ke UI sebelum lapisan data selesai):

### Step 1: Environment & Core Setup
1. Perbarui `pubspec.yaml` dengan seluruh paket di Bagian 2 dan jalankan `flutter pub get`.
2. Buat file `.env` di root proyek dengan isi `TMDB_API_KEY=MASUKKAN_API_KEY_DISINI` dan daftarkan `.env` ke dalam `pubspec.yaml` (`assets: - .env`).
3. Buat seluruh file di dalam `lib/core/` (`api_constants.dart`, `app_colors.dart`, `app_theme.dart`, `banana_score_helper.dart`, `debouncer.dart`, `password_hasher.dart`).

### Step 2: Database Lokal, Autentikasi & Layanan API
1. Buat semua model data di `lib/data/models/`.
2. Bangun `database_helper.dart` (lengkap dengan pembuatan tabel `users`, `watchlist`, dan *seed* akun demo) serta `session_manager.dart`.
3. Bangun `auth_profile_service.dart` (fungsi `login`, `register`, `getCurrentUser`, `updateProfile`, `updatePassword`, `updateAvatar`) dan `watchlist_service.dart`.
4. Bangun `tmdb_api_service.dart` menggunakan `Dio` dengan penanganan error yang rapi.

### Step 3: State Management (Riverpod Providers)
1. Buat `auth_provider.dart` yang memantau status sesi pengguna saat aplikasi dijalankan.
2. Buat `home_movies_provider.dart`, `explore_filter_provider.dart` (mendukung penggabungan Search Bar + Filter Genre + Sort + Tahun + Skor), `movie_detail_provider.dart`, dan `watchlist_provider.dart`.

### Step 4: Komponen Reusable & Layar Autentikasi
1. Bangun widget di `lib/ui/widgets/` (`movie_poster_card.dart`, `banana_rating_badge.dart`, `shimmer_loading_widgets.dart`).
2. Bangun `login_screen.dart` (lengkap dengan tombol *Quick Demo Login*) dan `register_screen.dart`.

### Step 5: Beranda, Search Bar, Kategori & Filter List Film
1. Bangun `main_navigation_screen.dart`.
2. Bangun `home_screen.dart` dengan *Hero Banner Carousel*, deretan chip **Kategori Film**, dan seksi katalog film horizontal.
3. Bangun `explore_filter_screen.dart` beserta `filter_bottom_sheet.dart` untuk menangani **Search Bar**, pemilihan **Kategori/Genre**, pengurutan, filter tahun/skor, serta *toggle* tampilan Grid/List.

### Step 6: Pemutar Trailer & Halaman Profil Mandiri
1. Bangun `movie_detail_screen.dart` dengan integrasi `youtube_player_flutter` yang otomatis memutar `key` trailer dari TMDb dan mendukung pergantian klip video.
2. Bangun `watchlist_screen.dart` dan `profile_screen.dart` beserta `edit_profile_screen.dart` (fitur ganti foto profil via `image_picker`, ubah nama/username/bio/genre favorit, ubah password, atribusi TMDb, dan logout).
3. Hubungkan semuanya di `lib/main.dart` dan jalankan `flutter analyze` untuk memastikan 0 *error* dan 0 *warning*.

---

## 9. Definition of Done (Checklist Verifikasi AI Agent)
Sebelum menyatakan tugas selesai, AI Agent wajib memastikan:
- [x] Pengguna bisa **Register** akun baru dan **Login** (serta tersedia tombol 1-klik akun demo).
- [x] Pengguna bisa membuka **Halaman Profil Mandiri** dan melakukan **Update Profil** (mengganti foto profil/avatar, nama, username, bio, genre favorit, dan password) yang tersimpan permanen di SQLite.
- [x] **Beranda** menampilkan *Hero Carousel*, chip **Kategori Film**, dan daftar film (*Now Playing*, *Popular*, *Top Rated*, *Upcoming*).
- [x] Halaman Eksplor memiliki **Search Bar** (*debounced*) dan **Filter List Film** lengkap (berdasarkan Kategori/Genre, Urutan Popularitas/Rating/Terbaru, Tahun Rilis, dan Skor Rating) dengan tampilan Grid maupun List.
- [x] Halaman Detail Film berhasil memutar **Video Trailer YouTube** secara langsung di dalam aplikasi dan bisa menyimpan film ke **Watchlist** spesifik milik akun yang sedang login.