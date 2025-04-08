function makedata {
    # ���ɲ��������ļ�
    param (
        [string]$outputPrefix = "default",
        [int]$tot = 15
    )

    $output = "$outputPrefix-data.txt"
    $content = @("[demo]", "$outputPrefix-demo.exe", "[tot]", "$tot", "")
    foreach ($i in 1..$tot) {
        $content += "[$i]"
        $content += ""
        $content += ""
    }
    [System.IO.File]::WriteAllLines($output, $content)
    Write-Host "�����ɲ������� $output��" -ForegroundColor Green
    code $output
}

function ensuredir {
    # ȷ��Ŀ¼���ڣ�����������򴴽�
    param (
        [string]$dirPath
    )
    if (-not (Test-Path $dirPath)) {
        New-Item -Path $dirPath -ItemType Directory | Out-Null
    }
}

function compvc {
    # ʹ�� VC ���������� C++ �ļ�
    param (
        [string]$inputFile,
        [string]$outputFile = "debug/dump/ownvc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "ʹ�� VC ���� $inputFile �� $outputFile" -ForegroundColor DarkGray
    ensuredir "debug"
    ensuredir "debug/dump"
    $sourceCharset = if ($srcgbk) { "gbk" } else { "UTF-8" }

    # cl ��һ�л�����ļ���������
    if ($ignoreWarnings) {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX- /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Select-Object -Skip 1 | Out-Default
    }
    else {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Select-Object -Skip 1 | Out-Default
    }
    $vcError = $LASTEXITCODE

    if ($vcError -eq 0) {
        Remove-Item *.obj -Force
    }
    else {
        if ($ignoreWarnings) {
            Write-Host "VC �����д���" -ForegroundColor Red
        }
        else {
            Write-Host "VC �����о�������" -ForegroundColor Red
        }
    }
    return $vcError
}

function compgcc {
    # ʹ�� GCC ���������� C++ �ļ�
    param (
        [string]$inputFile,
        [string]$outputFile = "debug/dump/owngcc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "ʹ�� GCC ���� $inputFile �� $outputFile" -ForegroundColor DarkGray
    ensuredir "debug"
    ensuredir "debug/dump"
    $inputCharset = if ($srcgbk) { "GBK" } else { "UTF-8" }
    if ($ignoreWarnings) {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk | Out-Default
    }
    else {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk -Werror | Out-Default
    }
    $gccError = $LASTEXITCODE

    if ($gccError -ne 0) {
        if ($ignoreWarnings) {
            Write-Host "GCC �����д���" -ForegroundColor Red
        }
        else {
            Write-Host "GCC �����о�������" -ForegroundColor Red
        }
    }
    return $gccError
}

function runvc {
    # �������� VC
    param (
        [string]$ownCpp
    )

    $ownVcExe = "debug/dump/ownvc.exe"
    $vcError = compvc -inputFile $ownCpp -outputFile $ownVcExe -ignoreWarnings
    Write-Host ""
    if ($vcError -eq 0) {
        & .\$ownVcExe
    }
}

function rungcc {
    # �������� GCC
    param (
        [string]$ownCpp
    )
    $ownGccExe = "debug/dump/owngcc.exe"
    $gccError = compgcc -inputFile $ownCpp -outputFile $ownGccExe -ignoreWarnings
    Write-Host ""
    if ($gccError -eq 0) {
        & .\$ownGccExe
    }
}

function owngcc {
    # ���� GCC ����
    if (-not (Test-Path "debug/dump/owngcc.exe")) {
        Write-Host "δ�ҵ� debug/dump/owngcc.exe�����ȱ��롣" -ForegroundColor Red
        return
    }
    else {
        & "debug/dump/owngcc.exe"
    }
}

function ownvc {
    # ���� VC ����
    if (-not (Test-Path "debug/dump/ownvc.exe")) {
        Write-Host "δ�ҵ� debug/dump/ownvc.exe�����ȱ��롣" -ForegroundColor Red
        return
    }
    else {
        & "debug/dump/ownvc.exe"
    }
}

function test {
    # ��������
    # eg test 4-b2 -2.cpp
    # eg test 4-b2 .c -chkout
    param (
        [string]$dataSrcPrefix, # �����ļ�ǰ׺
        [string]$ownCpp, # Դ�ļ�
        [switch]$chkout
    )
    $ownCpp = "$dataSrcPrefix$ownCpp"
    if ($chkout) {
        $ownCpp = "output/$ownCpp"
    }
    $dataSrc = "$dataSrcPrefix-data.txt"
    $dataPrefix = ""
    $ownGccExe = "debug/dump/owngcc.exe"
    $ownVcExe = "debug/dump/ownvc.exe"
    $gccResPath = "debug/dump/resgcc.txt"
    $vcResPath = "debug/dump/resvc.txt"
    $demoResPath = "debug/dump/resdemo.txt"

    $gccConflictPath = "debug/conflictgcc.txt"
    $vcConflictPath = "debug/conflictvc.txt"
    $demoConflictPath = "debug/conflictdemo.txt"

    $dataNum = & getinput $dataSrc "[tot]"
    if (-not $dataNum) { $dataNum = 0 }

    if ($dataNum -ne 0) {
        $demoExe = & getinput $dataSrc "[demo]"
        Write-Host "ʹ�� demo ���� $demoExe���������� $dataNum��"
        $trim = & getinput $dataSrc "[trim]" 2>$null
        $maxlineStr = & getinput $dataSrc "[maxline]" 2>$null
        if ($maxlineStr) {
            $maxline = [int]$maxlineStr
            if ($maxline -le 0) {
                $maxline = 0
            }
        }
        else {
            $maxline = 0
        }
    }
    else {
        Write-Host "δ��ȡ�����ݡ������벻�ȶԡ�"
    }

    $gccErr = compgcc -inputFile $ownCpp -outputFile $ownGccExe -srcgbk:($chkout)
    $vcErr = compvc -inputFile $ownCpp -outputFile $ownVcExe -srcgbk:($chkout)

    if ($gccErr -ne 0 -or $vcErr -ne 0) { return }
    if ($dataNum -eq 0) {
        Write-Host "����ͨ����`n" -ForegroundColor Green
        return
    }

    "" | Out-File $gccResPath
    "" | Out-File $vcResPath
    "" | Out-File $demoResPath

    $barWidth = 45  # ���������
    Write-Host -NoNewline ""

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $resultTitle = "����ʱ��  $time`n�����ļ�  $ownCpp`n����Դ    $dataSrc`n����      $dataNum`n"
    $demoOutputs = @($resultTitle)
    $vcOutputs = @($resultTitle)
    $gccOutputs = @($resultTitle)

    $demoConflicts = @($resultTitle)
    $vcConflicts = @($resultTitle)
    $gccConflicts = @($resultTitle)

    $conflictCount = 0
    $vcgccdiff = $false
    for ($i = 1; $i -le $dataNum; $i++) {
        $inputData = & getinput $dataSrc "[$dataPrefix$i]"

        $demoSigleArr = $inputData | & "./$demoExe" 2>&1
        $vcSingleArr = $inputData | & "./$ownVcExe" 2>&1
        $gccSingleArr = $inputData | & "./$ownGccExe" 2>&1

        if ($trim -eq "right") {
            $demoSigleArr = ($demoSigleArr | ForEach-Object { $_.TrimEnd() })
            $vcSingleArr = ($vcSingleArr | ForEach-Object { $_.TrimEnd() })
            $gccSingleArr = ($gccSingleArr | ForEach-Object { $_.TrimEnd() })
        }
        if ($maxline) {
            $demoSigleArr = $demoSigleArr | Select-Object -First $maxline
            $vcSingleArr = $vcSingleArr | Select-Object -First $maxline
            $gccSingleArr = $gccSingleArr | Select-Object -First $maxline
        }

        $demoSigle = $demoSigleArr -join "`n"
        $vcSingle = $vcSingleArr -join "`n"
        $gccSingle = $gccSingleArr -join "`n"

        $demoOutputs += "[$i]"
        $demoOutputs += $demoSigle
        $vcOutputs += "[$i]"
        $vcOutputs += $vcSingle
        $gccOutputs += "[$i]"
        $gccOutputs += $gccSingle

        if ($demoSigle -ne $vcSingle -or $demoSigle -ne $gccSingle) {
            $conflictCount++
            $demoConflicts += "[$i Input]"
            $demoConflicts += $inputData
            $demoConflicts += "[$i Output]"
            $demoConflicts += $demoSigle

            $vcConflicts += "[$i Input]"
            $vcConflicts += $inputData
            $vcConflicts += "[$i Output]"
            $vcConflicts += $vcSingle

            $gccConflicts += "[$i Input]"
            $gccConflicts += $inputData
            $gccConflicts += "[$i Output]"
            $gccConflicts += $gccSingle

            if ($vcSingle -ne $gccSingle) {
                $vcgccdiff = $true
            }
        }

        $percent = [math]::Round(($i / $dataNum) * 100)
        $filled = [math]::Round(($i / $dataNum) * $barWidth)
        $empty = $barWidth - $filled
        if ($conflictCount -ne 0) {
            $conflict = [math]::Round(($conflictCount / $dataNum) * $barWidth)
            $filled = $filled - $conflict
            Write-Host -NoNewline "`r["
            $redbar = ("=" * $conflict)
            $normalbar = ("=" * $filled) + (" " * $empty) + "] $percent%"
            Write-Host -NoNewline $redbar -ForegroundColor Red
            Write-Host -NoNewline $normalbar
        }
        else {
            $bar = "[" + ("=" * $filled) + (" " * $empty) + "] $percent%"
            Write-Host -NoNewline "`r$bar"
        }
        [Console]::Out.Flush()
    }

    [System.IO.File]::WriteAllLines($gccResPath, $gccOutputs)
    [System.IO.File]::WriteAllLines($vcResPath, $vcOutputs)
    [System.IO.File]::WriteAllLines($demoResPath, $demoOutputs)

    if ($trim -eq "right") {
        $compareConfig = "������β�ո�ƥ��"
    }
    else {
        $compareConfig = "��ȫƥ��"
    }
    if ($maxline) {
        $compareConfig += "ǰ $maxline ��"
    }

    if ($conflictCount -ne 0) {
        [System.IO.File]::WriteAllLines($gccConflictPath, $gccConflicts)
        [System.IO.File]::WriteAllLines($vcConflictPath, $vcConflicts)
        [System.IO.File]::WriteAllLines($demoConflictPath, $demoConflicts)

        Write-Host "`n������ϡ�$compareConfig���� $conflictCount ���ͻ��" -ForegroundColor Yellow
        if ($vcgccdiff) {
            code --diff $demoConflictPath $vcConflictPath
            code --diff $demoConflictPath $gccConflictPath
            Write-Host "GCC �� VC �����һ�¡����������ȶԡ�" -ForegroundColor Red
        }
        else {
            code --diff $demoConflictPath $vcConflictPath
            Write-Host "�����ȶԡ�" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`n������ϡ�$compareConfig���޳�ͻ��" -ForegroundColor Green
    }
    Write-Host ""
}

function pack {
    # ����ļ��� ./source �ļ���
    if (Test-Path "./source") {
        Write-Host "����./source �ļ����Ѵ��ڣ�" -ForegroundColor Red
        return
    }

    New-Item -Path "./source" -ItemType Directory | Out-Null
    Move-Item -Path *-data.txt, *-demo.exe, *.cpp, *.c -Destination "./source" -ErrorAction SilentlyContinue
    Write-Host "�ļ����ƶ��� ./source �ļ��С�" -ForegroundColor Green
}

function unpack {
    # ����ļ�����ǰĿ¼
    if (-not (Test-Path "./source")) {
        Write-Host "����./source �ļ��в����ڣ�" -ForegroundColor Red
        return
    }
    Move-Item -Path "./source/*-data.txt", "./source/*-demo.exe", "./source/*.cpp", "./source/*.c" -Destination "./" -ErrorAction SilentlyContinue
    Remove-Item -Path "./source" -Force
    Write-Host "./source �ѽ����" -ForegroundColor Green
}

function listcolors {
    $colors = [enum]::GetValues([System.ConsoleColor])
    Foreach ($bgcolor in $colors) {
        Foreach ($fgcolor in $colors) { Write-Host "$fgcolor|"  -ForegroundColor $fgcolor -BackgroundColor $bgcolor -NoNewLine }
        Write-Host " on $bgcolor"
    }
}

function format {
    & tjformat . -c .utils/tjformat.json5
    $targetFolder = "./output"
    Get-ChildItem -Path $targetFolder -Directory -Recurse |
    Where-Object {
        # ����ļ����Ƿ�Ϊ��
        @(Get-ChildItem -Path $_.FullName -Force).Count -eq 0
    } |
    Remove-Item -Force
}

$installkey = & Get-Content "./.utils/.vsinstallkey" 2>$null
if (-not $installkey) {
    # û����ǰ���ã����Դӿ�ݷ�ʽ����ȡ
    $shell = New-Object -ComObject WScript.Shell
    $shortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Visual Studio 2022\Visual Studio Tools\Developer PowerShell for VS 2022.lnk"
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $target = $shortcut.TargetPath
    $arguments = $shortcut.Arguments
    $fullCommand = "$target $arguments"
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
    if ($fullCommand -match 'Enter-VsDevShell\s+([a-f0-9]+)') {
        $installkey = $matches[1]
        Write-Output "δ�ҵ� .vsinstallkey���Ѵӿ�ݷ�ʽ���Զ���ȡ��"
        Write-Output $installkey | Out-File -FilePath "./.utils/.vsinstallkey" -Encoding utf8
    }
    else {
        # ���Դ� VS ʵ���ļ�������ȡ
        $instancePath = "C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances"
        $instanceFolders = Get-ChildItem -Path $instancePath -Directory
        $targetFolder = $instanceFolders | Where-Object { $_.Name.Length -eq 8 }
        if ($targetFolder.Count -eq 1) {
            $installkey = $targetFolder.Name
            Write-Output "δ�ҵ� .vsinstallkey���Ѵ� VS ʵ���ļ������Զ���ȡ��"
            Write-Output $installkey | Out-File -FilePath "./.utils/.vsinstallkey" -Encoding utf8
        }
        else {
            # ���ˣ���ʾ�ֶ�����
            Write-Host "δ�ҵ���װ key������ .utils/.vsinstallkey �ļ���" -ForegroundColor Red
            code ./.utils/.vsinstallkey
            Write-Host "������� Developer PowerShell for VS 2022 �Ŀ�ݷ�ʽ���ն������ļ����ҵ���"
            Write-Host "����һ�� 8 λ 16 ���������������� .vsinstallkey �ļ��У�Ȼ�����������նˡ�"
            return
        }
    }
}

Write-Host "���ڼ��� VC++ ���� ($installkey)"
Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell $installkey -SkipAutomaticLocation -DevCmdArguments "-arch=x86 -host_arch=x64" | Out-Null

Write-Host "����װ����ɡ�`n" -ForegroundColor Green
