# Pokémon Soulgold Overlays

This is a simple project that contains dynamic widgets to add to OBS for streaming **Pokémon Soulgold**.

The goal is to streamline 2 things that drove me nuts when streaming pokemon games:
- Updating sprites
- Updating counts on my overlay.

Gone are the days of scrolling through hundreds of sprites to find the mon you are looking for.
No more editing text files and moving numbers on screen when a new digit shows up.

> [!IMPORTANT]
> The party widget is built for **Pokémon Soulgold v1.1.2**. Game updates can move things around in memory, which may break it until this project is updated too — so check that your game version matches before setting up. If a new version has just come out, see the [FAQs](#faqs).

## What's Included

- `.bat` files that you can map to hotkeys to kick off all of the necessary scripts
- A `.lua` script to load into mGBA that will output party data when you rearrange the party, deposit/withdraw, and update hp and statuses in battle
- Overlays that you can load into OBS as browser sources to display the desired data
- Scripts to update the counters with the push of a button
- A starter wheel that picks a random starter for you
- A small server that relays the party data to the overlays

## Setup

1. Install [Node.js](https://nodejs.org/en/download) (don't be scared, you don't have to code anything).
   - Grab whatever the LTS is — this project shouldn't ever be version dependent.
   - This is needed to run the javascript files that power this whole app.

2. Download this project.
   - On this page, click the green **Code** button → **Download ZIP**, then unzip it somewhere you won't move it later (OBS remembers where the files are — if you move the folder, the overlays go blank).
   - Install the lone dependency by running `npm install`, or for the non-technical folks: open the `hotkeys` folder and double-click `install.bat`. When it's done, go back and if you have a node_modules you're done.

3. Start the server:
   - Use `start.bat` located in the `hotkeys` folder, **or**
   - Open a command prompt / terminal and run `npm start`.

   > Non-tech note: this opens a command prompt window — leave it open until you're done streaming. Just minimize it.

4. In mGBA (version 0.10 or newer — older versions don't have the Scripting menu):
   - Open **Tools → Scripting**
   - Load `sgPartyEvents.lua` from the `lua` folder
   - You'll need to do this every time you open mGBA — it doesn't remember the script between sessions.

5. In OBS, add your desired overlays:
   - Add a new source as a **Browser**
   - Tick the option for **Local file** and point to the `.html` file for the overlay you want to display.
   - `overlays/party.html` — the party
     - Sprites are pulled from the Soulgold website, so this one needs an internet connection to show them. My apologies, if you're recording while on holiday in a remote location.
   - `overlays/counters.html` — attempt, deaths and level cap (Optional)
     - Three squares in a row that scale with the source width. Around 660 × 240 gives full-size squares.
   - `overlays/wheel/index.html` — the starter wheel (Optional)


   > The team widget rearranges itself based on how wide you make the browser source, so the same file works for a few different layouts. Set the **Width** and **Height** in the source's properties:
   > - **One row of 6** — width 500 or more. Around 1300 × 250 gives full-size discs.
   > - **2 columns × 3 rows** — width between 300 and 499. Around 400 × 600 works well.
   > - **One vertical column** — width under 300. Around 200 × 1000 works well.
   >
   > If the discs look cut off, make the source a little taller; if they look small, make it wider. For best results, use the Width and Height values of the browser source rather than using the scaling tool to resize.

6. (Optional) If using the counters widget:

   It updates automatically and does not need the server at all — it runs completely standalone. To change the numbers, run the `.bat` file from the `hotkeys` folder:
   - `addDeath` — adds one to the death count
   - `increaseCap` — moves the level cap to the next one (Falkner → Bugsy → Whitney → … → Champion)
   - `newRun` — adds one to the attempt count, resets deaths to 0, and sets the level cap back to the first one
   - `resetAll` — sets attempts back to 1, deaths to 0, and the level cap back to the first one

7. (Optional) If using the starter wheel:

   It spins as soon as it loads and does not need the server. When adding to your scene tick **Refresh browser when scene becomes active**. To spin again, toggle hide/show (the eye icon) next to the source and it will start again.

## Hotkeys

There are multiple ways on a computer to run a file by hotkey — the easiest is with an Elgato Stream Deck if you have one. Create a **System** key set to **Open**, name the key whatever you want, and point it to the desired `.bat` file. Press it and it does the thing.

That is the easy option but it's expensive. This can also be done for free — there are many ways to do it, all of which start with searching "run batch file with hotkey" on the Google machine.

## FAQs

### Will this work for [insert Romhack name]?

No. Every romhack has different addresses in memory for party information. Every romhack adds new pokemon in different ways and need a new mapping to render sprites. There is far more work needed for each than is worth the effort.

### It's not working

Is mGBA running the script? Did you start the server? Without these 2 the party overlay will not receive the data it needs. Remember the script has to be loaded again every time you open mGBA.

### The party shows but the sprites are missing

The sprites come from the internet — check your connection.

### A new version of Soulgold came out and the party widget stopped working

The game update moved things around in memory. Wait for me to update this project, or if you're feeling brave, see [Overly Technical Stuff](#overly-technical-stuff) to find the new values yourself.

### My egg is shiny but the overlay shows it normal

Rendering an egg is already hacky enough, I'm not adding more conditionals for something temporary.

## Support

If you like this and want to support me, come hang out on Twitch: [twitch.tv/professorxavier](https://www.twitch.tv/professorxavier). A follow goes a long way.

## Overly Technical Stuff

This all works by emitting TCP messages through mGBA. These messages are sent over your network, but the party overlay cannot receive them. The server listens for those TCP messages and forwards them on through websockets which is what the overlay is looking for.

> [!NOTE]
> As packaged the lua script provided will **only** work for the latest version of Soulgold. Every update potentially moves the memory addresses needed to render the team widget. I will do my best to keep this up to date but I can't immediately be on top of every hotfix released.
>
> Known values for each version are listed in `lua/ADDRESSES.md` — check there first. If your version isn't listed and you don't want to wait for me to update the repo, you can find the new addresses yourself with `findAddresses.lua` (in the `lua` folder):
>
> 1. Load your save in mGBA and stand in the overworld with at least one Pokémon in your party.
> 2. Open **Tools → Scripting** and load `findAddresses.lua`. Within a second or two it prints lines like:
>    ```
>    [finder] PARTY_LOC = 0x0203901C
>    [finder] gMain = 0x030055C0  ->  IN_BATTLE_ADDR = 0x030059F9
>    ```
>    If it prints more than one `PARTY_LOC`, the right one is the line whose `slot1:` matches your lead Pokémon's nickname, level and HP.
> 3. If it prints more than one `gMain`, leave the script running, get into a wild battle and back out — it keeps printing each candidate every couple of seconds, and the right one is the address whose `inBattle` flips from 0 to 1 and back.
> 4. Open `sgPartyEvents.lua` in any text editor, paste the two values over `PARTY_LOC` and `IN_BATTLE_ADDR` near the top, and save.
>
> If the scan finds nothing, set `LEAD_NICKNAME` at the top of `findAddresses.lua` to your lead Pokémon's exact nickname and run it again — it will dump the raw bytes around every match so the problem can be tracked down.
>
> If this sounds like too much for you to do, wait for me to make the update when I have the time to do so or use the old version of the rom.
