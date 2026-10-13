Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ErrorActionPreference = "Stop"
trap {
    try { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "CyberCircuit Installer - Startup Error", "OK", "Error") | Out-Null } catch {}
    exit 1
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mcDir = Join-Path $env:APPDATA ".minecraft"
$iconPath = Join-Path $root "src\main\resources\assets\cybercircuit-client\icon.png"
$bundledRuntimeRoot = Join-Path $root "runtime\jdk-25"
$adoptiumApi = "https://api.adoptium.net/v3/binary/latest/25/ga/windows/x64/jdk/hotspot/normal/eclipse"
$script:jdk25 = $null
$script:logBox = $null
$script:buildMutex = $null
$gradleVersion = "9.5.1"
$gradleRuntimeRoot = Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit\GradleRuntime") $gradleVersion
$gradleArchive = Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit") "downloads") ("gradle-$gradleVersion-bin.zip")
$gradleDownloadUrl = "https://services.gradle.org/distributions/gradle-$gradleVersion-bin.zip"
$gradleSha256 = "bafc141b619ad6350fd975fc903156dd5c151998cc8b058e8c1044ab5f7b031f"

function Find-CSharpCompiler {
    $candidates = @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

function Build-CyberCircuitLauncher {
    $cs = Join-Path $root 'launcher\CyberCircuitLauncher.cs'
    $ico = Join-Path $root 'launcher\CyberCircuitIcon.ico'
    $outDir = Join-Path $env:LOCALAPPDATA 'CyberCircuit'
    $outExe = Join-Path $outDir 'CyberCircuitLauncher.exe'
    if (-not (Test-Path -LiteralPath $cs)) { throw 'CyberCircuit launcher source is missing.' }
    $csc = Find-CSharpCompiler
    if (-not $csc) { throw 'Microsoft .NET Framework C# compiler (csc.exe) was not found. The desktop launcher cannot be compiled on this PC yet.' }
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    Write-CCLog 'Compiling the CyberCircuit desktop launcher application.' 'info'

    # Use a compiler response file so paths containing spaces are handled reliably and
    # csc.exe never receives an empty /out: argument. Compile to a temporary EXE, then
    # atomically replace the installed launcher.
    $compileTempDir = Join-Path $env:TEMP ('CyberCircuitLauncher-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $compileTempDir | Out-Null
    $tempExe = Join-Path $compileTempDir 'CyberCircuitLauncher.exe'
    $rsp = Join-Path $compileTempDir 'compile.rsp'
    $rspLines = New-Object System.Collections.Generic.List[string]
    [void]$rspLines.Add('/nologo')
    [void]$rspLines.Add('/target:winexe')
    [void]$rspLines.Add('/optimize+')
    [void]$rspLines.Add('/out:"' + $tempExe + '"')
    if (Test-Path -LiteralPath $ico) { [void]$rspLines.Add('/win32icon:"' + $ico + '"') }
    [void]$rspLines.Add('/reference:System.dll')
    [void]$rspLines.Add('/reference:System.Drawing.dll')
    [void]$rspLines.Add('/reference:System.Windows.Forms.dll')
    $core = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.Core.dll'
    if (-not (Test-Path -LiteralPath $core)) { $core = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\System.Core.dll' }
    if (Test-Path -LiteralPath $core) { [void]$rspLines.Add('/reference:"' + $core + '"') }
    [void]$rspLines.Add('"' + $cs + '"')
    [System.IO.File]::WriteAllLines($rsp, $rspLines, (New-Object System.Text.UTF8Encoding($false)))

    try {
        $compilerOutput = @(& $csc ('@' + $rsp) 2>&1 | ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line) {
                if ($line -match '(?i)(error|failed)') { Write-CCLog $line 'bad' } else { Write-CCLog $line 'info' }
                $line
            }
        })
        $cscExit = $LASTEXITCODE
        if ($cscExit -ne 0 -or -not (Test-Path -LiteralPath $tempExe)) {
            $details = ($compilerOutput -join [Environment]::NewLine)
            if ([string]::IsNullOrWhiteSpace($details)) { $details = 'The compiler returned no diagnostic text.' }
            throw ('The desktop CyberCircuit Launcher EXE could not be compiled. C# compiler exit code: ' + $cscExit + [Environment]::NewLine + [Environment]::NewLine + $details)
        }

        $installedTemp = Join-Path $outDir ('CyberCircuitLauncher-' + [guid]::NewGuid().ToString('N') + '.exe')
        Copy-Item -LiteralPath $tempExe -Destination $installedTemp -Force
        Move-Item -LiteralPath $installedTemp -Destination $outExe -Force
        if (-not (Test-Path -LiteralPath $outExe)) { throw 'The compiled CyberCircuit Launcher EXE could not be moved into the local application folder.' }
    } finally {
        if (Test-Path -LiteralPath $compileTempDir) { Remove-Item -LiteralPath $compileTempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\CyberCircuit'
    New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
    try {
        $ws = New-Object -ComObject WScript.Shell
        $shortcut = $ws.CreateShortcut((Join-Path $desktop 'CyberCircuit Client.lnk'))
        $shortcut.TargetPath = $outExe
        $shortcut.WorkingDirectory = $outDir
        $shortcut.IconLocation = $outExe + ',0'
        $shortcut.Description = 'CyberCircuit Client Launcher'
        $shortcut.Save()
        $shortcut2 = $ws.CreateShortcut((Join-Path $startMenu 'CyberCircuit Client.lnk'))
        $shortcut2.TargetPath = $outExe
        $shortcut2.WorkingDirectory = $outDir
        $shortcut2.IconLocation = $outExe + ',0'
        $shortcut2.Description = 'CyberCircuit Client Launcher'
        $shortcut2.Save()
    } catch { Write-CCLog ('Shortcut creation warning: ' + $_.Exception.Message) 'warn' }
    Write-CCLog ('CyberCircuit Launcher EXE ready: ' + $outExe) 'good'
    return $outExe
}

function Write-CCLog($message, $level="info") {
    # The installer can start background/build work while the Live Log form is being
    # created or closed. Never touch a disposed RichTextBox; logging must not be able
    # to crash the installer or hide the real build error.
    $box = $script:logBox
    if (-not $box) { return }
    try {
        if ($box.IsDisposed -or $box.Disposing) { return }
    } catch { return }

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), [string]$message
    $color = switch ($level) {
        "good" { [Drawing.Color]::FromArgb(70,220,125) }
        "bad"  { [Drawing.Color]::FromArgb(255,90,95) }
        "warn" { [Drawing.Color]::FromArgb(255,190,75) }
        "info" { [Drawing.Color]::FromArgb(215,220,230) }
        default { [Drawing.Color]::FromArgb(215,220,230) }
    }

    try {
        if ($box.InvokeRequired) {
            [void]$box.BeginInvoke([Action]{ Write-CCLog $message $level })
            return
        }
        if ($box.IsDisposed -or $box.Disposing) { return }
        $box.SelectionStart = $box.TextLength
        $box.SelectionLength = 0
        $box.SelectionColor = $color
        $box.AppendText($line + [Environment]::NewLine)
        $box.SelectionStart = $box.TextLength
        $box.ScrollToCaret()
    } catch {
        # Logging is non-critical. Ignore disposal/handle-race errors so the installer
        # can continue and report the actual operation error instead.
    }
}

function Set-RoundedRegion($control, $radius) {
    try {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = $radius * 2
        $path.AddArc(0,0,$d,$d,180,90)
        $path.AddArc($control.Width-$d,0,$d,$d,270,90)
        $path.AddArc($control.Width-$d,$control.Height-$d,$d,$d,0,90)
        $path.AddArc(0,$control.Height-$d,$d,$d,90,90)
        $path.CloseFigure()
        $control.Region = New-Object System.Drawing.Region($path)
        $path.Dispose()
    } catch {}
}

function New-CCButton($text, $x, $y, $w, $h, $accent=$false) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.Font = New-Object Drawing.Font("Segoe UI", 10, [Drawing.FontStyle]::Bold)
    $b.Size = New-Object Drawing.Size($w,$h)
    $b.Location = New-Object Drawing.Point($x,$y)
    $b.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.ForeColor = [Drawing.Color]::White
    $b.Tag = if ($accent) { "accent" } else { "normal" }
    $b.BackColor = if ($accent) { [Drawing.Color]::FromArgb(0,145,225) } else { [Drawing.Color]::FromArgb(25,31,41) }
    $b.Cursor = [Windows.Forms.Cursors]::Hand
    $b.Add_HandleCreated({ Set-RoundedRegion $this 12 })
    $b.Add_MouseEnter({
        if ($this.Tag -eq "accent") { $this.BackColor = [Drawing.Color]::FromArgb(0,175,255) }
        else { $this.BackColor = [Drawing.Color]::FromArgb(38,47,61) }
    })
    $b.Add_MouseLeave({
        if ($this.Tag -eq "accent") { $this.BackColor = [Drawing.Color]::FromArgb(0,145,225) }
        else { $this.BackColor = [Drawing.Color]::FromArgb(25,31,41) }
    })
    return $b
}

function Get-JdkReleaseVersion($jdkHome) {
    if (-not $jdkHome) { return $null }
    $release = Join-Path $jdkHome "release"
    if (-not (Test-Path -LiteralPath $release)) { return $null }
    try {
        $line = Get-Content -LiteralPath $release -ErrorAction Stop | Where-Object { $_ -match '^JAVA_VERSION=' } | Select-Object -First 1
        if ($line -match '^JAVA_VERSION="([^"]+)"') { return $Matches[1] }
    } catch {}
    return $null
}

function Invoke-JdkVersion($exe) {
    $result = [ordered]@{ ExitCode = -1; Text = "" }
    if (-not (Test-Path -LiteralPath $exe)) { return [PSCustomObject]$result }
    $proc = New-Object System.Diagnostics.Process
    try {
        $proc.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $proc.StartInfo.FileName = $exe
        $proc.StartInfo.Arguments = '-version'
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.CreateNoWindow = $true
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError = $true
        if (-not $proc.Start()) { return [PSCustomObject]$result }
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        $result.ExitCode = $proc.ExitCode
        $result.Text = (($stdout + "`n" + $stderr).Trim())
    } catch {
        $result.Text = $_.Exception.Message
    } finally {
        $proc.Dispose()
    }
    return [PSCustomObject]$result
}

function Test-Jdk25Structure($jdkHome) {
    if (-not $jdkHome) { return $false }
    $java = Join-Path $jdkHome "bin\java.exe"
    $javac = Join-Path $jdkHome "bin\javac.exe"
    if (-not ((Test-Path -LiteralPath $java) -and (Test-Path -LiteralPath $javac))) { return $false }
    $releaseVersion = Get-JdkReleaseVersion $jdkHome
    if ($releaseVersion) { return ($releaseVersion -match '^25(?:\.|$)') }
    return $true
}

function Test-Jdk25Home($jdkHome) {
    if (-not (Test-Jdk25Structure $jdkHome)) { return $false }
    $java = Join-Path $jdkHome "bin\java.exe"
    $javac = Join-Path $jdkHome "bin\javac.exe"
    $javaResult = Invoke-JdkVersion $java
    $javacResult = Invoke-JdkVersion $javac
    $javaOutput = [string]$javaResult.Text
    $javacOutput = [string]$javacResult.Text
    $javaOk = ($javaResult.ExitCode -eq 0) -and ($javaOutput -match '(?i)version\s+"25(?:\.|")')
    $javacOk = ($javacResult.ExitCode -eq 0) -and ($javacOutput -match '(?i)javac\s+25(?:\.|\s|$)')
    if ($javaOk -and $javacOk) { return $true }
    $releaseVersion = Get-JdkReleaseVersion $jdkHome
    if ($releaseVersion) { Write-CCLog "JDK release file reports JAVA_VERSION=$releaseVersion" "info" }
    Write-CCLog "Bundled JDK executable validation failed." "bad"
    Write-CCLog ("java.exe exit code: " + $javaResult.ExitCode) "bad"
    if ($javaOutput) { Write-CCLog ("java.exe output: " + ($javaOutput -replace '[\r\n]+',' | ')) "bad" }
    Write-CCLog ("javac.exe exit code: " + $javacResult.ExitCode) "bad"
    if ($javacOutput) { Write-CCLog ("javac.exe output: " + ($javacOutput -replace '[\r\n]+',' | ')) "bad" }
    return $false
}

function Find-JdkHomeByExecutables($searchRoot) {
    if (-not $searchRoot -or -not (Test-Path -LiteralPath $searchRoot)) { return $null }
    try { $resolvedRoot = (Resolve-Path -LiteralPath $searchRoot).Path } catch { $resolvedRoot = $searchRoot }
    try {
        $javacMatches = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq "javac.exe" }
        foreach ($javacMatch in $javacMatches) {
            $binDir = Split-Path $javacMatch.FullName -Parent
            $jdkCandidateHome = Split-Path $binDir -Parent
            $java = Join-Path $binDir "java.exe"
            if (Test-Path -LiteralPath $java) {
                if (Test-Jdk25Structure $jdkCandidateHome) { return (Resolve-Path -LiteralPath $jdkCandidateHome).Path }
                $probe = Invoke-JdkVersion $java
                if (($probe.ExitCode -eq 0) -and ($probe.Text -match '(?i)version\s+"25(?:\.|")')) { return (Resolve-Path -LiteralPath $jdkCandidateHome).Path }
            }
        }
    } catch {}
    try {
        $javaMatches = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq "java.exe" }
        foreach ($javaMatch in $javaMatches) {
            $binDir = Split-Path $javaMatch.FullName -Parent
            $jdkCandidateHome = Split-Path $binDir -Parent
            $javac = Join-Path $binDir "javac.exe"
            if (Test-Path -LiteralPath $javac) {
                if (Test-Jdk25Structure $jdkCandidateHome) { return (Resolve-Path -LiteralPath $jdkCandidateHome).Path }
                $probe = Invoke-JdkVersion $javaMatch.FullName
                if (($probe.ExitCode -eq 0) -and ($probe.Text -match '(?i)version\s+"25(?:\.|")')) { return (Resolve-Path -LiteralPath $jdkCandidateHome).Path }
            }
        }
    } catch {}
    return $null
}

