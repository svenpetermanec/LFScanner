# LFScanner (Turtle WoW / Vanilla 1.12)

**LFScanner** is a lightweight, efficient chat-scanning addon designed specifically for the **Turtle WoW** (Vanilla+) client. It monitors the World chat for dungeon and raid recruitment messages and alerts you instantly when a group matches your specific role and raid interests.

---

## Features

* **Pre-filled Turtle WoW Raids:** Pre-configured with keywords for **Emerald Sanctum NM**, **Karazhan 10**, **Ruins of AQ**, **ZG**, and more.
* **Filtering Role Specific:** Choose between **DPS**, **RDPS (Ranged)**, **Tank**, or **Heal**.
* **Click-to-Whisper:** Click a player's name in the chat alert to instantly start a whisper.
* **Anti-Spam & Muting:**
    * **Throttle:** Prevents multiple alerts from the same person/raid within 60 seconds.
    * **1h Mute:** Use the "Mute Last" button to ignore a specific player's alerts for one hour.
* **History Log:** View the last 8 matches with timestamps.

---

## Installation

1.  **Download:** Click the green **Code** button and select **Download ZIP**.
2.  **Unzip:** Extract the contents of the `.zip` file.
3.  **Rename:** You will likely see a folder named `LFScanner-master`. **You must rename this folder to exactly `LFScanner`** (remove the `-master` suffix).
4.  **Move:** Place the `LFScanner` folder into your World of Warcraft directory: `Interface\AddOns\`.
6.  **Load:** Restart the game or type `/reload` in-game.

---

## 📖 How To Use

### Configuration
* **Toggle Menu:** Click the Minimap icon or type `/lfscanner`.
* **Start/Pause:** Use the top-left button to enable or disable the scanner globally.
* **Adding Raids:** Enter a name and comma-separated keywords (e.g., `UBRS` and `UBRS, REND, BWL`) then click **Add**.

### Role Selection
Select your role from the dropdown. 
* **DPS:** Matches general damage keywords.
* **RDPS:** Specifically looks for Ranged, Caster, Mage, Lock, and Hunter keywords.

### Managing Spammers
If a player is filling your alerts with spam, open the UI and click **Mute Last**. This adds them to a temporary blacklist for 60 minutes. You can clear all mutes at any time with the **Unmute All** button.
