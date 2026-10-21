# Game Session and appearance

Open **Game Session** from the sidebar, an achievement page, or **Open Game Session** beside a library game's **Open stats** action. Title spoofing is at the top left, game details and the achievement-page image at the top right, and Auto Unlock below. Opening a selected game loads its title details and requests Xbox playtime when connected and outside the existing cooldown. Opening the page does not start spoofing or an unlock queue.

Queue settings, saved queues and tools are permanently visible. Queue status sits to their right where space permits and flows underneath in smaller windows. Delay fields accommodate 10080 minutes. Details support selection and copying.

In **Settings → Appearance**, choose game art, a local custom image, or no artwork; optionally retain game art across pages and launches. Adjust glass transparency, blur and colour, or choose OLED black. Preferences are local. Wide Xbox catalogue artwork is preferred when available; image availability varies by game. The full image keeps its aspect ratio, with a blurred fill behind it.

Home and Library summaries use the loaded library: earned base-game Mythics, fully completed games including add-ons, and weighted achievement completion. Duplicate title IDs are counted once. Unknown progress and titles without achievement definitions do not contribute to the percentage. These summaries do not make extra network requests.

## Verification

Run `tools/Test-Enhancements.ps1` and `tools/Test-Presentation.ps1` with .NET 9. After `tools/Build-Release.ps1`, run `tools/Test-Presentation.ps1 -Executable <published exe> -OutputDirectory <new directory>` for offline UI checks at three window sizes, image reuse, customization, layout fit and 240-game scrolling. This uses generated demo artwork and fictional account data; it does not invoke spoofing or unlock execution. CI retains the rendered checks as an artifact. Live authenticated Xbox behavior is outside these offline checks.