function Find-JdkHomeInTree($searchRoot) {
    if (-not $searchRoot -or -not (Test-Path -LiteralPath $searchRoot)) { return $null }
    try { $resolvedRoot = (Resolve-Path -LiteralPath $searchRoot).Path } catch { $resolvedRoot = $searchRoot }
    if (Test-Jdk25Structure $resolvedRoot) { return $resolvedRoot }
    return Find-JdkHomeByExecutables $resolvedRoot
}

function Find-BundledJdk25 {
    if (Test-Jdk25Structure $bundledRuntimeRoot) { return $bundledRuntimeRoot }
    $runtimeRoot = Join-Path $root "runtime"
    if (Test-Path -LiteralPath $runtimeRoot) {
        $found = Find-JdkHomeByExecutables $runtimeRoot
        if ($found -and ($found -ne (Join-Path $runtimeRoot "downloads"))) { return $found }
    }
    return $null
}

function Find-StandardJdk25 {
    $homes = New-Object System.Collections.Generic.List[string]
    $add = { param($p) if ($p -and (Test-Path $p) -and -not $homes.Contains($p)) { [void]$homes.Add($p) } }

    if ($env:JAVA_HOME) { & $add $env:JAVA_HOME }
    try {
        $cmd = Get-Command javac.exe -ErrorAction SilentlyContinue
        if ($cmd) { & $add (Split-Path (Split-Path $cmd.Source -Parent) -Parent) }
    } catch {}

    $roots = @(
        "$env:ProgramFiles\Eclipse Adoptium",
        "$env:ProgramFiles\Microsoft",
        "$env:ProgramFiles\Java",
        "$env:ProgramFiles\Amazon Corretto",
        "$env:ProgramFiles\Zulu",
        "${env:ProgramFiles(x86)}\Eclipse Adoptium",
        "${env:ProgramFiles(x86)}\Java",
        (Join-Path $mcDir "runtime")
    )
    foreach ($r in $roots) {
        if (Test-Path $r) {
            Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { & $add $_.FullName }
        }
    }
    foreach ($h in ($homes | Select-Object -Unique)) {
        if (Test-Jdk25Home $h) { return $h }
    }
    return $null
}

function Find-Jdk25([switch]$FullScan) {
    $bundled = Find-BundledJdk25
    if ($bundled) { return $bundled }
    $standard = Find-StandardJdk25
    if ($standard) { return $standard }
    if (-not $FullScan) { return $null }

    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root }
    foreach ($drive in $drives) {
        $status.Text = "Scanning $($drive.Root) for a JDK 25..."
        $progress.Value = [Math]::Min(92, [Math]::Max(20, $progress.Value + 2))
        $form.Refresh()
        try {
            $matches = Get-ChildItem -LiteralPath $drive.Root -Filter "javac.exe" -File -Recurse -ErrorAction SilentlyContinue
            foreach ($match in $matches) {
                $jdkCandidateHome = Split-Path (Split-Path $match.FullName -Parent) -Parent
                if (Test-Jdk25Home $jdkCandidateHome) { return $jdkCandidateHome }
            }
        } catch {}
    }
    return $null
}

function Get-AdoptiumJdk25Package {
    $downloadDir = Join-Path (Join-Path $root "runtime") "downloads"
    $cacheFile = Join-Path $downloadDir "temurin-jdk25-metadata.json"
    $metaUrl = "https://api.adoptium.net/v3/assets/latest/25/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse"

    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    $jsonText = $null

    try {
        Write-CCLog "Requesting the official Temurin JDK 25 package metadata from Adoptium." "info"
        $response = Invoke-WebRequest -Uri $metaUrl -UseBasicParsing -Headers @{ "User-Agent" = "CyberCircuit-Client/0.3.21" } -TimeoutSec 30
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            $jsonText = $response.Content
            Set-Content -LiteralPath $cacheFile -Value $jsonText -Encoding UTF8
            Write-CCLog "Adoptium package metadata downloaded and cached." "good"
        }
    } catch {
        Write-CCLog "Could not refresh Adoptium metadata: $($_.Exception.Message)" "warn"
        if (Test-Path -LiteralPath $cacheFile) {
            $jsonText = Get-Content -LiteralPath $cacheFile -Raw -ErrorAction SilentlyContinue
            if ($jsonText) { Write-CCLog "Using cached Adoptium metadata instead." "warn" }
        }
    }

    if (-not $jsonText) {
        # Offline/API fallback for the currently released Temurin 25.0.4.1 Windows x64 JDK.
        # The URL and checksum are pinned to the official Adoptium release used by v21.
        Write-CCLog "Adoptium API metadata was unavailable. Using the pinned official Temurin 25.0.4.1 Windows x64 package fallback." "warn"
        return [PSCustomObject]@{
            Url      = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jdk_x64_windows_hotspot_25.0.4.1_1.zip"
            Name     = "OpenJDK25U-jdk_x64_windows_hotspot_25.0.4.1_1.zip"
            Size     = [int64]141167264
            Checksum = "00c847d804f4a78e9f04f2683faf14fed898535b177b7fc704486cb0284e9283"
            Version  = "25.0.4.1"
        }
    }

    try {
        $assets = $jsonText | ConvertFrom-Json
    } catch {
        Write-CCLog "Cached/current Adoptium metadata was invalid. Falling back to the pinned official Temurin 25.0.4.1 package." "warn"
        return [PSCustomObject]@{
            Url      = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jdk_x64_windows_hotspot_25.0.4.1_1.zip"
            Name     = "OpenJDK25U-jdk_x64_windows_hotspot_25.0.4.1_1.zip"
            Size     = [int64]141167264
            Checksum = "00c847d804f4a78e9f04f2683faf14fed898535b177b7fc704486cb0284e9283"
            Version  = "25.0.4.1"
        }
    }

    $asset = @($assets | Where-Object {
        $_.binary.os -eq "windows" -and
        $_.binary.architecture -eq "x64" -and
        $_.binary.image_type -eq "jdk" -and
        $_.binary.jvm_impl -eq "hotspot" -and
        $_.binary.package.link -and
        $_.binary.package.checksum -and
        $_.binary.package.size
    } | Select-Object -First 1)

    if (-not $asset) { throw "Adoptium did not return a Windows x64 Temurin JDK 25 package." }

    $pkg = $asset[0].binary.package
    $hash = [string]$pkg.checksum
    if ($hash -notmatch '^[0-9a-fA-F]{64}$') { throw "Adoptium returned an invalid SHA-256 checksum in its metadata." }

    [PSCustomObject]@{
        Url      = [string]$pkg.link
        Name     = [string]$pkg.name
        Size     = [int64]$pkg.size
        Checksum = $hash.ToLowerInvariant()
        Version  = [string]$asset[0].version.semver
    }
}

