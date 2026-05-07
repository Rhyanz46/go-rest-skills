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
5. **Tim siapa yang harus ditanya** — kalau bisa diidentifikasi dari `git blame`, struktur folder, atau CODEOWNERS, sebut. Kalau tidak, bilang "perlu cari tahu owner-nya dulu."

Contoh output yang benar:

> **`app/use_case/billing.go:142`** — perhitungan diskon di-skip kalau `customer.Tier == "legacy"`, padahal field `tier` tidak pernah di-set ke string itu di kode yang aku baca.
>
> Bisa jadi ini sengaja: ada kemungkinan tier `"legacy"` di-inject lewat data migration manual atau dari service lain. Tapi dari kode saja tidak bisa dipastikan.
>
> **Tanya ke tim billing**: "Apakah `customer.Tier == 'legacy'` masih dipakai? Kalau iya, di-set di mana, dan apakah skip diskon di sini memang behaviour yang dimau?"

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
