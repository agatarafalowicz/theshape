# The Shape – Flutter

Port aplikacji "The Shape" z React + Vite + Tailwind do **Flutter**.
Wygląd, kolory, gradienty, kolejność ekranów, animacje pulsujące i logika
gry zostały odwzorowane 1:1 z oryginalnej wersji webowej.

## Struktura

```
lib/
  main.dart                       – uruchomienie + router stanu (login/bluetooth/main)
  app_theme.dart                  – paleta kolorów + 4 gradienty (CTA, indigo→purple, green, tło)
  widgets/
    decorative_blobs.dart         – rozmyte „bloby" w rogach ekranu
    glass_card.dart               – kontener „glassmorphism" z BackdropFilter
    primary_button.dart           – pełnoszerokościowy CTA z efektem active:scale-95
    shape_widget.dart             – CustomPainter rysujący 5 kształtów (kwadrat/trójkąt/koło/gwiazda/romb) z poświatą
  screens/
    login_page.dart               – logowanie + rejestracja + zakładki, użytkownik zapisany w SharedPreferences
    bluetooth_pairing.dart        – wybór czujnika RL/S/C + symulacja parowania
    main_page.dart                – 3 zakładki (Gra / Znajomi / Ustawienia) + 2 dialogi (wylogowanie, dodawanie znajomego)
    game_screen.dart              – pełna gra: nauka → bravo → ready → playing (10 rund, 6s/runda) → finished
```

## Mapowanie technologii

| Web (oryginał)                       | Flutter (port)                                  |
| ------------------------------------ | ----------------------------------------------- |
| `localStorage`                       | `shared_preferences`                            |
| `useState` / `useEffect`             | `StatefulWidget` + `setState` + `Timer`         |
| Tailwind `bg-*/blur-*/border-*`      | `Container` + `BoxDecoration` + `BackdropFilter`|
| `lucide-react` (ikony)               | `Icons` z Material                              |
| SVG `<polygon>` / `<rect>`           | `CustomPainter` w `shape_widget.dart`           |
| `@react-form` + walidacja             | `TextField` + walidacja w stanie                |
| `Dialog` (Radix)                     | `showDialog` + `Dialog`                         |
| `inter` font (przeglądarka)          | `google_fonts: Inter`                           |

## Uruchomienie

```bash
cd the_shape_flutter
flutter pub get
flutter run                   # urządzenie / emulator
flutter run -d chrome         # w przeglądarce
flutter build apk --release   # build dla Androida
```

## Konto testowe

Identycznie jak w wersji React:

- **email**: `test@t.pl`
- **hasło**: `password`