function Move-ToBadPartial($path, $tag) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $badPath = "$path.$tag-$stamp"
    try {
        Move-Item -LiteralPath $path -Destination $badPath -Force -ErrorAction Stop
        Write-CCLog "Preserved the old download as $badPath" "warn"
    } catch {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}

function Verify-JdkArchive($archive, $expectedSize, $expectedHash) {
    if (-not (Test-Path -LiteralPath $archive)) { return $false }
    $size = (Get-Item -LiteralPath $archive).Length
    if ($size -ne $expectedSize) {
        Write-CCLog "Archive size is $size bytes; Adoptium expects $expectedSize bytes." "bad"
        return $false
    }
    Write-CCLog "Calculating JDK archive SHA-256..." "info"
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expectedHash) {
        Write-CCLog "SHA-256 verification failed." "bad"
        Write-CCLog "Expected: $expectedHash" "bad"
        Write-CCLog "Received: $actual" "bad"
        return $false
    }
    Write-CCLog "JDK archive SHA-256 verification passed." "good"
    return $true
}

function Download-FileWithResume($url, $destination, $expectedSize=0, $label="file") {
    $directory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $maxAttempts = 10

    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $startAt = 0
        if (Test-Path -LiteralPath $destination) {
            try { $startAt = [int64](Get-Item -LiteralPath $destination).Length } catch { $startAt = 0 }
        }

        if ($expectedSize -gt 0 -and $startAt -gt $expectedSize) {
            Write-CCLog "$label partial is larger than the expected archive. Restarting cleanly." "warn"
            Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
            $startAt = 0
        }

        $response = $null
        $stream = $null
        $fileStream = $null
        try {
            $request = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create($url)
            $request.Method = "GET"
            $request.UserAgent = "CyberCircuit-Client/0.3.21"
            $request.Timeout = 30000
            $request.ReadWriteTimeout = 30000
            $request.AllowAutoRedirect = $true
            if ($startAt -gt 0) {
                try { $request.AddRange($startAt) } catch {}
            }

            $response = $request.GetResponse()
            $statusCode = [int]$response.StatusCode
            $contentLength = [int64]$response.ContentLength
            $append = ($startAt -gt 0 -and $statusCode -eq 206)

            if ($startAt -gt 0 -and -not $append) {
                Write-CCLog "$label server did not resume the requested range; restarting from byte 0." "warn"
                $startAt = 0
            }

            if ($append) {
                $fileStream = New-Object System.IO.FileStream($destination, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
                $downloaded = $startAt
            } else {
                $fileStream = New-Object System.IO.FileStream($destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
                $downloaded = 0
            }

            $stream = $response.GetResponseStream()
            $buffer = New-Object byte[] (1024 * 1024)
            $lastLogBytes = $downloaded
            $totalForProgress = if ($expectedSize -gt 0) { $expectedSize } elseif ($append -and $contentLength -gt 0) { $startAt + $contentLength } else { 0 }

            while ($true) {
                $read = $stream.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                $fileStream.Write($buffer, 0, $read)
                $downloaded += $read

                if (($downloaded - $lastLogBytes) -ge (5MB)) {
                    if ($totalForProgress -gt 0) {
                        $pct = [int][Math]::Min(98, [Math]::Max(20, ($downloaded * 100.0 / $totalForProgress)))
                        $progress.Value = $pct
                        $status.Text = "$label download: $downloaded / $totalForProgress bytes"
                    } else {
                        $status.Text = "$label download: $downloaded bytes"
                    }
                    Write-CCLog ("{0}: {1} bytes downloaded." -f $label, $downloaded) "info"
                    $form.Refresh()
                    $lastLogBytes = $downloaded
                }
            }
            $fileStream.Flush()
            if ($expectedSize -gt 0 -and $downloaded -ne $expectedSize) {
                throw "$label download ended at $downloaded bytes; expected $expectedSize bytes."
            }
            Write-CCLog "$label download completed ($downloaded bytes)." "good"
            return
        } catch {
            Write-CCLog "$label download attempt $attempt/$maxAttempts failed: $($_.Exception.Message)" "warn"
            if ($attempt -eq $maxAttempts) { throw "$label download failed after $maxAttempts attempts. The partial file has been kept for retry." }
            Start-Sleep -Seconds ([Math]::Min(5, $attempt))
        } finally {
            if ($stream) { try { $stream.Dispose() } catch {} }
            if ($fileStream) { try { $fileStream.Dispose() } catch {} }
            if ($response) { try { $response.Dispose() } catch {} }
        }
    }
}

function Download-BundledJdk25 {
    $runtimeDir = Join-Path $root "runtime"
    $projectDownloadDir = Join-Path $runtimeDir "downloads"
    $cacheDownloadDir = Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit") "downloads"
    $partial = Join-Path $cacheDownloadDir "temurin-jdk25.zip.partial"
    $finalZip = Join-Path $cacheDownloadDir "temurin-jdk25.zip"
    $projectArchive = Join-Path $projectDownloadDir "temurin-jdk25.zip"
    $stage = $null

    New-Item -ItemType Directory -Force -Path $projectDownloadDir | Out-Null
    New-Item -ItemType Directory -Force -Path $cacheDownloadDir | Out-Null
    $pkg = Get-AdoptiumJdk25Package
    $status.Text = "Preparing Temurin JDK $($pkg.Version)..."
    Write-CCLog "Using official Temurin JDK $($pkg.Version) package." "good"
    Write-CCLog "Expected archive size: $($pkg.Size) bytes." "info"
    Write-CCLog "Expected SHA-256: $($pkg.Checksum)" "info"

    # A completed archive left by a previous attempt can be verified without another download.
    if (Test-Path -LiteralPath $finalZip) {
        if (Verify-JdkArchive $finalZip $pkg.Size $pkg.Checksum) {
            Write-CCLog "Existing complete JDK archive passed verification; skipping download." "good"
        } else {
            Move-ToBadPartial $finalZip "bad-archive"
        }
    }

    if (-not (Test-Path -LiteralPath $finalZip)) {
        if (Test-Path -LiteralPath $partial) {
            $partialSize = (Get-Item -LiteralPath $partial).Length
            if ($partialSize -ge $pkg.Size) {
                Write-CCLog "Partial file is already at least the expected size; validating it before downloading." "warn"
                Move-Item -LiteralPath $partial -Destination $finalZip -Force
                if (-not (Verify-JdkArchive $finalZip $pkg.Size $pkg.Checksum)) {
                    Move-ToBadPartial $finalZip "bad-resume"
                }
            }
        }

        if (-not (Test-Path -LiteralPath $finalZip)) {
            if (Test-Path -LiteralPath $partial) {
                $resumeSize = (Get-Item -LiteralPath $partial).Length
                if ($resumeSize -gt 0) {
                    Write-CCLog "Found an incomplete JDK archive ($resumeSize bytes). Resuming instead of restarting." "warn"
                    $status.Text = "Resuming JDK 25 download..."
                }
            } else {
                $status.Text = "Downloading JDK 25 into the CyberCircuit project..."
            }

            $progress.Value = 20
            $form.Refresh()
            Write-CCLog "Downloading from the official Adoptium package link with native Windows resume + retries." "info"
            try {
                Download-FileWithResume $pkg.Url $partial ([int64]$pkg.Size) "JDK 25"
            } catch {
                $kept = if (Test-Path -LiteralPath $partial) { (Get-Item -LiteralPath $partial).Length } else { 0 }
                Write-CCLog "JDK download failed; partial file kept at $partial ($kept bytes)." "bad"
                throw $_.Exception.Message
            }

            if (-not (Test-Path -LiteralPath $partial)) { throw "The JDK download finished without creating the archive." }
            $size = (Get-Item -LiteralPath $partial).Length
            if ($size -ne $pkg.Size) {
                Write-CCLog "Download stopped with $size bytes; expected $($pkg.Size) bytes. Keeping the partial file." "bad"
                throw "The JDK archive is incomplete. The partial download has been kept for another resume attempt."
            }
            Move-Item -LiteralPath $partial -Destination $finalZip -Force
        }
    }

    $status.Text = "Verifying the JDK archive..."
    $progress.Value = 36
    $form.Refresh()
    if (-not (Verify-JdkArchive $finalZip $pkg.Size $pkg.Checksum)) {
        Move-ToBadPartial $finalZip "checksum-failed"
        # One automatic clean restart protects against a stale partial created by an older installer.
        Write-CCLog "The downloaded archive does not match the current Adoptium release. Starting one clean download." "warn"
        if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue }
        try {
            Download-FileWithResume $pkg.Url $partial ([int64]$pkg.Size) "JDK 25 clean retry"
        } catch {
            Write-CCLog "Clean JDK download failed; partial file was kept." "bad"
            throw "The clean JDK download failed. Check your internet connection and try GET JDK 25 again."
        }
        if (-not (Test-Path -LiteralPath $partial)) { throw "The clean JDK download did not create an archive." }
        if ((Get-Item -LiteralPath $partial).Length -ne $pkg.Size) { throw "The clean JDK download is incomplete; its partial file has been kept." }
        Move-Item -LiteralPath $partial -Destination $finalZip -Force
        if (-not (Verify-JdkArchive $finalZip $pkg.Size $pkg.Checksum)) {
            Move-ToBadPartial $finalZip "checksum-failed-again"
            throw "The JDK archive failed SHA-256 verification twice. The installer kept the failed archive for diagnosis."
        }
    }

    $status.Text = "Extracting and validating JDK 25..."
    $progress.Value = 52
    $form.Refresh()

    # Stage outside OneDrive. The project itself may be under OneDrive, and OneDrive
    # can briefly hold newly-created files/handles while syncing. The final JDK still
    # ends up inside this project's runtime\jdk-25 folder.
    $stage = Join-Path $env:LOCALAPPDATA "CyberCircuit\jdk25-stage"
    if (Test-Path -LiteralPath $stage) {
        try { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop }
        catch { Write-CCLog "Old JDK staging folder could not be fully removed; using a fresh staging path." "warn" }
    }
    try {
        Copy-Item -LiteralPath $finalZip -Destination $projectArchive -Force
        Write-CCLog "Verified JDK archive mirrored into the project runtime\downloads folder." "good"
    } catch {
        Write-CCLog "Could not mirror the JDK ZIP into the OneDrive project; continuing with the verified local cache." "warn"
    }

    $stage = Join-Path $env:LOCALAPPDATA ("CyberCircuit\jdk25-stage-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    Write-CCLog "Extracting JDK 25 into a local staging folder (outside OneDrive)." "info"
    $extracted = $false
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($finalZip, $stage)
        $extracted = $true
        Write-CCLog "JDK archive extracted with the Windows/.NET ZIP extractor." "good"
    } catch {
        Write-CCLog "Primary ZIP extraction failed: $($_.Exception.Message)" "warn"
    }
    if (-not $extracted) {
        try {
            if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Force -Path $stage | Out-Null
            Expand-Archive -LiteralPath $finalZip -DestinationPath $stage -Force
            $extracted = $true
            Write-CCLog "JDK archive extracted with PowerShell Expand-Archive fallback." "good"
        } catch {
            Write-CCLog "PowerShell ZIP extraction failed: $($_.Exception.Message)" "bad"
        }
    }
    if (-not $extracted) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        throw "The JDK archive could not be extracted. The verified download is still kept so GET JDK 25 can retry extraction."
    }

    # Find the JDK directly from its executables. This deliberately does NOT depend on a
    # particular archive top-level folder name or on the release file being immediately available.
    $jdkHome = Find-JdkHomeByExecutables $stage
    if (-not $jdkHome) {
        $top = @(Get-ChildItem -LiteralPath $stage -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        if ($top.Count -gt 0) { Write-CCLog ("Extracted archive top level: " + ($top -join "; ")) "info" }
        $exeSample = @(Get-ChildItem -LiteralPath $stage -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -in @("java.exe","javac.exe") } |
            Select-Object -First 20 -ExpandProperty FullName)
        if ($exeSample.Count -gt 0) { Write-CCLog ("JDK executables found during diagnostic: " + ($exeSample -join "; ")) "good" }
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        throw "CyberCircuit extracted the verified JDK archive but could not validate a matching java.exe + javac.exe pair as Java 25."
    }
    Write-CCLog "Found JDK home from java.exe + javac.exe: $jdkHome" "good"
    if (-not (Test-Jdk25Structure $jdkHome)) {
        throw "The extracted JDK folder does not contain both java.exe and javac.exe."
    }
    if (Test-Jdk25Home $jdkHome) {
        Write-CCLog "Staged java.exe and javac.exe both report Java 25." "good"
    } else {
        throw "The extracted JDK contains java.exe and javac.exe, but the executables did not report Java 25 during validation."
    }

    # Copy the complete JDK instead of moving individual children. This avoids the
    # partial-runtime state that was causing the v16-v18 failures. A separate temporary
    # destination is validated first, then copied into runtime\jdk-25.
    $installTemp = Join-Path $runtimeDir "jdk-25-installing"
    if (Test-Path -LiteralPath $installTemp) { Remove-Item -LiteralPath $installTemp -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $installTemp | Out-Null
    Write-CCLog "Copying the complete JDK into a temporary project runtime folder." "info"

    $robo = Get-Command robocopy.exe -ErrorAction SilentlyContinue
    if ($robo) {
        & $robo.Source $jdkHome $installTemp /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS 2>&1 | ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line) { Write-CCLog $line "info" }
        }
        $rc = $LASTEXITCODE
        if ($rc -ge 8) {
            Remove-Item -LiteralPath $installTemp -Recurse -Force -ErrorAction SilentlyContinue
            throw "Windows robocopy could not copy the complete JDK into the project. Robocopy exit code: $rc"
        }
    } else {
        Copy-Item -LiteralPath (Join-Path $jdkHome '*') -Destination $installTemp -Recurse -Force
    }

    if (-not (Test-Jdk25Structure $installTemp)) {
        Remove-Item -LiteralPath $installTemp -Recurse -Force -ErrorAction SilentlyContinue
        throw "The complete JDK was extracted, but the project copy did not contain both java.exe and javac.exe."
    }

    if (Test-Path -LiteralPath $bundledRuntimeRoot) {
        $backupRuntime = Join-Path $runtimeDir ("jdk-25-old-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        try {
            Move-Item -LiteralPath $bundledRuntimeRoot -Destination $backupRuntime -Force -ErrorAction Stop
            Write-CCLog "Moved the previous incomplete runtime aside: $backupRuntime" "warn"
        } catch {
            Write-CCLog "Could not rename the old runtime folder immediately; will mirror the new JDK over it instead." "warn"
        }
    }
    if (-not (Test-Path -LiteralPath $bundledRuntimeRoot)) {
        Move-Item -LiteralPath $installTemp -Destination $bundledRuntimeRoot -Force
    } else {
        $robo2 = Get-Command robocopy.exe -ErrorAction SilentlyContinue
        if ($robo2) {
            & $robo2.Source $installTemp $bundledRuntimeRoot /E /COPY:DAT /DCOPY:DAT /R:4 /W:1 /NFL /NDL /NJH /NJS 2>&1 | ForEach-Object {
                $line = $_.ToString().Trim()
                if ($line) { Write-CCLog $line "info" }
            }
            $rc2 = $LASTEXITCODE
            if ($rc2 -ge 8) { throw "Windows could not mirror the new JDK over the existing runtime folder. Robocopy exit code: $rc2" }
            Remove-Item -LiteralPath $installTemp -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Copy-Item -LiteralPath (Join-Path $installTemp '*') -Destination $bundledRuntimeRoot -Recurse -Force
            Remove-Item -LiteralPath $installTemp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    # Keep the verified JDK ZIP as a local cache so a future repair does not need another 140 MB download.

    # Final project validation is structural. The actual compiler/runtime test is performed
    # from the local build workspace below, which avoids OneDrive file-lock/sync timing issues.
    if (-not (Test-Jdk25Structure $bundledRuntimeRoot)) {
        throw "JDK 25 was copied into runtime\jdk-25, but the final project structure validation failed."
    }
    Write-CCLog "JDK 25 validated and stored in runtime\jdk-25." "good"
    $progress.Value = 100
    return $bundledRuntimeRoot
}

function Get-GradleRuntime {
    $gradleBat = Join-Path $gradleRuntimeRoot "bin\gradle.bat"
    if (Test-Path -LiteralPath $gradleBat) { return $gradleRuntimeRoot }

    $downloadDir = Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit") "downloads"
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    $tmp = "$gradleArchive.partial"

    if (Test-Path -LiteralPath $gradleArchive) {
        try {
            $cachedHash = (Get-FileHash -LiteralPath $gradleArchive -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($cachedHash -eq $gradleSha256) {
                Write-CCLog "Cached Gradle $gradleVersion archive passed SHA-256 verification." "good"
            } else {
                Write-CCLog "Cached Gradle archive failed SHA-256 verification; replacing it." "warn"
                Remove-Item -LiteralPath $gradleArchive -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Remove-Item -LiteralPath $gradleArchive -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path -LiteralPath $gradleArchive)) {
        Write-CCLog "Gradle $gradleVersion is not present. Downloading the Gradle distribution required by CyberCircuit." "info"
        $status.Text = "Downloading Gradle $gradleVersion..."
        $progress.Value = 28
        $form.Refresh()

        if (Test-Path -LiteralPath $tmp) {
            $partialSize = (Get-Item -LiteralPath $tmp).Length
            Write-CCLog "Found a partial Gradle archive ($partialSize bytes). Resuming instead of restarting." "warn"
        }
        try {
            Download-FileWithResume $gradleDownloadUrl $tmp 0 "Gradle $gradleVersion"
        } catch {
            Write-CCLog "Gradle download was interrupted; the partial archive was kept for the next attempt." "bad"
            throw "Gradle $gradleVersion download failed or was interrupted. The partial download has been kept."
        }
        if (-not (Test-Path -LiteralPath $tmp)) { throw "Gradle download completed without creating its archive." }
        if ((Get-Item -LiteralPath $tmp).Length -le 0) { throw "Gradle download produced an empty archive." }
        $gradleActualHash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($gradleActualHash -ne $gradleSha256) {
            Write-CCLog "Gradle SHA-256 verification failed." "bad"
            Write-CCLog "Expected: $gradleSha256" "bad"
            Write-CCLog "Received: $gradleActualHash" "bad"
            throw "The downloaded Gradle $gradleVersion archive failed SHA-256 verification."
        }
        Write-CCLog "Gradle $gradleVersion SHA-256 verification passed." "good"
        Move-Item -LiteralPath $tmp -Destination $gradleArchive -Force
    }

    $stage = Join-Path $env:LOCALAPPDATA ("CyberCircuit\gradle-stage-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    Write-CCLog "Extracting Gradle $gradleVersion into a local staging folder." "info"
    $extracted = $false
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($gradleArchive, $stage)
        $extracted = $true
        Write-CCLog "Gradle archive extracted successfully." "good"
    } catch {
        try {
            Expand-Archive -LiteralPath $gradleArchive -DestinationPath $stage -Force
            $extracted = $true
            Write-CCLog "Gradle archive extracted with PowerShell fallback." "good"
        } catch {
            Write-CCLog "Gradle extraction failed: $($_.Exception.Message)" "bad"
        }
    }
    if (-not $extracted) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        throw "Gradle $gradleVersion could not be extracted. The archive is kept in runtime\downloads."
    }

    $gradleHome = $null
    try {
        $candidateBat = Get-ChildItem -LiteralPath $stage -Recurse -Filter "gradle.bat" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '\\bin\\gradle\.bat$' } | Select-Object -First 1
        if ($candidateBat) { $gradleHome = Split-Path (Split-Path $candidateBat.FullName -Parent) -Parent }
    } catch {}
    if (-not $gradleHome) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        throw "Gradle $gradleVersion was extracted but its bin\gradle.bat could not be located."
    }

    # IMPORTANT: the destination parent must exist before Move-Item targets the final
    # Gradle runtime path. Windows otherwise reports the vague error
    # "Could not find a part of the path." even though extraction succeeded.
    $gradleRuntimeParent = Split-Path -Parent $gradleRuntimeRoot
    New-Item -ItemType Directory -Force -Path $gradleRuntimeParent | Out-Null
    Write-CCLog "Preparing local Gradle runtime destination: $gradleRuntimeRoot" "info"

    $installTemp = Join-Path $gradleRuntimeParent ("gradle-installing-" + [guid]::NewGuid().ToString("N"))
    if (Test-Path -LiteralPath $installTemp) { Remove-Item -LiteralPath $installTemp -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $installTemp | Out-Null
    $robo = Get-Command robocopy.exe -ErrorAction SilentlyContinue
    if ($robo) {
        & $robo.Source $gradleHome $installTemp /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS 2>&1 | ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line) { Write-CCLog $line "info" }
        }
        if ($LASTEXITCODE -ge 8) {
            Remove-Item -LiteralPath $installTemp -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
            throw "Windows could not copy Gradle $gradleVersion into the CyberCircuit runtime."
        }
    } else {
        Copy-Item -LiteralPath (Join-Path $gradleHome '*') -Destination $installTemp -Recurse -Force
    }
    if (Test-Path -LiteralPath $gradleRuntimeRoot) {
        Write-CCLog "Removing the previous local Gradle $gradleVersion runtime before replacement." "info"
        try { Remove-Item -LiteralPath $gradleRuntimeRoot -Recurse -Force -ErrorAction Stop }
        catch { throw "Could not replace the existing Gradle $gradleVersion runtime because it is locked. Close other CyberCircuit/Gradle windows and try again. Details: $($_.Exception.Message)" }
    }
    Move-Item -LiteralPath $installTemp -Destination $gradleRuntimeRoot -Force -ErrorAction Stop
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue

    $gradleBat = Join-Path $gradleRuntimeRoot "bin\gradle.bat"
    if (-not (Test-Path -LiteralPath $gradleBat)) { throw "Gradle $gradleVersion was installed, but bin\gradle.bat is missing at $gradleBat." }
    Write-CCLog "Gradle $gradleVersion is ready at $gradleRuntimeRoot." "good"
    return $gradleRuntimeRoot
}

