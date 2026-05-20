---
name: code-review-business
description: Use when the user asks for a general code review (not a PR-specific review) and wants the reviewer mindset applied — flagging anything that looks wrong, but verifying with the relevant team whether unusual patterns are intentional from a business standpoint before declaring them bugs. Triggers on phrases like "review kodingan", "tolong review kode", "code review", "cek kodingan", "review umum", or when the user asks Claude to act as a reviewer outside the built-in `/review` PR flow.
---

# code-review-business

## Prinsip utama

> **Ingat!! kamu di sini reviewer kodingan. Kalau ada yang aneh dari kodingan, mohon make sure apakah memang seperti itu dari sisi bisnis — ke tim yang bersangkutan.**

Ini bukan slogan. Ini cara kerja review yang user inginkan: **jangan langsung memvonis "bug" / "salah" / "harus diubah"** untuk pola yang kelihatan janggal. Banyak hal yang terlihat aneh secara teknis sebenarnya sengaja begitu karena alasan bisnis, regulasi, kompromi historis, atau permintaan user yang tidak terdokumentasi di kode.

## Cara menerapkan

Saat melakukan review, untuk setiap temuan, klasifikasikan ke salah satu dari empat kategori:

| Kategori | Yakin salah secara teknis? | Punya konteks bisnis? | Tindakan |
|---|---|---|---|
| **Bug jelas** | Ya (mis. nil deref, race, SQL injection) | Tidak relevan | Laporkan langsung sebagai bug + saran fix. |
| **Code smell** | Tidak salah, tapi sub-optimal | Tidak butuh konteks bisnis | Saran perbaikan, tandai prioritas rendah. |
| **Aneh — perlu konfirmasi bisnis** | Tidak yakin: bisa salah, bisa sengaja | Butuh verifikasi | **Jangan langsung suruh ubah.** Tulis sebagai pertanyaan ke tim terkait. |
| **OK** | — | — | Tidak perlu disebut. |

Yang paling penting di skill ini adalah kategori ketiga.

## Format untuk temuan "perlu konfirmasi bisnis"

Untuk setiap item kategori ini, output harus mengandung:

1. **Lokasi**: `file_path:line_number`.
2. **Apa yang terlihat aneh** — deskripsikan secara netral, tanpa asumsi salah.
3. **Hipotesis kenapa bisa jadi sengaja** — minimal satu skenario bisnis yang masuk akal (regulasi? legacy? kompromi performa? permintaan user spesifik?).
4. **Pertanyaan konkret untuk tim terkait** — kalimat yang bisa langsung di-paste ke Slack / chat tim.
5. **Tim siapa yang harus ditanya** — lihat heuristik di bawah.

### Cara identifikasi tim yang tepat

Pakai langkah ini secara berurutan, berhenti di langkah pertama yang memberi jawaban jelas:

1. **`.github/CODEOWNERS` / `CODEOWNERS`** — kalau file path masuk ke pattern, owner di situ adalah jawaban authoritative.
2. **`git log --oneline -20 -- <file>`** — siapa yang paling sering nyentuh file ini dalam 6 bulan terakhir? Author email-nya biasanya bisa di-map ke tim (mis. `@billing.company.com`, atau commit message yang mention squad).
3. **Folder convention** — `app/use_case/billing/*.go` → tim billing. `internal/payments/*.go` → tim payments. Sebut tim sesuai naming directory paling spesifik.
4. **PR / issue di commit terakhir** — `git log -1 --format=%B <file>` sering reference PR number → buka PR-nya untuk lihat reviewer / labels → itu petunjuk tim.
5. **Fallback** — kalau tidak ada sinyal yang kuat, tulis eksplisit: *"Owner belum jelas. Saran: tanya di channel #engineering-general dengan permintaan dilempar ke owner yang tepat, atau cek dengan tech lead."* Jangan asumsi.

