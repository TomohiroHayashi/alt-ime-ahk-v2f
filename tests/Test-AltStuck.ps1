<#
.SYNOPSIS
    Regression test: does a fast Alt tap leave Alt logically stuck down?

.DESCRIPTION
    Starts the script under test, injects many fast Alt taps (down, then up
    after a random 0-3 ms gap) and checks after each tap whether Windows still
    thinks the Alt key is down. A stuck Alt turns Esc into Alt+Esc and Enter
    into Alt+Enter.

    The bug this guards against: AutoHotkey removes its keyboard hook while
    Send() uses SendInput. If the Alt key-up arrives in that window, the hook
    never sees it, so "~*LAlt up" never sends {LAlt Up}, and the
    {LAlt DownR} injected by "*LAlt" stays in effect. Under load (right after
    boot) the window is wide enough for real typing to hit it.

    The taps go to the foreground window, and the script under test switches
    the IME on and off while the test runs. Exit every other instance of
    alt-ime-ahk first (including one started by Task Scheduler as admin):
    a second keyboard hook makes the result meaningless.

.PARAMETER AhkExe
    Path to AutoHotkey v2 (AutoHotkey64.exe). Not needed when -Script is an .exe.

.PARAMETER Script
    The .ahk script (or compiled .exe) to test. Defaults to the script in the
    repository root.

.PARAMETER Taps
    Number of taps per key.

.PARAMETER Keys
    Which keys to test: LAlt, RAlt or both.

.EXAMPLE
    .\tests\Test-AltStuck.ps1 -AhkExe C:\Tools\AutoHotkey\AutoHotkey64.exe

.NOTES
    Exit code 0 when no tap left a key stuck, 1 when at least one did,
    2 when the test could not run.
#>
[CmdletBinding()]
param(
    [string]$AhkExe,
    [string]$Script = (Join-Path (Split-Path -Parent $PSScriptRoot) 'alt-ime-ahk-v2f.ahk'),
    [ValidateRange(1, 10000)][int]$Taps = 200,
    [ValidateSet('LAlt', 'RAlt')][string[]]$Keys = @('LAlt', 'RAlt')
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class AltTap {
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte sc, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);

    const uint KEYEVENTF_EXTENDEDKEY = 0x1, KEYEVENTF_KEYUP = 0x2;

    static uint Ext(byte vk) { return vk == 0xA5 ? KEYEVENTF_EXTENDEDKEY : 0; } // RAlt is an extended key.

    public static bool IsDown(byte vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

    public static void Release(byte vk, byte sc) {
        keybd_event(vk, sc, Ext(vk) | KEYEVENTF_KEYUP, UIntPtr.Zero);
        Thread.Sleep(100);
    }

    // Returns the gaps (in microseconds) of the taps that left the key stuck.
    public static double[] Run(byte vk, byte sc, int taps, int settleMs, int seed) {
        var rnd = new Random(seed);
        var stuck = new System.Collections.Generic.List<double>();
        for (int i = 0; i < taps; i++) {
            double gapUs = rnd.NextDouble() * 3000;
            keybd_event(vk, sc, Ext(vk), UIntPtr.Zero);
            var sw = Stopwatch.StartNew();
            while (sw.Elapsed.TotalMilliseconds * 1000 < gapUs) { } // busy-wait: Sleep() is too coarse
            keybd_event(vk, sc, Ext(vk) | KEYEVENTF_KEYUP, UIntPtr.Zero);
            Thread.Sleep(settleMs);
            if (IsDown(vk)) {
                stuck.Add(gapUs);
                Release(vk, sc);
            }
        }
        return stuck.ToArray();
    }
}
'@

$keyInfo = @{
    LAlt = @{ Vk = [byte]0xA4; Sc = [byte]0x38 }
    RAlt = @{ Vk = [byte]0xA5; Sc = [byte]0x38 }
}

$Script = (Resolve-Path $Script).Path
if ($Script -like '*.exe') {
    $exe = $Script; $arguments = @()
} else {
    if (-not $AhkExe) { Write-Error 'Pass -AhkExe (path to AutoHotkey64.exe) to run an .ahk script.'; exit 2 }
    $exe = (Resolve-Path $AhkExe).Path; $arguments = @("`"$Script`"")
}

$others = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -match '^alt-ime-ahk|^AutoHotkey' }
if ($others) {
    $list = ($others | ForEach-Object { "$($_.ProcessName) (pid $($_.Id))" }) -join ', '
    Write-Host "Another AutoHotkey / alt-ime-ahk process is running: $list" -ForegroundColor Red
    Write-Host 'Exit it from the tray icon first; a second keyboard hook makes this test meaningless.'
    exit 2
}

foreach ($k in $Keys) {
    if ([AltTap]::IsDown($keyInfo[$k].Vk)) { [AltTap]::Release($keyInfo[$k].Vk, $keyInfo[$k].Sc) }
}

Write-Host "Testing: $Script"
$proc = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru
$failed = $false
try {
    Start-Sleep -Seconds 2 # let the script install its keyboard hook
    if ($proc.HasExited) { Write-Error "The script exited early (exit code $($proc.ExitCode))."; exit 2 }

    foreach ($k in $Keys) {
        $stuck = [AltTap]::Run($keyInfo[$k].Vk, $keyInfo[$k].Sc, $Taps, 300, 12345)
        $color = if ($stuck.Count) { 'Red' } else { 'Green' }
        Write-Host ("{0}: {1} of {2} taps left the key stuck" -f $k, $stuck.Count, $Taps) -ForegroundColor $color
        if ($stuck.Count) {
            $failed = $true
            Write-Host ('  gaps (us): ' + (($stuck | Select-Object -First 15 | ForEach-Object { '{0:N0}' -f $_ }) -join ', '))
        }
    }
} finally {
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    foreach ($k in $Keys) {
        if ([AltTap]::IsDown($keyInfo[$k].Vk)) { [AltTap]::Release($keyInfo[$k].Vk, $keyInfo[$k].Sc) }
    }
}

if ($failed) { Write-Host 'FAIL' -ForegroundColor Red; exit 1 }
Write-Host 'PASS' -ForegroundColor Green
exit 0