function Get-GitHubJson($url) {
    $headers = @{ "User-Agent" = "CyberCircuit-Client/0.3.21"; "Accept" = "application/vnd.github+json" }
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -TimeoutSec 30
    return ($response.Content | ConvertFrom-Json)
}

function Test-FabricModJar($jarPath, $minecraftVersion="26.2") {
    if (-not (Test-Path -LiteralPath $jarPath)) { return $false }
    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)
        $entry = $zip.GetEntry("fabric.mod.json")
        if (-not $entry) { return $false }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        try { $json = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $mod = $json | ConvertFrom-Json
        if (-not $mod.id) { return $false }
        if (-not $mod.depends -or -not $mod.depends.minecraft) { return $true }
        $depText = [string]$mod.depends.minecraft | Out-String
        return ($depText -match [regex]::Escape($minecraftVersion))
    } catch {
        return $false
    } finally {
        if ($zip) { $zip.Dispose() }
    }
}

function Download-ExternalJar($url, $destination, $expectedSha256=$null) {
    $tmp = "$destination.partial"
    try {
        Download-FileWithResume $url $tmp 0 "Companion module"
    } catch {
        throw "Module download failed: $url"
    }
    if (-not (Test-Path -LiteralPath $tmp)) { throw "Module download failed: $url" }
    if ($expectedSha256) {
        $actualModuleHash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualModuleHash -ne ([string]$expectedSha256).ToLowerInvariant()) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            throw "Downloaded module failed SHA-256 verification: $url"
        }
        Write-CCLog "Companion module SHA-256 verification passed." "good"
    }
    if (-not (Test-FabricModJar $tmp "26.2")) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        throw "Downloaded module failed Fabric JAR validation for Minecraft 26.2: $url"
    }
    Move-Item -LiteralPath $tmp -Destination $destination -Force
    return $destination
}

