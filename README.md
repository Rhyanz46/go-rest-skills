# go-rest-skills

Plugin marketplace untuk Claude Code CLI berisi kumpulan skill yang aku pakai sehari-hari. Plugin name di dalam marketplace ini adalah **`rhyanz46`**.

Setelah plugin di-install, semua skill di dalamnya tersedia otomatis di sesi Claude Code, dengan namespace `rhyanz46:<skill-name>`.

---

## Cara install

Di dalam Claude Code CLI, jalankan:

```text
/plugin marketplace add Rhyanz46/go-rest-skills
/plugin install rhyanz46@go-rest-skills
```

Restart sesi setelah install. Cek dengan `/help` atau lihat daftar skill di system prompt — skill harus muncul dengan prefix `rhyanz46:`.

Untuk update ke versi terbaru:

```text
/plugin update rhyanz46@go-rest-skills
```

---

## Skill yang tersedia

### `rhyanz46:go-rest-clean-arch`

Playbook kanonik untuk Go REST backend dengan gaya **Clean Architecture** (controller → use_case → repository), validasi request berbasis `map_validator`, dan urutan belajar **Stop-and-Wait** dari `ai_instruction/`.

Pakai skill ini saat:
- Mendesain, scaffold, atau refactor Go REST service di gaya ini
- Project punya `CLAUDE.md` yang reference `go-rest-clean-arch`
- Pattern `app/{controller,use_case,repository}` muncul atau dibahas
- User eksplisit minta playbook ini

Detail lengkap: [`skills/go-rest-clean-arch/SKILL.md`](skills/go-rest-clean-arch/SKILL.md) (+ folder `references/` untuk hard rules dan contoh).

### `rhyanz46:code-review-business`

Skill review kodingan general dengan satu prinsip kunci: **kalau ada yang aneh, verifikasi ke tim yang bersangkutan dulu — jangan langsung memvonis "bug"**. Banyak pola yang terlihat janggal sebenarnya sengaja begitu karena alasan bisnis, regulasi, atau kompromi historis.

Pakai skill ini saat:
- Minta review kode general (bukan PR formal)
- Frasa pemicu: "tolong review kodingan", "cek kodingan ini", "code review", "review umum", dll.

Output dikelompokkan ke 4 kategori: **bug jelas**, **perlu konfirmasi bisnis** (paling penting — disertai pertanyaan siap-paste untuk tim terkait), **code smell**, dan **catatan positif**.

Untuk PR formal, security review, atau perbaikan langsung, pakai built-in `/review`, `/ultrareview`, atau `/security-review`.

Detail lengkap: [`skills/code-review-business/README.md`](skills/code-review-business/README.md) dan [`SKILL.md`](skills/code-review-business/SKILL.md).

---

## Struktur repo

```
.
├── .claude-plugin/
│   ├── marketplace.json     # marketplace manifest (name: go-rest-skills)
│   └── plugin.json          # plugin manifest (name: rhyanz46)
├── skills/
│   ├── go-rest-clean-arch/
│   │   ├── SKILL.md
│   │   └── references/      # hard rules, anti-patterns, recipes
│   └── code-review-business/
│       ├── SKILL.md
│       └── README.md
└── tools/
    └── lint.sh              # static analysis helper
```

---

## Kontribusi

Repo ini personal, tapi PR / issue welcome kalau ada saran perbaikan atau temuan bug di skill-nya.

## Lisensi

Free to use & modify untuk kebutuhan personal maupun tim.
