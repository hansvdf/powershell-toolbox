# PATH setup on macOS

How to make the scripts in this repository available by name on a Mac, and the macOS background you need to understand what the setup scripts do: the two shells (zsh and PowerShell), how `PATH` works, and PowerShell's profile files.

## In short

- On a Mac you work in **zsh** by default. PowerShell (`pwsh`) is a separate shell, which you can start from zsh or open directly.
- To run the scripts by name **inside PowerShell**, run this once in `pwsh`:

  ```powershell
  ./setup/Add-ScriptFoldersToPath.ps1 -StorePermanently
  ```

  This writes the list of script folders to your PowerShell profile, `~/.config/powershell/profile.ps1`. Every new PowerShell window then has them on `PATH`.
- This does **not** make the scripts available by name in **zsh**. For that, see [Running the scripts from zsh](#running-the-scripts-from-zsh).
- After adding a new subfolder to the repository, run the command again. To undo everything, run `./setup/Remove-ScriptFoldersFromPath.ps1 -StorePermanently`.

## Two shells: zsh and PowerShell

A *shell* is the program that reads the commands you type in a terminal. macOS uses **zsh** by default. When you open Terminal, iTerm2 or the VS Code terminal, you're in zsh unless you changed that.

**PowerShell** is a different shell, which you install separately (`brew install powershell`). Its command is `pwsh`. zsh can't run PowerShell scripts itself: if you type `./Compare-Folders.ps1` in zsh, it tries to read the file as a zsh script and fails on the first line:

```text
./Compare-Folders.ps1: line 1: syntax error near unexpected token `newline'
./Compare-Folders.ps1: line 1: `<#'
```

So you either run the scripts from inside PowerShell, or let zsh hand them over to PowerShell (see [Running the scripts from zsh](#running-the-scripts-from-zsh)).

### Opening PowerShell from zsh

The usual way: type `pwsh` in a zsh terminal.

```zsh
pwsh
```

PowerShell now runs *inside* zsh. It inherits zsh's environment, including `PATH`. Type `exit` to return to zsh.

### Opening PowerShell directly

You can also start PowerShell without zsh in between. From least to most invasive:

1. **VS Code terminal.** In the terminal panel, click the **⌄** next to **+** and choose **pwsh**. To make it the default, open the command palette (⌘⇧P), run **Terminal: Select Default Profile** and pick **pwsh**.
2. **One terminal app.**
   - **Terminal.app:** Settings → General → *Shells open with* → **Command (complete path)** → `/opt/homebrew/bin/pwsh`
   - **iTerm2:** Settings → Profiles → General → Command → **Custom Shell** → `/opt/homebrew/bin/pwsh`
3. **As your login shell, for every terminal app.**

   ```zsh
   sudo sh -c 'echo /opt/homebrew/bin/pwsh >> /etc/shells'
   chsh -s /opt/homebrew/bin/pwsh
   ```

   Switch back with `chsh -s /bin/zsh`. Only do this if you want PowerShell for everything: many Mac tools and instructions assume zsh.

`/opt/homebrew/bin/pwsh` is the Homebrew location on Apple silicon Macs. On Intel Macs it's `/usr/local/bin/pwsh`. Run `which pwsh` in zsh to see yours.

PowerShell opened directly does **not** read zsh's startup file (`~/.zshrc`). It starts with the basic system `PATH`, plus whatever its own profile adds.

### Which one do I have?

In PowerShell:

```powershell
(Get-Process -Id $PID).Parent.ProcessName
```

- `zsh`: PowerShell was started from zsh.
- Anything else, such as `login` or `Code Helper`: it was opened directly.

## How PATH works on macOS

`PATH` is the list of folders a shell searches when you type a command by name. Compared to Windows, there are four differences that matter here:

| | Windows | macOS |
| --- | --- | --- |
| Separator between folders | `;` | `:` |
| Variable name | Case-insensitive: `$env:Path` and `$env:PATH` are the same | Case-sensitive: only `$env:PATH` is the real one; `$env:Path` is a different, unused variable |
| Permanent per-user `PATH` | Stored in the registry (the "user PATH") | Doesn't exist. Every shell builds `PATH` at startup from its startup files |
| Inherited by programs started from the shell | Yes | Yes |

The third difference is the important one. To make a change permanent on a Mac, you add it to a **startup file** that the shell runs every time it starts. Each shell has its own:

| Shell | Startup file |
| --- | --- |
| zsh | `~/.zshrc` |
| PowerShell | its profile files (see the next section) |

Because of inheritance, which startup file counts depends on how PowerShell was started:

| Where you type the command | Startup files that ran | Scripts found by name if the folders are added in… |
| --- | --- | --- |
| zsh | `~/.zshrc` | `~/.zshrc` |
| `pwsh` started from zsh | `~/.zshrc` (inherited), then the PowerShell profile | `~/.zshrc` **or** the PowerShell profile |
| `pwsh` opened directly | the PowerShell profile | the PowerShell profile |

## PowerShell profile files on macOS

A *profile* is a PowerShell script that runs automatically every time PowerShell starts. It's PowerShell's equivalent of `~/.zshrc`. There isn't just one, but four, depending on **who** it applies to (you or all users) and **which host** (only the normal `pwsh` terminal, or every program that runs PowerShell):

| Profile | Applies to | Path on macOS (Homebrew) |
| --- | --- | --- |
| Current user, current host (this is `$PROFILE`) | You, only in the `pwsh` terminal | `~/.config/powershell/Microsoft.PowerShell_profile.ps1` |
| **Current user, all hosts** | **You, in every PowerShell host** | **`~/.config/powershell/profile.ps1`** |
| All users, current host | Everyone, only in the `pwsh` terminal | `/opt/homebrew/Cellar/powershell/<version>/libexec/Microsoft.PowerShell_profile.ps1` |
| All users, all hosts | Everyone, in every PowerShell host | `/opt/homebrew/Cellar/powershell/<version>/libexec/profile.ps1` |

A *host* is the program that runs PowerShell: the `pwsh` terminal is one, and the **PowerShell extension** in VS Code is another, with its own "current host" profile, `Microsoft.VSCode_profile.ps1`. The "all hosts" profiles run in both.

When PowerShell starts, it runs the profiles that exist in this order: all users/all hosts, all users/current host, current user/all hosts, current user/current host. Profiles that don't exist are skipped, and none of them exist after a fresh install.

### Checking your profiles

```powershell
$PROFILE                    # path of the current user, current host profile
$PROFILE | Select-Object *  # paths of all four
Test-Path $PROFILE          # True if that file exists
Test-Path $PROFILE.CurrentUserAllHosts

# All four at once, with whether each exists
foreach ($name in 'AllUsersAllHosts', 'AllUsersCurrentHost', 'CurrentUserAllHosts', 'CurrentUserCurrentHost') {
    '{0,-24} {1,-6} {2}' -f $name, (Test-Path $PROFILE.$name), $PROFILE.$name
}
```

To open or create a profile in VS Code: `code $PROFILE.CurrentUserAllHosts`.

### Which profile the setup script uses, and why

`Add-ScriptFoldersToPath.ps1 -StorePermanently` writes to **current user, all hosts** (`~/.config/powershell/profile.ps1`):

- **Current user:** it's your setup, it doesn't need `sudo`, and it doesn't affect other users.
- **All hosts:** the folders are on `PATH` in the `pwsh` terminal *and* in the VS Code PowerShell extension.
- **Not the all-users profiles:** they live inside the Homebrew installation folder, which is replaced when PowerShell is updated, so your changes would disappear.

Profiles also run when a script is started with `pwsh -File`, unless you add `-NoProfile`. Because the setup script writes a fixed list of folders (see below), this adds practically no startup time.

## What the setup scripts do on macOS

### Without `-StorePermanently`

The folders are added to `$env:PATH` of the current PowerShell session only. Close the window and they're gone. Nothing is written to disk.

### With `-StorePermanently`

The folders are added to the current session *and* the script writes a marked block to `~/.config/powershell/profile.ps1`. It creates the file and the `~/.config/powershell` folder if they don't exist. The block looks like this:

```powershell
# >>> powershell-toolbox PATH: /Users/you/Projects/powershell-toolbox >>>
# Added by Add-ScriptFoldersToPath.ps1 on 2026-11-22.
# Run that script again with -StorePermanently to update this list, or
# Remove-ScriptFoldersFromPath.ps1 -StorePermanently to remove this block.
foreach ($folder in @(
    '/Users/you/Projects/powershell-toolbox'
    '/Users/you/Projects/powershell-toolbox/files'
    '/Users/you/Projects/powershell-toolbox/power-bi'
    '/Users/you/Projects/powershell-toolbox/setup'
)) {
    if (($env:PATH -split [IO.Path]::PathSeparator) -notcontains $folder) {
        $env:PATH += [IO.Path]::PathSeparator + $folder
    }
}
# <<< powershell-toolbox PATH: /Users/you/Projects/powershell-toolbox <<<
```

- **The `>>>` and `<<<` lines** mark where the block starts and ends. The scripts use them to find it again. They include the folder, so if you also run the script with `-Path` for another folder, that folder gets its own block.
- **Which folders:** the repository and all its subfolders, except dot-folders like `.git` and folders named in `-Exclude`, which defaults to `docs`. Use for example `-Exclude 'docs', 'test*'` to skip more.
- **The folder list is fixed.** PowerShell doesn't scan the repository at startup, so it starts as fast as before. New subfolders only appear after you run the script again.
- **The loop** adds each folder to the *end* of `PATH`, unless it's already there. Adding to the end means built-in commands keep priority over a script with the same name. Checking first avoids duplicates when you start `pwsh` from inside `pwsh`.

What happens when you run the scripts again:

| You run… | Result |
| --- | --- |
| `Add-… -StorePermanently`, no block yet | The block is added at the end of the profile, after a blank line. |
| `Add-… -StorePermanently`, block already there | The block is replaced in the same position with the current folder list. |
| `Remove-… -StorePermanently` | The block is deleted. The rest of the profile stays as it is. If the profile is then empty, the file is deleted. |
| `Remove-… -StorePermanently`, no block | Nothing changes; the script says no block was found. |

Your own lines above or below the block are never changed. If you edit the folder list *inside* the block by hand, running the add script again overwrites those edits. Put your own `PATH` changes outside the block.

On **Windows**, `-StorePermanently` doesn't use the profile: it adds the folders to the user `PATH` in the registry, as Windows users expect.

## Running the scripts from zsh

The PowerShell profile only runs when PowerShell starts. zsh never reads it, so after the setup script, typing `Compare-Folders.ps1` in zsh still gives "command not found". You have three options.

### 1. Start them with `pwsh`

Works right away, with a full or relative path:

```zsh
pwsh -File ~/Projects/powershell-toolbox/files/Compare-Folders.ps1 -FolderA ./old -FolderB ./new
```

### 2. Make them runnable by name from zsh

This needs two things.

**a. The script folders on zsh's `PATH`.** Add this to `~/.zshrc`. It adds the repository and all its subfolders, skipping dot-folders like `.git` and the `docs` folder, the same as the setup script. It picks up new subfolders every time you open a terminal:

```zsh
# powershell-toolbox: add the repository and its subfolders to PATH
for dir in ~/Projects/powershell-toolbox ~/Projects/powershell-toolbox/**/*(/N); do
  [[ $dir == */.* || $dir == */docs || $dir == */docs/* ]] || PATH="$PATH:$dir"
done
export PATH
```

**b. Scripts that tell zsh to use PowerShell.** Each script needs this as its very first line, above the `<#` help block:

```powershell
#!/usr/bin/env pwsh
```

It also needs to be executable: `chmod +x files/Compare-Folders.ps1`. The scripts in this repository don't have that first line yet. It's harmless on Windows, where PowerShell treats it as a comment.

Because `pwsh` started from zsh inherits zsh's `PATH`, this option also makes the scripts available by name in PowerShell. You then don't need `-StorePermanently` on the Mac, unless you also open PowerShell directly.

### About `export PATH=...`

A line like this is zsh syntax:

```zsh
export PATH="$HOME/Scripts/PowerShell:$PATH"
```

- **Typed in a terminal:** it adds that one folder to `PATH` for the current zsh window only.
- **In `~/.zshrc`:** it applies to every new zsh window, and to `pwsh` started from zsh.
- **Only that exact folder** is added, not its subfolders. That's why option 2 uses a loop.
- **The folder goes first:** `"folder:$PATH"` puts it at the start of `PATH`, so its commands win over system commands with the same name. `"$PATH:folder"` puts it at the end.

### `/etc/paths.d`

macOS also has a system-wide option: a file in `/etc/paths.d/` that lists folders, one per line. It needs `sudo`, applies to all users, doesn't include subfolders and has to be edited by hand when folders change. It's not recommended for this repository.

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `syntax error near unexpected token 'newline'` … `` `<#' `` | You ran a `.ps1` file in zsh. Run it in `pwsh`, use `pwsh -File …`, or set up option 2 above. |
| `command not found` in zsh after running the setup script | Expected: the setup script only changes PowerShell's `PATH`. See [Running the scripts from zsh](#running-the-scripts-from-zsh). |
| Not found in a new PowerShell window | Did you use `-StorePermanently`? Check that the block is there: `Get-Content $PROFILE.CurrentUserAllHosts`. Check the folders in the current session: `$env:PATH -split ':'`. |
| A new script in a new subfolder isn't found | The folder list is fixed. Run `./setup/Add-ScriptFoldersToPath.ps1 -StorePermanently` again. |
| PowerShell won't run the script at all | On macOS the execution policy doesn't apply. Check that you're in `pwsh` and the path is right. |