function Get-BaritoneFabricAsset {
    $direct = "https://github.com/cabaletta/baritone/releases/download/v1.19.0/baritone-standalone-fabric-1.19.0.jar"
    try {
        $api = "https://api.github.com/repos/cabaletta/baritone/releases/tags/v1.19.0"
        $release = Get-GitHubJson $api
        $asset = @($release.assets | Where-Object { $_.name -eq 'baritone-standalone-fabric-1.19.0.jar' } | Select-Object -First 1)
        if ($asset) { return $asset[0] }
    } catch {
        Write-CCLog "Baritone release metadata request failed; using the pinned official release URL." "warn"
    }
    return [PSCustomObject]@{ name = 'baritone-standalone-fabric-1.19.0.jar'; browser_download_url = $direct; digest = $null }
}

function Get-Wurst26Asset {
    $assetName = 'Wurst-Client-v7.55.1-MC26.2.jar'
    $direct = "https://github.com/Wurst-Imperium/Wurst-MCX2/releases/download/v7.55.1/$assetName"
    try {
        $api = "https://api.github.com/repos/Wurst-Imperium/Wurst-MCX2/releases/tags/v7.55.1"
        $release = Get-GitHubJson $api
        $asset = @($release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1)
        if ($asset) { return $asset[0] }
        Write-CCLog "Official Wurst 7.55.1 release was found, but its Minecraft 26.2 asset was not listed by the API; using the pinned official asset URL." "warn"
    } catch {
        Write-CCLog "Official Wurst 7.55.1 release metadata request failed; using the pinned Wurst-MCX2 release URL." "warn"
    }
    return [PSCustomObject]@{ name = $assetName; browser_download_url = $direct; digest = $null }
}

function Get-FabricApi26Asset {
    return [PSCustomObject]@{
        name = 'fabric-api-0.158.0+26.2.jar'
        browser_download_url = 'https://maven.fabricmc.net/net/fabricmc/fabric-api/fabric-api/0.158.0+26.2/fabric-api-0.158.0+26.2.jar'
        digest = $null
    }
}

function Install-CompanionModules {
    $modsDir = Join-Path $mcDir "mods"
    $launcherLibrary = Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit") "ModLibrary"
    New-Item -ItemType Directory -Force -Path $modsDir | Out-Null
    New-Item -ItemType Directory -Force -Path $launcherLibrary | Out-Null
    Write-CCLog "Installing 26.2 Fabric companion modules into the Minecraft mods folder." "info"

    $failures = New-Object System.Collections.Generic.List[string]

    try {
        $bar = Get-BaritoneFabricAsset
        $barDest = Join-Path $modsDir "CyberCircuit-Baritone-26.2.jar"
        $barLib = Join-Path $launcherLibrary "CyberCircuit-Baritone-26.2.jar"
        Write-CCLog ("Baritone release asset: " + $bar.name) "good"
        if (Test-Path -LiteralPath $barDest) { Remove-Item -LiteralPath $barDest -Force -ErrorAction SilentlyContinue }
        [void](Download-ExternalJar $bar.browser_download_url $barDest ($bar.digest -replace "^sha256:",""))
        Copy-Item -LiteralPath $barDest -Destination $barLib -Force
        Write-CCLog "Baritone Fabric 26.2 installed and staged in the launcher library." "good"
    } catch {
        $msg = "Baritone installation failed: " + $_.Exception.Message
        [void]$failures.Add($msg); Write-CCLog $msg "bad"
    }

    try {
        $apiAsset = Get-FabricApi26Asset
        $apiDest = Join-Path $modsDir "fabric-api-0.158.0+26.2.jar"
        $apiLib = Join-Path $launcherLibrary "fabric-api-0.158.0+26.2.jar"
        Write-CCLog ("Fabric API asset: " + $apiAsset.name + " (official Fabric Maven)") "good"
        if (Test-Path -LiteralPath $apiDest) { Remove-Item -LiteralPath $apiDest -Force -ErrorAction SilentlyContinue }
        [void](Download-ExternalJar $apiAsset.browser_download_url $apiDest ($apiAsset.digest -replace "^sha256:",""))
        Copy-Item -LiteralPath $apiDest -Destination $apiLib -Force
        Write-CCLog "Fabric API 0.158.0+26.2 installed and staged in the launcher library." "good"
    } catch {
        $msg = "Fabric API installation failed: " + $_.Exception.Message
        [void]$failures.Add($msg); Write-CCLog $msg "bad"
    }

    try {
        $wurst = Get-Wurst26Asset
        $wurstActualName = 'Wurst-Client-v7.55.1-MC26.2.jar'
        $wurstDest = Join-Path $modsDir $wurstActualName
        $wurstLib = Join-Path $launcherLibrary $wurstActualName
        Write-CCLog ("Wurst 26.2 release asset: " + $wurst.name) "good"
        if (Test-Path -LiteralPath $wurstDest) { Remove-Item -LiteralPath $wurstDest -Force -ErrorAction SilentlyContinue }
        [void](Download-ExternalJar $wurst.browser_download_url $wurstDest ($wurst.digest -replace "^sha256:",""))
        Copy-Item -LiteralPath $wurstDest -Destination $wurstLib -Force
        Write-CCLog "Wurst 7.55.1 for Minecraft 26.2 installed and staged in the launcher library." "good"
        Write-CCLog "Wurst remains a separate companion Fabric mod; CyberCircuit does not modify its source." "warn"
    } catch {
        $msg = "Wurst installation failed: " + $_.Exception.Message
        [void]$failures.Add($msg); Write-CCLog $msg "bad"
    }

    if ($failures.Count -gt 0) {
        Write-CCLog ("Companion module installation finished with " + $failures.Count + " failure(s). The 4/4 check will report the exact missing JARs.") "bad"
    }
}

