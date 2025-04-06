Write-Host "���ڼ��� VC++ ����..."
Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell 8825af93 -SkipAutomaticLocation -DevCmdArguments "-arch=x86 -host_arch=x64" | Out-Null

function makedata {
    # ���ɲ��������ļ�
    param (
        [string]$outputPrefix = "default",
        [int]$tot = 10
    )

    $output = "$outputPrefix-data.txt"

    $content = @("[demo]", "$outputPrefix-demo.exe", "[tot]", "$tot", "")
    foreach ($i in 1..$tot) {
        $content += "[$i]"
        $content += ""
        $content += ""
    }
    [System.IO.File]::WriteAllLines($output, $content)

    Write-Host "��ɡ�" -ForegroundColor Green

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
        [string]$outputFile = "debug/ownvc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "ʹ�� VC ���� $inputFile �� $outputFile" -ForegroundColor DarkBlue
    ensuredir "debug"
    $sourceCharset = if ($srcgbk) { "gbk" } else { "UTF-8" }
    if ($ignoreWarnings) {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX- /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Out-Default
    }
    else {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Out-Default
    }
    $vcError = $LASTEXITCODE

    if ($vcError -eq 0) {
        Remove-Item *.obj -Force
    }
    else {
        if ($ignoreWarnings) {
            Write-Host "VC �����д���" -ForegroundColor Red
        } else {
            Write-Host "VC �����о�������" -ForegroundColor Red
        }
    }
    return $vcError
}

function compgcc {
    # ʹ�� GCC ���������� C++ �ļ�
    param (
        [string]$inputFile,
        [string]$outputFile = "debug/owngcc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "ʹ�� GCC ���� $inputFile �� $outputFile" -ForegroundColor DarkBlue
    ensuredir "debug"
    $inputCharset = if ($srcgbk) { "GBK" } else { "UTF-8" }
    if ($ignoreWarnings) {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk | Out-Default
    }
    else {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk -Werror | Out-Default
    }
    $gccError = $LASTEXITCODE

    if ($gccError -ne 0) {
        if($ignoreWarnings) {
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

    $ownVcExe = "debug/ownvc.exe"
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
    $ownGccExe = "debug/owngcc.exe"
    $gccError = compgcc -inputFile $ownCpp -outputFile $ownGccExe -ignoreWarnings
    Write-Host ""
    if ($gccError -eq 0) {
        & .\$ownGccExe
    }
}

function owngcc {
    # ���� GCC ����
    if (-not (Test-Path "debug/owngcc.exe")) {
        Write-Host "δ�ҵ� debug/owngcc.exe�����ȱ��롣" -ForegroundColor Red
        return
    }
    else {
        & "debug/owngcc.exe"
    }
}

function ownvc {
    # ���� VC ����
    if (-not (Test-Path "debug/ownvc.exe")) {
        Write-Host "δ�ҵ� debug/ownvc.exe�����ȱ��롣" -ForegroundColor Red
        return
    }
    else {
        & "debug/ownvc.exe"
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
    $ownGccExe = "debug/owngcc.exe"
    $ownVcExe = "debug/ownvc.exe"
    $ownGccRes = "debug/resgcc.txt"
    $ownVcRes = "debug/resvc.txt"
    $demoRes = "debug/resdemo.txt"

    $dataNum = & getinput $dataSrc "[tot]"
    if (-not $dataNum) { $dataNum = 0 }

    if ($dataNum -ne 0) {
        Write-Host "��ȡ�� $dataNum �����ݡ�"
        $demoExe = & getinput $dataSrc "[demo]"
        Write-Host "ʹ�� demo ���� $demoExe��"
    }
    else {
        Write-Host "δ��ȡ�����ݡ������벻�ȶԡ�"
    }

    Write-Host "�����ļ���$ownCpp"

    $gccErr = compgcc -inputFile $ownCpp -outputFile $ownGccExe -srcgbk:($chkout)
    if ($gccErr -eq 0) {
        Write-Host "GCC ����ͨ����" -ForegroundColor Green
    }

    $vcErr = compvc -inputFile $ownCpp -outputFile $ownVcExe -srcgbk:($chkout)
    if ($vcErr -eq 0) {
        Write-Host "VC ����ͨ����" -ForegroundColor Green
    }

    if ($dataNum -eq 0) { return }

    if ($gccErr -ne 0 -or $vcErr -ne 0) { return }

    "" | Out-File $ownGccRes
    "" | Out-File $ownVcRes
    "" | Out-File $demoRes

    $barWidth = 45  # ���������
    Write-Host -NoNewline "����: "

    for ($i = 1; $i -le $dataNum; $i++) {
        $percent = [math]::Round(($i / $dataNum) * 100)
        $filled = [math]::Round(($i / $dataNum) * $barWidth)
        $empty = $barWidth - $filled
        $bar = "[" + ("=" * $filled) + (" " * $empty) + "] $percent%"

        Write-Host -NoNewline "`r����: $bar"  # ʹ�� `r` �ص����׸���
        [Console]::Out.Flush()  # ǿ��ˢ�����

        "[$i]" | Out-File -Append $ownGccRes
        "[$i]" | Out-File -Append $ownVcRes
        "[$i]" | Out-File -Append $demoRes

        & getinput $dataSrc "[$dataPrefix$i]" | & "./$ownGccExe" | Out-File -Append $ownGccRes 2>&1
        & getinput $dataSrc "[$dataPrefix$i]" | & "./$ownVcExe"  | Out-File -Append $ownVcRes  2>&1
        & getinput $dataSrc "[$dataPrefix$i]" | & "./$demoExe"   | Out-File -Append $demoRes   2>&1
    }
    Write-Host "`nִ����ϡ�" -ForegroundColor Green
    # �������벻��
    Write-Host "GCC �������Ƚϣ�" -ForegroundColor DarkBlue
    & txtcomp --file1 $demoRes --file2 $ownGccRes --display normal
    Write-Host "VC �������Ƚϣ�" -ForegroundColor DarkBlue
    & txtcomp --file1 $demoRes --file2 $ownVcRes --display normal
    Write-Host "˵�����ļ� 1 Ϊ��⣬�ļ� 2 Ϊ���⡣"

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
        # ����ļ����Ƿ�Ϊ�գ�û���ļ������ļ��У�
        @(Get-ChildItem -Path $_.FullName -Force).Count -eq 0
    } |
    Remove-Item -Force
}

Write-Host "����װ����ɡ��������ű�װ����ɡ�" -ForegroundColor Green