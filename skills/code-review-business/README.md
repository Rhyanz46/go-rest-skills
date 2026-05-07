# code-review-business

Skill untuk Claude Code CLI yang membuat Claude bertindak sebagai **reviewer kodingan** dengan satu prinsip kunci:

> Kalau ada yang aneh dari kodingan, **make sure dulu ke tim yang bersangkutan** apakah memang seperti itu dari sisi bisnis — jangan langsung memvonis "bug".

Skill ini cocok untuk review umum di project sehari-hari, bukan untuk review PR formal (untuk itu pakai `/review` atau `/ultrareview` bawaan).

---

## Instalasi

Skill ini didistribusikan sebagai bagian dari **plugin marketplace `go-rest-skills`** (plugin name: `rhyanz46`). Sekali plugin di-install, semua skill di dalamnya — termasuk `code-review-business` — otomatis tersedia.

### Cara install via Claude Code CLI

```text
/plugin marketplace add Rhyanz46/go-rest-skills
/plugin install rhyanz46@go-rest-skills
```

Setelah terpasang, mulai sesi baru. Skill akan muncul sebagai `rhyanz46:code-review-business` di daftar skill.

### Cara install manual (user-level, tanpa plugin)

Kalau kamu tidak mau pakai mekanisme plugin, copy manual:

```bash
mkdir -p ~/.claude/skills/code-review-business
cp SKILL.md README.md ~/.claude/skills/code-review-business/
```

Mode manual akan terdaftar tanpa namespace (`code-review-business`, bukan `rhyanz46:code-review-business`). Pilih salah satu — jangan dua-duanya, biar tidak bingung membedakan versi.

---

## Cara memicu skill

Skill akan terpicu otomatis saat kamu memakai frasa-frasa berikut (atau yang serupa):

- "tolong review kodingan"
- "review kode di file X"
- "cek kodingan ini"
- "code review"
- "review umum"
- atau eksplisit: `/code-review-business`

Contoh prompt yang efektif:

```
Tolong review kodingan di app/use_case/billing.go,
apa ada yang aneh atau perlu didiskusikan ke tim?
```

```
Cek kodingan di branch ini, fokus ke file yang berubah saja.
```

```
Review repo ini secara umum, kasih tahu mana yang perlu konfirmasi
ke tim sebelum diubah.
```

---

## Apa yang akan kamu dapat

Output review akan dikelompokkan dalam **4 kategori**, dengan urutan:

### 1. Bug jelas
Hal-hal yang pasti salah secara teknis (nil deref, race, SQL injection, dll). Disebut paling atas, lengkap dengan saran fix.

### 2. Perlu konfirmasi bisnis ⭐ (bagian paling penting)
Pola yang terlihat janggal **tapi belum tentu salah** — bisa jadi sengaja karena alasan bisnis, regulasi, legacy, atau permintaan user yang tidak terdokumentasi.

Untuk setiap item, Claude akan menulis:

- **Lokasi**: `file_path:line_number`
- **Apa yang terlihat aneh** (deskripsi netral, tanpa asumsi salah)
- **Hipotesis kenapa bisa jadi sengaja**
- **Pertanyaan siap-paste** untuk dikirim ke tim
- **Tim siapa yang harus ditanya** (kalau bisa diidentifikasi dari `git blame` / CODEOWNERS)

Contoh output:

> **`app/use_case/billing.go:142`** — perhitungan diskon di-skip kalau `customer.Tier == "legacy"`, padahal field `tier` tidak pernah di-set ke string itu di kode yang aku baca.
>
> Bisa jadi ini sengaja: ada kemungkinan tier `"legacy"` di-inject lewat data migration manual atau dari service lain.
>
> **Tanya ke tim billing**: "Apakah `customer.Tier == 'legacy'` masih dipakai? Di-set di mana, dan apakah skip diskon di sini memang behaviour yang dimau?"

### 3. Code smell / saran perbaikan
Tidak salah, tapi sub-optimal. Prioritas rendah.

### 4. Catatan positif (opsional)
Pola yang bagus dan layak dilanjutkan.

---

## Yang TIDAK akan dilakukan skill ini

- ❌ Tidak akan langsung menulis "ini bug, harus diubah jadi X" untuk pola yang masuk kategori "perlu konfirmasi bisnis"
- ❌ Tidak akan langsung edit kode untuk kategori #2, walaupun permission mode mengizinkan
- ❌ Tidak akan menyamaratakan semua temuan jadi "saran perbaikan"
- ❌ Tidak akan memvonis kode di branch lain / repo lain salah hanya karena tidak sesuai pola di repo aktif

Filosofinya: **keputusan tetap di tim/user**, skill ini hanya menyiapkan pertanyaan dan konteks.

---

## Kapan TIDAK pakai skill ini

| Mau lakukan | Pakai |
|---|---|
| Review PR spesifik (dengan nomor) | `/review` atau `/ultrareview <PR#>` |
| Security review pending changes | `/security-review` |
| Fix bug langsung tanpa diskusi | Prompt biasa, tanpa keyword review |
| Cari skill lain | `/find-skills` |

---

## Mengubah / mengembangkan skill

Edit `~/.claude/skills/code-review-business/SKILL.md` langsung. Setelah perubahan:

1. Restart sesi Claude Code (skill di-cache per session).
2. Coba trigger ulang dengan prompt review.

Bagian yang paling sering perlu di-tweak:
- **Frontmatter `description`** → menentukan kapan skill auto-trigger. Tambahkan keyword baru kalau ada frasa yang kamu sering pakai tapi belum kena.
- **Format pertanyaan untuk tim** → sesuaikan dengan gaya komunikasi tim kamu (Slack vs. email vs. ticket).
- **Daftar kategori** → kalau mau menambahkan kategori baru (mis. "performa") boleh, tapi jaga agar kategori "perlu konfirmasi bisnis" tetap menonjol.

---

## Lisensi & atribusi

Personal skill, bebas dipakai dan dimodifikasi.