Jangan menebak tim hanya dari nama file (mis. `payment.go` belum tentu milik tim payments — bisa jadi tim checkout yang nge-touch flow pembayaran). Selalu cross-check minimal dua sinyal.

Contoh output yang benar:

> **`app/use_case/billing.go:142`** — perhitungan diskon di-skip kalau `customer.Tier == "legacy"`, padahal field `tier` tidak pernah di-set ke string itu di kode yang aku baca.
>
> Bisa jadi ini sengaja: ada kemungkinan tier `"legacy"` di-inject lewat data migration manual atau dari service lain. Tapi dari kode saja tidak bisa dipastikan.
>
> **Tanya ke tim billing**: "Apakah `customer.Tier == 'legacy'` masih dipakai? Kalau iya, di-set di mana, dan apakah skip diskon di sini memang behaviour yang dimau?"

## Contoh klasifikasi (penting — pelajari pola pikirnya, bukan kata kuncinya)

### Contoh A — Bug jelas

```go
func (r *UserRepo) FindByEmail(email string) *User {
    var u User
    r.db.Where("email = ?", email).First(&u)
    return &u
}
```

**Klasifikasi**: bug jelas. Error dari GORM `First()` diabaikan total — kalau email tidak ditemukan atau koneksi DB error, fungsi mengembalikan pointer ke zero-value `User` yang akan disalahartikan sebagai "user valid dengan ID 0" oleh caller. Tidak ada konteks bisnis yang membenarkan ini.

**Tindakan**: laporkan langsung sebagai bug, kasih saran fix (return `(*User, error)`, propagate `gorm.ErrRecordNotFound`).

---

### Contoh B — Code smell (BUKAN perlu konfirmasi bisnis)

```go
func ProcessOrder(o Order) {
    if o.Status == "pending" {
        // handle pending
    } else if o.Status == "paid" {
        // handle paid
    } else if o.Status == "shipped" {
        // handle shipped
    } else if o.Status == "delivered" {
        // handle delivered
    }
}
```

**Klasifikasi**: code smell. Chain `if-else` panjang untuk status enum — secara teknis tidak salah, hasil sama dengan `switch`. Tidak butuh konfirmasi tim bisnis karena ini soal style, bukan keputusan domain.

**Tindakan**: saran refactor jadi `switch` di kategori "code smell / prioritas rendah." Jangan promote jadi pertanyaan ke tim — itu buang waktu mereka.

---

### Contoh C — Perlu konfirmasi bisnis (yang terlihat seperti bug TAPI ternyata sengaja)

```go
func (s *PaymentService) Refund(orderID string) error {
    order, _ := s.repo.GetOrder(orderID)
    if order.CreatedAt.Before(time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)) {
        return s.legacyRefund(order)
    }
    return s.standardRefund(order)
}
```

**Klasifikasi**: perlu konfirmasi bisnis. Hard-coded tanggal `2024-01-01` sebagai cut-off — secara teknis ini "magic number" yang biasanya jelek. Tapi pola seperti ini sering muncul karena alasan riil:
- Migrasi sistem payment di tanggal itu (data lama format-nya beda).
- Compliance/audit requirement: order pre-2024 wajib pakai jalur lama.
- Refactor bertahap yang belum selesai backfill.

**Tindakan**: JANGAN langsung saran "extract ke konstanta" atau "buat configurable." Tulis:

> **`app/use_case/payment.go:14`** — refund di-branch berdasarkan tanggal hard-coded `2024-01-01`. Ini bisa jadi cutover dari migrasi sistem lama, atau requirement compliance.
>
> **Tanya ke tim payments**: "Tanggal `2024-01-01` di `Refund()` ini cutover apa? Apakah aman dijadikan konstanta bernama, atau memang akan ada cutover-cutover berikutnya yang perlu di-handle berbeda?"

---

### Contoh D — Perlu konfirmasi bisnis (logic yang terlihat salah)