function Verify-FourModuleJars($clientJarName) {
    $modsDir = Join-Path $mcDir "mods"
    $libraryDir = Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit") "ModLibrary"
    $required = [ordered]@{
        "CyberCircuit Client" = @(
            (Join-Path $modsDir "CyberCircuit-Client-26.2.jar"),
            (Join-Path $libraryDir "CyberCircuit-Client-26.2.jar")
        )
        "Baritone" = @(
            (Join-Path $modsDir "CyberCircuit-Baritone-26.2.jar"),
            (Join-Path $libraryDir "CyberCircuit-Baritone-26.2.jar")
        )
        "Fabric API" = @(
            (Join-Path $modsDir "fabric-api-0.158.0+26.2.jar"),
            (Join-Path $libraryDir "fabric-api-0.158.0+26.2.jar")
        )
        "Wurst Client" = @(
            (Join-Path $modsDir "Wurst-Client-v7.55.1-MC26.2.jar"),
            (Join-Path $libraryDir "Wurst-Client-v7.55.1-MC26.2.jar")
        )
    }

    $failed = New-Object System.Collections.Generic.List[string]
    foreach ($name in $required.Keys) {
        $paths = $required[$name]
        foreach ($path in $paths) {
            if (-not (Test-Path -LiteralPath $path)) {
                [void]$failed.Add($name + " missing: " + $path)
                continue
            }
            try {
                $size = (Get-Item -LiteralPath $path -ErrorAction Stop).Length
                if ($size -le 0) { [void]$failed.Add($name + " is empty: " + $path) }
            } catch { [void]$failed.Add($name + " cannot be read: " + $path) }
        }
        $modPath = $paths[0]
        if (Test-Path -LiteralPath $modPath) {
            if (-not (Test-FabricModJar $modPath "26.2")) {
                [void]$failed.Add($name + " failed Fabric 26.2 JAR validation: " + $modPath)
            }
        }
    }

    if ($failed.Count -eq 0) {
        Write-CCLog "Required module check passed: 4/4 JARs are downloaded, present and validated for Minecraft 26.2." "good"
        return $true
    }

    Write-CCLog "Required module check FAILED: 4/4 JARs are not ready." "bad"
    foreach ($item in $failed) { Write-CCLog ("Module check: " + $item) "bad" }
    throw ("The required 4-module JAR check failed. Missing or invalid items:`n- " + [string]::Join("`n- ", $failed.ToArray()))
}

function Set-Jdk25($jdkHome) {
    $script:jdk25 = $jdkHome
    $env:JAVA_HOME = $jdkHome
    $env:Path = (Join-Path $jdkHome 'bin') + ';' + $env:Path
    $java.Text = "JAVA 25  |  JDK READY"
    $java.ForeColor = [Drawing.Color]::FromArgb(55,205,105)
}

# ---------- MODERN GUI ----------
$form = New-Object Windows.Forms.Form
$form.Text = "CyberCircuit Client 26.2"
$form.ClientSize = New-Object Drawing.Size(960,640)
$form.StartPosition = "CenterScreen"
$form.BackColor = [Drawing.Color]::FromArgb(7,9,13)
$form.ForeColor = [Drawing.Color]::White
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.MinimizeBox = $true

$logo = New-Object Windows.Forms.PictureBox
$logo.Location = New-Object Drawing.Point(38,30)
$logo.Size = New-Object Drawing.Size(78,78)
$logo.SizeMode = [Windows.Forms.PictureBoxSizeMode]::Zoom
if (Test-Path $iconPath) { $logo.Image = [Drawing.Image]::FromFile($iconPath) }
$form.Controls.Add($logo)

$title = New-Object Windows.Forms.Label
$title.Text = "CYBERCIRCUIT"
$title.Font = New-Object Drawing.Font("Segoe UI", 29, [Drawing.FontStyle]::Bold)
$title.ForeColor = [Drawing.Color]::FromArgb(88,204,255)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(132,28)
$form.Controls.Add($title)

$sub = New-Object Windows.Forms.Label
$sub.Text = "CLIENT INSTALLER  /  MINECRAFT 26.2"
$sub.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)
$sub.ForeColor = [Drawing.Color]::FromArgb(145,155,170)
$sub.AutoSize = $false
$sub.UseCompatibleTextRendering = $false
$sub.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$sub.Size = New-Object Drawing.Size(420,24)
$sub.Location = New-Object Drawing.Point(135,82)
$form.Controls.Add($sub)

$version = New-Object Windows.Forms.Label
$version.Text = "BUILD 0.3.19  |  v26"
$version.Font = New-Object Drawing.Font("Segoe UI", 8, [Drawing.FontStyle]::Bold)
$version.ForeColor = [Drawing.Color]::FromArgb(55,205,105)
$version.AutoSize = $false
$version.UseCompatibleTextRendering = $false
$version.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$version.Size = New-Object Drawing.Size(240,22)
$version.Location = New-Object Drawing.Point(135,108)
$form.Controls.Add($version)

$card = New-Object Windows.Forms.Panel
$card.Location = New-Object Drawing.Point(38,135)
$card.Size = New-Object Drawing.Size(884,326)
$card.BackColor = [Drawing.Color]::FromArgb(15,19,26)
$form.Controls.Add($card)

$cardTitle = New-Object Windows.Forms.Label
$cardTitle.Text = "INSTALLATION STATUS"
$cardTitle.Font = New-Object Drawing.Font("Segoe UI", 11, [Drawing.FontStyle]::Bold)
$cardTitle.ForeColor = [Drawing.Color]::FromArgb(232,237,244)
$cardTitle.AutoSize = $true
$cardTitle.Location = New-Object Drawing.Point(25,20)
$card.Controls.Add($cardTitle)

function New-StatusLabel($text,$x,$y) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text
    $l.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
    $l.ForeColor = [Drawing.Color]::FromArgb(155,165,178)
    $l.AutoSize = $true
    $l.Location = New-Object Drawing.Point($x,$y)
    $card.Controls.Add($l)
    return $l
}

$java = New-StatusLabel "JAVA 25  |  CHECKING..." 25 62
$mc = New-StatusLabel "MINECRAFT  |  CHECKING..." 25 100
$project = New-StatusLabel "PROJECT  |  READY" 25 138

$javaPathLabel = New-Object Windows.Forms.Label
$javaPathLabel.Font = New-Object Drawing.Font("Segoe UI",8)
$javaPathLabel.ForeColor = [Drawing.Color]::FromArgb(105,115,128)
$javaPathLabel.AutoEllipsis = $true
$javaPathLabel.Size = New-Object Drawing.Size(820,24)
$javaPathLabel.Location = New-Object Drawing.Point(25,174)
$card.Controls.Add($javaPathLabel)

$progress = New-Object Windows.Forms.ProgressBar
$progress.Location = New-Object Drawing.Point(25,215)
$progress.Size = New-Object Drawing.Size(834,12)
$progress.Style = "Continuous"
$progress.Minimum = 0
$progress.Maximum = 100
$card.Controls.Add($progress)

$status = New-Object Windows.Forms.Label
$status.Text = "Ready. CyberCircuit will use its bundled JDK first."
$status.Font = New-Object Drawing.Font("Segoe UI",9)
$status.ForeColor = [Drawing.Color]::FromArgb(170,180,192)
$status.AutoEllipsis = $true
$status.Size = New-Object Drawing.Size(834,38)
$status.Location = New-Object Drawing.Point(25,247)
$card.Controls.Add($status)

$hint = New-Object Windows.Forms.Label
$hint.Text = "Bundled JDK 25  >  installed JDK 25  >  Baritone + Wurst companion modules  >  in-game module manager  >  optional full PC scan"
$hint.Font = New-Object Drawing.Font("Segoe UI",8)
$hint.ForeColor = [Drawing.Color]::FromArgb(92,103,118)
$hint.AutoSize = $true
$hint.Location = New-Object Drawing.Point(25,294)
$card.Controls.Add($hint)

$build = New-CCButton "BUILD  +  INSTALL" 38 495 300 58 $true
$javaBtn = New-CCButton "GET JDK 25" 354 495 190 58 $false
$scan = New-CCButton "SCAN PC" 560 495 150 58 $false
$open = New-CCButton "OPEN PROJECT" 726 495 196 58 $false
$exit = New-CCButton "CLOSE" 38 568 150 40 $false
$reset = New-CCButton "RESET STATUS" 204 568 150 40 $false
$liveLog = New-CCButton "LIVE LOG" 366 568 105 40 $false
$launchApp = New-CCButton "OPEN APP" 480 568 112 40 $false
$form.Controls.AddRange(@($build,$javaBtn,$scan,$open,$exit,$reset,$liveLog,$launchApp))

$pathLabel = New-Object Windows.Forms.Label
$pathLabel.Text = "Project  |  $root"
$pathLabel.Font = New-Object Drawing.Font("Segoe UI",8)
$pathLabel.ForeColor = [Drawing.Color]::FromArgb(82,92,106)
$pathLabel.AutoEllipsis = $true
$pathLabel.Size = New-Object Drawing.Size(300,24)
$pathLabel.Location = New-Object Drawing.Point(615,575)
$form.Controls.Add($pathLabel)
$launcherStatus = New-Object Windows.Forms.Label
$launcherStatus.Text = "Client app  |  not built yet"
$launcherStatus.Font = New-Object Drawing.Font("Segoe UI",8)
$launcherStatus.ForeColor = [Drawing.Color]::FromArgb(82,92,106)
$launcherStatus.AutoEllipsis = $true
$launcherStatus.Size = New-Object Drawing.Size(300,20)
$launcherStatus.Location = New-Object Drawing.Point(615,553)
$form.Controls.Add($launcherStatus)

$existingLauncher = Join-Path $env:LOCALAPPDATA 'CyberCircuit\CyberCircuitLauncher.exe'
$launcherStatus.Text = 'Client app  |  SOURCE READY — BUILD REQUIRED'
$launcherStatus.ForeColor = [Drawing.Color]::FromArgb(255,190,75)

if (Test-Path $mcDir) {
    $mc.Text = "MINECRAFT  |  DETECTED"
    $mc.ForeColor = [Drawing.Color]::FromArgb(55,205,105)
} else {
    $mc.Text = "MINECRAFT  |  NOT FOUND"
    $mc.ForeColor = [Drawing.Color]::FromArgb(245,95,95)
}

