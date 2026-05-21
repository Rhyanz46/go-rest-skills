# Changelog

Semua perubahan signifikan untuk plugin ini dicatat di sini. Versi mengikuti format `MAJOR.MINOR.PATCH`.

## v0.10.7

- **Fix**: tambah block `metadata` (description + version) di marketplace-level dan `owner.email`. Diff terakhir vs Anthropic reference plugin yang berfungsi — mereka punya keduanya, kita tidak.

## v0.10.6

- **Fix**: kembalikan `"strict": false` di `marketplace.json`. Setelah plugin.json dihapus di v0.10.5, default `strict: true` ternyata mengabaikan `skills` array di marketplace karena tidak ada plugin.json sebagai "authority". Anthropic reference plugin selalu pakai `strict: false` + `skills` array tanpa plugin.json — sekarang kita mirror persis.

## v0.10.5

- **Fix**: hapus `.claude-plugin/plugin.json`. Setelah `strict: false` dihapus di v0.10.4, plugin.json menjadi "authority" yang tidak mendeklarasikan skill apapun, sehingga `marketplace.json`'s `skills` array di-treat sebagai supplement dan tidak benar-benar di-load. Mirror layout Anthropic reference (`anthropic-agent-skills`) yang berfungsi: hanya `marketplace.json` dengan `skills` array. Versi sekarang otomatis di-track dari commit SHA.

## v0.10.4

- **Fix**: hapus `"strict": false` di `marketplace.json` — itu yang menyebabkan error `conflicting manifests: both plugin.json and marketplace entry specify components` di `/doctor`. Default `strict: true` mengizinkan plugin.json (authority) + marketplace entry (supplements) coexist.

## v0.10.3

- **Fix**: skill discovery — tambah `skills` array eksplisit di `marketplace.json` mengikuti format Anthropic reference. Tanpa ini, fresh install hasilnya `0 skills` di `/reload-plugins`. Reinstall plugin di mesin yang sudah pernah install untuk apply fix ini.

## v0.10.2

- **`code-review-business`**: tambah 4 contoh konkret (bug jelas, code smell, perlu konfirmasi bisnis × 2) + pattern-recognition guide untuk membedakan kategori.
- **`code-review-business`**: tambah heuristik 5-langkah untuk identifikasi tim yang tepat (CODEOWNERS → git log → folder convention → PR/issue → fallback).
- **`go-rest-clean-arch`**: tambah catatan verifikasi modul path via pkg.go.dev di `bootstrap-new-project.md` sebelum `go get`.
- **Top-level README**: tambah contoh transcript output `code-review-business` supaya pengunjung GitHub langsung paham bentuk output-nya.
- **`plugin.json` & `marketplace.json`**: broaden description supaya tidak terkesan plugin Go-only — sekarang mention kedua skill.
- **Scrub branding**: ganti referensi `github.com/Lintasarta/ai-cdn-services`, `lintasarta.com/*`, dan judul "AI CDN Services" jadi placeholder netral (`your-org/your-service`, `example.com`).
- **Bump version manifest**: `plugin.json` dari `0.1.0` (yang sudah drift jauh) ke `0.10.2` supaya match dengan tag commit terbaru.

## v0.10.1

- Tambah top-level `README.md`: install steps + index skill untuk pengunjung marketplace di GitHub.

## v0.10.0

- **New skill: `code-review-business`** — reviewer mode dengan prinsip "kalau ada yang aneh, verifikasi ke tim yang bersangkutan dulu, jangan langsung memvonis bug." Output dikelompokkan ke 4 kategori; yang paling penting adalah "perlu konfirmasi bisnis" yang menyiapkan pertanyaan siap-paste untuk tim terkait.

## v0.9.0

- Hard rule #24: ban silent numeric narrowing/sign conversion di Go REST playbook.

## v0.8.0

- Hard rule #23: review untuk orphaned data — discipline cascade + reconciliation.

## v0.7.0

- Hard rule #22: Swagger UI gated by BasicAuth, auto-disable ketika env credential unset.

## v0.6.0

- Hard rule #21: bounded fan-out (errgroup + channels) untuk list-time third-party calls.

## v0.5.0

- Hard rule #19: never ignore error.
- Hard rule #20: resource cleanup, no leaks.

## v0.4.0

- Hard rule #18: request_id propagation + 5xx sanitization + structured logging.

## v0.3.0

- Hard rule #17: ban camelCase di REST surface (snake_case JSON, kebab-case URL).

## v0.2.1

- Refine rule #6: interface independence, bukan cuma struct.

## v0.2.0

- Tambah `bootstrap-new-project` recipe (Tahap 3).
- Tambah `tools/lint.sh` untuk static analysis (Tahap 4).

## v0.1.2

- Tambah `feature-recipe.md`: walkthrough end-to-end yang menutup 5 friction point dari smoke-test.

## v0.1.1

- Tajamkan rule #10.
- Tambah 4 varian anti-pattern dari baseline audit.

## v0.1.0

- 6 hard rules baru + reference anti-pattern.

## v0.0.x (pre-tagging)

- Initial: Clean Architecture playbook untuk Go REST (controller / use_case / repository).
- Hard rule: reuse `pkg/` utilities, no per-feature pagination/error logic.
- Hard rule: ban N+1 queries di use_case loop, prefer batch fetch.
- Tambah `.claude-plugin/marketplace.json` agar `/plugin marketplace add` mengenali plugin.