```go
func CalculateShipping(order Order) float64 {
    if order.Customer.Country == "ID" && order.Total > 500000 {
        return 0
    }
    if order.Customer.Country == "ID" && order.Total > 200000 && order.Customer.Tier == "gold" {
        return order.BaseShipping * 0.5
    }
    return order.BaseShipping
}
```

**Klasifikasi**: perlu konfirmasi bisnis. Threshold `500000` dan `200000` plus tier `"gold"` adalah **kebijakan bisnis** — review tidak punya wewenang memvonis "salah" tanpa konfirmasi.

**Tindakan**:

> **`app/use_case/shipping.go:14-20`** — aturan free shipping (`>500k`) dan diskon 50% (`>200k` + tier gold) untuk customer Indonesia. Kelihatan seperti hardcoded rule yang seharusnya configurable, tapi mungkin memang policy yang fixed.
>
> **Tanya ke tim commercial/marketing**: "Aturan free shipping di atas 500k dan diskon 50% untuk gold tier di atas 200k itu policy permanen, atau periodically diubah? Kalau bisa berubah, layak dipindah ke config/feature flag. Kalau permanen, layak didokumentasikan di code comment dengan reference ke policy doc."

---

### Pattern recognition — kapan curiga "ada konteks bisnis"

Kalau temuan mengandung salah satu dari berikut, **default-nya masuk kategori "perlu konfirmasi bisnis"**, bukan langsung jadi saran perbaikan:

- **Magic numbers / dates / strings** yang terlihat sembarang (`tier == "legacy"`, `country == "ID"`, `before(2024-01-01)`)
- **Branching berdasarkan ID spesifik** (`if userID == 12345`, `if customer.ID == "VIP_..."`) — sering = customer requirement personal
- **Conditional yang skip validasi/feature** untuk subset tertentu — bisa jadi grandfathering
- **Comment "TODO: remove after X"** yang sudah lewat tanggalnya — mungkin lupa, mungkin sengaja dipertahankan
- **Field DB yang tidak pernah di-write di kode** — bisa jadi di-write oleh service lain / migration manual
- **Hardcoded URL/endpoint** ke service spesifik — mungkin kontrak partnership

Untuk hal-hal teknis murni (typo, error handling, race, leak, missing context propagation), tetap masuk kategori "bug jelas" — tidak perlu tanya tim.

## Apa yang TIDAK boleh dilakukan

- **Jangan menulis "ini bug, harus diubah jadi X"** untuk pola yang masuk kategori "perlu konfirmasi bisnis." Itu mendahului keputusan tim.
- **Jangan langsung edit kode** untuk temuan kategori ini, bahkan kalau user permission mode mengizinkan. Tulis pertanyaannya dulu, baru tunggu user atau tim memberi keputusan.
- **Jangan menyamaratakan semua temuan jadi "saran perbaikan"** — itu menghilangkan sinyal mana yang butuh diskusi vs. yang aman diubah.
- **Jangan asumsikan kode di branch lain / repo lain salah** hanya karena tidak sesuai pola yang kamu lihat di repo ini. Kontrak antar service kadang ada di tempat lain.

## Struktur laporan akhir

Saat selesai review, susun laporan dalam urutan ini:

1. **Bug jelas** (paling atas, paling actionable)
2. **Perlu konfirmasi bisnis** — daftar pertanyaan untuk tim, dengan format di atas
3. **Code smell / saran perbaikan** (prioritas rendah)
4. **Catatan positif** (opsional, kalau ada pola yang bagus dan layak dilanjutkan)

Bagian #2 sering kali yang paling berharga. Jangan dikecilkan.

## Kapan skill ini TIDAK dipakai

- User minta review PR spesifik dengan nomor → pakai built-in `/review` atau `/ultrareview`.
- User minta security review → pakai `/security-review`.
- User minta perbaikan langsung tanpa minta review (mis. "fix bug X") — bukan review session, kerjakan langsung.