$bundled = Find-BundledJdk25
if ($bundled) {
    Set-Jdk25 $bundled
    $javaPathLabel.Text = "JDK source  |  BUNDLED  |  $bundled"
    $status.Text = "Bundled JDK 25 is ready. No PC scan required."
    Write-CCLog "Bundled JDK 25 detected: $bundled" "good"
    $progress.Value = 100
} else {
    $standard = Find-StandardJdk25
    if ($standard) {
        Set-Jdk25 $standard
        $javaPathLabel.Text = "JDK source  |  INSTALLED  |  $standard"
        $status.Text = "System JDK 25 found. The bundled runtime is not present yet."
        Write-CCLog "System JDK 25 detected: $standard" "good"
        $progress.Value = 100
    } else {
        $java.Text = "JAVA 25  |  NOT FOUND"
        $java.ForeColor = [Drawing.Color]::FromArgb(245,95,95)
        $javaPathLabel.Text = "JDK source  |  none found"
        $progress.Value = 0
    }
}

$logForm = New-Object Windows.Forms.Form
$logForm.Text = "CyberCircuit | Live Log"
$logForm.ClientSize = New-Object Drawing.Size(700,360)
$logForm.StartPosition = "CenterParent"
$logForm.BackColor = [Drawing.Color]::FromArgb(7,9,13)
$logForm.ForeColor = [Drawing.Color]::White
$logForm.MinimizeBox = $false
$logForm.MaximizeBox = $false
$logBox = New-Object Windows.Forms.RichTextBox
$logBox.Dock = [Windows.Forms.DockStyle]::Fill
$logBox.BackColor = [Drawing.Color]::FromArgb(10,13,18)
$logBox.ForeColor = [Drawing.Color]::FromArgb(215,220,230)
$logBox.Font = New-Object Drawing.Font("Consolas",9)
$logBox.BorderStyle = [Windows.Forms.BorderStyle]::None
$logBox.ReadOnly = $true
$logBox.DetectUrls = $false
$logForm.Controls.Add($logBox)
$script:logBox = $logBox
$script:launcherStatus = $launcherStatus
Write-CCLog "CyberCircuit Installer v26 started. Java Edition desktop launcher/mod manager support enabled." "good"
Write-CCLog "Bundled JDK 25 has priority over system Java." "info"
Write-CCLog "Installer uses native Windows .NET WebRequest downloads for file transfers. Desktop launcher is built separately and does not require Java/Gradle for day-to-day mod management." "info"
$liveLog.Add_Click({
    if (-not $logForm.Visible) { [void]$logForm.Show($form) } else { $logForm.BringToFront() }
})

$open.Add_Click({ Start-Process explorer.exe $root })
$launchApp.Add_Click({
    try {
        # Always rebuild the launcher from this package before opening it.
        # This prevents an older launcher EXE in %LOCALAPPDATA% from being reused.
        $launcherExe = Build-CyberCircuitLauncher
        Start-Process -FilePath $launcherExe
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "CyberCircuit | Launcher", "OK", "Error") | Out-Null }
})
$exit.Add_Click({ $form.Close() })
$reset.Add_Click({
    $progress.Value = if ($script:jdk25) { 100 } else { 0 }
    $status.Text = if ($script:jdk25) { "JDK 25 ready. Build the client when you're ready." } elseif (Test-Path -LiteralPath (Join-Path $root "runtime\downloads\temurin-jdk25.zip.partial")) { "A partial JDK download is ready to resume." } else { "Ready. Get JDK 25 or scan the PC." }
    $project.Text = "PROJECT  |  READY"
    $project.ForeColor = [Drawing.Color]::FromArgb(155,165,178)
})

$javaBtn.Add_Click({
    $javaBtn.Enabled = $false
    try {
        if (Find-BundledJdk25) {
            Set-Jdk25 (Find-BundledJdk25)
            $javaPathLabel.Text = "JDK source  |  BUNDLED  |  $script:jdk25"
            $status.Text = "Bundled JDK 25 is already installed in the project."
            Write-CCLog "Bundled JDK 25 already installed." "good"
            $progress.Value = 100
        } else {
            $partial = Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit") "downloads") "temurin-jdk25.zip.partial"
            $projectPartial = Join-Path (Join-Path (Join-Path $root "runtime") "downloads") "temurin-jdk25.zip.partial"
            $resumeNote = if ((Test-Path -LiteralPath $partial) -or (Test-Path -LiteralPath $projectPartial)) { "`n`nA partial JDK download already exists and will be resumed." } else { "" }
            $choice = [Windows.Forms.MessageBox]::Show(
                "CyberCircuit can download Temurin JDK 25 directly into this project's runtime folder.`n`nThe download is large and requires internet access.$resumeNote`n`nContinue?",
                "CyberCircuit | Get JDK 25",
                "YesNo",
                "Question"
            )
            if ($choice -eq [Windows.Forms.DialogResult]::Yes) {
                $found = Download-BundledJdk25
                Set-Jdk25 $found
                $javaPathLabel.Text = "JDK source  |  BUNDLED  |  $found"
                $status.Text = "JDK 25 is now stored inside the CyberCircuit project."
                Write-CCLog "JDK 25 installed into the project runtime folder." "good"
                $progress.Value = 100
            }
        }
    } catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "CyberCircuit | JDK 25", "OK", "Error") | Out-Null
        $status.Text = "JDK setup failed."
        Write-CCLog ("JDK setup failed: " + $_.Exception.Message) "bad"
    } finally { $javaBtn.Enabled = $true }
})

$scan.Add_Click({
    $scan.Enabled = $false; $build.Enabled = $false; $javaBtn.Enabled = $false; $open.Enabled = $false
    try {
        $status.Text = "Scanning local drives for a real JDK 25..."
        $progress.Value = 10
        $form.Refresh()
        Write-CCLog "Starting full PC JDK 25 scan." "info"
        $found = Find-Jdk25 -FullScan
        if ($found) {
            Set-Jdk25 $found
            $javaPathLabel.Text = "JDK source  |  SCAN RESULT  |  $found"
            $status.Text = "Found and validated JDK 25."
            Write-CCLog "Full PC scan found a valid JDK 25: $found" "good"
            $progress.Value = 100
        } else {
            $script:jdk25 = $null
            $java.Text = "JAVA 25  |  JDK NOT FOUND"
            $java.ForeColor = [Drawing.Color]::FromArgb(245,95,95)
            $javaPathLabel.Text = "JDK source  |  none found"
            $status.Text = "No complete JDK 25 with java.exe + javac.exe was found."
            Write-CCLog "Full PC scan found no complete JDK 25." "bad"
            if (Test-Path -LiteralPath $bundledRuntimeRoot) {
                Write-CCLog "A runtime\jdk-25 folder exists, but it is incomplete or failed validation." "warn"
            }
            $progress.Value = 0
            [Windows.Forms.MessageBox]::Show("No complete JDK 25 with java.exe + javac.exe was found.`n`nA partial runtime folder does not count as a valid JDK.`n`nUse GET JDK 25 to resume or finish the bundled download.", "CyberCircuit | Java 25 not found", "OK", "Warning") | Out-Null
        }
    } catch {
        Write-CCLog "SCAN FAILED: $($_.Exception.Message)" "bad"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "CyberCircuit | Scan failed", "OK", "Error") | Out-Null
    } finally { $scan.Enabled = $true; $build.Enabled = $true; $javaBtn.Enabled = $true; $open.Enabled = $true }
})

$build.Add_Click({
    $build.Enabled = $false; $javaBtn.Enabled = $false; $scan.Enabled = $false; $open.Enabled = $false; $reset.Enabled = $false
    $progress.Value = 5
    $project.Text = "PROJECT  |  BUILDING..."
    $project.ForeColor = [Drawing.Color]::FromArgb(82,199,255)
    $status.Text = "Preparing build..."
    try {
        try { [void](Build-CyberCircuitLauncher) } catch { Write-CCLog ('Launcher application build warning: ' + $_.Exception.Message) 'warn' }
        try {
            Write-CCLog 'Preparing Baritone and Wurst companion modules independently of the client build.' 'info'
            Install-CompanionModules
        } catch { Write-CCLog ('Companion-module preparation warning: ' + $_.Exception.Message) 'warn' }
        $bundled = Find-BundledJdk25
        if ($bundled) {
            Set-Jdk25 $bundled
            $javaPathLabel.Text = "JDK source  |  BUNDLED  |  $bundled"
        } elseif (-not $script:jdk25 -or -not (Test-Jdk25Home $script:jdk25)) {
            $status.Text = "No bundled JDK 25 found."
            $progress.Value = 10
            $form.Refresh()
            $choice = [Windows.Forms.MessageBox]::Show(
                "CyberCircuit does not currently have a usable JDK 25.`n`nYES = download JDK 25 into this project.`nNO = ask permission to scan every local drive.",
                "CyberCircuit | JDK 25 required",
                "YesNo",
                "Question"
            )
            if ($choice -eq [Windows.Forms.DialogResult]::Yes) {
                $found = Download-BundledJdk25
                Set-Jdk25 $found
                $javaPathLabel.Text = "JDK source  |  BUNDLED  |  $found"
            } else {
                $choice2 = [Windows.Forms.MessageBox]::Show(
                    "A full PC scan can take several minutes.`n`nScan all local drives for javac.exe?",
                    "CyberCircuit | Full Java Scan",
                    "YesNo",
                    "Question"
                )
                if ($choice2 -ne [Windows.Forms.DialogResult]::Yes) { throw "JDK 25 is required. Use GET JDK 25, then run BUILD + INSTALL again." }
                $status.Text = "Scanning the PC for a real JDK 25..."
                $progress.Value = 12
                $form.Refresh()
                $found = Find-Jdk25 -FullScan
                if (-not $found) { throw "No JDK 25 with javac.exe was found. Use GET JDK 25 to install one into the project." }
                Set-Jdk25 $found
                $javaPathLabel.Text = "JDK source  |  SCAN RESULT  |  $found"
            }
        }

        if (-not (Test-Jdk25Structure $script:jdk25)) { throw "The selected Java installation does not contain a complete JDK 25." }
        if (-not (Test-Path $mcDir)) { throw "Minecraft folder was not found at:`n$mcDir" }

        # Bootstrap Gradle before making the local build copy so the local build workspace
        # receives both bundled runtimes and can stay completely out of OneDrive.
        $gradleHome = Get-GradleRuntime

        # Always build from a fresh LocalAppData workspace. Never delete the previous
        # workspace: this is deliberate because Gradle/Norton/OneDrive can still hold a
        # jar open for a short time after a previous build. A fresh workspace means there is
        # nothing for the installer to clear, so a locked gradle-instrumentation-agent jar
        # cannot block the next build.
        $buildBase = Join-Path $env:LOCALAPPDATA "CyberCircuit\Builds"
        New-Item -ItemType Directory -Force -Path $buildBase | Out-Null
        $localRoot = Join-Path $buildBase ("Client-26.2-" + (Get-Date -Format "yyyyMMdd-HHmmss-fff") + "-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        $status.Text = "Preparing an isolated local build..."
        Write-CCLog "Creating a fresh local build workspace outside OneDrive: $localRoot" "info"
        New-Item -ItemType Directory -Force -Path $localRoot | Out-Null

        $roboProject = Get-Command robocopy.exe -ErrorAction SilentlyContinue
        if ($roboProject) {
            # Never copy old Gradle state or build output into the new workspace. The build
            # will generate both from scratch.
            $excludeDirs = @(
                (Join-Path $root "runtime\downloads"),
                (Join-Path $root "runtime\jdk-25-installing"),
                (Join-Path $root ".gradle"),
                (Join-Path $root "build")
            )
            & $roboProject.Source $root $localRoot /E /COPY:DAT /DCOPY:DAT /R:3 /W:1 /XJ /NFL /NDL /NJH /NJS /XD $excludeDirs 2>&1 | ForEach-Object {
                $line = $_.ToString().Trim(); if ($line) { Write-CCLog ("Project copy: " + $line) "info" }
            }
            $rcProject = $LASTEXITCODE
            if ($rcProject -ge 8) { throw "Windows could not create the local CyberCircuit build workspace. Robocopy exit code: $rcProject" }
        } else {
            Copy-Item -LiteralPath (Join-Path $root '*') -Destination $localRoot -Recurse -Force
        }

        # Copy only the complete bundled JDK into the local workspace. Gradle is kept in
        # its separate LocalAppData runtime and is invoked from there.
        $localRuntime = Join-Path $localRoot "runtime"
        New-Item -ItemType Directory -Force -Path $localRuntime | Out-Null
        $localJdkRoot = Join-Path $localRuntime "jdk-25"
        $roboJdk = Get-Command robocopy.exe -ErrorAction SilentlyContinue
        if ($roboJdk) {
            & $roboJdk.Source $script:jdk25 $localJdkRoot /E /COPY:DAT /DCOPY:DAT /R:3 /W:1 /XJ /NFL /NDL /NJH /NJS 2>&1 | ForEach-Object {
                $line = $_.ToString().Trim(); if ($line) { Write-CCLog ("JDK copy: " + $line) "info" }
            }
            $rcJdk = $LASTEXITCODE
            if ($rcJdk -ge 8) { throw "Windows could not copy the bundled JDK into the local build workspace. Robocopy exit code: $rcJdk" }
        } else {
            Copy-Item -LiteralPath (Join-Path $script:jdk25 '*') -Destination $localJdkRoot -Recurse -Force
        }
        $buildRoot = $localRoot

        # The build uses the verified JDK directly from the local workspace (when OneDrive
        # is involved) and the isolated Gradle runtime from LocalAppData. This avoids a
        # second, fragile Gradle copy and prevents the earlier missing-path failure.
        $buildJdk = Find-JdkHomeInTree (Join-Path $buildRoot "runtime")
        if (-not $buildJdk) { throw "The bundled JDK 25 could not be found inside the build workspace: $(Join-Path $buildRoot 'runtime\jdk-25')" }
        Write-CCLog "Build workspace JDK candidate: $buildJdk" "good"
        if (-not (Test-Jdk25Home $buildJdk)) {
            throw "The bundled JDK 25 is present, but java.exe/javac.exe failed the final version check in the local build workspace."
        }
        Set-Jdk25 $buildJdk
        $javaPathLabel.Text = "JDK source  |  BUNDLED  |  $script:jdk25"
        Write-CCLog "Using bundled JDK 25 from the build workspace." "good"
        $env:JAVA_HOME = $script:jdk25
        $env:Path = (Join-Path $script:jdk25 'bin') + ';' + $env:Path

        # Keep using the isolated Gradle runtime returned by Get-GradleRuntime. It lives
        # outside OneDrive by design, so there is no missing-project-path dependency here.
        $gradleBat = Join-Path $gradleHome "bin\gradle.bat"
        if (-not (Test-Path -LiteralPath $gradleBat)) { throw "The isolated Gradle $gradleVersion runtime is missing its executable: $gradleBat" }
        # Prevent two CyberCircuit builds from sharing Gradle's Windows file locks.
        $script:buildMutex = New-Object System.Threading.Mutex($false, "Local\CyberCircuit-Client-26.2-Build")
        if (-not $script:buildMutex.WaitOne(0)) {
            throw "Another CyberCircuit build is already running. Close the other installer/build window and try again."
        }

        $env:GRADLE_USER_HOME = Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit\GradleUserHome") ([guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
        $progress.Value = 20
        $status.Text = "Starting Gradle / Fabric Loom with JDK 25..."
        Write-CCLog "Starting Gradle / Fabric Loom with JDK 25." "info"
        Write-CCLog "Using local Gradle distribution: $gradleHome" "good"
        Write-CCLog "Gradle daemon disabled; each build gets an isolated Gradle user home to reduce Windows/Norton jar-lock conflicts." "good"
        Push-Location $buildRoot
        & $gradleBat '--no-daemon' '--no-parallel' '--no-watch-fs' '-Dorg.gradle.internal.instrumentation.agent=false' '-Dorg.gradle.vfs.watch=false' 'build' 2>&1 | ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line) {
                $safe = if ($line.Length -gt 100) { $line.Substring(0,100) } else { $line }
                $status.Text = $safe
                if ($line -match "(FAILURE|FAILED|ERROR|Exception|Could not|Unable|error:)" ) { Write-CCLog $line "bad" } elseif ($line -match "(BUILD SUCCESSFUL|BUILDING|Downloading|Compiling|Processing|SUCCESS|UP-TO-DATE|> Task)" ) { Write-CCLog $line "good" } else { Write-CCLog $line "info" }
                $form.Refresh()
            }
        }
        $code = $LASTEXITCODE
        Pop-Location
        if ($script:buildMutex) {
            try { [void]$script:buildMutex.ReleaseMutex() } catch {}
            $script:buildMutex.Dispose()
            $script:buildMutex = $null
        }
        if ($code -ne 0) { throw "Gradle build failed. The Live Log contains the complete Gradle/Fabric output." }

        $jar = Get-ChildItem (Join-Path $buildRoot "build\libs") -Filter "*.jar" |
            Where-Object { $_.Name -notlike "*-sources.jar" } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $jar) { throw "Build completed but no client JAR was found." }
        $mods = Join-Path $mcDir "mods"
        $launcherLibrary = Join-Path (Join-Path $env:LOCALAPPDATA "CyberCircuit") "ModLibrary"
        New-Item -ItemType Directory -Force -Path $mods | Out-Null
        New-Item -ItemType Directory -Force -Path $launcherLibrary | Out-Null

        # Use a stable CyberCircuit filename so the launcher can always find the core
        # client regardless of the Gradle archive/version filename.
        $coreJarName = "CyberCircuit-Client-26.2.jar"
        $coreModsPath = Join-Path $mods $coreJarName
        $coreLibraryPath = Join-Path $launcherLibrary $coreJarName
        Copy-Item -LiteralPath $jar.FullName -Destination $coreModsPath -Force
        Copy-Item -LiteralPath $jar.FullName -Destination $coreLibraryPath -Force
        if (-not (Test-Path -LiteralPath $coreModsPath) -or (Get-Item -LiteralPath $coreModsPath).Length -le 0) {
            throw "CyberCircuit core JAR could not be installed into the Minecraft mods folder. Security software may have removed or locked the file."
        }
        if (-not (Test-FabricModJar $coreModsPath "26.2")) {
            throw "CyberCircuit core JAR was copied, but its Fabric 26.2 metadata could not be validated."
        }
        Write-CCLog ("CyberCircuit core client installed as " + $coreJarName + " (source build: " + $jar.Name + ").") "good"
        Write-CCLog "CyberCircuit core client staged in the desktop launcher mod library." "good"

        # Companion modules are installed after the main client so the build result remains
        # usable even if a third-party download is unavailable.
        Install-CompanionModules
        Verify-FourModuleJars $jar.Name

        $progress.Value = 100
        $project.Text = "PROJECT  |  INSTALLED"
        $project.ForeColor = [Drawing.Color]::FromArgb(55,205,105)
        $status.Text = "Installed $($jar.Name) into Minecraft mods."
        Write-CCLog "Installed $($jar.Name) into Minecraft mods." "good"
        [Windows.Forms.MessageBox]::Show("CyberCircuit Client is installed.`n`nBaritone and Wurst companion modules were also checked/installed when available.`n`nOpen CyberCircuit Client from the desktop shortcut or the OPEN APP button. In the app, toggle modules, click APPLY TO MINECRAFT, then use PLAY or APPLY + LAUNCH; the app manages the JAR files in .minecraft\mods before the game starts.", "CyberCircuit Client | Installed", "OK", "Information") | Out-Null
    } catch {
        if ($script:buildMutex) {
            try { [void]$script:buildMutex.ReleaseMutex() } catch {}
            try { $script:buildMutex.Dispose() } catch {}
            $script:buildMutex = $null
        }
        $project.Text = "PROJECT  |  BUILD FAILED"
        $project.ForeColor = [Drawing.Color]::FromArgb(245,95,95)
        $status.Text = "Build failed. See the message for details."
        Write-CCLog "BUILD FAILED: $($_.Exception.Message)" "bad"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "CyberCircuit | Build failed", "OK", "Error") | Out-Null
    } finally {
        $build.Enabled = $true; $javaBtn.Enabled = $true; $scan.Enabled = $true; $open.Enabled = $true; $reset.Enabled = $true
    }
})

[void]$form.ShowDialog()
